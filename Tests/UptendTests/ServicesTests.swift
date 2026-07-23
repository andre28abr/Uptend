import Testing
import Foundation
@testable import Uptend

struct ServicesTests {

    @Test func parsesBrewServicesJSON() {
        let json = """
        [
          {"name":"postgresql@16","status":"started","user":"andre","file":"/opt/homebrew/.../plist","exit_code":0},
          {"name":"redis","status":"none","user":null,"file":"/opt/homebrew/.../plist","exit_code":null},
          {"name":"nginx","status":"error","user":null,"file":"/x","exit_code":1}
        ]
        """
        let items = ServicesService.parse(Data(json.utf8))
        #expect(items.count == 3)
        #expect(items.first?.name == "nginx")   // ordenado alfabético
        let pg = items.first { $0.name == "postgresql@16" }
        #expect(pg?.isRunning == true)
        #expect(items.first { $0.name == "redis" }?.isRunning == false)
    }

    @Test func parseServicesHandlesGarbage() {
        #expect(ServicesService.parse(Data("lixo".utf8)).isEmpty)
        #expect(ServicesService.parse(Data("[]".utf8)).isEmpty)
    }
}
