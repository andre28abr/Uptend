import Testing
@testable import Uptend

/// Testes dos parsers e mapeamentos da categoria Rede.
struct NetworkTests {

    @Test func latencyParse() {
        let reply = "64 bytes from 1.1.1.1: icmp_seq=0 ttl=57 time=12.3 ms"
        #expect(LatencyMonitor.parseTime(reply) == 12.3)
        #expect(LatencyMonitor.parseTime("Request timeout for icmp_seq 0") == nil)
    }

    @Test func latencyStddev() {
        #expect(LatencyMonitor.stddev([10, 10, 10]) == 0)
        #expect(LatencyMonitor.stddev([]) == 0)
        #expect(LatencyMonitor.stddev([2, 4, 4, 4, 5, 5, 7, 9]) == 2)
    }

    @Test func wifiQualityMapping() {
        #expect(WiFiService.quality(fromRSSI: -50) == 100)
        #expect(WiFiService.quality(fromRSSI: -75) == 50)
        #expect(WiFiService.quality(fromRSSI: -100) == 0)
        #expect(WiFiService.quality(fromRSSI: 0) == 0)   // sem sinal
    }

    @Test func gatewayAndDNSParse() {
        let route = """
           route to: default
        destination: default
               gateway: 192.168.15.1
        """
        #expect(NetworkTools.parseGateway(route) == "192.168.15.1")

        let scutil = """
        resolver #1
          nameserver[0] : 192.168.15.1
          nameserver[1] : 8.8.8.8
        resolver #2
          nameserver[0] : 192.168.15.1
        """
        #expect(NetworkTools.parseDNS(scutil) == ["192.168.15.1", "8.8.8.8"])
    }

    @Test func macParse() {
        let ifconfig = """
        lo0: flags=8049<UP,LOOPBACK> mtu 16384
        \tinet 127.0.0.1 netmask 0xff000000
        en0: flags=8863<UP,BROADCAST> mtu 1500
        \tether a4:83:e7:11:22:33
        \tinet 192.168.15.12 netmask 0xffffff00
        """
        let macs = NetworkTools.parseMac(ifconfig)
        #expect(macs.contains { $0.interface == "en0" && $0.mac == "a4:83:e7:11:22:33" })
    }

    @Test func connectionsParse() {
        let output = """
        COMMAND     PID   USER   FD   TYPE  DEVICE SIZE/OFF NODE NAME
        firefox   4210 andre   50u  IPv4  0x123     0t0  TCP 192.168.15.12:52344->140.82.112.3:443 (ESTABLISHED)
        """
        let list = ConnectionsService.parse(output)
        #expect(list.count == 1)
        #expect(list.first?.command == "firefox")
        #expect(list.first?.remote == "140.82.112.3:443")
    }
}
