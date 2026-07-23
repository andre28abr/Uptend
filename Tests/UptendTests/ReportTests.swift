import Testing
import Foundation
@testable import Uptend

struct ReportTests {

    private func sample() -> ReportData {
        ReportData(
            generatedAt: "13/07/2026 10:00",
            computerName: "Mac do André", serialNumber: "C02X1234", modelIdentifier: "Mac14,7",
            hardwareUUID: "UUID-1", model: "MacBook Pro", chip: "Apple M2", cores: 8, memory: "16 GB",
            diskTotal: "500 GB", diskFree: "200 GB", batteryCycles: "120",
            osVersion: "macOS 15", uptime: "3 dias", localIP: "192.168.0.10",
            apps: [
                ReportApp(name: "Xcode", version: "16.0", sizeBytes: 12_000_000_000, source: "App Store", bundleID: "com.apple.dt.Xcode"),
                ReportApp(name: "Firefox", version: "130", sizeBytes: 300_000_000, source: "Manual / Homebrew", bundleID: "org.mozilla.firefox"),
            ],
            brewPackages: 42, outdated: 3,
            security: [ReportCheck(name: "FileVault", ok: true, detail: "Ativado"),
                       ReportCheck(name: "Firewall", ok: false, detail: "Desativado")])
    }

    // MARK: Escopo

    @Test func scopeInclusion() {
        #expect(SystemReport.includes(.hardware, scope: .complete))
        #expect(SystemReport.includes(.software, scope: .apps))
        #expect(!SystemReport.includes(.hardware, scope: .apps))
        #expect(!SystemReport.includes(.software, scope: .hardware))
        #expect(SystemReport.includes(.security, scope: .security))
        #expect(!SystemReport.includes(.security, scope: .apps))
    }

    // MARK: Markdown

    @Test func markdownCompleteHasEverything() {
        let md = SystemReport.markdown(sample(), scope: .complete, detail: .detailed)
        #expect(md.contains("# Inventário do Mac"))
        #expect(md.contains("C02X1234"))            // número de série
        #expect(md.contains("## Hardware"))
        #expect(md.contains("## Segurança"))
        #expect(md.contains("Xcode"))               // app na tabela detalhada
        #expect(md.contains("FileVault: OK"))
        #expect(md.contains("Firewall: ATENÇÃO"))
    }

    @Test func markdownAppsScopeExcludesHardware() {
        let md = SystemReport.markdown(sample(), scope: .apps, detail: .summary)
        #expect(md.contains("## Aplicativos"))
        #expect(!md.contains("## Hardware"))
        #expect(!md.contains("## Segurança"))
    }

    @Test func summaryShowsTopAppsNotFullTable() {
        let md = SystemReport.markdown(sample(), scope: .apps, detail: .summary)
        #expect(md.contains("Maiores apps:"))
        #expect(!md.contains("| App | Versão |"))
    }

    // MARK: JSON

    @Test func jsonIsValidAndScoped() throws {
        let text = SystemReport.json(sample(), scope: .complete, detail: .detailed)
        let obj = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any]
        #expect(obj?["identificacao"] != nil)
        #expect(obj?["hardware"] != nil)
        #expect(obj?["aplicativos"] != nil)
        // Escopo apps não traz hardware.
        let appsOnly = SystemReport.json(sample(), scope: .apps, detail: .summary)
        let obj2 = try JSONSerialization.jsonObject(with: Data(appsOnly.utf8)) as? [String: Any]
        #expect(obj2?["hardware"] == nil)
        #expect(obj2?["aplicativos"] != nil)
    }

    // MARK: HTML

    @Test func htmlIsWellFormedAndEscapes() {
        var data = sample()
        data.computerName = "A & B <script>"
        let html = SystemReport.html(data, scope: .complete, detail: .summary)
        #expect(html.hasPrefix("<!doctype html>"))
        #expect(html.contains("<h1>Inventário do Mac</h1>"))
        #expect(html.contains("A &amp; B &lt;script&gt;"))   // escapado
        #expect(!html.contains("<script>"))
    }

    // MARK: Parser do system_profiler

    @Test func parsesHardwareValue() {
        let output = """
        Hardware:

            Hardware Overview:

              Model Name: MacBook Pro
              Model Identifier: Mac14,7
              Serial Number (system): C02XABC123
              Hardware UUID: 1234-5678
        """
        #expect(ReportBuilder.value(in: output, key: "Serial Number") == "C02XABC123")
        #expect(ReportBuilder.value(in: output, key: "Model Identifier") == "Mac14,7")
        #expect(ReportBuilder.value(in: output, key: "Hardware UUID") == "1234-5678")
        #expect(ReportBuilder.value(in: output, key: "Inexistente") == "")
    }

    // MARK: Parsers do pente-fino

    @Test func parsesMultipleValues() {
        let disp = "  Chipset Model: Apple M2\n  Resolution: 2560 x 1600\n  Chipset Model: Radeon\n  Resolution: 1920 x 1080"
        #expect(ReportBuilder.allValues(in: disp, key: "Chipset Model") == ["Apple M2", "Radeon"])
        #expect(ReportBuilder.allValues(in: disp, key: "Resolution").count == 2)
    }

    @Test func parsesSIP() {
        #expect(ReportBuilder.parseSIP("System Integrity Protection status: enabled.") == "Ativado")
        #expect(ReportBuilder.parseSIP("System Integrity Protection status: disabled.") == "Desativado")
        #expect(ReportBuilder.parseSIP("indefinido") == "")
    }

    @Test func parsesDNSAndGateway() {
        let dns = "  resolver #1\n  nameserver[0] : 8.8.8.8\n  nameserver[1] : 1.1.1.1\n  nameserver[0] : 8.8.8.8"
        #expect(ReportBuilder.parseDNS(dns) == ["8.8.8.8", "1.1.1.1"])   // sem duplicar
        let route = "Destination        Gateway            Flags\ndefault            192.168.0.1        UGScg\n127.0.0.1          127.0.0.1          UH"
        #expect(ReportBuilder.parseGateway(route) == "192.168.0.1")
    }

    @Test func parsesEtherAndDU() {
        let ifc = "en0: flags=8863\n\tether a4:83:e7:11:22:33 \n\tinet 192.168.0.5"
        #expect(ReportBuilder.etherAddress(ifc) == "a4:83:e7:11:22:33")
        #expect(ReportBuilder.parseDU("2048\t/Users/x/Downloads") == 2048)
        #expect(ReportBuilder.parseDU("lixo") == nil)
    }

    @Test func parsesVolumesAndExtensions() {
        let df = """
        Filesystem      Size  Used Avail Capacity iused ifree %iused  Mounted on
        /dev/disk3s1s1  494G   15G  200G    88%   500k  2.0G    0%   /
        /dev/disk4s1    2.0T  1.0T  1.0T    50%   100k  1.0G    0%   /Volumes/My Disk
        map auto_home     0B    0B    0B   100%   0     0     100%   /System/Volumes/Data/home
        """
        let vols = ReportBuilder.parseVolumes(df)
        #expect(vols.contains { $0.hasPrefix("Sistema (/):") })
        #expect(vols.contains { $0.hasPrefix("My Disk:") })     // nome com espaço não é descartado
        #expect(!vols.contains { $0.contains("auto_home") })   // fora de / e /Volumes

        let ext = "enabled active teamID com.crowdstrike.falcon.Agent Falcon\n--- com.apple.system_extension"
        let parsed = ReportBuilder.parseExtensions(ext)
        #expect(parsed.contains("com.crowdstrike.falcon.Agent"))
        #expect(!parsed.contains { $0.hasPrefix("com.apple") })
    }

    @Test func parsesInstallHistory() {
        let output = """
        Install History:

            Xcode:

              Version: 16.0
              Source: App Store
              Install Date: 2026-05-01 10:00:00 +0000

            macOS 15.1:

              Version: 15.1
              Source: Apple
              Install Date: 2024-11-01 09:00:00 +0000
        """
        let h = ReportBuilder.parseInstallHistory(output)
        #expect(h.count == 2)
        #expect(h.first?.hasPrefix("Xcode — 2026") == true)   // mais recente primeiro
    }

    @Test func parsesUsersAndSystemPaths() {
        let output = "_mbsetupuser\nandre\ndaemon\nnobody\nroot\nGuest"
        let users = ReportBuilder.parseUsers(output)
        #expect(users.contains("andre"))
        #expect(users.contains("Guest"))
        #expect(!users.contains("root"))
        #expect(!users.contains("_mbsetupuser"))
    }

    @Test func parsesBootTimeAndTimezone() {
        #expect(!ReportBuilder.bootTime("{ sec = 1730000000, usec = 0 } Mon Oct 27 2024").isEmpty)
        #expect(ReportBuilder.bootTime("sem sec") == "")
        #expect(ReportBuilder.timezone("/var/db/timezone/zoneinfo/America/Sao_Paulo") == "America/Sao_Paulo")
    }

    // MARK: Renderização com pente-fino

    @Test func deepSectionsRenderInComplete() {
        var data = sample()
        var deep = ReportDeep()
        deep.sip = "Ativado"
        deep.startupItems = ["com.docker.helper"]
        deep.runtimes = [ReportRuntime(name: "Node.js", version: "v20.0.0")]
        deep.folderSizes = [ReportFolder(name: "Downloads", bytes: 5_000_000_000)]
        deep.nonAppStoreApps = 12
        data.deep = deep

        let md = SystemReport.markdown(data, scope: .complete, detail: .detailed)
        #expect(md.contains("## Integridade e personalizações"))
        #expect(md.contains("SIP): Ativado"))
        #expect(md.contains("com.docker.helper"))
        #expect(md.contains("Node.js: v20.0.0"))
        #expect(md.contains("## Armazenamento"))

        // Escopo estreito não traz personalizações.
        let hwOnly = SystemReport.markdown(data, scope: .hardware, detail: .summary)
        #expect(!hwOnly.contains("## Integridade e personalizações"))
    }
}
