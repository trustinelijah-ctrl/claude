import SwiftData
import SwiftUI

/// Profile: stats, recent history and settings.
struct YouView: View {
    @Environment(AppServices.self) private var services
    @Query(sort: \ScanRecord.lastScannedAt, order: .reverse) private var records: [ScanRecord]
    @State private var selected: AnalysisModel?

    private var average: Int? {
        guard !records.isEmpty else { return nil }
        return records.map(\.score).reduce(0, +) / records.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("You").hfDisplay(34)
                        Spacer()
                        Text("\(services.streak.days)-day streak").eyebrow()
                    }
                    .padding(.top, 20)

                    HStack(spacing: 12) {
                        StatTile(value: "\(records.count)", label: "Foods decoded")
                        StatTile(value: average.map(String.init) ?? "–", label: "Average score",
                                 tint: average.map { ScoreTier(score: $0).color })
                        StatTile(value: "\(services.streak.best)", label: "Best streak")
                    }

                    if !records.isEmpty {
                        SectionTitle(eyebrow: "History", title: "Recent scans")
                            .padding(.top, 22)
                        ListCard {
                            ForEach(Array(records.prefix(5).enumerated()), id: \.element.barcode) { index, record in
                                Button {
                                    Haptics.tap()
                                    selected = AnalysisModel.from(record: record, services: services)
                                } label: {
                                    RecordRow(record: record,
                                              subtitle: record.lastScannedAt.formatted(.relative(presentation: .named)),
                                              showsDivider: true)
                                }
                                .buttonStyle(.plain)
                            }
                            NavigationLink {
                                HistoryView()
                            } label: {
                                LinkRow(title: "See all history", value: nil, showsDivider: false)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    SectionTitle(eyebrow: "Settings", title: "Make it yours")
                        .padding(.top, 22)
                    ListCard {
                        NavigationLink { SettingsView() } label: {
                            LinkRow(title: "Scoring lens", value: services.preferences.lens.title)
                        }
                        NavigationLink { SettingsView() } label: {
                            LinkRow(title: "Avoid list", value: services.preferences.allergens.isEmpty ? "None" : "\(services.preferences.allergens.count)")
                        }
                        NavigationLink { MethodologyView() } label: {
                            LinkRow(title: "How we score", value: nil)
                        }
                        NavigationLink { SettingsView() } label: {
                            LinkRow(title: "More settings", value: nil, showsDivider: false)
                        }
                    }
                    .buttonStyle(.plain)

                    Text(SafeLanguage.disclaimer)
                        .font(.system(size: 12))
                        .foregroundStyle(HF.Palette.inkTertiary)
                        .padding(.top, 18)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, HF.Space.gutter)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(HF.Palette.canvas.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $selected) { ProductResultView(model: $0, animateReveal: false) }
        }
    }
}

struct StatTile: View {
    var value: String
    var label: String
    var tint: Color?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value)
                .font(.system(size: 30, weight: .bold).monospacedDigit())
                .tracking(-1)
                .foregroundStyle(tint ?? HF.Palette.ink)
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(HF.Palette.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(HF.Palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.035), radius: 18, y: 6)
    }
}

struct LinkRow: View {
    var title: String
    var value: String?
    var showsDivider = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(-0.3)
                    .foregroundStyle(HF.Palette.ink)
                Spacer()
                if let value {
                    Text(value).font(.system(size: 16)).foregroundStyle(HF.Palette.inkSecondary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(HF.Palette.inkTertiary)
            }
            .padding(.horizontal, 22)
            .frame(minHeight: 58)
            if showsDivider {
                Rectangle().fill(HF.Palette.hairline).frame(height: 1)
            }
        }
        .contentShape(Rectangle())
    }
}
