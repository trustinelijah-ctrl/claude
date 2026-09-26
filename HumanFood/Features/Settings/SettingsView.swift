import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var context
    @State private var confirmClear = false

    var body: some View {
        @Bindable var prefs = services.preferences
        List {
            Section {
                ForEach(Preferences.Lens.allCases) { lens in
                    Button {
                        Haptics.tick()
                        prefs.lens = lens
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: prefs.lens == lens ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(prefs.lens == lens ? HF.Palette.accent : HF.Palette.inkTertiary)
                                .font(.system(size: 18))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(lens.title).font(HF.Font.headline).foregroundStyle(HF.Palette.ink)
                                Text(lens.detail).font(HF.Font.callout).foregroundStyle(HF.Palette.inkSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Scoring lens")
            } footer: {
                Text("Changes apply to new and revisited scans.")
            }

            Section("Avoid list") {
                ForEach(Preferences.allergenOptions) { allergen in
                    Toggle(allergen.name, isOn: Binding(
                        get: { prefs.allergens.contains(allergen.tag) },
                        set: { on in
                            if on { prefs.allergens.insert(allergen.tag) } else { prefs.allergens.remove(allergen.tag) }
                        }
                    ))
                    .tint(HF.Palette.accent)
                }
            }

            Section("Experience") {
                Toggle("Haptics", isOn: $prefs.hapticsEnabled).tint(HF.Palette.accent)
            }

            Section("About") {
                NavigationLink("How we score") { MethodologyView() }
                NavigationLink("Disclaimer") {
                    ScrollView {
                        Text(SafeLanguage.disclaimer)
                            .font(HF.Font.body)
                            .foregroundStyle(HF.Palette.ink)
                            .padding(HF.Space.gutter)
                    }
                    .background(HF.Palette.canvas)
                    .navigationTitle("Disclaimer")
                }
                Link(destination: URL(string: "https://world.openfoodfacts.org")!) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Product data by Open Food Facts").foregroundStyle(HF.Palette.ink)
                        Text("Available under the Open Database Licence (ODbL).")
                            .font(HF.Font.caption).foregroundStyle(HF.Palette.inkSecondary)
                    }
                }
                LabeledContent("AI verdicts", value: services.config.hasAI ? "On" : "Local only")
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
            }

            Section {
                Button("Clear history", role: .destructive) { confirmClear = true }
            }
        }
        .scrollContentBackground(.hidden)
        .background(HF.Palette.canvas.ignoresSafeArea())
        .navigationTitle("Settings")
        .confirmationDialog("Clear all scanned foods?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear history", role: .destructive) {
                try? context.delete(model: ScanRecord.self)
                try? context.save()
            }
        }
    }
}

struct MethodologyView: View {
    private struct Pillar: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let body: String
    }

    private let pillars: [Pillar] = [
        .init(symbol: "leaf", title: "Processing first",
              body: "Every product starts from its NOVA processing group. Whole and minimally processed foods begin near the top; ultra-processed formulations start lower and can't score above 69."),
        .init(symbol: "cube", title: "Nutrients that matter",
              body: "We lower the score for added sugar, salt, saturated fat, industrial trans fat and very high energy density, and raise it for fibre, which only plants provide."),
        .init(symbol: "carrot", title: "Real ingredients",
              body: "Whole grains and legumes as the first ingredient, a high share of fruit, vegetables and nuts, and short, recognisable lists earn points. Refined flour, syrups, refined oils and flavourings cost points."),
        .init(symbol: "fork.knife", title: "Mostly plants",
              body: "Following whole-food, plant-based research, processed meat, red meat, other animal protein, dairy and eggs lower the score. Choose the Flexible lens to soften this."),
        .init(symbol: "atom", title: "Additives, in context",
              body: "Additives are rated from a reference list built on public assessments from bodies such as EFSA, the FDA and IARC. Those we rate \"best avoided\" cap the score at 49."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HF.Space.l) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("How we score").hfDisplay(34)
                    Text("A number from 0 to 100, calculated on your phone with the same rules for every product. AI writes the summary. It never sets the score.")
                        .font(HF.Font.body)
                        .foregroundStyle(HF.Palette.inkSecondary)
                }

                VStack(spacing: 12) {
                    ForEach(ScoreTier.allCases, id: \.self) { tier in
                        HStack {
                            Circle().fill(tier.color).frame(width: 10, height: 10)
                            Text(tier.title).font(HF.Font.headline)
                            Spacer()
                            Text(range(for: tier)).font(.system(size: 14, weight: .medium).monospacedDigit())
                                .foregroundStyle(HF.Palette.inkSecondary)
                        }
                    }
                }
                .hfCard()

                ForEach(pillars) { pillar in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: pillar.symbol)
                            .font(.system(size: 17))
                            .foregroundStyle(HF.Palette.accent)
                            .frame(width: 38, height: 38)
                            .background(HF.Palette.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(pillar.title).font(HF.Font.headline)
                            Text(pillar.body).font(HF.Font.callout).foregroundStyle(HF.Palette.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Reading list").eyebrow()
                    ForEach(readingList, id: \.self) { item in
                        Text(item).font(HF.Font.callout).foregroundStyle(HF.Palette.ink)
                    }
                }
                .hfCard()

                Text(SafeLanguage.disclaimer)
                    .font(HF.Font.caption)
                    .foregroundStyle(HF.Palette.inkTertiary)
            }
            .padding(HF.Space.gutter)
        }
        .background(HF.Palette.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private let readingList = [
        "The China Study and Whole, T. Colin Campbell",
        "In Defense of Food and Food Rules, Michael Pollan",
        "How Not to Die, Michael Greger",
        "Prevent and Reverse Heart Disease, Caldwell Esselstyn",
        "Ultra-Processed People, Chris van Tulleken",
        "The NOVA food classification, Monteiro et al.",
        "IARC Monographs vol. 114, red and processed meat",
    ]

    private func range(for tier: ScoreTier) -> String {
        switch tier {
        case .excellent: "85–100"
        case .good: "70–84"
        case .fair: "50–69"
        case .limit: "30–49"
        case .rarely: "0–29"
        }
    }
}
