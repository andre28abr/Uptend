import Foundation

// =============================================================================
// AUDITORIA DE BANCO DE DADOS — achados a partir do SCHEMA (E4, modo estrutura)
// Analisa SÓ a estrutura (nome + tipo das colunas, chaves, índices) — LGPD-safe,
// nunca lê dado. Heurística honesta: aponta o que MERECE VERIFICAÇÃO (ex.: coluna
// com cara de PII em tipo de texto), não afirma que o dado está exposto.
// Lógica pura → testável.
// =============================================================================

public enum DatabaseAudit {

    /// Colunas sensíveis (LGPD) por padrão de NOME → severidade se estiverem em texto plano.
    /// Alta: identificadores fortes / credenciais. Média: PII comum.
    private static let sensitiveHigh = ["senha", "password", "passwd", "pwd", "cpf", "cnpj",
        "rg", "cartao", "cartão", "card", "credit", "cvv", "cvc", "passaporte", "passport"]
    private static let sensitiveMedium = ["email", "e_mail", "e-mail", "telefone", "celular",
        "phone", "endereco", "endereço", "cep", "nascimento", "nasc", "salario", "salário",
        "conta_bancaria", "agencia", "agência", "pix", "token", "secret", "api_key", "apikey",
        "nome_completo", "fullname", "birth"]

    private static func matches(_ name: String, _ patterns: [String]) -> Bool {
        let n = name.lowercased()
        return patterns.contains { n.contains($0) }
    }
    /// Nome sugere que já é um HASH (não texto plano)?
    private static func looksHashed(_ name: String) -> Bool {
        matches(name, ["hash", "bcrypt", "argon", "scrypt", "digest", "encrypted", "cipher"])
    }

    /// Uma amostra dos valores realmente parece um HASH (bcrypt/argon2/sha/md5…)?
    /// Usado só no MODO COMPLETO (amostragem em memória) para confirmar/afastar o achado.
    public static func valuesLookHashed(_ values: [String]) -> Bool {
        let vals = values.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !vals.isEmpty else { return false }
        func isHash(_ v: String) -> Bool {
            if v.hasPrefix("$2a$") || v.hasPrefix("$2b$") || v.hasPrefix("$2y$") || v.hasPrefix("$argon2") || v.hasPrefix("$6$") || v.hasPrefix("$5$") { return true }
            let hex = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
            if [32, 40, 64, 128].contains(v.count), v.unicodeScalars.allSatisfy(hex.contains) { return true }
            return false
        }
        let hashed = vals.filter(isHash).count
        return Double(hashed) / Double(vals.count) >= 0.7
    }

    /// Achados a partir do schema. Em MODO COMPLETO, `passwordSamples` (chave "tabela.coluna" →
    /// valores amostrados EM MEMÓRIA) confirma se a senha é hash ou texto plano.
    public static func findings(from schema: DatabaseSchema,
                                passwordSamples: [String: [String]] = [:]) -> [AuditFinding] {
        var out: [AuditFinding] = []
        let cat = "Banco de dados"

        for table in schema.tables {
            for col in table.columns {
                let where_ = "\(table.name).\(col.name)"

                // Credencial em texto plano (senha/password) — sem cara de hash
                if matches(col.name, ["senha", "password", "passwd", "pwd"]), col.isTextType, !looksHashed(col.name) {
                    // Modo completo: se amostramos e os valores são hash, não é problema → pula.
                    if let sample = passwordSamples[where_] {
                        if valuesLookHashed(sample) { continue }
                        out.append(AuditFinding(
                            id: "db-password-plaintext-\(table.name)-\(col.name)",
                            title: "Senha em texto plano CONFIRMADA por amostra (\(where_))",
                            severity: .high, category: cat,
                            recommendation: "Migre \(col.name) para hash (bcrypt/argon2) e invalide as senhas atuais.",
                            businessImpact: "Amostra dos dados mostra senhas legíveis — vazamento expõe contas na hora. Violação grave de LGPD."))
                        continue
                    }
                    out.append(AuditFinding(
                        id: "db-password-plaintext-\(table.name)-\(col.name)",
                        title: "Coluna de senha possivelmente em texto plano (\(where_))",
                        severity: .high, category: cat,
                        recommendation: "Armazene apenas o hash (bcrypt/argon2), nunca a senha em claro. Confirme que \(col.name) guarda hash.",
                        businessImpact: "Se o banco vazar, senhas em texto plano expõem contas dos clientes imediatamente — violação grave de LGPD."))
                }
                // PII forte em texto plano
                else if matches(col.name, sensitiveHigh), col.isTextType, !looksHashed(col.name) {
                    out.append(AuditFinding(
                        id: "db-pii-strong-\(table.name)-\(col.name)",
                        title: "Dado sensível possivelmente em texto plano (\(where_))",
                        severity: .high, category: cat,
                        recommendation: "Cifre em repouso ou pseudonimize \(col.name); restrinja o acesso ao mínimo necessário.",
                        businessImpact: "CPF/cartão/documento em claro é dado sensível pela LGPD — exposição gera sanção e dano ao titular."))
                }
                // PII comum em texto plano (sem indício de cifra/hash no nome)
                else if matches(col.name, sensitiveMedium), col.isTextType, !looksHashed(col.name) {
                    out.append(AuditFinding(
                        id: "db-pii-\(table.name)-\(col.name)",
                        title: "Possível dado pessoal em texto plano (\(where_))",
                        severity: .medium, category: cat,
                        recommendation: "Avalie cifrar/pseudonimizar \(col.name) e aplicar minimização de dados (LGPD).",
                        businessImpact: "Dado pessoal exposto amplia o impacto de um vazamento e a responsabilidade sob a LGPD."))
                }
            }

            // Tabela sem chave primária (integridade)
            if !table.hasPrimaryKey, !table.columns.isEmpty {
                out.append(AuditFinding(
                    id: "db-no-pk-\(table.name)",
                    title: "Tabela sem chave primária (\(table.name))",
                    severity: .low, category: cat,
                    recommendation: "Defina uma chave primária em \(table.name) para garantir unicidade e integridade.",
                    businessImpact: "Sem chave primária há risco de linhas duplicadas e inconsistência dos dados."))
            }

            // FK sem índice (integridade/desempenho)
            for fk in table.foreignKeyColumns where !table.indexedColumns.contains(fk) {
                out.append(AuditFinding(
                    id: "db-fk-no-index-\(table.name)-\(fk)",
                    title: "Chave estrangeira sem índice (\(table.name).\(fk))",
                    severity: .low, category: cat,
                    recommendation: "Crie um índice em \(fk) para acelerar joins e checagens de integridade.",
                    businessImpact: "FKs sem índice degradam consultas e a verificação de integridade referencial."))
            }
        }

        // Resumo "ok" quando nada foi levantado (mantém a nota alta e sinaliza cobertura)
        if out.isEmpty {
            out.append(AuditFinding(
                id: "db-structure-ok",
                title: "Estrutura do banco sem achados na análise (só schema)",
                severity: .ok, category: cat,
                recommendation: nil,
                businessImpact: nil))
        }
        return out
    }

    /// Constrói uma "auditoria" (ExternalAudit) a partir do schema — o banco vira um alvo
    /// de auditoria como qualquer host, entrando na nota/relatórios/frota.
    public static func makeAudit(from schema: DatabaseSchema, collectedAt: String,
                                 passwordSamples: [String: [String]] = [:]) -> ExternalAudit {
        ExternalAudit(
            schemaVersion: 1,
            collector: .init(name: "uptend-db", version: "1.0.0", mode: passwordSamples.isEmpty ? "estrutura" : "completo"),
            collectedAt: collectedAt,
            host: .init(hostname: "BD: \(schema.name)", machineId: "db:\(schema.engine):\(schema.name)"),
            machine: nil, os: nil, disks: [], resources: nil, users: nil, docker: nil, profile: nil,
            findings: findings(from: schema, passwordSamples: passwordSamples), lynis: nil)
    }
}
