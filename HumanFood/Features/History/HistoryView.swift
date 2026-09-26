import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ScanRecord.lastScannedAt, order: .reverse) private var records: [ScanRecord]

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All", great = "Great picks", swap = "To swap"
        var id: String { rawValue }
    }

    @State private var filter: Filter = .all
    @State private var search = ""
    @State private var selected: AnalysisModel?

    private var filtered: [ScanRecord] {
        records.filter { record in
            let matchesFilter: Bool = switch filter {
            case .all: true
            case .great: record.score >= 70
            case .swap: record.score < 50
            }
            let matchesSearch = search.isEmpty
                || record.name.localizedCaseInsensitiveContains(search)
                || (record.brand?.localizedCaseInsensitiveContains(search) ?? false)
            return matchesFilter && matchesSearch
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    StatsHeader(records: records, streak: services.streak.days)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    Picker("Filter", selection: $filter) {
                        ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: HF.Space.gutter, bottom: 8, trailing: HF.Space.gutter))
                }

                if filtered.isEmpty {
                    EmptyHistory(hasAny: !records.isEmpty)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                ForEach(filtered) { record in
                    Button {
                        Haptics.tap()
                        selected = AnalysisModel.from(record: record, services: services)
                    } label: {
                        HistoryRow(record: record)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(HF.Palette.hairline)
                    .listRowInsets(EdgeInsets(top: 10, leading: HF.Space.gutter, bottom: 10, trailing: HF.Space.gutter))
                    .swipeActions {
                        Button(role: .destructive) {
                            context.delete(record)
                            try? context.save()
                        } label: { Label("Delete", systemImage: "trash") }
                        Button {
                            record.isFavorite.toggle()
                            try? context.save()
                        } label: { Label("Favourite", systemImage: record.isFavorite ? "heart.slash" : "heart") }
                            .tint(HF.Palette.accent)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(HF.Palette.canvas.ignoresSafeArea())
            .searchable(text: $search, prompt: "Search your foods")
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(HF.Palette.ink)
                }
            }
            .sheet(item: $selected) { ProductResultView(model: $0, animateReveal: false) }
        }
    }
}

private struct StatsHeader: View {
    var records: [ScanRecord]
    var streak: Int

    private var average: Int {
        guard !records.isEmpty else { return 0 }
        return records.map(\.score).reduce(0, +) / records.count
    }

    var body: some View {
        HStack(spacing: 10) {
            stat(value: "\(records.count)", label: "Foods decoded")
            stat(value: records.isEmpty ? "–" : "\(average)", label: "Average score", tint: records.isEmpty ? nil : ScoreTier(score: average).color)
            stat(value: "\(streak)", label: "Day streak", symbol: "flame.fill")
        }
        .padding(.horizontal, HF.Space.gutter)
        .padding(.top, 8)
    }

    private func stat(value: String, label: String, tint: Color? = nil, symbol: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(value).font(HF.Font.numeral(30)).foregroundStyle(tint ?? HF.Palette.ink)
                if let symbol {
                    Image(systemName: symbol).font(.system(size: 14)).foregroundStyle(HF.Palette.limit)
                }
            }
            Text(label).font(HF.Font.caption).foregroundStyle(HF.Palette.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(HF.Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(HF.Palette.hairline))
    }
}

private struct HistoryRow: View {
    var record: ScanRecord

    var body: some View {
        HStack(spacing: 14) {
            ProductThumb(url: record.imageURL, size: 54, corner: 14)
            VStack(alignment: .leading, spacing: 3) {
                Text(record.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(HF.Palette.ink)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let brand = record.brand { Text(brand).lineLimit(1) }
                    if record.isFavorite { Image(systemName: "heart.fill").foregroundStyle(HF.Palette.accent) }
                }
                .font(HF.Font.caption)
                .foregroundStyle(HF.Palette.inkSecondary)
                Text(record.lastScannedAt, format: .relative(presentation: .named))
                    .font(HF.Font.caption)
                    .foregroundStyle(HF.Palette.inkTertiary)
            }
            Spacer(minLength: 0)
            ScoreBadge(score: record.score, size: 46)
        }
        .contentShape(Rectangle())
    }
}

private struct EmptyHistory: View {
    var hasAny: Bool

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: hasAny ? "line.3.horizontal.decrease.circle" : "barcode.viewfinder")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(HF.Palette.inkTertiary)
            Text(hasAny ? "Nothing matches" : "Your first scan is waiting")
                .font(HF.Font.display(20))
            Text(hasAny ? "Try another filter or search." : "Everything you scan lands here, ready to revisit offline.")
                .font(HF.Font.callout)
                .foregroundStyle(HF.Palette.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }
}
