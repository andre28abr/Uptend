import SwiftUI

// MARK: - Cabeçalho de tela

/// Título + subtítulo + ações à direita, padrão no topo de cada tela.
struct ScreenHeader<Actions: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var actions: () -> Actions

    init(title: String, subtitle: String, @ViewBuilder actions: @escaping () -> Actions = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.actions = actions
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title2).fontWeight(.medium)
                Text(subtitle).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 8) { actions() }
        }
    }
}

// MARK: - Botão só de ícone com tooltip

/// Ícone flat clicável. O tooltip aparece ao passar o mouse (regra de design do projeto).
struct IconButton: View {
    let systemImage: String
    let help: String
    var role: ButtonRole? = nil
    var action: () -> Void = {}

    var body: some View {
        Button(role: role, action: action) {
            Image(systemName: systemImage)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(help)
    }
}

// MARK: - Indicador de status

struct StatusDot: View {
    let color: Color
    var body: some View {
        Circle().fill(color).frame(width: 8, height: 8)
    }
}

// MARK: - Cartão de métrica (dashboard)

struct StatCard: View {
    let title: String
    let value: String
    let systemImage: String
    var tint: Color = .secondary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 26, weight: .medium))
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }
}

// MARK: - Linha em cartão (lista de itens)

/// Cartão com borda fina usado nas listas de containers, repositórios, etc.
struct CardRow<Leading: View, Trailing: View>: View {
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            leading()
            Spacer(minLength: 12)
            HStack(spacing: 2) { trailing() }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .cardBackground()
    }
}

// MARK: - Estilo de cartão reutilizável

extension View {
    func cardBackground(cornerRadius: CGFloat = 10) -> some View {
        self
            .background(Color(nsColor: .controlBackgroundColor),
                        in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
    }

    /// Padding padrão de conteúdo das telas.
    func screenPadding() -> some View {
        self.padding(20)
    }
}

// MARK: - Mini-gráfico (sparkline)

struct Sparkline: View {
    let values: [Double]
    var tint: Color = .accentColor
    var maxValue: Double? = nil

    var body: some View {
        GeometryReader { geo in
            let peak = max(maxValue ?? (values.max() ?? 1), 0.0001)
            Path { path in
                guard values.count > 1 else { return }
                let stepX = geo.size.width / CGFloat(values.count - 1)
                for (index, value) in values.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = geo.size.height * (1 - CGFloat(min(value / peak, 1)))
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(tint, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
        }
    }
}

// MARK: - Monograma (ícone de app baseado na inicial)

struct Monogram: View {
    let text: String
    var size: CGFloat = 32

    private var initials: String {
        let parts = text.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 7)
            .fill(Color.accentColor.opacity(0.15))
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            )
    }
}
