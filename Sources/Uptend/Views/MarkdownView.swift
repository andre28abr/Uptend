import SwiftUI
import UptendCore
import AppKit

/// Renderiza Markdown (só leitura) a partir dos blocos do `MarkdownParser`.
/// O realce inline (negrito/itálico/código/links) vem do `AttributedString`.
struct MarkdownView: View {
    let text: String
    /// Pasta do arquivo, para resolver imagens com caminho relativo.
    var baseDir: URL?

    private var blocks: [MarkdownBlock] { MarkdownParser.parse(text) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                view(for: block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func view(for block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            inline(text)
                .font(headingFont(level))
                .fontWeight(level <= 2 ? .bold : .semibold)
                .padding(.top, level <= 2 ? 6 : 2)

        case .paragraph(let text):
            inline(text).fixedSize(horizontal: false, vertical: true)

        case .code(let language, let code):
            CodeView(code: code, language: language ?? "plain", showLineNumbers: false)
                .frame(maxHeight: 360)
                .cardBackground()

        case .bulletList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").foregroundStyle(.secondary)
                        inline(item).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .orderedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(index + 1).").foregroundStyle(.secondary).monospacedDigit()
                        inline(item).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .quote(let lines):
            HStack(spacing: 10) {
                Rectangle().fill(.secondary).frame(width: 3)
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, l in
                        inline(l).foregroundStyle(.secondary)
                    }
                }
            }

        case .rule:
            Divider().padding(.vertical, 4)

        case .table(let headers, let rows):
            tableView(headers: headers, rows: rows)

        case .image(let alt, let path):
            imageView(alt: alt, path: path)
        }
    }

    // MARK: Inline

    /// Converte texto inline (negrito/itálico/código/links) para um `Text`.
    private func inline(_ string: String) -> Text {
        if let attributed = try? AttributedString(
            markdown: string,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return Text(attributed)
        }
        return Text(string)
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: .title
        case 2: .title2
        case 3: .title3
        case 4: .headline
        default: .body
        }
    }

    // MARK: Tabela

    private func tableView(headers: [String], rows: [[String]]) -> some View {
        let columns = max(headers.count, rows.map(\.count).max() ?? 0)
        return VStack(alignment: .leading, spacing: 0) {
            tableRow(cells: headers, columns: columns, header: true)
            Divider()
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                tableRow(cells: row, columns: columns, header: false)
            }
        }
        .cardBackground()
    }

    private func tableRow(cells: [String], columns: Int, header: Bool) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<columns, id: \.self) { col in
                inline(col < cells.count ? cells[col] : "")
                    .fontWeight(header ? .semibold : .regular)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                if col < columns - 1 { Divider() }
            }
        }
    }

    // MARK: Imagem

    @ViewBuilder
    private func imageView(alt: String, path: String) -> some View {
        // Só imagens locais (privacidade: não buscamos imagens remotas automaticamente).
        if !path.hasPrefix("http"), let baseDir,
           let image = NSImage(contentsOf: baseDir.appendingPathComponent(path)) {
            VStack(alignment: .leading, spacing: 4) {
                Image(nsImage: image)
                    .resizable().scaledToFit()
                    .frame(maxWidth: 480, maxHeight: 360, alignment: .leading)
                    .cardBackground()
                if !alt.isEmpty { Text(alt).font(.caption).foregroundStyle(.secondary) }
            }
        } else {
            Label(alt.isEmpty ? path : alt, systemImage: "photo")
                .font(.callout).foregroundStyle(.secondary)
        }
    }
}
