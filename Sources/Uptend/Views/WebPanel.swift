import SwiftUI
import WebKit

// =============================================================================
// PAINEL EMBUTIDO — abre o painel web de um serviço self-hosted DENTRO do Uptend.
// Reutilizável para qualquer serviço do Catálogo (Metabase, Dozzle, Portainer…).
// A WebView só carrega a URL do serviço (confiável, self-hosted); + botão "Abrir no
// navegador" que sempre funciona. Nota: no app empacotado, o Info.plist libera rede
// local (NSAllowsLocalNetworking) para a WebView carregar http do servidor.
// =============================================================================

struct EmbeddedWeb: NSViewRepresentable {
    let url: URL
    /// Cookie de sessão opcional (ex.: Metabase) — instalado antes de carregar,
    /// para o painel abrir já autenticado, sem pedir login.
    var cookie: HTTPCookie? = nil

    func makeNSView(context: Context) -> WKWebView {
        let view = WKWebView(frame: .zero)
        if let cookie {
            view.configuration.websiteDataStore.httpCookieStore.setCookie(cookie) {
                view.load(URLRequest(url: url))
            }
        } else {
            view.load(URLRequest(url: url))
        }
        return view
    }
    func updateNSView(_ view: WKWebView, context: Context) {}
}

/// WebView que renderiza uma string de HTML (relatório autocontido). Não faz rede —
/// o HTML é gerado localmente (Auditoria Externa) e é 100% offline.
struct EmbeddedHTML: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView {
        let view = WKWebView(frame: .zero, configuration: ReportWindow.fullscreenConfig())
        view.loadHTMLString(html, baseURL: nil)
        return view
    }
    func updateNSView(_ view: WKWebView, context: Context) {
        view.loadHTMLString(html, baseURL: nil)
    }
}

/// Abre um relatório HTML numa JANELA NATIVA redimensionável, com o botão verde de
/// tela cheia do macOS — ideal para apresentar numa TV/monitor. (A pré-visualização
/// padrão é uma sheet, que não tem esse botão.)
enum ReportWindow {
    private static var windows: [NSWindow] = []
    private static var tokens: [ObjectIdentifier: NSObjectProtocol] = [:]

    /// Fecha o rastreio de uma janela: solta a referência do array E remove o
    /// observer (senão o NotificationCenter reteria o bloco — e, com ele, a
    /// NSWindow + WKWebView — para sempre, vazando a cada relatório aberto).
    @MainActor
    private static func untrack(_ win: NSWindow) {
        windows.removeAll { $0 === win }
        if let t = tokens.removeValue(forKey: ObjectIdentifier(win)) {
            NotificationCenter.default.removeObserver(t)
        }
    }

    /// Config do WKWebView com tela-cheia de elemento habilitada (para o botão do dashboard).
    static func fullscreenConfig() -> WKWebViewConfiguration {
        let cfg = WKWebViewConfiguration()
        if #available(macOS 12.3, *) { cfg.preferences.isElementFullscreenEnabled = true }
        return cfg
    }

    @MainActor
    static func open(html: String, title: String) {
        let web = WKWebView(frame: NSRect(x: 0, y: 0, width: 1280, height: 840),
                            configuration: fullscreenConfig())
        web.loadHTMLString(html, baseURL: nil)
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1280, height: 840),
                           styleMask: [.titled, .closable, .miniaturizable, .resizable],
                           backing: .buffered, defer: false)
        win.title = title
        win.collectionBehavior.insert(.fullScreenPrimary)   // habilita o botão verde → tela cheia
        win.contentView = web
        win.center()
        win.isReleasedWhenClosed = false
        win.tabbingMode = .disallowed
        windows.append(win)
        tokens[ObjectIdentifier(win)] = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: win, queue: .main) { _ in
            MainActor.assumeIsolated { untrack(win) }
        }
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// Converte um relatório HTML (autocontido) em PDF, usando o próprio motor do WebKit
/// (`createPDF`). Tudo local/offline. Mantém-se vivo até terminar via `active`.
final class HTMLToPDF: NSObject, WKNavigationDelegate {
    private static var active: Set<HTMLToPDF> = []
    private var webView: WKWebView?
    private var completion: ((Data?) -> Void)?

    /// Renderiza `html` e devolve os bytes do PDF (nil em caso de erro). Chame na main thread.
    static func render(html: String, completion: @escaping (Data?) -> Void) {
        let r = HTMLToPDF()
        r.completion = completion
        active.insert(r)
        let wv = WKWebView(frame: NSRect(x: 0, y: 0, width: 820, height: 1160))
        wv.navigationDelegate = r
        r.webView = wv
        wv.loadHTMLString(html, baseURL: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Pequeno atraso para o layout/SVG assentarem antes de "imprimir".
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            webView.createPDF(configuration: WKPDFConfiguration()) { result in
                switch result {
                case .success(let data): self?.done(data)
                case .failure: self?.done(nil)
                }
            }
        }
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { done(nil) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { done(nil) }

    private func done(_ data: Data?) {
        completion?(data)
        completion = nil
        webView = nil
        HTMLToPDF.active.remove(self)
    }
}

/// Folha que mostra o painel do serviço embutido, com recarregar e "abrir no navegador".
struct ServicePanelSheet: View {
    let title: String
    let url: URL
    /// Sessão já autenticada (opcional) — abre o painel sem pedir login.
    var sessionCookie: HTTPCookie? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var reloadID = UUID()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(title).font(.headline)
                Text(url.absoluteString).font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
                Spacer()
                if sessionCookie != nil {
                    Label("Sessão automática", systemImage: "lock.open.fill")
                        .font(.caption).foregroundStyle(.green)
                }
                IconButton(systemImage: "arrow.clockwise", help: "Recarregar") { reloadID = UUID() }
                Button { NSWorkspace.shared.open(url) } label: {
                    Label("Abrir no navegador", systemImage: "arrow.up.right.square")
                }
                Button("Fechar") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            .padding(12)
            Divider()
            EmbeddedWeb(url: url, cookie: sessionCookie).id(reloadID)
        }
        .frame(minWidth: 900, idealWidth: 1100, minHeight: 600, idealHeight: 760)
    }
}

/// Alvo para abrir um painel de serviço (usado em `.sheet(item:)`).
struct PanelTarget: Identifiable {
    let id = UUID()
    let title: String
    let url: URL
}
