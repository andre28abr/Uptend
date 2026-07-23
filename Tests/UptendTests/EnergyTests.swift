import Testing
@testable import Uptend

struct EnergyTests {

    @Test func parsesPmset() {
        let out = "Now drawing from 'Battery Power'\n -InternalBattery-0 (id=35520611)\t36%; discharging; 2:28 remaining present: true"
        let b = EnergyService.parsePmset(out)
        #expect(b.charge == 36)
        #expect(b.state == "discharging")
        #expect(b.timeRemaining == "2:28 remaining")
    }

    @Test func parsesPmsetCharging() {
        let b = EnergyService.parsePmset(" -InternalBattery-0 (id=1)\t80%; charging; 0:45 remaining present: true")
        #expect(b.charge == 80)
        #expect(b.state == "charging")
    }

    @Test func parsesTopProcesses() {
        let ps = """
        %CPU COMM
        45.2 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome
        12.0 /System/Library/CoreServices/Finder.app/Contents/MacOS/Finder
         0.0 /usr/sbin/nada
        """
        let procs = EnergyService.parseTopProcesses(ps, limit: 8)
        #expect(procs.count == 2)                          // pula o de 0%
        #expect(procs.first?.name == "Google Chrome")      // basename com espaço
        #expect(procs.first?.cpu == 45.2)
    }

    @Test func valueReadsSystemProfilerLine() {
        let out = "          Cycle Count: 281\n          Condition: Normal"
        #expect(EnergyService.value(out, "Cycle Count") == "281")
        #expect(EnergyService.value(out, "Condition") == "Normal")
        #expect(EnergyService.value(out, "Inexistente") == "")
    }
}
