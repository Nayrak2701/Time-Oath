import SwiftUI

/// Add or edit a single alarm — wheel time picker + label, like the native Clock.
struct AlarmEditView: View {
    @EnvironmentObject var store: AlarmStore
    @Environment(\.dismiss) private var dismiss

    let existing: Alarm?

    @State private var time: Date
    @State private var label: String

    init(existing: Alarm?) {
        self.existing = existing
        let base = existing ?? Alarm(hour: 7, minute: 0)
        let date = Calendar.current.date(from: DateComponents(hour: base.hour, minute: base.minute)) ?? Date()
        _time = State(initialValue: date)
        _label = State(initialValue: base.label)
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                }
                Section {
                    TextField(S.t("Label (optional)", "Bezeichnung (optional)"), text: $label)
                }
                if existing != nil {
                    Section {
                        Button(role: .destructive) {
                            if let e = existing { store.deleteAlarm(e) }
                            dismiss()
                        } label: {
                            Text(S.t("Delete alarm", "Wecker löschen")).frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.oathBackground.ignoresSafeArea())
            .navigationTitle(existing == nil ? S.t("Add alarm", "Wecker hinzufügen")
                                             : S.t("Edit alarm", "Wecker ändern"))
            .navigationBarTitleDisplayMode(.inline)
            .tint(.oathAccent)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(S.t("Cancel", "Abbrechen")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(S.t("Save", "Sichern")) { save() }.fontWeight(.semibold)
                }
            }
        }
    }

    private func save() {
        let c = Calendar.current.dateComponents([.hour, .minute], from: time)
        let alarm = Alarm(id: existing?.id ?? UUID(),
                          hour: c.hour ?? 0, minute: c.minute ?? 0,
                          label: label.trimmingCharacters(in: .whitespaces),
                          isEnabled: existing?.isEnabled ?? true)
        if existing == nil { store.addAlarm(alarm) } else { store.updateAlarm(alarm) }
        dismiss()
    }
}
