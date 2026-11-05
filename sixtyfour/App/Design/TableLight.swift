import CoreMotion
import SwiftUI
import UIKit

/// The lamp over the table, as the device is tilted. Tilting the iPad or iPhone moves the
/// light across the pieces and the board, the way a real set catches a lamp when you lean
/// over it. The light follows quick movements and drifts back to rest when held still, so
/// holding the device at an angle doesn't leave the board lit from the side.
@MainActor
@Observable
final class TableLight {
    /// Where the light has moved, -1...1 on each axis in screen terms (x right, y down).
    private(set) var tilt: CGSize = .zero

    @ObservationIgnored private let motion = CMMotionManager()
    @ObservationIgnored private var rest = SIMD3<Double>(0, 0, -1)
    @ObservationIgnored private var started = false

    init() {
        #if DEBUG
        // Filming on the simulator, which has no motion sensor: `-tiltSweep YES` circles the lamp.
        if UserDefaults.standard.bool(forKey: "tiltSweep") {
            let start = Date()
            Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
                let t = Date().timeIntervalSince(start)
                MainActor.assumeIsolated {
                    self?.tilt = CGSize(width: sin(t * 1.4) * 0.85, height: cos(t * 1.1) * 0.6)
                }
            }
            return
        }
        #endif
        // Screenshot runs: `-tilt "0.6,-0.4"` sets a fixed light.
        if let fixed = UserDefaults.standard.string(forKey: "tilt") {
            let p = fixed.split(separator: ",").compactMap { Double($0) }
            if p.count == 2 { tilt = CGSize(width: p[0], height: p[1]) }
            return
        }
        start()
    }

    func start() {
        guard !started, motion.isDeviceMotionAvailable else { return }
        started = true
        motion.deviceMotionUpdateInterval = 1.0 / 30
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let g = data?.gravity else { return }
            MainActor.assumeIsolated { self.update(SIMD3(g.x, g.y, g.z)) }
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        started = false
    }

    private func update(_ g: SIMD3<Double>) {
        // The rest position follows slowly (about four seconds), so only movement lights things.
        rest += (g - rest) * 0.008
        let d = g - rest
        // Device axes to screen axes for the current interface orientation.
        var x = d.x, y = -d.y
        switch Self.orientation {
        case .landscapeLeft: (x, y) = (-d.y, -d.x)
        case .landscapeRight: (x, y) = (d.y, d.x)
        case .portraitUpsideDown: (x, y) = (-d.x, d.y)
        default: break
        }
        let target = CGSize(width: max(-1, min(1, x * 3.2)), height: max(-1, min(1, y * 3.2)))
        // Smooth, so the light glides rather than trembles.
        let k = 0.18
        let next = CGSize(width: tilt.width + (target.width - tilt.width) * k,
                          height: tilt.height + (target.height - tilt.height) * k)
        if abs(next.width - tilt.width) > 0.002 || abs(next.height - tilt.height) > 0.002 { tilt = next }
    }

    private static var orientation: UIInterfaceOrientation {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.interfaceOrientation ?? .portrait
    }
}

/// A glint of the lamp on a piece: a soft band of light across its surface, moving as the
/// device tilts. Masked to the piece's own silhouette, so it only ever lights the piece.
struct PieceSheen: View {
    let imageName: String
    let size: CGFloat
    let dark: Bool
    @Environment(TableLight.self) private var light: TableLight?

    var body: some View {
        let t = light?.tilt ?? .zero
        LinearGradient(stops: [.init(color: .white.opacity(0), location: 0.30),
                               .init(color: .white.opacity(dark ? 0.55 : 0.38), location: 0.47),
                               .init(color: .white.opacity(dark ? 0.12 : 0.08), location: 0.55),
                               .init(color: .white.opacity(0), location: 0.70)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .frame(width: size * 2.2, height: size * 2.2)
            .offset(x: (t.width * 0.45 - 0.08) * size, y: (t.height * 0.45 - 0.08) * size)
            .frame(width: size, height: size)
            .clipped()
            .mask(Image(imageName).resizable().interpolation(.medium))
            .blendMode(.plusLighter)
            .opacity(0.9)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// The lamp's reflection on the board's lacquer: a broad, faint highlight that slides the
/// opposite way to the tilt, like a reflection should.
struct BoardGloss: View {
    let size: CGFloat
    @Environment(TableLight.self) private var light: TableLight?

    var body: some View {
        let t = light?.tilt ?? .zero
        RadialGradient(colors: [.white.opacity(0.10), .white.opacity(0.03), .clear],
                       center: UnitPoint(x: 0.36 - t.width * 0.3, y: 0.28 - t.height * 0.3),
                       startRadius: 0, endRadius: size * 0.62)
            .frame(width: size, height: size)
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
