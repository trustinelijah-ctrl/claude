import SwiftUI

// MARK: - Summary list (Scout-style, expandable)

/// "Beneficial ingredients · Worth watching · Processing" — tap a row to see its factors.
struct SummaryListCard: View {
    var score: ScoreResult

    private enum Row: String { case good, watch, processing }
    @State private var open: Row?

    private var good: [ScoreFactor] { score.factors.filter { $0.impact > 0 && $0.group != .processing } }
    private var watch: [ScoreFactor] { score.considerations.filter { $0.group != .processing } }
    private var processing: ScoreFactor? { score.factors.first { $0.group == .processing } }

    private var watchColor: Color {
        guard let worst = watch.map(\.impact).min() else { return HF.Palette.inkTertiary }
        return worst <= -8 ? HF.Palette.rarely : HF.Palette.limit
    }

    private var processingColor: Color {
        switch processing?.impact ?? 0 {
        case 10...: HF.Palette.excellent
        case 0..<10: HF.Palette.good
        case -9..<0: HF.Palette.fair
        default: HF.Palette.limit
        }
    }

    var body: some View {
        ListCard {
            row(.good, title: "Beneficial ingredients", value: "\(good.count)",
                dot: good.isEmpty ? HF.Palette.inkTertiary : HF.Palette.excellent, factors: good)
            row(.watch, title: "Worth watching", value: "\(watch.count)", dot: watchColor, factors: watch)
            row(.processing, title: "Processing",
                value: processing?.title.replacingOccurrences(of: "Whole or minimally processed", with: "Minimal") ?? "Unknown",
                dot: processingColor, factors: processing.map { [$0] } ?? [], last: true)
        }
    }

    @ViewBuilder
    private func row(_ id: Row, title: String, value: String, dot: Color, factors: [ScoreFactor], last: Bool = false) -> some View {
        Button {
            guard !factors.isEmpty else { return }
            Haptics.tick()
            withAnimation(HF.Motion.snappy) { open = open == id ? nil : id }
        } label: {
            ValueRow(title: title, value: value, dot: dot, showsDivider: !last || open == id)
        }
        .buttonStyle(.plain)

        if open == id {
            VStack(spacing: 0) {
                ForEach(factors) { factor in
                    FactorRow(factor: factor)
                    if factor.id != factors.last?.id {
                        Rectangle().fill(HF.Palette.hairline).frame(height: 1).padding(.leading, 46)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 6)
            .background(HF.Palette.surfaceRaised)
            .transition(.opacity.combined(with: .move(edge: .top)))
            if !last {
                Rectangle().fill(HF.Palette.hairline).frame(height: 1)
            }
        }
    }
}

struct FactorRow: View {
    var factor: ScoreFactor

    private var tint: Color {
        switch factor.kind {
        case .positive: HF.Palette.excellent
        case .consideration: factor.impact <= -12 ? HF.Palette.rarely : factor.impact <= -5 ? HF.Palette.limit : HF.Palette.fair
        case .info: HF.Palette.inkSecondary
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: factor.symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(factor.title)
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(-0.2)
                    .foregroundStyle(HF.Palette.ink)
                Text(factor.detail)
                    .font(.system(size: 14))
                    .foregroundStyle(HF.Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            if factor.impact != 0 {
                Text(factor.impact > 0 ? "+\(factor.impact)" : "−\(abs(factor.impact))")
                    .font(HF.Font.mono(14, weight: .semibold))
                    .foregroundStyle(tint)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 14)
    }
}

// MARK: - Verdict

struct VerdictCard: View {
    var verdict: Verdict?
    var confidence: ScoreResult.Confidence

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let verdict {
                Text(verdict.summary)
                    .font(.system(size: 20, weight: .regular))
                    .tracking(-0.4)
                    .lineSpacing(5)
                    .foregroundStyle(HF.Palette.ink.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                if let tip = verdict.tip, !tip.isEmpty {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lightbulb")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(HF.Palette.accent)
                        Text(tip)
                            .font(.system(size: 16))
                            .tracking(-0.2)
                            .foregroundStyle(HF.Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(HF.Palette.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                HStack(spacing: 8) {
                    Image(systemName: verdict.origin == .ai ? "sparkles" : "leaf")
                    Text(verdict.origin == .ai ? "AI-assisted summary" : "Human Food summary")
                    if confidence == .low { Text("· limited data") }
                }
                .font(HF.Font.mono(11))
                .foregroundStyle(HF.Palette.inkTertiary)
            } else {
                SkeletonLines(lines: 4)
                    .padding(.vertical, 6)
            }
        }
        .padding(26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HF.Palette.surface, in: RoundedRectangle(cornerRadius: HF.Radius.card, style: .continuous))
        .shadow(color: .black.opacity(0.035), radius: 18, y: 6)
        .animation(HF.Motion.soft, value: verdict)
    }
}

// MARK: - Nutrition

struct NutritionCard: View {
    var product: Product

    private struct Row: Identifiable {
        var id: String { name }
        var name: String
        var value: Double
        var unit: String
        /// Low / high thresholds (UK FSA front-of-pack style) — nil for neutral rows.
        var bands: (low: Double, high: Double)?
        var higherIsBetter = false
    }

    private var rows: [Row] {
        let n = product.nutrients
        let bev = product.isBeverage
        var rows: [Row] = []
        if let v = n.energyKcal { rows.append(Row(name: "Energy", value: v, unit: "kcal")) }
        if let v = n.sugars { rows.append(Row(name: "Sugars", value: v, unit: "g", bands: bev ? (low: 2.5, high: 11.25) : (low: 5, high: 22.5))) }
        if let v = n.saturatedFat { rows.append(Row(name: "Saturated fat", value: v, unit: "g", bands: bev ? (low: 0.75, high: 2.5) : (low: 1.5, high: 5))) }
        if let v = n.fat { rows.append(Row(name: "Fat", value: v, unit: "g", bands: bev ? (low: 1.5, high: 8.75) : (low: 3, high: 17.5))) }
        if let v = n.salt { rows.append(Row(name: "Salt", value: v, unit: "g", bands: bev ? (low: 0.3, high: 0.75) : (low: 0.3, high: 1.5))) }
        if let v = n.fiber { rows.append(Row(name: "Fibre", value: v, unit: "g", bands: (low: 3, high: 6), higherIsBetter: true)) }
        if let v = n.protein { rows.append(Row(name: "Protein", value: v, unit: "g")) }
        return rows
    }

    var body: some View {
        if rows.isEmpty {
            Text("No nutrition data yet for this product.")
                .font(HF.Font.callout)
                .foregroundStyle(HF.Palette.inkSecondary)
                .hfCard()
        } else {
            ListCard {
                ForEach(rows) { row in
                    ValueRow(title: row.name, value: format(row), dot: color(for: row), showsDivider: row.id != rows.last?.id)
                }
            }
        }
    }

    private func color(for row: Row) -> Color {
        guard let bands = row.bands else { return HF.Palette.ink.opacity(0.15) }
        if row.higherIsBetter {
            return row.value >= bands.high ? HF.Palette.excellent : row.value >= bands.low ? HF.Palette.good : HF.Palette.ink.opacity(0.15)
        }
        return row.value <= bands.low ? HF.Palette.excellent : row.value <= bands.high ? HF.Palette.fair : HF.Palette.rarely
    }

    private func format(_ row: Row) -> String {
        let number = row.unit == "kcal" ? String(Int(row.value.rounded())) : ScoringEngine.fmt(row.value)
        return "\(number) \(row.unit)"
    }
}

// MARK: - Ingredients

struct IngredientsCard: View {
    var product: Product
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let text = product.ingredientsText, !text.isEmpty {
                Text(text)
                    .font(.system(size: 16))
                    .tracking(-0.2)
                    .foregroundStyle(HF.Palette.inkSecondary)
                    .lineSpacing(4)
                    .lineLimit(expanded ? nil : 4)
                Button(expanded ? "Show less" : "Show all") {
                    Haptics.tick()
                    withAnimation(HF.Motion.snappy) { expanded.toggle() }
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(HF.Palette.ink)
            } else {
                Text("No ingredient list available.")
                    .font(HF.Font.callout)
                    .foregroundStyle(HF.Palette.inkSecondary)
            }
            if !product.additives.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(product.additives, id: \.self) { code in
                        let info = AdditiveCatalog.info(for: code)
                        Chip(text: "\(info.code.uppercased()) · \(info.name)",
                             tint: info.tier >= .elevated ? HF.Palette.rarely : info.tier == .moderate ? HF.Palette.limit : HF.Palette.inkSecondary)
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HF.Palette.surface, in: RoundedRectangle(cornerRadius: HF.Radius.card, style: .continuous))
        .shadow(color: .black.opacity(0.035), radius: 18, y: 6)
    }
}

// MARK: - Alternatives

struct AlternativesSection: View {
    var model: AnalysisModel
    var onOpen: (AnalysisModel) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if model.score.tier == .excellent {
                SectionTitle(eyebrow: "Swaps", title: "Already a great pick")
                HStack(spacing: 14) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(HF.Palette.excellent)
                    Text("Hard to beat. Keep it in the basket.")
                        .font(.system(size: 17))
                        .tracking(-0.3)
                        .foregroundStyle(HF.Palette.inkSecondary)
                }
                .hfCard(padding: 22)
            } else {
                HStack(alignment: .lastTextBaseline) {
                    SectionTitle(eyebrow: "Swaps", title: "Healthier picks")
                    if !model.alternativesLoaded {
                        ProgressView().padding(.bottom, 6)
                    }
                }

                if !model.alternatives.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 12) {
                            ForEach(model.alternatives) { alt in
                                Button {
                                    Haptics.tap()
                                    onOpen(AnalysisModel(product: alt.product, score: alt.score, isRevisit: true))
                                } label: {
                                    AlternativeCard(item: alt, delta: alt.score.score - model.score.score)
                                }
                                .buttonStyle(PressableStyle())
                            }
                        }
                        .padding(.horizontal, HF.Space.gutter)
                        .padding(.vertical, 10)
                    }
                    .scrollIndicators(.hidden)
                    .padding(.horizontal, -HF.Space.gutter)
                    .transition(.opacity)
                }

                if let ideas = model.verdict?.alternatives, !ideas.isEmpty {
                    ListCard {
                        ForEach(ideas) { idea in
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: "arrow.triangle.swap")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(HF.Palette.accent)
                                    .frame(width: 34, height: 34)
                                    .background(HF.Palette.accent.opacity(0.1), in: Circle())
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(idea.title)
                                        .font(.system(size: 16, weight: .semibold))
                                        .tracking(-0.3)
                                        .foregroundStyle(HF.Palette.ink)
                                    Text(idea.reason)
                                        .font(.system(size: 14))
                                        .foregroundStyle(HF.Palette.inkSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            if idea.id != ideas.last?.id {
                                Rectangle().fill(HF.Palette.hairline).frame(height: 1).padding(.leading, 68)
                            }
                        }
                    }
                }
            }
        }
        .animation(HF.Motion.soft, value: model.alternativesLoaded)
    }
}

struct AlternativeCard: View {
    var item: ScoredProduct
    var delta: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                ProductThumb(url: item.product.imageURL, size: 132, corner: 20)
                ScoreDial(score: item.score.score, size: 42)
                    .padding(3)
                    .background(HF.Palette.surface, in: Circle())
                    .offset(x: 8, y: -8)
            }
            Text(item.product.name)
                .font(.system(size: 15, weight: .semibold))
                .tracking(-0.3)
                .foregroundStyle(HF.Palette.ink)
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)
            Text("+\(delta) points")
                .font(HF.Font.mono(12, weight: .semibold))
                .foregroundStyle(HF.Palette.excellent)
        }
        .frame(width: 132)
        .padding(14)
        .background(HF.Palette.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.035), radius: 14, y: 4)
    }
}
