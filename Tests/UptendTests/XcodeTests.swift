import Testing
@testable import Uptend

struct XcodeTests {

    @Test func parsesSimulatorList() {
        let output = """
        == Devices ==
        -- iOS 26.5 --
            iPhone 17 Pro (626734BC-1766-4129-A841-629B2C5AD4D0) (Shutdown)
            iPhone 17 (CA18B63C-A3D4-4B81-AB1F-D4056C1ADF96) (Booted)
        -- iPadOS 18.0 --
            iPad Pro 13-inch (M5) (743BAF44-28AC-464B-A4E8-799FE2BCD69B) (Shutdown)
        """
        let sims = XcodeService.parseSimulators(output)
        #expect(sims.count == 3)
        let booted = sims.first { $0.state == "Booted" }
        #expect(booted?.name == "iPhone 17")
        #expect(booted?.isBooted == true)
        let ipad = sims.first { $0.name == "iPad Pro 13-inch (M5)" }
        #expect(ipad?.os == "iPadOS 18.0")
        #expect(ipad?.udid == "743BAF44-28AC-464B-A4E8-799FE2BCD69B")
    }

    @Test func parseSimulatorsHandlesEmpty() {
        #expect(XcodeService.parseSimulators("== Devices ==").isEmpty)
        #expect(XcodeService.parseSimulators("").isEmpty)
    }

    @Test func parsesRuntimeTotal() {
        let output = """
        == Disk Images ==
        -- iOS --
        iOS 26.5 (23F77) - BBEE35E8-F24E-4FCE-9BE9-A5579A88991C (Ready)

        Total Disk Images: 1 (7.9G)
        """
        let r = XcodeService.parseRuntimeTotal(output)
        #expect(r.count == 1)
        #expect(r.size == "7.9G")
    }

    @Test func parseRuntimeTotalHandlesNone() {
        #expect(XcodeService.parseRuntimeTotal("No disk images").count == 0)
        #expect(XcodeService.parseRuntimeTotal("").size == "")
    }

    @Test func friendlySizeAddsUnitSuffix() {
        #expect(XcodeService.friendlySize("7.9G") == "7.9 GB")
        #expect(XcodeService.friendlySize("192M") == "192 MB")
        #expect(XcodeService.friendlySize("500K") == "500 KB")
        #expect(XcodeService.friendlySize("0") == "0")
        #expect(XcodeService.friendlySize("") == "")
    }
}
