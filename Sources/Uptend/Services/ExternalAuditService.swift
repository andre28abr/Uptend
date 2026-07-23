import Foundation
import UptendCore

// =============================================================================
// AUDITORIA EXTERNA — serviço de ingestão (Fase 2)
// Importa arquivos de auditoria (JSON schema v1), guarda um histórico local em
// Application Support e roda o coletor portátil num host conectado por SSH.
// Toda a lógica de schema/pontuação vive em UptendCore (puro/testável).
// =============================================================================

/// Uma auditoria carregada na interface: o documento + de onde veio + a nota.
struct LoadedAudit: Identifiable, Equatable {
    let id: String                 // hash do conteúdo (dedup e cadeia de custódia)
    let audit: ExternalAudit
    let importedAt: Date

    var score: AuditScore { AuditScoring.evaluate(audit) }
    var hostname: String { audit.host.hostname }

    static func == (lhs: LoadedAudit, rhs: LoadedAudit) -> Bool { lhs.id == rhs.id }
}

@MainActor
final class ExternalAuditService: ObservableObject {
    @Published private(set) var audits: [LoadedAudit] = []
    @Published var selectedID: String?
    @Published var busy = false
    @Published var busyMessage: String?
    @Published var lastError: String?

    /// A auditoria em foco no painel (a selecionada, ou a mais recente).
    var selected: LoadedAudit? {
        audits.first { $0.id == selectedID } ?? audits.first
    }

    /// Banco central do app (SQLite). As auditorias ficam como registros do tipo
    /// `VaultKind.externalAudit` — o mesmo banco guardará dados das outras abas.
    private let vault: UptendVault

    /// Retenção do histórico (dias). Registros mais antigos são apagados na abertura.
    let retentionDays: Int

    /// Em produção usa o banco central compartilhado (`.shared`); testes injetam um
    /// banco em memória/temporário. `nil` resolve para `.shared` já no contexto
    /// @MainActor (usar `.shared` como valor-padrão o avaliaria fora do ator).
    init(vault: UptendVault? = nil, retentionDays: Int = 90) {
        self.vault = vault ?? .shared
        self.retentionDays = retentionDays
        pruneOld()
        reload()
    }

    /// Remove auditorias mais antigas que `retentionDays`. Retorna quantas.
    @discardableResult
    func pruneOld() -> Int {
        vault.pruneOlderThan(days: retentionDays, kind: VaultKind.externalAudit)
    }

    /// Apaga TODO o histórico de auditorias (limpar para liberar espaço).
    func clearAll() {
        vault.clear(kind: VaultKind.externalAudit)
        audits = []
        selectedID = nil
    }

    /// Espaço ocupado pelo histórico de auditorias no banco.
    func storageBytes() -> Int64 { vault.totalBytes(kind: VaultKind.externalAudit) }

    /// Bytes exatos (JSON) da auditoria selecionada — para assinar/verificar (A2).
    func selectedPayload() -> Data? {
        guard let id = selected?.id else { return nil }
        return vault.payload(id: id)
    }

    // MARK: Histórico persistido

    /// Recarrega o histórico a partir do banco (mais recentes primeiro).
    func reload() {
        var loaded: [LoadedAudit] = []
        for rec in vault.records(kind: VaultKind.externalAudit) {
            guard let data = vault.payload(id: rec.id),
                  let audit = try? ExternalAuditParser.parse(data) else { continue }
            loaded.append(LoadedAudit(id: rec.id, audit: audit, importedAt: rec.importedAt))
        }
        audits = loaded    // já vem ordenado por importedAt DESC do banco
        if selectedID == nil || !audits.contains(where: { $0.id == selectedID }) {
            selectedID = audits.first?.id
        }
    }

    /// Ingere uma auditoria montada no app (ex.: auditoria de banco de dados) no Vault.
    @discardableResult
    func ingestAudit(_ audit: ExternalAudit, suggestedName: String) -> Bool {
        let enc = JSONEncoder(); enc.keyEncodingStrategy = .convertToSnakeCase
        guard let data = try? enc.encode(audit) else { lastError = "Falha ao preparar a auditoria."; return false }
        return ingest(data, suggestedName: suggestedName)
    }

    /// A coleta anterior do MESMO host (por data de coleta), para detecção de desvio (drift).
    func previousAudit(for current: LoadedAudit) -> LoadedAudit? {
        let key = RiskExceptionStore.hostKey(current.audit)
        return audits
            .filter { $0.id != current.id
                && RiskExceptionStore.hostKey($0.audit) == key
                && $0.audit.collectedAt < current.audit.collectedAt }
            .max { $0.audit.collectedAt < $1.audit.collectedAt }
    }

    func remove(_ loaded: LoadedAudit) {
        vault.delete(id: loaded.id)
        audits.removeAll { $0.id == loaded.id }
        if selectedID == loaded.id { selectedID = audits.first?.id }
    }

    /// Migra auditorias salvas na versão antiga (arquivos JSON em Application Support/
    /// Uptend/audits) para o banco central. Idempotente (dedup por conteúdo). Chamado
    /// uma vez pelo app — nunca nos testes (que usam bancos isolados).
    func migrateLegacyFilesIfPresent() {
        let fm = FileManager.default
        guard let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let dir = base.appendingPathComponent("Uptend/audits", isDirectory: true)
        guard fm.fileExists(atPath: dir.path) else { return }
        var migrated = 0
        for url in (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [] where url.pathExtension == "json" {
            if let data = try? Data(contentsOf: url),
               ingest(data, suggestedName: url.deletingPathExtension().lastPathComponent) { migrated += 1 }
        }
        // Renomeia a pasta para não reprocessar (se falhar, a dedup por conteúdo protege).
        try? fm.moveItem(at: dir, to: base.appendingPathComponent("Uptend/audits-migrado", isDirectory: true))
        if migrated > 0 { reload() }
    }

    // MARK: Importar de arquivo

    /// Importa um arquivo `.json` de auditoria (arrastar ou "Importar…").
    @discardableResult
    func importFile(_ url: URL) -> Bool {
        lastError = nil
        let needsStop = url.startAccessingSecurityScopedResource()
        defer { if needsStop { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            lastError = "Não consegui ler o arquivo."
            return false
        }
        return ingest(data, suggestedName: url.deletingPathExtension().lastPathComponent)
    }

    /// Valida e guarda um JSON de auditoria. Retorna false (e preenche `lastError`) se inválido.
    @discardableResult
    func ingest(_ data: Data, suggestedName: String) -> Bool {
        let parsed: ExternalAudit
        do {
            parsed = try ExternalAuditParser.parse(data)
        } catch let ExternalAuditParser.ParseError.unsupportedVersion(found, max) {
            lastError = "Este arquivo é de uma versão mais nova (schema \(found)) do que este Uptend entende (até \(max)). Atualize o app."
            return false
        } catch {
            lastError = "Arquivo de auditoria inválido (não é um JSON no formato esperado)."
            return false
        }

        // Se veio schema de banco, deriva os achados de estrutura/LGPD e re-serializa (E4).
        let audit = parsed.enrichedWithDatabaseFindings()
        var data = data
        if audit.findings.count != parsed.findings.count {
            let enc = JSONEncoder(); enc.keyEncodingStrategy = .convertToSnakeCase
            if let d = try? enc.encode(audit) { data = d }
        }

        let id = Self.hash(data)
        if let existing = audits.first(where: { $0.id == id }) {
            selectedID = existing.id       // já importado (mesmo conteúdo) — só seleciona
            return true
        }
        let host = audit.host.hostname.isEmpty ? suggestedName : audit.host.hostname
        let importedAt = Date()
        let ok = vault.insert(id: id, kind: VaultKind.externalAudit, source: host, title: host,
                              createdAt: Self.parseISO(audit.collectedAt) ?? importedAt,
                              payload: data, importedAt: importedAt)
        guard ok else {
            lastError = "Não consegui guardar a auditoria no banco."
            return false
        }
        audits.insert(LoadedAudit(id: id, audit: audit, importedAt: importedAt), at: 0)
        selectedID = id
        return true
    }

    // MARK: Rodar o coletor num host conectado (SSH)

    /// Envia o coletor portátil ao host (base64 → arquivo temporário), roda uma passada
    /// read-only, recupera o JSON pela saída padrão e o importa. Limpa os temporários.
    func runCollector(on host: RemoteHost, runLynis: Bool = false, auditDB: Bool = false) async {
        lastError = nil
        busy = true
        busyMessage = runLynis ? "Coletando + Lynis em \(host.name)… (pode levar 1–2 min)" : "Coletando em \(host.name)…"
        defer { busy = false; busyMessage = nil }

        guard let scriptURL = Bundle.module.url(forResource: "audit-collector", withExtension: "sh"),
              let scriptData = try? Data(contentsOf: scriptURL) else {
            lastError = "Coletor não encontrado no pacote do app."
            return
        }
        let b64 = scriptData.base64EncodedString()
        let inv = Self.collectorInvocation(scriptB64: b64, runLynis: runLynis, auditDB: auditDB,
                                           db: host.db, password: host.db.flatMap { _ in DBCredentialStore.password(for: host) })

        let r = await SSHRunner.run(host, ["bash", "-lc", inv.remote], stdin: inv.stdin)
        guard r.ok, let jsonStart = r.stdout.firstIndex(of: "{") else {
            let err = (r.stderr.isEmpty ? r.stdout : r.stderr).trimmingCharacters(in: .whitespacesAndNewlines)
            lastError = err.isEmpty ? "A coleta não retornou dados." : "Falha na coleta: \(err)"
            return
        }
        let json = String(r.stdout[jsonStart...])
        if !ingest(Data(json.utf8), suggestedName: host.name) {
            // lastError já preenchido pelo ingest
        }
    }

    /// Comando remoto + stdin da coleta. `stdin` carrega a senha do banco (se houver),
    /// para que ela NUNCA apareça no argv/cmdline do processo remoto (world-readable
    /// em /proc). Os demais campos (usuário/host/porta/nome do banco) não são segredo
    /// e seguem inline. Puro → testável.
    struct CollectorInvocation: Equatable { let remote: String; let stdin: String? }

    nonisolated static func collectorInvocation(scriptB64 b64: String, runLynis: Bool, auditDB: Bool,
                                                db: DBCredential?, password: String?) -> CollectorInvocation {
        var env = runLynis ? "UPTEND_RUN_LYNIS=1 " : ""
        var prelude = ""
        var stdin: String? = nil
        if auditDB {
            env += "UPTEND_DB_AUDIT=1 "
            // Credencial de banco (se cadastrada). Sem credencial → peer auth no servidor.
            if let db {
                let q = SSHRunner.shellQuote
                let p = db.kind == "mysql" ? "UPTEND_MY" : "UPTEND_PG"
                env += "\(p)_USER=\(q(db.user)) \(p)_HOST=\(q(db.host)) \(p)_PORT=\(db.port) "
                if !db.database.isEmpty { env += "\(p)_DB=\(q(db.database)) " }
                if let pw = password, !pw.isEmpty {
                    // Senha via stdin: lida no início e exportada para o ambiente do
                    // coletor. Environ é legível só pelo dono do processo (≠ cmdline).
                    stdin = pw + "\n"
                    prelude = "IFS= read -r __UPTEND_DBPW; export \(p)_PASSWORD=\"$__UPTEND_DBPW\"; "
                }
            }
        }
        // Uma passada: grava o script num temp, roda (saída em /tmp), imprime o JSON e limpa.
        let remote = prelude
            + "echo \(b64) | base64 -d > /tmp/uptend-ac.sh && "
            + "F=$(\(env)bash /tmp/uptend-ac.sh /tmp 2>/dev/null | grep '^UPTEND_AUDIT_FILE=' | cut -d= -f2) && "
            + "cat \"$F\" && rm -f /tmp/uptend-ac.sh \"$F\" \"$F.sha256\""
        return CollectorInvocation(remote: remote, stdin: stdin)
    }

    // MARK: Coletor avulso (exportar o script)

    /// Conteúdo do coletor portátil (para salvar num pen drive e rodar offline).
    static func collectorScript() -> Data? {
        guard let url = Bundle.module.url(forResource: "audit-collector", withExtension: "sh") else { return nil }
        return try? Data(contentsOf: url)
    }

    /// Salva o coletor em `url` (torna executável). Retorna false + `lastError` se falhar.
    @discardableResult
    func exportCollector(to url: URL) -> Bool {
        lastError = nil
        guard let data = Self.collectorScript() else {
            lastError = "Coletor não encontrado no pacote do app."
            return false
        }
        do {
            try data.write(to: url, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
            return true
        } catch {
            lastError = "Não consegui salvar o coletor: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: Mesclar achados de varredura ativa (TLS) na auditoria selecionada

    /// Substitui os achados de varredura anteriores (prefixo `tls-scan-`) pelos novos e
    /// re-salva a auditoria informada. Relatórios e nota desse host passam a incluir o TLS.
    @discardableResult
    func mergeScanFindings(_ scan: [AuditFinding], into sel: LoadedAudit) -> Bool {
        let base = sel.audit.findings.filter { !$0.id.hasPrefix("tls-scan-") }
        let updated = sel.audit.replacingFindings(base + scan)

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        guard let data = try? encoder.encode(updated) else { lastError = "Falha ao atualizar a auditoria."; return false }

        // Substitui no banco (novo hash) mantendo data/origem.
        vault.delete(id: sel.id)
        let newID = Self.hash(data)
        let ok = vault.insert(id: newID, kind: VaultKind.externalAudit,
                              source: updated.host.hostname, title: updated.host.hostname,
                              createdAt: Self.parseISO(updated.collectedAt) ?? Date(),
                              payload: data, importedAt: Date())
        guard ok else { lastError = "Falha ao guardar a auditoria atualizada."; reload(); return false }
        reload()
        selectedID = newID
        return true
    }

    // MARK: Helpers

    private static func hash(_ data: Data) -> String {
        HashUtil.sha256(data: data)
    }

    private static func parseISO(_ iso: String) -> Date? {
        ISO8601DateFormatter().date(from: iso)
    }
}
