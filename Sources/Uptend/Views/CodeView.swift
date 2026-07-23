import SwiftUI

/// Mostra código com realce de sintaxe e (opcional) números de linha. Só leitura.
/// A gutter de números e o código usam a mesma fonte monoespaçada, então as linhas
/// alinham verticalmente; o conteúdo não quebra linha e rola na horizontal.
struct CodeView: View {
    let code: String
    let language: String
    var showLineNumbers = true
    var maxLines = 6000

    private var lines: ArraySlice<Substring> {
        let all = code.split(separator: "\n", omittingEmptySubsequences: false)
        return all.prefix(maxLines)
    }
    private var truncated: Bool {
        code.split(separator: "\n", omittingEmptySubsequences: false).count > maxLines
    }

    private var highlighted: AttributedString {
        let joined = lines.joined(separator: "\n")
        return CodeHighlighter.highlight(String(joined), language: language)
    }
    private var gutter: String {
        (1...max(lines.count, 1)).map(String.init).joined(separator: "\n")
    }

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            HStack(alignment: .top, spacing: 12) {
                if showLineNumbers {
                    Text(gutter)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.trailing)
                }
                Text(highlighted)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }
            .fixedSize(horizontal: true, vertical: true)
            .padding(12)
        }
        .overlay(alignment: .bottom) {
            if truncated {
                Text("Arquivo grande — mostrando as primeiras \(maxLines) linhas.")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(6).background(.thinMaterial, in: Capsule()).padding(6)
            }
        }
    }
}
