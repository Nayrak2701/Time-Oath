import SwiftUI

/// Full-screen locked wake cycle. The app cannot be used for anything else while
/// this is up — no alarm list, no settings. Only scanning the QR (or the
/// emergency code) ends it.
struct RingingView: View {
    @EnvironmentObject var store: AlarmStore

    @State private var now = Date()
    @State private var showOverride = false
    @State private var scanError: String?
    @State private var lastScan = ""

    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.oathBlack.ignoresSafeArea()
            switch store.wakePhase {
            case .ringing:   ringing
            case .snoozed:   snoozed
            case .countdown: countdown
            }
        }
        .onReceive(clock) { now = $0 }
        .sheet(isPresented: $showOverride) {
            EmergencyOverrideView().environmentObject(store)
        }
    }

    // MARK: - Ringing (two buttons)

    private var ringing: some View {
        VStack {
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: "alarm.fill").font(.system(size: 34)).foregroundColor(.oathAccent)
                Text("Time Oath").font(.title3.weight(.semibold)).foregroundColor(.oathWhite.opacity(0.9))
                Text(timeString).font(.system(size: 82, weight: .thin, design: .rounded))
                    .monospacedDigit().foregroundColor(.oathWhite)
            }
            Spacer()

            HStack(spacing: 14) {
                if store.canSnooze {
                    Button { store.pressSnooze() } label: {
                        actionLabel(S.t("Rest again", "Nochmal hinlegen"),
                                    sub: S.t("\(store.snoozeMinutes) min", "\(store.snoozeMinutes) Min"),
                                    system: "zzz", filled: false)
                    }
                }
                Button { store.pressGetUp() } label: {
                    actionLabel(S.t("Get up now", "Jetzt Aufstehen"),
                                sub: S.t("scan the code", "Code scannen"),
                                system: "figure.walk", filled: true)
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 40)
        }
    }

    private func actionLabel(_ title: String, sub: String, system: String, filled: Bool) -> some View {
        VStack(spacing: 6) {
            Image(systemName: system).font(.system(size: 24))
            Text(title).font(.headline)
            Text(sub).font(.caption).opacity(0.8)
        }
        .foregroundColor(filled ? .oathBlack : .oathWhite)
        .frame(maxWidth: .infinity)
        .frame(height: 104)
        .background(filled ? Color.oathAccent : Color.oathWhite.opacity(0.14),
                    in: RoundedRectangle(cornerRadius: 22))
    }

    // MARK: - Snoozed (locked, waiting to ring again)

    private var snoozed: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "zzz").font(.system(size: 40)).foregroundColor(.oathAccent)
            Text(S.t("Ringing again in", "Klingelt wieder in"))
                .font(.title3).foregroundColor(.oathWhite.opacity(0.8))
            Text(remainingString).font(.system(size: 72, weight: .semibold, design: .rounded))
                .monospacedDigit().foregroundColor(.oathWhite)
            Text(S.t("Locked. Only scanning the QR code stops the alarm.",
                     "Gesperrt. Nur der QR-Scan stoppt den Wecker."))
                .font(.footnote).foregroundColor(.oathWhite.opacity(0.5))
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Spacer()
            Button(S.t("Code missing?", "Code fehlt?")) { showOverride = true }
                .font(.footnote).foregroundColor(.oathWhite.opacity(0.5)).padding(.bottom, 30)
        }
    }

    // MARK: - Countdown (camera + timer)

    private var countdown: some View {
        ZStack {
            CameraPreview { handleScan($0) }.ignoresSafeArea()
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.oathWhite.opacity(0.9), lineWidth: 3)
                .frame(width: 240, height: 240)

            VStack {
                VStack(spacing: 4) {
                    Text(remainingString)
                        .font(.system(size: 54, weight: .bold, design: .rounded)).monospacedDigit()
                        .foregroundColor(store.wakeRemaining <= 10 ? .oathAccent : .oathWhite)
                    Text(S.t("Walk to the QR code and scan it", "Lauf zum QR-Code und scanne ihn"))
                        .font(.subheadline).foregroundColor(.oathWhite.opacity(0.9))
                }
                .padding(.vertical, 14).padding(.horizontal, 22)
                .background(Color.oathBlack.opacity(0.7), in: RoundedRectangle(cornerRadius: 18))
                .padding(.top, 20)

                if let scanError {
                    Text(scanError).font(.headline).foregroundColor(.oathBlack)
                        .padding().background(Color.oathAccent, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.top, 8)
                }
                Spacer()
                Button(S.t("Code missing?", "Code fehlt?")) { showOverride = true }
                    .font(.footnote).foregroundColor(.oathWhite.opacity(0.7)).padding(.bottom, 30)
            }
        }
    }

    private func handleScan(_ code: String) {
        guard code != lastScan else { return }
        lastScan = code
        if code == store.qrCodeValue {
            store.stopAlarm()
        } else {
            scanError = S.t("Wrong code — keep looking.", "Falscher Code – weitersuchen.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { lastScan = "" }
        }
    }

    // MARK: - Formatting

    private var remainingString: String {
        let s = store.wakeRemaining
        return String(format: "%d:%02d", s / 60, s % 60)
    }
    private var timeString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: S.isGerman ? "de_DE" : "en_US")
        f.dateFormat = S.isGerman ? "HH:mm" : "h:mm"
        return f.string(from: now)
    }
}
