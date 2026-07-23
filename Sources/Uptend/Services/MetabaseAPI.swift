import Foundation

// =============================================================================
// METABASE API — automatiza a configuração inicial (criar a conta de admin)
// Num Metabase novo, ele expõe um `setup-token`; uma chamada a /api/setup cria o
// admin e finaliza a configuração — sem abrir o navegador. Se já estiver
// configurado, o token some e não há o que fazer.
// Só faz chamadas HTTP ao Metabase self-hosted (confiável) — nada externo.
// =============================================================================

enum MetabaseAPI {
    enum APIError: LocalizedError {
        case unreachable
        case alreadyConfigured
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .unreachable: "Não consegui falar com o Metabase nesse endereço. Ele está no ar?"
            case .alreadyConfigured: "Este Metabase já tem uma conta de administrador (não é novo)."
            case .failed(let m): "O Metabase recusou a configuração: \(m)"
            }
        }
    }

    /// Token de setup (só existe num Metabase novo). nil = já configurado.
    static func setupToken(baseURL: URL) async throws -> String? {
        let url = baseURL.appendingPathComponent("api/session/properties")
        do {
            let (data, resp) = try await URLSession.shared.data(from: url)
            guard (resp as? HTTPURLResponse)?.statusCode == 200,
                  let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw APIError.unreachable
            }
            return obj["setup-token"] as? String
        } catch let e as APIError {
            throw e
        } catch {
            throw APIError.unreachable
        }
    }

    /// Cria a conta de admin e finaliza o setup. Retorna o id de sessão.
    @discardableResult
    static func createAdmin(baseURL: URL, token: String, email: String, password: String,
                            firstName: String = "Admin", lastName: String = "Uptend",
                            siteName: String = "Uptend") async throws -> String {
        let url = baseURL.appendingPathComponent("api/setup")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "token": token,
            "user": ["first_name": firstName, "last_name": lastName, "email": email,
                     "password": password, "site_name": siteName],
            "prefs": ["site_name": siteName, "allow_tracking": false],
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.failed("sem resposta") }
        guard http.statusCode == 200 || http.statusCode == 201 else {
            throw APIError.failed(metabaseError(data) ?? "código \(http.statusCode)")
        }
        let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        return (obj?["id"] as? String) ?? ""
    }

    /// Autentica e devolve o id de sessão (para abrir o painel já logado).
    static func login(baseURL: URL, email: String, password: String) async throws -> String {
        let url = baseURL.appendingPathComponent("api/session")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["username": email, "password": password])
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw APIError.unreachable }
            guard http.statusCode == 200 || http.statusCode == 201 else {
                throw APIError.failed(metabaseError(data) ?? "login recusado (código \(http.statusCode))")
            }
            guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let id = obj["id"] as? String else {
                throw APIError.failed("resposta de login inesperada")
            }
            return id
        } catch let e as APIError {
            throw e
        } catch {
            throw APIError.unreachable
        }
    }

    /// Cookie de sessão do Metabase, para a WebView abrir já autenticada.
    static func sessionCookie(baseURL: URL, sessionID: String) -> HTTPCookie? {
        guard let host = baseURL.host else { return nil }
        return HTTPCookie(properties: [
            .name: "metabase.SESSION",
            .value: sessionID,
            .domain: host,
            .path: "/",
        ])
    }

    /// Metabase devolve erros no formato {"errors":{"campo":"mensagem"}} — extrai algo legível.
    private static func metabaseError(_ data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let errors = obj["errors"] as? [String: Any], let first = errors.values.first {
            return String(describing: first)
        }
        return obj["message"] as? String
    }

    /// Senha forte para a conta de admin (letras maiúsc./minúsc., dígitos e símbolos).
    static func strongPassword(length: Int = 20) -> String {
        let sets = ["ABCDEFGHJKLMNPQRSTUVWXYZ", "abcdefghijkmnpqrstuvwxyz", "23456789", "!@#$%*-_"]
        var rng = SystemRandomNumberGenerator()
        var chars: [Character] = sets.map { $0.randomElement(using: &rng)! }   // garante 1 de cada
        let all = Array(sets.joined())
        while chars.count < length { chars.append(all.randomElement(using: &rng)!) }
        return String(chars.shuffled(using: &rng))
    }
}

// MARK: - Credenciais do Metabase no Keychain (um item por endereço)

enum MetabaseCredentials {
    private static let service = "uptend.metabase.admin"

    struct Cred: Codable, Equatable { let email: String; let password: String }

    static func save(baseURL: String, email: String, password: String) {
        guard let data = try? JSONEncoder().encode(Cred(email: email, password: password)),
              let json = String(data: data, encoding: .utf8) else { return }
        _ = Keychain.set(json, service: service, account: baseURL)   // atualiza (não duplica)
    }

    static func load(baseURL: String) -> Cred? {
        guard let json = Keychain.get(service: service, account: baseURL),
              let data = json.data(using: .utf8),
              let cred = try? JSONDecoder().decode(Cred.self, from: data) else { return nil }
        return cred
    }

    static func delete(baseURL: String) {
        _ = Keychain.delete(service: service, account: baseURL)
    }
}
