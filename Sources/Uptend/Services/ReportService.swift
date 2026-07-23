import Foundation

// MARK: - Opções do relatório

/// O que incluir no relatório (inventário da máquina).
enum ReportScope: String, CaseIterable, Identifiable, Sendable {
    case complete, apps, hardware, security, storage
    var id: String { rawValue }
    var title: String {
        switch self {
        case .complete: "Relatório completo"
        case .apps: "Somente aplicativos"
        case .hardware: "Somente hardware"
        case .security: "Somente segurança"
        case .storage: "Somente armazenamento"
        }
    }
    var systemImage: String {
        switch self {
        case .complete: "doc.text.magnifyingglass"
        case .apps: "macwindow"
        case .hardware: "cpu"
        case .security: "lock.shield"
        case .storage: "internaldrive"
        }
    }
}

enum ReportFormat: String, CaseIterable, Identifiable, Sendable {
    case markdown, html, json, text
    var id: String { rawValue }
    var title: String {
        switch self {
        case .markdown: "Markdown"
        case .html: "HTML (para imprimir/PDF)"
        case .json: "JSON (dados)"
        case .text: "Texto simples"
        }
    }
    var fileExtension: String {
        switch self {
        case .markdown: "md"
        case .html: "html"
        case .json: "json"
        case .text: "txt"
        }
    }
}

enum ReportDetail: String, CaseIterable, Identifiable, Sendable {
    case summary, detailed
    var id: String { rawValue }
    var title: String { self == .summary ? "Resumido" : "Detalhado" }
}

// MARK: - Dados coletados (inventário)

struct ReportApp: Codable, Sendable, Hashable {
    let name: String
    let version: String?
    let sizeBytes: Int64
    let source: String
    let bundleID: String?
    var sizeLabel: String { ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file) }
}

struct ReportCheck: Codable, Sendable, Hashable {
    let name: String
    let ok: Bool
    let detail: String
}

struct ReportRuntime: Codable, Sendable, Hashable { let name: String; let version: String }
struct ReportFolder: Codable, Sendable, Hashable {
    let name: String; let bytes: Int64
    var sizeLabel: String { ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) }
}
struct ReportFile: Codable, Sendable, Hashable {
    let path: String; let bytes: Int64
    var sizeLabel: String { ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) }
}
struct ReportInterface: Codable, Sendable, Hashable { let name: String; let ip: String; let mac: String }
struct ReportRawSection: Codable, Sendable, Hashable { let title: String; let text: String }

/// Seções "profundas" do pente-fino (coletadas conforme o escopo).
struct ReportDeep: Codable, Sendable {
    // Sistema detalhado
    var osBuild = ""
    var kernel = ""
    var bootTime = ""
    var timezone = ""
    var localHostName = ""
    // Hardware detalhado
    var gpu: [String] = []
    var displays: [String] = []
    var batteryCondition: String = ""
    // Rede detalhada
    var interfaces: [ReportInterface] = []
    var dns: [String] = []
    var gateway: String = ""
    // Integridade & personalizações (original vs. usuário)
    var sip: String = ""
    var startupItems: [String] = []
    var loginItems: [String] = []
    var systemExtensions: [String] = []
    var users: [String] = []
    var brewFormulae: Int = 0
    var brewCasks: Int = 0
    var brewFormulaeList: [String] = []
    var brewCasksList: [String] = []
    var nonAppStoreApps: Int = 0
    var hasUsrLocal = false
    var hasOpt = false
    var shellDotfiles: [String] = []
    var installHistory: [String] = []
    // Ferramentas de linha de comando
    var runtimes: [ReportRuntime] = []
    // Armazenamento
    var folderSizes: [ReportFolder] = []
    var largestFiles: [ReportFile] = []
    var volumes: [String] = []
    // Blocos brutos (componentes e periféricos, do system_profiler)
    var rawSections: [ReportRawSection] = []
}

/// Retrato completo da máquina, montado uma vez e depois formatado sob demanda.
struct ReportData: Codable, Sendable {
    var generatedAt: String
    // Identificação (inventário)
    var computerName: String
    var serialNumber: String
    var modelIdentifier: String
    var hardwareUUID: String
    // Hardware
    var model: String
    var chip: String
    var cores: Int
    var memory: String
    var diskTotal: String
    var diskFree: String
    var batteryCycles: String
    // Sistema / rede
    var osVersion: String
    var uptime: String
    var localIP: String
    // Software
    var apps: [ReportApp]
    var brewPackages: Int
    var outdated: Int
    // Segurança
    var security: [ReportCheck]
    // Pente-fino (opcional, conforme escopo)
    var deep: ReportDeep?

    var totalAppsSize: Int64 { apps.reduce(0) { $0 + $1.sizeBytes } }
}

