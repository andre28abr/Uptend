import Testing
@testable import Uptend

/// Parser de snapshots do restic — fixture real (uptend-lab).
struct RemoteBackupTests {

    @Test func parsesSnapshotsNewestFirst() {
        let json = """
        [
          {"id":"aaaa1111bbbb","short_id":"aaaa1111","time":"2026-07-16T20:30:57.5-03:00","paths":["/home/andresouza"],"summary":{"total_bytes_processed":4890}},
          {"id":"cccc2222dddd","short_id":"cccc2222","time":"2026-07-16T21:00:00.0-03:00","paths":["/etc"],"summary":{"total_bytes_processed":102400}}
        ]
        """
        let snaps = RemoteBackup.parseSnapshots(json)
        #expect(snaps.count == 2)
        // mais recentes primeiro (a lista do restic vem cronológica → invertemos)
        #expect(snaps.first?.id == "cccc2222")
        #expect(snaps.first?.paths == ["/etc"])
        #expect(snaps.last?.id == "aaaa1111")
        #expect(snaps.last?.time == "2026-07-16 20:30")     // T→espaço, prefixo 16
    }

    @Test func handlesEmptyAndGarbage() {
        #expect(RemoteBackup.parseSnapshots("[]").isEmpty)
        #expect(RemoteBackup.parseSnapshots("lixo").isEmpty)
    }

    @Test func backupAndRestoreArgsUseRepoAndFolder() {
        let b = RemoteBackup.backupArgs(folder: "/home/andre")
        #expect(b.last!.contains("backup \"/home/andre\""))
        #expect(b.last!.contains(RemoteBackup.repo))
        let r = RemoteBackup.restoreArgs(id: "aaaa1111", target: "/tmp/x")
        #expect(r.last!.contains("restore aaaa1111"))
        #expect(r.last!.contains("--target \"/tmp/x\""))
    }

    @Test func backupAndRestoreArgsRejectUnsafeInput() {
        // Revalidação interna: caminho relativo/perigoso e id não-hex abortam.
        let b = RemoteBackup.backupArgs(folder: "/home/andre; rm -rf /")
        #expect(b.last!.contains("inválido"))
        #expect(b.last!.contains("restic") == false)

        let bRel = RemoteBackup.backupArgs(folder: "relativo")
        #expect(bRel.last!.contains("inválido"))

        let rBadId = RemoteBackup.restoreArgs(id: "aaaa; id", target: "/tmp/x")
        #expect(rBadId.last!.contains("inválido"))
        #expect(rBadId.last!.contains("restore ") == false)

        let rBadPath = RemoteBackup.restoreArgs(id: "aaaa1111", target: "/tmp/x; rm -rf /")
        #expect(rBadPath.last!.contains("inválido"))
    }
}
