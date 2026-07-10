import Foundation

/// Dados de exemplo para a interface. Depois serão substituídos por dados reais
/// (Homebrew, Docker, Git, etc.). Aqui é só para avaliar o UX.
enum MockData {

    // MARK: Instalar

    static let apps: [String: [AppItem]] = [
        "dev": [
            AppItem(name: "Visual Studio Code", tagline: "Editor de código", token: "visual-studio-code", isCask: true),
            AppItem(name: "iTerm2", tagline: "Terminal", token: "iterm2", isCask: true),
            AppItem(name: "Warp", tagline: "Terminal moderno", token: "warp", isCask: true),
            AppItem(name: "Node.js", tagline: "Runtime JavaScript", token: "node", isCask: false),
            AppItem(name: "Python", tagline: "Linguagem", token: "python@3.12", isCask: false),
            AppItem(name: "Docker Desktop", tagline: "Containers", token: "docker", isCask: true),
            AppItem(name: "Postman", tagline: "Cliente de API", token: "postman", isCask: true),
            AppItem(name: "TablePlus", tagline: "Cliente de banco de dados", token: "tableplus", isCask: true),
            AppItem(name: "GitHub CLI", tagline: "gh na linha de comando", token: "gh", isCask: false),
            AppItem(name: "ripgrep", tagline: "Busca rápida em arquivos", token: "ripgrep", isCask: false),
        ],
        "sec": [
            AppItem(name: "Wireshark", tagline: "Análise de rede", token: "wireshark", isCask: true),
            AppItem(name: "Nmap", tagline: "Scanner de portas", token: "nmap", isCask: false),
            AppItem(name: "Little Snitch", tagline: "Firewall de aplicativos", token: "little-snitch", isCask: true),
            AppItem(name: "1Password", tagline: "Gerenciador de senhas", token: "1password", isCask: true),
            AppItem(name: "GPG Suite", tagline: "Criptografia", token: "gpg-suite", isCask: true),
            AppItem(name: "Burp Suite", tagline: "Testes de segurança web", token: "burp-suite", isCask: true),
        ],
        "design": [
            AppItem(name: "Figma", tagline: "Design de interface", token: "figma", isCask: true),
            AppItem(name: "ImageOptim", tagline: "Otimizar imagens", token: "imageoptim", isCask: true),
            AppItem(name: "Pixelmator Pro", tagline: "Editor de imagens", token: "pixelmator-pro", isCask: true),
            AppItem(name: "Sip", tagline: "Seletor de cores", token: "sip", isCask: true),
        ],
        "prod": [
            AppItem(name: "Raycast", tagline: "Lançador e produtividade", token: "raycast", isCask: true),
            AppItem(name: "Rectangle", tagline: "Organizar janelas", token: "rectangle", isCask: true),
            AppItem(name: "Obsidian", tagline: "Notas em Markdown", token: "obsidian", isCask: true),
            AppItem(name: "Notion", tagline: "Workspace", token: "notion", isCask: true),
            AppItem(name: "Notion Calendar", tagline: "Calendário", token: "notion-calendar", isCask: true),
            AppItem(name: "Fantastical", tagline: "Calendário", token: "fantastical", isCask: true),
        ],
        "util": [
            AppItem(name: "The Unarchiver", tagline: "Descompactar arquivos", token: "the-unarchiver", isCask: true),
            AppItem(name: "AppCleaner", tagline: "Desinstalar apps por completo", token: "appcleaner", isCask: true),
            AppItem(name: "Stats", tagline: "Monitor na barra de menu", token: "stats", isCask: true),
            AppItem(name: "Hidden Bar", tagline: "Organizar a barra de menu", token: "hiddenbar", isCask: true),
            AppItem(name: "Maccy", tagline: "Histórico de clipboard", token: "maccy", isCask: true),
        ],
    ]

    // MARK: Atualizar

    static let updates: [String: [UpdatePackage]] = [
        "formulas": [
            UpdatePackage(name: "node", current: "20.11.0", latest: "20.12.1"),
            UpdatePackage(name: "git", current: "2.43.0", latest: "2.44.0"),
            UpdatePackage(name: "python@3.12", current: "3.12.1", latest: "3.12.3"),
            UpdatePackage(name: "ffmpeg", current: "6.1", latest: "6.1.1"),
            UpdatePackage(name: "ripgrep", current: "14.1.0", latest: "14.1.1"),
        ],
        "casks": [
            UpdatePackage(name: "visual-studio-code", current: "1.87", latest: "1.88"),
            UpdatePackage(name: "raycast", current: "1.68", latest: "1.70"),
            UpdatePackage(name: "figma", current: "116.5", latest: "116.9"),
        ],
        "system": [
            UpdatePackage(name: "macOS", current: "26.5", latest: "26.5.1"),
            UpdatePackage(name: "Safari", current: "18.4", latest: "18.5"),
        ],
    ]

    // MARK: Ferramentas
}
