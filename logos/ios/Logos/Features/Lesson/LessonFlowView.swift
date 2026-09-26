import SwiftUI

/// The daily lesson: open → Christian teaching → Stoic teaching → side by side
/// → check yourself → say it → done. Same steps, same mastery rules as the web.
struct LessonFlowView: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    static let steps = [("Open", "Beginn"), ("Christian teaching", "Christliche Lehre"), ("Stoic teaching", "Stoische Lehre"),
                        ("Side by side", "Nebeneinander"), ("Check yourself", "Selbstprüfung"), ("Say it", "Sprich es"), ("Done", "Fertig")]

    var st: JSONValue { store.lesson }
    var id: String { st["id"].string }
    var les: Lesson? { store.corpus.lessons[id] }
    var concept: Concept? { store.corpus.concept(id) }
    var title: String { concept.map { store.pick($0.t) } ?? id }
    var step: Int { st["step"].int }

    var body: some View {
        ScrollViewReader { proxy in
            Page {
                Color.clear.frame(height: 0).id("top")
                if let les {
                    if step > 0 && step < 6 {
                        StepRail(total: 5, current: step - 1, label: store.L(Self.steps[step].0, Self.steps[step].1))
                    }
                    Group {
                        switch step {
                        case 0: openStep(les)
                        case 1, 2: teaching(les, christian: step == 1)
                        case 3: compare(les)
                        case 4: check(les)
                        case 5: say(les)
                        default: done(les)
                        }
                    }
                    .id(step)
                    .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 12)), removal: .opacity))
                    Ornament()
                } else {
                    EmptyNote(title: store.L("No lesson here.", "Keine Lektion."))
                }
            }
            .onChange(of: step) { _, _ in withAnimation { proxy.scrollTo("top", anchor: .top) } }
            .animation(.easeOut(duration: 0.3), value: step)
        }
        .logosNavigation(title)
    }

    func advance() {
        let wasDone = st["done"].truthy
        store.lessonAdvance()
        Feedback.shared.play(!wasDone && store.lesson["done"].truthy ? .done : .turn, muted: store.mute)
    }
    func back() { store.updateLesson { $0["step"] = .number(max(0, $0["step"].double - 1)) }; Feedback.shared.play(.tap, muted: store.mute) }

    // MARK: 0 — open

    @ViewBuilder func openStep(_ les: Lesson) -> some View {
        VStack(spacing: 0) {
            Rubric(store.L("Today's lesson", "Lektion des Tages")).padding(.top, 22)
            Plate(id: les.plate, height: 130).padding(.vertical, 14)
            Heading(title).multilineTextAlignment(.center)
            if let g = concept?.gloss { Cite(g).padding(.top, 6) }
        }.frame(maxWidth: .infinity)
        Block { PassageText(store.pick(les.intro), small: true) }
        if let bl = store.corpus.builds[id], let from = bl.from {
            let u = store.unitForLesson(id)
            let met = u.map(store.unitReady) ?? false
            Block {
                AnswerBox {
                    Rubric(met ? store.L("Builds on what you have done", "Baut auf dem auf, was du getan hast")
                               : store.L("Builds on earlier units", "Baut auf früheren Einheiten auf"))
                    Meta(store.pick(from))
                }
            }
        }
        Block(rule: false) {
            Button(store.L("Begin — about 6 minutes", "Beginnen — etwa 6 Minuten"), action: advance).buttonStyle(.solid)
            HStack(spacing: 10) {
                Button(store.L("Choose a different topic", "Anderes Thema wählen")) { router.push(.pickLesson) }.buttonStyle(.ghostSmall)
                Button(store.L("Skip to practice", "Zum Üben")) { router.tab = .practice }.buttonStyle(.ghostSmall)
            }.padding(.top, 12)
        }
    }

    // MARK: 1/2 — teachings

    @ViewBuilder func teaching(_ les: Lesson, christian: Bool) -> some View {
        let side = christian ? les.christian : les.stoic
        let dep = christian ? store.corpus.depth[id]?.c : store.corpus.depth[id]?.s
        let deep = store.corpus.deepen[id]
        Block(top: 16) {
            Rubric(title).padding(.bottom, 10)
            Heading(christian ? store.L("The Christian teaching", "Die christliche Lehre") : store.L("The Stoic teaching", "Die stoische Lehre"))
            PassageText(store.pick(side.summary), small: true).padding(.top, 16)
        }
        if let s = dep?.story { Rail(label: store.L("Where this comes from", "Woher das kommt")) { Paragraphs(text: store.pick(s)) } }
        Block {
            Rubric(store.L("What it actually says", "Was sie tatsächlich sagt")).padding(.bottom, 8)
            ForEach(Array(side.points.enumerated()), id: \.offset) { i, p in NumberedPoint(n: i + 1, text: store.pick(p)) }
        }
        if let l = dep?.life { Rail(label: store.L("On an ordinary day", "An einem gewöhnlichen Tag")) { Paragraphs(text: store.pick(l)) } }
        if !christian, let dist = deep?.dist {
            Block {
                AnswerBox {
                    Rubric(store.L("A distinction worth getting right", "Eine Unterscheidung, die sitzen muss"))
                    Paragraphs(text: store.pick(dist))
                }
            }
        }
        if let longer = christian ? deep?.c : deep?.s {
            Block {
                Heading(store.L("A closer look", "Genauer hingesehen"), level: 2)
                Paragraphs(text: store.pick(longer)).padding(.top, 14)
            }
        }
        if !christian, let obj = deep?.obj {
            Block {
                Rubric(store.L("The objection you will meet", "Der Einwand, dem du begegnest")).padding(.bottom, 10)
                PassageText(store.pick(obj), small: true, color: .burgundy)
                if let rep = deep?.rep { Paragraphs(text: store.pick(rep)).padding(.top, 14) }
            }
        }
        Block {
            Rubric(store.L("In its own words", "In eigenen Worten"))
            Meta(store.L("Save any of these and you can learn them by heart, step by step.", "Speichere davon, was du willst — dann lernst du es Stufe für Stufe auswendig.") + " " + store.translationName)
                .padding(.top, 6).padding(.bottom, 16)
            ForEach(side.quotes, id: \.self) { k in
                QuoteCard(key: k, concept: id, why: store.corpus.qwhy[id + ":" + k].map { store.pick($0) })
            }
        }
        AskBlock(topic: id, tradition: christian ? "christian" : "stoic", summary: store.pick(side.summary), points: side.points.map { store.pick($0) })
        Block(rule: false) {
            Button(christian ? store.L("Now the Stoic teaching", "Nun die stoische Lehre") : store.L("Continue", "Weiter"), action: advance).buttonStyle(.solid)
            Button(store.L("Back", "Zurück"), action: back).buttonStyle(.ghost).padding(.top, 12)
        }
    }

    // MARK: 3 — side by side

    @ViewBuilder func compare(_ les: Lesson) -> some View {
        Block(top: 16) {
            Heading(store.L("Side by side", "Nebeneinander"))
            Meta(store.L("You have now heard each tradition on its own terms. Comparison is a separate skill — and an optional one. Skip it if you would rather let the two settle first.",
                         "Du hast nun jede Tradition für sich gehört. Der Vergleich ist eine eigene Fertigkeit — und freiwillig. Überspring ihn, wenn du die beiden erst setzen lassen willst.")).padding(.top, 12)
        }
        if let b = store.corpus.builds[id], let t = b.t, let body = b.body {
            Block { Heading(store.pick(t), level: 2); Paragraphs(text: store.pick(body)).padding(.top, 14) }
        }
        if !st["compared"].truthy {
            Block(rule: false) {
                Button(store.L("Show how they compare", "Vergleich anzeigen")) {
                    withAnimation { store.updateLesson { $0["compared"] = true } }
                    Feedback.shared.play(.turn, muted: store.mute)
                }.buttonStyle(.outline)
                Button(store.L("Skip for now", "Vorerst überspringen"), action: advance).buttonStyle(.ghost).padding(.top, 12)
            }
        } else {
            if let a = concept?.agree, !a.isEmpty { Band(kind: .agree) { Rubric(store.L("Where they agree", "Wo sie übereinstimmen")); Paragraphs(text: store.pick(a)) } }
            if let t = concept?.tension ?? les.tension, !t.isEmpty { Band(kind: .tension) { Rubric(store.L("Where they differ", "Wo sie sich unterscheiden")); Paragraphs(text: store.pick(t)) } }
            if let ap = concept?.application, !ap.isEmpty { Rail(label: store.L("Try this week", "Diese Woche")) { Paragraphs(text: store.pick(ap)) } }
            Block(rule: false) { Button(store.L("Continue", "Weiter"), action: advance).buttonStyle(.solid) }
        }
    }

    // MARK: 4 — think, then check

    @ViewBuilder func check(_ les: Lesson) -> some View {
        if let th = store.corpus.think[id], !st["thoughtDone"].truthy {
            ThinkBlock(think: th, text: Binding(get: { store.lesson["thought"].string },
                                                set: { v in store.updateLesson { $0["thought"] = .string(v) } }))
            Block(rule: false) {
                Button(store.L("Continue", "Weiter")) {
                    store.updateLesson { $0["thoughtDone"] = true }
                    Feedback.shared.play(.turn, muted: store.mute)
                }.buttonStyle(.solid)
            }
        } else {
            Block(top: 16) {
                Heading(store.L("Check yourself", "Selbstprüfung"))
                Meta(store.L("Four questions on what you just read. The last one gives you a new case to apply it to.",
                             "Vier Fragen zum eben Gelesenen. Die letzte gibt dir einen neuen Fall, auf den du es anwendest.")).padding(.top, 12)
            }
            ForEach(Array(les.check.enumerated()), id: \.offset) { i, q in
                Block {
                    CheckView(number: i + 1, q: q, given: st["checks"][String(i)].intValue) { j in
                        store.updateLesson { if $0["checks"][String(i)].isNull { $0["checks"][String(i)] = .number(Double(j)) } }
                    }
                }
            }
            let answered = st["checks"].object.count >= les.check.count
            if answered {
                let right = store.lessonCorrect(st)
                Block(rule: false) {
                    Text("\(right) / \(les.check.count)").font(Typo.h2).foregroundStyle(Color.ink)
                    Meta(right >= 3 ? store.L("Good. That is enough to start recalling this without help.", "Gut. Das genügt, um das künftig ohne Hilfe abzurufen.")
                                    : store.L("Worth reading the two teachings again before you move on.", "Es lohnt sich, die beiden Lehren noch einmal zu lesen, bevor du weitergehst.")).padding(.top, 8)
                    Button(store.L("Continue", "Weiter"), action: advance).buttonStyle(.solid).padding(.top, 18)
                    if right < 2 {
                        Button(store.L("Read them again", "Noch einmal lesen")) {
                            store.updateLesson { $0["step"] = 1; $0["checks"] = [:] }
                        }.buttonStyle(.ghost).padding(.top, 12)
                    }
                }
            }
        }
    }

    // MARK: 5 — say it

    @ViewBuilder func say(_ les: Lesson) -> some View {
        if let say = les.say {
            Block(top: 16) {
                SpeakDrill(question: store.pick(say.q), hint: store.pick(say.hint), model: store.pick(say.model), secs: say.secs ?? 90,
                           placeholder: store.L("No looking back at the lesson.", "Nicht in der Lektion nachsehen."),
                           text: Binding(get: { store.lesson["said"].string }, set: { v in store.updateLesson { $0["said"] = .string(v) } }),
                           coach: Binding(get: { store.lesson["coach"].stringValue }, set: { v in store.updateLesson { $0["coach"] = v.map(JSONValue.string) ?? nil } }),
                           previous: st["prevSaid"].array,
                           revealed: Binding(get: { store.lesson["revealed"].truthy }, set: { v in store.updateLesson { $0["revealed"] = .bool(v) } }),
                           onRetry: {
                               store.updateLesson { l in
                                   var p = l["prevSaid"].array
                                   p.append(["text": l["said"], "coach": l["coach"]])
                                   l["prevSaid"] = .array(Array(p.suffix(5))); l["said"] = ""; l["coach"] = nil
                               }
                           })
            }
            if st["revealed"].truthy {
                Block(rule: false) { Button(store.L("Finish", "Abschließen"), action: advance).buttonStyle(.solid) }
            }
        } else {
            Block(rule: false) { Button(store.L("Finish", "Abschließen"), action: advance).buttonStyle(.solid) }
        }
    }

    // MARK: 6 — done

    @ViewBuilder func done(_ les: Lesson) -> some View {
        VStack(spacing: 0) {
            Plate(id: les.plate, height: 110).padding(.top, 26)
            Heading(title).padding(.top, 10)
            Meta(store.L("Lesson complete", "Lektion abgeschlossen")).padding(.top, 10)
        }.frame(maxWidth: .infinity)
        Block {
            VStack(alignment: .leading, spacing: 8) {
                Meta(store.L("Answered correctly", "Richtig beantwortet") + ": \(store.lessonCorrect(st))/\(les.check.count)")
                Meta(store.L("Quotes saved to review", "Zitate in die Wiederholung") + ": \(les.christian.quotes.filter(store.isSaved).count + les.stoic.quotes.filter(store.isSaved).count)")
                Meta(store.L("Now at", "Jetzt auf") + ": " + store.masteryName(store.mastery(id)))
            }
        }
        Block(rule: false) {
            Button(store.L("Back to the path", "Zurück zum Weg")) {
                store.lessonFinish()
                router.popToRoot(); router.tab = .path
            }.buttonStyle(.solid)
            Button(store.L("Open the full topic", "Ganzes Thema öffnen")) { router.push(.concept(id)) }.buttonStyle(.ghost).padding(.top, 12)
            Button(store.L("Practise what you saved", "Gespeichertes üben")) { store.lessonFinish(); router.tab = .review }.buttonStyle(.outline).padding(.top, 12)
            Button(store.L("Do another lesson", "Weitere Lektion")) { router.push(.pickLesson) }.buttonStyle(.ghost).padding(.top, 12)
            Meta(store.L("Tomorrow brings a different topic. Nothing is lost if you miss a day.", "Morgen kommt ein anderes Thema. Nichts geht verloren, wenn du einen Tag auslässt.")).padding(.top, 20)
        }
    }
}

/// "Think it through": two readings, no right answer, a question for you.
struct ThinkBlock: View {
    @Environment(AppStore.self) private var store
    let think: Think
    @Binding var text: String
    @State private var speech = SpeechCapture()
    var body: some View {
        Block(top: 16) {
            Heading(store.L("Think it through", "Denk es durch"))
            Meta(store.L("No right answer here, and the app will not give you one.", "Hier gibt es keine richtige Antwort, und die App gibt dir keine.")).padding(.top, 12)
            Rubric(store.pick(think.t)).padding(.top, 18)
        }
        Band(kind: .agree) { Rubric(store.L("One way", "So")); Paragraphs(text: store.pick(think.a)) }
        Band(kind: .tension) { Rubric(store.L("The other way", "Anders")); Paragraphs(text: store.pick(think.b)) }
        Block {
            PassageText(store.pick(think.q), small: true).padding(.bottom, 14)
            SpeakField(text: $text, speech: speech, lang: store.lang, secs: 120,
                       placeholder: store.L("For you. Nobody grades this.", "Für dich. Das benotet niemand."), minHeight: 120)
        }
        .onDisappear { speech.stop() }
    }
}

/// "Ask for another angle": the reviewer adds one clarification inside a tradition.
struct AskBlock: View {
    @Environment(AppStore.self) private var store
    let topic: String
    let tradition: String
    let summary: String
    let points: [String]
    @State private var answer: String?
    @State private var failure: CoachError?
    @State private var pending = false

    var body: some View {
        Block {
            if let a = answer {
                Rail(label: store.L("One more angle", "Noch ein Blickwinkel")) { Paragraphs(text: a) }
            } else {
                Button {
                    Task {
                        pending = true
                        let r = await CoachClient().run(.explain(topic: topic, tradition: tradition, summary: summary, points: points), exerciseLang: store.lang)
                        pending = false
                        switch r { case .success(let t): withAnimation { answer = t }; case .failure(let e): failure = e }
                    }
                } label: {
                    HStack { if pending { ProgressView().tint(.ink) }; Text(store.L("Explain it another way", "Anders erklären")) }
                }
                .buttonStyle(.ghost).disabled(pending)
                if let f = failure { Meta(f.reason(store.lang), color: .burgundy).padding(.top, 10) }
            }
        }
    }
}

struct PickLessonView: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    var body: some View {
        Page {
            PageHead(title: store.L("Choose a topic", "Thema wählen"),
                     sub: store.L("Any lesson, any day. The path keeps its order; this is a detour, not a skip.",
                                  "Jede Lektion, jeden Tag. Der Weg behält seine Ordnung; das ist ein Umweg, kein Überspringen."))
            ForEach(store.corpus.lessonIDs, id: \.self) { id in
                Button {
                    store.openLesson(id)
                    router.pop()
                    Feedback.shared.play(.turn, muted: store.mute)
                } label: {
                    RowLink(title: store.conceptTitle(id), sub: store.masteryName(store.mastery(id))) {
                        if store.unitForLesson(id).map(store.unitDone) ?? false { Text("✓").foregroundStyle(Color.forest) }
                    }
                }.buttonStyle(.plain)
            }
        }
        .logosNavigation()
    }
}
