import SwiftUI

/// Emergency escape when the QR code is missing or damaged. A fresh 10-digit
/// code must be typed exactly. Deliberately tedious — the only sanctioned way
/// out other than scanning.
struct EmergencyOverrideView: View {
    @EnvironmentObject var store: AlarmStore
    @Environment(\.dismiss) private var dismiss

    @State private var input = ""
    @State private var showError = false
    @FocusState private var focused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 28) {
                Text(S.t("Emergency code", "Notfall-Code"))
                    .font(.title2.weight(.bold)).foregroundColor(.oathText)

                Text(S.t("Type the code below exactly to stop the alarm without the QR code.",
                         "Tippe den folgenden Code exakt ein, um den Wecker ohne QR-Code zu stoppen."))
                    .font(.subheadline).foregroundColor(.oathSecondary)
                    .multilineTextAlignment(.center)

                Text(store.emergencyCode)
                    .font(.system(size: 34, weight: .semibold, design: .monospaced))
                    .kerning(4).foregroundColor(.oathText)
                    .padding(.vertical, 16).frame(maxWidth: .infinity)
                    .background(Color.oathCard, in: RoundedRectangle(cornerRadius: 16))
                    .textSelection(.disabled)

                TextField(S.t("Enter code", "Code eingeben"), text: $input)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .font(.system(size: 26, weight: .medium, design: .monospaced))
                    .multilineTextAlignment(.center).foregroundColor(.oathText)
                    .padding()
                    .background(Color.oathCard, in: RoundedRectangle(cornerRadius: 16))
                    .focused($focused)
                    .onChange(of: input) { newValue in
                        input = String(newValue.prefix(10).filter(\.isNumber))
                        if input.count == 10 { validate() }
                    }

                if showError {
                    Label(S.t("Wrong. A new code was generated.", "Falsch. Ein neuer Code wurde erzeugt."),
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote).foregroundColor(.oathAccent)
                }
                Spacer()
            }
            .padding(24)
            .background(Color.oathBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .tint(.oathAccent)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(S.t("Cancel", "Abbrechen")) { dismiss() }
                }
            }
            .onAppear { focused = true }
        }
    }

    private func validate() {
        if input == store.emergencyCode {
            store.stopAlarm()
            dismiss()
        } else {
            store.regenerateEmergencyCode()
            input = ""
            showError = true
        }
    }
}
