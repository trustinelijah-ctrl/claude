import SwiftData
import SwiftUI

struct HomeView: View {
    var onScan: () -> Void
    var onCompare: () -> Void
    var onSeeAll: () -> Void

    @Environment(AppServices.self) private var services
    @Query(sort: \ScanRecord.lastScannedAt, order: .reverse) private var records: [ScanRecord]

    @State private var pull: CGFloat = 0
    @State private var armed = true
    @State private var selected: AnalysisModel?

    private let pullThreshold: CGFloat = 110

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                    .padding(.top, 20)
                    .padding(.bottom, 14)
                HeroCard(pullProgress: min(1, pull / pullThreshold))
                HStack(spacing: 14) {
                    ActionTile(style: .dark, title: "Scan", subtitle: "Single product", action: onScan) {
                        ScanGlyph(size: 22, lineWidth: 2)
                    }
                    ActionTile(style: .light, title: "Compare", subtitle: "Rank a shelf", action: onCompare) {
                        Image(systemName: "bag").font(.system(size: 20, weight: .medium))
                    }
                }
                if !records.isEmpty {
                    recent
                        .padding(.top, 18)
                }
                HowItWorksCard()
                    .padding(.top, records.isEmpty ? 18 : 8)
            }
            .padding(.horizontal, HF.Space.gutter)
            .padding(.bottom, 32)
            .background(alignment: .top) {
                GeometryReader { geo in
                    Color.clear.preference(key: PullOffsetKey.self, value: geo.frame(in: .named("home")).minY)
                }
            }
        }
        .coordinateSpace(name: "home")
        .scrollIndicators(.hidden)
        .onPreferenceChange(PullOffsetKey.self) { offset in
            pull = max(0, offset)
            // Pull down anywhere to scan.
            if armed, offset > pullThreshold {
                armed = false
                Haptics.lock()
                onScan()
            } else if offset < 10 {
                armed = true
            }
        }
        .sheet(item: $selected) { ProductResultView(model: $0, animateReveal: false) }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Human Food")
                .font(.system(size: 21, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(HF.Palette.ink)
            Spacer()
            Text("\(records.count) \(records.count == 1 ? "scan" : "scans")")
                .eyebrow()
                .contentTransition(.numericText())
        }
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recent").hfDisplay(24)
                Spacer()
                Button("See all", action: onSeeAll)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(HF.Palette.inkSecondary)
            }
            ListCard {
                ForEach(Array(records.prefix(3).enumerated()), id: \.element.barcode) { index, record in
                    Button {
                        Haptics.tap()
                        selected = AnalysisModel.from(record: record, services: services)
                    } label: {
                        RecordRow(record: record, showsDivider: index < min(records.count, 3) - 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct PullOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: - Hero

private struct HeroCard: View {
    var pullProgress: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                DotLabel(text: pullProgress > 0.05 ? "Keep pulling" : "Begin")
                Spacer()
                ScanGlyph(size: 26, lineWidth: 2)
                    .foregroundStyle(HF.Palette.ink.opacity(0.55))
                    .scaleEffect(1 + pullProgress * 0.35)
                    .rotationEffect(.degrees(pullProgress * 90))
            }
            Text("Scan a\nproduct.")
                .font(.system(size: 52, weight: .heavy))
                .tracking(-2.4)
                .foregroundStyle(HF.Palette.ink)
                .padding(.top, 22)
            Text("An honest 0–100 in seconds. Pull down anywhere to scan.")
                .font(.system(size: 18, weight: .regular))
                .tracking(-0.3)
                .foregroundStyle(HF.Palette.inkSecondary)
                .lineSpacing(3)
                .padding(.top, 18)
                .padding(.trailing, 30)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: HF.Radius.hero, style: .continuous)
                .fill(LinearGradient(colors: [HF.Palette.mint, HF.Palette.surface],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .shadow(color: .black.opacity(0.05), radius: 24, y: 10)
        .animation(HF.Motion.snappy, value: pullProgress > 0.05)
    }
}

// MARK: - Tiles

struct ActionTile<Icon: View>: View {
    enum Style { case dark, light }

    var style: Style
    var title: String
    var subtitle: String
    var action: () -> Void
    @ViewBuilder var icon: Icon

    private var foreground: Color { style == .dark ? .white : HF.Palette.ink }

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    icon
                        .foregroundStyle(foreground)
                        .frame(width: 58, height: 58)
                        .background(style == .dark ? Color.white.opacity(0.1) : HF.Palette.ink.opacity(0.06), in: Circle())
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(foreground.opacity(0.7))
                        .padding(.top, 4)
                }
                Spacer(minLength: 26)
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .tracking(-0.6)
                    .foregroundStyle(foreground)
                Text(subtitle)
                    .font(.system(size: 16))
                    .tracking(-0.3)
                    .foregroundStyle(foreground.opacity(style == .dark ? 0.6 : 0.55))
                    .padding(.top, 4)
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 170, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: HF.Radius.card, style: .continuous)
                    .fill(style == .dark
                          ? AnyShapeStyle(LinearGradient(colors: [HF.Palette.forest, HF.Palette.forestLight],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                          : AnyShapeStyle(HF.Palette.surfaceMuted))
            }
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - How it works

private struct HowItWorksCard: View {
    private let steps: [(String, String)] = [
        ("Scan", "Point your camera at any barcode."),
        ("Understand", "See every point we add or take away, and why."),
        ("Swap", "Get a healthier pick from the same shelf."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("How it works").hfDisplay(24)
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 18) {
                    Text("\(index + 1)")
                        .font(.system(size: 16, weight: .semibold).monospacedDigit())
                        .foregroundStyle(HF.Palette.ink)
                        .frame(width: 36, height: 36)
                        .background(HF.Palette.ink.opacity(0.06), in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(step.0)
                            .font(.system(size: 19, weight: .bold))
                            .tracking(-0.4)
                        Text(step.1)
                            .font(.system(size: 16))
                            .tracking(-0.2)
                            .foregroundStyle(HF.Palette.inkSecondary)
                    }
                }
            }
        }
        .padding(26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HF.Palette.surface, in: RoundedRectangle(cornerRadius: HF.Radius.card, style: .continuous))
        .shadow(color: .black.opacity(0.035), radius: 18, y: 6)
    }
}

// MARK: - Shared row

/// Product row used by Home, Shelf and You.
struct RecordRow: View {
    var record: ScanRecord
    var subtitle: String?
    var showsDivider = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ProductThumb(url: record.imageURL, size: 52, corner: 14)
                VStack(alignment: .leading, spacing: 3) {
                    Text(record.name)
                        .font(.system(size: 16, weight: .semibold))
                        .tracking(-0.3)
                        .foregroundStyle(HF.Palette.ink)
                        .lineLimit(1)
                    Text(subtitle ?? record.brand ?? record.tier.title)
                        .font(.system(size: 14))
                        .foregroundStyle(HF.Palette.inkSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                ScoreBadge(score: record.score, size: 44)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            if showsDivider {
                Rectangle().fill(HF.Palette.hairline).frame(height: 1).padding(.leading, 84)
            }
        }
        .contentShape(Rectangle())
    }
}
