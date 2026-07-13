import SwiftUI
import UIKit

/// The entire app uses only three colours:
///   black  #1D1D1F   white  #F5F5F7   accent #FF7200
/// Everything else is one of these at reduced opacity. No other hues.
extension UIColor {
    static let oathBlack  = UIColor(red: 0x1D/255.0, green: 0x1D/255.0, blue: 0x1F/255.0, alpha: 1)
    static let oathWhite  = UIColor(red: 0xF5/255.0, green: 0xF5/255.0, blue: 0xF7/255.0, alpha: 1)
    static let oathAccent = UIColor(red: 0xFF/255.0, green: 0x72/255.0, blue: 0x00/255.0, alpha: 1)
}

extension Color {
    static let oathAccent = Color(UIColor.oathAccent)
    static let oathBlack  = Color(UIColor.oathBlack)
    static let oathWhite  = Color(UIColor.oathWhite)

    /// Adaptive: white in light mode, black in dark mode.
    static let oathBackground = Color(UIColor { $0.userInterfaceStyle == .dark ? .oathBlack : .oathWhite })
    /// Adaptive primary text: black in light, white in dark.
    static let oathText = Color(UIColor { $0.userInterfaceStyle == .dark ? .oathWhite : .oathBlack })
    /// Muted text — same hue, reduced opacity (stays within the palette).
    static let oathSecondary = Color(UIColor {
        ($0.userInterfaceStyle == .dark ? UIColor.oathWhite : UIColor.oathBlack).withAlphaComponent(0.55)
    })
    /// Card / grouped surface — a faint tint of the text colour.
    static let oathCard = Color(UIColor {
        ($0.userInterfaceStyle == .dark ? UIColor.oathWhite : UIColor.oathBlack).withAlphaComponent(0.07)
    })
    /// Hairline separators.
    static let oathSeparator = Color(UIColor {
        ($0.userInterfaceStyle == .dark ? UIColor.oathWhite : UIColor.oathBlack).withAlphaComponent(0.15)
    })
}
