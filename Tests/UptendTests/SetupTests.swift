import Testing
import Foundation
@testable import Uptend

/// Testes da Etapa 5: agendamento (lógica de vencimento) e dotfiles (allowlist/segurança).
struct SetupTests {

    @Test func scheduleIsDue() {
        let now = Date(timeIntervalSince1970: 1_000_000_000)
        let fiveDaysAgo = now.addingTimeInterval(-5 * 86400)
        let tenDaysAgo = now.addingTimeInterval(-10 * 86400)

        #expect(ScheduleService.isDue(last: nil, intervalDays: 7, now: now))          // nunca executado
        #expect(!ScheduleService.isDue(last: fiveDaysAgo, intervalDays: 7, now: now)) // ainda em dia
        #expect(ScheduleService.isDue(last: tenDaysAgo, intervalDays: 7, now: now))   // vencido
    }

    @Test func scheduleStatusText() {
        let now = Date(timeIntervalSince1970: 1_000_000_000)
        #expect(ScheduleService.statusText(last: nil, intervalDays: 7, now: now) == "Nunca executado")

        let twoDaysAgo = now.addingTimeInterval(-2 * 86400)
        #expect(ScheduleService.statusText(last: twoDaysAgo, intervalDays: 7, now: now).contains("faltam 5"))

        let nineDaysAgo = now.addingTimeInterval(-9 * 86400)
        #expect(ScheduleService.statusText(last: nineDaysAgo, intervalDays: 7, now: now).contains("Vencido"))
    }

    @MainActor @Test func dotfilesAllowlistIsSafe() {
        // Todos os dotfiles suportados são nomes simples, sem separador de caminho nem "..".
        for name in DotfilesService.known {
            #expect(name.hasPrefix("."))
            #expect(!name.contains("/"))
            #expect(!name.contains(".."))
        }
    }

    @MainActor @Test func profilePathIsInsideProfilesDir() {
        let url = ProfilesService.url(forName: "meu-setup")
        #expect(url.pathExtension == "brewfile")
        #expect(url.path.contains("Uptend/Profiles"))
    }
}
