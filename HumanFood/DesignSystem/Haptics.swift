import UIKit

/// Thin wrapper so every haptic respects the user's preference.
@MainActor
enum Haptics {
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: PreferenceKeys.haptics) as? Bool ?? true
    }

    private static let selection = UISelectionFeedbackGenerator()
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let notification = UINotificationFeedbackGenerator()

    static func prepare() {
        selection.prepare()
        rigid.prepare()
    }

    static func tick() {
        guard isEnabled else { return }
        selection.selectionChanged()
    }

    static func tap() {
        guard isEnabled else { return }
        light.impactOccurred()
    }

    /// Tick used while the score counts up; intensity rises with the number.
    static func countTick(progress: Double) {
        guard isEnabled else { return }
        soft.impactOccurred(intensity: 0.35 + 0.6 * progress)
    }

    static func lock() {
        guard isEnabled else { return }
        rigid.impactOccurred(intensity: 0.9)
    }

    static func success() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
    }

    static func warning() {
        guard isEnabled else { return }
        notification.notificationOccurred(.warning)
    }
}
