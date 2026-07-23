import Foundation

// MARK: - Programa de uma fonte de terceiros

/// Um programa (fórmula ou cask) oferecido por um tap de terceiros do Homebrew.
struct TapProgram: Codable, Hashable, Identifiable {
    let name: String       // nome da fórmula/cask (folha, ex.: "peapod")
    let tap: String        // fonte no formato owner/repo (ex.: "andre28abr/peapod")
    let isCask: Bool

    var id: String { "\(tap)/\(name)" + (isCask ? "#cask" : "") }
    var qualified: String { "\(tap)/\(name)" }
    var owner: String { String(tap.split(separator: "/").first ?? "") }

    var isValid: Bool {
        InputValidator.isValidRepoFullName(tap) && InputValidator.isValidBrewToken(name)
    }
}

/// Uma conta do GitHub tratada como provedora de fontes Homebrew: agrega os
/// programas de todos os repositórios `homebrew-*` daquele usuário.
struct TapProvider: Codable, Hashable, Identifiable {
    let user: String              // login do GitHub (ex.: "andre28abr")
    var tapCount: Int             // quantos repositórios homebrew-* foram achados
    var programs: [TapProgram]    // todos os programas, de todas as fontes do usuário

    var id: String { user }
    var programCount: Int { programs.count }
}

/// Funções puras da descoberta de taps a partir de uma conta do GitHub. Sem rede,
/// para poderem ser testadas isoladamente (o `GitHubService` faz as chamadas).
enum TapDiscovery {
    private static let prefix = "homebrew-"

    /// Um repositório é uma fonte Homebrew quando se chama `homebrew-<algo>`.
    static func isTapRepo(_ repoName: String) -> Bool {
        repoName.lowercased().hasPrefix(prefix) && repoName.count > prefix.count
    }

    /// Converte o nome do repositório na "fonte" (tap): `homebrew-peapod` → `owner/peapod`.
    static func tapName(owner: String, repo: String) -> String {
        "\(owner)/\(String(repo.dropFirst(prefix.count)))"
    }

    /// Extrai os nomes das fórmulas/casks a partir dos arquivos `.rb` de uma pasta.
    static func recipeNames(fromFiles files: [String]) -> [String] {
        files.filter { $0.hasSuffix(".rb") }
            .map { String($0.dropLast(3)) }
            .filter { !$0.isEmpty }
            .sorted { $0.lowercased() < $1.lowercased() }
    }
}

// MARK: - "Meus programas" (favoritos, 1 clique)

/// Um programa pessoal favoritado, guardado localmente (só nomes, nada sensível).
struct MyPackage: Identifiable, Codable, Hashable {
    var name: String
    var tap: String
    var formula: String
    var note: String = ""
    var isCask: Bool = false

    var id: String { tap + "/" + formula }
    var qualified: String { "\(tap)/\(formula)" }

    var isValid: Bool {
        InputValidator.isValidRepoFullName(tap)
            && InputValidator.isValidBrewToken(formula)
            && !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

/// Lista curada de "Meus programas", editável na interface e guardada em UserDefaults.
@MainActor
final class MyPackagesStore: ObservableObject {
    @Published private(set) var packages: [MyPackage] = []

    private let key = "uptend.mypackages"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        packages = Self.decode(defaults.data(forKey: key))
    }

    @discardableResult
    func add(_ package: MyPackage) -> Bool {
        guard package.isValid, !packages.contains(where: { $0.id == package.id }) else { return false }
        packages.append(package)
        packages.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        save()
        return true
    }

    func remove(_ package: MyPackage) {
        packages.removeAll { $0.id == package.id }
        save()
    }

    private func save() { defaults.set(Self.encode(packages), forKey: key) }

    nonisolated static func encode(_ list: [MyPackage]) -> Data {
        (try? JSONEncoder().encode(list)) ?? Data()
    }
    nonisolated static func decode(_ data: Data?) -> [MyPackage] {
        guard let data, let list = try? JSONDecoder().decode([MyPackage].self, from: data) else { return [] }
        return list.filter { $0.isValid }
    }
}

// MARK: - Provedores (contas do GitHub) adicionados

/// Contas do GitHub que o usuário adicionou como fontes. Guarda os programas
/// descobertos (cache local) para a busca geral poder incluí-los mesmo offline.
@MainActor
final class TapProvidersStore: ObservableObject {
    @Published private(set) var providers: [TapProvider] = []

    private let key = "uptend.tapproviders"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        providers = Self.decode(defaults.data(forKey: key))
    }

    /// Todos os programas de todas as contas adicionadas (para a busca geral).
    var allPrograms: [TapProgram] { providers.flatMap(\.programs) }

    /// Adiciona ou atualiza um provedor (re-descoberto).
    func upsert(_ provider: TapProvider) {
        providers.removeAll { $0.user.lowercased() == provider.user.lowercased() }
        providers.append(provider)
        providers.sort { $0.user.localizedCaseInsensitiveCompare($1.user) == .orderedAscending }
        save()
    }

    func remove(_ user: String) {
        providers.removeAll { $0.user.lowercased() == user.lowercased() }
        save()
    }

    func contains(_ user: String) -> Bool {
        providers.contains { $0.user.lowercased() == user.lowercased() }
    }

    private func save() { defaults.set(Self.encode(providers), forKey: key) }

    nonisolated static func encode(_ list: [TapProvider]) -> Data {
        (try? JSONEncoder().encode(list)) ?? Data()
    }
    nonisolated static func decode(_ data: Data?) -> [TapProvider] {
        guard let data, let list = try? JSONDecoder().decode([TapProvider].self, from: data) else { return [] }
        // Filtra programas inválidos (consistente com MyPackagesStore/HostStore) — evita
        // que um UserDefaults adulterado injete tokens inválidos na busca geral.
        return list.map { TapProvider(user: $0.user, tapCount: $0.tapCount, programs: $0.programs.filter(\.isValid)) }
    }
}
