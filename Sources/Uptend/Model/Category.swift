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
    case dashboard, homebrew, applications, cleanup, git, docker, services, network, security, report, energy, xcode, storage, tools, settings

    var id: String { rawValue }

    /// Categorias que aparecem no grupo principal da barra lateral. Início e
    /// Configurações ficam fora (acessadas pelos ícones da toolbar).
    static var primary: [Category] {
        allCases.filter { $0 != .settings && $0 != .dashboard }
    }

    var title: String {
        switch self {
        case .dashboard: "Início"
        case .homebrew: "Homebrew"
        case .applications: "Aplicativos"
        case .cleanup: "Limpeza"
        case .git: "Git"
        case .docker: "Docker"
        case .services: "Serviços"
        case .network: "Rede"
        case .security: "Segurança"
        case .report: "Relatório"
        case .energy: "Bateria e Energia"
        case .xcode: "Xcode"
        case .storage: "Armazenamento"
        case .tools: "Ferramentas"
        case .settings: "Configurações"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: "house"
        case .homebrew: "mug"
        case .applications: "macwindow"
        case .cleanup: "sparkles"
        case .git: "arrow.triangle.branch"
        case .docker: "shippingbox"
        case .services: "server.rack"
        case .network: "network"
        case .security: "lock.shield"
        case .report: "doc.text.magnifyingglass"
        case .energy: "bolt.fill"
        case .xcode: "hammer.fill"
        case .storage: "internaldrive.fill"
        case .tools: "wrench.and.screwdriver"
        case .settings: "gearshape"
        }
    }

    var help: String {
        switch self {
        case .dashboard: "Visão geral do Mac e configuração inicial"
        case .homebrew: "Central do Homebrew: buscar, instalar, atualizar e remover"
        case .applications: "Listar e desinstalar apps do Mac"
        case .cleanup: "Liberar espaço e limpar arquivos"
        case .git: "Sincronizar seus repositórios Git"
        case .docker: "Gerenciar containers e imagens"
        case .services: "Ligar/desligar serviços locais (bancos de dados, etc.)"
        case .network: "Velocidade, IP, ping e DNS"
        case .security: "Checar e reforçar a segurança do Mac"
        case .report: "Inventário completo do Mac para exportar ou guardar no histórico"
        case .energy: "Saúde da bateria e consumo de energia"
        case .xcode: "Xcode, DerivedData e simuladores"
        case .storage: "Uso do disco e arquivos duplicados"
        case .tools: "Utilitários (canivete suíço)"
        case .settings: "Preferências do Uptend"
        }
    }

    var subsections: [SubSection] {
        switch self {
        case .dashboard:
            return [
                SubSection(id: "overview", title: "Visão geral", systemImage: "gauge.with.dots.needle.bottom.50percent"),
                SubSection(id: "firstrun", title: "Primeira vez", systemImage: "flag.checkered"),
                SubSection(id: "ambiente", title: "Preparar ambiente", systemImage: "shippingbox.and.arrow.backward"),
                SubSection(id: "profiles", title: "Perfis (Brewfile)", systemImage: "doc.on.doc"),
                SubSection(id: "compare", title: "Comparar perfil", systemImage: "arrow.left.arrow.right"),
                SubSection(id: "dotfiles", title: "Dotfiles", systemImage: "terminal"),
            ]
        case .homebrew:
            return [
                SubSection(id: "search", title: "Buscar e instalar", systemImage: "magnifyingglass"),
                SubSection(id: "essentials", title: "Essenciais", systemImage: "star"),
                SubSection(id: "taps", title: "Fontes (contas)", systemImage: "person.2.badge.gearshape"),
                SubSection(id: "mypackages", title: "Meus programas", systemImage: "shippingbox"),
                SubSection(id: "installed", title: "Instalados", systemImage: "checkmark.circle"),
                SubSection(id: "outdated", title: "Atualizações", systemImage: "arrow.triangle.2.circlepath"),
                SubSection(id: "tidy", title: "Faxina", systemImage: "wand.and.sparkles"),
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
                SubSection(id: "space", title: "Espaço em disco", systemImage: "chart.pie"),
            ]
        case .git:
            return [
                SubSection(id: "all", title: "Todos", systemImage: "tray.full"),
                SubSection(id: "dirty", title: "Com alterações", systemImage: "pencil"),
                SubSection(id: "desync", title: "Dessincronizados", systemImage: "arrow.triangle.2.circlepath"),
                SubSection(id: "favorites", title: "Favoritos", systemImage: "star"),
                SubSection(id: "account", title: "Conta GitHub", systemImage: "person.crop.circle"),
                SubSection(id: "browse", title: "Meus repositórios", systemImage: "square.grid.2x2"),
                SubSection(id: "publish", title: "Publicar pasta", systemImage: "square.and.arrow.up.on.square"),
            ]
        case .docker:
            return [
                SubSection(id: "containers", title: "Containers", systemImage: "shippingbox", badge: "4"),
                SubSection(id: "images", title: "Imagens", systemImage: "square.stack.3d.up", badge: "12"),
                SubSection(id: "volumes", title: "Volumes", systemImage: "externaldrive", badge: "6"),
                SubSection(id: "networks", title: "Redes", systemImage: "network", badge: "3"),
            ]
        case .services:
            return [
                SubSection(id: "list", title: "Serviços do Homebrew", systemImage: "server.rack"),
            ]
        case .network:
            return [
                SubSection(id: "overview", title: "Visão geral", systemImage: "speedometer"),
                SubSection(id: "wifi", title: "Wi-Fi", systemImage: "wifi"),
                SubSection(id: "quality", title: "Qualidade", systemImage: "waveform.path.ecg"),
                SubSection(id: "addresses", title: "Endereços", systemImage: "number"),
                SubSection(id: "connections", title: "Conexões ativas", systemImage: "cable.connector"),
                SubSection(id: "ports", title: "Portas em uso", systemImage: "point.3.connected.trianglepath.dotted"),
                SubSection(id: "speedtest", title: "Teste de velocidade", systemImage: "gauge.with.dots.needle.67percent"),
                SubSection(id: "ping", title: "Ping", systemImage: "dot.radiowaves.left.and.right"),
                SubSection(id: "dns", title: "DNS", systemImage: "magnifyingglass"),
            ]
        case .energy:
            return [
                SubSection(id: "battery", title: "Bateria", systemImage: "battery.100percent"),
                SubSection(id: "consumption", title: "Consumo", systemImage: "bolt"),
            ]
        case .xcode:
            return [
                SubSection(id: "xcode", title: "Xcode", systemImage: "hammer"),
                SubSection(id: "simulators", title: "Simuladores", systemImage: "iphone"),
            ]
        case .storage:
            return [
                SubSection(id: "usage", title: "Uso do disco", systemImage: "chart.pie"),
                SubSection(id: "duplicates", title: "Duplicados", systemImage: "doc.on.doc"),
            ]
        case .security:
            return [
                SubSection(id: "status", title: "Status", systemImage: "checklist"),
                SubSection(id: "exposure", title: "Exposição", systemImage: "shield.lefthalf.filled"),
                SubSection(id: "antivirus", title: "Antivírus (ClamAV)", systemImage: "shield.checkerboard"),
                SubSection(id: "verify", title: "Verificar app", systemImage: "checkmark.seal"),
                SubSection(id: "secrets", title: "Segredos nos repos", systemImage: "eye.trianglebadge.exclamationmark"),
                SubSection(id: "audit", title: "Auditoria (Lynis)", systemImage: "list.bullet.clipboard"),
                SubSection(id: "deps", title: "Vulnerabilidades", systemImage: "cube.transparent"),
                SubSection(id: "passwords", title: "Senhas", systemImage: "key.horizontal"),
                SubSection(id: "hash", title: "Hash de arquivo", systemImage: "number"),
            ]
        case .report:
            return [
                SubSection(id: "inventario", title: "Inventário do Mac", systemImage: "doc.text.magnifyingglass"),
            ]
        case .tools:
            return [
                SubSection(id: "converters", title: "Conversores", systemImage: "arrow.left.arrow.right"),
                SubSection(id: "runtimes", title: "Versões (runtime)", systemImage: "cube"),
                SubSection(id: "qr", title: "QR Code", systemImage: "qrcode"),
                SubSection(id: "ssh", title: "Chave SSH", systemImage: "terminal"),
                SubSection(id: "clipboard", title: "Histórico de clipboard", systemImage: "doc.on.clipboard"),
            ]
        case .settings:
            return [
                SubSection(id: "general", title: "Geral", systemImage: "gearshape"),
                SubSection(id: "info", title: "Informações do Mac", systemImage: "desktopcomputer"),
                SubSection(id: "health", title: "Saúde", systemImage: "heart.text.square"),
                SubSection(id: "toggles", title: "Ajustes rápidos", systemImage: "switch.2"),
                SubSection(id: "login", title: "Itens de inicialização", systemImage: "power"),
                SubSection(id: "focus", title: "Modo foco", systemImage: "moon"),
                SubSection(id: "schedule", title: "Agendamento", systemImage: "calendar"),
                SubSection(id: "dados", title: "Dados e histórico", systemImage: "cylinder.split.1x2"),
                SubSection(id: "about", title: "Sobre", systemImage: "info.circle"),
            ]
        }
    }
}

/// Algo que tem um título exibível — usado para ordenar menus alfabeticamente.
protocol Titled { var title: String { get } }
extension Category: Titled {}
extension SubSection: Titled {}

extension Array where Element: Titled {
    /// Ordena por título, sem diferenciar maiúsculas/acentos (padrão do português).
    var alphabetical: [Element] {
        sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
}
