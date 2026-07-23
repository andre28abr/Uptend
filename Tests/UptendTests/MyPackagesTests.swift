import Testing
import Foundation
@testable import Uptend

struct MyPackagesTests {

    @Test func validPackagePasses() {
        let p = MyPackage(name: "Peapod", tap: "andre28abr/peapod", formula: "peapod")
        #expect(p.isValid)
        #expect(p.qualified == "andre28abr/peapod/peapod")
        #expect(p.id == "andre28abr/peapod/peapod")
    }

    @Test func invalidPackagesRejected() {
        #expect(MyPackage(name: "", tap: "andre28abr/peapod", formula: "peapod").isValid == false)      // sem nome
        #expect(MyPackage(name: "X", tap: "sembarra", formula: "peapod").isValid == false)              // tap sem owner/repo
        #expect(MyPackage(name: "X", tap: "andre28abr/peapod", formula: "--force").isValid == false)    // fórmula perigosa
        #expect(MyPackage(name: "X", tap: "a/b/c", formula: "peapod").isValid == false)                 // barra extra
        #expect(MyPackage(name: "X", tap: "../etc/peapod", formula: "peapod").isValid == false)         // path traversal
    }

    @Test func encodeDecodeRoundTrips() {
        let list = [
            MyPackage(name: "Peapod", tap: "andre28abr/peapod", formula: "peapod", note: "meu app"),
            MyPackage(name: "Banana", tap: "andre28abr/banana", formula: "banana"),
        ]
        let data = MyPackagesStore.encode(list)
        #expect(MyPackagesStore.decode(data) == list)
    }

    @Test func decodeFiltersInvalidAndHandlesNil() {
        #expect(MyPackagesStore.decode(nil).isEmpty)
        #expect(MyPackagesStore.decode(Data("lixo".utf8)).isEmpty)
        // Um item inválido embutido no JSON é descartado na decodificação.
        let bad = MyPackage(name: "X", tap: "sembarra", formula: "peapod")
        let good = MyPackage(name: "Ok", tap: "a/b", formula: "peapod")
        let decoded = MyPackagesStore.decode(MyPackagesStore.encode([bad, good]))
        #expect(decoded == [good])
    }

    @MainActor
    @Test func storeAddDedupAndRemove() {
        let suite = UserDefaults(suiteName: "uptend.tests.\(UUID().uuidString)")!
        let store = MyPackagesStore(defaults: suite)
        #expect(store.packages.isEmpty)

        let p = MyPackage(name: "Peapod", tap: "andre28abr/peapod", formula: "peapod")
        #expect(store.add(p) == true)
        #expect(store.add(p) == false)                                   // duplicado
        #expect(store.add(MyPackage(name: "", tap: "a/b", formula: "x")) == false)  // inválido
        #expect(store.packages.count == 1)

        // Persistência: uma nova store lê o que foi salvo.
        let reloaded = MyPackagesStore(defaults: suite)
        #expect(reloaded.packages == [p])

        store.remove(p)
        #expect(store.packages.isEmpty)
    }

    @MainActor
    @Test func storeSortsByName() {
        let suite = UserDefaults(suiteName: "uptend.tests.\(UUID().uuidString)")!
        let store = MyPackagesStore(defaults: suite)
        store.add(MyPackage(name: "Zebra", tap: "a/z", formula: "zebra"))
        store.add(MyPackage(name: "abacate", tap: "a/ab", formula: "abacate"))
        #expect(store.packages.map(\.name) == ["abacate", "Zebra"])
    }

    // MARK: Descoberta de taps por conta

    @Test func recognizesHomebrewTapRepos() {
        #expect(TapDiscovery.isTapRepo("homebrew-peapod"))
        #expect(TapDiscovery.isTapRepo("Homebrew-Peapod"))       // sem diferenciar caixa
        #expect(TapDiscovery.isTapRepo("peapod") == false)       // repo comum
        #expect(TapDiscovery.isTapRepo("homebrew-") == false)    // sem nome depois do prefixo
    }

    @Test func buildsTapNameFromRepo() {
        #expect(TapDiscovery.tapName(owner: "andre28abr", repo: "homebrew-peapod") == "andre28abr/peapod")
    }

    @Test func extractsRecipeNamesFromFiles() {
        let files = ["peapod.rb", "banana.rb", "README.md", ".gitignore", "notes.txt"]
        #expect(TapDiscovery.recipeNames(fromFiles: files) == ["banana", "peapod"])   // só .rb, alfabético
        #expect(TapDiscovery.recipeNames(fromFiles: []).isEmpty)
    }

    @MainActor
    @Test func providersStoreUpsertRemoveAndPrograms() {
        let suite = UserDefaults(suiteName: "uptend.tests.\(UUID().uuidString)")!
        let store = TapProvidersStore(defaults: suite)
        let p = TapProvider(user: "andre28abr", tapCount: 2, programs: [
            TapProgram(name: "peapod", tap: "andre28abr/peapod", isCask: false),
            TapProgram(name: "banana", tap: "andre28abr/banana", isCask: false),
        ])
        store.upsert(p)
        #expect(store.contains("Andre28abr"))             // sem diferenciar caixa
        #expect(store.allPrograms.count == 2)

        // Reverificar (upsert de novo) substitui, não duplica.
        store.upsert(TapProvider(user: "andre28abr", tapCount: 1, programs: [
            TapProgram(name: "peapod", tap: "andre28abr/peapod", isCask: false),
        ]))
        #expect(store.providers.count == 1)
        #expect(store.allPrograms.count == 1)

        // Persiste entre instâncias.
        let reloaded = TapProvidersStore(defaults: suite)
        #expect(reloaded.providers.count == 1)

        store.remove("andre28abr")
        #expect(store.providers.isEmpty)
    }

    @Test func searchResultOwnerAndIdentity() {
        let core = SearchResult(name: "wget", isCask: false)
        #expect(core.owner == nil)
        let mine = SearchResult(name: "peapod", isCask: false, tap: "andre28abr/peapod")
        #expect(mine.owner == "andre28abr")
        #expect(core.id != mine.id)                       // origem diferente → id diferente
    }
}
