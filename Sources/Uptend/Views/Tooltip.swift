import SwiftUI

// Tooltip customizado e rápido. O tooltip nativo do macOS demora ~1,5s e ignora
// ajustes de atraso. Aqui, cada `.tip(texto)` publica — via preference — o texto e a
// posição do item ao passar o mouse; o `.tooltipHost()` (na raiz) desenha UM tooltip
// acima de tudo, sem o recorte que um overlay comum sofreria dentro de ScrollView/List.

private struct TooltipData: Equatable {
    let text: String
    let anchor: Anchor<CGRect>
    static func == (a: TooltipData, b: TooltipData) -> Bool { a.text == b.text }
}

private struct TooltipKey: PreferenceKey {
    static let defaultValue: TooltipData? = nil
    static func reduce(value: inout TooltipData?, nextValue: () -> TooltipData?) {
        value = nextValue() ?? value
    }
}

private struct TipModifier: ViewModifier {
    let text: String
    var delay: TimeInterval = 0.18
    @State private var hovering = false
    @State private var show = false

    func body(content: Content) -> some View {
        content
            .onHover { isHovering in
                hovering = isHovering
                if isHovering {
                    Task {
                        try? await Task.sleep(for: .seconds(delay))
                        if hovering { show = true }
                    }
                } else {
                    show = false
                }
            }
            .anchorPreference(key: TooltipKey.self, value: .bounds) { anchor in
                (show && !text.isEmpty) ? TooltipData(text: text, anchor: anchor) : nil
            }
    }
}

extension View {
    /// Tooltip rápido no hover (substitui `.help` onde queremos resposta imediata).
    func tip(_ text: String, delay: TimeInterval = 0.18) -> some View {
        modifier(TipModifier(text: text, delay: delay))
    }

    /// Coloca na raiz (envolve todo o conteúdo): desenha o tooltip ativo acima de tudo.
    func tooltipHost() -> some View {
        overlayPreferenceValue(TooltipKey.self) { data in
            GeometryReader { proxy in
                if let data {
                    let rect = proxy[data.anchor]
                    // Abaixo do item; se estiver muito perto da base, mostra acima.
                    let below = rect.maxY + 30 < proxy.size.height
                    Text(data.text)
                        .font(.caption)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
                        .fixedSize()
                        .position(x: min(max(rect.midX, 90), proxy.size.width - 90),
                                  y: below ? rect.maxY + 16 : rect.minY - 14)
                        .transition(.opacity)
                }
            }
            .allowsHitTesting(false)
            .animation(.easeOut(duration: 0.1), value: data)
        }
    }
}
