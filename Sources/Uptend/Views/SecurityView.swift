import SwiftUI
import AppKit

struct SecurityView: View {
    let sub: SubSection?
    @EnvironmentObject var security: SecurityService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch sub?.id {
                case "passwords": PasswordGeneratorCard()
                case "hash": HashToolCard()
                default: statusContent
                }
            }
            .screenPadding()
            .frame(maxWidth: 860, alignment: .leading)
        }
        .task {
            if security.checks.isEmpty { await security.refresh() }
        }
    }

    // MARK: Status

    private var statusContent: some View {
        Group {
            ScreenHeader(
                title: "Status de segurança",
                subtitle: security.loading ? "Verificando…" : subtitle
            ) {
                if security.loading { ProgressView().controlSize(.small) }
                IconButton(systemImage: "arrow.clockwise", help: "Verificar novamente") {
                    Task { await security.refresh() }
                }
            }

            VStack(spacing: 8) {
                ForEach(security.checks) { check in
                    checkRow(check)
                }

                // Atualizações do sistema (sob demanda, pois é lenta)
                if let updates = security.updates {
                    checkRow(updates)
                } else {
                    CardRow {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.down.circle").foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Atualizações do sistema").fontWeight(.medium)
                                Text("Ainda não verificado").font(.callout).foregroundStyle(.secondary)
                            }
                        }
                    } trailing: {
                        if security.checkingUpdates {
                            ProgressView().controlSize(.small).frame(width: 24, height: 24)
                        } else {
                            IconButton(systemImage: "magnifyingglass", help: "Verificar atualizações (pode demorar)") {
                                Task { await security.checkUpdates() }
                            }
                        }
                    }
                }
            }
        }
    }

    private var subtitle: String {
        let warnings = security.checks.filter { $0.status == .warning }.count
        return warnings == 0 ? "Tudo em ordem" : "\(warnings) ponto(s) de atenção"
    }

    private func checkRow(_ check: SecurityCheck) -> some View {
        CardRow {
            HStack(spacing: 10) {
                Image(systemName: check.status.systemImage).foregroundStyle(check.status.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(check.name).fontWeight(.medium)
                    Text(check.detail).font(.callout).foregroundStyle(.secondary)
                }
            }
        } trailing: {
            EmptyView()
        }
    }

}

// MARK: - Gerador de senhas

struct PasswordGeneratorCard: View {
    @State private var length: Double = 20
    @State private var useDigits = true
    @State private var useSymbols = true
    @State private var password = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Gerador de senhas", systemImage: "key.horizontal").font(.headline)

            HStack(spacing: 10) {
                Text(password.isEmpty ? "Clique em Gerar" : password)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(password.isEmpty ? .secondary : .primary)
                    .textSelection(.enabled)
                    .lineLimit(1).truncationMode(.tail)
                Spacer()
                IconButton(systemImage: "doc.on.doc", help: "Copiar") {
                    if !password.isEmpty { copy(password) }
                }
                .disabled(password.isEmpty)
            }
            .padding(10)
            .cardBackground()

            HStack {
                Text("Tamanho: \(Int(length))").frame(width: 110, alignment: .leading)
                Slider(value: $length, in: 8...64, step: 1)
            }
            Toggle("Incluir números", isOn: $useDigits)
            Toggle("Incluir símbolos", isOn: $useSymbols)

            Button {
                password = PasswordGenerator.generate(length: Int(length), useDigits: useDigits, useSymbols: useSymbols)
            } label: {
                Label("Gerar", systemImage: "arrow.clockwise")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }

    private func copy(_ text: String) {
        Clipboard.copy(text)
    }
}

// MARK: - Hash de arquivos

struct HashToolCard: View {
    @State private var fileName = ""
    @State private var hash = ""
    @State private var computing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Hash de arquivo (SHA-256)", systemImage: "number").font(.headline)
            Text("Verifique a integridade de um download.").font(.callout).foregroundStyle(.secondary)

            HStack {
                Button("Escolher arquivo…") { pickFile() }
                if computing { ProgressView().controlSize(.small) }
                if !fileName.isEmpty {
                    Text(fileName).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
            }

            if !hash.isEmpty {
                HStack(spacing: 10) {
                    Text(hash)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(2)
                    Spacer()
                    IconButton(systemImage: "doc.on.doc", help: "Copiar hash") {
                        Clipboard.copy(hash)
                    }
                }
                .padding(10)
                .cardBackground()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }

    private func pickFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        fileName = url.lastPathComponent
        hash = ""
        computing = true
        Task {
            let result = await Task.detached { HashUtil.sha256(fileAt: url) }.value
            hash = result ?? "Não foi possível ler o arquivo."
            computing = false
        }
    }
}
