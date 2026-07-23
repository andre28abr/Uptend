import Foundation

// =============================================================================
// DISCOS DO SERVIDOR (leitura) — Passo 7 do módulo Servidor
// Dispositivos (lsblk), uso dos sistemas de arquivos (df), status de RAID
// (mdadm/ZFS) e saúde SMART. Só LEITURA — montar/formatar/RAID/cripto são
// destrutivos e ficam para depois, com hardware real e travas fortes.
// =============================================================================

struct BlockDevice: Identifiable, Hashable {
    let name: String
    let sizeBytes: Int64
    let type: String        // disk / part / lvm …
    let mount: String
    let fstype: String
    var id: String { name }
    var isDisk: Bool { type == "disk" }
    var sizeLabel: String { ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file) }
}

struct FSUsage: Identifiable, Hashable {
    let source: String
    let fstype: String
    let sizeBytes: Int64
    let usedBytes: Int64
    let mount: String
    var id: String { source }
    var usedFraction: Double { sizeBytes > 0 ? Double(usedBytes) / Double(sizeBytes) : 0 }
    var usedLabel: String { ByteCountFormatter.string(fromByteCount: usedBytes, countStyle: .file) }
    var sizeLabel: String { ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file) }
}

enum RemoteDisks {

    static func devices(_ host: RemoteHost) async -> [BlockDevice] {
        let r = await SSHRunner.run(host, ["lsblk", "-b", "-P", "-o", "NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE"])
        return parseLsblk(r.stdout)
    }

    static func usage(_ host: RemoteHost) async -> [FSUsage] {
        let r = await SSHRunner.run(host, ["df", "-B1", "--output=source,fstype,size,used,avail,pcent,target"])
        return parseDf(r.stdout)
    }

    static func raidStatus(_ host: RemoteHost) async -> String {
        let r = await SSHRunner.run(host, ["bash", "-lc",
            "cat /proc/mdstat 2>/dev/null; echo ---ZFS---; (command -v zpool >/dev/null && sudo -n zpool status 2>/dev/null || echo no-zfs)"])
        return summarizeRaid(r.stdout)
    }

    static func smartInstalled(_ host: RemoteHost) async -> Bool {
        let r = await SSHRunner.run(host, ["bash", "-lc", "command -v smartctl >/dev/null && echo yes || echo no"])
        return r.stdout.contains("yes")
    }

    static let installSmartArgs = ["bash", "-lc",
        "sudo -n apt-get install -y smartmontools >/dev/null 2>&1; command -v smartctl >/dev/null && echo INSTALADO || echo FALHOU"]

    static func smart(_ host: RemoteHost, device: String) async -> String {
        guard InputValidator.isValidFileName(device) else { return "Dispositivo inválido." }
        let r = await SSHRunner.run(host, ["sudo", "-n", "smartctl", "-H", "/dev/" + device])
        let out = (r.stdout + "\n" + r.stderr).trimmingCharacters(in: .whitespacesAndNewlines)
        return out.isEmpty ? "Sem saída." : out
    }

    // MARK: Parsers puros

    static func parseLsblk(_ output: String) -> [BlockDevice] {
        output.split(whereSeparator: \.isNewline).compactMap { raw -> BlockDevice? in
            let d = pairs(String(raw))
            guard let name = d["NAME"], !name.isEmpty,
                  !name.hasPrefix("nbd"), !name.hasPrefix("loop") else { return nil }
            let size = Int64(d["SIZE"] ?? "0") ?? 0
            guard size > 0 else { return nil }
            return BlockDevice(name: name, sizeBytes: size, type: d["TYPE"] ?? "",
                               mount: d["MOUNTPOINT"] ?? "", fstype: d["FSTYPE"] ?? "")
        }
    }

    /// Lê pares `CHAVE="valor"` de uma linha do lsblk `-P`.
    static func pairs(_ line: String) -> [String: String] {
        var dict: [String: String] = [:]
        guard let re = try? NSRegularExpression(pattern: "(\\w+)=\"([^\"]*)\"") else { return dict }
        let ns = line as NSString
        for m in re.matches(in: line, range: NSRange(location: 0, length: ns.length)) where m.numberOfRanges == 3 {
            dict[ns.substring(with: m.range(at: 1))] = ns.substring(with: m.range(at: 2))
        }
        return dict
    }

    static func parseDf(_ output: String) -> [FSUsage] {
        let pseudo: Set<String> = ["tmpfs", "devtmpfs", "overlay", "squashfs", "efivarfs", "ramfs"]
        var result: [FSUsage] = []
        var seen: Set<String> = []
        for raw in output.split(whereSeparator: \.isNewline) {
            let line = String(raw)
            if line.hasPrefix("Filesystem") { continue }
            let f = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard f.count >= 7 else { continue }
            let source = f[0], fstype = f[1]
            guard !pseudo.contains(fstype), !seen.contains(source) else { continue }
            guard let size = Int64(f[2]), let used = Int64(f[3]) else { continue }
            seen.insert(source)
            let mount = f[6...].joined(separator: " ")
            result.append(FSUsage(source: source, fstype: fstype, sizeBytes: size, usedBytes: used, mount: mount))
        }
        return result.sorted { $0.usedFraction > $1.usedFraction }
    }

    static func summarizeRaid(_ output: String) -> String {
        let parts = output.components(separatedBy: "---ZFS---")
        let md = parts.first ?? ""
        let zfs = parts.count > 1 ? parts[1] : ""
        var lines: [String] = []
        if md.range(of: "md[0-9]+\\s*:", options: .regularExpression) != nil {
            lines.append("mdadm: array(s) RAID detectado(s).")
        } else {
            lines.append("mdadm: nenhum array RAID.")
        }
        if zfs.contains("no-zfs") {
            lines.append("ZFS: não instalado.")
        } else if zfs.contains("pool:") {
            lines.append("ZFS: pool(s) detectado(s).")
        } else {
            lines.append("ZFS: nenhum pool.")
        }
        return lines.joined(separator: "\n")
    }
}
