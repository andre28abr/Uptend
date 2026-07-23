import Testing
import UptendCore
import Foundation
@testable import Uptend

struct SecurityScannersTests {

    // MARK: Exposição (netstat)

    @Test func parsesListeningPortsAndScope() {
        let sample = """
        Active Internet connections (including servers)
        Proto Recv-Q Send-Q  Local Address          Foreign Address        (state)
        tcp4       0      0  *.22                   *.*                    LISTEN
        tcp4       0      0  127.0.0.1.5432         *.*                    LISTEN
        tcp6       0      0  ::1.631                *.*                    LISTEN
        tcp4       0      0  *.5900                 *.*                    LISTEN
        tcp4       0      0  192.168.0.5.51000      1.2.3.4.443            ESTABLISHED
        """
        let ports = ExposureService.parseListening(sample)
        #expect(ports.contains(ListeningPort(port: 22, exposed: true)))
        #expect(ports.contains(ListeningPort(port: 5432, exposed: false)))
        #expect(ports.contains(ListeningPort(port: 631, exposed: false)))
        #expect(ports.contains(ListeningPort(port: 5900, exposed: true)))
        // Conexão ESTABLISHED não é porta em escuta.
        #expect(!ports.contains { $0.port == 51000 })
    }

    @Test func serviceChecksFlagExposedServices() {
        let ports = [ListeningPort(port: 22, exposed: true),
                     ListeningPort(port: 5900, exposed: false)]
        let checks = ExposureService.serviceChecks(from: ports)
        let ssh = checks.first { $0.name == "Login remoto (SSH)" }
        let screen = checks.first { $0.name == "Compartilhamento de Tela" }
        let files = checks.first { $0.name.contains("SMB") }
        #expect(ssh?.status == .warning)                 // exposto → alerta
        #expect(ssh?.detail.contains("exposto") == true)
        #expect(screen?.status == .ok)                   // só local → ok
        #expect(files?.detail == "Desligado")            // nada ouvindo → ok
        #expect(files?.status == .ok)
    }

    // MARK: gitleaks

    @Test func parsesGitleaksFindings() {
        let json = """
        [{"Description":"AWS Access Key","StartLine":10,"File":"src/config.js",
          "RuleID":"aws-access-token","Secret":"REDACTED"}]
        """
        let findings = SecretScanService.parseFindings(Data(json.utf8))
        #expect(findings.count == 1)
        #expect(findings[0].file == "src/config.js")
        #expect(findings[0].startLine == 10)
        #expect(findings[0].ruleID == "aws-access-token")
        #expect(findings[0].id == "src/config.js:10:aws-access-token")
    }

    @Test func gitleaksEmptyReportMeansClean() {
        #expect(SecretScanService.parseFindings(Data("[]".utf8)).isEmpty)
        #expect(SecretScanService.parseFindings(Data("lixo".utf8)).isEmpty)
    }

    // MARK: Lynis

    @Test func parsesLynisReport() {
        let report = """
        # Lynis report
        hardening_index=67
        warning[]=SSH-7408|Consider hardening SSH configuration|-|
        suggestion[]=BOOT-5264|Check PTS module configuration|text|
        suggestion[]=AUTH-9286|Configure password aging|-|
        """
        let parsed = AuditService.parseReport(report)
        #expect(parsed.index == 67)
        #expect(parsed.warnings.map(\.text) == ["Consider hardening SSH configuration"])
        #expect(parsed.warnings.first?.testID == "SSH-7408")
        #expect(parsed.warnings.first?.category == "Servidor/acesso SSH")   // categoria em PT
        #expect(parsed.suggestions.count == 2)
        #expect(parsed.suggestions.first?.text == "Check PTS module configuration")
    }

    @Test func lynisReportWithoutIndex() {
        let parsed = AuditService.parseReport("# vazio\nfoo=bar")
        #expect(parsed.index == nil)
        #expect(parsed.warnings.isEmpty)
    }

    // MARK: osv-scanner

    @Test func parsesOsvVulns() {
        let json = """
        {"results":[{"packages":[
          {"package":{"name":"lodash","version":"4.17.11","ecosystem":"npm"},
           "vulnerabilities":[{"id":"GHSA-jf85-cpcp-j695","summary":"Prototype pollution"}]}
        ]}]}
        """
        let vulns = DepsScanService.parseVulns(Data(json.utf8))
        #expect(vulns.count == 1)
        #expect(vulns[0].package == "lodash")
        #expect(vulns[0].ecosystem == "npm")
        #expect(vulns[0].vulnID == "GHSA-jf85-cpcp-j695")
        #expect(vulns[0].summary == "Prototype pollution")
    }

    @Test func osvNoResultsMeansClean() {
        #expect(DepsScanService.parseVulns(Data("{\"results\":[]}".utf8)).isEmpty)
        #expect(DepsScanService.parseVulns(Data("{}".utf8)).isEmpty)
    }
}
