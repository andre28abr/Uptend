import Foundation

// =============================================================================
// CATÁLOGO DE CONTROLES + DECLARAÇÃO DE APLICABILIDADE (SoA) — FASE B1
// Gap-assessment por framework: em vez de só medir o que a auditoria toca,
// lista TODOS os controles do framework e dá um status honesto a cada um:
//   • Coberto        — a auditoria verifica e está conforme
//   • Não conforme   — a auditoria verifica e há achado aberto (gap)
//   • Não avaliado   — controle técnico que poderíamos checar, mas esta coleta não checou
//   • Manual         — exige processo/política/evidência fora da coleta automática
//   • Não aplicável  — decisão de escopo (marcado à parte)
// Gera a Declaração de Aplicabilidade (SoA) que a ISO 27001 exige.
// Foco inicial: ISO/IEC 27001:2022 Anexo A (93 controles). Lógica pura → testável.
// =============================================================================

public enum SoAStatus: String, Sendable, CaseIterable {
    case coberto = "Coberto"
    case naoConforme = "Não conforme"
    case naoAvaliado = "Não avaliado"
    case manual = "Manual"
    case naoAplicavel = "Não aplicável"

    public var colorHex: String {
        switch self {
        case .coberto: "#30a46c"
        case .naoConforme: "#e5484d"
        case .naoAvaliado: "#8a8a8f"
        case .manual: "#4a90d9"
        case .naoAplicavel: "#6b6b70"
        }
    }
    /// Conta no denominador de "% de conformidade automatizável"?
    public var isAutomatedScope: Bool { self == .coberto || self == .naoConforme || self == .naoAvaliado }
}

public enum ControlNature: String, Sendable {
    case automatable   // a coleta do host consegue inspecionar
    case manual        // exige processo/política/pessoas/físico
}

public struct ControlCatalogEntry: Identifiable, Equatable, Sendable {
    public let id: String        // ex.: "A.8.20"
    public let title: String     // título em PT
    public let theme: String     // Organizacional / Pessoas / Físico / Tecnológico
    public let nature: ControlNature
}

public struct SoAControl: Identifiable, Equatable, Sendable {
    public let entry: ControlCatalogEntry
    public let status: SoAStatus
    public let findingIds: [String]   // achados que sustentam o status (quando houver)
    public var id: String { entry.id }
}

public struct SoASummary: Sendable, Equatable {
    public let total: Int
    public let counts: [SoAStatus: Int]
    /// % de conformidade sobre o escopo automatizável (coberto / (coberto+não conforme+não avaliado)).
    public let automatedPercent: Int
    /// % coberto sobre o que a auditoria de fato verificou (coberto / (coberto+não conforme)).
    public let checkedPercent: Int
}

public enum ComplianceCatalog {

    // MARK: Transição ISO 27001:2013 → 2022 (só os refs que o ComplianceMap emite)

    static func iso2022(_ ref2013: String) -> String? {
        switch ref2013 {
        case "A.9.2.3": "A.8.2"        // direitos de acesso privilegiado
        case "A.9.2.4": "A.5.17"       // informação de autenticação
        case "A.9.4.1": "A.8.3"        // restrição de acesso à informação
        case "A.9.4.2": "A.8.5"        // autenticação segura
        case "A.9.4.3": "A.5.17"       // gestão de senhas → informação de autenticação
        case "A.10.1.1": "A.8.24"      // uso de criptografia
        case "A.11.2.4": "A.7.13"      // manutenção de equipamento
        case "A.11.2.8": "A.8.1"       // equipamento sem supervisão → dispositivos do usuário
        case "A.12.1.1": "A.5.37"      // procedimentos operacionais documentados
        case "A.12.1.3": "A.8.6"       // gestão de capacidade
        case "A.12.2.1": "A.8.7"       // proteção contra malware
        case "A.12.4.1": "A.8.15"      // registro (logging)
        case "A.12.4.4": "A.8.17"      // sincronização de relógio
        case "A.12.6.1": "A.8.8"       // gestão de vulnerabilidades técnicas
        case "A.13.1.1": "A.8.20"      // segurança de redes
        case "A.13.1.3": "A.8.22"      // segregação de redes
        case "A.14.1.2": "A.8.26"      // requisitos de segurança da aplicação
        case "A.14.2.5": "A.8.27"      // princípios de engenharia/arquitetura seguras
        default: nil
        }
    }

    // MARK: Catálogo ISO/IEC 27001:2022 Anexo A (93 controles)

    public static let iso27001_2022: [ControlCatalogEntry] = {
        func e(_ id: String, _ t: String, _ theme: String, _ n: ControlNature) -> ControlCatalogEntry {
            ControlCatalogEntry(id: id, title: t, theme: theme, nature: n)
        }
        let org = "Organizacional", ppl = "Pessoas", phy = "Físico", tec = "Tecnológico"
        let M = ControlNature.manual, A = ControlNature.automatable
        return [
            // A.5 Organizacional (37)
            e("A.5.1", "Políticas de segurança da informação", org, M),
            e("A.5.2", "Papéis e responsabilidades de segurança", org, M),
            e("A.5.3", "Segregação de funções", org, M),
            e("A.5.4", "Responsabilidades da direção", org, M),
            e("A.5.5", "Contato com autoridades", org, M),
            e("A.5.6", "Contato com grupos de interesse especial", org, M),
            e("A.5.7", "Inteligência de ameaças", org, M),
            e("A.5.8", "Segurança da informação na gestão de projetos", org, M),
            e("A.5.9", "Inventário de informações e ativos associados", org, M),
            e("A.5.10", "Uso aceitável de informações e ativos", org, M),
            e("A.5.11", "Devolução de ativos", org, M),
            e("A.5.12", "Classificação da informação", org, M),
            e("A.5.13", "Rotulagem da informação", org, M),
            e("A.5.14", "Transferência de informações", org, M),
            e("A.5.15", "Controle de acesso", org, A),
            e("A.5.16", "Gestão de identidade", org, A),
            e("A.5.17", "Informação de autenticação", org, A),
            e("A.5.18", "Direitos de acesso", org, A),
            e("A.5.19", "Segurança na relação com fornecedores", org, M),
            e("A.5.20", "Segurança em acordos com fornecedores", org, M),
            e("A.5.21", "Segurança na cadeia de suprimento de TIC", org, M),
            e("A.5.22", "Monitoramento e revisão de serviços de fornecedores", org, M),
            e("A.5.23", "Segurança no uso de serviços em nuvem", org, M),
            e("A.5.24", "Planejamento e preparação da resposta a incidentes", org, M),
            e("A.5.25", "Avaliação e decisão sobre eventos de segurança", org, M),
            e("A.5.26", "Resposta a incidentes de segurança", org, M),
            e("A.5.27", "Aprendizado com incidentes", org, M),
            e("A.5.28", "Coleta de evidências", org, M),
            e("A.5.29", "Segurança durante disrupção", org, M),
            e("A.5.30", "Prontidão de TIC para continuidade de negócio", org, M),
            e("A.5.31", "Requisitos legais, estatutários e contratuais", org, M),
            e("A.5.32", "Direitos de propriedade intelectual", org, M),
            e("A.5.33", "Proteção de registros", org, M),
            e("A.5.34", "Privacidade e proteção de dados pessoais", org, M),
            e("A.5.35", "Revisão independente da segurança da informação", org, M),
            e("A.5.36", "Conformidade com políticas e normas de segurança", org, M),
            e("A.5.37", "Procedimentos operacionais documentados", org, M),
            // A.6 Pessoas (8)
            e("A.6.1", "Triagem (verificação de antecedentes)", ppl, M),
            e("A.6.2", "Termos e condições de contratação", ppl, M),
            e("A.6.3", "Conscientização, educação e treinamento", ppl, M),
            e("A.6.4", "Processo disciplinar", ppl, M),
            e("A.6.5", "Responsabilidades após encerramento ou mudança", ppl, M),
            e("A.6.6", "Acordos de confidencialidade ou não divulgação", ppl, M),
            e("A.6.7", "Trabalho remoto", ppl, M),
            e("A.6.8", "Relato de eventos de segurança da informação", ppl, M),
            // A.7 Físico (14)
            e("A.7.1", "Perímetros de segurança física", phy, M),
            e("A.7.2", "Entrada física", phy, M),
            e("A.7.3", "Segurança de escritórios, salas e instalações", phy, M),
            e("A.7.4", "Monitoramento de segurança física", phy, M),
            e("A.7.5", "Proteção contra ameaças físicas e ambientais", phy, M),
            e("A.7.6", "Trabalho em áreas seguras", phy, M),
            e("A.7.7", "Mesa limpa e tela limpa", phy, M),
            e("A.7.8", "Localização e proteção de equipamentos", phy, M),
            e("A.7.9", "Segurança de ativos fora das instalações", phy, M),
            e("A.7.10", "Mídia de armazenamento", phy, M),
            e("A.7.11", "Utilidades de suporte", phy, M),
            e("A.7.12", "Segurança do cabeamento", phy, M),
            e("A.7.13", "Manutenção de equipamentos", phy, A),
            e("A.7.14", "Descarte ou reutilização segura de equipamentos", phy, M),
            // A.8 Tecnológico (34)
            e("A.8.1", "Dispositivos de endpoint do usuário", tec, A),
            e("A.8.2", "Direitos de acesso privilegiado", tec, A),
            e("A.8.3", "Restrição de acesso à informação", tec, A),
            e("A.8.4", "Acesso ao código-fonte", tec, M),
            e("A.8.5", "Autenticação segura", tec, A),
            e("A.8.6", "Gestão de capacidade", tec, A),
            e("A.8.7", "Proteção contra malware", tec, A),
            e("A.8.8", "Gestão de vulnerabilidades técnicas", tec, A),
            e("A.8.9", "Gestão de configuração", tec, A),
            e("A.8.10", "Exclusão de informações", tec, M),
            e("A.8.11", "Mascaramento de dados", tec, M),
            e("A.8.12", "Prevenção de vazamento de dados (DLP)", tec, M),
            e("A.8.13", "Backup das informações", tec, M),
            e("A.8.14", "Redundância dos recursos de processamento", tec, M),
            e("A.8.15", "Registro de eventos (logging)", tec, A),
            e("A.8.16", "Atividades de monitoramento", tec, A),
            e("A.8.17", "Sincronização de relógio", tec, A),
            e("A.8.18", "Uso de programas utilitários privilegiados", tec, M),
            e("A.8.19", "Instalação de software em sistemas operacionais", tec, M),
            e("A.8.20", "Segurança de redes", tec, A),
            e("A.8.21", "Segurança de serviços de rede", tec, M),
            e("A.8.22", "Segregação de redes", tec, A),
            e("A.8.23", "Filtragem web", tec, M),
            e("A.8.24", "Uso de criptografia", tec, A),
            e("A.8.25", "Ciclo de vida de desenvolvimento seguro", tec, M),
            e("A.8.26", "Requisitos de segurança da aplicação", tec, A),
            e("A.8.27", "Princípios de arquitetura e engenharia seguras", tec, A),
            e("A.8.28", "Codificação segura", tec, M),
            e("A.8.29", "Testes de segurança em desenvolvimento e homologação", tec, M),
            e("A.8.30", "Desenvolvimento terceirizado", tec, M),
            e("A.8.31", "Separação de ambientes (dev/teste/produção)", tec, M),
            e("A.8.32", "Gestão de mudanças", tec, M),
            e("A.8.33", "Informações de teste", tec, M),
            e("A.8.34", "Proteção de sistemas durante testes de auditoria", tec, M),
        ]
    }()

    // MARK: SoA — cruza o catálogo com os achados da auditoria

    /// Agrupa os achados por controle ISO 2022 (via ComplianceMap + transição).
    static func findingsByISO2022(_ audit: ExternalAudit) -> [String: [AuditFinding]] {
        var map: [String: [AuditFinding]] = [:]
        for f in audit.findings {
            guard let ref2013 = ComplianceMap.refs(for: f).iso27001,
                  let c = iso2022(ref2013) else { continue }
            map[c, default: []].append(f)
        }
        return map
    }

    /// Declaração de Aplicabilidade para ISO 27001:2022 (todos os 93 controles com status).
    public static func soaISO27001(_ audit: ExternalAudit) -> [SoAControl] {
        let byControl = findingsByISO2022(audit)
        return iso27001_2022.map { entry in
            let fs = byControl[entry.id] ?? []
            let status: SoAStatus
            if !fs.isEmpty {
                status = fs.contains { $0.severity > .ok } ? .naoConforme : .coberto
            } else {
                status = entry.nature == .manual ? .manual : .naoAvaliado
            }
            return SoAControl(entry: entry, status: status,
                              findingIds: fs.filter { $0.severity > .ok }.map(\.id))
        }
    }

    public static func summary(_ soa: [SoAControl]) -> SoASummary {
        var counts: [SoAStatus: Int] = [:]
        for c in soa { counts[c.status, default: 0] += 1 }
        let coberto = counts[.coberto] ?? 0
        let naoConf = counts[.naoConforme] ?? 0
        let naoAval = counts[.naoAvaliado] ?? 0
        let autoScope = coberto + naoConf + naoAval
        let checked = coberto + naoConf
        return SoASummary(
            total: soa.count, counts: counts,
            automatedPercent: autoScope == 0 ? 0 : Int(Double(coberto) / Double(autoScope) * 100),
            checkedPercent: checked == 0 ? 0 : Int(Double(coberto) / Double(checked) * 100))
    }

    // MARK: Export CSV

    public static func csv(_ soa: [SoAControl]) -> String {
        var out = "controle,titulo,tema,natureza,status,achados\n"
        for c in soa {
            out += [c.entry.id, c.entry.title, c.entry.theme,
                    c.entry.nature == .manual ? "manual" : "automatizável",
                    c.status.rawValue, c.findingIds.joined(separator: " ")]
                .map(csvEscape).joined(separator: ",") + "\n"
        }
        return out
    }

    private static func csvEscape(_ v: String) -> String {
        if v.contains(",") || v.contains("\"") || v.contains("\n") {
            return "\"" + v.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return v
    }
}
