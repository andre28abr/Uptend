import SwiftUI

/// Folha que mostra a saída ao vivo de um comando do Homebrew.
struct RunningTaskView: View {
    @EnvironmentObject var brew: BrewService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                if brew.runningBusy {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
                Text(brew.runningTitle ?? "").font(.headline)
                Spacer()
            }

            ScrollViewReader { proxy in
                ScrollView {
                    Text(brew.runningLog.isEmpty ? "Iniciando…" : brew.runningLog)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                    Color.clear.frame(height: 1).id("bottom")
                }
                .frame(minHeight: 260)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
                .onChange(of: brew.runningLog) { _, _ in
                    withAnimation(.linear(duration: 0.1)) { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }

            HStack {
                if brew.runningBusy {
                    Text("Executando…").foregroundStyle(.secondary).font(.callout)
                }
                Spacer()
                Button("Fechar") { brew.dismissRunning() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(brew.runningBusy)
            }
        }
        .padding(16)
        .frame(width: 580, height: 420)
    }
}
