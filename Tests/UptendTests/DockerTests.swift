import Testing
@testable import Uptend

/// Testes do parser da saída JSON do Docker (`--format {{json .}}`).
struct DockerTests {

    @Test func parseContainers() {
        let output = """
        {"ID":"abc123","Image":"postgres:16","Names":"postgres-db","State":"running","Status":"Up 2 hours"}
        {"ID":"def456","Image":"nginx:latest","Names":"nginx-proxy","State":"exited","Status":"Exited (0) 3 days ago"}
        """
        let list = DockerService.parseContainers(output)
        #expect(list.count == 2)
        #expect(list[0].name == "postgres-db")
        #expect(list[0].running == true)
        #expect(list[1].running == false)
    }

    @Test func parseContainersRunningFallbackFromStatus() {
        // Sem o campo State, infere "rodando" pelo Status começando com "Up".
        let output = #"{"ID":"x","Image":"redis:7","Names":"cache","Status":"Up 5 minutes"}"#
        let list = DockerService.parseContainers(output)
        #expect(list.first?.running == true)
    }

    @Test func parseImages() {
        let output = #"{"ID":"img1","Repository":"postgres","Tag":"16","Size":"425MB"}"#
        let list = DockerService.parseImages(output)
        #expect(list.count == 1)
        #expect(list[0].repository == "postgres")
        #expect(list[0].tag == "16")
        #expect(list[0].size == "425MB")
    }

    @Test func parseVolumesAndNetworks() {
        let volumes = DockerService.parseVolumes(#"{"Name":"pg-data","Driver":"local"}"#)
        #expect(volumes.first?.name == "pg-data")

        let networks = DockerService.parseNetworks(#"{"ID":"n1","Name":"bridge","Driver":"bridge"}"#)
        #expect(networks.first?.name == "bridge")
    }

    @Test func ignoresGarbageLines() {
        let output = """
        não é json
        {"ID":"ok","Image":"alpine","Names":"a","State":"running","Status":"Up"}
        """
        #expect(DockerService.parseContainers(output).count == 1)
    }
}
