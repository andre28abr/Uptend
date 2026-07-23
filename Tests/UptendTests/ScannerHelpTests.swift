import Testing
import UptendCore
@testable import Uptend

struct ScannerHelpTests {

    @Test func translatesGitleaksRuleTypes() {
        #expect(ScannerHelp.gitleaksRule("aws-access-token") == "Chave de acesso da AWS")
        #expect(ScannerHelp.gitleaksRule("github-pat") == "Token do GitHub")
        #expect(ScannerHelp.gitleaksRule("private-key") == "Chave privada (SSH/PGP/TLS)")
        #expect(ScannerHelp.gitleaksRule("openai-api-key") == "Chave da OpenAI")
        #expect(ScannerHelp.gitleaksRule("algo-desconhecido") == "Possível segredo")
    }

    @Test func mapsLynisCategoryFromTestID() {
        #expect(ScannerHelp.lynisCategory("SSH-7408") == "Servidor/acesso SSH")
        #expect(ScannerHelp.lynisCategory("AUTH-9286") == "Autenticação e senhas")
        #expect(ScannerHelp.lynisCategory("FIRE-4513") == "Firewall")
        #expect(ScannerHelp.lynisCategory("XYZ-0000") == "Recomendação de segurança")
    }

    @Test func osvActionHintMentionsPackage() {
        #expect(ScannerHelp.osvActionHint(package: "lodash").contains("lodash"))
    }
}
