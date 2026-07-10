import Foundation
import CoreLocation

/// Pede autorização de Localização — exigida pelo macOS apenas para ler o nome (SSID)
/// da rede Wi-Fi. O Uptend não coleta nem usa localização para mais nada.
@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var status: CLAuthorizationStatus
    var onChange: (() -> Void)?

    private let manager = CLLocationManager()

    override init() {
        status = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    var authorized: Bool {
        status == .authorizedAlways || status == .authorized
    }

    func request() {
        manager.requestWhenInUseAuthorization()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let newStatus = manager.authorizationStatus
        Task { @MainActor in
            self.status = newStatus
            self.onChange?()
        }
    }
}
