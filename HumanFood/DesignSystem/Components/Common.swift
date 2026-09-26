import SwiftUI

/// Product photo with a calm placeholder.
struct ProductThumb: View {
    var url: URL?
    var size: CGFloat = 56
    var corner: CGFloat = 14

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(HF.Palette.surfaceRaised)
            AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.25))) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit().padding(size * 0.08)
                        .transition(.opacity)
                default:
                    Image(systemName: "takeoutbag.and.cup.and.straw")
                        .font(.system(size: size * 0.34, weight: .light))
                        .foregroundStyle(HF.Palette.inkTertiary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous).strokeBorder(HF.Palette.hairline))
    }
}

/// Animated placeholder bars shown while AI prose loads.
struct SkeletonLines: View {
    var lines: Int = 3
    @State private var shimmer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(0..<lines, id: \.self) { i in
                RoundedRectangle(cornerRadius: 5)
                    .fill(HF.Palette.ink.opacity(shimmer ? 0.10 : 0.05))
                    .frame(height: 12)
                    .frame(maxWidth: i == lines - 1 ? 180 : .infinity, alignment: .leading)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { shimmer = true }
        }
    }
}

/// Wraps children onto multiple lines (used for chips).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxX, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct Chip: View {
    var text: String
    var tint: Color = HF.Palette.ink

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(tint.opacity(0.08), in: Capsule())
    }
}

/// Small circular glass button used over the camera.
struct GlassIconButton: View {
    var systemName: String
    var action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.tap()
            action()
        }) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial.opacity(0.9), in: Circle())
                .environment(\.colorScheme, .dark)
        }
        .buttonStyle(PressableStyle(scale: 0.9))
    }
}

struct SectionHeader: View {
    var title: String
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).eyebrow()
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(HF.Font.caption)
                    .foregroundStyle(HF.Palette.inkTertiary)
            }
        }
        .padding(.horizontal, 4)
    }
}
