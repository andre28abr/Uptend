import Foundation

/// Bloco de Markdown reconhecido pelo parser. O realce inline (negrito, itálico,
/// código, links) é resolvido na hora de renderizar, via `AttributedString`.
public enum MarkdownBlock: Equatable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case code(language: String?, code: String)
    case bulletList([String])
    case orderedList([String])
    case quote([String])
    case rule
    case table(headers: [String], rows: [[String]])
    case image(alt: String, path: String)
}

/// Parser de Markdown em nível de bloco (nativo, sem dependências). Cobre o que
/// aparece em READMEs: títulos, parágrafos, listas, código cercado, citações,
/// linhas horizontais, tabelas (GFM) e imagens em linha própria.
public enum MarkdownParser {

    public static func parse(_ text: String) -> [MarkdownBlock] {
        let lines = text.components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var i = 0

        func isRule(_ s: String) -> Bool {
            let t = s.trimmingCharacters(in: .whitespaces)
            return ["---", "***", "___"].contains { t.count >= 3 && Set(t) == Set($0) }
        }
        func isTableSeparator(_ s: String) -> Bool {
            let t = s.trimmingCharacters(in: .whitespaces)
            guard t.contains("|") || t.contains("-") else { return false }
            let cells = t.split(separator: "|", omittingEmptySubsequences: true)
            guard !cells.isEmpty else { return false }
            return cells.allSatisfy { cell in
                let c = cell.trimmingCharacters(in: .whitespaces)
                return !c.isEmpty && c.allSatisfy { $0 == "-" || $0 == ":" }
            }
        }
        func splitRow(_ s: String) -> [String] {
            var row = s.trimmingCharacters(in: .whitespaces)
            if row.hasPrefix("|") { row.removeFirst() }
            if row.hasSuffix("|") { row.removeLast() }
            return row.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        }

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Linha em branco
            if trimmed.isEmpty { i += 1; continue }

            // Código cercado ``` ou ~~~
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                let fence = String(trimmed.prefix(3))
                let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var code: [String] = []
                i += 1
                while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix(fence) {
                    code.append(lines[i]); i += 1
                }
                if i < lines.count { i += 1 }   // pula a cerca de fechamento
                blocks.append(.code(language: lang.isEmpty ? nil : lang, code: code.joined(separator: "\n")))
                continue
            }

            // Linha horizontal
            if isRule(trimmed) { blocks.append(.rule); i += 1; continue }

            // Título ATX
            if trimmed.hasPrefix("#") {
                let hashes = trimmed.prefix { $0 == "#" }.count
                if hashes <= 6, trimmed.dropFirst(hashes).first == " " {
                    let content = trimmed.dropFirst(hashes).trimmingCharacters(in: .whitespaces)
                    blocks.append(.heading(level: hashes, text: content))
                    i += 1; continue
                }
            }

            // Imagem em linha própria: ![alt](path)
            if trimmed.hasPrefix("!["), let img = parseImage(trimmed) {
                blocks.append(.image(alt: img.alt, path: img.path)); i += 1; continue
            }

            // Tabela (linha com | seguida de linha separadora com o MESMO número de
            // células — como no GFM; senão "parágrafo com |" + "---" viraria tabela)
            if trimmed.contains("|"), i + 1 < lines.count, isTableSeparator(lines[i + 1]),
               splitRow(lines[i + 1]).count == splitRow(line).count {
                let headers = splitRow(line)
                var rows: [[String]] = []
                i += 2
                while i < lines.count && lines[i].contains("|") &&
                        !lines[i].trimmingCharacters(in: .whitespaces).isEmpty {
                    rows.append(splitRow(lines[i])); i += 1
                }
                blocks.append(.table(headers: headers, rows: rows))
                continue
            }

            // Citação
            if trimmed.hasPrefix(">") {
                var quote: [String] = []
                while i < lines.count && lines[i].trimmingCharacters(in: .whitespaces).hasPrefix(">") {
                    let q = lines[i].trimmingCharacters(in: .whitespaces)
                    quote.append(String(q.dropFirst()).trimmingCharacters(in: .whitespaces))
                    i += 1
                }
                blocks.append(.quote(quote)); continue
            }

            // Lista não ordenada
            if isBullet(trimmed) {
                var items: [String] = []
                while i < lines.count, isBullet(lines[i].trimmingCharacters(in: .whitespaces)) {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    items.append(String(t.dropFirst(2)).trimmingCharacters(in: .whitespaces))
                    i += 1
                }
                blocks.append(.bulletList(items)); continue
            }

            // Lista ordenada
            if orderedPrefix(trimmed) != nil {
                var items: [String] = []
                while i < lines.count, let p = orderedPrefix(lines[i].trimmingCharacters(in: .whitespaces)) {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    items.append(String(t.dropFirst(p)).trimmingCharacters(in: .whitespaces))
                    i += 1
                }
                blocks.append(.orderedList(items)); continue
            }

            // Parágrafo: acumula linhas até uma em branco ou um bloco especial.
            // A linha atual é SEMPRE consumida — garante o avanço do laço mesmo quando
            // ela começa com "#" sem ser um título válido (ex.: "#Título", "#!/bin/sh").
            var para: [String] = [trimmed]
            i += 1
            while i < lines.count {
                let t = lines[i].trimmingCharacters(in: .whitespaces)
                if t.isEmpty || t.hasPrefix("#") || t.hasPrefix("```") || t.hasPrefix("~~~")
                    || t.hasPrefix(">") || isBullet(t) || orderedPrefix(t) != nil || isRule(t) {
                    break
                }
                para.append(t); i += 1
            }
            blocks.append(.paragraph(para.joined(separator: " ")))
        }
        return blocks
    }

    // MARK: Auxiliares

    public static func isBullet(_ s: String) -> Bool {
        (s.hasPrefix("- ") || s.hasPrefix("* ") || s.hasPrefix("+ "))
    }

    /// Se `s` começa com "N. " ou "N) ", devolve o tamanho do prefixo a remover.
    public static func orderedPrefix(_ s: String) -> Int? {
        var digits = 0
        for ch in s { if ch.isNumber { digits += 1 } else { break } }
        guard digits > 0, digits < s.count else { return nil }
        let idx = s.index(s.startIndex, offsetBy: digits)
        let sep = s[idx]
        guard sep == "." || sep == ")" else { return nil }
        let after = s.index(after: idx)
        guard after < s.endIndex, s[after] == " " else { return nil }
        return digits + 2   // dígitos + separador + espaço
    }

    /// Extrai alt e caminho de `![alt](path)`.
    public static func parseImage(_ s: String) -> (alt: String, path: String)? {
        guard let bang = s.range(of: "!["),
              let altEnd = s.range(of: "](", range: bang.upperBound..<s.endIndex),
              let close = s.range(of: ")", range: altEnd.upperBound..<s.endIndex) else { return nil }
        let alt = String(s[bang.upperBound..<altEnd.lowerBound])
        let path = String(s[altEnd.upperBound..<close.lowerBound]).trimmingCharacters(in: .whitespaces)
        return (alt, path)
    }
}
