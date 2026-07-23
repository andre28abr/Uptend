import Testing
@testable import Uptend

/// Runner falso: devolve saídas canned por comando, sem tocar no sistema.
struct MockRunner: CommandRunning {
    let handler: @Sendable (_ path: String, _ args: [String]) -> CommandResult
    func capture(_ launchPath: String, _ args: [String], env: [String: String]?) async -> CommandResult {
        handler(launchPath, args)
    }
}

/// Demonstra o valor do `CommandRunning`: testar a ORQUESTRAÇÃO dos serviços
/// (comando → parse → estado) de forma determinística e instantânea.
struct CommandRunnerTests {

    @Test @MainActor func exposureServiceFromMockedCommands() async {
        let mock = MockRunner { path, args in
            if path.contains("socketfilterfw"), args.contains("--getstealthmode") {
                return CommandResult(exitCode: 0, stdout: "Firewall stealth mode is off", stderr: "")
            }
            if path.contains("socketfilterfw") {
                return CommandResult(exitCode: 0, stdout: "Firewall is enabled. (State = 1)", stderr: "")
            }
            if path.contains("netstat") {
                return CommandResult(exitCode: 0,
                    stdout: "tcp4  0 0  *.22            *.*  LISTEN\ntcp4  0 0  127.0.0.1.5432  *.*  LISTEN",
                    stderr: "")
            }
            return CommandResult(exitCode: 0, stdout: "", stderr: "")
        }
        let e = ExposureService(runner: mock)
        await e.refresh()
        #expect(e.checks.contains { $0.name == "Firewall do aplicativo" && $0.status == .ok })
        #expect(e.checks.contains { $0.name == "Modo invisível (stealth)" && $0.status == .warning })
        #expect(e.checks.contains { $0.name == "Login remoto (SSH)" && $0.detail.contains("exposto") })
    }

    @Test @MainActor func appCheckVerdictFromMockedCommands() async {
        // App próprio/sem assinatura: Gatekeeper rejeita.
        let mock = MockRunner { path, args in
            if path.contains("spctl") {
                return CommandResult(exitCode: 3, stdout: "", stderr: "/x.app: rejected\nsource=no usable signature")
            }
            if path.contains("codesign") {   // -dv e --verify falham (não assinado)
                return CommandResult(exitCode: 1, stdout: "", stderr: "code object is not signed at all")
            }
            if path.contains("xattr") {       // sem atributo de quarentena
                return CommandResult(exitCode: 1, stdout: "", stderr: "")
            }
            return CommandResult(exitCode: 0, stdout: "", stderr: "")
        }
        let c = AppCheckService(runner: mock)
        await c.check(path: "/System/Applications/Calculator.app")   // caminho existe; comandos são mockados
        #expect(c.verdict?.gatekeeperAccepted == false)
        #expect(c.verdict?.signed == false)
        #expect(c.verdict?.level == .danger)
    }

    @Test @MainActor func appCheckTrustedFromMockedCommands() async {
        // App notarizado: aceito + Developer ID + notarizado.
        let mock = MockRunner { path, args in
            if path.contains("spctl") {
                return CommandResult(exitCode: 0, stdout: "", stderr: "/x.app: accepted\nsource=Notarized Developer ID")
            }
            if path.contains("codesign"), args.contains("-dv") {
                return CommandResult(exitCode: 0, stdout: "",
                    stderr: "Authority=Developer ID Application: Foo (ABCDE12345)\nTeamIdentifier=ABCDE12345")
            }
            if path.contains("codesign") { return CommandResult(exitCode: 0, stdout: "", stderr: "") }
            if path.contains("xattr") { return CommandResult(exitCode: 1, stdout: "", stderr: "") }
            return CommandResult(exitCode: 0, stdout: "", stderr: "")
        }
        let c = AppCheckService(runner: mock)
        await c.check(path: "/System/Applications/Calculator.app")
        #expect(c.verdict?.level == .trusted)
        #expect(c.verdict?.teamID == "ABCDE12345")
        #expect(c.verdict?.notarized == true)
    }
}
