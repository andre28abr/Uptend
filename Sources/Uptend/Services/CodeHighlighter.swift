import Foundation
import AppKit

/// Realce de sintaxe leve e nativo (sem dependências). Um scanner de passo único
/// reconhece comentários, strings, números e palavras-chave para várias famílias de
/// linguagem, e produz um `AttributedString` colorido para exibição (só leitura).
enum CodeHighlighter {

    enum Token: Equatable { case plain, keyword, string, comment, number }

    struct LangSpec {
        let lineComments: [String]
        let blockComment: (open: String, close: String)?
        let stringDelimiters: [Character]
        let tripleStrings: Bool
        let keywords: Set<String>
    }

    // MARK: Especificações por linguagem

    static func spec(for language: String) -> LangSpec {
        switch language {
        case "swift":
            return LangSpec(lineComments: ["//"], blockComment: ("/*", "*/"),
                            stringDelimiters: ["\""], tripleStrings: true, keywords: swiftKeywords)
        case "cfamily":
            return LangSpec(lineComments: ["//"], blockComment: ("/*", "*/"),
                            stringDelimiters: ["\"", "'", "`"], tripleStrings: false, keywords: cKeywords)
        case "python":
            return LangSpec(lineComments: ["#"], blockComment: nil,
                            stringDelimiters: ["\"", "'"], tripleStrings: true, keywords: pythonKeywords)
        case "ruby":
            return LangSpec(lineComments: ["#"], blockComment: nil,
                            stringDelimiters: ["\"", "'"], tripleStrings: false, keywords: rubyKeywords)
        case "shell":
            return LangSpec(lineComments: ["#"], blockComment: nil,
                            stringDelimiters: ["\"", "'"], tripleStrings: false, keywords: shellKeywords)
        case "json":
            return LangSpec(lineComments: [], blockComment: nil,
                            stringDelimiters: ["\""], tripleStrings: false, keywords: ["true", "false", "null"])
        case "yaml":
            return LangSpec(lineComments: ["#"], blockComment: nil,
                            stringDelimiters: ["\"", "'"], tripleStrings: false,
                            keywords: ["true", "false", "null", "yes", "no", "on", "off"])
        case "css":
            return LangSpec(lineComments: [], blockComment: ("/*", "*/"),
                            stringDelimiters: ["\"", "'"], tripleStrings: false, keywords: [])
        case "sql":
            return LangSpec(lineComments: ["--"], blockComment: ("/*", "*/"),
                            stringDelimiters: ["'", "\""], tripleStrings: false, keywords: sqlKeywords)
        case "markup":
            return LangSpec(lineComments: [], blockComment: ("<!--", "-->"),
                            stringDelimiters: ["\"", "'"], tripleStrings: false, keywords: [])
        default:
            return LangSpec(lineComments: ["#", "//"], blockComment: nil,
                            stringDelimiters: ["\"", "'"], tripleStrings: false, keywords: [])
        }
    }

    // MARK: Scanner (puro, testável)

    /// Tokeniza o texto e devolve os intervalos (UTF-16) não triviais e seu tipo.
    static func tokens(_ text: String, spec: LangSpec) -> [(range: NSRange, token: Token)] {
        let ns = text as NSString
        let n = ns.length
        var i = 0
        var out: [(NSRange, Token)] = []

        func matches(_ s: String, at idx: Int) -> Bool {
            let len = (s as NSString).length
            guard idx + len <= n else { return false }
            return ns.substring(with: NSRange(location: idx, length: len)) == s
        }
        func isIdentStart(_ c: unichar) -> Bool {
            (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95 || c == 36 || c > 127
        }
        func isIdent(_ c: unichar) -> Bool { isIdentStart(c) || (c >= 48 && c <= 57) }
        func isDigit(_ c: unichar) -> Bool { c >= 48 && c <= 57 }

        while i < n {
            let c = ns.character(at: i)

            // Comentário de linha
            if let lc = spec.lineComments.first(where: { matches($0, at: i) }) {
                let start = i
                _ = lc
                while i < n && ns.character(at: i) != 10 { i += 1 }   // 10 = \n
                out.append((NSRange(location: start, length: i - start), .comment))
                continue
            }
            // Comentário de bloco
            if let bc = spec.blockComment, matches(bc.open, at: i) {
                let start = i
                i += (bc.open as NSString).length
                while i < n && !matches(bc.close, at: i) { i += 1 }
                if i < n { i += (bc.close as NSString).length }
                out.append((NSRange(location: start, length: i - start), .comment))
                continue
            }
            // String (com suporte opcional a aspas triplas)
            if let ch = Character(unicodeScalarLiteralSafe: c), spec.stringDelimiters.contains(ch) {
                let start = i
                let triple = spec.tripleStrings && matches(String(repeating: ch, count: 3), at: i)
                let delim = triple ? String(repeating: ch, count: 3) : String(ch)
                i += (delim as NSString).length
                while i < n {
                    if ns.character(at: i) == 92 { i += 2; continue }   // 92 = \ (escape)
                    if matches(delim, at: i) { i += (delim as NSString).length; break }
                    i += 1
                }
                out.append((NSRange(location: start, length: i - start), .string))
                continue
            }
            // Número
            if isDigit(c) || (c == 46 && i + 1 < n && isDigit(ns.character(at: i + 1))) {
                let prev = i > 0 ? ns.character(at: i - 1) : 0
                if !isIdent(prev) {   // evita pegar o "1" de "abc1"
                    let start = i
                    while i < n {
                        let d = ns.character(at: i)
                        if isDigit(d) || d == 46 || d == 95 ||
                            (d >= 97 && d <= 102) || (d >= 65 && d <= 70) ||   // a-f A-F (hex)
                            d == 120 || d == 88 || d == 111 || d == 79 || d == 98 || d == 66 {  // x X o O b B
                            i += 1
                        } else { break }
                    }
                    out.append((NSRange(location: start, length: i - start), .number))
                    continue
                }
            }
            // Identificador / palavra-chave
            if isIdentStart(c) {
                let start = i
                while i < n && isIdent(ns.character(at: i)) { i += 1 }
                let word = ns.substring(with: NSRange(location: start, length: i - start))
                if spec.keywords.contains(word) {
                    out.append((NSRange(location: start, length: i - start), .keyword))
                }
                continue
            }
            i += 1
        }
        return out
    }

    // MARK: Coloração

    static func color(for token: Token) -> NSColor {
        switch token {
        case .comment: return .secondaryLabelColor
        case .string: return .systemGreen
        case .number: return .systemOrange
        case .keyword: return .systemPink
        case .plain: return .labelColor
        }
    }

    /// Produz o texto colorido pronto para um `Text(...)` do SwiftUI.
    static func highlight(_ text: String, language: String) -> AttributedString {
        let spec = spec(for: language)
        let mutable = NSMutableAttributedString(string: text)
        let full = NSRange(location: 0, length: (text as NSString).length)
        mutable.addAttribute(.foregroundColor, value: NSColor.labelColor, range: full)
        for (range, token) in tokens(text, spec: spec) where token != .plain {
            mutable.addAttribute(.foregroundColor, value: color(for: token), range: range)
        }
        return AttributedString(mutable)
    }

    // MARK: Conjuntos de palavras-chave

    static let swiftKeywords: Set<String> = [
        "func", "let", "var", "if", "else", "guard", "return", "for", "while", "in", "switch",
        "case", "default", "break", "continue", "struct", "class", "enum", "protocol", "extension",
        "import", "public", "private", "internal", "fileprivate", "open", "static", "final", "lazy",
        "weak", "unowned", "self", "super", "init", "deinit", "try", "catch", "throw", "throws",
        "async", "await", "actor", "nil", "true", "false", "nonisolated", "some", "any", "where",
        "as", "is", "do", "defer", "repeat", "typealias", "associatedtype", "mutating", "override",
    ]
    static let cKeywords: Set<String> = [
        "function", "const", "let", "var", "if", "else", "return", "for", "while", "do", "switch",
        "case", "default", "break", "continue", "class", "struct", "enum", "interface", "public",
        "private", "protected", "static", "final", "void", "int", "float", "double", "bool", "char",
        "string", "new", "delete", "this", "super", "import", "export", "from", "as", "try", "catch",
        "throw", "throws", "finally", "async", "await", "true", "false", "null", "nil", "undefined",
        "typeof", "instanceof", "extends", "implements", "package", "func", "type", "map", "range",
    ]
    static let pythonKeywords: Set<String> = [
        "def", "class", "if", "elif", "else", "for", "while", "in", "return", "import", "from", "as",
        "try", "except", "finally", "raise", "with", "lambda", "yield", "pass", "break", "continue",
        "and", "or", "not", "is", "None", "True", "False", "self", "async", "await", "global", "nonlocal",
    ]
    static let rubyKeywords: Set<String> = [
        "def", "end", "if", "elsif", "else", "unless", "while", "for", "in", "return", "class", "module",
        "require", "require_relative", "begin", "rescue", "ensure", "yield", "do", "then", "nil", "true",
        "false", "self", "attr_accessor", "attr_reader", "attr_writer", "puts", "new",
    ]
    static let shellKeywords: Set<String> = [
        "if", "then", "else", "elif", "fi", "for", "while", "do", "done", "case", "esac", "in",
        "function", "return", "export", "local", "echo", "cd", "source", "set", "unset", "read",
    ]
    static let sqlKeywords: Set<String> = [
        "select", "from", "where", "insert", "into", "values", "update", "set", "delete", "create",
        "table", "drop", "alter", "join", "left", "right", "inner", "outer", "on", "group", "by",
        "order", "having", "limit", "and", "or", "not", "null", "as", "distinct", "count", "primary", "key",
    ]
}

private extension Character {
    /// Constrói um `Character` a partir de um `unichar` (UTF-16), quando representável.
    init?(unicodeScalarLiteralSafe value: unichar) {
        guard let scalar = Unicode.Scalar(value) else { return nil }
        self = Character(scalar)
    }
}
