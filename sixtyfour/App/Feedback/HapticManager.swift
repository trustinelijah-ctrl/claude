import CoreHaptics
import UIKit

/// Physical feedback, only where the hardware can actually produce it.
///
/// Each event is its own Core Haptics pattern, shaped like the sound it goes with: a crisp
/// tap for a pawn, a tap with a short low body for a queen or rook, a double hit for a
/// capture, three falling bounces when a king tips over. Patterns are scheduled on the
/// haptic engine's own clock, so they land with the sound, not a frame later.
///
/// Most iPads have no haptic actuator. On those this does nothing at all, and the sense of
/// touch comes from the lift, shadow, sound and settle of the piece instead.
@MainActor
final class HapticManager {
    private let hardware: Bool = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    /// The player's choice in Options.
    var enabled = true
    var isSupported: Bool { hardware && enabled }
    /// Whether this device can vibrate at all, for showing the option.
    var hasHardware: Bool { hardware }

    private var engine: CHHapticEngine?

    func prepare() {
        guard hardware, engine == nil else { return }
        do {
            let e = try CHHapticEngine()
            e.isAutoShutdownEnabled = true
            e.playsHapticsOnly = true
            e.resetHandler = { [weak e] in try? e?.start() }
            try e.start()
            engine = e
        } catch {
            engine = nil
        }
    }

    // MARK: Events

    func pickup() {
        play([tap(0, 0.32, 0.75)])
    }

    /// A piece set down; `weight` 0...1 runs from a pawn's tap to a queen's knock.
    func place(after delay: TimeInterval, weight: Float = 0.7) {
        var events = [tap(0, 0.45 + 0.5 * weight, 0.75 - 0.35 * weight)]
        if weight > 0.75 {
            // Heavy pieces have a little body after the knock.
            events.append(hum(0.006, 0.045, 0.32 * weight, 0.12))
        }
        play(events, after: delay)
    }

    /// A capture: the taken piece knocked, then the taker set down.
    func capture(after delay: TimeInterval) {
        play([tap(0, 0.7, 0.85), tap(0.034, 0.95, 0.45), hum(0.04, 0.05, 0.3, 0.1)], after: delay)
    }

    /// A king tipping over: the crown's knock, two smaller bounces and a short roll.
    func topple(after delay: TimeInterval) {
        play([tap(0, 1.0, 0.5), hum(0.004, 0.06, 0.45, 0.1),
              tap(0.105, 0.5, 0.55), tap(0.175, 0.25, 0.6),
              hum(0.19, 0.22, 0.14, 0.05)], after: delay)
    }

    /// A button: a small, soft press.
    func button() {
        play([tap(0, 0.3, 0.55)])
    }

    /// A carried piece crossing into another square: the faintest detent.
    func notch() {
        play([tap(0, 0.2, 0.95)])
    }

    /// Checkmate: a firm knock, then a soft swell like the bell's ring.
    func checkmate(after delay: TimeInterval) {
        play([tap(0, 0.9, 0.4), hum(0.12, 0.5, 0.3, 0.2, fade: true)], after: delay)
    }

    // MARK: Building blocks

    private func tap(_ t: TimeInterval, _ intensity: Float, _ sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticTransient,
                      parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                                   CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)],
                      relativeTime: t)
    }

    private func hum(_ t: TimeInterval, _ duration: TimeInterval, _ intensity: Float, _ sharpness: Float,
                     fade: Bool = true) -> CHHapticEvent {
        var params = [CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                      CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)]
        if fade {
            params.append(CHHapticEventParameter(parameterID: .decayTime, value: Float(duration)))
            params.append(CHHapticEventParameter(parameterID: .sustained, value: 0))
        }
        return CHHapticEvent(eventType: .hapticContinuous, parameters: params, relativeTime: t, duration: duration)
    }

    private func play(_ events: [CHHapticEvent], after delay: TimeInterval = 0) {
        guard isSupported else { return }
        if engine == nil { prepare() }
        guard let engine else { return }
        do {
            let player = try engine.makePlayer(with: CHHapticPattern(events: events, parameters: []))
            try player.start(atTime: delay <= 0.004 ? CHHapticTimeImmediate : engine.currentTime + delay)
        } catch {
            // The engine may have stopped (app in background, audio session change): restart once.
            try? engine.start()
        }
    }
}
