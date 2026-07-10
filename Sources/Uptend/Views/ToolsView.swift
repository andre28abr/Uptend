import SwiftUI
import AppKit
import CoreImage

enum Clipboard {
    @MainActor
    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        ToastCenter.shared.show("Copiado")
    }
}

struct ToolsView: View {
    let sub: SubSection?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch sub?.id {
                case "qr": QRToolView()
                case "ports": PortsToolView()
                case "ssh": SSHToolView()
                case "clipboard": ClipboardToolView()
                default: ConvertersToolView()
                }
            }
            .screenPadding()
            .frame(maxWidth: 860, alignment: .leading)
        }
    }
}

// MARK: - Conversores

struct ConvertersToolView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case base64 = "Base64", json = "JSON", timestamp = "Timestamp", hex = "Hex → RGB"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .base64
    @State private var decode = false
    @State private var input = ""

    private var output: String {
        switch mode {
        case .base64:
            return decode ? (Converters.base64Decode(input) ?? "— entrada Base64 inválida —")
                          : Converters.base64Encode(input)
        case .json:
            return Converters.jsonPretty(input) ?? "— JSON inválido —"
        case .timestamp:
            return Converters.timestampToDate(input) ?? "— timestamp inválido —"
        case .hex:
            return Converters.hexToRGB(input) ?? "— use o formato RRGGBB —"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScreenHeader(title: "Conversores", subtitle: "Tudo local, nada sai da máquina")

            Picker("Modo", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if mode == .base64 {
                Toggle("Decodificar (Base64 → texto)", isOn: $decode)
            }

            Text("Entrada").font(.callout).foregroundStyle(.secondary)
            TextEditor(text: $input)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 90)
                .padding(6)
                .cardBackground()

            HStack {
                Text("Resultado").font(.callout).foregroundStyle(.secondary)
                Spacer()
                IconButton(systemImage: "doc.on.doc", help: "Copiar resultado") { Clipboard.copy(output) }
                    .disabled(input.isEmpty)
            }
            Text(input.isEmpty ? "—" : output)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
                .padding(10)
                .cardBackground()
        }
    }
}

// MARK: - QR Code

struct QRToolView: View {
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScreenHeader(title: "QR Code", subtitle: "Gere um QR de texto ou link")

            TextField("Digite um texto ou URL…", text: $text)
                .textFieldStyle(.plain)
                .padding(10)
                .cardBackground()

            if let image = Self.qrImage(from: text) {
                Image(nsImage: image)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 220, height: 220)
                    .padding(12)
                    .cardBackground()
            } else {
                Text("Digite algo para gerar o QR.").foregroundStyle(.secondary).padding(.top, 8)
            }
        }
    }

    static func qrImage(from string: String) -> NSImage? {
        guard !string.isEmpty, let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(string.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)) else { return nil }
        let rep = NSCIImageRep(ciImage: output)
        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        return image
    }
}

// MARK: - Portas em uso

struct PortsToolView: View {
    @StateObject private var service = PortsService()
    @State private var toKill: PortInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScreenHeader(title: "Portas em uso", subtitle: "\(service.ports.count) portas TCP em escuta") {
                if service.loading { ProgressView().controlSize(.small) }
                IconButton(systemImage: "arrow.clockwise", help: "Atualizar") { Task { await service.refresh() } }
            }

            if service.ports.isEmpty && !service.loading {
                ContentUnavailableView("Nenhuma porta em escuta", systemImage: "point.3.connected.trianglepath.dotted")
                    .padding(.top, 40)
            } else {
                VStack(spacing: 8) {
                    ForEach(service.ports) { port in
                        CardRow {
                            HStack(spacing: 12) {
                                Text(port.port)
                                    .font(.body.monospacedDigit()).fontWeight(.medium)
                                    .frame(width: 60, alignment: .leading)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(port.command).fontWeight(.medium)
                                    Text("PID \(port.pid)").font(.callout).foregroundStyle(.secondary)
                                }
                            }
                        } trailing: {
                            IconButton(systemImage: "xmark.octagon", help: "Encerrar processo") { toKill = port }
                        }
                    }
                }
            }
        }
        .task { await service.refresh() }
        .confirmationDialog(
            "Encerrar \(toKill?.command ?? "") (PID \(toKill?.pid ?? ""))?",
            isPresented: Binding(get: { toKill != nil }, set: { if !$0 { toKill = nil } }),
            titleVisibility: .visible
        ) {
            if let port = toKill {
                Button("Encerrar", role: .destructive) {
                    Task { await service.kill(port.pid) }
                    toKill = nil
                }
            }
            Button("Cancelar", role: .cancel) { toKill = nil }
        }
    }
}

// MARK: - Chave SSH

struct SSHToolView: View {
    @StateObject private var service = SSHService()
    @State private var name = "id_ed25519"
    @State private var comment = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScreenHeader(title: "Chave SSH", subtitle: "Suas chaves públicas em ~/.ssh") {
                IconButton(systemImage: "arrow.clockwise", help: "Recarregar") { service.load() }
            }

            if let message = service.message {
                Text(message).font(.callout).foregroundStyle(.secondary)
            }

            ForEach(service.keys) { key in
                CardRow {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(key.name).fontWeight(.medium)
                        Text(key.publicKey).font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    }
                } trailing: {
                    IconButton(systemImage: "doc.on.doc", help: "Copiar chave pública") { Clipboard.copy(key.publicKey) }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Gerar nova chave (ed25519)").font(.headline).padding(.top, 4)
                TextField("nome do arquivo (ex.: id_ed25519)", text: $name)
                    .textFieldStyle(.plain).padding(10).cardBackground()
                TextField("comentário (opcional, ex.: seu e-mail)", text: $comment)
                    .textFieldStyle(.plain).padding(10).cardBackground()
                Button {
                    Task { await service.generate(name: name, comment: comment) }
                } label: {
                    Label("Gerar chave", systemImage: "plus")
                }
            }
        }
        .task { service.load() }
    }
}

// MARK: - Histórico de clipboard

struct ClipboardToolView: View {
    @EnvironmentObject var clipboard: ClipboardService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScreenHeader(title: "Histórico de clipboard", subtitle: "O que você copiou (só enquanto o app está aberto)") {
                IconButton(systemImage: "trash", help: "Limpar histórico") { clipboard.clear() }
            }

            if clipboard.history.isEmpty {
                ContentUnavailableView("Nada copiado ainda", systemImage: "doc.on.clipboard")
                    .padding(.top, 40)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(clipboard.history.enumerated()), id: \.offset) { _, item in
                        CardRow {
                            Text(item).lineLimit(2).truncationMode(.tail)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } trailing: {
                            IconButton(systemImage: "doc.on.doc", help: "Copiar de novo") { clipboard.copy(item) }
                        }
                    }
                }
            }
        }
    }
}
