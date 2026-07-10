import SwiftUI

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let kind: Kind
    enum Kind { case success, error, info }
}

/// Avisos rápidos (toasts) de sucesso/erro, no rodapé da janela.
@MainActor
final class ToastCenter: ObservableObject {
    static let shared = ToastCenter()

    @Published var current: Toast?
    private var dismissTask: Task<Void, Never>?

    func show(_ text: String, kind: Toast.Kind = .success) {
        withAnimation(.spring(duration: 0.3)) { current = Toast(text: text, kind: kind) }
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if !Task.isCancelled { withAnimation(.easeOut(duration: 0.25)) { self?.current = nil } }
        }
    }
}

/// Overlay que exibe o toast atual.
struct ToastView: View {
    @ObservedObject private var center = ToastCenter.shared

    var body: some View {
        if let toast = center.current {
            HStack(spacing: 8) {
                Image(systemName: icon(toast.kind)).foregroundStyle(color(toast.kind))
                Text(toast.text).font(.callout)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
            .shadow(radius: 8, y: 2)
            .padding(.bottom, 24)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .id(toast.id)
        }
    }

    private func icon(_ kind: Toast.Kind) -> String {
        switch kind {
        case .success: "checkmark.circle.fill"
        case .error: "exclamationmark.triangle.fill"
        case .info: "info.circle.fill"
        }
    }

    private func color(_ kind: Toast.Kind) -> Color {
        switch kind {
        case .success: .green
        case .error: .orange
        case .info: .blue
        }
    }
}
