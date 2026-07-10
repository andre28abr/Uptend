import Foundation

/// Teste de velocidade real (download/upload) usando os endpoints públicos da Cloudflare.
/// É uma ação explícita do usuário — consome banda e contata um serviço externo.
enum SpeedTest {

    /// Retorna a velocidade de download em Mbps.
    static func download(bytes: Int = 25_000_000) async -> Double? {
        guard let url = URL(string: "https://speed.cloudflare.com/__down?bytes=\(bytes)") else { return nil }
        let start = Date()
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        let elapsed = Date().timeIntervalSince(start)
        guard elapsed > 0 else { return nil }
        return Double(data.count) * 8 / elapsed / 1_000_000
    }

    /// Retorna a velocidade de upload em Mbps.
    static func upload(bytes: Int = 10_000_000) async -> Double? {
        guard let url = URL(string: "https://speed.cloudflare.com/__up") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let payload = Data(count: bytes)
        let start = Date()
        guard (try? await URLSession.shared.upload(for: request, from: payload)) != nil else { return nil }
        let elapsed = Date().timeIntervalSince(start)
        guard elapsed > 0 else { return nil }
        return Double(bytes) * 8 / elapsed / 1_000_000
    }

    static func format(_ mbps: Double) -> String {
        String(format: "%.1f Mbps", mbps)
    }
}
