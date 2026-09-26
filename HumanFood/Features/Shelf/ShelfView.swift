import SwiftData
import SwiftUI

/// Your shelf: keepers you've found, items worth swapping next, and a way to rank a new shelf.
struct ShelfView: View {
    var onCompare: () -> Void

    @Environment(AppServices.self) private var services
    @Query(sort: \ScanRecord.score, order: .reverse) private var records: [ScanRecord]
    @State private var selected: AnalysisModel?

    private var keepers: [ScanRecord] { records.filter { $0.score >= 70 } }
    private var swaps: [ScanRecord] { records.filter { $0.score < 50 }.reversed() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Shelf").hfDisplay(34)
                    Spacer()
                    Text("\(records.count) items").eyebrow()
                }
                .padding(.top, 20)

                compareCard

                if records.isEmpty {
                    Text("Products you scan will be sorted here.")
                        .font(.system(size: 16))
                        .foregroundStyle(HF.Palette.inkSecondary)
                        .padding(.top, 12)
                }

                if !keepers.isEmpty {
                    SectionTitle(eyebrow: "Keepers", title: "Scored 70 and up")
                        .padding(.top, 26)
                    ListCard {
                        ForEach(Array(keepers.prefix(8).enumerated()), id: \.element.barcode) { index, record in
                            row(record, subtitle: record.tier.phrase, last: index == min(keepers.count, 8) - 1)
                        }
                    }
                }

                if !swaps.isEmpty {
                    SectionTitle(eyebrow: "Swap next", title: "Scored under 50")
                        .padding(.top, 26)
                    ListCard {
                        ForEach(Array(swaps.prefix(8).enumerated()), id: \.element.barcode) { index, record in
                            let idea = record.product.flatMap { LocalVerdictWriter.ideas(for: $0).first }
                            row(record, subtitle: idea.map { "Try: \($0.title)" }, last: index == min(swaps.count, 8) - 1)
                        }
                    }
                }
            }
            .padding(.horizontal, HF.Space.gutter)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .sheet(item: $selected) { ProductResultView(model: $0, animateReveal: false) }
    }

    private func row(_ record: ScanRecord, subtitle: String?, last: Bool) -> some View {
        Button {
            Haptics.tap()
            selected = AnalysisModel.from(record: record, services: services)
        } label: {
            RecordRow(record: record, subtitle: subtitle, showsDivider: !last)
        }
        .buttonStyle(.plain)
    }

    private var compareCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            DotLabel(text: "Compare", color: HF.Palette.good)
                .environment(\.colorScheme, .dark)
            Text("Rank a\nshelf.")
                .font(.system(size: 46, weight: .heavy))
                .tracking(-2)
                .foregroundStyle(.white)
                .padding(.top, 20)
            Text("Scan up to 12 products and we'll rank them, best first.")
                .font(.system(size: 17))
                .tracking(-0.3)
                .foregroundStyle(.white.opacity(0.65))
                .padding(.top, 14)
            Button(action: onCompare) {
                HStack(spacing: 10) {
                    Image(systemName: "bag")
                    Text("Start comparing")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(HF.Palette.forest)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(.white, in: Capsule())
            }
            .buttonStyle(PressableStyle())
            .padding(.top, 24)
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: HF.Radius.hero, style: .continuous)
                .fill(LinearGradient(colors: [HF.Palette.forest, HF.Palette.forestLight],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }
}
