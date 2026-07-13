import SwiftUI

/// Home screen — native-Clock-style list of alarms. Speaker (volume) top-left,
/// add + menu top-right. While a wake cycle is active the whole screen is
/// replaced by the locked wake view (no editing possible).
struct ContentView: View {
    @EnvironmentObject var store: AlarmStore

    @State private var editing: Alarm?
    @State private var showingAdd = false
    @State private var showingMenu = false
    @State private var showingVolume = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.oathBackground.ignoresSafeArea()
                if store.alarms.isEmpty { emptyState } else { alarmList }
            }
            .navigationTitle(S.t("Alarms", "Wecker"))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showingVolume = true } label: { Image(systemName: volumeIcon) }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 4) {
                        Button { showingAdd = true } label: { Image(systemName: "plus") }
                        Button { showingMenu = true } label: { Image(systemName: "line.3.horizontal") }
                    }
                }
            }
            .tint(.oathAccent)
        }
        .navigationViewStyle(.stack)
        .tint(.oathAccent)
        // Lockdown: the wake cycle takes over the whole app.
        .fullScreenCover(isPresented: $store.wakeActive) {
            RingingView().environmentObject(store)
        }
        .sheet(isPresented: $showingAdd) { AlarmEditView(existing: nil).environmentObject(store) }
        .sheet(item: $editing) { AlarmEditView(existing: $0).environmentObject(store) }
        .sheet(isPresented: $showingMenu) { MenuView().environmentObject(store) }
        .sheet(isPresented: $showingVolume) { volumeSheet }
        .onAppear {
            NotificationManager.requestAuthorization()
            store.resumeWakeIfNeeded()
            store.reschedule()
            store.checkForActiveAlarm()
        }
    }

    // MARK: - List

    private var alarmList: some View {
        List {
            Section(footer: nextAlarmFooter) {
                ForEach(store.sortedAlarms) { alarm in
                    AlarmRow(alarm: alarm,
                             isEnabled: Binding(get: { alarm.isEnabled },
                                                set: { store.setEnabled($0, for: alarm) }),
                             onTap: { editing = alarm })
                    .listRowBackground(Color.oathBackground)
                }
                .onDelete { store.deleteAlarms(at: $0, in: store.sortedAlarms) }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder private var nextAlarmFooter: some View {
        if let text = store.nextAlarmText {
            Text(text).font(.footnote).foregroundColor(.oathAccent)
                .frame(maxWidth: .infinity, alignment: .center).padding(.top, 8)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "alarm").font(.system(size: 52)).foregroundColor(.oathSecondary)
            Text(S.t("No alarm set", "Kein Wecker gestellt"))
                .font(.title3.weight(.semibold)).foregroundColor(.oathText)
            Text(S.t("Tap ＋ at the top right to add an alarm.",
                     "Tippe oben rechts auf ＋, um einen Wecker hinzuzufügen."))
                .font(.subheadline).foregroundColor(.oathSecondary)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
        }
    }

    // MARK: - Volume (behind the speaker icon)

    private var volumeSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(S.t("Volume", "Lautstärke")).font(.headline).foregroundColor(.oathText)
            HStack(spacing: 12) {
                Image(systemName: "speaker.fill").foregroundColor(.oathSecondary)
                Slider(value: $store.alarmVolume, in: 0...1).tint(.oathAccent)
                Image(systemName: "speaker.wave.3.fill").foregroundColor(.oathSecondary)
            }
            Text(S.t("The alarm rings at this volume — regardless of Do Not Disturb and the mute switch. Default: full.",
                     "Der Wecker klingelt in dieser Lautstärke – unabhängig von „Nicht stören“ und Stummschalter. Standard: voll."))
                .font(.caption).foregroundColor(.oathSecondary)
            Spacer(minLength: 0)
        }
        .padding(24)
        .background(Color.oathBackground)
        .presentationDetents([.height(210)])
    }

    private var volumeIcon: String {
        if store.alarmVolume <= 0.01 { return "speaker.slash.fill" }
        if store.alarmVolume < 0.5 { return "speaker.wave.1.fill" }
        return "speaker.wave.3.fill"
    }
}

private struct AlarmRow: View {
    let alarm: Alarm
    @Binding var isEnabled: Bool
    let onTap: () -> Void

    var body: some View {
        HStack {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(alarm.timeString)
                        .font(.system(size: 52, weight: .thin, design: .rounded)).monospacedDigit()
                    Text(alarm.label.isEmpty ? S.t("Alarm", "Wecker") : alarm.label)
                        .font(.subheadline).foregroundColor(.oathSecondary)
                }
                .foregroundColor(.oathText)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer()
            Toggle("", isOn: $isEnabled).labelsHidden().tint(.oathAccent)
        }
        .opacity(isEnabled ? 1 : 0.45)
        .padding(.vertical, 6)
    }
}
