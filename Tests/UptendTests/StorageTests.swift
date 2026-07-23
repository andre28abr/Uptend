import Testing
import Foundation
@testable import Uptend

struct StorageTests {

    @Test func findsDuplicatesByContent() throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("uptend-dup-\(UUID().uuidString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let same = Data("conteúdo idêntico".utf8)
        try same.write(to: dir.appendingPathComponent("a.txt"))
        try same.write(to: dir.appendingPathComponent("copia.txt"))          // duplicado de a.txt
        try Data("outro conteúdo".utf8).write(to: dir.appendingPathComponent("c.txt"))

        let groups = StorageService.scanDuplicates(path: dir.path)
        #expect(groups.count == 1)
        #expect(groups.first?.paths.count == 2)
        #expect(groups.first?.wastedBytes == Int64(same.count))   // 1 cópia extra desperdiçada
    }

    @Test func sameSizeDifferentContentIsNotDuplicate() throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("uptend-dup-\(UUID().uuidString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }
        // Mesmo tamanho (5 bytes), conteúdo diferente → NÃO é duplicado.
        try Data("aaaaa".utf8).write(to: dir.appendingPathComponent("x.txt"))
        try Data("bbbbb".utf8).write(to: dir.appendingPathComponent("y.txt"))
        #expect(StorageService.scanDuplicates(path: dir.path).isEmpty)
    }

    @Test func wastedBytesCalculation() {
        let g = DuplicateGroup(key: "h", sizeBytes: 1000, paths: ["a", "b", "c"])
        #expect(g.wastedBytes == 2000)   // 3 cópias → 2 desperdiçadas
    }
}
