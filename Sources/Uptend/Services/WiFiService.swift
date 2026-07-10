import Foundation
import CoreWLAN

struct WiFiInfo {
    var available = false
    var ssid = "—"
    var ssidLocked = false  // SSID indisponível sem permissão de Localização
    var rssi = 0            // dBm (negativo)
    var quality = 0         // 0...100
    var channel = "—"
    var band = "—"
    var txRate = "—"
    var security = "—"
}

/// Lê informações do Wi-Fi via CoreWLAN (local, sem rede). SSID exige permissão de
/// Localização no macOS recente; o resto (sinal, canal, taxa) funciona sem isso.
@MainActor
final class WiFiService: ObservableObject {
    @Published var info = WiFiInfo()
    private var timer: Timer?

    func start() {
        guard timer == nil else { return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        guard let interface = CWWiFiClient.shared().interface() else {
            info = WiFiInfo(available: false)
            return
        }

        var result = WiFiInfo(available: true)
        if let ssid = interface.ssid() {
            result.ssid = ssid
        } else {
            result.ssid = "Rede protegida"
            result.ssidLocked = true
        }
        result.rssi = interface.rssiValue()
        result.quality = Self.quality(fromRSSI: result.rssi)

        if let channel = interface.wlanChannel() {
            result.channel = "\(channel.channelNumber)"
            result.band = Self.bandLabel(channel.channelBand)
        }

        let rate = interface.transmitRate()
        result.txRate = rate > 0 ? "\(Int(rate)) Mbps" : "—"
        result.security = Self.securityLabel(interface.security())

        info = result
    }

    nonisolated static func quality(fromRSSI rssi: Int) -> Int {
        // -50 dBm (ótimo) -> 100%, -100 dBm (péssimo) -> 0%.
        if rssi == 0 { return 0 }
        return max(0, min(100, 2 * (rssi + 100)))
    }

    nonisolated static func bandLabel(_ band: CWChannelBand) -> String {
        switch band {
        case .band2GHz: "2.4 GHz"
        case .band5GHz: "5 GHz"
        case .band6GHz: "6 GHz"
        default: "—"
        }
    }

    nonisolated static func securityLabel(_ security: CWSecurity) -> String {
        switch security {
        case .none: "Aberta"
        case .WEP: "WEP"
        case .wpaPersonal, .wpaPersonalMixed: "WPA"
        case .wpa2Personal: "WPA2"
        case .wpa3Personal, .wpa3Transition: "WPA3"
        case .personal: "Pessoal"
        case .enterprise, .wpaEnterprise, .wpaEnterpriseMixed, .wpa2Enterprise, .wpa3Enterprise: "Enterprise"
        default: "—"
        }
    }
}
