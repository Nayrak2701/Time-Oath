import Foundation

/// In-app language selection. Default is English; the user can switch in the
/// settings menu. "System" follows the device language (Apple's recommended
/// default option to offer alongside explicit choices).
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case german

    var id: String { rawValue }

    /// Endonym label, as Apple recommends showing languages in their own tongue.
    var displayName: String {
        switch self {
        case .system:  return "System"
        case .english: return "English"
        case .german:  return "Deutsch"
        }
    }
}

/// Nonisolated mirror of the store's current language, so the string helper can
/// be read from any context (views, notification building, etc.). The store
/// keeps it in sync whenever the setting changes.
var currentAppLanguage: AppLanguage = .english

/// Tiny localisation helper. Every UI string is written inline as `S.t(en, de)`.
/// Because views observe the store, switching the language re-renders them.
enum S {
    static var isGerman: Bool {
        switch currentAppLanguage {
        case .german:  return true
        case .english: return false
        case .system:  return (Locale.preferredLanguages.first ?? "en").hasPrefix("de")
        }
    }

    static func t(_ en: String, _ de: String) -> String { isGerman ? de : en }
}
