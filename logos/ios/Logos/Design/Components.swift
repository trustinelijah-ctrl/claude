import SwiftUI

// MARK: - type

struct Rubric: View {
    let text: String
    var color: Color = .ink3
    init(_ text: String, color: Color = .ink3) { self.text = text; self.color = color }
    var body: some View {
        Text(text.uppercased())
            .font(Typo.rubric).tracking(2.2).foregroundStyle(color)
            .accessibilityAddTraits(.isHeader)
    }
}

struct Passage: View {
    let text: String
    var small = false
    var italic = false
    var color: Color = .ink
    init(_ text: String, small: Bool = false, italic: Bool = false, color: Color = .ink) {
        self.text = text; self.small = small; self.italic = italic; self.color = color
    }
    var body: some View {
        Text(text)
            .font(italic ? Typo.serifItalic(small ? 18.5 : 22) : (small ? Typo.passageSmall : Typo.passage))
            .lineSpacing(small ? 6 : 7)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }
}

/// Long teaching prose: one Passage per blank-line-separated move.
struct Paragraphs: View {
    let text: String
    var small = true
    var color: Color = .ink
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(TextTools.paragraphs(text).enumerated()), id: \.offset) { _, p in Passage(p, small: small, color: color) }
        }
    }
}

struct Meta: View {
    let text: String
    var color: Color = .ink3
    init(_ text: String, color: Color = .ink3) { self.text = text; self.color = color }
    var body: some View {
        Text(text).font(Typo.meta).foregroundStyle(color).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
    }
}

struct Cite: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View { Text(text).font(Typo.counter).foregroundStyle(Color.ink3) }
}

struct Heading: View {
    let text: String
    var level = 1
    init(_ text: String, level: Int = 1) { self.text = text; self.level = level }
    var body: some View {
        Text(text).font(level == 0 ? Typo.display : level == 1 ? Typo.h1 : level == 2 ? Typo.h2 : Typo.h3)
            .foregroundStyle(Color.ink).fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - structure

/// A page of the app: parchment ground, readable measure, generous margins.
struct Page<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) { content }
                .frame(maxWidth: Metrics.readable, alignment: .leading)
                .padding(.horizontal, Metrics.gutter)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Paper())
        .toolbarBackground(Color.vellum, for: .navigationBar)
    }
}

/// A block of the page, separated from the next by a hairline.
struct Block<Content: View>: View {
    var rule = true
    var top: CGFloat = Metrics.block
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, top)
        .padding(.bottom, Metrics.block)
        .overlay(alignment: .bottom) { if rule { Rectangle().fill(Color.ruleSoft).frame(height: 1) } }
    }
}

struct DoubleRule: View {
    var body: some View {
        VStack(spacing: 2) { Rectangle().fill(Color.rule).frame(height: 1); Rectangle().fill(Color.rule).frame(height: 1) }
    }
}

struct Ornament: View {
    var body: some View {
        Text("❧").font(Typo.serif(22)).foregroundStyle(Color.bronze2)
            .frame(maxWidth: .infinity).padding(.vertical, 28).accessibilityHidden(true)
    }
}

/// Label in the margin, content beside it, as the web's .rail.
struct Rail<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Rubric(label, color: .bronze)
            content
        }
        .padding(.leading, 16)
        .overlay(alignment: .leading) { Rectangle().fill(Color.bronze2).frame(width: 2) }
        .padding(.vertical, 18)
    }
}

struct AnswerBox<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) { content }
            .padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.vellum2)
            .overlay(Rectangle().stroke(Color.ruleSoft, lineWidth: 1))
    }
}

enum BandKind { case agree, tension, plain }
struct Band<Content: View>: View {
    var kind: BandKind = .plain
    @ViewBuilder var content: Content
    var color: Color { kind == .agree ? .forest : kind == .tension ? .burgundy : .ink4 }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) { content }
            .padding(.vertical, 16).padding(.horizontal, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.05))
            .overlay(alignment: .leading) { Rectangle().fill(color.opacity(0.75)).frame(width: 3) }
            .padding(.vertical, 8)
    }
}

struct ProgressRule: View {
    let fraction: Double
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.ruleSoft)
                Rectangle().fill(Color.bronze).frame(width: g.size.width * min(1, max(0, fraction)))
                    .animation(.easeOut(duration: 0.6), value: fraction)
            }
        }
        .frame(height: 3)
        .accessibilityElement().accessibilityLabel("Progress").accessibilityValue("\(Int(fraction * 100)) percent")
    }
}

struct StepRail: View {
    let total: Int
    let current: Int
    var label: String = ""
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule().fill(i < current ? Color.bronze2 : i == current ? Color.ink : Color.rule)
                    .frame(width: i == current ? 22 : 8, height: 4)
                    .animation(.snappy, value: current)
            }
            Spacer()
            if !label.isEmpty { Text(label).font(Typo.counter).foregroundStyle(Color.ink3) }
        }
        .padding(.vertical, 14)
        .accessibilityElement().accessibilityLabel("Step \(current + 1) of \(total)")
    }
}

struct NumberedPoint: View {
    let n: Int
    let text: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text("\(n)").font(Typo.serifItalic(20)).foregroundStyle(Color.bronze).frame(width: 18)
            Passage(text, small: true)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - controls

struct LogosButtonStyle: ButtonStyle {
    enum Kind { case solid, outline, ghost }
    var kind: Kind = .outline
    var wide = true
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typo.button).tracking(1.6).textCase(.uppercase)
            .multilineTextAlignment(.center)
            .padding(.vertical, 15).padding(.horizontal, 20)
            .frame(maxWidth: wide ? .infinity : nil, minHeight: 50)
            .foregroundStyle(kind == .solid ? Color.vellum : (kind == .ghost ? Color.ink2 : Color.ink))
            .background(kind == .solid ? Color.ink : Color.clear)
            .overlay(Rectangle().stroke(kind == .ghost ? Color.rule : Color.ink, lineWidth: 1))
            .opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == LogosButtonStyle {
    static var solid: LogosButtonStyle { LogosButtonStyle(kind: .solid) }
    static var outline: LogosButtonStyle { LogosButtonStyle(kind: .outline) }
    static var ghost: LogosButtonStyle { LogosButtonStyle(kind: .ghost) }
    static var solidSmall: LogosButtonStyle { LogosButtonStyle(kind: .solid, wide: false) }
    static var outlineSmall: LogosButtonStyle { LogosButtonStyle(kind: .outline, wide: false) }
    static var ghostSmall: LogosButtonStyle { LogosButtonStyle(kind: .ghost, wide: false) }
}

struct LinkButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(Typo.meta).underline(color: .bronze2).foregroundStyle(Color.bronze)
        }.buttonStyle(.plain)
    }
}

struct Chip: View {
    let title: String
    var on = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 14)).tracking(0.6)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .foregroundStyle(on ? Color.vellum : Color.ink2)
                .background(on ? Color.ink : Color.clear)
                .overlay(Rectangle().stroke(on ? Color.ink : Color.rule, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// A flow layout for chips.
struct Flow: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? 320
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > w, x > 0 { x = 0; y += row + spacing; row = 0 }
            x += sz.width + spacing; row = max(row, sz.height)
        }
        return CGSize(width: w, height: y + row)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += row + spacing; row = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing; row = max(row, sz.height)
        }
    }
}

struct LangSwitch: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Lang.allCases) { l in
                Button { withAnimation(.snappy) { store.lang = l } } label: {
                    Text(l.rawValue.uppercased()).font(Typo.counter)
                        .frame(width: 44, height: 36)
                        .foregroundStyle(store.lang == l ? Color.vellum : Color.ink3)
                        .background(store.lang == l ? Color.ink : Color.clear)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(l == .en ? "English" : "Deutsch")
                .accessibilityAddTraits(store.lang == l ? .isSelected : [])
            }
        }
        .overlay(Rectangle().stroke(Color.rule, lineWidth: 1))
        .sensoryFeedback(.selection, trigger: store.lang)
    }
}

/// Title block used at the top of every section.
struct PageHead: View {
    let title: String
    var sub: String = ""
    var showLang = true
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Heading(title, level: 0)
                Spacer(minLength: 12)
                if showLang { LangSwitch() }
            }
            if !sub.isEmpty { Meta(sub).padding(.top, 10) }
        }
        .padding(.top, 12).padding(.bottom, 20)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.rule).frame(height: 1) }
    }
}

// MARK: - quiz option

struct OptionRow: View {
    enum State { case idle, correct, wrong, dimmed }
    let text: String
    let state: State
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(state == .correct ? "✓" : state == .wrong ? "✗" : " ")
                    .font(Typo.serif(18)).frame(width: 16)
                    .foregroundStyle(state == .correct ? Color.forest : Color.burgundy)
                Text(text).font(Typo.serif(17.5)).multilineTextAlignment(.leading)
                    .foregroundStyle(state == .dimmed ? Color.ink4 : Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 14).padding(.horizontal, 14)
            .background(state == .correct ? Color.forest.opacity(0.07) : state == .wrong ? Color.burgundy.opacity(0.06) : Color.clear)
            .overlay(Rectangle().stroke(state == .correct ? Color.forest.opacity(0.6) : state == .wrong ? Color.burgundy.opacity(0.5) : Color.rule, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(state != .idle)
        .padding(.bottom, 8)
    }
}

/// A multiple-choice question in the web's fixed shuffle.
struct CheckView: View {
    @Environment(AppStore.self) private var store
    let number: Int?
    let q: CheckQuestion
    let given: Int?
    let answer: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Passage((number.map { "\($0). " } ?? "") + store.pick(q.q), small: true).padding(.bottom, 16)
            ForEach(TextTools.optionOrder(question: q.q, count: q.opts.count), id: \.self) { j in
                OptionRow(text: store.pick(q.opts[j]), state: state(j)) {
                    answer(j)
                    Feedback.shared.play(j == q.a ? .right : .wrong, muted: store.mute)
                }
            }
            if given != nil {
                AnswerBox { Meta(store.pick(q.why)) }.padding(.top, 6)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeOut(duration: 0.25), value: given)
    }

    func state(_ j: Int) -> OptionRow.State {
        guard let g = given else { return .idle }
        if j == q.a { return .correct }
        if j == g { return .wrong }
        return .dimmed
    }
}

// MARK: - quotes

struct QuoteCard: View {
    @Environment(AppStore.self) private var store
    let key: String
    var concept: String? = nil
    var why: String? = nil
    var saveable = true

    var body: some View {
        if let q = store.quote(key) {
            VStack(alignment: .leading, spacing: 12) {
                if q.isScripture { Passage(q.text, small: true) }
                else {
                    Passage(q.text, small: true, italic: true)
                        .padding(.leading, 14)
                        .overlay(alignment: .leading) { Rectangle().fill(Color.rule).frame(width: 2) }
                }
                HStack(alignment: .center) {
                    Cite(q.label)
                    Spacer()
                    if saveable {
                        let on = store.isSaved(key)
                        Chip(title: on ? "✓ " + store.L("In review", "In Wiederholung") : store.L("Save to review", "In Wiederholung"), on: on) {
                            if store.saveQuote(key, concept: concept) { Feedback.shared.play(.save, muted: store.mute) }
                        }
                        .disabled(on)
                    }
                }
                if let why, !why.isEmpty { Meta(why) }
            }
            .padding(18)
            .background(Color.vellum2.opacity(0.55))
            .overlay(Rectangle().stroke(Color.ruleSoft, lineWidth: 1))
            .padding(.bottom, 14)
        }
    }
}

// MARK: - rows

struct RowLink<Trailing: View>: View {
    let title: String
    var sub: String = ""
    var titleSize: CGFloat = 19
    @ViewBuilder var trailing: Trailing
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(Typo.serif(titleSize, .title3)).foregroundStyle(Color.ink).multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if !sub.isEmpty { Meta(sub).multilineTextAlignment(.leading) }
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.vertical, 16)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { Rectangle().fill(Color.ruleSoft).frame(height: 1) }
    }
}

extension RowLink where Trailing == EmptyView {
    init(title: String, sub: String = "", titleSize: CGFloat = 19) {
        self.init(title: title, sub: sub, titleSize: titleSize) { EmptyView() }
    }
}

struct EmptyNote: View {
    let title: String
    var sub: String = ""
    var body: some View {
        VStack(spacing: 10) {
            Text(title).font(Typo.h3).foregroundStyle(Color.ink2)
            if !sub.isEmpty { Meta(sub).multilineTextAlignment(.center) }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
    }
}

extension View {
    /// Standard back-bar look for pushed pages.
    func logosNavigation(_ title: String = "") -> some View {
        self.navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
}
