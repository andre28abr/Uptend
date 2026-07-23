import Foundation
import SwiftUI

/// Conta conectada do GitHub (dados públicos do usuário autenticado).
struct GitHubAccount: Codable, Equatable {
    let login: String
    let name: String?
    let avatarURL: String?
    let htmlURL: String?

    enum CodingKeys: String, CodingKey {
        case login, name
        case avatarURL = "avatar_url"
        case htmlURL = "html_url"
    }
}

/// Um repositório da conta (inclui privados).
struct GitHubRepo: Codable, Identifiable, Hashable {
    let name: String
    let fullName: String
    let isPrivate: Bool
    let description: String?
    let htmlURL: String
    let cloneURL: String
    let defaultBranch: String
    let updatedAt: String?
    let fork: Bool

    var id: String { fullName }

    enum CodingKeys: String, CodingKey {
        case name, description, fork
        case fullName = "full_name"
        case isPrivate = "private"
        case htmlURL = "html_url"
        case cloneURL = "clone_url"
        case defaultBranch = "default_branch"
        case updatedAt = "updated_at"
    }
}

/// Conecta a conta do GitHub via token pessoal (guardado no Keychain), lista os
/// repositórios (inclusive privados) e clona para uma pasta local.
///
/// Privacy by Design: nenhuma chamada de rede acontece sozinha — só quando o
/// usuário conecta, atualiza a lista ou clona. Sem telemetria.
@MainActor
final class GitHubService: ObservableObject {
    @Published var account: GitHubAccount?
    @Published var repos: [GitHubRepo] = []
    @Published var connecting = false
    @Published var restoring = false
    @Published var loadingRepos = false
    @Published var lastError: String?
    /// Caminho recém-clonado, para a UI oferecer "monitorar esta pasta".
    @Published var lastClonedPath: String?

    @Published var publishing = false
    @Published var publishedURL: String?

    var isConnected: Bool { account != nil }
    var hasToken: Bool { GitAuth.currentToken() != nil }

    private let apiBase = "https://api.github.com"
    private let accountKey = "uptend.github.account"

    init() {
        // Restaura a identidade do CACHE LOCAL (sem rede). A validação online só
        // acontece quando o usuário conecta ou atualiza — Privacy by Design:
        // nenhuma chamada de rede acontece sozinha no launch.
        if hasToken { account = cachedAccount() }
    }

    // MARK: - Conectar / desconectar

    /// Valida o token contra a API e, se ok, guarda no Keychain e carrega a conta.
    func connect(token rawToken: String) async {
        let token = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard InputValidator.isValidGitHubToken(token) else {
            lastError = "Token inválido. Cole um token do GitHub (começa com ghp_ ou github_pat_)."
            return
        }
        connecting = true
        lastError = nil
        defer { connecting = false }

        do {
            let user = try await fetchUser(token: token)
            guard Keychain.set(token, service: GitAuth.keychainService, account: GitAuth.keychainAccount) else {
                lastError = "Não foi possível guardar o token no Keychain."
                return
            }
            account = user
            cacheAccount(user)
            ActionLog.shared.record("GitHub conectado: @\(user.login)")
        } catch let error as GitHubError {
            lastError = error.message
        } catch {
            lastError = "Falha ao conectar: \(error.localizedDescription)"
        }
    }

    /// Se há um token salvo mas a identidade não está carregada (ex.: conectou antes
    /// do cache existir), recarrega os dados da conta pela API. Chamado ao abrir a tela
    /// da conta — ação explícita do usuário.
    func restoreIdentityIfNeeded() async {
        guard account == nil, let token = GitAuth.currentToken() else { return }
        restoring = true
        lastError = nil
        defer { restoring = false }
        do {
            let user = try await fetchUser(token: token)
            account = user
            cacheAccount(user)
        } catch let error as GitHubError {
            lastError = error.message   // ex.: 401 → token expirado
        } catch {
            lastError = "Não foi possível reconectar: \(error.localizedDescription)"
        }
    }

    func disconnect() {
        Keychain.delete(service: GitAuth.keychainService, account: GitAuth.keychainAccount)
        account = nil
        cacheAccount(nil)
        repos = []
        lastClonedPath = nil
        lastError = nil
        ActionLog.shared.record("GitHub desconectado")
    }

    // Cache local da identidade pública (login/nome/avatar) — nada secreto.
    private func cacheAccount(_ acc: GitHubAccount?) {
        if let acc, let data = try? JSONEncoder().encode(acc) {
            UserDefaults.standard.set(data, forKey: accountKey)
        } else {
            UserDefaults.standard.removeObject(forKey: accountKey)
        }
    }
    private func cachedAccount() -> GitHubAccount? {
        guard let data = UserDefaults.standard.data(forKey: accountKey) else { return nil }
        return try? JSONDecoder().decode(GitHubAccount.self, from: data)
    }

    // MARK: - Repositórios

    func loadRepos() async {
        guard let token = GitAuth.currentToken() else {
            lastError = "Conecte sua conta do GitHub primeiro."
            return
        }
        loadingRepos = true
        lastError = nil
        defer { loadingRepos = false }

        do {
            var all: [GitHubRepo] = []
            let perPage = 100
            // Percorre as páginas até esgotar (limite defensivo de 20 páginas = 2000 repos).
            for page in 1...20 {
                let path = "/user/repos?per_page=\(perPage)&page=\(page)&affiliation=owner,collaborator,organization_member&sort=updated"
                let batch: [GitHubRepo] = try await get(path, token: token)
                all.append(contentsOf: batch)
                if batch.count < perPage { break }
            }
            repos = all
        } catch let error as GitHubError {
            lastError = error.message
        } catch {
            lastError = "Falha ao carregar repositórios: \(error.localizedDescription)"
        }
    }

    // MARK: - Clonar

    /// Clona `repo` dentro da pasta `parent`, criando `parent/<nome-do-repo>`.
    /// Devolve o caminho local em caso de sucesso.
    @discardableResult
    func clone(_ repo: GitHubRepo, into parent: URL) async -> String? {
        guard InputValidator.isValidRepoFullName(repo.fullName),
              InputValidator.isValidFileName(repo.name) else {
            lastError = "Nome de repositório inesperado — clone cancelado por segurança."
            return nil
        }
        // Defesa em profundidade: só clonamos por HTTPS (evita URLs de transporte
        // do git como ext::/--upload-pack que poderiam executar comandos).
        guard repo.cloneURL.hasPrefix("https://") else {
            lastError = "URL de clone inesperada — cancelado por segurança."
            return nil
        }
        lastError = nil
        let dest = parent.appendingPathComponent(repo.name, isDirectory: true)
        if FileManager.default.fileExists(atPath: dest.path) {
            lastError = "Já existe uma pasta \"\(repo.name)\" em \(parent.path)."
            return nil
        }

        let env = GitAuth.env(token: GitAuth.currentToken())
        let result = await Shell.capture("/usr/bin/git",
            ["clone", repo.cloneURL, dest.path], env: env)
        guard result.ok else {
            let msg = result.stderr.isEmpty ? result.stdout : result.stderr
            lastError = "Falha ao clonar \(repo.name): " + msg.trimmingCharacters(in: .whitespacesAndNewlines)
            return nil
        }
        lastClonedPath = dest.path
        ActionLog.shared.record("Clonado: \(repo.fullName) → \(dest.path)")
        return dest.path
    }

    // MARK: - Publicar (criar repo de uma pasta local)

    /// Cria o repositório no GitHub e faz o primeiro push da pasta local.
    func publish(folderPath: String, name rawName: String, isPrivate: Bool, description: String) async {
        let name = rawName.trimmingCharacters(in: .whitespaces)
        guard let token = GitAuth.currentToken() else { lastError = "Conecte sua conta do GitHub primeiro."; return }
        guard InputValidator.isValidFileName(name) else {
            lastError = "Nome inválido. Use letras, números, ponto, hífen ou sublinhado."; return
        }
        guard folderPath.hasPrefix("/"), FileManager.default.fileExists(atPath: folderPath) else {
            lastError = "Pasta inválida."; return
        }
        publishing = true
        lastError = nil
        publishedURL = nil
        defer { publishing = false }

        // 1) Cria o repositório vazio na API.
        let repo: GitHubRepo
        do {
            repo = try await post("/user/repos",
                                  body: ["name": name, "private": isPrivate, "description": description, "auto_init": false],
                                  token: token)
        } catch let error as GitHubError {
            lastError = error.message; return
        } catch {
            lastError = "Falha ao criar o repositório: \(error.localizedDescription)"; return
        }

        // 2) Git local: inicializa (se preciso), commita e faz push autenticado.
        let env = GitAuth.env(token: token)
        func git(_ args: [String]) async -> CommandResult {
            await Shell.capture("/usr/bin/git", ["-C", folderPath] + args, env: env)
        }
        if !FileManager.default.fileExists(atPath: folderPath + "/.git") {
            _ = await git(["init"])
        }
        _ = await git(["add", "-A"])
        _ = await git(["commit", "-m", "Primeiro commit (via Uptend)"])   // ok falhar se nada a commitar
        _ = await git(["branch", "-M", "main"])
        _ = await git(["remote", "remove", "origin"])                      // ignora erro se não existir
        _ = await git(["remote", "add", "origin", repo.cloneURL])
        let push = await git(["push", "-u", "origin", "main"])

        publishedURL = repo.htmlURL
        if !push.ok {
            let msg = (push.stderr.isEmpty ? push.stdout : push.stderr).trimmed
            lastError = "Repositório criado, mas o envio falhou: \(msg). Você pode enviar depois pela aba Git (adicione a pasta e use Enviar/Push)."
        }
        ActionLog.shared.record("Publicado no GitHub: \(repo.fullName)")
    }

    // MARK: - Configurações do repositório

    /// Muda visibilidade e descrição de um repositório (`PATCH /repos/{owner}/{repo}`).
    /// Requer no token a permissão "Administration: Read and write".
    @discardableResult
    func updateRepo(fullName: String, isPrivate: Bool, description: String) async -> Bool {
        guard let token = GitAuth.currentToken() else { lastError = "Conecte sua conta do GitHub primeiro."; return false }
        guard InputValidator.isValidRepoFullName(fullName) else { lastError = "Repositório inválido."; return false }
        lastError = nil
        struct Updated: Decodable { let name: String? }
        do {
            let _: Updated = try await patch("/repos/\(fullName)",
                                             body: ["private": isPrivate, "description": description], token: token)
            ToastCenter.shared.show("Repositório atualizado")
            ActionLog.shared.record("Repo atualizado: \(fullName) (privado=\(isPrivate))")
            return true
        } catch let error as GitHubError {
            lastError = "Não foi possível atualizar. \(error.message) Se for permissão, edite o token no GitHub e adicione \"Administration: Read and write\"."
            return false
        } catch {
            lastError = "Falha ao atualizar: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Chave SSH → GitHub

    /// Envia uma chave SSH pública para a conta do GitHub (`POST /user/keys`).
    /// Requer no token a permissão de contas "Git SSH keys: Read and write".
    func uploadSSHKey(_ publicKey: String, title: String) async {
        guard let token = GitAuth.currentToken() else { lastError = "Conecte sua conta do GitHub primeiro."; return }
        lastError = nil
        struct KeyResponse: Decodable { let id: Int? }
        do {
            let _: KeyResponse = try await post("/user/keys", body: ["title": title, "key": publicKey], token: token)
            ToastCenter.shared.show("Chave SSH enviada ao GitHub")
            ActionLog.shared.record("Chave SSH enviada ao GitHub: \(title)")
        } catch let error as GitHubError {
            lastError = "Não foi possível enviar a chave. \(error.message) Se for permissão, edite o token no GitHub e adicione \"Git SSH keys: Read and write\" (Account permissions)."
        } catch {
            lastError = "Falha ao enviar a chave: \(error.localizedDescription)"
        }
    }

    // MARK: - Descobrir taps de uma conta do GitHub

    @Published var discovering = false

    /// Item da API de conteúdo de um diretório de repositório (`/contents/...`).
    private struct GHContent: Decodable { let name: String; let type: String }

    /// Varre a conta `user`, acha os repositórios `homebrew-*` e lista os programas
    /// (fórmulas/casks) de cada um — sem "tapar" nada ainda. Retorna nil em erro.
    func discoverProvider(user rawUser: String) async -> TapProvider? {
        let user = rawUser.trimmingCharacters(in: .whitespaces)
        guard InputValidator.isValidGitHubUser(user) else {
            lastError = "Usuário inválido. Use o login do GitHub (letras, números e hífen)."
            return nil
        }
        discovering = true
        lastError = nil
        defer { discovering = false }

        do {
            // 1) Lista os repositórios públicos do usuário e filtra os que são taps.
            let repos: [GitHubRepo] = try await fetchPublic("/users/\(user)/repos?per_page=100&sort=updated")
            let tapRepos = repos.filter { TapDiscovery.isTapRepo($0.name) }
            guard !tapRepos.isEmpty else {
                lastError = "Nenhuma fonte Homebrew encontrada em @\(user). Fontes são repositórios chamados \"homebrew-...\"."
                return nil
            }
            // 2) Para cada tap, lê os arquivos de receita (Formula/ e Casks/).
            var programs: [TapProgram] = []
            for repo in tapRepos {
                let tap = TapDiscovery.tapName(owner: user, repo: repo.name)
                guard InputValidator.isValidRepoFullName(tap) else { continue }
                let inFormulaDir = await recipeNames(owner: user, repo: repo.name, dir: "Formula")
                let inRoot = await recipeNames(owner: user, repo: repo.name, dir: "")   // fórmulas na raiz (taps antigos)
                let formulae = inFormulaDir + inRoot
                let casks = await recipeNames(owner: user, repo: repo.name, dir: "Casks")
                for name in Set(formulae) where InputValidator.isValidBrewToken(name) {
                    programs.append(TapProgram(name: name, tap: tap, isCask: false))
                }
                for name in Set(casks) where InputValidator.isValidBrewToken(name) {
                    programs.append(TapProgram(name: name, tap: tap, isCask: true))
                }
            }
            programs.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            ActionLog.shared.record("Fontes descobertas em @\(user): \(tapRepos.count) tap(s), \(programs.count) programa(s)")
            return TapProvider(user: user, tapCount: tapRepos.count, programs: programs)
        } catch let error as GitHubError {
            lastError = error.message
            return nil
        } catch {
            lastError = "Falha ao ler a conta @\(user): \(error.localizedDescription)"
            return nil
        }
    }

    /// Nomes de receitas `.rb` numa pasta de um repositório. Pasta vazia = raiz.
    /// Erros (ex.: pasta inexistente → 404) viram lista vazia, não falham a descoberta.
    private func recipeNames(owner: String, repo: String, dir: String) async -> [String] {
        guard InputValidator.isValidGitHubUser(owner), InputValidator.isValidFileName(repo) else { return [] }
        let path = dir.isEmpty ? "/repos/\(owner)/\(repo)/contents" : "/repos/\(owner)/\(repo)/contents/\(dir)"
        guard let items: [GHContent] = try? await fetchPublic(path) else { return [] }
        return TapDiscovery.recipeNames(fromFiles: items.filter { $0.type == "file" }.map(\.name))
    }

    // MARK: - Rede (privado)

    /// GET público: usa o token se houver (limite maior e repos privados seus),
    /// senão vai anônimo (só dados públicos). Para descobrir taps de qualquer conta.
    private func fetchPublic<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: apiBase + path) else { throw GitHubError.other("URL inválida.") }
        var request = URLRequest(url: url)
        if let token = GitAuth.currentToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("Uptend", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30

        let (data, response): (Data, URLResponse)
        do { (data, response) = try await URLSession.shared.data(for: request) }
        catch { throw GitHubError.other("Sem conexão com o GitHub (\(error.localizedDescription)).") }
        guard let http = response as? HTTPURLResponse else { throw GitHubError.other("Resposta inválida.") }
        switch http.statusCode {
        case 200...299: return try JSONDecoder().decode(T.self, from: data)
        case 401: throw GitHubError.unauthorized
        case 403: throw GitHubError.forbidden
        case 404: throw GitHubError.status(404)
        default: throw GitHubError.status(http.statusCode)
        }
    }

    private func fetchUser(token: String) async throws -> GitHubAccount {
        try await get("/user", token: token)
    }

    private func post<T: Decodable>(_ path: String, body: [String: Any], token: String) async throws -> T {
        try await send("POST", path, body: body, token: token)
    }
    private func patch<T: Decodable>(_ path: String, body: [String: Any], token: String) async throws -> T {
        try await send("PATCH", path, body: body, token: token)
    }

    private func send<T: Decodable>(_ method: String, _ path: String, body: [String: Any], token: String) async throws -> T {
        guard let url = URL(string: apiBase + path) else { throw GitHubError.other("URL inválida.") }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("Uptend", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        let (data, response): (Data, URLResponse)
        do { (data, response) = try await URLSession.shared.data(for: request) }
        catch { throw GitHubError.other("Sem conexão com o GitHub (\(error.localizedDescription)).") }
        guard let http = response as? HTTPURLResponse else { throw GitHubError.other("Resposta inválida.") }
        switch http.statusCode {
        case 200...299: return try JSONDecoder().decode(T.self, from: data)
        case 401: throw GitHubError.unauthorized
        case 403: throw GitHubError.forbidden
        case 404: throw GitHubError.forbidden
        case 422: throw GitHubError.other("O GitHub recusou (422): já existe ou algum dado é inválido.")
        default: throw GitHubError.status(http.statusCode)
        }
    }

    private func get<T: Decodable>(_ path: String, token: String) async throws -> T {
        guard let url = URL(string: apiBase + path) else { throw GitHubError.other("URL inválida.") }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("Uptend", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw GitHubError.other("Sem conexão com o GitHub (\(error.localizedDescription)).")
        }
        guard let http = response as? HTTPURLResponse else { throw GitHubError.other("Resposta inválida.") }
        switch http.statusCode {
        case 200...299:
            do { return try JSONDecoder().decode(T.self, from: data) }
            catch { throw GitHubError.other("Não entendi a resposta do GitHub.") }
        case 401:
            throw GitHubError.unauthorized
        case 403:
            throw GitHubError.forbidden
        default:
            throw GitHubError.status(http.statusCode)
        }
    }
}

enum GitHubError: Error {
    case unauthorized
    case forbidden
    case status(Int)
    case other(String)

    var message: String {
        switch self {
        case .unauthorized: "Token recusado (401). Verifique se ele é válido e não expirou."
        case .forbidden: "Acesso negado ou limite de uso atingido (403). Confira as permissões do token."
        case .status(let code): "GitHub respondeu com erro (HTTP \(code))."
        case .other(let text): text
        }
    }
}
