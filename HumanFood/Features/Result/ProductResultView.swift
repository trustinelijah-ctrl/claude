import SwiftUI
import SwiftData

struct ProductResultView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Bindable var model: AnalysisModel
    var animateReveal: Bool = true

    @State private var revealed = false
    @State private var toast: RewardToast.Content?
    @State private var nested: AnalysisModel?
    @State private var foodsDecoded = 0

    var body: some View {
        ZStack(alignment: .top) {
            HF.Palette.canvas.ignoresSafeArea()

            ScrollView {
                VStack(spacing: HF.Space.l) {
                    header
                    ScoreHero(score: model.score.score, animate: animateReveal && !reduceMotion) {
                        withAnimation(HF.Motion.soft) { revealed = true }
                        celebrate()
                    }
                    .padding(.top, HF.Space.s)
                    .padding(.bottom, HF.Space.m)

                    Group {
                        allergenBanner
                        VerdictCard(verdict: model.verdict, confidence: model.score.confidence)
                        if let note = model.score.capNote { capNoteView(note) }
                        FactorSection(title: "What's good", factors: model.score.positives, emptyText: "Nothing stood out on the plus side.")
                        FactorSection(title: "Worth knowing", factors: model.score.considerations, emptyText: "Nothing notable to flag.")
                        NutritionCard(product: model.product)
                        IngredientsCard(product: model.product)
                        AlternativesSection(model: model) { nested = $0 }
                        footer
                    }
                    .opacity(revealed || !animateReveal ? 1 : 0)
                    .offset(y: revealed || !animateReveal ? 0 : 24)
                }
                .padding(.horizontal, HF.Space.gutter)
                .padding(.top, 56)
                .padding(.bottom, 48)
            }
            .scrollIndicators(.hidden)

            topBar

            if let toast {
                RewardToast(content: toast)
                    .padding(.top, 58)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .task { await model.load(services: services, context: context) }
        .sheet(item: $nested) { ProductResultView(model: $0) }
        .onAppear {
            foodsDecoded = (try? context.fetchCount(FetchDescriptor<ScanRecord>())) ?? 0
            if !animateReveal { revealed = true }
        }
    }

    // MARK: Pieces

    private var topBar: some View {
        HStack {
            Capsule().fill(HF.Palette.ink.opacity(0.15)).frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .trailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(HF.Palette.ink)
                            .frame(width: 32, height: 32)
                            .background(HF.Palette.ink.opacity(0.06), in: Circle())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("Close")
                }
        }
        .padding(.horizontal, HF.Space.gutter)
        .padding(.top, 12)
    }

    private var header: some View {
        HStack(spacing: 14) {
            ProductThumb(url: model.product.imageURL, size: 72, corner: 18)
            VStack(alignment: .leading, spacing: 4) {
                if let brand = model.product.displayBrand {
                    Text(brand).eyebrow().lineLimit(1)
                }
                Text(model.product.name)
                    .font(HF.Font.display(24))
                    .foregroundStyle(HF.Palette.ink)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                if let quantity = model.product.quantity, !quantity.isEmpty {
                    Text(quantity).font(HF.Font.callout).foregroundStyle(HF.Palette.inkSecondary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var allergenBanner: some View {
        let matches = services.preferences.allergenMatches(for: model.product)
        if !matches.isEmpty {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(HF.Palette.limit)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Contains \(matches.map(\.name).joined(separator: ", "))")
                        .font(HF.Font.headline)
                    Text("On your avoid list. Always double-check the pack.")
                        .font(HF.Font.callout)
                        .foregroundStyle(HF.Palette.inkSecondary)
                }
                Spacer(minLength: 0)
            }
            .hfCard()
        }
    }

    private func capNoteView(_ note: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle").foregroundStyle(HF.Palette.inkSecondary)
            Text(note).font(HF.Font.callout).foregroundStyle(HF.Palette.inkSecondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Scored with the Human Food method · v\(Verdict.rubricVersion)")
                .font(HF.Font.caption)
                .foregroundStyle(HF.Palette.inkSecondary)
            Text(model.product.source == .openFoodFacts
                 ? "Product data: Open Food Facts contributors (ODbL)."
                 : "Product data: read from the label by the Human Food community.")
                .font(HF.Font.caption)
                .foregroundStyle(HF.Palette.inkTertiary)
            Text(SafeLanguage.disclaimer)
                .font(.system(size: 11))
                .foregroundStyle(HF.Palette.inkTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.top, HF.Space.m)
    }

    private func celebrate() {
        guard !model.isRevisit else { return }
        let grew = services.streak.recordScan()
        let content = RewardToast.Content(
            foods: max(foodsDecoded, 1),
            streak: services.streak.days,
            streakGrew: grew,
            tier: model.score.tier
        )
        withAnimation(HF.Motion.bouncy) { toast = content }
        Task {
            try? await Task.sleep(for: .seconds(2.6))
            withAnimation(HF.Motion.soft) { toast = nil }
        }
    }
}

// MARK: - Reward toast

struct RewardToast: View {
    struct Content: Equatable {
        var foods: Int
        var streak: Int
        var streakGrew: Bool
        var tier: ScoreTier
    }

    var content: Content

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "sparkle").foregroundStyle(content.tier.color)
                Text("Food #\(content.foods) decoded")
            }
            if content.streak > 0 {
                Divider().frame(height: 14)
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(HF.Palette.limit)
                        .symbolEffect(.bounce, value: content.streakGrew)
                    Text("\(content.streak)-day streak")
                }
            }
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(HF.Palette.ink)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(HF.Palette.hairline))
        .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
    }
}
