import SwiftUI
import AppKit

/// Armazenamento & Discos: uso do disco e caça-duplicados.
struct StorageView: View {
    let sub: SubSection?
    @StateObject private var storage = StorageService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch sub?.id {
                case "duplicates": duplicatesContent
                default: usageContent
                }
            }
            .screenPadding()
            .frame(maxWidth: 860, alignment: .leading)
        }
    }

    // MARK: Uso

    private var usageContent: some View {
        Group {
            ScreenHeader(title: "Uso do disco", subtitle: storage.loadingUsage ? "Calculando…" : "O que ocupa mais espaço") {
                if storage.loadingUsage { ProgressView().controlSize(.small) }
                IconButton(systemImage: "arrow.clockwise", help: "Recalcular") { Task { await storage.refreshUsage() } }
            }

            if !storage.volumes.isEmpty {
                Text("Volumes").font(.headline)
                ForEach(storage.volumes, id: \.self) { v in
                    CardRow {
                        HStack(spacing: 10) { Image(systemName: "internaldrive").foregroundStyle(.secondary); Text(v) }
                    } trailing: { EmptyView() }
                }
            }

            if !storage.folders.isEmpty {
                Text("Suas pastas").font(.headline).padding(.top, 4)
                let maxF = storage.folders.map(\.bytes).max() ?? 1
                ForEach(storage.folders) { f in
                    CardRow {
                        HStack(spacing: 10) {
                            Image(systemName: "folder").foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(f.name).fontWeight(.medium)
                                GeometryReader { geo in
                                    Capsule().fill(.quaternary).overlay(alignment: .leading) {
                                        Capsule().fill(Color.accentColor).frame(width: geo.size.width * min(Double(f.bytes) / Double(maxF), 1))
                                    }
                                }.frame(height: 5)
                            }
                        }
                    } trailing: {
                        Text(f.sizeLabel).font(.callout).foregroundStyle(.secondary)
                    }
                }
            }

            if !storage.largest.isEmpty {
                Text("Maiores arquivos").font(.headline).padding(.top, 4)
                ForEach(storage.largest) { file in
                    CardRow {
                        HStack(spacing: 10) {
                            Image(systemName: "doc").foregroundStyle(.secondary)
                            Text(URL(fileURLWithPath: file.path).lastPathComponent).lineLimit(1).truncationMode(.middle)
                        }
                    } trailing: {
                        Text(file.sizeLabel).font(.callout).foregroundStyle(.secondary)
                        IconButton(systemImage: "folder", help: "Mostrar no Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: file.path)])
                        }
                    }
                }
            }
        }
        .task { if storage.folders.isEmpty { await storage.refreshUsage() } }
    }

    // MARK: Duplicados

    private var duplicatesContent: some View {
        Group {
            ScreenHeader(title: "Arquivos duplicados", subtitle: "Ache cópias idênticas e libere espaço")

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle").foregroundStyle(.blue)
                Text("Escolha uma pasta. O Uptend compara os arquivos pelo conteúdo (não pelo nome) e mostra os que são idênticos. Você decide quais mover para a Lixeira.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading).cardBackground()

            Button {
                let panel = NSOpenPanel()
                panel.canChooseDirectories = true; panel.canChooseFiles = false
                panel.prompt = "Procurar"
                if panel.runModal() == .OK, let url = panel.url {
                    Task { await storage.findDuplicates(in: url.path) }
                }
            } label: { Label("Escolher pasta e procurar…", systemImage: "folder.badge.magnifyingglass") }
            .disabled(storage.scanningDupes)

            if storage.scanningDupes {
                HStack { ProgressView().controlSize(.small); Text("Procurando duplicados…").foregroundStyle(.secondary) }
            }
            if let error = storage.lastError { ErrorBanner(error) { storage.lastError = nil } }

            if storage.dupesDidScan && !storage.scanningDupes {
                if storage.duplicates.isEmpty && storage.lastError == nil {
                    Label("Nenhum arquivo duplicado encontrado.", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                } else if !storage.duplicates.isEmpty {
                    let wasted = storage.duplicates.reduce(Int64(0)) { $0 + $1.wastedBytes }
                    Text("\(storage.duplicates.count) grupo(s) — \(ByteCountFormatter.string(fromByteCount: wasted, countStyle: .file)) desperdiçados")
                        .font(.callout).foregroundStyle(.orange)
                    ForEach(storage.duplicates) { group in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(group.paths.count) cópias · \(group.sizeLabel) cada · sobra \(group.wastedLabel)")
                                .font(.caption).foregroundStyle(.secondary)
                            ForEach(group.paths, id: \.self) { path in
                                CardRow {
                                    Text(path).font(.system(.caption, design: .monospaced))
                                        .lineLimit(1).truncationMode(.middle)
                                } trailing: {
                                    IconButton(systemImage: "folder", help: "Mostrar no Finder") {
                                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                                    }
                                    IconButton(systemImage: "trash", help: "Mover esta cópia para a Lixeira") {
                                        Task { await storage.trash(path) }
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 4)
                    }
                }
            }
        }
    }
}
