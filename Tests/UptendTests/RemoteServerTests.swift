import Testing
@testable import Uptend

/// Parsers de systemd e apt — fixtures reais capturadas do uptend-lab.
struct RemoteServerTests {

    @Test func parsesSystemdUnits() {
        let units = """
        console-getty.service                       loaded active running Console Getty
        console-setup.service                       loaded active exited  Set console font and keymap
        docker.service                              loaded active running Docker Application Container Engine
        não-é-serviço linha estranha
        """
        let enabled: Set<String> = ["docker.service"]
        let parsed = RemoteSystemd.parseUnits(units, enabled: enabled)
        #expect(parsed.count == 3)
        let docker = parsed.first { $0.name == "docker.service" }
        #expect(docker?.isRunning == true)
        #expect(docker?.enabled == true)
        #expect(docker?.shortName == "docker")
        #expect(docker?.description == "Docker Application Container Engine")
        // exited não é "running"
        #expect(parsed.first { $0.name == "console-setup.service" }?.isRunning == false)
    }

    @Test func parsesEnabledUnitFiles() {
        let files = """
        cron.service                                 enabled         enabled
        docker.service                               enabled         enabled
        smbd.service                                 disabled        disabled
        sshd.service                                 alias           -
        """
        let enabled = RemoteSystemd.parseEnabled(files)
        #expect(enabled.contains("docker.service"))
        #expect(enabled.contains("cron.service"))
        #expect(enabled.contains("smbd.service") == false)
        #expect(enabled.contains("sshd.service") == false)   // alias, não enabled
    }

    @Test func parsesAptUpgradable() {
        let out = """
        Listing...
        libssh2-1t64/resolute-updates,resolute-security 1.11.1-1ubuntu0.26.04.3 arm64 [upgradable from: 1.11.1-1ubuntu0.26.04.2]
        vim/resolute-updates,resolute-security 2:9.1.2141-1ubuntu4.7 arm64 [upgradable from: 2:9.1.2141-1ubuntu4.6]
        """
        let pkgs = RemoteApt.parseUpgradable(out)
        #expect(pkgs.count == 2)
        #expect(pkgs[0].name == "libssh2-1t64")
        #expect(pkgs[0].newVersion == "1.11.1-1ubuntu0.26.04.3")
        #expect(pkgs[0].oldVersion == "1.11.1-1ubuntu0.26.04.2")
        #expect(pkgs[1].name == "vim")
    }

    @Test func aptAndServiceParsersHandleEmpty() {
        #expect(RemoteApt.parseUpgradable("Listing...").isEmpty)
        #expect(RemoteSystemd.parseUnits("", enabled: []).isEmpty)
    }

    @Test func validatesServiceNames() {
        #expect(InputValidator.isValidServiceName("docker.service"))
        #expect(InputValidator.isValidServiceName("getty@tty1.service"))
        #expect(InputValidator.isValidServiceName("a b.service") == false)
        #expect(InputValidator.isValidServiceName("evil; rm -rf /") == false)
    }
}
