import Testing
import UptendCore
import Foundation
@testable import Uptend

struct RepoBrowserTests {

    // MARK: Detecção de tipo de arquivo

    @Test func detectsFileKinds() {
        #expect(FileKind.detect(name: "README.md") == .markdown)
        #expect(FileKind.detect(name: "README") == .markdown)
        #expect(FileKind.detect(name: "LICENSE") == .text)
        #expect(FileKind.detect(name: "main.swift") == .code("swift"))
        #expect(FileKind.detect(name: "app.js") == .code("cfamily"))
        #expect(FileKind.detect(name: "script.py") == .code("python"))
        #expect(FileKind.detect(name: "Dockerfile") == .code("shell"))
        #expect(FileKind.detect(name: ".zshrc") == .code("shell"))
        #expect(FileKind.detect(name: "photo.PNG") == .image)
        #expect(FileKind.detect(name: "notes.txt") == .text)
        #expect(FileKind.detect(name: "blob.bin") == .binary)
    }

    @Test func mapsExtensionToLanguage() {
        #expect(FileKind.language(forExtension: "swift") == "swift")
        #expect(FileKind.language(forExtension: "ts") == "cfamily")
        #expect(FileKind.language(forExtension: "py") == "python")
        #expect(FileKind.language(forExtension: "json") == "json")
        #expect(FileKind.language(forExtension: "qwerty") == nil)
    }

    // MARK: Ordenação da árvore

    @Test func sortsDirectoriesFirstThenAlpha() {
        func node(_ name: String, dir: Bool) -> FileNode {
            FileNode(url: URL(fileURLWithPath: "/" + name), name: name, isDirectory: dir,
                     children: dir ? [] : nil)
        }
        let sorted = RepoBrowser.sort([node("zeta", dir: false), node("alpha", dir: true),
                                       node("Beta", dir: false)])
        #expect(sorted.map(\.name) == ["alpha", "Beta", "zeta"])
    }

    // MARK: Parser de Markdown

    @Test func parsesHeadingsAndParagraph() {
        let blocks = MarkdownParser.parse("# Título\n\nUm parágrafo aqui.")
        #expect(blocks.first == .heading(level: 1, text: "Título"))
        #expect(blocks.last == .paragraph("Um parágrafo aqui."))
    }

    @Test func parsesFencedCodeWithLanguage() {
        let md = "```swift\nlet x = 1\n```"
        let blocks = MarkdownParser.parse(md)
        #expect(blocks == [.code(language: "swift", code: "let x = 1")])
    }

    @Test func parsesLists() {
        let bullet = MarkdownParser.parse("- a\n- b\n- c")
        #expect(bullet == [.bulletList(["a", "b", "c"])])
        let ordered = MarkdownParser.parse("1. um\n2. dois")
        #expect(ordered == [.orderedList(["um", "dois"])])
    }

    @Test func hashLineThatIsNotHeadingDoesNotHang() {
        // Regressão: "#" sem espaço (ou 7+ hashes) caía no acumulador de parágrafo
        // que quebrava sem consumir a linha → laço infinito. Deve virar parágrafo.
        #expect(MarkdownParser.parse("#Título") == [.paragraph("#Título")])
        #expect(MarkdownParser.parse("#!/bin/bash") == [.paragraph("#!/bin/bash")])
        #expect(MarkdownParser.parse("####### sete") == [.paragraph("####### sete")])
        // Ainda reconhece títulos válidos e mistura com texto sem travar.
        let mixed = MarkdownParser.parse("# Válido\n#semEspaco\ntexto")
        #expect(mixed.contains(.heading(level: 1, text: "Válido")))
        #expect(mixed.contains(.paragraph("#semEspaco texto")))
    }

    @Test func parsesQuoteRuleAndImage() {
        #expect(MarkdownParser.parse("> citação").first == .quote(["citação"]))
        #expect(MarkdownParser.parse("---") == [.rule])
        #expect(MarkdownParser.parse("![logo](img/logo.png)")
                == [.image(alt: "logo", path: "img/logo.png")])
    }

    @Test func parsesTable() {
        let md = "| A | B |\n|---|---|\n| 1 | 2 |\n| 3 | 4 |"
        let blocks = MarkdownParser.parse(md)
        #expect(blocks == [.table(headers: ["A", "B"], rows: [["1", "2"], ["3", "4"]])])
    }

    @Test func orderedPrefixDetection() {
        #expect(MarkdownParser.orderedPrefix("1. item") == 3)
        #expect(MarkdownParser.orderedPrefix("12) item") == 4)
        #expect(MarkdownParser.orderedPrefix("nao lista") == nil)
        #expect(MarkdownParser.isBullet("- x"))
        #expect(!MarkdownParser.isBullet("-x"))
    }

    // MARK: Realce de sintaxe

    private func classify(_ code: String, _ language: String) -> [(String, CodeHighlighter.Token)] {
        let ns = code as NSString
        return CodeHighlighter.tokens(code, spec: CodeHighlighter.spec(for: language))
            .map { (ns.substring(with: $0.range), $0.token) }
    }

    @Test func highlightsSwiftTokens() {
        let toks = classify("let n = 42 // nota", "swift")
        #expect(toks.contains { $0 == ("let", .keyword) })
        #expect(toks.contains { $0 == ("42", .number) })
        #expect(toks.contains { $0 == ("// nota", .comment) })
    }

    @Test func highlightsStringsAndBlockComments() {
        let toks = classify("var s = \"oi\" /* bloco */", "cfamily")
        #expect(toks.contains { $0 == ("\"oi\"", .string) })
        #expect(toks.contains { $0 == ("/* bloco */", .comment) })
        #expect(toks.contains { $0 == ("var", .keyword) })
    }

    @Test func doesNotFlagKeywordInsideIdentifier() {
        // "letters" não deve ser marcada como a palavra-chave "let".
        let toks = classify("letters = 1", "swift")
        #expect(!toks.contains { $0.0 == "let" })
    }

    @Test func producesColoredAttributedString() {
        let attributed = CodeHighlighter.highlight("func a() {}", language: "swift")
        #expect(!attributed.characters.isEmpty)
    }
}
