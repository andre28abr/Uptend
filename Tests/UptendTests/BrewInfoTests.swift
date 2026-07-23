import Testing
import Foundation
@testable import Uptend

struct BrewInfoTests {

    @Test func parsesFormulaInfo() {
        let json = """
        {"formulae":[{"full_name":"wget","desc":"Internet file retriever",
          "homepage":"https://www.gnu.org/software/wget/","license":"GPL-3.0-or-later",
          "dependencies":["libidn2","openssl@3"],"versions":{"stable":"1.24.5"},"caveats":null}],
          "casks":[]}
        """
        let info = BrewService.parseInfo(Data(json.utf8), token: "wget", isCask: false)
        #expect(info?.name == "wget")
        #expect(info?.description == "Internet file retriever")
        #expect(info?.version == "1.24.5")
        #expect(info?.license == "GPL-3.0-or-later")
        #expect(info?.dependencies == ["libidn2", "openssl@3"])
    }

    @Test func parsesCaskInfo() {
        let json = """
        {"formulae":[],"casks":[{"token":"vlc","name":["VLC media player"],
          "desc":"Multimedia player","homepage":"https://www.videolan.org/vlc/",
          "version":"3.0.20","caveats":null}]}
        """
        let info = BrewService.parseInfo(Data(json.utf8), token: "vlc", isCask: true)
        #expect(info?.name == "VLC media player")
        #expect(info?.description == "Multimedia player")
        #expect(info?.version == "3.0.20")
        #expect(info?.dependencies.isEmpty == true)
    }

    @Test func handlesMissingFieldsAndGarbage() {
        // Fórmula sem desc/licença.
        let sparse = "{\"formulae\":[{\"full_name\":\"x\",\"versions\":{}}],\"casks\":[]}"
        let info = BrewService.parseInfo(Data(sparse.utf8), token: "x", isCask: false)
        #expect(info?.description == "Sem descrição.")
        #expect(info?.version == "—")
        // Lixo → nil.
        #expect(BrewService.parseInfo(Data("lixo".utf8), token: "x", isCask: false) == nil)
        // Pediu cask mas só veio fórmula → nil.
        #expect(BrewService.parseInfo(Data(sparse.utf8), token: "x", isCask: true) == nil)
    }

    // MARK: Taps

    @Test func parsesTapFormulaeAndCasks() {
        let json = """
        [{"name":"andre28abr/peapod","user":"andre28abr","repo":"peapod",
          "formula_names":["peapod","banana"],"cask_tokens":["peapod-gui"]}]
        """
        let names = BrewService.parseTapFormulae(json)
        #expect(names == ["banana", "peapod", "peapod-gui"])   // alfabético
    }

    @Test func parseTapFormulaeStripsOwnerRepoPrefix() {
        // Alguns taps reportam o nome qualificado; guardamos só a folha.
        let json = "[{\"name\":\"a/b\",\"formula_names\":[\"a/b/peapod\"],\"cask_tokens\":[]}]"
        #expect(BrewService.parseTapFormulae(json) == ["peapod"])
    }

    @Test func parseTapFormulaeHandlesEmptyAndGarbage() {
        #expect(BrewService.parseTapFormulae("[]").isEmpty)
        #expect(BrewService.parseTapFormulae("lixo").isEmpty)
        #expect(BrewService.parseTapFormulae("[{\"name\":\"a/b\"}]").isEmpty)
    }

    @Test func detectsTrustRequirementFromLog() {
        #expect(BrewService.logSuggestsTrust("Error: Tap andre28abr/peapod is not trusted. Run brew trust ...") == true)
        #expect(BrewService.logSuggestsTrust("Untrusted tap; refusing to install.") == true)
        #expect(BrewService.logSuggestsTrust("==> Installing peapod\nPouring...") == false)
    }

    // MARK: Nomes de app de um cask (para marcar procedência na aba Aplicativos)

    @Test func parsesCaskAppArtifacts() {
        let json = """
        {"casks":[{"token":"peapod","artifacts":[
          {"app":["Peapod.app"]},
          {"zap":[{"trash":["~/Library/Caches/peapod"]}]}
        ]}]}
        """
        #expect(BrewService.parseCaskAppNames(Data(json.utf8)) == ["Peapod.app"])
    }

    @Test func parseCaskAppNamesIgnoresNonStringAndGarbage() {
        // Entrada com {"target":...} junto do nome — só o nome (string) conta.
        let json = "{\"casks\":[{\"artifacts\":[{\"app\":[\"Foo.app\",{\"target\":\"Bar.app\"}]}]}]}"
        #expect(BrewService.parseCaskAppNames(Data(json.utf8)) == ["Foo.app"])
        #expect(BrewService.parseCaskAppNames(Data("lixo".utf8)).isEmpty)
        #expect(BrewService.parseCaskAppNames(Data("{\"casks\":[]}".utf8)).isEmpty)
    }

    @Test func normalizesAppNameForMatching() {
        #expect(BrewService.normalizeAppName("Peapod.app") == "peapod")
        #expect(BrewService.normalizeAppName("VLC") == "vlc")
        #expect(BrewService.normalizeAppName("  Foo.app ") == "foo")
    }
}
