import Testing
@testable import Uptend

/// Testes do parser de `git status --porcelain=v2 --branch`.
struct GitTests {

    @Test func cleanRepoSynced() {
        let output = """
        # branch.oid abc123
        # branch.head main
        # branch.upstream origin/main
        # branch.ab +0 -0
        """
        let s = GitService.parseStatus(output)
        #expect(s.branch == "main")
        #expect(s.ahead == 0)
        #expect(s.behind == 0)
        #expect(s.dirty == false)
    }

    @Test func aheadAndBehind() {
        let output = """
        # branch.head develop
        # branch.ab +2 -3
        """
        let s = GitService.parseStatus(output)
        #expect(s.branch == "develop")
        #expect(s.ahead == 2)
        #expect(s.behind == 3)
        #expect(s.dirty == false)
    }

    @Test func dirtyWorkingTree() {
        let output = """
        # branch.head main
        # branch.ab +0 -0
        1 .M N... 100644 100644 100644 aaa bbb src/file.swift
        ? untracked.txt
        """
        let s = GitService.parseStatus(output)
        #expect(s.dirty == true)
    }

    @Test func detachedHead() {
        let output = """
        # branch.oid abc123
        # branch.head (detached)
        """
        let s = GitService.parseStatus(output)
        #expect(s.branch == "(detached)")
        #expect(s.dirty == false)
    }

    @Test func repoStatusMapping() {
        func info(ahead: Int, behind: Int, dirty: Bool) -> GitRepoInfo {
            GitRepoInfo(path: "/x", name: "x", isRepo: true, branch: "main", ahead: ahead, behind: behind, dirty: dirty, error: nil)
        }
        #expect(info(ahead: 0, behind: 0, dirty: false).status == .synced)
        #expect(info(ahead: 2, behind: 0, dirty: false).status == .ahead(2))
        #expect(info(ahead: 0, behind: 3, dirty: false).status == .behind(3))
        #expect(info(ahead: 1, behind: 1, dirty: true).status == .dirty)  // dirty tem prioridade
    }
}
