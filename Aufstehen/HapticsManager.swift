import UIKit

/// Repeating haptic buzz while the alarm rings (foreground only — iOS does not
/// allow background haptics for third-party apps).
@MainActor
final class HapticsManager {

    private var timer: Timer?
    private let generator = UIImpactFeedbackGenerator(style: .heavy)

    func start() {
        generator.prepare()
        // Fire immediately, then on a steady, non-escalating cadence.
        buzz()
        timer = Timer.scheduledTimer(withTimeInterval: 1.4, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.buzz() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func buzz() {
        generator.impactOccurred(intensity: 0.8)
        generator.prepare()
    }
}
