import SwiftUI

struct RuntimesToolView: View {
    @StateObject private var service = RuntimesService()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScreenHeader(title: "Versões (runtime)", subtitle: "Node, Python e Ruby") {
                IconButton(systemImage: "arrow.clockwise", help: "Recarregar") { Task { await service.load() } }
            }

            if let message = service.message {
                Text(message).font(.callout).foregroundStyle(.secondary)
            }

            ForEach(service.runtimes) { runtime in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(runtime.name).fontWeight(.medium)
                        Spacer()
                        Text(runtime.current).font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    if let manager = runtime.manager {
                        if runtime.switchable && !runtime.versions.isEmpty {
                            HStack {
                                Text("Trocar (\(manager)):").font(.caption).foregroundStyle(.secondary)
                                Picker("", selection: Binding(get: { "" }, set: { version in
                                    if !version.isEmpty { Task { await service.setGlobal(runtime: runtime, version: version) } }
                                })) {
                                    Text("versão…").tag("")
                                    ForEach(runtime.versions, id: \.self) { Text($0).tag($0) }
                                }
                                .labelsHidden().frame(maxWidth: 160)
                            }
                        } else {
                            Text("Gerenciado por \(manager) (troca pelo terminal)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardBackground()
            }
        }
        .task { await service.load() }
    }
}
