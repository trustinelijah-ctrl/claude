import SwiftUI

/// The tray that fills up while scanning in Grocery mode.
struct GroceryTray: View {
    var basket: GroceryBasket
    var onRank: () -> Void
    var onClear: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(basket.items) { item in
                            TrayChip(item: item)
                                .id(item.id)
                                .transition(.scale(scale: 0.4).combined(with: .opacity))
                        }
                        if basket.items.isEmpty {
                            Text("Scanned items will appear here")
                                .font(HF.Font.callout)
                                .foregroundStyle(.white.opacity(0.6))
                                .frame(height: 64)
                                .padding(.horizontal, 8)
                        }
                    }
                    .padding(.horizontal, HF.Space.gutter)
                    .animation(HF.Motion.bouncy, value: basket.items)
                }
                .scrollIndicators(.hidden)
                .onChange(of: basket.items.count) { _, _ in
                    if let last = basket.items.last {
                        withAnimation(HF.Motion.soft) { proxy.scrollTo(last.id, anchor: .trailing) }
                    }
                }
            }

            HStack(spacing: 10) {
                if !basket.items.isEmpty {
                    Button(action: onClear) {
                        Image(systemName: "trash")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("Clear basket")
                }
                Button(action: onRank) {
                    HStack(spacing: 8) {
                        if basket.isLoading { ProgressView().tint(.black) }
                        Text(basket.ready.count >= 2 ? "Rank \(basket.ready.count) items" : "Scan at least 2 items")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(.white, in: Capsule())
                    .opacity(basket.ready.count >= 2 ? 1 : 0.55)
                }
                .buttonStyle(PressableStyle())
                .disabled(basket.ready.count < 2)
            }
            .padding(.horizontal, HF.Space.gutter)
            .environment(\.colorScheme, .dark)
        }
    }
}

private struct TrayChip: View {
    var item: GroceryBasket.Item

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white)
                switch item.state {
                case .loading:
                    ProgressView().tint(.black)
                case .ready(let scored):
                    AsyncImage(url: scored.product.imageURL) { image in
                        image.resizable().scaledToFit().padding(6)
                    } placeholder: {
                        Image(systemName: "takeoutbag.and.cup.and.straw").foregroundStyle(.gray)
                    }
                case .missing:
                    Image(systemName: "questionmark").foregroundStyle(.gray)
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            if let scored = item.scored {
                Text("\(scored.score.score)")
                    .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(scored.score.tier.color, in: Capsule())
                    .offset(x: 6, y: -6)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.top, 6)
        .padding(.trailing, 6)
        .animation(HF.Motion.bouncy, value: item)
    }
}

/// Best → least favourable, revealed one by one like a podium.
struct GroceryRankingView: View {
    @Environment(\.dismiss) private var dismiss
    var ranked: [ScoredProduct]
    var onDone: () -> Void

    @State private var shown = 0
    @State private var selected: AnalysisModel?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HF.Space.l) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your basket, ranked").font(HF.Font.display(32))
                        if let avg = average {
                            Text("Average score \(avg) · \(ranked.count) items")
                                .font(HF.Font.callout)
                                .foregroundStyle(HF.Palette.inkSecondary)
                        }
                    }

                    VStack(spacing: 10) {
                        ForEach(Array(ranked.enumerated()), id: \.element.id) { index, item in
                            if index < shown {
                                Button {
                                    Haptics.tap()
                                    selected = AnalysisModel(product: item.product, score: item.score, isRevisit: true)
                                } label: {
                                    RankRow(rank: index + 1, item: item, isBest: index == 0,
                                            isWorst: index == ranked.count - 1 && ranked.count > 2)
                                }
                                .buttonStyle(PressableStyle())
                                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                            }
                        }
                    }

                    if shown >= ranked.count, let worst = ranked.last, ranked.count > 1,
                       worst.score.tier != .excellent {
                        SwapHint(worst: worst)
                            .transition(.opacity)
                    }
                }
                .padding(HF.Space.gutter)
            }
            .background(HF.Palette.canvas.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onDone()
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(HF.Palette.ink)
                }
            }
            .sheet(item: $selected) { ProductResultView(model: $0, animateReveal: false) }
        }
        .task { await reveal() }
    }

    private var average: Int? {
        guard !ranked.isEmpty else { return nil }
        return ranked.map(\.score.score).reduce(0, +) / ranked.count
    }

    private func reveal() async {
        // Crown the winner first, then cascade down the list.
        for i in 0..<ranked.count {
            try? await Task.sleep(for: .milliseconds(i == 0 ? 250 : 140))
            withAnimation(HF.Motion.bouncy) { shown = i + 1 }
            if i == 0 { Haptics.success() } else { Haptics.tick() }
        }
    }
}

private struct RankRow: View {
    var rank: Int
    var item: ScoredProduct
    var isBest: Bool
    var isWorst: Bool

    var body: some View {
        HStack(spacing: 14) {
            Text("\(rank)")
                .font(HF.Font.numeral(26))
                .foregroundStyle(isBest ? HF.Palette.excellent : HF.Palette.inkTertiary)
                .frame(width: 28)
            ProductThumb(url: item.product.imageURL, size: 52, corner: 14)
            VStack(alignment: .leading, spacing: 3) {
                if isBest {
                    Label("Best pick", systemImage: "crown.fill")
                        .font(HF.Font.caption)
                        .foregroundStyle(HF.Palette.excellent)
                } else if isWorst {
                    Label("Swap first", systemImage: "arrow.triangle.swap")
                        .font(HF.Font.caption)
                        .foregroundStyle(item.score.tier.color)
                }
                Text(item.product.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(HF.Palette.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(item.score.tier.phrase)
                    .font(HF.Font.caption)
                    .foregroundStyle(HF.Palette.inkSecondary)
            }
            Spacer(minLength: 0)
            ScoreBadge(score: item.score.score, size: 46)
        }
        .padding(14)
        .background(HF.Palette.surface, in: RoundedRectangle(cornerRadius: HF.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: HF.Radius.card, style: .continuous)
                .strokeBorder(isBest ? HF.Palette.excellent.opacity(0.5) : HF.Palette.hairline, lineWidth: isBest ? 1.5 : 1)
        }
    }
}

private struct SwapHint: View {
    var worst: ScoredProduct

    var body: some View {
        let idea = LocalVerdictWriter.ideas(for: worst.product).first
        VStack(alignment: .leading, spacing: 8) {
            Text("One easy upgrade").eyebrow()
            Text(idea.map { "Try \($0.title.lowercased()) instead of your lowest-rated item." }
                 ?? "Look for a version with fewer ingredients.")
                .font(HF.Font.display(20))
                .foregroundStyle(HF.Palette.ink)
            if let reason = idea?.reason {
                Text(reason).font(HF.Font.callout).foregroundStyle(HF.Palette.inkSecondary)
            }
        }
        .hfCard()
    }
}
