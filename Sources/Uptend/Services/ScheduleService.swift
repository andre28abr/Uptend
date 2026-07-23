import Foundation

/// Lembretes de manutenção recorrente (limpeza e atualizações). Guarda o intervalo
/// (em dias) e a última execução, e calcula quando está vencido. O app precisa estar
/// aberto para lembrar (não há agendamento em segundo plano nesta versão).
@MainActor
final class ScheduleService: ObservableObject {
    @Published var cleanupIntervalDays: Int {
        didSet { UserDefaults.standard.set(cleanupIntervalDays, forKey: "uptend.sched.cleanupInterval") }
    }
    @Published var updateIntervalDays: Int {
        didSet { UserDefaults.standard.set(updateIntervalDays, forKey: "uptend.sched.updateInterval") }
    }
    @Published var lastCleanup: Date? {
        didSet { UserDefaults.standard.set(lastCleanup, forKey: "uptend.sched.lastCleanup") }
    }
    @Published var lastUpdate: Date? {
        didSet { UserDefaults.standard.set(lastUpdate, forKey: "uptend.sched.lastUpdate") }
    }
    @Published var backgroundReminders: Bool {
        didSet { UserDefaults.standard.set(backgroundReminders, forKey: "uptend.sched.background") }
    }

    init() {
        let defaults = UserDefaults.standard
        cleanupIntervalDays = defaults.object(forKey: "uptend.sched.cleanupInterval") as? Int ?? 14
        updateIntervalDays = defaults.object(forKey: "uptend.sched.updateInterval") as? Int ?? 7
        lastCleanup = defaults.object(forKey: "uptend.sched.lastCleanup") as? Date
        lastUpdate = defaults.object(forKey: "uptend.sched.lastUpdate") as? Date
        backgroundReminders = defaults.bool(forKey: "uptend.sched.background")
    }

    // MARK: - Lembretes em segundo plano (launchd)

    private var agentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.andresouza.uptend.reminder.plist")
    }

    func setBackgroundReminders(_ on: Bool) async {
        backgroundReminders = on
        if on { await installAgent() } else { await removeAgent() }
    }

    private func installAgent() async {
        let interval = max(1, min(updateIntervalDays, cleanupIntervalDays)) * 86400
        let dir = agentURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key><string>com.andresouza.uptend.reminder</string>
            <key>ProgramArguments</key>
            <array>
                <string>/usr/bin/osascript</string>
                <string>-e</string>
                <string>display notification "É hora de manter seu Mac. Abra o Uptend." with title "Uptend"</string>
            </array>
            <key>StartInterval</key><integer>\(interval)</integer>
        </dict>
        </plist>
        """
        try? plist.write(to: agentURL, atomically: true, encoding: .utf8)
        _ = await Shell.capture("/bin/launchctl", ["unload", agentURL.path])
        _ = await Shell.capture("/bin/launchctl", ["load", "-w", agentURL.path])
    }

    private func removeAgent() async {
        _ = await Shell.capture("/bin/launchctl", ["unload", "-w", agentURL.path])
        try? FileManager.default.removeItem(at: agentURL)
    }

    func markCleanupDone() { lastCleanup = Date() }
    func markUpdateDone() { lastUpdate = Date() }

    var cleanupDue: Bool { Self.isDue(last: lastCleanup, intervalDays: cleanupIntervalDays, now: Date()) }
    var updateDue: Bool { Self.isDue(last: lastUpdate, intervalDays: updateIntervalDays, now: Date()) }

    func cleanupStatus() -> String { Self.statusText(last: lastCleanup, intervalDays: cleanupIntervalDays, now: Date()) }
    func updateStatus() -> String { Self.statusText(last: lastUpdate, intervalDays: updateIntervalDays, now: Date()) }

    // MARK: - Lógica pura (testável)

    nonisolated static func daysBetween(_ from: Date, _ to: Date) -> Int {
        Int(to.timeIntervalSince(from) / 86400)
    }

    nonisolated static func isDue(last: Date?, intervalDays: Int, now: Date) -> Bool {
        guard let last else { return true }             // nunca executado
        return daysBetween(last, now) >= intervalDays
    }

    nonisolated static func statusText(last: Date?, intervalDays: Int, now: Date) -> String {
        guard let last else { return "Nunca executado" }
        let elapsed = daysBetween(last, now)
        let remaining = intervalDays - elapsed
        if remaining <= 0 { return "Vencido há \(-remaining) dia(s)" }
        return "Em dia · faltam \(remaining) dia(s)"
    }
}
