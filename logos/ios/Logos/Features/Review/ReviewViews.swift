import SwiftUI

struct ReviewView: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    @State private var addingCard = false

    var body: some View {
        let r = store.reviewStats
        Page {
            PageHead(title: store.L("Review", "Abruf"),
                     sub: store.L("Recall is the part that decides whether you can produce this in a conversation rather than recognise it on a page.",
                                  "Der Abruf entscheidet, ob du das im Gespräch hervorbringen kannst, statt es auf einer Seite nur wiederzuerkennen."))
            Block {
                if r.due > 0 {
                    Text("\(r.due)").font(Typo.serifBold(44)).foregroundStyle(Color.ink).contentTransition(.numericText())
                    Meta(r.due == 1 ? store.L("item due now", "Eintrag jetzt fällig") : store.L("items due now", "Einträge jetzt fällig")).padding(.top, 4)
                    Button(store.L("Begin", "Beginnen")) { router.push(.memorySession) }.buttonStyle(.solid).padding(.top, 18)
                } else {
                    PassageText(store.L("Nothing is due. Spacing recalls out is what makes them stick, so an empty queue means the system is working.",
                                    "Nichts fällig. Die Abstände lassen das Gelernte haften; eine leere Warteschlange heißt, dass das System arbeitet."), small: true)
                    if r.soon > 0 { Meta("\(r.soon) " + store.L("come due within two days.", "werden binnen zwei Tagen fällig.")).padding(.top, 12) }
                }
            }
            Block {
                Rubric(store.L("What is in your queue", "Was in deiner Warteschlange steht")).padding(.bottom, 12)
                VStack(alignment: .leading, spacing: 6) {
                    Meta("\(r.saved) " + store.L("passages you chose to keep", "Stellen, die du behalten wolltest"))
                    Meta("\(r.own) " + store.L("in your own words", "in deinen eigenen Worten"))
                    Meta("\(r.seeded) " + store.L("that came with the app", "die mit der App kamen"))
                    Meta("\(r.unseen) " + store.L("never attempted", "nie versucht"))
                    if r.locked > 0 { Meta("\(r.locked) " + store.L("waiting on lessons you have not reached", "warten auf noch nicht erreichte Lektionen")) }
                    Meta("\(r.all) " + store.L("in total", "insgesamt"))
                }
                if r.saved == 0 && r.own == 0 {
                    AnswerBox {
                        Meta(store.L("Everything here so far is material that shipped with the app. Anything you save from a lesson or a plan lands in this queue too. Tap Save to review under a passage.",
                                     "Bisher ist alles hier mitgeliefertes Material. Was du in einer Lektion oder einem Plan speicherst, landet ebenfalls in dieser Warteschlange. Tippe unter einer Stelle auf In Wiederholung."))
                    }.padding(.top, 16)
                }
            }
            if !r.struggling.isEmpty {
                Block {
                    Rubric(store.L("Where you keep failing", "Wo es immer wieder hakt"))
                    Meta(store.L("Judged on your actual success rate, not on how it felt.", "Nach deiner tatsächlichen Trefferquote beurteilt, nicht nach dem Gefühl.")).padding(.top, 6).padding(.bottom, 8)
                    ForEach(r.struggling) { m in
                        let st = store.memState(m.id)
                        RowLink(title: String(store.pick(m.q).prefix(64)),
                                sub: (m.concept.map { store.conceptTitle($0) + " · " } ?? "") + "\(st.successes)/\(st.attempts) " + store.L("recalled", "abgerufen"), titleSize: 16) {
                            Cite("\(Int(Double(st.successes) / Double(max(1, st.attempts)) * 100))%")
                        }
                    }
                }
            }
            SavedCardsBlock()
            Block(rule: false) {
                Button(store.L("Write a card in your own words", "Eine Karte in eigenen Worten schreiben")) { addingCard = true }.buttonStyle(.outline)
                Button(store.L("Write something down", "Etwas notieren")) { router.push(.capture(nil)) }.buttonStyle(.ghost).padding(.top, 12)
            }
            Ornament()
        }
        .sheet(isPresented: $addingCard) { OwnCardSheet() }
    }
}

struct SavedCardsBlock: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    var body: some View {
        let ex = store.extras
        if !ex.isEmpty {
            Block {
                Rubric(store.L("Saved", "Gespeichert") + " · \(ex.count)").padding(.bottom, 6)
                ForEach(ex.reversed()) { m in
                    let st = store.memState(m.id)
                    HStack(alignment: .center) {
                        Button { if m.mode == "memorise" { router.push(.memorise(m.id)) } } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(m.mode == "memorise" ? store.memoriseLabel(m) : store.pick(m.q)).font(Typo.serif(17)).foregroundStyle(Color.ink)
                                    .multilineTextAlignment(.leading)
                                Meta(dueLabel(st.due) + (m.mode == "memorise" ? " · " + store.L("step", "Stufe") + " \(st.stage + 1)/5" : ""))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        Menu {
                            Button(role: .destructive) { store.removeExtra(m.id) } label: { Label(store.L("Remove", "Entfernen"), systemImage: "trash") }
                        } label: { Image(systemName: "ellipsis").foregroundStyle(Color.ink3).frame(width: 36, height: 36) }
                    }
                    .padding(.vertical, 10)
                    .overlay(alignment: .bottom) { Rectangle().fill(Color.ruleSoft).frame(height: 1) }
                }
            }
        }
    }
    func dueLabel(_ ts: Double) -> String {
        let d = Int(ceil((ts - store.nowMs) / AppStore.day))
        if d <= 0 { return store.L("due now", "jetzt fällig") }
        if d == 1 { return store.L("tomorrow", "morgen") }
        return store.L("in \(d) days", "in \(d) Tagen")
    }
}

struct OwnCardSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var q = ""
    @State private var a = ""
    @State private var concept = ""
    var body: some View {
        NavigationStack {
            Page {
                PageHead(title: store.L("Your own card", "Deine eigene Karte"),
                         sub: store.L("Phrasing it yourself is half the learning. It joins the same review queue.",
                                      "Es selbst zu formulieren ist die halbe Arbeit. Die Karte kommt in dieselbe Warteschlange."), showLang: false)
                Block {
                    Rubric(store.L("Question", "Frage")).padding(.bottom, 8)
                    TextField(store.L("What should you be able to say?", "Was solltest du sagen können?"), text: $q, axis: .vertical)
                        .font(Typo.serif(18)).padding(12).overlay(Rectangle().stroke(Color.rule))
                    Rubric(store.L("Answer", "Antwort")).padding(.top, 18).padding(.bottom, 8)
                    TextField(store.L("In your words.", "In deinen Worten."), text: $a, axis: .vertical)
                        .lineLimit(4...12).font(Typo.serif(17)).padding(12).overlay(Rectangle().stroke(Color.rule))
                    Rubric(store.L("Topic", "Thema")).padding(.top, 18).padding(.bottom, 8)
                    Picker("", selection: $concept) {
                        Text(store.L("None", "Keins")).tag("")
                        ForEach(store.corpus.concepts) { c in Text(store.pick(c.t)).tag(c.id) }
                    }.pickerStyle(.menu).tint(.ink)
                }
                Block(rule: false) {
                    Button(store.L("Save", "Speichern")) {
                        store.addOwnCard(question: q, answer: a, concept: concept.isEmpty ? nil : concept)
                        Feedback.shared.play(.save, muted: store.mute)
                        dismiss()
                    }.buttonStyle(.solid).disabled(q.trimmingCharacters(in: .whitespaces).isEmpty || a.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(store.L("Cancel", "Abbrechen")) { dismiss() } } }
        }
    }
}

/// A review session over everything due, with the four-way rating.
struct MemorySessionView: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    @State private var queue: [String] = []
    @State private var i = 0
    @State private var revealed = false
    @State private var typed = ""
    @State private var done = 0
    @State private var total = 0
    @State private var started = false
    @State private var speech = SpeechCapture()

    var body: some View {
        Page {
            if !started { EmptyView() }
            else if i >= queue.count { finished }
            else if let m = store.memoryItem(queue[i]) { card(m) }
        }
        .logosNavigation(store.L("Review", "Abruf"))
        .onAppear(perform: start)
        .onDisappear { speech.stop() }
    }

    func start() {
        guard !started else { return }
        queue = store.dueItems.map(\.id)
        total = queue.count; i = 0; done = 0; revealed = false; typed = ""
        started = true
    }

    var finished: some View {
        VStack(alignment: .leading, spacing: 0) {
            Heading(store.L("Review complete", "Wiederholung abgeschlossen")).padding(.top, 20)
            PassageText(total == 0 ? store.L("Nothing is due.", "Nichts ist fällig.")
                    : store.L("You retrieved \(done) of \(total). What you failed on will return sooner than what you knew.",
                              "Du hast \(done) von \(total) abgerufen. Was misslang, kommt früher zurück als das Gewusste."), small: true).padding(.top, 16)
            HStack(spacing: 12) {
                Button(store.L("Done", "Fertig")) { router.pop() }.buttonStyle(.solidSmall)
                Button(store.L("Again", "Nochmal")) { started = false; start() }.buttonStyle(.ghostSmall)
            }.padding(.top, 22)
            Ornament()
        }
    }

    @ViewBuilder func card(_ m: MemoryItem) -> some View {
        HStack { Rubric(store.pick(store.corpus.modes[m.mode])); Spacer(); Cite("\(i + 1) / \(queue.count)") }.padding(.top, 14)
        ProgressRule(fraction: queue.isEmpty ? 0 : Double(i) / Double(queue.count)).padding(.top, 10)
        if m.mode == "memorise" {
            MemoriseStaircase(item: m) { good in rate(m, good ? .good : .hard, scheduled: true) }
                .id(m.id)
        } else {
            Block(top: 34) {
                PassageText(store.pick(m.q))
                if let c = m.concept {
                    Meta(store.conceptTitle(c) + (m.ref.map { " · " + store.scriptureRef($0) } ?? "")).padding(.top, 10)
                }
            }
            if !revealed {
                Block(rule: false) {
                    Rubric(store.L("Answer first", "Erst antworten")).padding(.bottom, 10)
                    SpeakField(text: $typed, speech: speech, lang: store.lang, secs: 90,
                               placeholder: store.L("Say it out loud, or type it. Then reveal.", "Sprich es laut oder tippe es. Dann aufdecken."), minHeight: 110)
                    Button(store.L("Reveal", "Aufdecken")) {
                        speech.stop()
                        withAnimation(.easeOut) { revealed = true }
                        Feedback.shared.play(.turn, muted: store.mute)
                    }.buttonStyle(.solid).padding(.top, 18)
                }
            } else {
                AnswerBox { Rubric(store.L("Stored answer", "Hinterlegte Antwort")); PassageText(store.pick(m.a), small: true) }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                Block(rule: false) {
                    Rubric(store.L("How did that go?", "Wie lief das?")).padding(.bottom, 12)
                    HStack(spacing: 8) {
                        ForEach(AppStore.Rating.allCases, id: \.self) { r in
                            Button(label(r)) { rate(m, r) }.buttonStyle(LogosButtonStyle(kind: r == .good ? .solid : .outline))
                        }
                    }
                    Meta(store.L("Rate the retrieval, not the recognition. Recognising the answer when you see it is not remembering it.",
                                 "Bewerte den Abruf, nicht das Wiedererkennen. Die Antwort zu erkennen, wenn du sie siehst, ist kein Erinnern.")).padding(.top, 14)
                }
            }
        }
    }

    func label(_ r: AppStore.Rating) -> String {
        switch r {
        case .forgot: return store.L("Forgot", "Vergessen")
        case .hard: return store.L("Hard", "Schwer")
        case .good: return store.L("Good", "Gut")
        case .immediate: return store.L("Immediate", "Sofort")
        }
    }

    func rate(_ m: MemoryItem, _ r: AppStore.Rating, scheduled: Bool = false) {
        if !scheduled { store.schedule(m.id, r) }
        if r != .forgot { done += 1 } else { queue.append(m.id) }
        Feedback.shared.play(r == .forgot ? .wrong : .right, muted: store.mute)
        withAnimation(.easeOut(duration: 0.25)) { i += 1; revealed = false; typed = "" }
    }
}

struct MemoriseView: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    let itemId: String
    var body: some View {
        Page {
            if let m = store.memoryItem(itemId) {
                MemoriseStaircase(item: m) { _ in router.pop() }
            }
        }
        .logosNavigation(store.L("Memorise", "Auswendig lernen"))
    }
}

/// Five steps from the whole text to nothing but the reference.
struct MemoriseStaircase: View {
    @Environment(AppStore.self) private var store
    let item: MemoryItem
    /// Called after scheduling, with whether recitation was good.
    let onFinish: (Bool) -> Void

    @State private var stage = 0
    @State private var filled: Set<Int> = []
    @State private var recite = ""
    @State private var checked = false
    @State private var entry = ""
    @State private var shake = 0
    @State private var meaning: String?
    @State private var meaningPending = false
    @State private var speech = SpeechCapture()
    @FocusState private var typing: Bool

    var text: String { store.memoriseText(item) }
    var label: String { store.memoriseLabel(item) }
    var gaps: [Int] { TextTools.gaps(for: text, stage: stage, seed: item.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Cite(label); Spacer() }.padding(.top, 14)
            StepRail(total: 5, current: stage, label: store.L("Step", "Stufe") + " \(stage + 1)/5")
            if stage == 0 { read }
            else if stage < 4 { gapsStage }
            else { reciteStage }
        }
        .onAppear { stage = min(4, store.memState(item.id).stage) }
        .onDisappear { speech.stop() }
        .animation(.easeOut(duration: 0.2), value: stage)
    }

    var read: some View {
        VStack(alignment: .leading, spacing: 0) {
            Meta(store.L("Read it aloud, twice. Then cover it.", "Lies es zweimal laut. Dann deck es zu.")).padding(.top, 16).padding(.bottom, 16)
            AnswerBox { PassageText(text); Cite(label + " · " + store.translationName) }
            Button(store.L("I have read it", "Gelesen")) { advance() }.buttonStyle(.solid).padding(.top, 22)
        }
    }

    var gapsStage: some View {
        let toks = TextTools.tokenise(text)
        let gs = gaps
        let current = gs.firstIndex { !filled.contains($0) }
        return VStack(alignment: .leading, spacing: 0) {
            Meta(store.L("Type the first letter of each missing word and the rest fills itself in.",
                         "Tippe den ersten Buchstaben jedes fehlenden Wortes, der Rest ergänzt sich.")).padding(.top, 16).padding(.bottom, 16)
            AnswerBox {
                gapText(toks, gs, current).font(Typo.serif(21)).lineSpacing(9)
                    .modifier(Shake(amount: CGFloat(shake)))
                Cite(label)
            }
            .onTapGesture { typing = true }
            TextField("", text: $entry)
                .focused($typing).textInputAutocapitalization(.never).autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .frame(width: 1, height: 1).opacity(0.01)
                .onChange(of: entry) { _, v in handle(v, toks, gs) }
            HStack {
                Cite("\(filled.count) / \(gs.count)")
                Spacer()
                Button(store.L("Show the words", "Wörter zeigen")) {
                    filled = Set(gs); Feedback.shared.play(.wrong, muted: store.mute)
                }.buttonStyle(.ghostSmall)
            }.padding(.top, 14)
            if filled.count >= gs.count {
                Button(store.L("Next step", "Nächste Stufe")) { advance() }.buttonStyle(.solid).padding(.top, 18)
            } else if !typing {
                Button(store.L("Start typing", "Tippen")) { typing = true }.buttonStyle(.outline).padding(.top, 18)
            }
        }
        .onAppear { typing = true }
    }

    func gapText(_ toks: [String], _ gs: [Int], _ current: Int?) -> Text {
        var t = Text("")
        for (i, tok) in toks.enumerated() {
            if gs.contains(i) && !filled.contains(i) {
                let n = max(2, TextTools.core(tok).count)
                let blank = String(repeating: "_", count: n)
                t = t + Text(blank).foregroundColor(i == current ? .bronze : .ink4).bold(i == current)
            } else if gs.contains(i) {
                t = t + Text(tok).foregroundColor(.forest)
            } else {
                t = t + Text(tok).foregroundColor(.ink)
            }
        }
        return t
    }

    func handle(_ v: String, _ toks: [String], _ gs: [Int]) {
        guard let ch = v.last else { return }
        entry = ""
        guard let cur = gs.first(where: { !filled.contains($0) }) else { return }
        let target = TextTools.core(toks[cur])
        if String(ch).lowercased() == String(target.prefix(1)).lowercased() {
            filled.insert(cur)
            Feedback.shared.play(filled.count >= gs.count ? .right : .tap, muted: store.mute)
            if filled.count >= gs.count { typing = false }
        } else {
            withAnimation(.default) { shake += 1 }
            Feedback.shared.play(.wrong, muted: store.mute)
        }
    }

    var reciteStage: some View {
        let sc = TextTools.similarity(said: recite, text: text)
        return VStack(alignment: .leading, spacing: 0) {
            Heading(label, level: 2).padding(.top, 16)
            Meta(store.L("From memory now. Say it aloud, then check.", "Jetzt aus dem Gedächtnis. Sprich es laut und prüfe dann.")).padding(.top, 10).padding(.bottom, 14)
            SpeakField(text: $recite, speech: speech, lang: store.lang, secs: 90,
                       placeholder: store.L("Recite it…", "Sprich es auf …"), minHeight: 120)
            if !checked {
                Button(store.L("Check", "Prüfen")) {
                    speech.stop(); withAnimation { checked = true }
                    Feedback.shared.play(sc >= 60 ? .right : .turn, muted: store.mute)
                }.buttonStyle(.solid).padding(.top, 18)
            } else {
                AnswerBox {
                    Rubric((sc >= 85 ? store.L("Word perfect", "Wörtlich richtig") : sc >= 60 ? store.L("Close", "Nah dran") : store.L("Not yet", "Noch nicht")) + " · \(sc)%",
                           color: sc >= 60 ? .forest : .burgundy)
                    TextTools.diff(said: recite, text: text).reduce(Text("")) { acc, p in
                        acc + Text(p.token).foregroundColor(p.hit == nil ? .ink : (p.hit! ? .forest : .burgundy)).underline(p.hit == false, color: .burgundy)
                    }.font(Typo.serif(19)).lineSpacing(6)
                    Cite(label)
                }.padding(.top, 16)
                if sc < 85 {
                    if let meaning { Rail(label: store.L("By meaning", "Nach dem Sinn")) { PassageText(meaning, small: true) } }
                    else {
                        Button {
                            Task {
                                meaningPending = true
                                let r = await CoachClient().run(.recite(text: text, reference: label, said: recite), exerciseLang: store.lang)
                                meaningPending = false
                                if case .success(let t) = r { withAnimation { meaning = t } }
                            }
                        } label: { Text(meaningPending ? store.L("Reading it…", "Wird gelesen …") : store.L("Did I get the meaning?", "Habe ich den Sinn getroffen?")) }
                        .buttonStyle(.ghost).padding(.top, 14).disabled(meaningPending || recite.count < 8)
                    }
                }
                Button(store.L("Done for today", "Für heute fertig")) {
                    store.setMemoriseStage(item.id, 4)
                    store.schedule(item.id, sc >= 60 ? .good : .hard)
                    Feedback.shared.play(.done, muted: store.mute)
                    onFinish(sc >= 60)
                }.buttonStyle(.solid).padding(.top, 18)
                Button(store.L("Run it again from the top", "Von vorn durchlaufen")) {
                    stage = 0; filled = []; recite = ""; checked = false; meaning = nil
                    store.setMemoriseStage(item.id, 0)
                }.buttonStyle(.ghost).padding(.top, 12)
            }
        }
    }

    func advance() {
        stage = min(4, stage + 1); filled = []; checked = false
        store.setMemoriseStage(item.id, stage)
        Feedback.shared.play(.turn, muted: store.mute)
    }
}

struct Shake: GeometryEffect {
    var amount: CGFloat
    var animatableData: CGFloat { get { amount } set { amount = newValue } }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 6 * sin(amount * .pi * 4), y: 0))
    }
}
