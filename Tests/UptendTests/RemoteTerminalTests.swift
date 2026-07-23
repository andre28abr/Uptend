import Testing
@testable import Uptend

struct RemoteTerminalTests {

    @Test func separatesOutputFromCwdMarker() {
        let stdout = "arquivo1.txt\narquivo2.txt\n\n__UPTEND_CWD__/home/andre/docs"
        let r = RemoteTerminal.parse(stdout: stdout, stderr: "", fallbackCwd: "/home/andre")
        #expect(r.output == "arquivo1.txt\narquivo2.txt")
        #expect(r.cwd == "/home/andre/docs")
    }

    @Test func keepsCwdWhenNoMarker() {
        let r = RemoteTerminal.parse(stdout: "só saída", stderr: "", fallbackCwd: "/tmp")
        #expect(r.output == "só saída")
        #expect(r.cwd == "/tmp")
    }

    @Test func appendsStderr() {
        let r = RemoteTerminal.parse(stdout: "\n__UPTEND_CWD__/root", stderr: "bash: xyz: comando não encontrado", fallbackCwd: "/root")
        #expect(r.output.contains("comando não encontrado"))
        #expect(r.cwd == "/root")
    }
}
