import SwiftUI

/// The "≡" menu: settings (language, durations), the stop-QR-code, and the
/// safety notes. Only reachable when the app is unlocked.
struct MenuView: View {
    @EnvironmentObject var store: AlarmStore
    @Environment(\.dismiss) private var dismiss

    @State private var showRegisterScanner = false
    @State private var shareItem: ShareItem?

    var body: some View {
        NavigationView {
            Form {
                // MARK: Settings
                Section(S.t("Settings", "Einstellungen")) {
                    Picker(S.t("Language", "Sprache"), selection: $store.language) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    Stepper(value: $store.snoozeMinutes, in: 1...30) {
                        settingRow(S.t("“Rest again” length", "„Nochmal hinlegen“-Dauer"),
                                   "\(store.snoozeMinutes) \(S.t("min", "Min"))")
                    }
                    Stepper(value: $store.maxSnoozes, in: 0...5) {
                        settingRow(S.t("“Rest again” allowed", "„Nochmal hinlegen“ erlaubt"),
                                   store.maxSnoozes == 0 ? S.t("never", "nie")
                                     : "\(store.maxSnoozes)×")
                    }
                    Stepper(value: $store.getUpSeconds, in: 30...300, step: 15) {
                        settingRow(S.t("Scan countdown", "Countdown zum Scannen"),
                                   timeLabel(store.getUpSeconds))
                    }
                }

                // MARK: QR code
                Section(S.t("QR code to stop", "QR-Code zum Stoppen")) {
                    VStack(spacing: 12) {
                        QRCodeView(value: store.qrCodeValue, size: 200)
                        Text(store.qrCodeValue).font(.system(.footnote, design: .monospaced))
                            .foregroundColor(.oathSecondary).lineLimit(1).minimumScaleFactor(0.5)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 6)

                    Button {
                        if let url = QRSheet.makePDF(value: store.qrCodeValue) { shareItem = ShareItem(url: url) }
                    } label: { Label(S.t("Print / save as PDF", "Drucken / als PDF sichern"), systemImage: "printer.fill") }
                    Button { showRegisterScanner = true } label: {
                        Label(S.t("Scan a different code", "Anderen Code scannen"), systemImage: "camera.viewfinder")
                    }
                    Button { store.regenerateQRValue() } label: {
                        Label(S.t("Generate a new code", "Neuen Code erzeugen"), systemImage: "arrow.clockwise")
                    }
                }

                // MARK: Info
                Section(S.t("How Time Oath wakes you", "So weckt dich Time Oath")) {
                    infoRow("moon.zzz.fill",
                            S.t("Leave the app open in the evening and keep the iPhone charged. It then wakes you reliably — even locked and in Do Not Disturb.",
                                "Lass die App abends geöffnet und das iPhone geladen. Sie weckt dann zuverlässig – auch gesperrt und im „Nicht stören“-Modus."))
                    infoRow("lock.fill",
                            S.t("Once an alarm rings, the app locks: no disabling, deleting or editing. Only scanning the QR code stops it.",
                                "Sobald ein Wecker klingelt, sperrt sich die App: kein Deaktivieren, Löschen oder Ändern. Nur der QR-Scan stoppt ihn."))
                    infoRow("qrcode.viewfinder",
                            S.t("Print the code and hang it away from your bed (e.g. the bathroom). Only a scan stops the alarm.",
                                "Häng den ausgedruckten Code außerhalb des Bettbereichs auf (z. B. im Bad). Nur ein Scan stoppt den Wecker."))
                    infoRow("battery.50",
                            S.t("An empty battery disables the alarm. Charge overnight.",
                                "Ein leerer Akku deaktiviert den Wecker. Am besten über Nacht laden."))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.oathBackground.ignoresSafeArea())
            .navigationTitle(S.t("Settings & QR", "Einstellungen & QR"))
            .navigationBarTitleDisplayMode(.inline)
            .tint(.oathAccent)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(S.t("Done", "Fertig")) { dismiss() }
                }
            }
            .sheet(isPresented: $showRegisterScanner) {
                NavigationView {
                    QRScannerScreen(title: S.t("Register a code", "Code hinterlegen"),
                                    instruction: S.t("Scan the QR code you want to use to stop the alarm.",
                                                     "Scanne den QR-Code, den du zum Stoppen benutzen willst.")) { code in
                        store.setQRValue(code)
                        return .accept
                    }
                }
            }
            .sheet(item: $shareItem) { item in ShareSheet(items: [item.url]) }
        }
    }

    private func settingRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundColor(.oathText)
            Spacer()
            Text(value).foregroundColor(.oathSecondary)
        }
    }

    private func infoRow(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundColor(.oathAccent).frame(width: 24)
            Text(text).font(.footnote).foregroundColor(.oathSecondary)
        }
        .padding(.vertical, 2)
    }

    private func timeLabel(_ seconds: Int) -> String {
        seconds % 60 == 0 ? "\(seconds / 60):00" : String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
