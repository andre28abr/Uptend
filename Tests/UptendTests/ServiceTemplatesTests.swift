import Testing
@testable import Uptend

struct ServiceTemplatesTests {

    private func template(_ id: String) -> ServiceTemplate {
        ServiceCatalog.templates.first { $0.id == id }!
    }

    @Test func buildsSimpleDockerRun() {
        let t = template("uptime-kuma")
        let args = t.dockerRunArgs(name: "uptime-kuma", fields: t.fields)
        #expect(args == ["docker", "run", "-d", "--name", "uptime-kuma", "--restart", "unless-stopped",
                         "-p", "3001:3001",
                         "-v", "uptime-kuma-data:/app/data",
                         "louislam/uptime-kuma:1"])
    }

    @Test func buildsUdpPortsAndEnvPassword() {
        let t = template("pihole")
        var fields = t.fields
        // preenche a senha
        if let i = fields.firstIndex(where: { $0.key == "pass" }) { fields[i].value = "segredo123" }
        let args = t.dockerRunArgs(name: "pihole", fields: fields)
        #expect(args.contains("53:53/udp"))            // porta UDP com sufixo
        #expect(args.contains("53:53"))                // porta TCP sem sufixo
        #expect(args.contains("8089:80"))              // web
        #expect(args.contains("WEBPASSWORD=segredo123"))
        // senha vazia não vira -e
        let noPass = t.dockerRunArgs(name: "pihole", fields: t.fields)
        #expect(noPass.contains(where: { $0.hasPrefix("WEBPASSWORD=") }) == false)
    }

    @Test func portainerIncludesSocketMount() {
        let t = template("portainer")
        let args = t.dockerRunArgs(name: "portainer", fields: t.fields)
        #expect(args.contains("/var/run/docker.sock:/var/run/docker.sock"))
    }

    @Test func webHostPortResolves() {
        let t = template("vaultwarden")     // host 8083 → container 80 (web)
        #expect(t.webHostPort(t.fields) == "8083")
    }

    @Test func validationCatchesBadInput() {
        let t = template("uptime-kuma")
        #expect(t.validate(name: "uptime-kuma", fields: t.fields) == nil)   // ok
        #expect(t.validate(name: "nome inválido", fields: t.fields) != nil) // espaço no nome
        var bad = t.fields
        bad[0].value = "99999"                                              // porta fora da faixa
        #expect(t.validate(name: "uptime-kuma", fields: bad) != nil)
    }

    @Test func extractsHostPortFromDockerPorts() {
        let ports = "0.0.0.0:3001->3001/tcp, [::]:3001->3001/tcp"
        #expect(ServiceTemplate.hostPort(forContainerPort: 3001, in: ports) == "3001")
        // porta do host diferente da do container
        #expect(ServiceTemplate.hostPort(forContainerPort: 8080, in: "0.0.0.0:8888->8080/tcp") == "8888")
        // porta de container não publicada
        #expect(ServiceTemplate.hostPort(forContainerPort: 9999, in: ports) == nil)
        #expect(ServiceTemplate.hostPort(forContainerPort: 80, in: "") == nil)
    }

    @Test func catalogHasMetabaseAndWazuhStack() {
        #expect(ServiceCatalog.templates.contains { $0.id == "metabase" })
        let wazuh = ServiceCatalog.stacks.first { $0.id == "wazuh" }
        #expect(wazuh != nil)
        #expect(wazuh?.deployArgs.first == "bash")
        #expect(wazuh?.deployArgs.last?.contains("docker compose up -d") == true)
        #expect(wazuh?.ramNote.isEmpty == false)   // avisa que é pesado
    }

    @Test func catalogHasExpectedShape() {
        #expect(ServiceCatalog.templates.count >= 6)
        #expect(ServiceCatalog.templates.allSatisfy { !$0.image.isEmpty && !$0.fields.isEmpty })
        #expect(ServiceCatalog.categories.contains("Monitoramento"))
    }

    @Test func redactsSecretsInDisplayedCommand() {
        // Ao exibir o comando no log, valores de senha/token/segredo somem (só a chave fica).
        let args = ["docker", "run", "-e", "WEBPASSWORD=segredo123", "-e", "MB_TOKEN=abc",
                    "-e", "DB_SECRET=xyz", "-e", "PUID=1000", "pihole/pihole:latest"]
        let shown = RemoteTask.redactedDisplay(args)
        #expect(shown.contains("segredo123") == false)
        #expect(shown.contains("abc") == false)
        #expect(shown.contains("xyz") == false)
        #expect(shown.contains("WEBPASSWORD=•••"))
        #expect(shown.contains("PUID=1000"))               // não-sensível permanece
        #expect(shown.contains("pihole/pihole:latest"))
    }
}
