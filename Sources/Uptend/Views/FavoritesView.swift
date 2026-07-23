import SwiftUI

struct FavoritesView: View {
    @StateObject private var favorites = FavoritesService()
    @State private var newURL = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ScreenHeader(title: "Repositórios favoritos", subtitle: "Clone sua lista de projetos de uma vez") {
                    Button {
                        favorites.cloneAll()
                    } label: {
                        Label("Clonar todos", systemImage: "square.and.arrow.down.on.square")
                    }
                    .disabled(favorites.urls.isEmpty || favorites.running)
                }

                HStack {
                    TextField("URL do repositório (https:// ou git@…)", text: $newURL)
                        .textFieldStyle(.plain).padding(10).cardBackground()
                        .onSubmit(addURL)
                    Button("Adicionar", action: addURL).disabled(newURL.isEmpty)
                }

                if favorites.urls.isEmpty {
                    ContentUnavailableView("Nenhum favorito", systemImage: "star").padding(.top, 20)
                } else {
                    ForEach(favorites.urls, id: \.self) { url in
                        CardRow {
                            HStack(spacing: 10) {
                                Image(systemName: "star.fill").foregroundStyle(.yellow)
                                Text(url).lineLimit(1).truncationMode(.middle)
                            }
                        } trailing: {
                            IconButton(systemImage: "minus.circle", help: "Remover") { favorites.remove(url) }
                        }
                    }
                }

                if favorites.running || !favorites.log.isEmpty {
                    Text(favorites.log)
                        .font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(10).cardBackground()
                }
            }
            .screenPadding()
            .frame(maxWidth: 860, alignment: .leading)
        }
    }

    private func addURL() {
        favorites.add(newURL)
        newURL = ""
    }
}
