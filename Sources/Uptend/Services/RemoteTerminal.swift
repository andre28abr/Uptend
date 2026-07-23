import Foundation

// =============================================================================
// TERMINAL EMBUTIDO — Passo 8 do módulo Servidor
// "Saída de emergência": executa o comando digitado pelo usuário no SERVIDOR dele,
// via SSH. Aqui, rodar comando arbitrário É a funcionalidade (o usuário poderia
// fazer o mesmo por `ssh` manual) — não uma brecha. O comando vai como UM argumento
// (SSHRunner o envolve em aspas), então não há injeção além do que o próprio usuário
// digita. Comandos são NÃO-interativos (sem TTY): top/vim/sudo-com-senha não servem.
// Mantém o diretório atual entre comandos capturando o `pwd` ao final.
// =============================================================================

enum RemoteTerminal {

    static let marker = "__UPTEND_CWD__"

    static func run(_ host: RemoteHost, cwd: String, command: String) async -> (output: String, cwd: String) {
        // Roda a partir do cwd atual e reporta o novo cwd (para `cd` persistir).
        let script = "cd \"\(cwd)\" 2>/dev/null\n\(command)\nprintf '\\n%s%s' \"\(marker)\" \"$(pwd)\""
        let r = await SSHRunner.run(host, ["bash", "-lc", script])
        return parse(stdout: r.stdout, stderr: r.stderr, fallbackCwd: cwd)
    }

    /// Separa a saída do comando do marcador de diretório final. Puro e testável.
    static func parse(stdout: String, stderr: String, fallbackCwd: String) -> (output: String, cwd: String) {
        var out = stdout
        var cwd = fallbackCwd
        if let range = out.range(of: marker, options: .backwards) {
            cwd = String(out[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            var head = String(out[..<range.lowerBound])
            while head.hasSuffix("\n") { head.removeLast() }   // remove o separador + newline final do comando
            out = head
        }
        let combined = out + (stderr.isEmpty ? "" : (out.isEmpty ? "" : "\n") + stderr)
        return (combined, cwd.isEmpty ? fallbackCwd : cwd)
    }
}
