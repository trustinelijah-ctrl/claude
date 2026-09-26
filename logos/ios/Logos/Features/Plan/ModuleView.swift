import SwiftUI

/// A "deep unit": teaching with sources, a worked example, faded practice
/// (rebuild the steps, last first), an independent answer and two transfers.
struct ModuleView: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    let moduleId: String
    @State private var step = 0
    @State private var sel: [String: Int] = [:]
    @State private var said: [String: String] = [:]
    @State private var revealed: Set<String> = []
    @State private var showSources = false

    enum Step: Hashable { case intro, teach, worked, faded(Int), independent, transfer(Int), done }

    func steps(_ m: Module) -> [Step] {
        var out: [Step] = [.intro, .teach, .worked]
        out += m.faded.indices.map { Step.faded($0) }
        out.append(.independent)
        out += m.transfer.indices.map { Step.transfer($0) }
        out.append(.done)
        return out
    }

    var body: some View {
        if let m = store.corpus.modules[moduleId] {
            let all = steps(m)
            ScrollViewReader { proxy in
                Page {
                    Color.clear.frame(height: 0).id("top")
                    StepRail(total: all.count, current: step, label: "\(step + 1) / \(all.count)")
                    content(m, all[min(step, all.count - 1)]).id(step).transition(.opacity)
                    Ornament()
                }
                .onChange(of: step) { _, _ in withAnimation { proxy.scrollTo("top", anchor: .top) } }
                .animation(.easeOut(duration: 0.25), value: step)
            }
            .logosNavigation(store.pick(m.title))
        }
    }

    var plateId: String { moduleId.contains("stoic") ? "control" : "providence" }

    func text(_ key: String) -> Binding<String> { Binding(get: { said[key] ?? "" }, set: { said[key] = $0 }) }

    @ViewBuilder func content(_ m: Module, _ s: Step) -> some View {
        switch s {
        case .intro:
            VStack(spacing: 0) {
                Plate(id: plateId, height: 118).padding(.top, 22)
                Heading(store.pick(m.title)).multilineTextAlignment(.center).padding(.top, 12)
                if let sub = m.sub { Meta(store.pick(sub)).multilineTextAlignment(.center).padding(.top, 10) }
            }.frame(maxWidth: .infinity)
            Block { PassageText(store.pick(m.teaching.hook), small: true) }
            nav(m, primary: store.L("Begin", "Beginnen"))
        case .teach:
            ForEach(Array(m.teaching.body.enumerated()), id: \.offset) { i, b in
                Block(top: i == 0 ? 16 : Metrics.block) { Heading(store.pick(b.h), level: 2); Paragraphs(text: store.pick(b.p)).padding(.top, 14) }
            }
            Block {
                LinkButton(title: showSources ? store.L("Hide sources", "Quellen ausblenden") : store.L("Sources", "Quellen")) { withAnimation { showSources.toggle() } }
                if showSources {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(m.claims.enumerated()), id: \.offset) { _, c in
                            if let u = c.url, let url = URL(string: u) { Link((c.cite ?? u) + " ↗", destination: url).font(Typo.meta).foregroundStyle(Color.bronze) }
                            else { Cite(c.cite ?? "") }
                        }
                    }.padding(.top, 14)
                }
            }
            nav(m, primary: store.L("Now put it to work", "Jetzt anwenden"))
        case .worked:
            Block(top: 18) {
                Heading(store.L("Worked example", "Durchgearbeitetes Beispiel"), level: 2)
                PassageText(store.pick(m.worked.question), small: true).padding(.top, 14)
                Meta(store.L("Read all four steps. You will build them yourself in a moment, last step first.",
                             "Lies alle vier Schritte. Gleich baust du sie selbst, den letzten zuerst.")).padding(.top, 12)
            }
            ForEach(Array(m.worked.steps.enumerated()), id: \.offset) { i, ws in
                Block {
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        Text("\(i + 1)").font(Typo.serifItalic(20)).foregroundStyle(Color.bronze)
                        VStack(alignment: .leading, spacing: 6) { Rubric(store.pick(ws.principle)); PassageText(store.pick(ws.text), small: true) }
                    }
                }
            }
            nav(m)
        case .faded(let fi):
            let f = m.faded[fi], keep = m.worked.steps.count - f.removed
            Block(top: 18) {
                Heading(store.L("Your turn", "Du bist dran"), level: 2)
                PassageText(store.pick(f.question), small: true).padding(.top, 14)
            }
            ForEach(Array(m.worked.steps.enumerated()), id: \.offset) { i, ws in
                Block {
                    if i < keep {
                        HStack(alignment: .firstTextBaseline, spacing: 14) {
                            Text("\(i + 1)").font(Typo.serifItalic(20)).foregroundStyle(Color.bronze)
                            VStack(alignment: .leading, spacing: 6) { Rubric(store.pick(ws.principle)); Meta(store.pick(ws.text)) }
                        }
                    } else {
                        let key = "\(fi)-\(i)"
                        Rubric(store.L("Step", "Schritt") + " \(i + 1) · " + store.L("Which principle belongs here?", "Welches Prinzip gehört hierher?")).padding(.bottom, 10)
                        ForEach(Array(ws.options.enumerated()), id: \.offset) { j, o in
                            OptionRow(text: store.pick(o), state: sel[key] == nil ? .idle : (j == ws.a ? .correct : (j == sel[key] ? .wrong : .dimmed))) {
                                sel[key] = j
                                Feedback.shared.play(j == ws.a ? .right : .wrong, muted: store.mute)
                            }
                        }
                        if sel[key] != nil {
                            Rubric(store.L("Now write that step in your own words", "Schreib diesen Schritt nun in eigenen Worten")).padding(.top, 12).padding(.bottom, 8)
                            ReflectField(text: text(key), placeholder: store.L("Say it aloud first.", "Sprich es zuerst laut."), minHeight: 90)
                            if revealed.contains(key) {
                                AnswerBox { Rubric(store.L("One way to put it", "Eine Art, es zu sagen")); Meta(store.pick(ws.text)) }.padding(.top, 10)
                            } else {
                                Button(store.L("Compare with a model", "Mit einem Muster vergleichen")) { revealed.insert(key) }.buttonStyle(.ghostSmall).padding(.top, 10)
                            }
                        }
                    }
                }
            }
            let blocked = (keep..<m.worked.steps.count).contains { sel["\(fi)-\($0)"] == nil }
            nav(m, blocked: blocked)
        case .independent:
            Block(top: 18) {
                Heading(store.L("On your own", "Allein"), level: 2)
                PassageText(store.pick(m.independent.q), small: true).padding(.top, 14)
            }
            Rail(label: store.L("Structure", "Aufbau")) { PassageText(store.pick(m.independent.hint), small: true, color: .ink2) }
            Block { ReflectField(text: text("ind"), placeholder: store.L("All four steps, in order.", "Alle vier Schritte, der Reihe nach."), minHeight: 180) }
            nav(m)
        case .transfer(let ti):
            let tr = m.transfer[ti], key = "tr\(ti)"
            Block(top: 18) {
                Rubric(tr.kind == "near" ? store.L("Near transfer", "Naher Transfer") : store.L("Far transfer", "Ferner Transfer")).padding(.bottom, 10)
                SpeakDrill(question: store.pick(tr.q), hint: store.pick(tr.hint), model: store.pick(tr.model), secs: 120,
                           placeholder: store.L("Same four moves.", "Dieselben vier Züge."), showQuestion: true,
                           text: text(key), coach: Binding(get: { said[key + ":coach"] }, set: { said[key + ":coach"] = $0 }),
                           revealed: Binding(get: { revealed.contains(key) }, set: { if $0 { revealed.insert(key) } else { revealed.remove(key) } }),
                           onRetry: { said[key] = ""; said[key + ":coach"] = nil })
            }
            nav(m)
        case .done:
            VStack(spacing: 0) {
                Plate(id: plateId, height: 104).padding(.top, 30)
                Heading(store.L("Done", "Fertig")).padding(.top, 12)
                Meta(store.L("You can now take this from both sides and say what your own position costs. That was the point.",
                             "Du kannst das jetzt von beiden Seiten führen und sagen, was deine eigene Position kostet. Darum ging es.")).multilineTextAlignment(.center).padding(.top, 12)
            }.frame(maxWidth: .infinity)
            Block(rule: false) {
                Button(store.L("Finish", "Abschließen")) {
                    store.markModuleDone(moduleId)
                    Feedback.shared.play(.done, muted: store.mute)
                    router.pop()
                }.buttonStyle(.solid)
            }
        }
    }

    @ViewBuilder func nav(_ m: Module, primary: String? = nil, blocked: Bool = false) -> some View {
        Block(rule: false) {
            Button(primary ?? store.L("Continue", "Weiter")) { step += 1; Feedback.shared.play(.turn, muted: store.mute) }
                .buttonStyle(.solid).disabled(blocked)
            if step > 0 { Button(store.L("Back", "Zurück")) { step -= 1 }.buttonStyle(.ghost).padding(.top, 12) }
        }
    }
}
