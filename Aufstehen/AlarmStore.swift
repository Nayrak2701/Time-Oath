import SwiftUI
import Combine

/// Central state + persistence. No accounts, no network, no backend.
///
/// The whole point of the app is to force punctual waking. So once an alarm
/// fires, the app enters a **locked** wake cycle: the alarm list and all settings
/// are unreachable, and the only way out is scanning the QR code (or the
/// emergency code). Leaving/relaunching/force-quitting keeps the lock — the
/// state is persisted.
@MainActor
final class AlarmStore: ObservableObject {

    static let shared = AlarmStore()

    static let defaultQRValue = "AUFSTEHEN-BAD-7K2F9Q"
    let ringWindow: TimeInterval = 180
    let keepAliveWindow: TimeInterval = 16 * 3600

    // MARK: - Persisted settings

    @Published var alarms: [Alarm] { didSet { persistAlarms(); if !wakeActive { reschedule() } } }
    @Published var qrCodeValue: String { didSet { defaults.set(qrCodeValue, forKey: K.qr) } }
    @Published var alarmVolume: Double { didSet { defaults.set(alarmVolume, forKey: K.volume) } }
    @Published var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: K.language); currentAppLanguage = language }
    }

    /// "+9 Minuten" (rest-again) duration, in minutes. Configurable.
    @Published var snoozeMinutes: Int { didSet { defaults.set(snoozeMinutes, forKey: K.snoozeMin) } }
    /// "Jetzt Aufstehen" countdown to reach the QR, in seconds. Configurable.
    @Published var getUpSeconds: Int { didSet { defaults.set(getUpSeconds, forKey: K.getUpSec) } }
    /// How many times "+9" may be used per wake cycle before only "Get up" remains.
    @Published var maxSnoozes: Int { didSet { defaults.set(maxSnoozes, forKey: K.maxSnooze) } }

    // MARK: - Live wake state (locked cycle)

    @Published var wakeActive = false          // an alarm cycle is in progress → app locked
    @Published var wakePhase: WakePhase = .ringing
    /// Deadline for the current .snoozed or .countdown phase.
    @Published var wakeUntil: Date?
    @Published var emergencyCode = ""

    private(set) var snoozeCount = 0
    private var wakeFireDate: Date?
    private(set) var currentFireDate: Date?

    // MARK: - Dependencies

    private let defaults = UserDefaults.standard
    private let engine = AlarmEngine()
    private let haptics = HapticsManager()
    private var tick: Timer?

    private enum K {
        static let alarms = "alarms.v2"
        static let qr = "alarm.qrValue"
        static let volume = "alarm.volume"
        static let language = "app.language"
        static let snoozeMin = "cfg.snoozeMinutes"
        static let getUpSec = "cfg.getUpSeconds"
        static let maxSnooze = "cfg.maxSnoozes"
        static let stopped = "alarm.stoppedCycle"
        // Locked-wake persistence.
        static let wActive = "wake.active"
        static let wPhase = "wake.phase"
        static let wUntil = "wake.until"
        static let wCount = "wake.snoozeCount"
        static let wFire = "wake.fireDate"
    }

    // MARK: - Init

    private init() {
        if let data = defaults.data(forKey: K.alarms),
           let saved = try? JSONDecoder().decode([Alarm].self, from: data) {
            alarms = saved
        } else {
            alarms = [Alarm(hour: 7, minute: 0, label: "", isEnabled: false)]
        }
        let storedQR = defaults.string(forKey: K.qr)
        qrCodeValue = (storedQR?.isEmpty == false) ? storedQR! : Self.defaultQRValue
        alarmVolume = defaults.object(forKey: K.volume) != nil ? defaults.double(forKey: K.volume) : 1.0
        language = AppLanguage(rawValue: defaults.string(forKey: K.language) ?? "") ?? .english
        snoozeMinutes = defaults.object(forKey: K.snoozeMin) != nil ? defaults.integer(forKey: K.snoozeMin) : 9
        getUpSeconds = defaults.object(forKey: K.getUpSec) != nil ? defaults.integer(forKey: K.getUpSec) : 60
        maxSnoozes = defaults.object(forKey: K.maxSnooze) != nil ? defaults.integer(forKey: K.maxSnooze) : 1

        currentAppLanguage = language
        restoreWakeState()
        reschedule()
    }

    // MARK: - Alarm CRUD (blocked while locked)

    func addAlarm(_ a: Alarm) { guard !wakeActive else { return }; alarms.append(a) }
    func updateAlarm(_ a: Alarm) {
        guard !wakeActive else { return }
        if let i = alarms.firstIndex(where: { $0.id == a.id }) { alarms[i] = a }
    }
    func deleteAlarm(_ a: Alarm) { guard !wakeActive else { return }; alarms.removeAll { $0.id == a.id } }
    func deleteAlarms(at offsets: IndexSet, in sorted: [Alarm]) {
        guard !wakeActive else { return }
        let ids = offsets.map { sorted[$0].id }
        alarms.removeAll { ids.contains($0.id) }
    }
    func setEnabled(_ on: Bool, for a: Alarm) {
        guard !wakeActive else { return }
        if let i = alarms.firstIndex(where: { $0.id == a.id }) { alarms[i].isEnabled = on }
    }

    var sortedAlarms: [Alarm] { alarms.sorted { $0.sortKey < $1.sortKey } }
    var hasEnabledAlarm: Bool { alarms.contains { $0.isEnabled } }
    var canSnooze: Bool { snoozeCount < maxSnoozes }

    private func persistAlarms() {
        if let d = try? JSONEncoder().encode(alarms) { defaults.set(d, forKey: K.alarms) }
    }

    // MARK: - Scheduling

    private func nextAlarmFire() -> Date? {
        alarms.filter(\.isEnabled).map { $0.nextOccurrence() }.min()
    }

    func reschedule() {
        NotificationManager.cancelAll()
        currentFireDate = nextAlarmFire()

        var fireDates: [Date] = alarms.filter(\.isEnabled).map { $0.nextOccurrence() }
        if wakeActive {
            // Keep nagging via notifications for the live cycle too.
            switch wakePhase {
            case .ringing: fireDates.append(Date().addingTimeInterval(1))
            case .snoozed: if let u = wakeUntil { fireDates.append(u) }
            case .countdown: if let u = wakeUntil { fireDates.append(u) }
            }
        }
        NotificationManager.schedule(fireDates: fireDates, window: ringWindow,
                                     soundName: AlarmEngine.notificationSoundName)

        if hasEnabledAlarm || wakeActive { startTick() } else { stopTick(); if !wakeActive { engine.stopKeepAlive() } }
    }

    // MARK: - Foreground / background keep-alive

    func handleBackground() {
        if wakeActive { engine.startKeepAlive(); return }   // stay alive to keep ringing
        guard let fire = currentFireDate else { return }
        if fire.timeIntervalSinceNow <= keepAliveWindow { engine.startKeepAlive() }
    }
    func handleForeground() {
        if !wakeActive && wakePhaseSoundOff { engine.stopKeepAlive() }
    }
    private var wakePhaseSoundOff: Bool { !wakeActive }

    // MARK: - Tick

    private func startTick() {
        guard tick == nil else { return }
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.onTick() }
        }
        RunLoop.main.add(t, forMode: .common)
        tick = t
    }
    private func stopTick() { tick?.invalidate(); tick = nil }

    private func onTick() {
        if wakeActive {
            guard let until = wakeUntil else { return }
            if (wakePhase == .snoozed || wakePhase == .countdown), Date() >= until {
                enterRinging()   // snooze elapsed, or ran out of time to scan
            }
            objectWillChange.send()   // refresh countdown labels
        } else {
            checkForActiveAlarm()
        }
    }

    // MARK: - Entering the locked wake cycle

    func checkForActiveAlarm() {
        guard !wakeActive, let fire = currentFireDate else { return }
        let now = Date()
        let handled = defaults.double(forKey: K.stopped) == fire.timeIntervalSince1970
        if now >= fire, now < fire.addingTimeInterval(ringWindow), !handled {
            startWake(fire: fire)
        } else if now >= fire.addingTimeInterval(ringWindow) {
            reschedule()
        }
    }

    private func startWake(fire: Date) {
        wakeActive = true
        wakeFireDate = fire
        snoozeCount = 0
        emergencyCode = Self.makeEmergencyCode()
        enterRinging()
        persistWake()
    }

    private func enterRinging() {
        wakePhase = .ringing
        wakeUntil = nil
        engine.startAlarm(volume: Float(alarmVolume))
        haptics.start()
        persistWake()
        reschedule()
    }

    /// "+9 Minuten" — rest again. Only while snoozes remain.
    func pressSnooze() {
        guard wakeActive, wakePhase == .ringing, canSnooze else { return }
        snoozeCount += 1
        haptics.stop()
        engine.stopAlarm(keepAlive: true)
        wakePhase = .snoozed
        wakeUntil = Date().addingTimeInterval(TimeInterval(snoozeMinutes * 60))
        persistWake()
        reschedule()
    }

    /// "Jetzt Aufstehen" — start the countdown to reach and scan the QR.
    func pressGetUp() {
        guard wakeActive, wakePhase == .ringing else { return }
        haptics.stop()
        engine.stopAlarm(keepAlive: true)
        wakePhase = .countdown
        wakeUntil = Date().addingTimeInterval(TimeInterval(getUpSeconds))
        persistWake()
        reschedule()
    }

    /// Correct QR scan or emergency code — the only way to unlock.
    func stopAlarm() {
        haptics.stop()
        engine.stopAlarm(keepAlive: hasEnabledAlarm)
        if let fire = wakeFireDate { defaults.set(fire.timeIntervalSince1970, forKey: K.stopped) }
        wakeActive = false
        wakePhase = .ringing
        wakeUntil = nil
        snoozeCount = 0
        clearWakePersistence()
        reschedule()
    }

    func regenerateEmergencyCode() { emergencyCode = Self.makeEmergencyCode() }

    /// QR editing is only allowed when unlocked.
    func regenerateQRValue() {
        guard !wakeActive else { return }
        let suffix = String((0..<6).map { _ in "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".randomElement()! })
        qrCodeValue = "TIMEOATH-\(suffix)"
    }
    func setQRValue(_ v: String) { guard !wakeActive else { return }; qrCodeValue = v }

    private static func makeEmergencyCode() -> String {
        String((0..<10).map { _ in "0123456789".randomElement()! })
    }

    // MARK: - Wake persistence (survives relaunch / force-quit)

    private func persistWake() {
        defaults.set(wakeActive, forKey: K.wActive)
        defaults.set(wakePhase.rawValue, forKey: K.wPhase)
        defaults.set(wakeUntil?.timeIntervalSince1970 ?? 0, forKey: K.wUntil)
        defaults.set(snoozeCount, forKey: K.wCount)
        defaults.set(wakeFireDate?.timeIntervalSince1970 ?? 0, forKey: K.wFire)
    }
    private func clearWakePersistence() {
        [K.wActive, K.wPhase, K.wUntil, K.wCount, K.wFire].forEach { defaults.removeObject(forKey: $0) }
    }
    private func restoreWakeState() {
        guard defaults.bool(forKey: K.wActive) else { return }
        wakeActive = true
        wakePhase = WakePhase(rawValue: defaults.string(forKey: K.wPhase) ?? "") ?? .ringing
        let u = defaults.double(forKey: K.wUntil); wakeUntil = u > 0 ? Date(timeIntervalSince1970: u) : nil
        snoozeCount = defaults.integer(forKey: K.wCount)
        let f = defaults.double(forKey: K.wFire); wakeFireDate = f > 0 ? Date(timeIntervalSince1970: f) : nil
        emergencyCode = Self.makeEmergencyCode()
    }

    /// Called on foreground: resume sound / advance phase after a relaunch.
    func resumeWakeIfNeeded() {
        guard wakeActive else { return }
        let now = Date()
        switch wakePhase {
        case .ringing:
            engine.startAlarm(volume: Float(alarmVolume)); haptics.start()
        case .snoozed, .countdown:
            if let u = wakeUntil, now >= u { enterRinging() }
        }
    }

    // MARK: - Display helpers

    /// Seconds remaining in the current snooze/countdown phase.
    var wakeRemaining: Int {
        guard let u = wakeUntil else { return 0 }
        return max(0, Int(u.timeIntervalSinceNow.rounded()))
    }

    var nextAlarmText: String? {
        guard let fire = nextAlarmFire() else { return nil }
        let secs = fire.timeIntervalSinceNow
        if secs < 3600 {
            let mins = max(1, Int(secs / 60))
            return S.t("Alarm in \(mins) min", "Wecker in \(mins) Min.")
        }
        let f = DateFormatter()
        f.locale = Locale(identifier: S.isGerman ? "de_DE" : "en_US")
        f.dateFormat = S.isGerman ? "EEEE HH:mm" : "EEEE h:mm a"
        return S.t("Next alarm: ", "Nächster Wecker: ") + f.string(from: fire)
    }
}
