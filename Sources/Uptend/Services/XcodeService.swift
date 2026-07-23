import Foundation

struct SimDevice: Identifiable, Sendable, Hashable {
    let name: String
    let udid: String
    let os: String
    let state: String            // Booted / Shutdown / Creating
    var id: String { udid }
    var isBooted: Bool { state == "Booted" }
}

/// Gerencia o Xcode (versão, DerivedData) e os simuladores de iOS/iPadOS.
/// Leitura + limpeza reversível (DerivedData vai para a Lixeira). Sem sudo.
@MainActor
final class XcodeService: ObservableObject {
    @Published var installed = false
    @Published var xcodePath = ""
    @Published var version = ""
    @Published var derivedDataBytes: Int64 = 0
    @Published var simulatorsBytes: Int64 = 0
    @Published var runtimeSize = ""
    @Published var runtimeCount = 0
    @Published var simulators: [SimDevice] = []
    @Published var loading = false
    @Published var busy: String?
    @Published var lastError: String?

    private var derivedDataURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/Xcode/DerivedData")
    }

    func refresh() async {
        loading = true
        defer { loading = false }
        let sel = await Shell.capture("/usr/bin/xcode-select", ["-p"])
        xcodePath = sel.stdout.trimmed
        installed = sel.ok && xcodePath.contains("Xcode")

        // Versão pelo Info.plist (sem prompt de licença).
        if let appRange = xcodePath.range(of: "Xcode.app") {
            let plist = String(xcodePath[..<appRange.upperBound]) + "/Contents/Info"
            let v = await Shell.capture("/usr/bin/defaults", ["read", plist, "CFBundleShortVersionString"])
            version = v.stdout.trimmed
        }

        derivedDataBytes = await Task.detached { [url = derivedDataURL] in
            FileManager.default.fileExists(atPath: url.path) ? FileUtils.size(of: url) : 0
        }.value

        let devices = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/CoreSimulator/Devices").path
        async let sizeC = Shell.capture("/usr/bin/du", ["-sk", "-d", "0", devices])
        async let listC = Shell.capture("/usr/bin/xcrun", ["simctl", "list", "devices", "available"])
        async let runtimeC = Shell.capture("/usr/bin/xcrun", ["simctl", "runtime", "list"])
        if let kb = (await sizeC).stdout.split(whereSeparator: { $0 == "\t" || $0 == "\n" }).first
            .flatMap({ Int64($0.trimmingCharacters(in: .whitespaces)) }) {
            simulatorsBytes = kb * 1024
        }
        simulators = Self.parseSimulators((await listC).stdout)
        let runtime = Self.parseRuntimeTotal((await runtimeC).stdout)
        runtimeCount = runtime.count
        runtimeSize = runtime.size
    }

    /// Apaga os simuladores "indisponíveis" (de runtimes que você não tem mais).
    func deleteUnavailable() async {
        busy = "unavailable"
        lastError = nil
        defer { busy = nil }
        let r = await Shell.capture("/usr/bin/xcrun", ["simctl", "delete", "unavailable"])
        if !r.ok { lastError = "Falha: " + (r.stderr.isEmpty ? r.stdout : r.stderr).trimmed }
        await refresh()
    }

    var simulatorsLabel: String {
        ByteCountFormatter.string(fromByteCount: simulatorsBytes, countStyle: .file)
    }

    /// Total das imagens de iOS baixadas (ex.: "7,9 GB"). Vazio se não houver runtimes.
    var runtimeLabel: String { Self.friendlySize(runtimeSize) }

    /// Move o DerivedData para a Lixeira (reversível). Libera muito espaço.
    func cleanDerivedData() async {
        busy = "derived"
        lastError = nil
        defer { busy = nil }
        do {
            if FileManager.default.fileExists(atPath: derivedDataURL.path) {
                try FileManager.default.trashItem(at: derivedDataURL, resultingItemURL: nil)
                ActionLog.shared.record("DerivedData movido para a Lixeira")
            }
        } catch {
            lastError = "Não foi possível limpar o DerivedData: \(error.localizedDescription)"
        }
        await refresh()
    }

    func shutdown(_ udid: String) async { await simctl("shutdown", udid) }
    func erase(_ udid: String) async { await simctl("erase", udid) }
    func delete(_ udid: String) async { await simctl("delete", udid) }

    private func simctl(_ action: String, _ udid: String) async {
        guard udid.range(of: "^[0-9A-Fa-f-]{36}$", options: .regularExpression) != nil else {
            lastError = "Identificador de simulador inválido."; return
        }
        busy = udid
        lastError = nil
        defer { busy = nil }
        let r = await Shell.capture("/usr/bin/xcrun", ["simctl", action, udid])
        if !r.ok { lastError = "Falha (\(action)): " + (r.stderr.isEmpty ? r.stdout : r.stderr).trimmed }
        await refresh()
    }

    var derivedDataLabel: String {
        ByteCountFormatter.string(fromByteCount: derivedDataBytes, countStyle: .file)
    }

    // MARK: Parser (puro, testável)

    /// Lê o rodapé de `xcrun simctl runtime list`: "Total Disk Images: N (7.9G)".
    nonisolated static func parseRuntimeTotal(_ output: String) -> (count: Int, size: String) {
        for raw in output.split(whereSeparator: \.isNewline) {
            let line = String(raw).trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("Total Disk Images:") else { continue }
            let count = Int(line.drop(while: { !$0.isNumber }).prefix(while: \.isNumber)) ?? 0
            var size = ""
            if let open = line.firstIndex(of: "("), let close = line.lastIndex(of: ")"), open < close {
                size = String(line[line.index(after: open)..<close]).trimmingCharacters(in: .whitespaces)
            }
            return (count, size)
        }
        return (0, "")
    }

    /// Deixa o tamanho do `du`/`simctl` mais legível: "7.9G" -> "7.9 GB".
    nonisolated static func friendlySize(_ raw: String) -> String {
        guard let last = raw.last, last.isLetter else { return raw }
        return "\(raw.dropLast()) \(last)B"
    }

    /// Lê `xcrun simctl list devices available`.
    nonisolated static func parseSimulators(_ output: String) -> [SimDevice] {
        var result: [SimDevice] = []
        var currentOS = ""
        for raw in output.split(whereSeparator: \.isNewline) {
            let line = String(raw)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("--"), trimmed.hasSuffix("--") {
                currentOS = trimmed.replacingOccurrences(of: "--", with: "").trimmingCharacters(in: .whitespaces)
                continue
            }
            // "    Nome (UUID) (Estado)"
            guard let udidRange = trimmed.range(of: "[0-9A-F]{8}-[0-9A-F-]{27}", options: [.regularExpression, .caseInsensitive]) else { continue }
            let udid = String(trimmed[udidRange])
            let name = String(trimmed[..<udidRange.lowerBound])
                .trimmingCharacters(in: CharacterSet(charactersIn: " (")).trimmingCharacters(in: .whitespaces)
            var state = "Shutdown"
            if let stateRange = trimmed.range(of: "\\((Booted|Shutdown|Creating|Booting)\\)", options: .regularExpression) {
                state = trimmed[stateRange].trimmingCharacters(in: CharacterSet(charactersIn: "()"))
            }
            if !name.isEmpty { result.append(SimDevice(name: name, udid: udid, os: currentOS, state: state)) }
        }
        return result
    }
}
