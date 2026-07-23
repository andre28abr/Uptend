import Testing
@testable import Uptend

/// Parsers do Docker remoto — fixtures reais capturadas do uptend-lab.
struct RemoteDockerTests {

    @Test func parsesContainers() {
        let out = """
        postgres\trunning\tUp 2 hours\tpostgres:16-alpine\t5432/tcp
        redis\trunning\tUp 2 hours\tredis:alpine\t6379/tcp
        nginx\trunning\tUp 2 hours\tnginx:alpine\t0.0.0.0:8080->80/tcp, [::]:8080->80/tcp
        app\texited\tExited (0) 3 minutes ago\tbusybox\t
        """
        let cs = RemoteDocker.parseContainers(out)
        #expect(cs.count == 4)
        #expect(cs[0].name == "postgres")
        #expect(cs[0].isRunning)
        #expect(cs[0].image == "postgres:16-alpine")
        #expect(cs[0].ports == "5432/tcp")
        // ports com vírgulas continua num campo só (split por TAB)
        #expect(cs[2].ports == "0.0.0.0:8080->80/tcp, [::]:8080->80/tcp")
        // container parado, sem portas
        #expect(cs[3].isRunning == false)
        #expect(cs[3].ports.isEmpty)
    }

    @Test func parsesImagesAndVolumes() {
        let imgs = RemoteDocker.parseImages("""
        postgres:16-alpine\t412MB\t57c72fd2a128
        nginx:alpine\t93.8MB\t54f2a904c251
        """)
        #expect(imgs.count == 2)
        #expect(imgs[0].repoTag == "postgres:16-alpine")
        #expect(imgs[0].size == "412MB")
        #expect(imgs[0].imageID == "57c72fd2a128")

        let vols = RemoteDocker.parseVolumes("89dda5fa1a2d\tlocal\npgdata\tlocal")
        #expect(vols.count == 2)
        #expect(vols[1].name == "pgdata")
        #expect(vols[1].driver == "local")
    }

    @Test func parsersHandleEmptyAndGarbage() {
        #expect(RemoteDocker.parseContainers("").isEmpty)
        #expect(RemoteDocker.parseImages("").isEmpty)
        #expect(RemoteDocker.parseVolumes("linha sem tab").isEmpty)
    }

    @Test func validatesDockerNames() {
        #expect(InputValidator.isValidDockerName("nginx"))
        #expect(InputValidator.isValidDockerName("postgres:16-alpine"))
        #expect(InputValidator.isValidDockerName("57c72fd2a128"))
        #expect(InputValidator.isValidDockerName("grafana/grafana"))
        #expect(InputValidator.isValidDockerName("nginx; rm -rf /") == false)   // metacaracteres
        #expect(InputValidator.isValidDockerName("$(whoami)") == false)
        #expect(InputValidator.isValidDockerName("a b") == false)               // espaço
        #expect(InputValidator.isValidDockerName("") == false)
    }
}
