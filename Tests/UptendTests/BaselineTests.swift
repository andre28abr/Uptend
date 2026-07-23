import Testing
import Foundation
@testable import UptendCore

struct BaselineTests {

    private func f(_ id: String, _ sev: AuditSeverity, _ cat: String = "Segurança / Rede") -> AuditFinding {
        AuditFinding(id: id, title: id, severity: sev, category: cat, recommendation: "faça X")
    }
    private func audit(_ fs: [AuditFinding]) -> ExternalAudit {
        ExternalAudit(schemaVersion: 1, collector: .init(name: "x", version: "1", mode: "admin"),
            collectedAt: "2026-07-21T00:00:00Z", host: .init(hostname: "h", machineId: "m-1"),
            machine: nil, os: nil, disks: [], resources: nil, users: nil, docker: nil, profile: nil,
            findings: fs, lynis: nil)
    }

    @Test func generateCapturesEvaluatedControls() {
        let ref = audit([f("firewall-inactive", .ok), f("ssh-root-login", .ok, "Contas / SSH")])
        let b = BaselineEngine.generate(from: ref, name: "Padrão", today: "2026-07-21")
        #expect(b.items.count == 2)
        #expect(b.mandatoryCount == 2)
        #expect(Set(b.items.map(\.key)) == ["firewall", "ssh-root-login"])   // base-key normalizado
    }

    @Test func assessMarksConformeAndDesvio() {
        let ref = audit([f("firewall-inactive", .ok), f("ssh-root-login", .ok, "Contas / SSH")])
        let b = BaselineEngine.generate(from: ref, name: "Padrão", today: "2026-07-21")
        // máquina cliente: firewall caiu, ssh ok
        let client = audit([f("firewall-inactive", .high), f("ssh-root-login", .ok, "Contas / SSH")])
        let results = BaselineEngine.assess(client, against: b)
        let fw = results.first { $0.item.key == "firewall" }!
        let ssh = results.first { $0.item.key == "ssh-root-login" }!
        #expect(fw.status == .desvio)
        #expect(ssh.status == .conforme)
    }

    @Test func canonicalKeyUnifiesOkAndProblemVariants() {
        // Máquina de referência BOA: firewall-ok / umask-strict-ok / uid0-unique-ok.
        let ref = audit([f("firewall-ok", .ok), f("umask-strict-ok", .ok, "Config"), f("uid0-unique-ok", .ok, "Contas")])
        let b = BaselineEngine.generate(from: ref, name: "Padrão", today: "2026-07-21")
        // Máquina cliente RUIM: ids diferentes para o MESMO controle.
        let client = audit([f("firewall-inactive", .high), f("umask-loose", .medium, "Config"), f("uid0-multiple", .high, "Contas")])
        let results = BaselineEngine.assess(client, against: b)
        // Todos devem casar (senão apareceriam como "não avaliado").
        #expect(results.allSatisfy { $0.status == .desvio })
        #expect(BaselineEngine.summary(results).naoAvaliado == 0)
    }

    @Test func missingControlIsNaoAvaliado() {
        let b = Baseline(name: "P", createdAt: "2026-07-21", items: [BaselineItem(key: "auditd", title: "auditd")])
        let results = BaselineEngine.assess(audit([]), against: b)   // auditoria não checou auditd
        #expect(results.first?.status == .naoAvaliado)
    }

    @Test func summaryReprovaComDesvioObrigatorio() {
        let b = Baseline(name: "P", createdAt: "2026-07-21", items: [
            BaselineItem(key: "firewall", title: "Firewall", mandatory: true),
            BaselineItem(key: "kernel-aslr", title: "ASLR", mandatory: false),
        ])
        let client = audit([f("firewall-inactive", .high), f("kernel-aslr", .low, "Config")])
        let sum = BaselineEngine.summary(BaselineEngine.assess(client, against: b))
        #expect(sum.desvio == 2)
        #expect(sum.mandatoryDesvio == 1)     // só o firewall é obrigatório
        #expect(sum.passed == false)
    }

    @Test func builtinProfilesAreNested() {
        let basico = BaselineEngine.builtin(.basico, today: "2026-07-21")
        let padrao = BaselineEngine.builtin(.padrao, today: "2026-07-21")
        let rigoroso = BaselineEngine.builtin(.rigoroso, today: "2026-07-21")
        // Mesmo catálogo nos três (muda só o obrigatório).
        #expect(basico.items.count == padrao.items.count && padrao.items.count == rigoroso.items.count)
        let mBasico = Set(basico.items.filter(\.mandatory).map(\.key))
        let mPadrao = Set(padrao.items.filter(\.mandatory).map(\.key))
        let mRigoroso = Set(rigoroso.items.filter(\.mandatory).map(\.key))
        // Rigoroso ⊇ Padrão ⊇ Básico
        #expect(mBasico.isSubset(of: mPadrao))
        #expect(mPadrao.isSubset(of: mRigoroso))
        #expect(mBasico.count < mPadrao.count && mPadrao.count < mRigoroso.count)
        #expect(mRigoroso.count == rigoroso.items.count)   // no Rigoroso tudo é obrigatório
    }

    @Test func builtinKeysAreCanonical() {
        // Toda chave do catálogo curado deve ser uma identidade canônica estável
        // (controlKey(chave) == chave), senão não casaria com os achados.
        for item in BaselineEngine.builtin(.rigoroso, today: "2026-07-21").items {
            #expect(ComplianceMap.controlKey(item.key) == item.key, "chave não canônica: \(item.key)")
        }
    }

    @Test func stricterProfileFailsWhereLooserPasses() {
        // Máquina com um desvio só em item que é obrigatório no Rigoroso, não no Básico.
        let client = audit([f("umask-loose", .medium, "Config"),           // umask → só obrig. no Rigoroso
                            f("firewall-ok", .ok)])                          // essencial ok
        let basico = BaselineEngine.summary(BaselineEngine.assess(client, against: BaselineEngine.builtin(.basico, today: "2026-07-21")))
        let rigoroso = BaselineEngine.summary(BaselineEngine.assess(client, against: BaselineEngine.builtin(.rigoroso, today: "2026-07-21")))
        #expect(basico.passed == true)      // umask não é obrigatório no Básico
        #expect(rigoroso.passed == false)   // é obrigatório no Rigoroso
    }

    @Test func codableRoundTrip() throws {
        let b = Baseline(name: "P", createdAt: "2026-07-21", items: [BaselineItem(key: "firewall", title: "Firewall", note: "ufw ativo")])
        let data = try JSONEncoder().encode(b)
        let back = try JSONDecoder().decode(Baseline.self, from: data)
        #expect(back == b)
    }

    @Test func reportIsSelfContained() {
        let ref = audit([f("firewall-inactive", .ok)])
        let b = BaselineEngine.generate(from: ref, name: "Padrão", today: "2026-07-21")
        let client = audit([f("firewall-inactive", .high)])
        let html = AuditReport.baselineHTML(client, baseline: b)
        #expect(html.contains("Conformidade ao Baseline"))
        #expect(html.contains("REPROVADO"))
        #expect(html.contains("http://") == false && html.contains("https://") == false)
    }
}
