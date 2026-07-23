import Testing
@testable import Uptend

/// Testes do parser de saída do ClamAV.
struct ClamAVTests {

    @Test func parseScanFindings() {
        let output = """
        /Users/x/Downloads/ok.txt: OK
        /Users/x/Downloads/eicar.com: Win.Test.EICAR_HDB-1 FOUND
        /Users/x/Downloads/two: Some.Other.Sig FOUND

        ----------- SCAN SUMMARY -----------
        Scanned files: 3
        Infected files: 2
        """
        let result = ClamAVService.parseScan(output)
        #expect(result.infected == 2)
        #expect(result.findings.count == 2)
        #expect(result.findings.first?.file == "/Users/x/Downloads/eicar.com")
        #expect(result.findings.first?.signature == "Win.Test.EICAR_HDB-1")
    }

    @Test func parseScanClean() {
        let output = """
        /Users/x/a: OK
        ----------- SCAN SUMMARY -----------
        Infected files: 0
        """
        #expect(ClamAVService.parseScan(output).infected == 0)
    }

    @Test func parseVersionWithDefinitions() {
        #expect(ClamAVService.parseVersion("ClamAV 1.0.5/27200/Fri Jul 10 09:00:00 2026").contains("27200"))
        #expect(ClamAVService.parseVersion("ClamAV 1.0.5").contains("Sem definições"))
    }

    @Test func durationFormat() {
        #expect(ClamAVService.formatDuration(45) == "45s")
        #expect(ClamAVService.formatDuration(75) == "1m 15s")
        #expect(ClamAVService.formatDuration(3661) == "61m 1s")
    }

    @Test func noiseFilter() {
        #expect(ClamAVService.isNoiseLine("LibClamAV Warning: cli_realpath: Invalid arguments."))
        #expect(ClamAVService.isNoiseLine("some cli_realpath thing"))
        #expect(!ClamAVService.isNoiseLine("/Users/x/evil: Win.Test.EICAR_HDB-1 FOUND"))
        #expect(!ClamAVService.isNoiseLine("Infected files: 1"))
    }
}
