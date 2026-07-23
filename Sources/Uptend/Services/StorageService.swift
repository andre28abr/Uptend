import Foundation
import CryptoKit

struct StorageFolder: Identifiable, Sendable, Hashable {
    let name: String; let bytes: Int64
    var id: String { name }
    var sizeLabel: String { ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) }
}

struct StorageFile: Identifiable, Sendable, Hashable {
    let path: String; let bytes: Int64
    var id: String { path }
    var sizeLabel: String { ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) }
}

/// Um grupo de arquivos idênticos (mesmo conteúdo).
struct DuplicateGroup: Identifiable, Sendable, Hashable {
    let key: String            // hash
    let sizeBytes: Int64
    var paths: [String]
    var id: String { key }
    var wastedBytes: Int64 { sizeBytes * Int64(max(0, paths.count - 1)) }
    var sizeLabel: String { ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file) }
    var wastedLabel: String { ByteCountFormatter.string(fromByteCount: wastedBytes, countStyle: .file) }
}

/// Uso do disco (pastas, volumes, maiores arquivos) e caça-duplicados por conteúdo.
@MainActor
final class StorageService: ObservableObject {
    // Uso
    @Published var folders: [StorageFolder] = []
    @Published var volumes: [String] = []
    @Published var largest: [StorageFile] = []
    @Published var loadingUsage = false
    // Duplicados
    @Published var duplicates: [DuplicateGroup] = []
    @Published var scanningDupes = false
    @Published var dupesScannedPath: String?
    @Published var dupesDidScan = false
    @Published var lastError: String?

    // MARK: Uso do disco

    func refreshUsage() async {
        loadingUsage = true
        defer { loadingUsage = false }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let names = ["Downloads", "Desktop", "Documents", "Pictures", "Movies", "Music"]
        async let foldersC = Self.folderSizes(home: home, names: names)
        async let dfC = Shell.capture("/bin/df", ["-Hl"])
        async let largeC = Self.largestFiles(home: home)
        folders = await foldersC
        volumes = ReportBuilder.parseVolumes((await dfC).stdout)
        largest = await largeC
    }

    private static func folderSizes(home: String, names: [String]) async -> [StorageFolder] {
        await withTaskGroup(of: StorageFolder?.self) { group in
            for name in names {
                group.addTask {
                    let path = "\(home)/\(name)"
                    guard FileManager.default.fileExists(atPath: path) else { return nil }
                    let r = await Shell.capture("/usr/bin/du", ["-sk", "-d", "0", path])
                    guard let first = r.stdout.split(whereSeparator: { $0 == "\t" || $0 == "\n" }).first,
                          let kb = Int64(first.trimmingCharacters(in: .whitespaces)) else { return nil }
                    return StorageFolder(name: name, bytes: kb * 1024)
                }
            }
            var out: [StorageFolder] = []
            for await f in group { if let f { out.append(f) } }
            return out.sorted { $0.bytes > $1.bytes }
        }
    }

    private static func largestFiles(home: String) async -> [StorageFile] {
        let r = await Shell.capture("/usr/bin/mdfind", ["-onlyin", home, "kMDItemFSSize > 524288000"])
        let paths = r.stdout.split(whereSeparator: \.isNewline).prefix(200).map(String.init)
        var files: [StorageFile] = []
        for path in paths {
            if let size = (try? FileManager.default.attributesOfItem(atPath: path))?[.size] as? NSNumber {
                files.append(StorageFile(path: path, bytes: size.int64Value))
            }
        }
        return Array(files.sorted { $0.bytes > $1.bytes }.prefix(15))
    }

    // MARK: Duplicados

    func findDuplicates(in path: String) async {
        guard path.hasPrefix("/"), FileManager.default.fileExists(atPath: path) else { lastError = "Pasta inválida."; return }
        scanningDupes = true
        lastError = nil
        duplicates = []
        dupesScannedPath = path
        defer { scanningDupes = false; dupesDidScan = true }
        duplicates = await Task.detached { Self.scanDuplicates(path: path) }.value
    }

    /// Move um arquivo para a Lixeira (reversível).
    func trash(_ path: String) async {
        do {
            try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
            // Remove das listas exibidas.
            for i in duplicates.indices { duplicates[i].paths.removeAll { $0 == path } }
            duplicates.removeAll { $0.paths.count < 2 }
            ActionLog.shared.record("Duplicado para a Lixeira: \(URL(fileURLWithPath: path).lastPathComponent)")
        } catch {
            lastError = "Não foi possível mover para a Lixeira: \(error.localizedDescription)"
        }
    }

    /// Varre a pasta, agrupa por tamanho e confirma duplicados por hash (SHA-256).
    /// Bounded: ignora pastas de ruído e limita a quantidade de arquivos.
    nonisolated static func scanDuplicates(path: String, fileLimit: Int = 40000) -> [DuplicateGroup] {
        let fm = FileManager.default
        let skip: Set<String> = [".git", "node_modules", ".build", "DerivedData", "Pods", ".venv", "venv", "__pycache__", "Library"]
        guard let en = fm.enumerator(at: URL(fileURLWithPath: path),
                                     includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey],
                                     options: []) else { return [] }
        // 1) Agrupa por tamanho.
        var bySize: [Int64: [String]] = [:]
        var count = 0
        for case let url as URL in en {
            if skip.contains(url.lastPathComponent) { en.skipDescendants(); continue }
            guard let vals = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey]),
                  vals.isRegularFile == true, vals.isSymbolicLink != true,
                  let size = vals.fileSize, size > 0 else { continue }
            bySize[Int64(size), default: []].append(url.path)
            count += 1
            if count >= fileLimit { break }
        }
        // 2) Só grupos com >1 arquivo do mesmo tamanho: confirma por hash.
        var groups: [DuplicateGroup] = []
        for (size, paths) in bySize where paths.count > 1 {
            var byHash: [String: [String]] = [:]
            for p in paths { if let h = hashFile(p) { byHash[h, default: []].append(p) } }
            for (hash, dupes) in byHash where dupes.count > 1 {
                groups.append(DuplicateGroup(key: hash, sizeBytes: size, paths: dupes.sorted()))
            }
        }
        return groups.sorted { $0.wastedBytes > $1.wastedBytes }
    }

    /// SHA-256 do conteúdo do arquivo (streaming, sem carregar tudo na memória).
    nonisolated static func hashFile(_ path: String) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: URL(fileURLWithPath: path)) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try? handle.read(upToCount: 1_048_576), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
