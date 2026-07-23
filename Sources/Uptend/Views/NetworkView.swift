import SwiftUI
import Charts

struct NetworkView: View {
    let sub: SubSection?
    @EnvironmentObject var monitor: MonitorService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch sub?.id {
                case "wifi": WiFiCard()
                case "quality": QualityCard()
                case "addresses": AddressesCard()
                case "connections": ConnectionsCard()
                case "ports": PortsToolView()
                case "speedtest": SpeedTestCard()
                case "ping": PingCard()
                case "dns": DNSCard()
                default: overviewContent
                }
            }
            .screenPadding()
            .frame(maxWidth: 860, alignment: .leading)
        }
    }

    // MARK: Visão geral

    private var overviewContent: some View {
        Group {
            ScreenHeader(title: "Visão geral", subtitle: "Tráfego de rede em tempo real")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
                statCard("Baixando agora", MonitorService.formatRate(monitor.downRate), "arrow.down.circle", .blue)
                statCard("Enviando agora", MonitorService.formatRate(monitor.upRate), "arrow.up.circle", .green)
                statCard("Baixado na sessão", FileUtils.label(Int64(monitor.sessionDown)), "tray.and.arrow.down", .blue)
                statCard("Enviado na sessão", FileUtils.label(Int64(monitor.sessionUp)), "tray.and.arrow.up", .green)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 14) {
                    legend(.blue, "Baixando")
                    legend(.green, "Enviando")
                }
                Chart {
                    ForEach(Array(monitor.downHistory.enumerated()), id: \.offset) { index, value in
                        AreaMark(x: .value("t", index), y: .value("bytes/s", value))
                            .foregroundStyle(.blue.opacity(0.2))
                    }
                    ForEach(Array(monitor.downHistory.enumerated()), id: \.offset) { index, value in
                        LineMark(x: .value("t", index), y: .value("Download", value), series: .value("s", "d"))
                            .foregroundStyle(.blue)
                    }
                    ForEach(Array(monitor.upHistory.enumerated()), id: \.offset) { index, value in
                        LineMark(x: .value("t", index), y: .value("Upload", value), series: .value("s", "u"))
                            .foregroundStyle(.green)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks { mark in
                        AxisValueLabel {
                            if let value = mark.as(Double.self) { Text(MonitorService.formatRate(value)).font(.caption2) }
                        }
                    }
                }
                .frame(height: 180)
                .padding(12)
                .cardBackground()
            }

            Text("Interfaces").font(.headline).padding(.top, 4)
            ForEach(NetworkTools.localIPv4(), id: \.ip) { item in
                CardRow {
                    HStack(spacing: 10) {
                        Image(systemName: "wifi").foregroundStyle(.secondary)
                        Text(item.interface).foregroundStyle(.secondary)
                        Text(item.ip).fontWeight(.medium)
                    }
                } trailing: {
                    IconButton(systemImage: "doc.on.doc", help: "Copiar") { Clipboard.copy(item.ip) }
                }
            }
        }
    }

    private func statCard(_ title: String, _ value: String, _ icon: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(value).font(.system(size: 18, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7)
            Text(title).font(.callout).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }

    private func legend(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Wi-Fi

struct WiFiCard: View {
    @StateObject private var wifi = WiFiService()
    @StateObject private var location = LocationService()

    private var tint: Color {
        wifi.info.quality >= 67 ? .green : (wifi.info.quality >= 34 ? .orange : .red)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScreenHeader(title: "Wi-Fi", subtitle: wifi.info.available ? "Conectado" : "Sem Wi-Fi ativo") {
                IconButton(systemImage: "arrow.clockwise", help: "Atualizar") { wifi.refresh() }
            }

            if wifi.info.available {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(wifi.info.ssid).font(.headline)
                        Spacer()
                        if wifi.info.ssidLocked && !location.authorized {
                            Button("Mostrar nome") { location.request() }
                                .help("Permite a Localização (exigência do macOS) para exibir o nome da rede")
                        }
                    }
                    Gauge(value: Double(wifi.info.quality), in: 0...100) {
                        Text("Sinal")
                    } currentValueLabel: {
                        Text("\(wifi.info.quality)%")
                    }
                    .gaugeStyle(.accessoryLinearCapacity)
                    .tint(tint)
                    Text("\(wifi.info.rssi) dBm").font(.caption).foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardBackground()

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                    infoTile("Canal", wifi.info.channel, "antenna.radiowaves.left.and.right")
                    infoTile("Banda", wifi.info.band, "dot.radiowaves.left.and.right")
                    infoTile("Taxa", wifi.info.txRate, "speedometer")
                    infoTile("Segurança", wifi.info.security, "lock")
                }
            } else {
                ContentUnavailableView("Sem Wi-Fi ativo", systemImage: "wifi.slash").padding(.top, 40)
            }
        }
        .task {
            location.onChange = { wifi.refresh() }
            wifi.start()
        }
        .onDisappear { wifi.stop() }
    }

    private func infoTile(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).foregroundStyle(.secondary)
            Text(value).fontWeight(.medium).lineLimit(1).minimumScaleFactor(0.7)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }
}

// MARK: - Qualidade da conexão

struct QualityCard: View {
    @StateObject private var latency = LatencyMonitor()
    @State private var running = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScreenHeader(title: "Qualidade",
                         subtitle: running ? "Medindo latência para \(latency.host)…" : "Latência para \(latency.host)") {
                Button {
                    running.toggle()
                    if running { latency.start() } else { latency.stop() }
                } label: {
                    Label(running ? "Parar" : "Medir", systemImage: running ? "stop.fill" : "play.fill")
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                metric("Latência", latency.current > 0 ? String(format: "%.0f ms", latency.current) : "—",
                       help: "Tempo de ida e volta até o servidor agora. Quanto menor, mais responsiva a conexão.")
                metric("Média", latency.average > 0 ? String(format: "%.0f ms", latency.average) : "—",
                       help: "Latência média durante a medição.")
                metric("Jitter", String(format: "%.0f ms", latency.jitter),
                       help: "Variação da latência. Jitter alto causa travadas em chamadas e jogos.")
                metric("Perda", String(format: "%.0f%%", latency.lossPercent),
                       help: "Porcentagem de pacotes que não voltaram. Acima de 0% indica instabilidade.")
            }

            Chart(Array(latency.history.enumerated()), id: \.offset) { index, value in
                LineMark(x: .value("t", index), y: .value("ms", value))
                    .foregroundStyle(.orange)
                    .interpolationMethod(.monotone)
            }
            .chartXAxis(.hidden)
            .frame(height: 160)
            .padding(12)
            .cardBackground()
        }
        .onDisappear { latency.stop(); running = false }
    }

    private func metric(_ title: String, _ value: String, help: String = "") -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value).font(.system(size: 18, weight: .medium).monospacedDigit())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
        .tip(help.isEmpty ? title : help)
    }
}

// MARK: - Endereços

struct AddressesCard: View {
    @State private var macs: [(interface: String, mac: String)] = []
    @State private var gateway = "—"
    @State private var dns: [String] = []
    @State private var ipInfo: NetworkTools.IPInfo?
    @State private var loadingIP = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScreenHeader(title: "Endereços", subtitle: "Local, roteador, DNS e público")

            row("Gateway (roteador)", gateway, "point.topleft.down.to.point.bottomright.curvepath")
            ForEach(NetworkTools.localIPv4(), id: \.ip) { item in
                row("IP local (\(item.interface))", item.ip, "wifi")
            }
            ForEach(macs, id: \.mac) { item in
                row("MAC (\(item.interface))", item.mac, "number")
            }
            if !dns.isEmpty {
                row("Servidores DNS", dns.joined(separator: ", "), "magnifyingglass")
            }

            CardRow {
                HStack(spacing: 10) {
                    Image(systemName: "globe").foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("IP público").fontWeight(.medium)
                        if let info = ipInfo {
                            Text("\(info.ip) · \(info.org)").font(.callout).foregroundStyle(.secondary)
                            Text("\(info.city), \(info.region) — \(info.country)").font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text("Consulta um serviço externo (internet)").font(.callout).foregroundStyle(.secondary)
                        }
                    }
                }
            } trailing: {
                if loadingIP {
                    ProgressView().controlSize(.small).frame(width: 24, height: 24)
                } else {
                    IconButton(systemImage: "magnifyingglass", help: "Descobrir IP público e provedor") {
                        Task { loadingIP = true; ipInfo = await NetworkTools.ipInfo(); loadingIP = false }
                    }
                }
            }
        }
        .task {
            macs = await NetworkTools.macAddresses().filter { $0.mac.contains(":") }
            gateway = await NetworkTools.gateway() ?? "—"
            dns = await NetworkTools.dnsServers()
        }
    }

    private func row(_ title: String, _ value: String, _ icon: String) -> some View {
        CardRow {
            HStack(spacing: 10) {
                Image(systemName: icon).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).fontWeight(.medium)
                    Text(value).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                        .lineLimit(1).truncationMode(.middle)
                }
            }
        } trailing: {
            IconButton(systemImage: "doc.on.doc", help: "Copiar") { Clipboard.copy(value) }
        }
    }
}

// MARK: - Conexões ativas

struct ConnectionsCard: View {
    @StateObject private var service = ConnectionsService()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScreenHeader(title: "Conexões ativas", subtitle: "\(service.connections.count) conexões estabelecidas") {
                if service.loading { ProgressView().controlSize(.small) }
                IconButton(systemImage: "arrow.clockwise", help: "Atualizar") { Task { await service.refresh() } }
            }

            if service.connections.isEmpty && !service.loading {
                ContentUnavailableView("Nenhuma conexão ativa", systemImage: "cable.connector.slash").padding(.top, 40)
            } else {
                VStack(spacing: 8) {
                    ForEach(service.connections) { connection in
                        CardRow {
                            HStack(spacing: 12) {
                                Image(systemName: "cable.connector").foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(connection.command).fontWeight(.medium)
                                    Text(connection.remote).font(.callout).foregroundStyle(.secondary)
                                        .lineLimit(1).truncationMode(.middle)
                                }
                            }
                        } trailing: {
                            Text("PID \(connection.pid)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .task { await service.refresh() }
    }
}

// MARK: - Teste de velocidade

struct SpeedTestCard: View {
    @State private var download: Double?
    @State private var upload: Double?
    @State private var running = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScreenHeader(title: "Teste de velocidade", subtitle: "Mede download e upload (usa banda)") {
                if running { ProgressView().controlSize(.small) }
                Button("Testar", action: run).disabled(running)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
                result("Baixar", download, "arrow.down.circle", .blue)
                result("Enviar", upload, "arrow.up.circle", .green)
            }

            Text("O teste baixa e envia dados via Cloudflare — contato com a internet e consumo de banda.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func result(_ title: String, _ value: Double?, _ icon: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(value.map { SpeedTest.format($0) } ?? "—").font(.system(size: 22, weight: .medium))
            Text(title).font(.callout).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }

    private func run() {
        running = true
        download = nil
        upload = nil
        Task {
            download = await SpeedTest.download()
            upload = await SpeedTest.upload()
            running = false
        }
    }
}

// MARK: - Ping

struct PingCard: View {
    @State private var host = ""
    @State private var output = ""
    @State private var running = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScreenHeader(title: "Ping", subtitle: "Testa a conexão com um host")
            HStack {
                TextField("host ou IP (ex.: apple.com)", text: $host)
                    .textFieldStyle(.plain).padding(10).cardBackground()
                    .onSubmit(run)
                Button("Ping", action: run).disabled(host.isEmpty)
                if running { ProgressView().controlSize(.small) }
            }
            if !output.isEmpty {
                Text(output)
                    .font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(10).cardBackground()
            }
        }
    }

    private func run() {
        running = true
        output = "Executando…"
        Task { output = await NetworkTools.ping(host); running = false }
    }
}

// MARK: - DNS

struct DNSCard: View {
    @State private var host = ""
    @State private var output = ""
    @State private var running = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScreenHeader(title: "DNS", subtitle: "Resolve um host para endereços IP")
            HStack {
                TextField("host (ex.: github.com)", text: $host)
                    .textFieldStyle(.plain).padding(10).cardBackground()
                    .onSubmit(run)
                Button("Resolver", action: run).disabled(host.isEmpty)
                if running { ProgressView().controlSize(.small) }
            }
            if !output.isEmpty {
                Text(output)
                    .font(.system(.body, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(10).cardBackground()
            }
        }
    }

    private func run() {
        running = true
        output = "Resolvendo…"
        Task { output = await NetworkTools.dnsLookup(host); running = false }
    }
}
