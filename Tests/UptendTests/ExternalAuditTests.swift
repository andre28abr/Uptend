import Testing
import Foundation
@testable import UptendCore

/// Auditoria Externa (schema v1): parser, validação de versão e pontuação.
/// Inclui a decodificação de uma FIXTURE REAL gerada pelo audit-collector.sh no
/// laboratório (uptend-lab), garantindo que schema ↔ coletor batem de verdade.
struct ExternalAuditTests {

    // MARK: Parser + versão

    private let minimal = """
    {
      "schema_version": 1,
      "collector": {"name": "uptend-audit", "version": "1.0.0", "mode": "admin"},
      "collected_at": "2026-07-17T03:00:00Z",
      "host": {"hostname": "srv1", "machine_id": "abc"},
      "machine": {"virtual": false, "vendor": "Dell", "model": "R640", "cpu_model": "Xeon",
                  "cpu_cores": 16, "ram_bytes": 68719476736, "bios_vendor": "Dell",
                  "bios_version": "2.1", "bios_date": "2020-01-01"},
      "os": {"distro": "ubuntu", "version": "20.04", "pretty": "Ubuntu 20.04",
             "kernel": "5.4.0", "uptime_seconds": 1000, "eol_date": "2025-05-29",
             "updates_total": 5, "updates_security": 2},
      "disks": [{"name": "sda", "model": "Samsung", "size_bytes": 512000000000,
                 "rotational": false, "smart_available": true, "smart_healthy": true,
                 "power_on_hours": 12000, "reallocated_sectors": 0}],
      "findings": [
        {"id": "ssh-root", "title": "Root SSH", "severity": "high", "category": "SSH",
         "cis": "5.2.8", "evidence": "PermitRootLogin yes", "recommendation": "desative",
         "business_impact": "porta de entrada"},
        {"id": "os-eol", "title": "SO fora de suporte", "severity": "critical",
         "category": "Sistema operacional", "cis": null, "evidence": "EOL",
         "recommendation": "migre", "business_impact": "sem patches"},
        {"id": "fw-ok", "title": "Firewall ativo", "severity": "ok", "category": "Rede",
         "cis": null, "evidence": null, "recommendation": null, "business_impact": null}
      ],
      "lynis": {"available": true, "hardening_index": 65, "warnings": ["w1"], "suggestions": ["s1","s2"]}
    }
    """

    @Test func parsesMinimalDocument() throws {
        let audit = try ExternalAuditParser.parse(Data(minimal.utf8))
        #expect(audit.schemaVersion == 1)
        #expect(audit.collector.mode == "admin")
        #expect(audit.host.hostname == "srv1")
        // Regressão A1: machine_id (snake_case) DEVE decodificar. A propriedade se
        // chamava `machineID`, que .convertFromSnakeCase (→ machineId) nunca casava,
        // deixando o identificador estável do host sempre nil.
        #expect(audit.host.machineId == "abc")
        #expect(audit.machine?.ramBytes == 68719476736)
        #expect(audit.os?.eolDate == "2025-05-29")
        #expect(audit.disks.count == 1)
        #expect(audit.disks.first?.smartHealthy == true)
        #expect(audit.findings.count == 3)
        #expect(audit.lynis?.hardeningIndex == 65)
        #expect(audit.lynis?.suggestions.count == 2)
    }

    @Test func rejectsNewerSchemaVersion() {
        let future = minimal.replacingOccurrences(of: "\"schema_version\": 1", with: "\"schema_version\": 999")
        #expect(throws: ExternalAuditParser.ParseError.self) {
            try ExternalAuditParser.parse(Data(future.utf8))
        }
    }

    @Test func rejectsGarbage() {
        #expect(throws: ExternalAuditParser.ParseError.self) {
            try ExternalAuditParser.parse(Data("não é json".utf8))
        }
    }

    // MARK: Severidade

    @Test func severityOrderingAndWeight() {
        #expect(AuditSeverity.ok < .low)
        #expect(AuditSeverity.high < .critical)
        #expect(max(AuditSeverity.low, .high) == .high)
        #expect(AuditSeverity.critical.deduction == 20)
        #expect(AuditSeverity.ok.deduction == 0)
    }

    // MARK: Pontuação / semáforo / top riscos

    @Test func scoringComputesScoreCategoriesAndTopRisks() throws {
        let audit = try ExternalAuditParser.parse(Data(minimal.utf8))
        let s = AuditScoring.evaluate(audit)
        // 100 − (high 10 + critical 20 + ok 0) = 70
        #expect(s.score == 70)
        #expect(s.light == .yellow)                 // 50…79
        #expect(s.counts[.high] == 1)
        #expect(s.counts[.critical] == 1)
        #expect(s.counts[.ok] == 1)

        // Semáforo por categoria (alfabético): Rede verde, SSH vermelho, SO vermelho.
        let rede = s.categories.first { $0.category == "Rede" }
        #expect(rede?.light == .green)
        let ssh = s.categories.first { $0.category == "SSH" }
        #expect(ssh?.light == .red)

        // Top riscos: crítico antes de alto; "ok" nunca entra.
        #expect(s.topRisks.first?.severity == .critical)
        #expect(s.topRisks.allSatisfy { $0.severity > .ok })
        #expect(s.topRisks.count == 2)
    }

    @Test func scoreFloorsAtZero() throws {
        // Muitos críticos derrubam a nota, mas nunca abaixo de 0.
        var doc = minimal
        let many = (0..<10).map {
            "{\"id\":\"c\($0)\",\"title\":\"t\",\"severity\":\"critical\",\"category\":\"X\",\"cis\":null,\"evidence\":null,\"recommendation\":null,\"business_impact\":null}"
        }.joined(separator: ",")
        doc = doc.replacingOccurrences(of: "\"findings\": [", with: "\"findings\": [\(many),")
        let s = AuditScoring.evaluate(try ExternalAuditParser.parse(Data(doc.utf8)))
        #expect(s.score == 0)
        #expect(s.light == .red)
    }

    // MARK: Fixture REAL do laboratório (coletor ↔ schema batem)

    @Test func decodesRealLabFixture() throws {
        guard let url = Bundle.module.url(forResource: "lab-audit", withExtension: "json", subdirectory: "Fixtures") else {
            Issue.record("fixture lab-audit.json não encontrada no bundle de testes")
            return
        }
        let audit = try ExternalAuditParser.parse(Data(contentsOf: url))
        #expect(audit.schemaVersion == 1)
        #expect(audit.collector.name == "uptend-audit")
        #expect(audit.collector.mode == "admin")
        #expect(audit.host.hostname == "uptend-lab")
        #expect(audit.machine?.virtual == true)
        #expect(audit.disks.isEmpty == false)          // discos reais (vda/vdb/vdc), sem zram/nbd
        #expect(audit.findings.isEmpty == false)

        // A pontuação roda sem crashar e produz um semáforo válido.
        let s = AuditScoring.evaluate(audit)
        #expect((0...100).contains(s.score))
        #expect([.green, .yellow, .red].contains(s.light))
        // Campos expandidos (pente-fino) presentes: recursos e usuários.
        #expect(audit.resources?.diskRootPercent != nil)
        #expect(audit.users?.loginUsers != nil)
        // Achados de hardening SSH sempre presentes (config lida em modo admin).
        #expect(audit.findings.contains { $0.category.contains("SSH") })
    }
}
