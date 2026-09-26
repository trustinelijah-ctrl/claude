import SwiftUI

enum ScanMode: String, CaseIterable, Identifiable {
    case barcode, label, grocery
    var id: String { rawValue }

    var title: String {
        switch self {
        case .barcode: "Barcode"
        case .label: "Label"
        case .grocery: "Grocery"
        }
    }

    var hint: String {
        switch self {
        case .barcode: "Point at any barcode"
        case .label: "Photograph the ingredients list"
        case .grocery: "Sweep across your basket"
        }
    }

    var frameSize: CGSize {
        switch self {
        case .barcode: CGSize(width: 290, height: 170)
        case .label: CGSize(width: 300, height: 400)
        case .grocery: CGSize(width: 330, height: 330)
        }
    }
}

/// Capsule segmented control with a sliding highlight.
struct ScanModePicker: View {
    @Binding var mode: ScanMode
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 2) {
            ForEach(ScanMode.allCases) { item in
                Button {
                    guard item != mode else { return }
                    Haptics.tick()
                    withAnimation(HF.Motion.snappy) { mode = item }
                } label: {
                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(item == mode ? Color.black : Color.white.opacity(0.8))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background {
                            if item == mode {
                                Capsule().fill(.white).matchedGeometryEffect(id: "pill", in: ns)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: Capsule())
        .environment(\.colorScheme, .dark)
    }
}

/// Dimmed surround with a clear cut-out and animated corner brackets.
struct ViewfinderOverlay: View {
    var mode: ScanMode
    var pulse: Int
    var busy: Bool

    @State private var breathe = false
    @State private var flash = false

    var body: some View {
        GeometryReader { geo in
            let size = mode.frameSize
            let rect = CGRect(x: (geo.size.width - size.width) / 2,
                              y: (geo.size.height - size.height) / 2 - 40,
                              width: size.width, height: size.height)
            ZStack {
                CutoutShape(hole: size, lift: 40)
                    .fill(Color.black.opacity(0.45), style: FillStyle(eoFill: true))

                CornerBrackets()
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    .frame(width: rect.width, height: rect.height)
                    .scaleEffect(flash ? 0.94 : (breathe ? 1.015 : 1))
                    .position(x: rect.midX, y: rect.midY)
                    .shadow(color: .white.opacity(flash ? 0.8 : 0), radius: 12)

                if busy {
                    ScanLine()
                        .frame(width: rect.width - 40, height: rect.height - 24)
                        .position(x: rect.midX, y: rect.midY)
                }
            }
            .animation(HF.Motion.soft, value: mode)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { breathe = true }
        }
        .onChange(of: pulse) { _, _ in
            withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) { flash = true }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.18)) { flash = false }
        }
    }
}

/// Full-screen rectangle with an animatable rounded hole.
struct CutoutShape: Shape {
    var hole: CGSize
    var lift: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(hole.width, hole.height) }
        set { hole = CGSize(width: newValue.first, height: newValue.second) }
    }

    func path(in r: CGRect) -> Path {
        var p = Path()
        p.addRect(r)
        let rect = CGRect(x: r.midX - hole.width / 2, y: r.midY - hole.height / 2 - lift,
                          width: hole.width, height: hole.height)
        p.addRoundedRect(in: rect, cornerSize: CGSize(width: 28, height: 28), style: .continuous)
        return p
    }
}

struct CornerBrackets: Shape {
    var length: CGFloat = 30
    var radius: CGFloat = 28

    func path(in r: CGRect) -> Path {
        var p = Path()
        let l = length, c = radius
        // top-left
        p.move(to: CGPoint(x: r.minX, y: r.minY + c + l))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + c))
        p.addQuadCurve(to: CGPoint(x: r.minX + c, y: r.minY), control: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + c + l, y: r.minY))
        // top-right
        p.move(to: CGPoint(x: r.maxX - c - l, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - c, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + c), control: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + c + l))
        // bottom-right
        p.move(to: CGPoint(x: r.maxX, y: r.maxY - c - l))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - c))
        p.addQuadCurve(to: CGPoint(x: r.maxX - c, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - c - l, y: r.maxY))
        // bottom-left
        p.move(to: CGPoint(x: r.minX + c + l, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + c, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - c), control: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY - c - l))
        return p
    }

    var animatableData: CGFloat {
        get { length }
        set { length = newValue }
    }
}

/// A soft light sweeping through the frame while we look something up.
struct ScanLine: View {
    @State private var down = false

    var body: some View {
        GeometryReader { geo in
            LinearGradient(colors: [.clear, .white.opacity(0.85), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(height: 2)
                .shadow(color: .white, radius: 8)
                .offset(y: down ? geo.size.height : 0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { down = true }
        }
    }
}

/// Shown on the simulator or devices without the scanner.
struct CameraUnavailableBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x1A1C18), Color(hex: 0x0B0B0A)], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 10) {
                Image(systemName: "camera.metering.unknown")
                    .font(.system(size: 34, weight: .light))
                Text("Camera unavailable")
                    .font(HF.Font.display(20))
                Text("Use a real device, or type a barcode below.")
                    .font(HF.Font.callout)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .foregroundStyle(.white)
            .offset(y: -40)
        }
        .ignoresSafeArea()
    }
}
