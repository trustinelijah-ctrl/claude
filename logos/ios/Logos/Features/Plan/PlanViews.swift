import SwiftUI

struct PlanView: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    let planId: String

    var body: some View {
        if let pl = store.corpus.plan(planId) {
            let st = store.planState(planId), rec = store.planRecord(planId)
            Page {
                VStack(spacing: 0) {
                    Plate(id: pl.plate, height: 110).padding(.top, 20)
                    Heading(store.pick(pl.title)).multilineTextAlignment(.center).padding(.top, 10)
                    if let b = pl.blurb { Meta(store.pick(b)).multilineTextAlignment(.center).padding(.top, 10) }
                }.frame(maxWidth: .infinity).padding(.bottom, 18)
                Block {
                    HStack { Rubric(store.L("Days done", "Tage erledigt")); Spacer(); Cite("\(st["doneDays"].int) / \(pl.days.count)") }.padding(.bottom, 10)
                    ProgressRule(fraction: pl.days.isEmpty ? 0 : Double(st["doneDays"].int) / Double(pl.days.count))
                    if rec.total > 0 {
                        Meta(store.L("Speaking tasks answered", "Sprechaufgaben beantwortet") + ": \(rec.spoken) / \(rec.total)" +
                             (rec.skipped > 0 ? " · \(rec.skipped) " + store.L("skipped", "übersprungen") : "")).padding(.top, 10)
                    }
                }
                ForEach(Array(pl.days.enumerated()), id: \.offset) { d, day in
                    let done = d < st["doneDays"].int
                    Button { router.push(.planDay(planId, d)) } label: {
                        HStack(alignment: .top, spacing: 14) {
                            Text(done ? "✓" : "\(d + 1)").font(Typo.counter).foregroundStyle(done ? Color.forest : Color.ink)
                                .frame(width: 32, height: 32).overlay(Circle().stroke(done ? Color.forest : Color.ink, lineWidth: 1))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(store.pick(day.title)).font(Typo.serif(18, .headline)).foregroundStyle(Color.ink).multilineTextAlignment(.leading)
                                if let a = day.aim { Meta(store.pick(a)) }
                                Meta(day.steps.map { stepLabel($0) }.joined(separator: " · "), color: .ink4)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 14)
                        .overlay(alignment: .bottom) { Rectangle().fill(Color.ruleSoft).frame(height: 1) }
                        .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
                Ornament()
            }
            .logosNavigation(store.pick(pl.title))
        }
    }

    func stepLabel(_ s: PlanStep) -> String { Self.stepLabel(s, store) }

    static func stepLabel(_ s: PlanStep, _ store: AppStore) -> String {
        ["read": store.L("Read", "Lesen"), "teach": store.L("Learn", "Lernen"), "quotes": store.L("Sources", "Quellen"),
         "planq": store.L("Check", "Prüfen"), "think": store.L("Think", "Denken"), "memorise": store.L("Memorise", "Auswendig"),
         "check": store.L("Check", "Prüfen"), "speak": store.L("Speak", "Sprechen"), "reflect": store.L("Reflect", "Nachdenken")][s.t] ?? ""
    }
}

/// One day of a track, step by step. Answers and speaking are kept per step
/// (planWork), so leaving and returning never loses work.
struct PlanDayView: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    let planId: String
    let day: Int
    @State private var step = 0
    @State private var answers: [Int: Int] = [:]
    @State private var finishedTrack = false

    var body: some View {
        if let pl = store.corpus.plan(planId), pl.days.indices.contains(day) {
            let d = pl.days[day]
            ScrollViewReader { proxy in
                Page {
                    Color.clear.frame(height: 0).id("top")
                    if step < d.steps.count {
                        StepRail(total: d.steps.count, current: step, label: PlanView.stepLabel(d.steps[step], store))
                        stepView(pl, d, d.steps[step]).id(step)
                            .transition(.opacity)
                        controls(pl, d)
                    } else {
                        dayDone(pl, d)
                    }
                }
                .onChange(of: step) { _, _ in withAnimation { proxy.scrollTo("top", anchor: .top) } }
                .animation(.easeOut(duration: 0.25), value: step)
            }
            .logosNavigation(store.L("Day", "Tag") + " \(day + 1) · " + store.pick(d.title))
            .onAppear { store.setPlanState(planId) { if $0["started"].isNull { $0["started"] = .number(store.nowMs) } } }
        }
    }

    func said(_ s: Int) -> Binding<String> {
        Binding(get: { store.planWork(planId, day: day, step: s)["text"].string },
                set: { v in store.setPlanWork(planId, day: day, step: s) { $0["text"] = .string(v); $0["ts"] = .number(store.nowMs) } })
    }

    @ViewBuilder func stepView(_ pl: Plan, _ d: PlanDay, _ s: PlanStep) -> some View {
        let firstRead = d.steps.firstIndex { $0.t == "read" } == step
        switch s.t {
        case "read":
            Block(top: 18) {
                Heading(store.pick(s.title), level: 2)
                Paragraphs(text: store.pick(s.body)).padding(.top, 16)
            }
            if firstRead, let blocks = store.corpus.planDepth["\(planId):\(day)"] {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, b in
                    Block { Heading(store.pick(b.h), level: 2); Paragraphs(text: store.pick(b.b)).padding(.top, 14) }
                }
            }
            if firstRead, let sw = store.corpus.saidWell["\(planId):\(day)"] {
                Block(rule: false) { Rubric(store.L("The same point, two ways", "Derselbe Punkt, zweimal")) }
                Band(kind: .tension) { Rubric(store.L("Said badly", "Schlecht gesagt")); PassageText(store.pick(sw.bad), small: true) }
                Band(kind: .agree) { Rubric(store.L("Said well", "Gut gesagt")); PassageText(store.pick(sw.well), small: true) }
                if let n = sw.note { Block { Meta(store.pick(n)) } }
            }
        case "teach":
            if let l = s.lesson, let les = store.corpus.lessons[l] {
                let christian = s.side == "christian"
                let side = christian ? les.christian : les.stoic
                let dep = christian ? store.corpus.depth[l]?.c : store.corpus.depth[l]?.s
                Block(top: 18) {
                    Heading(christian ? store.L("The Christian teaching", "Die christliche Lehre") : store.L("The Stoic teaching", "Die stoische Lehre"), level: 2)
                    PassageText(store.pick(side.summary), small: true).padding(.top, 14)
                }
                if let st = dep?.story { Rail(label: store.L("Where this comes from", "Woher das kommt")) { Paragraphs(text: store.pick(st)) } }
                Block { ForEach(Array(side.points.enumerated()), id: \.offset) { i, p in NumberedPoint(n: i + 1, text: store.pick(p)) } }
                if let lf = dep?.life { Rail(label: store.L("On an ordinary day", "An einem gewöhnlichen Tag")) { Paragraphs(text: store.pick(lf)) } }
            }
        case "quotes":
            Block(top: 18) {
                Rubric(store.L("In its own words", "In eigenen Worten"))
                Meta(store.L("Save what you want to keep. Saved lines are learned by heart, step by step.",
                             "Speichere, was du behalten willst. Gespeichertes wird Stufe für Stufe auswendig gelernt.")).padding(.top, 6).padding(.bottom, 16)
                ForEach(s.keys ?? [], id: \.self) { k in
                    QuoteCard(key: k, concept: s.concept, why: store.corpus.pqwhy["\(planId):\(day):\(k)"].map { store.pick($0) })
                }
            }
        case "memorise":
            if let k = s.key, let q = store.quote(k) {
                Block(top: 18) {
                    Heading(store.L("Learn this by heart", "Das auswendig lernen"), level: 2)
                    AnswerBox { PassageText(q.text, small: true); Cite(q.label) }.padding(.top, 16)
                    Button(store.L("Open the staircase", "Die Stufen öffnen")) {
                        store.saveQuote(k, concept: s.concept)
                        if let m = store.extras.first(where: { $0.qk == k }) { router.push(.memorise(m.id)) }
                    }.buttonStyle(.outline).padding(.top, 18)
                    Meta(store.L("Five steps, from the whole text to nothing but the reference.", "Fünf Stufen, vom ganzen Text bis zur bloßen Angabe.")).padding(.top, 10)
                }
            }
        case "think":
            if let th = s.key.flatMap({ store.corpus.planThink[$0] }) { ThinkBlock(think: th, text: said(step)) }
        case "planq", "check":
            let q: CheckQuestion? = s.t == "planq" ? s.key.flatMap { store.corpus.planQ[$0] }
                : s.lesson.flatMap { store.corpus.lessons[$0]?.check }.flatMap { c in s.i.flatMap { c.indices.contains($0) ? c[$0] : nil } }
            if let q {
                Block(top: 18) { CheckView(number: nil, q: q, given: answers[step]) { j in if answers[step] == nil { answers[step] = j } } }
            }
        case "speak":
            let sp: SayTask? = s.lesson.flatMap { store.corpus.lessons[$0]?.say }
                ?? s.q.map { SayTask(q: $0, hint: s.hint ?? LS("", ""), model: s.model ?? LS("", ""), secs: s.secs) }
            if let sp {
                let stepIndex = step
                let rec = store.planWork(planId, day: day, step: stepIndex)
                Block(top: 18) {
                    SpeakDrill(question: store.pick(sp.q), hint: store.pick(sp.hint), model: store.pick(sp.model), secs: s.secs ?? sp.secs ?? 60,
                               text: said(stepIndex),
                               coach: Binding(get: { store.planWork(planId, day: day, step: stepIndex)["coach"].stringValue },
                                              set: { v in store.setPlanWork(planId, day: day, step: stepIndex) { $0["coach"] = v.map(JSONValue.string) ?? nil; $0["coachTs"] = .number(store.nowMs) } }),
                               previous: rec["prev"].array,
                               revealed: Binding(get: { store.planWork(planId, day: day, step: stepIndex)["revealed"].truthy },
                                                 set: { v in store.setPlanWork(planId, day: day, step: stepIndex) { $0["revealed"] = .bool(v) } }),
                               onRetry: {
                                   store.setPlanWork(planId, day: day, step: stepIndex) { r in
                                       var p = r["prev"].array
                                       p.append(["text": r["text"], "coach": r["coach"], "ts": .number(store.nowMs)])
                                       r["prev"] = .array(Array(p.suffix(5))); r["text"] = ""; r["coach"] = nil
                                   }
                               })
                }
                if rec["skipped"].truthy && rec["text"].string.trimmingCharacters(in: .whitespaces).count < 15 {
                    AnswerBox { Meta(store.L("Marked skipped. It stays open — answering it later still counts.", "Als übersprungen markiert. Sie bleibt offen — sie später zu beantworten zählt weiterhin.")) }
                }
            }
        case "reflect":
            Block(top: 18) {
                PassageText(store.pick(s.q), small: true).padding(.bottom, 16)
                ReflectField(text: said(step))
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder func controls(_ pl: Plan, _ d: PlanDay) -> some View {
        let s = d.steps[step]
        let blocked = (s.t == "check" || s.t == "planq") && answers[step] == nil
        let speakEmpty = s.t == "speak" && said(step).wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).count < 15
        Block(rule: false) {
            if speakEmpty {
                Button(store.L("Skip this one for now", "Diese vorerst überspringen")) {
                    store.setPlanWork(planId, day: day, step: step) { $0["skipped"] = true; $0["ts"] = .number(store.nowMs) }
                    next(pl, d)
                }.buttonStyle(.ghost)
                Meta(store.L("It will be recorded as skipped rather than answered, and you can come back to it.",
                             "Sie wird als übersprungen statt beantwortet vermerkt, und du kannst zurückkommen.")).padding(.top, 10).padding(.bottom, 16)
            }
            Button(step == d.steps.count - 1 ? store.L("Finish the day", "Tag abschließen") : store.L("Continue", "Weiter")) { next(pl, d) }
                .buttonStyle(.solid).disabled(blocked)
            if step > 0 {
                Button(store.L("Back", "Zurück")) { step -= 1; Feedback.shared.play(.tap, muted: store.mute) }.buttonStyle(.ghost).padding(.top, 12)
            }
        }
    }

    func next(_ pl: Plan, _ d: PlanDay) {
        let s = d.steps[step]
        if (s.t == "speak" || s.t == "reflect"), let l = s.lesson, said(step).wrappedValue.trimmingCharacters(in: .whitespaces).count > 25 {
            store.noteEvidence(l, "spoke")
        }
        step += 1
        if step >= d.steps.count {
            finishedTrack = store.completePlanDay(planId, day: day)
            Feedback.shared.play(finishedTrack ? .done : .turn, muted: store.mute)
        } else {
            Feedback.shared.play(.turn, muted: store.mute)
        }
    }

    @ViewBuilder func dayDone(_ pl: Plan, _ d: PlanDay) -> some View {
        let last = day >= pl.days.count - 1
        VStack(spacing: 0) {
            Plate(id: pl.plate, height: last ? 130 : 100).padding(.top, 30)
            Heading(last ? store.pick(pl.title) : store.L("Day", "Tag") + " \(day + 1)").padding(.top, 12)
            Meta(last ? store.L("Track complete.", "Weg abgeschlossen.") : store.pick(d.title)).padding(.top, 10)
        }.frame(maxWidth: .infinity)
        if last {
            let rec = store.planRecord(planId)
            Block {
                PassageText(rec.spoken > 0 ? store.L("You have been through the whole track and answered its speaking tasks.", "Du hast den ganzen Weg durchlaufen und seine Sprechaufgaben beantwortet.")
                                       : store.L("You have read the whole track. Nothing here has yet tested whether you can say any of it.", "Du hast den ganzen Weg gelesen. Bisher hat nichts geprüft, ob du etwas davon sagen kannst."), small: true)
            }
            Block {
                AnswerBox {
                    Rubric(store.L("What this actually shows", "Was das tatsächlich zeigt"))
                    Meta(store.L("Read and worked through", "Gelesen und durchgearbeitet") + ": \(pl.days.count) / \(pl.days.count)")
                    Meta(store.L("Speaking tasks answered", "Sprechaufgaben beantwortet") + ": \(rec.spoken) / \(rec.total)" + (rec.skipped > 0 ? " · \(rec.skipped) " + store.L("skipped", "übersprungen") : ""))
                    if rec.spoken < rec.total {
                        Meta(store.L("Until those are answered, this is reading rather than demonstrated speaking.", "Solange die offen sind, ist das Lektüre und kein nachgewiesenes Sprechen."), color: .burgundy)
                    }
                }
            }
            Block(rule: false) { Button(store.L("Back to the track", "Zurück zum Weg")) { router.pop() }.buttonStyle(.solid) }
        } else {
            Block(rule: false) {
                Meta(store.L("Day", "Tag") + " \(day + 2) " + store.L("is open whenever you want it.", "steht offen, wann immer du willst."))
                Button(store.L("Straight on to day", "Direkt weiter zu Tag") + " \(day + 2)") {
                    router.pop(); router.push(.planDay(planId, day + 1))
                }.buttonStyle(.solid).padding(.top, 18)
                Button(store.L("Stop here for today", "Für heute hier aufhören")) { router.pop() }.buttonStyle(.ghost).padding(.top, 12)
            }
        }
        Ornament()
    }
}

/// A private writing field with the microphone, for reflections.
struct ReflectField: View {
    @Environment(AppStore.self) private var store
    @Binding var text: String
    var placeholder: String? = nil
    var minHeight: CGFloat = 130
    @State private var speech = SpeechCapture()
    var body: some View {
        SpeakField(text: $text, speech: speech, lang: store.lang, secs: 180,
                   placeholder: placeholder ?? store.L("For yourself. Nobody else reads this.", "Für dich. Das liest sonst niemand."), minHeight: minHeight)
            .onDisappear { speech.stop() }
    }
}
