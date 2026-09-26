import SwiftUI

// MARK: - Verdict

struct VerdictCard: View {
    var verdict: Verdict?
    var confidence: ScoreResult.Confidence

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Our take").eyebrow()
                Spacer()
                if let verdict {
                    Label(verdict.origin == .ai ? "AI-assisted" : "Human Food", systemImage: verdict.origin == .ai ? "sparkles" : "leaf")
                        .font(HF.Font.caption)
                        .foregroundStyle(HF.Palette.inkTertiary)
                }
            }
            if let verdict {
                Text(verdict.headline)
                    .font(HF.Font.display(22))
                    .foregroundStyle(HF.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verdict.summary)
                    .font(HF.Font.body)
                    .foregroundStyle(HF.Palette.inkSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                if let tip = verdict.tip, !tip.isEmpty {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lightbulb")
                            .foregroundStyle(HF.Palette.accent)
                        Text(tip)
                            .font(HF.Font.callout)
                            .foregroundStyle(HF.Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(HF.Palette.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                if confidence == .low {
                    Label("Limited product data — treat as a rough guide.", systemImage: "questionmark.circle")
                        .font(HF.Font.caption)
                        .foregroundStyle(HF.Palette.inkTertiary)
                }
            } else {
                SkeletonLines(lines: 4)
                    .padding(.vertical, 4)
            }
        }
        .hfCard()
        .animation(HF.Motion.soft, value: verdict)
    }
}

// MARK: - Factors (collapsible, Scout-style)

struct FactorSection: View {
    var title: String
    var factors: [ScoreFactor]
    var emptyText: String
    @State private var expanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                Haptics.tick()
                withAnimation(HF.Motion.snappy) { expanded.toggle() }
            } label: {
                HStack {
                    Text(title).font(HF.Font.headline).foregroundStyle(HF.Palette.ink)
                    Text("\(factors.count)")
                        .font(HF.Font.caption)
                        .foregroundStyle(HF.Palette.inkSecondary)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(HF.Palette.ink.opacity(0.06), in: Capsule())
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(HF.Palette.inkTertiary)
                        .rotationEffect(.degrees(expanded ? 0 : -90))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(spacing: 0) {
                    if factors.isEmpty {
                        Text(emptyText)
                            .font(HF.Font.callout)
                            .foregroundStyle(HF.Palette.inkSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 14)
                    }
                    ForEach(factors) { factor in
                        FactorRow(factor: factor)
                        if factor.id != factors.last?.id {
                            Divider().overlay(HF.Palette.hairline)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .hfCard()
    }
}

struct FactorRow: View {
    var factor: ScoreFactor
    @State private var showDetail = false

    private var tint: Color {
        switch factor.kind {
        case .positive: HF.Palette.excellent
        case .consideration: factor.impact <= -12 ? HF.Palette.rarely : factor.impact <= -5 ? HF.Palette.limit : HF.Palette.fair
        case .info: HF.Palette.inkSecondary
        }
    }

    var body: some View {
        Button {
            Haptics.tick()
            withAnimation(HF.Motion.snappy) { showDetail.toggle() }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: factor.symbol)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(tint)
                        .frame(width: 34, height: 34)
                        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(factor.title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(HF.Palette.ink)
                            .multilineTextAlignment(.leading)
                        Text(factor.group.title)
                            .font(HF.Font.caption)
                            .foregroundStyle(HF.Palette.inkTertiary)
                    }
                    Spacer()
                    if factor.impact != 0 {
                        Text(factor.impact > 0 ? "+\(factor.impact)" : "−\(abs(factor.impact))")
                            .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(tint)
                    }
                }
                if showDetail {
                    Text(factor.detail)
                        .font(HF.Font.callout)
                        .foregroundStyle(HF.Palette.inkSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 46)
                        .transition(.opacity)
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
        if let v = n.fat { rows.append(Row(name: "Fat", value: v, unit: "g", bands: bev ? (low: 1.5, high: 8.75) : (low: 3, high: 17.5))) }
        if let v = n.saturatedFat { rows.append(Row(name: "Saturated fat", value: v, unit: "g", bands: bev ? (low: 0.75, high: 2.5) : (low: 1.5, high: 5))) }
        if let v = n.sugars { rows.append(Row(name: "Sugars", value: v, unit: "g", bands: bev ? (low: 2.5, high: 11.25) : (low: 5, high: 22.5))) }
        if let v = n.fiber { rows.append(Row(name: "Fibre", value: v, unit: "g", bands: (low: 3, high: 6), higherIsBetter: true)) }
        if let v = n.protein { rows.append(Row(name: "Protein", value: v, unit: "g")) }
        if let v = n.salt { rows.append(Row(name: "Salt", value: v, unit: "g", bands: bev ? (low: 0.3, high: 0.75) : (low: 0.3, high: 1.5))) }
        return rows
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Nutrition", trailing: product.isBeverage ? "per 100 ml" : "per 100 g")
            if rows.isEmpty {
                Text("No nutrition data yet for this product.")
                    .font(HF.Font.callout)
                    .foregroundStyle(HF.Palette.inkSecondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(rows) { row in
                        HStack {
                            Circle().fill(color(for: row)).frame(width: 8, height: 8)
                            Text(row.name).font(HF.Font.callout).foregroundStyle(HF.Palette.ink)
                            Spacer()
                            Text(format(row))
                                .font(.system(size: 14, weight: .medium).monospacedDigit())
                                .foregroundStyle(HF.Palette.ink)
                        }
                    }
                }
            }
        }
        .hfCard()
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
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Ingredients", trailing: product.ingredients.isEmpty ? nil : "\(product.ingredients.count)")
            if let text = product.ingredientsText, !text.isEmpty {
                Text(text)
                    .font(HF.Font.callout)
                    .foregroundStyle(HF.Palette.inkSecondary)
                    .lineSpacing(3)
                    .lineLimit(expanded ? nil : 4)
                Button(expanded ? "Show less" : "Show all") {
                    Haptics.tick()
                    withAnimation(HF.Motion.snappy) { expanded.toggle() }
                }
                .font(.system(size: 14, weight: .semibold))
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
        .hfCard()
    }
}

// MARK: - Alternatives

struct AlternativesSection: View {
    var model: AnalysisModel
    var onOpen: (AnalysisModel) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if model.score.tier == .excellent {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(HF.Palette.excellent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Already a great pick").font(HF.Font.headline)
                        Text("Hard to beat. Keep it in the basket.")
                            .font(HF.Font.callout).foregroundStyle(HF.Palette.inkSecondary)
                    }
                }
                .hfCard()
            } else {
                SectionHeader(title: "Healthier swaps", trailing: model.alternativesLoaded ? nil : "Searching…")

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
                        .padding(.horizontal, 2)
                    }
                    .scrollIndicators(.hidden)
                    .transition(.opacity)
                } else if !model.alternativesLoaded {
                    HStack(spacing: 12) {
                        ForEach(0..<2, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: HF.Radius.card, style: .continuous)
                                .fill(HF.Palette.surface)
                                .frame(width: 168, height: 196)
                                .overlay(SkeletonLines(lines: 3).padding())
                        }
                    }
                }

                if let ideas = model.verdict?.alternatives, !ideas.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(ideas) { idea in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "arrow.triangle.swap")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(HF.Palette.accent)
                                    .frame(width: 30, height: 30)
                                    .background(HF.Palette.accent.opacity(0.1), in: Circle())
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(idea.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(HF.Palette.ink)
                                    Text(idea.reason).font(HF.Font.callout).foregroundStyle(HF.Palette.inkSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 10)
                        }
                    }
                    .hfCard()
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
                ProductThumb(url: item.product.imageURL, size: 136, corner: 16)
                ScoreBadge(score: item.score.score, size: 40)
                    .background(HF.Palette.surface, in: Circle())
                    .offset(x: 8, y: -8)
            }
            Text(item.product.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(HF.Palette.ink)
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)
            Text("+\(delta) points")
                .font(HF.Font.caption)
                .foregroundStyle(HF.Palette.excellent)
        }
        .frame(width: 136)
        .padding(14)
        .background(HF.Palette.surface, in: RoundedRectangle(cornerRadius: HF.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: HF.Radius.card, style: .continuous).strokeBorder(HF.Palette.hairline))
    }
}
