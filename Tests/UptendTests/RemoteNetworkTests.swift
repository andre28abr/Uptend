import Testing
@testable import Uptend

/// Parsers de rede — fixtures reais capturadas do uptend-lab.
struct RemoteNetworkTests {

    @Test func parsesGateway() {
        let out = "default via 192.168.139.1 dev eth0 proto dhcp src 192.168.139.188 metric 100"
        #expect(RemoteNetwork.parseGateway(out) == "192.168.139.1 (eth0)")
        #expect(RemoteNetwork.parseGateway("nada aqui") == nil)
    }

    @Test func parsesListeningPorts() {
        let out = """
        State  Recv-Q Send-Q Local Address:Port  Peer Address:PortProcess
        LISTEN 0      4096       127.0.0.1:38891      0.0.0.0:*    users:(("containerd",pid=4083,fd=14))
        LISTEN 0      4096         0.0.0.0:8080       0.0.0.0:*    users:(("docker-proxy",pid=10382,fd=7))
        LISTEN 0      4096         0.0.0.0:22         0.0.0.0:*    users:(("sshd",pid=3034,fd=3))
        LISTEN 0      4096            [::]:8080          [::]:*    users:(("docker-proxy",pid=10391,fd=7))
        """
        let ports = RemoteNetwork.parseListening(out)
        // IPv4/IPv6 da 8080 colapsam em uma entrada
        #expect(ports.count == 3)
        // ordenado por porta
        #expect(ports.map(\.port) == ["22", "8080", "38891"])
        let ssh = ports.first { $0.port == "22" }
        #expect(ssh?.process == "sshd")
        #expect(ssh?.isPublic == true)                 // 0.0.0.0
        let containerd = ports.first { $0.port == "38891" }
        #expect(containerd?.isPublic == false)         // 127.0.0.1 = só local
        #expect(containerd?.process == "containerd")
    }

    @Test func handlesEmpty() {
        #expect(RemoteNetwork.parseListening("").isEmpty)
        #expect(RemoteNetwork.parseListening("State Recv-Q ...").isEmpty)   // só cabeçalho
    }
}
