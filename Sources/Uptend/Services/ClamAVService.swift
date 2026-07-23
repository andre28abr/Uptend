import Foundation

/// Frente gráfica para o ClamAV (antivírus open-source, instalado via Homebrew).
/// Detecta, configura, atualiza definições (freshclam), escaneia e gerencia quarentena.
/// Tudo local, como usuário (sem sudo), via `Process` (sem shell).
@MainActor
final class ClamAVService: ObservableObject {
    @Published var installed = false
    @Published var configReady = false
    @Published var dbInfo = "—"
    @Published var running = false
    @Published var log = ""
    @Published var updateStatus: String?
    @Published var quarantine: [URL] = []

    // Modo turbo (daemon clamd + clamdscan multithread)
    @Published var daemonAvailable = false
    @Published var daemonRunning = false
    @Published var daemonBusy = false

    private var clamscanPath: String?
    private var freshclamPath: String?
    private var clamdPath: String?
    private var clamdscanPath: String?
    @Published var scanElapsed: TimeInterval = 0
    @Published var threadOverride: Int? {
        didSet { UserDefaults.standard.set(threadOverride ?? 0, forKey: "uptend.clamThreads") }
    }

    var coreCount: Int { ProcessInfo.processInfo.activeProcessorCount }
    /// Padrão automático: ~3/4 dos núcleos (escala com a máquina).
    var autoThreads: Int { max(2, coreCount * 3 / 4) }
    /// Núcleos efetivamente usados (manual, se definido; senão automático).
    var effectiveThreads: Int { threadOverride ?? autoThreads }
    var usingAutoThreads: Bool { threadOverride == nil }

    private var prefix = "/opt/homebrew"
    private var scanProcess: Process?
    private var cancelRequested = false   // fecha a corrida cancelar↔onStart (B11)
    private var streamRemainder = ""
    private var scanTimer: Timer?
    private var scanStart: Date?

    var quarantineDir: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Uptend/Quarentena")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private var configDir: URL { URL(fileURLWithPath: prefix).appendingPathComponent("etc/clamav") }
    private var freshclamConf: URL { configDir.appendingPathComponent("freshclam.conf") }
    private var clamdConf: URL { configDir.appendingPathComponent("clamd.conf") }
    private var dbDir: URL { URL(fileURLWithPath: prefix).appendingPathComponent("var/lib/clamav") }
    private var runDir: URL { URL(fileURLWithPath: prefix).appendingPathComponent("var/run/clamav") }
    private var socketPath: String { runDir.appendingPathComponent("clamd.sock").path }

    init() {
        let stored = UserDefaults.standard.integer(forKey: "uptend.clamThreads")
        threadOverride = stored > 0 ? stored : nil
    }

    // MARK: Detecção

    func detect() async {
        clamscanPath = Shell.binaryPath("clamscan")
        freshclamPath = Shell.binaryPath("freshclam")
        clamdPath = Shell.binaryPath("clamd")
        clamdscanPath = Shell.binaryPath("clamdscan")
        installed = clamscanPath != nil
        daemonAvailable = clamdPath != nil && clamdscanPath != nil

        if let path = clamscanPath {
            prefix = URL(fileURLWithPath: path).deletingLastPathComponent().deletingLastPathComponent().path
            let version = await Shell.capture(path, ["--version"])
            dbInfo = Self.parseVersion(version.stdout)
        }
        configReady = FileManager.default.fileExists(atPath: freshclamConf.path)

        let ping = await Shell.capture("/usr/bin/pgrep", ["-x", "clamd"])
        daemonRunning = ping.ok && !ping.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        loadQuarantine()
    }

    // MARK: Modo turbo (daemon)

    func setupDaemonConfig() async {
        try? FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
        let threads = effectiveThreads
        let conf = """
        LocalSocket \(socketPath)
        DatabaseDirectory \(dbDir.path)
        MaxThreads \(threads)
        """
        try? conf.write(to: clamdConf, atomically: true, encoding: .utf8)
    }

    func startDaemon() async {
        guard let clamdPath, !daemonRunning else { return }
        await setupDaemonConfig()
        daemonBusy = true
        log = "$ clamd (carregando as definições na memória, ~20s…)\n\n"
        // O clamd carrega o banco e daemoniza; o comando retorna quando fica pronto.
        let out = await Shell.capture(clamdPath, ["--config-file=" + clamdConf.path], env: Shell.brewEnv)
        daemonBusy = false
        await detect()
        if daemonRunning {
            log += "Daemon ativo. Os escaneamentos agora usam todos os núcleos.\n"
            ActionLog.shared.record("ClamAV: modo turbo (daemon) iniciado")
        } else {
            log += (out.stderr.isEmpty ? out.stdout : out.stderr)
            log += "\n\n== Não foi possível iniciar o daemon. Atualize as definições e tente novamente. ==\n"
        }
    }

    func stopDaemon() async {
        daemonBusy = true
        _ = await Shell.capture("/usr/bin/killall", ["clamd"])
        daemonBusy = false
        await detect()
        ActionLog.shared.record("ClamAV: modo turbo (daemon) parado")
    }

    nonisolated static func parseVersion(_ output: String) -> String {
        let parts = output.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "/")
        if parts.count >= 3 { return "Definições \(parts[1]) — \(parts[2])" }
        return "Sem definições (atualize)"
    }

    // MARK: Configuração

    func setupConfig() async {
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)

        let sample = configDir.appendingPathComponent("freshclam.conf.sample")
        if !FileManager.default.fileExists(atPath: freshclamConf.path),
           let content = try? String(contentsOf: sample, encoding: .utf8) {
            // O sample vem com a linha "Example" que precisa ser comentada.
            let fixed = content.replacingOccurrences(of: "(?m)^Example$", with: "#Example", options: .regularExpression)
            try? fixed.write(to: freshclamConf, atomically: true, encoding: .utf8)
        }
        configReady = FileManager.default.fileExists(atPath: freshclamConf.path)
    }

    // MARK: Atualizar definições

    func updateDefinitions() async {
        guard let freshclamPath else { return }
        if !configReady { await setupConfig() }
        running = true
        updateStatus = nil
        log = "$ freshclam\n\n"
        let code = await Shell.stream(freshclamPath, [], env: Shell.brewEnv) { chunk in
            Task { @MainActor in self.log += chunk }
        }
        running = false
        // O freshclam pode imprimir "ERROR: NULL X509 store" (aviso inofensivo no macOS)
        // e mesmo assim concluir. Consideramos sucesso pelo código e pelo conteúdo.
        let ok = code == 0
            || log.contains("updated")
            || log.localizedCaseInsensitiveContains("up to date")
            || log.localizedCaseInsensitiveContains("up-to-date")
        updateStatus = ok ? "Definições atualizadas com sucesso." : "Falha ao atualizar (código \(code))."
        ActionLog.shared.record(ok ? "ClamAV: definições atualizadas" : "ClamAV: falha ao atualizar")
        await detect()
    }

    /// Indica se o log contém o aviso conhecido e inofensivo de certificado TLS.
    var hasHarmlessX509Warning: Bool {
        log.contains("NULL X509 store")
    }

    // MARK: Escanear

    /// Pastas de maior risco para o escaneamento rápido (sem /Applications, que é grande).
    func quickScanPaths() -> [String] {
        let home = NSHomeDirectory()
        return ["\(home)/Downloads", "\(home)/Desktop", "/private/tmp"]
            .filter { FileManager.default.fileExists(atPath: $0) }
    }

    /// Completo **curado**: lista de alto valor para malware e rápida — apps, locais de
    /// download e pontos de persistência. Não inclui Application Support (cheio de caches
    /// de navegador/IDE, baixo valor e muito lento); isso fica no Agressivo.
    func curatedScanPaths() -> [String] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        func rel(_ p: String) -> String { home.appendingPathComponent(p).path }

        return [
            "/Applications",
            rel("Applications"),
            rel("Downloads"),
            rel("Desktop"),
            rel("Documents"),
            // Persistência via LaunchAgents/Daemons.
            rel("Library/LaunchAgents"),
            "/Library/LaunchAgents",
            "/Library/LaunchDaemons",
            // Persistência via arquivos de inicialização do shell (malware injeta uma linha).
            rel(".zshrc"), rel(".zprofile"), rel(".zshenv"), rel(".zlogin"),
            rel(".bash_profile"), rel(".bashrc"), rel(".profile"),
        ].filter { fm.fileExists(atPath: $0) }
    }

    /// Agressivo: Aplicativos + pasta pessoal inteira, sem exclusões (mais demorado e quente).
    func aggressiveScanPaths() -> [String] {
        ["/Applications", NSHomeDirectory()].filter { FileManager.default.fileExists(atPath: $0) }
    }

    nonisolated static func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let minutes = total / 60
        let secs = total % 60
        return minutes > 0 ? "\(minutes)m \(secs)s" : "\(secs)s"
    }

    func scan(paths: [String], quarantineInfected: Bool) async {
        let usesDaemon = daemonRunning && clamdscanPath != nil
        guard let bin = usesDaemon ? clamdscanPath : clamscanPath, !paths.isEmpty else { return }

        var args: [String]
        if usesDaemon {
            // clamdscan é recursivo por padrão; --multiscan usa várias threads.
            // (Sem --fdpass: o clamd roda como o próprio usuário e lê os arquivos direto;
            //  o --fdpass gerava avisos inofensivos "cli_realpath" no macOS.)
            args = ["--multiscan", "--infected", "--config-file=" + clamdConf.path]
        } else {
            args = ["-r", "--infected"]
        }
        if quarantineInfected {
            args.append("--move=" + quarantineDir.path)
        }
        args += paths

        running = true
        cancelRequested = false
        updateStatus = nil
        streamRemainder = ""
        startScanTimer()
        log = "$ \(usesDaemon ? "clamdscan (turbo, multinúcleo)" : "clamscan") — \(paths.joined(separator: ", "))\n\n"
        let code = await Shell.stream(bin, args, env: Shell.brewEnv,
                                      onStart: { [weak self] proc in Task { @MainActor in
                                          guard let self else { return }
                                          // Se o cancelamento chegou primeiro, encerra já; senão registra.
                                          if self.cancelRequested { proc.terminate() } else { self.scanProcess = proc }
                                      } }) { chunk in
            Task { @MainActor in self.appendScanChunk(chunk) }
        }
        // Descarrega o que sobrou no buffer (última linha parcial).
        if !streamRemainder.isEmpty && !Self.isNoiseLine(streamRemainder) { log += streamRemainder }
        streamRemainder = ""
        stopScanTimer()
        running = false
        scanProcess = nil
        loadQuarantine()
        log += "\nTempo total: \(Self.formatDuration(scanElapsed))\n"
        if code == 2 {
            log += "== Verificação interrompida ==\n"
            return
        }
        let result = Self.parseScan(log)
        ActionLog.shared.record("ClamAV: verificação — \(result.infected) ameaça(s) em \(Self.formatDuration(scanElapsed))")
    }

    private func startScanTimer() {
        scanStart = Date()
        scanElapsed = 0
        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                if let start = self?.scanStart { self?.scanElapsed = Date().timeIntervalSince(start) }
            }
        }
    }

    private func stopScanTimer() {
        scanTimer?.invalidate()
        scanTimer = nil
        if let start = scanStart { scanElapsed = Date().timeIntervalSince(start) }
    }

    /// Acumula a saída por linhas e descarta os avisos de ruído do libclamav
    /// (ex.: "cli_realpath: Invalid arguments", inofensivos no macOS).
    private func appendScanChunk(_ chunk: String) {
        streamRemainder += chunk
        let parts = streamRemainder.components(separatedBy: "\n")
        streamRemainder = parts.last ?? ""
        for line in parts.dropLast() where !Self.isNoiseLine(line) {
            log += line + "\n"
        }
    }

    nonisolated static func isNoiseLine(_ line: String) -> Bool {
        line.contains("LibClamAV Warning")
            || line.contains("cli_realpath")
            || line.contains("File tree walk aborted")
            || line.contains("safe quarantine action")
            || line.contains("traverse_to:")
    }

    /// Interrompe um escaneamento em andamento.
    func cancelScan() {
        cancelRequested = true          // se o onStart ainda não registrou o processo, ele encerra ao chegar
        scanProcess?.terminate()
        scanProcess = nil
    }

    nonisolated static func parseScan(_ output: String) -> (infected: Int, findings: [(file: String, signature: String)]) {
        var findings: [(String, String)] = []
        var infected = 0
        for line in output.split(whereSeparator: \.isNewline) {
            let s = String(line)
            if s.hasSuffix(" FOUND") {
                let body = String(s.dropLast(" FOUND".count))
                if let range = body.range(of: ": ", options: .backwards) {
                    findings.append((String(body[..<range.lowerBound]), String(body[range.upperBound...])))
                }
            } else if s.hasPrefix("Infected files:") {
                infected = Int(s.replacingOccurrences(of: "Infected files:", with: "").trimmingCharacters(in: .whitespaces)) ?? findings.count
            }
        }
        if infected == 0 { infected = findings.count }
        return (infected, findings)
    }

    // MARK: Quarentena

    func loadQuarantine() {
        quarantine = (try? FileManager.default.contentsOfDirectory(
            at: quarantineDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
    }

    func deleteQuarantined(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        loadQuarantine()
        ActionLog.shared.record("ClamAV: item da quarentena excluído")
    }
}
