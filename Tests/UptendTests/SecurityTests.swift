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
}
