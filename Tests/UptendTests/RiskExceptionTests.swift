import Testing
import Foundation
@testable import UptendCore

struct RiskExceptionTests {

    private func f(_ id: String, _ sev: AuditSeverity, _ cat: String = "Segurança / Rede") -> AuditFinding {
        AuditFinding(id: id, title: id, severity: sev, category: cat, recommendation: "faça X")
    }
    private func audit(_ fs: [AuditFinding]) -> ExternalAudit {
        ExternalAudit(schemaVersion: 1, collector: .init(name: "x", version: "1", mode: "admin"),
            collectedAt: "2026-07-21T00:00:00Z", host: .init(hostname: "h", machineId: nil),
            machine: nil, os: nil, disks: [], resources: nil, users: nil, docker: nil, profile: nil,
            findings: fs, lynis: nil)
    }
    private func exc(_ id: String, expires: String) -> RiskException {
        RiskException(findingId: id, title: id, justification: "custo", responsible: "GRC",
                      acceptedAt: "2026-07-01", expiresAt: expires)
    }

    @Test func activeExceptionRemovesFindingFromEffective() {
        let a = audit([f("firewall-inactive", .high), f("kernel-aslr", .low)])
        let exceptions = [exc("firewall-inactive", expires: "2026-12-31")]
        let eff = RiskExceptions.effective(a, exceptions: exceptions, today: "2026-07-21")
        #expect(eff.findings.count == 1)
        #expect(eff.findings.first?.id == "kernel-aslr")
        // sai da matriz/registro
        #expect(RiskRegister.risks(from: eff).contains { $0.findingId == "firewall-inactive" } == false)
    }

    @Test func expiredExceptionDoesNotRemove() {
        let a = audit([f("firewall-inactive", .high)])
        let exceptions = [exc("firewall-inactive", expires: "2026-07-20")]   // ontem
        let eff = RiskExceptions.effective(a, exceptions: exceptions, today: "2026-07-21")
        #expect(eff.findings.count == 1)                                    // volta a contar
        #expect(RiskExceptions.expired(a, exceptions: exceptions, today: "2026-07-21").count == 1)
        #expect(RiskExceptions.accepted(a, exceptions: exceptions, today: "2026-07-21").isEmpty)
    }

    @Test func acceptedListsOnlyExistingActive() {
        let a = audit([f("firewall-inactive", .high)])
        // uma exceção ativa que existe + uma que não corresponde a achado nenhum
        let exceptions = [exc("firewall-inactive", expires: "2026-12-31"), exc("nao-existe", expires: "2026-12-31")]
        let acc = RiskExceptions.accepted(a, exceptions: exceptions, today: "2026-07-21")
        #expect(acc.count == 1)
        #expect(acc.first?.findingId == "firewall-inactive")
    }

    @Test func acceptanceStartDateIsRespected() {
        // B1: aceitação com início FUTURO ainda não vale hoje.
        let e = RiskException(findingId: "x", title: "x", justification: "c", responsible: "GRC",
                              acceptedAt: "2026-08-01", expiresAt: "2026-12-31")
        #expect(e.isActive(asOf: "2026-07-22") == false)   // antes de começar
        #expect(e.isActive(asOf: "2026-08-01") == true)    // no início
        #expect(e.isActive(asOf: "2026-09-01") == true)    // dentro
    }

    @Test func todayWithTimeComponentDoesNotExpireEarly() {
        // B1: um `today` com hora (timestamp ISO) não pode fazer expirar um dia antes.
        let e = RiskException(findingId: "x", title: "x", justification: "c", responsible: "GRC",
                              acceptedAt: "2026-07-01", expiresAt: "2026-07-22")
        #expect(e.isActive(asOf: "2026-07-22T14:30:00Z") == true)   // ainda o dia-limite
        #expect(e.isActive(asOf: "2026-07-23T00:00:00Z") == false)
    }

    @Test func expiresOnBoundaryDayIsStillActive() {
        let e = exc("x", expires: "2026-07-21")
        #expect(e.isActive(asOf: "2026-07-21") == true)      // o próprio dia ainda vale
        #expect(e.isActive(asOf: "2026-07-22") == false)
    }

    @Test func daysRemainingComputes() {
        let e = exc("x", expires: "2026-07-31")
        #expect(e.daysRemaining(asOf: "2026-07-21") == 10)
        #expect(e.daysRemaining(asOf: "2026-08-01") == -1)
    }

    @Test func reportHasAcceptedSection() throws {
        let a = audit([f("firewall-inactive", .high), f("kernel-aslr", .low)])
        let exceptions = [exc("firewall-inactive", expires: "2026-12-31")]
        let eff = RiskExceptions.effective(a, exceptions: exceptions, today: "2026-07-21")
        let acc = RiskExceptions.accepted(a, exceptions: exceptions, today: "2026-07-21")
        let html = AuditReport.riskRegisterHTML(eff, accepted: acc)
        #expect(html.contains("Riscos aceitos (exceções formais)"))
        #expect(html.contains("firewall-inactive"))         // aparece na seção de aceitos
        #expect(html.contains("http://") == false && html.contains("https://") == false)
    }
}
