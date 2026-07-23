import Testing
@testable import Uptend

struct RemoteDeployTests {

    private let host = RemoteHost(name: "lab", kind: .server, address: "10.0.0.5",
                                  user: "andre", port: 22, keyPath: "~/.ssh/k")

    @Test func validatesPortMapping() {
        #expect(RemoteDeploy.isValidPortMapping("8080:80"))
        #expect(RemoteDeploy.isValidPortMapping("80:8080"))
        #expect(RemoteDeploy.isValidPortMapping("8080") == false)
        #expect(RemoteDeploy.isValidPortMapping("0:80") == false)
        #expect(RemoteDeploy.isValidPortMapping("70000:80") == false)
        #expect(RemoteDeploy.isValidPortMapping("a:b") == false)
    }

    @Test func remoteDirUsesUserAndName() {
        #expect(RemoteDeploy.remoteDir(host, name: "meu-site") == "/home/andre/uptend-deploys/meu-site")
    }

    @Test func buildRunArgsWithAndWithoutPort() {
        let withPort = RemoteDeploy.buildRunArgs(host, name: "meu-site", port: "8080:80").last!
        #expect(withPort.contains("docker build -t meu-site ."))
        #expect(withPort.contains("cd /home/andre/uptend-deploys/meu-site"))
        #expect(withPort.contains("-p 8080:80"))
        #expect(withPort.contains("docker run -d --name meu-site"))

        let noPort = RemoteDeploy.buildRunArgs(host, name: "meu-site", port: "").last!
        #expect(noPort.contains("-p ") == false)
    }

    @Test func buildRunArgsRejectsBadNameOrPort() {
        // Revalidação interna: nome/porta perigosos não montam o docker run — abortam.
        let badName = RemoteDeploy.buildRunArgs(host, name: "meu-site; rm -rf /", port: "").last!
        #expect(badName.contains("deploy cancelado"))
        #expect(badName.contains("docker run") == false)

        let badPort = RemoteDeploy.buildRunArgs(host, name: "meu-site", port: "8080:80; id").last!
        #expect(badPort.contains("deploy cancelado"))
        #expect(badPort.contains("docker run") == false)
    }
}
