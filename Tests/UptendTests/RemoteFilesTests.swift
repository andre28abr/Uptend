import Testing
@testable import Uptend

/// Parser de arquivos (find -printf) — fixture real do uptend-lab.
struct RemoteFilesTests {

    @Test func parsesAndSortsListing() {
        let out = """
        f\t220\t2026-02-13 09:16\t.bash_logout
        d\t30\t2026-07-15 10:16\t.ssh
        f\t3771\t2026-02-13 09:16\t.bashrc
        d\t40\t2026-07-15 10:18\t.cache
        """
        let items = RemoteFiles.parseListing(out)
        #expect(items.count == 4)
        // pastas primeiro, depois arquivos — cada grupo alfabético
        #expect(items.map(\.name) == [".cache", ".ssh", ".bash_logout", ".bashrc"])
        #expect(items[0].isDir)
        #expect(items[2].isDir == false)
        #expect(items[2].sizeBytes == 220)
    }

    @Test func nameWithSpacesSurvives() {
        // nome com espaço fica intacto (split por TAB, name é o último campo)
        let items = RemoteFiles.parseListing("f\t10\t2026-01-01 00:00\tmeu arquivo.txt")
        #expect(items.first?.name == "meu arquivo.txt")
    }

    @Test func parentPath() {
        #expect(RemoteFiles.parent(of: "/home/andre/docs") == "/home/andre")
        #expect(RemoteFiles.parent(of: "/home") == "/")
        #expect(RemoteFiles.parent(of: "/") == "/")
        #expect(RemoteFiles.parent(of: "/home/andre/") == "/home")
    }

    @Test func validatesRemotePaths() {
        #expect(InputValidator.isSafeRemotePath("/home/andre/meu arquivo.txt"))
        #expect(InputValidator.isSafeRemotePath("relativo") == false)          // não absoluto
        #expect(InputValidator.isSafeRemotePath("/etc/$(whoami)") == false)     // injeção
        #expect(InputValidator.isSafeRemotePath("/a; rm -rf /") == false)
        #expect(InputValidator.isSafeRemotePath("/glob/*") == false)           // glob
    }
}
