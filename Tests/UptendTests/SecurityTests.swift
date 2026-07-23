import Testing
@testable import Uptend

/// Testes de segurança: garantem que a validação de tokens barra entradas perigosas
/// e que o catálogo de apps só contém tokens válidos.
struct SecurityTests {

    @Test func validTokensPass() {
        let valid = ["node", "python@3.12", "visual-studio-code", "gpg-suite", "1password", "ripgrep"]
        for token in valid {
            #expect(InputValidator.isValidBrewToken(token), "\(token) deveria ser válido")
        }
    }

    @Test func maliciousTokensAreRejected() {
        let malicious = [
            "node; rm -rf /",      // separador de comando
            "foo && curl evil",    // encadeamento
            "$(whoami)",           // substituição de comando
            "`id`",                // backticks
            "foo | sh",            // pipe
            "foo bar",             // espaço
            "../../etc/passwd",    // path traversal
            "",                    // vazio
            "foo\nbar",            // newline
            "--force",             // option injection
            "-rf",                 // option injection
        ]
        for token in malicious {
            #expect(!InputValidator.isValidBrewToken(token), "\(token) deveria ser rejeitado")
        }
    }

    @Test func optionInjectionIsBlocked() {
        // Valores começando com "-" viram opção em vez de operando — devem ser barrados.
        #expect(!InputValidator.isValidHost("-oProxyCommand"))
        #expect(!InputValidator.isValidFileName("-rf"))
        #expect(!InputValidator.isSafeArgument("--privileged"))
        #expect(!InputValidator.isValidSearchQuery("-x"))
    }

    @Test func bundleIDValidation() {
        #expect(InputValidator.isValidBundleID("com.apple.finder"))
        #expect(InputValidator.isValidBundleID("com.andresouza.uptend"))
        #expect(!InputValidator.isValidBundleID("../../Documents"))  // path traversal
        #expect(!InputValidator.isValidBundleID(".."))
        #expect(!InputValidator.isValidBundleID("a/b"))
        #expect(!InputValidator.isValidBundleID("com..evil"))
        #expect(!InputValidator.isValidBundleID(""))
    }

    @Test func databaseNameValidation() {
        #expect(InputValidator.isValidDatabaseName("loja"))
        #expect(InputValidator.isValidDatabaseName("app_prod-2026"))
        #expect(!InputValidator.isValidDatabaseName("x'; DROP DATABASE y; --"))
        #expect(!InputValidator.isValidDatabaseName("nome com espaço"))
        #expect(!InputValidator.isValidDatabaseName("`crase`"))
        #expect(!InputValidator.isValidDatabaseName(""))       // vazio é tratado à parte no isValid
    }

    @Test func jumpHostValidation() {
        #expect(InputValidator.isValidJumpHost("bastion.empresa.com"))
        #expect(InputValidator.isValidJumpHost("user@bastion:22"))
        #expect(!InputValidator.isValidJumpHost("bastion; rm -rf ~"))
        #expect(!InputValidator.isValidJumpHost("$(whoami)"))
        #expect(!InputValidator.isValidJumpHost("-oProxyCommand=evil"))   // não começa por '-'
        #expect(!InputValidator.isValidJumpHost(""))
    }

    @Test func catalogTokensAreAllValid() {
        for (_, apps) in MockData.apps {
            for app in apps {
                #expect(!app.token.isEmpty, "\(app.name) sem token")
                #expect(InputValidator.isValidBrewToken(app.token), "token inválido no catálogo: \(app.token)")
            }
        }
    }

    @Test func catalogTokensUniquePerCategory() {
        for (category, apps) in MockData.apps {
            let tokens = apps.map(\.token)
            #expect(tokens.count == Set(tokens).count, "tokens duplicados na categoria \(category)")
        }
    }

    @Test func searchQueryValidation() {
        #expect(InputValidator.isValidSearchQuery("ffmpeg"))
        #expect(InputValidator.isValidSearchQuery("visual studio"))
        #expect(!InputValidator.isValidSearchQuery(""))
        #expect(!InputValidator.isValidSearchQuery("foo; rm -rf /"))
        #expect(!InputValidator.isValidSearchQuery("$(id)"))
        #expect(!InputValidator.isValidSearchQuery(String(repeating: "a", count: 65)))
    }

    @Test func appleScriptTextSafety() {
        #expect(InputValidator.isSafeAppleScriptText("Spotify"))
        #expect(InputValidator.isSafeAppleScriptText("Google Chrome"))
        #expect(!InputValidator.isSafeAppleScriptText("\" & do shell script \"rm -rf ~\""))  // tenta escapar do literal
        #expect(!InputValidator.isSafeAppleScriptText("foo\\bar"))
        #expect(!InputValidator.isSafeAppleScriptText("foo\nbar"))
        #expect(!InputValidator.isSafeAppleScriptText(""))
    }

    @Test func containerNameValidation() {
        // Nome de container Docker (--name): alfanumérico + _ . -, sem / : @ nem "..".
        for ok in ["meu-site", "uptime-kuma", "app_1", "n8n", "db.prod"] {
            #expect(InputValidator.isValidContainerName(ok), "\(ok) deveria ser válido")
        }
        for bad in ["-rf", "a/b", "a:b", "user@host", "..", "app..v2",
                    "foo bar", "foo;rm", "$(id)", "", "café"] {
            #expect(!InputValidator.isValidContainerName(bad), "\(bad) deveria ser rejeitado")
        }
    }

    @Test func serviceNameValidation() {
        // Unidades systemd: aceita @ . _ : - mas nunca "..", espaço ou começar com "-".
        for ok in ["docker.service", "ssh", "getty@tty1.service", "systemd-logind"] {
            #expect(InputValidator.isValidServiceName(ok), "\(ok) deveria ser válido")
        }
        for bad in ["-x", "../evil", "a..b", "foo bar", "foo;rm", ""] {
            #expect(!InputValidator.isValidServiceName(bad), "\(bad) deveria ser rejeitado")
        }
    }

    @Test func fileNameBlocksTraversal() {
        #expect(InputValidator.isValidFileName("uptend_lab_ed25519"))
        #expect(InputValidator.isValidFileName("id_ed25519.pub"))
        #expect(!InputValidator.isValidFileName(".."))
        #expect(!InputValidator.isValidFileName("."))
        #expect(!InputValidator.isValidFileName("a..b"))
        #expect(!InputValidator.isValidFileName("-rf"))
        #expect(!InputValidator.isValidFileName("a/b"))
    }

    @Test func brewTokenBlocksDotDot() {
        // Reforço de defesa em profundidade: "a..b" tem caracteres válidos mas ".." é traversal.
        #expect(!InputValidator.isValidBrewToken("a..b"))
        #expect(!InputValidator.isValidBrewToken("..foo"))
        #expect(InputValidator.isValidBrewToken("python@3.12"))
    }

    @Test func repoFullNameValidation() {
        #expect(InputValidator.isValidRepoFullName("andre28abr/peapod"))
        #expect(InputValidator.isValidRepoFullName("wazuh/wazuh-docker"))
        #expect(!InputValidator.isValidRepoFullName("../../etc"))
        #expect(!InputValidator.isValidRepoFullName("a/b/c"))
        #expect(!InputValidator.isValidRepoFullName("owner..x/repo"))
        #expect(!InputValidator.isValidRepoFullName("-owner/repo"))
        #expect(!InputValidator.isValidRepoFullName("owner/"))
    }
}
