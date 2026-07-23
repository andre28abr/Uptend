import SwiftUI

struct SpaceAnalyzerView: View {
    @StateObject private var analyzer = SpaceAnalyzerService()

    private var maxSize: Int64 { analyzer.items.map(\.size).max() ?? 1 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ScreenHeader(title: "Espaço em disco", subtitle: subtitle) {
                    if analyzer.scanning { ProgressView().controlSize(.small) }
                    IconButton(systemImage: "house", help: "Pasta pessoal") { analyzer.goHome() }
                    IconButton(systemImage: "arrow.up", help: "Subir um nível") { analyzer.goUp() }
                        .disabled(!analyzer.canGoUp)
                    IconButton(systemImage: "folder", help: "Escolher pasta") { analyzer.pickFolder() }
                }

                if analyzer.items.isEmpty && !analyzer.scanning {
                    ContentUnavailableView("Pasta vazia ou sem acesso", systemImage: "chart.pie").padding(.top, 30)
                } else {
                    ForEach(analyzer.items) { item in
                        row(item)
                    }
                }
            }
            .screenPadding()
            .frame(maxWidth: 860, alignment: .leading)
        }
        .task { if analyzer.items.isEmpty { await analyzer.analyze() } }
    }

    private var subtitle: String {
        if analyzer.scanning { return "Analisando…" }
        return "\(FileUtils.label(analyzer.total)) · \(analyzer.current.path)"
    }

    private func row(_ item: SpaceItem) -> some View {
        CardRow {
            HStack(spacing: 12) {
                Image(systemName: item.isDirectory ? "folder.fill" : "doc")
                    .foregroundStyle(item.isDirectory ? Color.accentColor : .secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name).fontWeight(.medium).lineLimit(1).truncationMode(.middle)
                    Capsule()
                        .fill(Color.accentColor.opacity(0.25))
                        .frame(width: max(4, CGFloat(Double(item.size) / Double(maxSize)) * 220), height: 5)
                }
            }
        } trailing: {
            Text(FileUtils.label(item.size))
                .font(.callout.monospacedDigit()).foregroundStyle(.secondary).padding(.trailing, 4)
            if item.isDirectory {
                IconButton(systemImage: "chevron.right", help: "Abrir") { analyzer.open(item) }
            } else {
                IconButton(systemImage: "folder", help: "Mostrar no Finder") { analyzer.open(item) }
            }
        }
    }
}
