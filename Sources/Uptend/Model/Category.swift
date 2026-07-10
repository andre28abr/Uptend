import Foundation

/// Uma subseção dentro de uma categoria (a coluna do meio, no layout de 3 colunas).
struct SubSection: Identifiable, Hashable {
    let id: String
    let title: String
    let systemImage: String
    var badge: String? = nil
}

/// Categorias principais (a barra lateral esquerda).
enum Category: String, CaseIterable, Identifiable, Hashable {
    case dashboard, setup, homebrew, applications, cleanup, git, docker, network, security, system, tools, settings

    var id: String { rawValue }

    /// Categorias que aparecem no grupo principal da barra lateral (Configurações fica separada).
    static var primary: [Category] {
        allCases.filter { $0 != .settings }
    }

    var title: String {
        switch self {
        case .dashboard: "Início"
        case .setup: "Setup"
        case .homebrew: "Homebrew"
        case .applications: "Aplicativos"
        case .cleanup: "Limpeza"
        case .git: "Git"
        case .docker: "Docker"
        case .network: "Rede"
        case .security: "Segurança"
        case .system: "Sistema"
        case .tools: "Ferramentas"
        case .settings: "Configurações"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: "house"
        case .setup: "wand.and.stars"
        case .homebrew: "mug"
        case .applications: "macwindow"
        case .cleanup: "sparkles"
        case .git: "arrow.triangle.branch"
        case .docker: "shippingbox"
        case .network: "network"
        case .security: "lock.shield"
        case .system: "desktopcomputer"
        case .tools: "wrench.and.screwdriver"
        case .settings: "gearshape"
        }
    }

    var help: String {
        switch self {
        case .dashboard: "Visão geral do Mac"
        case .setup: "Configuração inicial: primeira vez, perfis e dotfiles"
        case .homebrew: "Central do Homebrew: buscar, instalar, atualizar e remover"
        case .applications: "Listar e desinstalar apps do Mac"
        case .cleanup: "Liberar espaço e limpar arquivos"
        case .git: "Sincronizar seus repositórios Git"
        case .docker: "Gerenciar containers e imagens"
        case .network: "Velocidade, IP, ping e DNS"
        case .security: "Checar e reforçar a segurança do Mac"
        case .system: "Informações e ajustes do sistema"
        case .tools: "Utilitários (canivete suíço)"
        case .settings: "Preferências do Uptend"
        }
    }

    var subsections: [SubSection] {
        switch self {
        case .dashboard:
            return [
                SubSection(id: "overview", title: "Visão geral", systemImage: "gauge.with.dots.needle.bottom.50percent"),
                SubSection(id: "health", title: "Saúde do sistema", systemImage: "stethoscope"),
                SubSection(id: "activity", title: "Atividade", systemImage: "clock.arrow.circlepath"),
            ]
        case .setup:
            return [
                SubSection(id: "firstrun", title: "Primeira vez", systemImage: "flag.checkered"),
                SubSection(id: "profiles", title: "Perfis (Brewfile)", systemImage: "doc.on.doc"),
                SubSection(id: "dotfiles", title: "Dotfiles", systemImage: "terminal"),
            ]
        case .homebrew:
            return [
                SubSection(id: "search", title: "Buscar e instalar", systemImage: "magnifyingglass"),
                SubSection(id: "essentials", title: "Essenciais", systemImage: "star"),
                SubSection(id: "installed", title: "Instalados", systemImage: "checkmark.circle"),
                SubSection(id: "outdated", title: "Atualizações", systemImage: "arrow.triangle.2.circlepath"),
                SubSection(id: "maintenance", title: "Manutenção", systemImage: "wrench.and.screwdriver"),
            ]
        case .applications:
            return [
                SubSection(id: "all", title: "Todos os apps", systemImage: "square.grid.2x2"),
            ]
        case .cleanup:
            return [
                SubSection(id: "trash", title: "Lixeira", systemImage: "trash"),
                SubSection(id: "caches", title: "Caches", systemImage: "internaldrive"),
                SubSection(id: "logs", title: "Logs", systemImage: "doc.text"),
                SubSection(id: "downloads", title: "Downloads", systemImage: "arrow.down.circle"),
                SubSection(id: "dev", title: "Dev (Xcode, npm, Docker)", systemImage: "hammer"),
            ]
        case .git:
            return [
                SubSection(id: "all", title: "Todos", systemImage: "tray.full"),
                SubSection(id: "dirty", title: "Com alterações", systemImage: "pencil"),
                SubSection(id: "desync", title: "Dessincronizados", systemImage: "arrow.triangle.2.circlepath"),
            ]
        case .docker:
            return [
                SubSection(id: "containers", title: "Containers", systemImage: "shippingbox", badge: "4"),
                SubSection(id: "images", title: "Imagens", systemImage: "square.stack.3d.up", badge: "12"),
                SubSection(id: "volumes", title: "Volumes", systemImage: "externaldrive", badge: "6"),
                SubSection(id: "networks", title: "Redes", systemImage: "network", badge: "3"),
            ]
        case .network:
            return [
                SubSection(id: "overview", title: "Visão geral", systemImage: "speedometer"),
                SubSection(id: "wifi", title: "Wi-Fi", systemImage: "wifi"),
                SubSection(id: "quality", title: "Qualidade", systemImage: "waveform.path.ecg"),
                SubSection(id: "addresses", title: "Endereços", systemImage: "number"),
                SubSection(id: "connections", title: "Conexões ativas", systemImage: "cable.connector"),
                SubSection(id: "speedtest", title: "Teste de velocidade", systemImage: "gauge.with.dots.needle.67percent"),
                SubSection(id: "ping", title: "Ping", systemImage: "dot.radiowaves.left.and.right"),
                SubSection(id: "dns", title: "DNS", systemImage: "magnifyingglass"),
            ]
        case .security:
            return [
                SubSection(id: "status", title: "Status", systemImage: "checklist"),
                SubSection(id: "passwords", title: "Senhas", systemImage: "key.horizontal"),
                SubSection(id: "hash", title: "Hash de arquivo", systemImage: "number"),
            ]
        case .system:
            return [
                SubSection(id: "info", title: "Informações", systemImage: "info.circle"),
                SubSection(id: "login", title: "Itens de inicialização", systemImage: "power"),
                SubSection(id: "toggles", title: "Ajustes rápidos", systemImage: "switch.2"),
            ]
        case .tools:
            return [
                SubSection(id: "converters", title: "Conversores", systemImage: "arrow.left.arrow.right"),
                SubSection(id: "qr", title: "QR Code", systemImage: "qrcode"),
                SubSection(id: "ports", title: "Portas em uso", systemImage: "point.3.connected.trianglepath.dotted"),
                SubSection(id: "ssh", title: "Chave SSH", systemImage: "terminal"),
                SubSection(id: "clipboard", title: "Histórico de clipboard", systemImage: "doc.on.clipboard"),
            ]
        case .settings:
            return [
                SubSection(id: "general", title: "Geral", systemImage: "gearshape"),
                SubSection(id: "schedule", title: "Agendamento", systemImage: "calendar"),
                SubSection(id: "about", title: "Sobre", systemImage: "info.circle"),
            ]
        }
    }
}
