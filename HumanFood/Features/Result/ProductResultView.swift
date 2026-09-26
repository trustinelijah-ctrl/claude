import SwiftData
import SwiftUI

/// Result screen. New scans open on a full-screen reveal (the ring counts up,
/// bursts, stamps), then the ring flies into the header dial and the details rise in.
struct ProductResultView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var model: AnalysisModel
    var animateReveal: Bool

    private enum Stage { case reveal, settled }

    @State private var stage: Stage
    @State private var didSetUp = false
    @State private var toast: RewardToast.Content?
    @State private var nested: AnalysisModel?
    @State private var foodsDecoded = 0
    @Namespace private var dialSpace

    init(model: AnalysisModel, animateReveal: Bool = true) {
        self.model = model
        self.animateReveal = animateReveal
        _stage = State(initialValue: animateReveal ? .reveal : .settled)
    }

    private var tier: ScoreTier { model.score.tier }

    var body: some View {
        ZStack(alignment: .top) {
            HF.Palette.canvas.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    verdictLine
                        .padding(.top, 22)

                    Group {
                        allergenBanner
                        SummaryListCard(score: model.score)
                            .padding(.top, 26)

                        SectionTitle(eyebrow: "Summary", title: "What you need to know")
                            .padding(.top, 44)
                        VerdictCard(verdict: model.verdict, confidence: model.score.confidence)
                            .padding(.top, 18)
                        if let note = model.score.capNote {
                            Label(note, systemImage: "info.circle")
                                .font(.system(size: 14))
                                .foregroundStyle(HF.Palette.inkSecondary)
                                .padding(.top, 14)
                                .padding(.horizontal, 6)
                        }

                        AlternativesSection(model: model) { nested = $0 }
                            .padding(.top, 44)

                        SectionTitle(eyebrow: "Nutrition", title: model.product.isBeverage ? "Per 100 ml" : "Per 100 g")
                            .padding(.top, 44)
                        NutritionCard(product: model.product)
                            .padding(.top, 18)

                        SectionTitle(eyebrow: "Ingredients", title: "What's inside")
                            .padding(.top, 44)
                        IngredientsCard(product: model.product)
                            .padding(.top, 18)

                        footer
                            .padding(.top, 36)
                    }
                    .opacity(stage == .settled ? 1 : 0)
                    .offset(y: stage == .settled ? 0 : 40)
                }
                .padding(.horizontal, HF.Space.gutter)
                .padding(.top, 28)
                .padding(.bottom, 48)
            }
            .scrollIndicators(.hidden)
            .scrollDisabled(stage == .reveal)

            if stage == .reveal {
                revealStage
                    .transition(.opacity)
            }

            if let toast {
                RewardToast(content: toast)
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .task { await model.load(services: services, context: context) }
        .sheet(item: $nested) { ProductResultView(model: $0, animateReveal: false) }
        .onAppear {
            guard !didSetUp else { return }
            didSetUp = true
            foodsDecoded = (try? context.fetchCount(FetchDescriptor<ScanRecord>())) ?? 0
            if reduceMotion && animateReveal {
                stage = .settled
                celebrate()
            }
        }
    }

    // MARK: - Reveal

    private var revealStage: some View {
        ZStack {
            HF.Palette.canvas.ignoresSafeArea()
            VStack(spacing: 30) {
                Spacer()
                VStack(spacing: 10) {
                    ProductThumb(url: model.product.imageURL, size: 64, corner: 18)
                    Text(model.product.name)
                        .font(.system(size: 20, weight: .bold))
                        .tracking(-0.5)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 40)
                }
                ScoreHero(score: model.score.score, size: 250, namespace: dialSpace) {
                    Task {
                        try? await Task.sleep(for: .milliseconds(650))
                        withAnimation(.spring(response: 0.62, dampingFraction: 0.84)) { stage = .settled }
                        celebrate()
                    }
                }
                Spacer()
                Spacer()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Impatient? Tap to skip straight to the details.
            withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) { stage = .settled }
        }
    }

    // MARK: - Header (photo · name · dial)

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            ProductThumb(url: model.product.imageURL, size: 112, corner: 28)
                .overlay(alignment: .topLeading) {
                    FloatingCircleButton(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                    }
                    .offset(x: -6, y: -6)
                    .accessibilityLabel("Close")
                }

            VStack(alignment: .leading, spacing: 6) {
                if let brand = model.product.displayBrand {
                    Text(brand).eyebrow().lineLimit(1)
                }
                Text(model.product.name)
                    .font(.system(size: 26, weight: .bold))
                    .tracking(-0.9)
                    .foregroundStyle(HF.Palette.ink)
                    .lineLimit(3)
                    .minimumScaleFactor(0.75)
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                if stage == .settled {
                    ScoreDial(score: model.score.score, size: 92)
                        .matchedGeometryEffect(id: "dial", in: dialSpace)
                } else {
                    Color.clear
                }
            }
            .frame(width: 92, height: 92)
            .overlay(alignment: .topTrailing) {
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(HF.Palette.ink)
                        .frame(width: 38, height: 38)
                        .background(.regularMaterial, in: Circle())
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
                }
                .offset(x: 8, y: -10)
                .opacity(stage == .settled ? 1 : 0)
            }
            .padding(.top, 10)
        }
    }

    /// "Rarely · Worth swapping when you can." in the tier colour.
    private var verdictLine: some View {
        Text("\(tier.title) · \(model.verdict?.headline ?? tier.phrase).")
            .font(.system(size: 17, weight: .medium))
            .tracking(-0.3)
            .foregroundStyle(tier.color)
            .contentTransition(.opacity)
            .animation(HF.Motion.soft, value: model.verdict?.headline)
            .opacity(stage == .settled ? 1 : 0)
    }

    private var shareText: String {
        "\(model.product.name) scored \(model.score.score)/100 (\(tier.title)) on Human Food."
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
            .padding(.top, 22)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Human Food method · v\(Verdict.rubricVersion)").eyebrow()
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
    }

    private func celebrate() {
        guard !model.isRevisit else { return }
        let grew = services.streak.recordScan()
        let content = RewardToast.Content(foods: max(foodsDecoded, 1), streak: services.streak.days,
                                          streakGrew: grew, tier: model.score.tier)
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
            HStack(spacing: 7) {
                Circle().fill(content.tier.color).frame(width: 7, height: 7)
                Text("\(content.foods) foods scanned")
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
        .shadow(color: .black.opacity(0.1), radius: 16, y: 6)
    }
}
