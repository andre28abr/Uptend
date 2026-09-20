# Inventário do código: Uptend

> Gerado por `raiz/maquina/inventario.py` em 2026-09-20, direto do código. Não editar à mão: regenerar ao fechar um bloco de trabalho. Serve de mapa para quem vai mexer no projeto; a explicação do porquê está no README, no CLAUDE.md e nos docs do repositório. Testes são contados por função declarada; o pytest e o cargo podem reportar mais execuções por causa de parametrização.

## Resumo

| Linguagem | Números |
|---|---|
| Swift | 152 arquivos, 431 tipos, 428 testes |

## Swift

| Arquivo | Pasta | Tipos | Principais tipos · doc |
|---|---|---|---|
| `Package.swift` | Uptend | 0 |  |
| `Sources/Uptend/App/AppState.swift` | App | 4 | Appearance, AppState, HostKind, HostContext · Aparência escolhida pelo usuário. `system` acompanha o macOS. |
| `Sources/Uptend/App/UptendApp.swift` | App | 2 | UptendApp, AppDelegate · Garante que a janela apareça e ganhe foco mesmo rodando o binário direto |
| `Sources/Uptend/Model/Category.swift` | Model | 3 | SubSection, Category, Titled · Uma subseção dentro de uma categoria (a coluna do meio, no layout de 3 colunas). |
| `Sources/Uptend/Model/MockData.swift` | Model | 1 | MockData · Dados de exemplo para a interface. Depois serão substituídos por dados reais |
| `Sources/Uptend/Model/Models.swift` | Model | 5 | AppItem, UpdatePackage, GitStatus, CheckStatus, SecurityCheck |
| `Sources/Uptend/Services/ActionLog.swift` | Services | 2 | ActionEntry, ActionLog · Registro das ações relevantes (instalar, remover, limpar, sincronizar). |
| `Sources/Uptend/Services/AppCheckService.swift` | Services | 3 | TrustLevel, AppVerdict, AppCheckService · Veredito de segurança de um app: assinatura, notarização, Gatekeeper e quarentena. |
| `Sources/Uptend/Services/AppsService.swift` | Services | 3 | AppOrigin, MacApp, AppsService · Lista os apps em /Applications e permite desinstalá-los movendo para a Lixeira |
| `Sources/Uptend/Services/AuditSigner.swift` | Services | 1 | AuditSigner |
| `Sources/Uptend/Services/BaselineStore.swift` | Services | 1 | BaselineStore |
| `Sources/Uptend/Services/BrandingStore.swift` | Services | 1 | BrandingStore |
| `Sources/Uptend/Services/BrewService.swift` | Services | 5 | OutdatedItem, SearchResult, BrewInfo, BrewOutdated, BrewService · Pacote desatualizado, vindo de `brew outdated --json=v2`. |
| `Sources/Uptend/Services/ClamAVService.swift` | Services | 1 | ClamAVService · Frente gráfica para o ClamAV (antivírus open-source, instalado via Homebrew). |
| `Sources/Uptend/Services/CleanupService.swift` | Services | 2 | CleanupTarget, CleanupService · Um alvo de limpeza. `kind` define o comportamento e, principalmente, se é reversível. |
| `Sources/Uptend/Services/ClipboardService.swift` | Services | 1 | ClipboardService · Histórico de clipboard mantido apenas em memória e apenas enquanto o app está |
| `Sources/Uptend/Services/CodeHighlighter.swift` | Services | 1 | CodeHighlighter · Realce de sintaxe leve e nativo (sem dependências). Um scanner de passo único |
| `Sources/Uptend/Services/CommandRunner.swift` | Services | 3 | CommandRunning, LiveCommandRunner, InstallableTool · Abstração sobre a execução de processos, para que os serviços recebam um |
| `Sources/Uptend/Services/ConnectionsService.swift` | Services | 2 | Connection, ConnectionsService · Lista as conexões TCP estabelecidas da máquina (leitura via lsof — só o próprio Mac). |
| `Sources/Uptend/Services/Converters.swift` | Services | 1 | Converters · Conversores locais (nada sai da máquina). Funções puras e testáveis. |
| `Sources/Uptend/Services/CryptoTools.swift` | Services | 2 | PasswordGenerator, HashUtil · Gera senhas fortes localmente (nada sai da máquina — Privacy by Design). |
| `Sources/Uptend/Services/DockerService.swift` | Services | 6 | DockerContainerInfo, DockerImageInfo, DockerVolumeInfo, DockerNetworkInfo, ContainerEngine, DockerService · Um "motor de containers" que o usuário pode ter instalado (a caixinha que roda o Linux). |
| `Sources/Uptend/Services/DotfilesService.swift` | Services | 2 | DotfileItem, DotfilesService · Restaura arquivos de configuração ("dotfiles") de uma pasta de backup escolhida |
| `Sources/Uptend/Services/EnergyService.swift` | Services | 3 | BatteryInfo2, ProcInfo, EnergyService · Lê saúde da bateria (`pmset`, `system_profiler`) e os processos que mais |
| `Sources/Uptend/Services/ExposureService.swift` | Services | 2 | ListeningPort, ExposureService · Uma porta em escuta detectada pelo `netstat` (superfície de ataque). |
| `Sources/Uptend/Services/ExternalAuditService.swift` | Services | 2 | LoadedAudit, ExternalAuditService · Uma auditoria carregada na interface: o documento + de onde veio + a nota. |
| `Sources/Uptend/Services/FavoritesService.swift` | Services | 1 | FavoritesService · Lista de repositórios favoritos (URLs) para clonar todos de uma vez numa pasta escolhida. |
| `Sources/Uptend/Services/FileUtils.swift` | Services | 1 | FileUtils · Utilitários de arquivo compartilhados (cálculo de tamanho em disco). |
| `Sources/Uptend/Services/FocusService.swift` | Services | 1 | FocusService · Modo foco: limpa a mesa (oculta os ícones da Mesa) e oculta o Dock automaticamente. |
| `Sources/Uptend/Services/GitAuth.swift` | Services | 1 | GitAuth · Autenticação do git por HTTPS usando o token do GitHub, sem jamais expor o |
| `Sources/Uptend/Services/GitHubService.swift` | Services | 4 | GitHubAccount, GitHubRepo, GitHubService, GitHubError · Conta conectada do GitHub (dados públicos do usuário autenticado). |
| `Sources/Uptend/Services/GitService.swift` | Services | 3 | GitRepoInfo, GitService, GitFileChange · Estado real de um repositório Git monitorado. |
| `Sources/Uptend/Services/HealthService.swift` | Services | 3 | BatteryInfo, DiskHealth, HealthService · Saúde do hardware: bateria (condição, ciclos, capacidade) e status SMART dos discos. |
| `Sources/Uptend/Services/HomeLabMonitor.swift` | Services | 2 | RemoteOverview, HomeLabMonitor · Instantâneo de saúde de um host remoto (para a "Visão geral"). |
| `Sources/Uptend/Services/Keychain.swift` | Services | 1 | Keychain · Guarda segredos (ex.: token do GitHub, senha de banco) no Keychain do macOS — |
| `Sources/Uptend/Services/LatencyMonitor.swift` | Services | 1 | LatencyMonitor · Mede latência continuamente (ping) para avaliar a estabilidade da conexão. |
| `Sources/Uptend/Services/LinuxStats.swift` | Services | 1 | LinuxStats · Parsers puros da saída de comandos Linux (para a "Visão geral" do HomeLab). |
| `Sources/Uptend/Services/LocationService.swift` | Services | 1 | LocationService · Pede autorização de Localização — exigida pelo macOS apenas para ler o nome (SSID) |
| `Sources/Uptend/Services/MetabaseAPI.swift` | Services | 2 | MetabaseAPI, MetabaseCredentials |
| `Sources/Uptend/Services/MonitorService.swift` | Services | 1 | MonitorService · Amostra CPU, memória e tráfego de rede em intervalos, mantendo um pequeno |
| `Sources/Uptend/Services/MyPackages.swift` | Services | 6 | TapProgram, TapProvider, TapDiscovery, MyPackage, MyPackagesStore, TapProvidersStore · Um programa (fórmula ou cask) oferecido por um tap de terceiros do Homebrew. |
| `Sources/Uptend/Services/NetworkTools.swift` | Services | 1 | NetworkTools · Ferramentas de rede. IP local é lido localmente; IP público exige contatar um |
| `Sources/Uptend/Services/PortsService.swift` | Services | 2 | PortInfo, PortsService · Lista portas TCP em escuta e permite encerrar o processo dono (sem sudo — processos do usuário). |
| `Sources/Uptend/Services/ProfilesService.swift` | Services | 2 | BrewProfile, ProfilesService · Gerencia "perfis" — Brewfiles salvos com a lista de apps/ferramentas do usuário, |
| `Sources/Uptend/Services/RemoteBackup.swift` | Services | 3 | BackupSnapshot, ResticSnapshotJSON, RemoteBackup |
| `Sources/Uptend/Services/RemoteDeploy.swift` | Services | 1 | RemoteDeploy |
| `Sources/Uptend/Services/RemoteDisks.swift` | Services | 3 | BlockDevice, FSUsage, RemoteDisks |
| `Sources/Uptend/Services/RemoteDocker.swift` | Services | 4 | RemoteContainer, RemoteImage, RemoteVolume, RemoteDocker |
| `Sources/Uptend/Services/RemoteFiles.swift` | Services | 2 | RemoteFile, RemoteFiles |
| `Sources/Uptend/Services/RemoteHost.swift` | Services | 5 | RemoteHost, DBCredential, DBCredentialStore, HostStore, SSHRunner · Um servidor remoto (HomeLab ou Servidor Linux) que o Uptend gerencia por SSH. |
| `Sources/Uptend/Services/RemoteNetwork.swift` | Services | 3 | NetworkInfo, RemoteListeningPort, RemoteNetwork |
| `Sources/Uptend/Services/RemoteSecurity.swift` | Services | 2 | ServerSecurityCheck, RemoteSecurity |
| `Sources/Uptend/Services/RemoteServer.swift` | Services | 4 | ServiceUnit, RemoteSystemd, AptPackage, RemoteApt |
| `Sources/Uptend/Services/RemoteTerminal.swift` | Services | 1 | RemoteTerminal |
| `Sources/Uptend/Services/ReportBuilder.swift` | Services | 1 | ReportBuilder · Coleta o inventário da máquina (dados dos serviços + ferramentas do macOS). |
| `Sources/Uptend/Services/ReportRenderers.swift` | Services | 1 | SystemReport |
| `Sources/Uptend/Services/ReportService.swift` | Services | 12 | ReportScope, ReportFormat, ReportDetail, ReportApp, ReportCheck, ReportRuntime … · O que incluir no relatório (inventário da máquina). |
| `Sources/Uptend/Services/RiskExceptionStore.swift` | Services | 1 | RiskExceptionStore |
| `Sources/Uptend/Services/RuntimesService.swift` | Services | 2 | RuntimeInfo, RuntimesService · Mostra as versões de runtimes (Node, Python, Ruby) e permite trocar a versão global |
| `Sources/Uptend/Services/SQLiteSchemaReader.swift` | Services | 1 | SQLiteSchemaReader |
| `Sources/Uptend/Services/SSHService.swift` | Services | 2 | SSHKey, SSHService · Lista chaves SSH públicas e gera novas (ed25519). |
| `Sources/Uptend/Services/ScheduleService.swift` | Services | 1 | ScheduleService · Lembretes de manutenção recorrente (limpeza e atualizações). Guarda o intervalo |
| `Sources/Uptend/Services/Security.swift` | Services | 1 | InputValidator · Validação de entradas antes de virarem argumentos de comandos externos. |
| `Sources/Uptend/Services/SecurityMonitor.swift` | Services | 2 | SecurityEvent, SecurityMonitor |
| `Sources/Uptend/Services/SecurityScanners.swift` | Services | 5 | SecretFinding, SecretScanService, AuditService, DepVuln, DepsScanService · Uma ocorrência de segredo encontrada pelo gitleaks (secret já redigido). |
| `Sources/Uptend/Services/SecurityService.swift` | Services | 1 | SecurityService · Lê o estado de segurança do Mac (somente leitura, sem sudo). |
| `Sources/Uptend/Services/ServerAlerts.swift` | Services | 2 | ServerAlert, ServerAlertsService |
| `Sources/Uptend/Services/ServerSetup.swift` | Services | 2 | SetupStep, ServerSetup |
| `Sources/Uptend/Services/ServiceTemplates.swift` | Services | 5 | TemplateField, ServiceTemplate, ServiceCatalog, ServiceStack, RemoteTask · Um stack pesado (multi-container) instalado por um script fixo, sob demanda. |
| `Sources/Uptend/Services/ServicesService.swift` | Services | 2 | BrewServiceItem, ServicesService · Um serviço de fundo gerenciado pelo `brew services` (Postgres, Redis, etc.). |
| `Sources/Uptend/Services/Shell.swift` | Services | 2 | CommandResult, Shell · Executa processos externos (Homebrew, git, etc.). Duas formas: |
| `Sources/Uptend/Services/SpaceAnalyzerService.swift` | Services | 2 | SpaceItem, SpaceAnalyzerService · Mostra o que ocupa espaço numa pasta (tamanho por item), com navegação para dentro. |
| `Sources/Uptend/Services/SpeedTest.swift` | Services | 1 | SpeedTest · Teste de velocidade real (download/upload) usando os endpoints públicos da Cloudflare. |
| `Sources/Uptend/Services/StorageService.swift` | Services | 4 | StorageFolder, StorageFile, DuplicateGroup, StorageService · Um grupo de arquivos idênticos (mesmo conteúdo). |
| `Sources/Uptend/Services/SystemService.swift` | Services | 3 | MacInfo, SystemToggle, SystemService · Um ajuste rápido do sistema baseado em `defaults` (sem sudo, por usuário). |
| `Sources/Uptend/Services/TLSScanner.swift` | Services | 4 | TLSProbeResult, AuditSeverityLevel, ProbeBox, TLSScanner · Referência mutável para capturar o certificado dentro do verify block. |
| `Sources/Uptend/Services/UptendVault.swift` | Services | 3 | VaultRecord, VaultKind, UptendVault · Metadados de um registro guardado (sem o payload, para listagens rápidas). |
| `Sources/Uptend/Services/WiFiService.swift` | Services | 2 | WiFiInfo, WiFiService · Lê informações do Wi-Fi via CoreWLAN (local, sem rede). SSID exige permissão de |
| `Sources/Uptend/Services/XcodeService.swift` | Services | 2 | SimDevice, XcodeService · Gerencia o Xcode (versão, DerivedData) e os simuladores de iOS/iPadOS. |
| `Sources/Uptend/Views/AppCheckView.swift` | Views | 1 | AppCheckView · "Posso abrir isso com segurança?" — verifica assinatura, notarização, |
| `Sources/Uptend/Views/AppDataView.swift` | Views | 1 | AppDataView |
| `Sources/Uptend/Views/ApplicationsView.swift` | Views | 1 | ApplicationsView |
| `Sources/Uptend/Views/AuditoriaExternaView.swift` | Views | 21 | AuditoriaSection, AuditoriaSidebar, AuditoriaContentColumn, AuditoriaDetailColumn, AuditoriaExternaView, AuditImportView … · Cores do semáforo (verde/amarelo/vermelho) reutilizadas no painel. |
| `Sources/Uptend/Views/BrandingView.swift` | Views | 1 | BrandingView |
| `Sources/Uptend/Views/ClamAVView.swift` | Views | 1 | ClamAVView |
| `Sources/Uptend/Views/CleanupView.swift` | Views | 1 | CleanupView |
| `Sources/Uptend/Views/CodeView.swift` | Views | 1 | CodeView · Mostra código com realce de sintaxe e (opcional) números de linha. Só leitura. |
| `Sources/Uptend/Views/CompareProfileView.swift` | Views | 1 | CompareProfileView |
| `Sources/Uptend/Views/Components.swift` | Views | 8 | ScreenHeader, IconButton, ErrorBanner, StatusDot, StatCard, CardRow … · Título + subtítulo + ações à direita, padrão no topo de cada tela. |
| `Sources/Uptend/Views/DashboardView.swift` | Views | 1 | DashboardView |
| `Sources/Uptend/Views/DockerView.swift` | Views | 1 | DockerView |
| `Sources/Uptend/Views/EnergyView.swift` | Views | 1 | EnergyView · Bateria & Energia: saúde da bateria e apps que mais consomem. |
| `Sources/Uptend/Views/EnvironmentSetupView.swift` | Views | 2 | EnvTool, EnvironmentSetupView · Uma ferramenta que o Uptend pode usar, com como detectar e como instalar. |
| `Sources/Uptend/Views/ExposureView.swift` | Views | 1 | ExposureView · Painel de "superfície de ataque": firewall, stealth e serviços de acesso remoto |
| `Sources/Uptend/Views/FavoritesView.swift` | Views | 1 | FavoritesView |
| `Sources/Uptend/Views/GitHubViews.swift` | Views | 4 | GitHubAccountView, PublishRepoView, RepoSettingsSheet, GitHubReposView · Conectar/desconectar a conta do GitHub via token pessoal (guardado no Keychain). |
| `Sources/Uptend/Views/GitView.swift` | Views | 2 | GitView, CommitSheet · Mostra os arquivos alterados e recebe a mensagem, faz commit + push num clique. |
| `Sources/Uptend/Views/HomeLab.swift` | Views | 36 | HomeLabSection, HostTabBar, HomeLabSidebar, HomeLabContentColumn, HomeLabDetailColumn, HLPreviewBanner … · Aviso fixo de que é só interface, sem dados reais. |
| `Sources/Uptend/Views/HomebrewView.swift` | Views | 11 | HomebrewView, BrewSearchView, SourceTag, BrewInfoSheet, BrewTidyView, BrewEssentialsView … · Central do Homebrew: roteia entre as subseções. |
| `Sources/Uptend/Views/MarkdownView.swift` | Views | 1 | MarkdownView · Renderiza Markdown (só leitura) a partir dos blocos do `MarkdownParser`. |
| `Sources/Uptend/Views/MenuBarDashboard.swift` | Views | 1 | MenuBarDashboard · Mini painel que aparece ao clicar no ícone da barra de menu. |
| `Sources/Uptend/Views/NetworkView.swift` | Views | 8 | NetworkView, WiFiCard, QualityCard, AddressesCard, ConnectionsCard, SpeedTestCard … |
| `Sources/Uptend/Views/NotificationCenterView.swift` | Views | 4 | NotificationBell, NotificationPanel, TodoItem, NotificationCenterView · O sino da toolbar. Apenas alterna o estado — o painel é um overlay no RootView |
| `Sources/Uptend/Views/RepoBrowserView.swift` | Views | 3 | RepoBrowserView, BrowseTarget, LoadedContent · Navegador de arquivos de um repositório local — só leitura. Árvore à esquerda, |
| `Sources/Uptend/Views/ReportPanel.swift` | Views | 1 | ReportPanel · Painel do relatório/inventário da máquina: escolhe escopo, formato e nível de |
| `Sources/Uptend/Views/RootView.swift` | Views | 5 | RootView, SidebarView, ActivityDot, ContentColumn, DetailColumn · Layout de três colunas: categorias | subseções | conteúdo. |
| `Sources/Uptend/Views/RunningTaskView.swift` | Views | 1 | RunningTaskView · Folha que mostra a saída ao vivo de um comando do Homebrew. |
| `Sources/Uptend/Views/RuntimesToolView.swift` | Views | 1 | RuntimesToolView |
| `Sources/Uptend/Views/SecurityScannersView.swift` | Views | 6 | ScannerMissingCard, ScanTargetPicker, SecretScanView, ScannerIntro, AuditView, DepsScanView · Aparece quando a ferramenta OSS não está instalada — oferece instalar via Homebrew. |
| `Sources/Uptend/Views/SecurityView.swift` | Views | 3 | SecurityView, PasswordGeneratorCard, HashToolCard |
| `Sources/Uptend/Views/ServicesView.swift` | Views | 1 | ServicesView · Serviços de fundo do Homebrew: ligar/desligar bancos de dados e afins. |
| `Sources/Uptend/Views/SettingsView.swift` | Views | 1 | SettingsView |
| `Sources/Uptend/Views/SetupView.swift` | Views | 4 | SetupView, FirstRunView, ProfilesSetupView, DotfilesSetupView |
| `Sources/Uptend/Views/SpaceAnalyzerView.swift` | Views | 1 | SpaceAnalyzerView |
| `Sources/Uptend/Views/StorageView.swift` | Views | 1 | StorageView · Armazenamento & Discos: uso do disco e caça-duplicados. |
| `Sources/Uptend/Views/SystemExtraViews.swift` | Views | 2 | HealthView, FocusView |
| `Sources/Uptend/Views/SystemView.swift` | Views | 1 | SystemView |
| `Sources/Uptend/Views/TapsView.swift` | Views | 6 | FavoriteButton, KindTag, TapOriginBadge, ManagedProgram, MyPackagesView, TapManagerView · Estrela para favoritar um programa de fonte de terceiros. Cheia = favoritado. |
| `Sources/Uptend/Views/ToastCenter.swift` | Views | 3 | Toast, ToastCenter, ToastView · Avisos rápidos (toasts) de sucesso/erro, no rodapé da janela. |
| `Sources/Uptend/Views/ToolsView.swift` | Views | 7 | Clipboard, ToolsView, ConvertersToolView, QRToolView, PortsToolView, SSHToolView … |
| `Sources/Uptend/Views/Tooltip.swift` | Views | 3 | TooltipData, TooltipKey, TipModifier |
| `Sources/Uptend/Views/WebPanel.swift` | Views | 6 | EmbeddedWeb, EmbeddedHTML, ReportWindow, HTMLToPDF, ServicePanelSheet, PanelTarget · WebView que renderiza uma string de HTML (relatório autocontido). Não faz rede — |
| `Sources/Uptend/Views/XcodeView.swift` | Views | 1 | XcodeView · Xcode & Simuladores: versão, limpeza do DerivedData e gestão dos simuladores. |
| `Sources/UptendCore/AttackSurfaceMap.swift` | UptendCore | 3 | SurfaceEntry, AttackSurface, AttackSurfaceMap |
| `Sources/UptendCore/AuditCompare.swift` | UptendCore | 2 | AuditComparison, AuditCompare |
| `Sources/UptendCore/AuditDashboard.swift` | UptendCore | 1 | AuditDashboard |
| `Sources/UptendCore/AuditDataset.swift` | UptendCore | 1 | AuditDataset |
| `Sources/UptendCore/AuditDomains.swift` | UptendCore | 2 | DomainScore, AuditDomains |
| `Sources/UptendCore/AuditReport.swift` | UptendCore | 1 | AuditReport |
| `Sources/UptendCore/Baseline.swift` | UptendCore | 7 | BaselineItem, Baseline, BaselineStatus, BaselineResult, BaselineSummary, BaselineProfile … |
| `Sources/UptendCore/CVE.swift` | UptendCore | 4 | CVE, CVEMatch, CVEDatabase, CVEMatcher |
| `Sources/UptendCore/ComplianceCatalog.swift` | UptendCore | 6 | SoAStatus, ControlNature, ControlCatalogEntry, SoAControl, SoASummary, ComplianceCatalog |
| `Sources/UptendCore/ComplianceMap.swift` | UptendCore | 4 | FrameworkRefs, ComplianceFramework, FrameworkCoverage, ComplianceMap · Referências de frameworks para um achado. |
| `Sources/UptendCore/DatabaseAudit.swift` | UptendCore | 1 | DatabaseAudit |
| `Sources/UptendCore/DatabaseSchema.swift` | UptendCore | 3 | DBColumn, DBTable, DatabaseSchema |
| `Sources/UptendCore/DetectionRules.swift` | UptendCore | 2 | DetectionRule, DetectionRules |
| `Sources/UptendCore/DriftAnalysis.swift` | UptendCore | 3 | DriftLevel, DriftReport, DriftAnalysis |
| `Sources/UptendCore/ExternalAudit.swift` | UptendCore | 8 | AuditSeverity, AuditFinding, ExternalAudit, ExternalAuditParser, AuditLight, AuditCategoryStatus … · Severidade de um achado, do "tudo certo" ao "crítico". Comparável (para ordenar |
| `Sources/UptendCore/FleetRollup.swift` | UptendCore | 4 | FleetHostRow, FleetFinding, Fleet, FleetRollup |
| `Sources/UptendCore/HardeningPlaybook.swift` | UptendCore | 1 | HardeningPlaybook |
| `Sources/UptendCore/LGPDLens.swift` | UptendCore | 4 | LGPDArticle, LGPDItem, LGPDSummary, LGPDLens |
| `Sources/UptendCore/MarkdownParser.swift` | UptendCore | 2 | MarkdownBlock, MarkdownParser · Bloco de Markdown reconhecido pelo parser. O realce inline (negrito, itálico, |
| `Sources/UptendCore/MitreMap.swift` | UptendCore | 2 | MitreTechnique, MitreMap |
| `Sources/UptendCore/PortService.swift` | UptendCore | 1 | PortService |
| `Sources/UptendCore/RemediationMap.swift` | UptendCore | 4 | RemediationEffort, Remediation, OSFamily, RemediationMap · Família de distribuição — decide o pacote/firewall/MAC certo (apt×dnf). |
| `Sources/UptendCore/RepoBrowser.swift` | UptendCore | 3 | FileNode, FileKind, RepoBrowser · Um nó (arquivo ou pasta) na árvore de um repositório sendo visualizado. |
| `Sources/UptendCore/ReportBranding.swift` | UptendCore | 1 | ReportBranding |
| `Sources/UptendCore/ReportSignature.swift` | UptendCore | 1 | ReportSignature |
| `Sources/UptendCore/RiskException.swift` | UptendCore | 2 | RiskException, RiskExceptions |
| `Sources/UptendCore/RiskRegister.swift` | UptendCore | 3 | RiskLevel, Risk, RiskRegister |
| `Sources/UptendCore/ScannerHelp.swift` | UptendCore | 2 | LynisFinding, ScannerHelp · Um item de recomendação do Lynis, com o ID do teste preservado para explicar |
| `Tests/UptendTests/AppCheckTests.swift` | teste | 6 |  |
| `Tests/UptendTests/AppsTests.swift` | teste | 2 |  |
| `Tests/UptendTests/AttackSurfaceTests.swift` | teste | 5 |  |
| `Tests/UptendTests/AuditCompareTests.swift` | teste | 4 |  |
| `Tests/UptendTests/AuditDashboardTests.swift` | teste | 4 |  |
| `Tests/UptendTests/AuditDatasetTests.swift` | teste | 4 |  |
| `Tests/UptendTests/AuditDomainsTests.swift` | teste | 3 |  |
| `Tests/UptendTests/AuditReportTests.swift` | teste | 15 |  |
| `Tests/UptendTests/AuditSignerTests.swift` | teste | 8 |  |
| `Tests/UptendTests/BaselineTests.swift` | teste | 10 |  |
| `Tests/UptendTests/BrandingTests.swift` | teste | 4 |  |
| `Tests/UptendTests/BrewInfoTests.swift` | teste | 10 |  |
| `Tests/UptendTests/BrewTidyTests.swift` | teste | 3 |  |
| `Tests/UptendTests/CVETests.swift` | teste | 11 |  |
| `Tests/UptendTests/ClamAVTests.swift` | teste | 5 |  |
| `Tests/UptendTests/CommandRunnerTests.swift` | teste | 3 |  |
| `Tests/UptendTests/ComplianceCatalogTests.swift` | teste | 8 |  |
| `Tests/UptendTests/ComplianceMapTests.swift` | teste | 8 |  |
| `Tests/UptendTests/CryptoToolsTests.swift` | teste | 4 |  |
| `Tests/UptendTests/DatabaseAuditTests.swift` | teste | 9 |  |
| `Tests/UptendTests/DetectionRulesTests.swift` | teste | 5 |  |
| `Tests/UptendTests/DockerTests.swift` | teste | 5 |  |
| `Tests/UptendTests/DriftAnalysisTests.swift` | teste | 4 |  |
| `Tests/UptendTests/EnergyTests.swift` | teste | 4 |  |
| `Tests/UptendTests/EvidenceTests.swift` | teste | 5 |  |
| `Tests/UptendTests/ExternalAuditServiceTests.swift` | teste | 15 |  |
| `Tests/UptendTests/ExternalAuditTests.swift` | teste | 7 |  |
| `Tests/UptendTests/FleetRollupTests.swift` | teste | 6 |  |
| `Tests/UptendTests/GitHubTests.swift` | teste | 9 |  |
| `Tests/UptendTests/GitTests.swift` | teste | 9 |  |
| `Tests/UptendTests/HardeningPlaybookTests.swift` | teste | 7 |  |
| `Tests/UptendTests/HomeLabFoundationTests.swift` | teste | 10 |  |
| `Tests/UptendTests/KeychainTests.swift` | teste | 1 |  |
| `Tests/UptendTests/LGPDAndCompleteTests.swift` | teste | 4 |  |
| `Tests/UptendTests/LogicTests.swift` | teste | 9 |  |
| `Tests/UptendTests/MaintenanceTests.swift` | teste | 4 |  |
| `Tests/UptendTests/MetabaseAPITests.swift` | teste | 3 |  |
| `Tests/UptendTests/MyPackagesTests.swift` | teste | 11 |  |
| `Tests/UptendTests/NetworkTests.swift` | teste | 6 |  |
| `Tests/UptendTests/RemediationMitreTests.swift` | teste | 4 |  |
| `Tests/UptendTests/RemoteBackupTests.swift` | teste | 4 |  |
| `Tests/UptendTests/RemoteDeployTests.swift` | teste | 4 |  |
| `Tests/UptendTests/RemoteDisksTests.swift` | teste | 3 |  |
| `Tests/UptendTests/RemoteDockerTests.swift` | teste | 4 |  |
| `Tests/UptendTests/RemoteFilesTests.swift` | teste | 4 |  |
| `Tests/UptendTests/RemoteHostTests.swift` | teste | 3 |  |
| `Tests/UptendTests/RemoteNetworkTests.swift` | teste | 3 |  |
| `Tests/UptendTests/RemoteSecurityTests.swift` | teste | 4 |  |
| `Tests/UptendTests/RemoteServerTests.swift` | teste | 5 |  |
| `Tests/UptendTests/RemoteTerminalTests.swift` | teste | 3 |  |
| `Tests/UptendTests/RepoBrowserTests.swift` | teste | 15 |  |
| `Tests/UptendTests/ReportTests.swift` | teste | 16 |  |
| `Tests/UptendTests/RiskExceptionTests.swift` | teste | 8 |  |
| `Tests/UptendTests/RiskRegisterTests.swift` | teste | 5 |  |
| `Tests/UptendTests/ScannerHelpTests.swift` | teste | 3 |  |
| `Tests/UptendTests/SecurityMonitorTests.swift` | teste | 5 |  |
| `Tests/UptendTests/SecurityScannersTests.swift` | teste | 8 |  |
| `Tests/UptendTests/SecurityTests.swift` | teste | 15 |  |
| `Tests/UptendTests/SecurityToolsTests.swift` | teste | 8 |  |
| `Tests/UptendTests/ServerSetupTests.swift` | teste | 2 |  |
| `Tests/UptendTests/ServiceTemplatesTests.swift` | teste | 9 |  |
| `Tests/UptendTests/ServicesTests.swift` | teste | 2 |  |
| `Tests/UptendTests/SetupTests.swift` | teste | 4 |  |
| `Tests/UptendTests/SmokeTests.swift` | teste | 12 |  |
| `Tests/UptendTests/StorageTests.swift` | teste | 3 |  |
| `Tests/UptendTests/TLSScannerFindingsTests.swift` | teste | 2 |  |
| `Tests/UptendTests/ToolsTests.swift` | teste | 6 |  |
| `Tests/UptendTests/UptendVaultTests.swift` | teste | 9 |  |
| `Tests/UptendTests/XcodeTests.swift` | teste | 5 |  |
| `make-icon.swift` | Uptend | 0 |  |

## Scripts de shell

| Arquivo | Primeira linha de comentário |
|---|---|
| `Sources/Uptend/Resources/audit-collector.sh` | ============================================================================= |
| `build-app.sh` | # Compila o Uptend e monta um Uptend.app para rodar localmente. |
| `make-dmg.sh` | # Empacota o Uptend.app num DMG (arrastar para Aplicativos). |
| `test.sh` | # Roda a suíte de testes automatizados usando o toolchain do Xcode |
