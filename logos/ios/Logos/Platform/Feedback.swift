import AVFoundation
import UIKit

/// The web app's small acknowledgements (a soft tone and a tap), rebuilt
/// natively. Silent when muted or when Reduce Motion asks for stillness.
@MainActor
final class Feedback {
    static let shared = Feedback()
    enum Cue { case tap, turn, save, right, wrong, done }

    private let synth = ToneSynth()

    private func tone(_ f: Double, _ d: Double, _ v: Double, after: Double = 0, tri: Bool = false) {
        synth.add(freq: f, dur: d, vol: v * 3.2, after: after, tri: tri)
    }

    func play(_ cue: Cue, muted: Bool) {
        let haptic: () -> Void
        switch cue {
        case .right, .done, .save: haptic = { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        case .wrong: haptic = { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
        default: haptic = { UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6) }
        }
        if !UIAccessibility.isReduceMotionEnabled { haptic() }
        guard !muted, synth.ensure() else { return }
        switch cue {
        case .tap: tone(320, 0.06, 0.035, tri: true)
        case .turn: tone(196, 0.16, 0.045); tone(294, 0.13, 0.025)
        case .save: tone(392, 0.12, 0.04); tone(587, 0.20, 0.035, after: 0.085)
        case .right: tone(523, 0.10, 0.04); tone(784, 0.22, 0.032, after: 0.09)
        case .wrong: tone(196, 0.20, 0.035, tri: true)
        case .done: for (i, f) in [392.0, 494, 587, 784].enumerated() { tone(f, 0.5, 0.03, after: Double(i) * 0.12) }
        }
    }
}

/// A tiny additive synth on the audio render thread. Not actor-isolated:
/// its state is guarded by a lock because the render block runs off-main.
final class ToneSynth: @unchecked Sendable {
    private struct Voice { var freq, start, dur, vol: Double; var tri: Bool }
    private let engine = AVAudioEngine()
    private var started = false
    private var voices: [Voice] = []
    private var t: Double = 0
    private let lock = NSLock()

    func add(freq: Double, dur: Double, vol: Double, after: Double, tri: Bool) {
        lock.lock(); voices.append(Voice(freq: freq, start: t + after, dur: dur, vol: vol, tri: tri)); lock.unlock()
    }

    func ensure() -> Bool {
        if started { return true }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            let sr = engine.outputNode.outputFormat(forBus: 0).sampleRate
            let rate = sr > 0 ? sr : 44_100
            guard let mono = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1) else { return false }
            let node = AVAudioSourceNode(format: mono, renderBlock: Self.render(self, rate: rate))
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: mono)
            try engine.start()
            started = true
        } catch { started = false }
        return started
    }

    private static func render(_ synth: ToneSynth, rate: Double) -> AVAudioSourceNodeRenderBlock {
        { [unowned synth] _, _, frameCount, abl -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(abl)
            synth.lock.lock(); defer { synth.lock.unlock() }
            for f in 0..<Int(frameCount) {
                var s = 0.0
                for v in synth.voices where synth.t >= v.start && synth.t < v.start + v.dur {
                    let age = synth.t - v.start
                    let env = min(1, age / 0.012) * exp(-5.5 * age / v.dur)
                    let ph = 2 * Double.pi * v.freq * age
                    s += v.vol * env * (v.tri ? asin(sin(ph)) * 2 / .pi : sin(ph))
                }
                for b in buffers { b.mData?.assumingMemoryBound(to: Float.self)[f] = Float(s) }
                synth.t += 1 / rate
            }
            synth.voices.removeAll { synth.t > $0.start + $0.dur }
            return noErr
        }
    }
}
