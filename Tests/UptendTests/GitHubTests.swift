import Testing
import Foundation
@testable import Uptend

/// Testes da integração com o GitHub: validadores e decodificação da API.
struct GitHubTests {

    // MARK: Validador de token

    @Test func acceptsValidTokens() {
        #expect(InputValidator.isValidGitHubToken("ghp_" + String(repeating: "a", count: 36)))
        #expect(InputValidator.isValidGitHubToken("github_pat_" + String(repeating: "9", count: 30)))
    }

    @Test func rejectsBadTokens() {
        #expect(!InputValidator.isValidGitHubToken(""))
        #expect(!InputValidator.isValidGitHubToken("curto"))                       // < 20
        #expect(!InputValidator.isValidGitHubToken("ghp with space aaaaaaaaaaaa")) // espaço
        #expect(!InputValidator.isValidGitHubToken("ghp_\"; rm -rf ~ aaaaaaaaaa"))  // metacaracteres
        #expect(!InputValidator.isValidGitHubToken(String(repeating: "a", count: 300))) // longo demais
    }

    // MARK: Validador de owner/repo

    @Test func acceptsValidRepoFullName() {
        #expect(InputValidator.isValidRepoFullName("andresouza/uptend"))
        #expect(InputValidator.isValidRepoFullName("Org-1/meu.repo_2"))
    }

    @Test func rejectsRepoTraversal() {
        #expect(!InputValidator.isValidRepoFullName("../etc/passwd"))
        #expect(!InputValidator.isValidRepoFullName("owner/../secret"))
        #expect(!InputValidator.isValidRepoFullName("sembarra"))
        #expect(!InputValidator.isValidRepoFullName("a/b/c"))
    }

    // MARK: Mensagem de commit

    @Test func commitMessageSanity() {
        #expect(InputValidator.isSafeCommitMessage("Ajusta layout do dashboard"))
        #expect(InputValidator.isSafeCommitMessage("Título\n\nCorpo com detalhes")) // multilinha ok
        #expect(!InputValidator.isSafeCommitMessage(""))
        #expect(!InputValidator.isSafeCommitMessage("   \n  "))          // só espaços
        #expect(!InputValidator.isSafeCommitMessage("nul\0byte"))        // NUL
        #expect(!InputValidator.isSafeCommitMessage(String(repeating: "x", count: 2001)))
    }

    // MARK: Decodificação da API do GitHub

    @Test func decodesRepoIncludingPrivate() throws {
        let json = """
        [
          {
            "name": "uptend",
            "full_name": "andresouza/uptend",
            "private": true,
            "description": "Canivete suíço do Mac",
            "html_url": "https://github.com/andresouza/uptend",
            "clone_url": "https://github.com/andresouza/uptend.git",
            "default_branch": "main",
            "updated_at": "2026-07-13T10:00:00Z",
            "fork": false
          }
        ]
        """
        let repos = try JSONDecoder().decode([GitHubRepo].self, from: Data(json.utf8))
        #expect(repos.count == 1)
        let r = repos[0]
        #expect(r.name == "uptend")
        #expect(r.fullName == "andresouza/uptend")
        #expect(r.isPrivate == true)
        #expect(r.cloneURL == "https://github.com/andresouza/uptend.git")
        #expect(r.defaultBranch == "main")
        #expect(r.id == "andresouza/uptend")
    }

    @Test func decodesRepoWithNullDescription() throws {
        let json = """
        [{"name":"x","full_name":"a/x","private":false,"description":null,
          "html_url":"https://github.com/a/x","clone_url":"https://github.com/a/x.git",
          "default_branch":"master","updated_at":null,"fork":true}]
        """
        let repos = try JSONDecoder().decode([GitHubRepo].self, from: Data(json.utf8))
        #expect(repos[0].description == nil)
        #expect(repos[0].fork == true)
        #expect(repos[0].isPrivate == false)
    }

    @Test func decodesAccount() throws {
        let json = """
        {"login":"andresouza","name":"André","avatar_url":"https://x/y.png",
         "html_url":"https://github.com/andresouza"}
        """
        let acc = try JSONDecoder().decode(GitHubAccount.self, from: Data(json.utf8))
        #expect(acc.login == "andresouza")
        #expect(acc.name == "André")
    }

    // MARK: Erros amigáveis

    @Test func errorMessagesArePortuguese() {
        #expect(GitHubError.unauthorized.message.contains("401"))
        #expect(GitHubError.forbidden.message.contains("403"))
        #expect(GitHubError.status(500).message.contains("500"))
        #expect(GitHubError.other("boom").message == "boom")
    }
}
