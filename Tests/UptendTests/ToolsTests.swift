import Testing
import Foundation
@testable import Uptend

/// Testes dos conversores e do parser de portas (lógica pura).
struct ToolsTests {

    @Test func base64RoundTrip() {
        let encoded = Converters.base64Encode("Uptend")
        #expect(encoded == "VXB0ZW5k")
        #expect(Converters.base64Decode(encoded) == "Uptend")
        #expect(Converters.base64Decode("não é base64 válido @@@") == nil)
    }

    @Test func jsonPretty() {
        let out = Converters.jsonPretty("{\"b\":2,\"a\":1}")
        #expect(out != nil)
        #expect(out!.contains("\"a\" : 1"))
        #expect(Converters.jsonPretty("{quebrado") == nil)
    }

    @Test func timestampConversion() {
        // Época 0 em UTC.
        #expect(Converters.timestampToDate("0", timeZone: TimeZone(identifier: "UTC")!) == "1970-01-01 00:00:00")
        #expect(Converters.timestampToDate("abc") == nil)
    }

    @Test func hexToRGB() {
        #expect(Converters.hexToRGB("#FF8800") == "rgb(255, 136, 0)")
        #expect(Converters.hexToRGB("00FF00") == "rgb(0, 255, 0)")
        #expect(Converters.hexToRGB("xyz") == nil)
    }

    @Test func networkRateFormatting() {
        #expect(MonitorService.formatRate(0) == "0 B/s")
        #expect(MonitorService.formatRate(512) == "512 B/s")
        #expect(MonitorService.formatRate(1536) == "1.5 KB/s")
        #expect(MonitorService.formatRate(1024 * 1024) == "1.0 MB/s")
    }

    @Test func portsParsing() {
        let output = """
        COMMAND     PID   USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
        node      12345 andre   20u  IPv4 0x1234      0t0  TCP *:3000 (LISTEN)
        ControlCe   999 andre    8u  IPv6 0x5678      0t0  TCP [::1]:7000 (LISTEN)
        """
        let ports = PortsService.parse(output)
        #expect(ports.count == 2)
        #expect(ports.contains { $0.port == "3000" && $0.command == "node" && $0.pid == "12345" })
        #expect(ports.contains { $0.port == "7000" })
    }
}
