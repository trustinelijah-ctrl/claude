import CoreHaptics
import UIKit

/// Physical feedback, only where the hardware can actually produce it.
///
/// Most iPads have no haptic actuator. On those this does nothing at all, and the sense of
/// touch comes from the lift, shadow, sound and settle of the piece instead.
@MainActor
final class HapticManager {
    let isSupported: Bool = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    private lazy var light = UIImpactFeedbackGenerator(style: .light)
    private lazy var rigid = UIImpactFeedbackGenerator(style: .rigid)
    private lazy var heavy = UIImpactFeedbackGenerator(style: .heavy)
    private lazy var notify = UINotificationFeedbackGenerator()

    func prepare() {
        guard isSupported else { return }
        rigid.prepare()
        heavy.prepare()
    }

    func pickup() {
        guard isSupported else { return }
        light.impactOccurred(intensity: 0.45)
        rigid.prepare()
    }

    func place(after delay: TimeInterval, weight: Float = 0.7) {
        fire(after: delay) { $0.rigid.impactOccurred(intensity: CGFloat(weight)) }
    }

    func capture(after delay: TimeInterval) {
        fire(after: delay) { $0.heavy.impactOccurred(intensity: 0.85) }
    }

    func checkmate(after delay: TimeInterval) {
        fire(after: delay) { $0.notify.notificationOccurred(.success) }
    }

    private func fire(after delay: TimeInterval, _ body: @escaping (HapticManager) -> Void) {
        guard isSupported else { return }
        if delay <= 0.004 {
            body(self)
        } else {
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(delay))
                guard let self else { return }
                body(self)
            }
        }
    }
}
