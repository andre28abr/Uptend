import Foundation

/// Coleta o inventário da máquina (dados dos serviços + ferramentas do macOS).
/// Local-first: só lê o próprio Mac, nada é enviado para fora. Sem sudo.
///
/// O pente-fino (`ReportDeep`) é coletado **conforme o escopo** — escopos estreitos
/// continuam rápidos; o "completo" faz o levantamento detalhado.
@MainActor
enum ReportBuilder {

    static func gather(scope: ReportScope, system: SystemService, apps: AppsService,
                       brew: BrewService, security: SecurityService) async -> ReportData {
        if system.info.chip == "—" { await system.loadInfo() }
        if apps.apps.isEmpty { await apps.scan() }
        if security.checks.isEmpty { await security.refresh() }

        // Chamadas independentes em paralelo.
        async let hwC = Shell.capture("/usr/sbin/system_profiler", ["SPHardwareDataType"])
        async let nameC = Shell.capture("/usr/sbin/scutil", ["--get", "ComputerName"])
        async let ipC = primaryIP()
        let hw = await hwC
        let nameOut = await nameC
        let localIP = await ipC
        let serial = value(in: hw.stdout, key: "Serial Number")
        let modelID = value(in: hw.stdout, key: "Model Identifier")
        let uuid = value(in: hw.stdout, key: "Hardware UUID")
        let computerName = nameOut.ok && !nameOut.stdout.trimmed.isEmpty
            ? nameOut.stdout.trimmed : ProcessInfo.processInfo.hostName

        let reportApps = apps.apps.map {
            ReportApp(name: $0.name, version: $0.version, sizeBytes: $0.sizeBytes,
                      source: $0.origin.label, bundleID: $0.bundleID)
        }
        let checks = security.checks.map { ReportCheck(name: $0.name, ok: $0.status == .ok, detail: $0.detail) }
        let info = system.info

        var data = ReportData(
            generatedAt: Date().formatted(date: .abbreviated, time: .shortened),
            computerName: computerName,
            serialNumber: serial.isEmpty ? "—" : serial,
            modelIdentifier: modelID.isEmpty ? "—" : modelID,
            hardwareUUID: uuid.isEmpty ? "—" : uuid,
            model: info.model, chip: info.chip, cores: info.cores, memory: info.memory,
            diskTotal: info.diskTotal, diskFree: info.diskFree, batteryCycles: info.batteryCycles,
            osVersion: info.osVersion, uptime: info.uptime, localIP: localIP,
            apps: reportApps, brewPackages: brew.installedCount, outdated: brew.outdated.count,
            security: checks)

        data.deep = await gatherDeep(scope: scope, apps: apps, brew: brew)
        return data
    }

    // MARK: Pente-fino

    private static func gatherDeep(scope: ReportScope, apps: AppsService, brew: BrewService) async -> ReportDeep? {
        let needHW = SystemReport.includes(.hardware, scope: scope)
        let needSys = SystemReport.includes(.system, scope: scope)
        let needSW = SystemReport.includes(.software, scope: scope)
        let needPers = SystemReport.includes(.personalization, scope: scope)
        let needStorage = SystemReport.includes(.storage, scope: scope)
        guard needHW || needSys || needSW || needPers || needStorage else { return nil }

        // Cada seção roda concorrentemente (e usa async let internamente) — o tempo
        // total fica ≈ o da seção mais lenta, não a soma de todas.
        async let hw = needHW ? hardwareSection() : nil
        async let sys = needSys ? systemSection() : nil
        async let sw = needSW ? softwareSection(brew: brew) : nil
        async let pers = needPers ? personalizationSection(apps: apps, brew: brew) : nil
        async let sto = needStorage ? storageSection() : nil

        var deep = ReportDeep()
        if let h = await hw { deep.gpu = h.gpu; deep.displays = h.displays; deep.batteryCondition = h.battery; deep.rawSections = h.raw }
        if let s = await sys {
            deep.interfaces = s.interfaces; deep.gateway = s.gateway; deep.dns = s.dns
            deep.osBuild = s.osBuild; deep.kernel = s.kernel; deep.bootTime = s.boot
            deep.timezone = s.tz; deep.localHostName = s.localHost
        }
        if let w = await sw {
            deep.runtimes = w.runtimes; deep.brewFormulaeList = w.formulae
            deep.brewCasksList = w.casks; deep.installHistory = w.history
        }
        if let p = await pers {
            deep.sip = p.sip; deep.startupItems = p.startup; deep.loginItems = p.login
            deep.systemExtensions = p.sysext; deep.users = p.users
            deep.brewFormulae = p.fCount; deep.brewCasks = p.cCount
            deep.nonAppStoreApps = p.nonAppStore; deep.hasUsrLocal = p.usrLocal
            deep.hasOpt = p.opt; deep.shellDotfiles = p.dotfiles
        }
        if let st = await sto { deep.folderSizes = st.folders; deep.volumes = st.volumes; deep.largestFiles = st.largest }
        return deep
    }

    // Cada seção do pente-fino, com suas chamadas independentes em paralelo (async let).

    private struct HWDeep { var gpu: [String]; var displays: [String]; var battery: String; var raw: [ReportRawSection] }
    private static func hardwareSection() async -> HWDeep {
        async let dispC = Shell.capture("/usr/sbin/system_profiler", ["SPDisplaysDataType"])
        async let powerC = Shell.capture("/usr/sbin/system_profiler", ["SPPowerDataType"])
        async let rawC = peripherals()
        let disp = await dispC, power = await powerC
        let cond = value(in: power.stdout, key: "Condition")
        let maxCap = value(in: power.stdout, key: "Maximum Capacity")
        return HWDeep(gpu: allValues(in: disp.stdout, key: "Chipset Model"),
                      displays: allValues(in: disp.stdout, key: "Resolution"),
                      battery: [cond, maxCap].filter { !$0.isEmpty }.joined(separator: " · "),
                      raw: await rawC)
    }

    private struct SysDeep { var interfaces: [ReportInterface]; var gateway: String; var dns: [String]; var osBuild: String; var kernel: String; var boot: String; var tz: String; var localHost: String }
    private static func systemSection() async -> SysDeep {
        async let ifacesC = interfaces()
        async let routeC = Shell.capture("/usr/sbin/netstat", ["-rn", "-f", "inet"])
        async let dnsC = Shell.capture("/usr/sbin/scutil", ["--dns"])
        async let buildC = Shell.capture("/usr/bin/sw_vers", ["-buildVersion"])
        async let kernelC = Shell.capture("/usr/bin/uname", ["-mrs"])
        async let bootC = Shell.capture("/usr/sbin/sysctl", ["-n", "kern.boottime"])
        async let tzC = Shell.capture("/usr/bin/readlink", ["/etc/localtime"])
        async let localC = Shell.capture("/usr/sbin/scutil", ["--get", "LocalHostName"])
        return SysDeep(interfaces: await ifacesC,
                       gateway: parseGateway((await routeC).stdout), dns: parseDNS((await dnsC).stdout),
                       osBuild: (await buildC).stdout.trimmed, kernel: (await kernelC).stdout.trimmed,
                       boot: bootTime((await bootC).stdout), tz: timezone((await tzC).stdout),
                       localHost: (await localC).stdout.trimmed)
    }

    private struct SwDeep { var runtimes: [ReportRuntime]; var formulae: [String]; var casks: [String]; var history: [String] }
    private static func softwareSection(brew: BrewService) async -> SwDeep {
        async let rtC = runtimes()
        async let histC = Shell.capture("/usr/sbin/system_profiler", ["SPInstallHistoryDataType"])
        return SwDeep(runtimes: await rtC, formulae: brew.installedFormulaeSorted,
                      casks: brew.installedCasksSorted, history: parseInstallHistory((await histC).stdout))
    }

    private struct PersDeep { var sip: String; var startup: [String]; var login: [String]; var sysext: [String]; var users: [String]; var fCount: Int; var cCount: Int; var nonAppStore: Int; var usrLocal: Bool; var opt: Bool; var dotfiles: [String] }
    private static func personalizationSection(apps: AppsService, brew: BrewService) async -> PersDeep {
        async let sipC = Shell.capture("/usr/bin/csrutil", ["status"])
        async let loginC = loginItems()
        async let extC = Shell.capture("/usr/bin/systemextensionsctl", ["list"])
        async let usersC = Shell.capture("/usr/bin/dscl", [".", "-list", "/Users"])
        let fm = FileManager.default
        return PersDeep(sip: parseSIP((await sipC).stdout), startup: startupItems(), login: await loginC,
                        sysext: parseExtensions((await extC).stdout), users: parseUsers((await usersC).stdout),
                        fCount: brew.installedFormulae.count, cCount: brew.installedCasks.count,
                        nonAppStore: apps.apps.filter { $0.origin.label != AppOrigin.appStore.label }.count,
                        usrLocal: fm.fileExists(atPath: "/usr/local/bin"),
                        opt: fm.fileExists(atPath: "/opt/homebrew") || fm.fileExists(atPath: "/opt/local"),
                        dotfiles: shellDotfiles())
    }

    private struct StoDeep { var folders: [ReportFolder]; var volumes: [String]; var largest: [ReportFile] }
    private static func storageSection() async -> StoDeep {
        async let foldersC = folderSizes()
        async let dfC = Shell.capture("/bin/df", ["-Hl"])
        async let largestC = largestFiles()
        return StoDeep(folders: await foldersC, volumes: parseVolumes((await dfC).stdout), largest: await largestC)
    }

    // MARK: Coletores auxiliares

    private static func primaryIP() async -> String {
        for iface in ["en0", "en1"] {
            let r = await Shell.capture("/usr/sbin/ipconfig", ["getifaddr", iface])
            if r.ok, !r.stdout.trimmed.isEmpty { return r.stdout.trimmed }
        }
        return "—"
    }

    private static func interfaces() async -> [ReportInterface] {
        let names = ["en0", "en1", "en2"]
        return await withTaskGroup(of: (Int, ReportInterface?).self) { group in
            for (index, iface) in names.enumerated() {
                group.addTask {
                    async let ipC = Shell.capture("/usr/sbin/ipconfig", ["getifaddr", iface])
                    async let cfgC = Shell.capture("/sbin/ifconfig", [iface])
                    let ipR = await ipC, cfg = await cfgC
                    let ip = ipR.ok ? ipR.stdout.trimmed : ""
                    let mac = etherAddress(cfg.stdout)
                    return (index, (ip.isEmpty && mac.isEmpty) ? nil : ReportInterface(name: iface, ip: ip, mac: mac))
                }
            }
            var found: [(Int, ReportInterface)] = []
            for await (index, iface) in group { if let iface { found.append((index, iface)) } }
            return found.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    private static func runtimes() async -> [ReportRuntime] {
        let tools: [(String, String, [String])] = [
            ("Node.js", "node", ["--version"]), ("Python", "python3", ["--version"]),
            ("Ruby", "ruby", ["--version"]), ("Go", "go", ["version"]),
            ("Java", "java", ["-version"]), ("PHP", "php", ["--version"]),
            ("Rust", "rustc", ["--version"]), ("Swift", "swift", ["--version"]),
        ]
        // Roda as checagens de versão em paralelo (antes eram sequenciais).
        return await withTaskGroup(of: (Int, ReportRuntime?).self) { group in
            for (index, tool) in tools.enumerated() {
                group.addTask {
                    guard let path = Shell.binaryPath(tool.1) else { return (index, nil) }
                    let r = await Shell.capture(path, tool.2)
                    let line = (r.stdout + r.stderr).split(whereSeparator: \.isNewline).first.map(String.init)?.trimmed ?? ""
                    return (index, line.isEmpty ? nil : ReportRuntime(name: tool.0, version: line))
                }
            }
            var found: [(Int, ReportRuntime)] = []
            for await (index, rt) in group { if let rt { found.append((index, rt)) } }
            return found.sorted { $0.0 < $1.0 }.map(\.1)   // preserva a ordem da lista
        }
    }

    private static func startupItems() -> [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let dirs = ["\(home)/Library/LaunchAgents", "/Library/LaunchAgents", "/Library/LaunchDaemons"]
        var items: [String] = []
        for dir in dirs {
            guard let names = try? FileManager.default.contentsOfDirectory(atPath: dir) else { continue }
            for name in names where name.hasSuffix(".plist") && !name.hasPrefix("com.apple") {
                items.append(name.replacingOccurrences(of: ".plist", with: ""))
            }
        }
        return Array(Set(items)).sorted().prefix(40).map { $0 }
    }

    private static func shellDotfiles() -> [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [".zshrc", ".zprofile", ".zshenv", ".bashrc", ".bash_profile", ".profile", ".gitconfig", ".vimrc"]
        return candidates.filter { FileManager.default.fileExists(atPath: home.appendingPathComponent($0).path) }
    }

    private static func folderSizes() async -> [ReportFolder] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let folders = ["Downloads", "Desktop", "Documents", "Pictures", "Movies", "Music"]
        // `du` de cada pasta em paralelo (a mais pesada define o tempo, não a soma).
        return await withTaskGroup(of: (Int, ReportFolder?).self) { group in
            for (index, folder) in folders.enumerated() {
                group.addTask {
                    let path = "\(home)/\(folder)"
                    guard FileManager.default.fileExists(atPath: path) else { return (index, nil) }
                    let r = await Shell.capture("/usr/bin/du", ["-sk", "-d", "0", path])
                    guard let kb = parseDU(r.stdout) else { return (index, nil) }
                    return (index, ReportFolder(name: folder, bytes: kb * 1024))
                }
            }
            var found: [(Int, ReportFolder)] = []
            for await (index, f) in group { if let f { found.append((index, f)) } }
            return found.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    private static func largestFiles() async -> [ReportFile] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        // Spotlight: rápido, indexado. Arquivos > 500 MB dentro da pasta pessoal.
        let r = await Shell.capture("/usr/bin/mdfind", ["-onlyin", home, "kMDItemFSSize > 524288000"])
        let paths = r.stdout.split(whereSeparator: \.isNewline).prefix(200).map(String.init)
        var files: [ReportFile] = []
        for path in paths {
            if let size = (try? FileManager.default.attributesOfItem(atPath: path))?[.size] as? NSNumber {
                files.append(ReportFile(path: path, bytes: size.int64Value))
            }
        }
        return Array(files.sorted { $0.bytes > $1.bytes }.prefix(15))
    }

    /// Dump bruto de componentes e periféricos (um processo do system_profiler).
    private static func peripherals() async -> [ReportRawSection] {
        let types = ["SPMemoryDataType", "SPStorageDataType", "SPDisplaysDataType", "SPAudioDataType",
                     "SPUSBDataType", "SPThunderboltDataType", "SPBluetoothDataType", "SPNetworkDataType",
                     "SPPowerDataType", "SPPrintersDataType", "SPCameraDataType"]
        let r = await Shell.capture("/usr/sbin/system_profiler", types)
        let text = r.stdout.trimmed
        return text.isEmpty ? [] : [ReportRawSection(title: "Componentes e periféricos", text: String(text.prefix(80000)))]
    }

    /// Itens de login do usuário (via System Events).
    private static func loginItems() async -> [String] {
        let r = await Shell.capture("/usr/bin/osascript",
            ["-e", "tell application \"System Events\" to get the name of every login item"])
        return r.stdout.trimmed.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    // MARK: Parsers puros (testáveis)

    /// Primeiro valor de `Chave: valor` na saída do system_profiler.
    nonisolated static func value(in output: String, key: String) -> String {
        allValues(in: output, key: key).first ?? ""
    }

    /// Todos os valores de linhas `Chave: valor`.
    nonisolated static func allValues(in output: String, key: String) -> [String] {
        var result: [String] = []
        for raw in output.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix(key), let colon = line.firstIndex(of: ":") {
                let v = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                if !v.isEmpty { result.append(v) }
            }
        }
        return result
    }

    nonisolated static func parseSIP(_ output: String) -> String {
        let l = output.lowercased()
        if l.contains("enabled") { return "Ativado" }
        if l.contains("disabled") { return "Desativado" }
        return ""
    }

    nonisolated static func parseDNS(_ output: String) -> [String] {
        var servers: [String] = []
        for raw in output.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("nameserver["), let colon = line.firstIndex(of: ":") {
                let ip = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                if !ip.isEmpty && !servers.contains(ip) { servers.append(ip) }
            }
        }
        return servers
    }

    nonisolated static func parseGateway(_ output: String) -> String {
        for raw in output.split(whereSeparator: \.isNewline) {
            let fields = raw.split(separator: " ", omittingEmptySubsequences: true)
            if fields.count >= 2, fields[0] == "default" { return String(fields[1]) }
        }
        return ""
    }

    nonisolated static func etherAddress(_ output: String) -> String {
        for raw in output.split(whereSeparator: \.isNewline) {
            let fields = raw.trimmingCharacters(in: .whitespaces).split(separator: " ")
            if fields.count >= 2, fields[0] == "ether" { return String(fields[1]) }
        }
        return ""
    }

    /// Primeiro campo (KB) de `du -sk`.
    nonisolated static func parseDU(_ output: String) -> Int64? {
        guard let first = output.split(whereSeparator: { $0 == "\t" || $0 == "\n" }).first else { return nil }
        return Int64(first.trimmingCharacters(in: .whitespaces))
    }

    /// Volumes locais de `df -Hl` (só "/" e "/Volumes/...").
    nonisolated static func parseVolumes(_ output: String) -> [String] {
        var result: [String] = []
        let lines = output.split(whereSeparator: \.isNewline)
        for raw in lines.dropFirst() {   // pula o cabeçalho
            let fields = raw.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            // df -Hl: Filesystem Size Used Avail Capacity iused ifree %iused Mounted-on…
            // O ponto de montagem pode conter espaços (ex.: "/Volumes/My Disk").
            guard fields.count >= 9 else { continue }
            let mounted = fields[8...].joined(separator: " ")
            guard mounted == "/" || mounted.hasPrefix("/Volumes/") else { continue }
            let name = mounted == "/" ? "Sistema (/)" : String(mounted.dropFirst("/Volumes/".count))
            result.append("\(name): \(fields[1]) total, \(fields[2]) usados")
        }
        return result
    }

    nonisolated static func bootTime(_ output: String) -> String {
        guard let r = output.range(of: "sec = ") else { return "" }
        let rest = output[r.upperBound...]
        let digits = rest.prefix { $0.isNumber }
        guard let sec = TimeInterval(digits) else { return "" }
        return Date(timeIntervalSince1970: sec).formatted(date: .abbreviated, time: .shortened)
    }

    nonisolated static func timezone(_ output: String) -> String {
        let t = output.trimmed
        if let r = t.range(of: "zoneinfo/") { return String(t[r.upperBound...]) }
        return t
    }

    nonisolated static func parseUsers(_ output: String) -> [String] {
        let system: Set<String> = ["daemon", "nobody", "root"]
        return output.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("_") && !system.contains($0) }
            .sorted()
    }

    /// Extrai (nome — data) do SPInstallHistoryDataType, mais recentes primeiro.
    nonisolated static func parseInstallHistory(_ output: String) -> [String] {
        var items: [(name: String, date: String)] = []
        var current = ""
        let fields = ["Version:", "Source:", "Install Date:", "Install History:"]
        for raw in output.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.hasSuffix(":"), !line.contains(": "), !fields.contains(where: { line.hasPrefix($0) }) {
                current = String(line.dropLast())
            } else if line.hasPrefix("Install Date:") {
                let date = line.dropFirst("Install Date:".count).trimmingCharacters(in: .whitespaces)
                if !current.isEmpty { items.append((current, date)) }
            }
        }
        return items.sorted { $0.date > $1.date }.prefix(30).map { "\($0.name) — \($0.date)" }
    }

    /// Bundle IDs de extensões de sistema de terceiros (não com.apple).
    nonisolated static func parseExtensions(_ output: String) -> [String] {
        var found: Set<String> = []
        for raw in output.split(whereSeparator: \.isNewline) {
            for token in raw.split(whereSeparator: { $0 == " " || $0 == "\t" }) {
                let t = String(token)
                if t.contains("."), !t.hasPrefix("com.apple"),
                   t.range(of: "^[A-Za-z0-9]+(\\.[A-Za-z0-9-]+)+$", options: .regularExpression) != nil {
                    found.insert(t)
                }
            }
        }
        return Array(found).sorted().prefix(20).map { $0 }
    }
}
