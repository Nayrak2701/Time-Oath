import Foundation

/// A single alarm. Multiple of these live in the store, each independently on/off.
struct Alarm: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var hour: Int
    var minute: Int
    var label: String = ""
    var isEnabled: Bool = true

    /// Minutes since midnight — used for sorting the list like the native Clock app.
    var sortKey: Int { hour * 60 + minute }

    var timeString: String {
        String(format: "%02d:%02d", hour, minute)
    }

    /// Next occurrence of this alarm strictly after `reference`.
    func nextOccurrence(after reference: Date = Date()) -> Date {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.nextDate(after: reference,
                                         matching: comps,
                                         matchingPolicy: .nextTime) ?? reference.addingTimeInterval(86_400)
    }
}

/// Which step of the locked wake cycle is showing.
enum WakePhase: String {
    case ringing     // alarm sounding — buttons "+9" (if allowed) and "Get up now"
    case snoozed     // "+9" pressed — locked, waiting to ring again
    case countdown   // "Get up now" pressed — camera + countdown to scan the QR
}
