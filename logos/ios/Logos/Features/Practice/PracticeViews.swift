import SwiftUI

struct PracticeView: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        Page {
            PageHead(title: store.L("Practice", "Üben"), sub: store.L("Retrieval, then speech, then the day itself.", "Abruf, dann Sprache, dann der Tag selbst."))
            row(store.L("Memory", "Gedächtnis"), store.L("\(store.dueItems.count) due", "\(store.dueItems.count) fällig"),
                store.L("Spaced recall of everything you have saved.", "Verteilter Abruf von allem, was du gespeichert hast.")) { router.push(.memorySession) }
            row(store.L("Rhetoric Studio", "Rhetorik-Studio"), "\(store.doc["sessions"].array.count)",
                store.L("Answer under time, then read what you failed to retrieve.", "Antworte unter Zeitdruck, dann lies, was du nicht abrufen konntest.")) { router.push(.rhetoric) }
            let h = Calendar.current.component(.hour, from: store.now())
            row(h < 15 ? store.L("Morning intention", "Morgenvorsatz") : store.L("Evening examination", "Abendbetrachtung"), "",
                store.L("What was within my responsibility, and how did I answer it?", "Was lag in meiner Verantwortung, und wie habe ich geantwortet?")) { router.push(.reflect) }
            row(store.L("Speech bank", "Formulierungen"), "\(store.corpus.speech.count)",
                store.L("Formulations to internalise, in both languages.", "Formulierungen zum Verinnerlichen, in beiden Sprachen.")) { router.push(.speechBank) }
            row(store.L("Craft", "Handwerk"), "\(store.corpus.figures.count)",
                store.L("Figures of speech, taught from the texts you already know. Rewrite, say it, get coached.", "Redefiguren, gelehrt an Texten, die du schon kennst. Umschreiben, sprechen, Rückmeldung.")) { router.push(.craft) }
            row(store.L("Voices", "Stimmen"), "\(store.corpus.voices.count)",
                store.L("People who lived these questions: a scene, a line to keep, a move to use.", "Menschen, die diese Fragen gelebt haben: eine Szene, ein Satz, ein Zug.")) { router.push(.voices) }
            if store.lockedCount > 0 {
                Block { Meta("\(store.lockedCount) " + store.L("recalls are held back until you have learned their topic. Finish a lesson to release them.",
                                                              "Abrufe warten, bis du ihr Thema gelernt hast. Schließe eine Lektion ab, um sie freizugeben.")) }
            }
            Block(rule: false) {
                Button(store.L("Settings, backup and sync", "Einstellungen, Sicherung und Abgleich")) { router.push(.settings) }.buttonStyle(.ghost)
            }
            Ornament()
        }
    }

    func row(_ title: String, _ count: String, _ sub: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            RowLink(title: title, sub: sub, titleSize: 21) { if !count.isEmpty { Cite(count) } }
        }.buttonStyle(.plain)
    }
}

// MARK: - rhetoric studio

struct RhetoricView: View {
    @Environment(AppStore.self) private var store
    enum Stage { case config, prompt, review }
    @State private var stage: Stage = .config
    @State private var concept = ""
    @State private var lang: Lang = .en
    @State private var difficulty = "easy"
    @State private var prompt: RhetoricPrompt?
    @State private var answer = ""
    @State private var coach: String?
    @State private var prev: [JSONValue] = []
    @State private var showBetter = false
    @State private var left = 0
    @State private var timer: Timer?
    @State private var speech = SpeechCapture()

    var body: some View {
        Page {
            switch stage {
            case .config: config
            case .prompt: if let p = prompt { running(p) }
            case .review: if let p = prompt { review(p) }
            }
        }
        .logosNavigation(store.L("Rhetoric Studio", "Rhetorik-Studio"))
        .onAppear {
            if concept.isEmpty {
                concept = store.doc["lastConcept"].stringValue ?? "control"
                lang = store.lang
                let lv = store.mastery(concept)
                difficulty = lv >= 4 ? "expert" : lv >= 3 ? "hard" : lv >= 2 ? "moderate" : "easy"
            }
        }
        .onDisappear { timer?.invalidate(); speech.stop() }
    }

    var matching: [RhetoricPrompt] { store.corpus.rhetoric.filter { $0.concept == concept && $0.lang == lang.rawValue && $0.difficulty == difficulty } }
    var near: [RhetoricPrompt] { store.corpus.rhetoric.filter { $0.concept == concept && $0.lang == lang.rawValue && $0.difficulty != difficulty } }
    var other: [RhetoricPrompt] { store.corpus.rhetoric.filter { $0.concept == concept && $0.lang != lang.rawValue } }

    @ViewBuilder var config: some View {
        PageHead(title: store.L("Rhetoric Studio", "Rhetorik-Studio"), sub: store.L("Configure the room, then speak into it.", "Richte den Raum ein, dann sprich hinein."), showLang: false)
        Block {
            Rubric(store.L("Topic", "Thema")).padding(.bottom, 8)
            Picker("", selection: $concept) {
                ForEach(store.corpus.concepts.filter { c in store.corpus.rhetoric.contains { $0.concept == c.id } }) { c in Text(store.pick(c.t)).tag(c.id) }
            }.pickerStyle(.menu).tint(.ink)
        }
        Block {
            Rubric(store.L("Language", "Sprache")).padding(.bottom, 10)
            Flow { ForEach(Lang.allCases) { l in Chip(title: l == .en ? store.L("English", "Englisch") : store.L("German", "Deutsch"), on: lang == l) { lang = l } } }
        }
        Block {
            Rubric(store.L("Difficulty", "Schwierigkeit")).padding(.bottom, 10)
            Flow { ForEach(["easy", "moderate", "hard", "expert"], id: \.self) { d in Chip(title: store.pick(store.corpus.diff[d]), on: difficulty == d) { difficulty = d } } }
        }
        if matching.isEmpty {
            Block {
                Heading(store.L("Not covered yet", "Noch nicht abgedeckt"), level: 2)
                Meta(store.L("There is no task for that exact combination, and substituting a different topic or a harder one would teach you the wrong thing about your own progress.",
                             "Für genau diese Kombination gibt es keine Aufgabe, und ein anderes Thema oder eine schwerere Stufe unterzuschieben würde dir ein falsches Bild von deinem Fortschritt geben.")).padding(.top, 10)
                if !near.isEmpty {
                    Rubric(store.L("Same topic and language, different level", "Gleiches Thema und gleiche Sprache, andere Stufe")).padding(.top, 18)
                    ForEach(near) { r in promptRow(r, store.pick(store.corpus.diff[r.difficulty])) }
                }
                if !other.isEmpty {
                    Rubric(store.L("Same topic, other language", "Gleiches Thema, andere Sprache")).padding(.top, 18)
                    ForEach(other) { r in promptRow(r, (r.lang == "de" ? store.L("German", "Deutsch") : store.L("English", "Englisch")) + " · " + store.pick(store.corpus.diff[r.difficulty])) }
                }
            }
        } else {
            Block(rule: false) {
                Button(store.L("Enter the room", "Den Raum betreten")) { begin(matching.randomElement()!) }.buttonStyle(.solid)
                Meta("\(matching.count) " + store.L("prompts for this room.", "Aufgaben für diesen Raum.")).padding(.top, 10)
            }
        }
    }

    func promptRow(_ r: RhetoricPrompt, _ title: String) -> some View {
        Button { begin(r) } label: { RowLink(title: title, sub: String(r.q.prefix(110)) + "…", titleSize: 17) { Cite("\(r.secs)s") } }.buttonStyle(.plain)
    }

    func begin(_ p: RhetoricPrompt) {
        prompt = p; answer = ""; coach = nil; prev = []; showBetter = false
        stage = .prompt
        store.lastConcept = p.concept
        startClock(p.secs)
        Feedback.shared.play(.turn, muted: store.mute)
    }

    func startClock(_ secs: Int) {
        left = secs
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in if left > 0 { left -= 1 } else { timer?.invalidate() } }
        }
    }

    func quoteMarks(_ p: RhetoricPrompt, _ s: String) -> String { p.lang == "de" ? "»" + s + "«" : "“" + s + "”" }

    @ViewBuilder func running(_ p: RhetoricPrompt) -> some View {
        HStack {
            Rubric(store.pick(store.corpus.who[p.who]) + " · " + store.pick(store.corpus.diff[p.difficulty]))
            Spacer()
            Text(String(format: "%d:%02d", left / 60, left % 60)).font(Typo.counter).foregroundStyle(left <= 10 ? Color.burgundy : Color.ink)
                .contentTransition(.numericText(countsDown: true))
        }.padding(.top, 16)
        ProgressRule(fraction: p.secs > 0 ? Double(left) / Double(p.secs) : 0).padding(.top, 10)
        Block(top: 30) { PassageText(quoteMarks(p, p.q)) }
        if !prev.isEmpty { AttemptsView(previous: prev) }
        Block(rule: false) {
            Rubric(store.L("Your answer", "Deine Antwort")).padding(.bottom, 10)
            SpeakField(text: $answer, speech: speech, lang: Lang(rawValue: p.lang) ?? .en, secs: p.secs,
                       placeholder: store.L("Speak. The words land here.", "Sprich. Die Worte landen hier."))
            Button(store.L("Review my answer", "Antwort ansehen")) {
                speech.stop(); timer?.invalidate()
                store.logRhetoric(promptId: p.id, answer: answer, secs: p.secs - left, lang: p.lang, concept: p.concept, difficulty: p.difficulty)
                stage = .review
                Feedback.shared.play(.turn, muted: store.mute)
            }.buttonStyle(.solid).padding(.top, 18)
        }
    }

    @ViewBuilder func review(_ p: RhetoricPrompt) -> some View {
        Block(top: 18) {
            Rubric(store.L("The question", "Die Frage")).padding(.bottom, 8)
            PassageText(quoteMarks(p, p.q), small: true, color: .ink2)
            Rubric(store.L("What you said", "Was du gesagt hast")).padding(.top, 18).padding(.bottom, 8)
            PassageText(answer.isEmpty ? store.L("Nothing written.", "Nichts geschrieben.") : answer, small: true)
        }
        Rail(label: store.L("What a strong answer needs", "Was eine starke Antwort braucht")) { PassageText(p.structure, small: true, color: .ink2) }
        Block {
            SpeakDrill(question: p.q, hint: p.structure, model: p.better, secs: p.secs, exerciseLang: Lang(rawValue: p.lang),
                       showQuestion: false, text: $answer, coach: $coach, previous: [], revealed: $showBetter,
                       onRetry: {
                           prev.append(["text": .string(answer), "coach": coach.map(JSONValue.string) ?? nil])
                           answer = ""; coach = nil; showBetter = false; stage = .prompt
                           startClock(p.secs)
                       })
        }
        if !p.sources.isEmpty {
            Block {
                Rubric(store.L("What you could have used", "Was du hättest nutzen können")).padding(.bottom, 12)
                ForEach(p.sources, id: \.self) { k in QuoteCard(key: k, concept: p.concept) }
            }
        }
        if let f = store.corpus.followUps[p.id] {
            Block {
                Rubric(store.L("They come back with", "Die Gegenseite legt nach")).padding(.bottom, 8)
                PassageText(quoteMarks(p, store.pick(f.q)), small: true, color: .burgundy)
                Meta(store.pick(f.hint)).padding(.top, 10)
            }
        }
        Block(rule: false) {
            Button(store.L("Another prompt", "Andere Aufgabe")) { stage = .config }.buttonStyle(.outline)
        }
    }
}

// MARK: - reflect

struct ReflectView: View {
    @Environment(AppStore.self) private var store
    @State private var evening = Calendar.current.component(.hour, from: Date()) >= 15

    var body: some View {
        let r = store.reflection()
        Page {
            PageHead(title: evening ? store.L("Evening examination", "Abendbetrachtung") : store.L("Morning intention", "Morgenvorsatz"),
                     sub: evening ? store.L("Seneca did this nightly, and Ignatius taught its Christian form. Seven questions; answer the ones that bite.",
                                            "Seneca tat das jeden Abend, Ignatius lehrte die christliche Form. Sieben Fragen; beantworte die, die treffen.")
                                  : store.L("One sentence on what today asks of you, before it starts asking.", "Ein Satz darüber, was der Tag von dir verlangt, bevor er zu verlangen beginnt."))
            Block {
                Flow {
                    Chip(title: store.L("Morning", "Morgen"), on: !evening) { evening = false }
                    Chip(title: store.L("Evening", "Abend"), on: evening) { evening = true }
                }
            }
            if !evening {
                Block {
                    PassageText(store.L("What is within my responsibility today, and how will I answer it?", "Was liegt heute in meiner Verantwortung, und wie will ich antworten?"), small: true).padding(.bottom, 14)
                    ReflectField(text: Binding(get: { store.reflection()["morning"].string },
                                               set: { v in store.setReflection { $0["morning"] = .string(v) } }))
                }
            } else {
                ForEach(Array(store.corpus.eveningQ.enumerated()), id: \.offset) { i, q in
                    Block {
                        PassageText("\(i + 1). " + store.pick(q), small: true).padding(.bottom, 10)
                        TextField(store.L("A line is enough.", "Eine Zeile genügt."), text: Binding(
                            get: { store.reflection()["evening"][i].string },
                            set: { v in store.setReflection { r in
                                var arr = r["evening"].array
                                while arr.count <= i { arr.append("") }
                                arr[i] = .string(v); r["evening"] = .array(arr)
                            } }), axis: .vertical)
                            .font(Typo.serif(17)).padding(12).background(Color.vellum2.opacity(0.6)).overlay(Rectangle().stroke(Color.rule))
                    }
                }
            }
            let past = store.doc["reflections"].array.filter { $0["date"].string != store.todayKey }.prefix(7)
            if !past.isEmpty {
                Block {
                    Rubric(store.L("Earlier days", "Frühere Tage")).padding(.bottom, 8)
                    ForEach(Array(past.enumerated()), id: \.offset) { _, p in
                        VStack(alignment: .leading, spacing: 4) {
                            Cite(p["date"].string)
                            if !p["morning"].string.isEmpty { Meta(p["morning"].string) }
                            let ev = p["evening"].array.map(\.string).filter { !$0.isEmpty }
                            if !ev.isEmpty { Meta(ev.joined(separator: " · "), color: .ink2) }
                        }.padding(.vertical, 8)
                    }
                }
            }
            Ornament()
        }
        .logosNavigation()
        .onAppear { _ = r }
    }
}

// MARK: - speech bank

struct SpeechBankView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        Page {
            PageHead(title: store.L("Speech bank", "Formulierungen"),
                     sub: store.L("Formulations to internalise, in both languages. Say them until they come without reaching.",
                                  "Formulierungen zum Verinnerlichen, in beiden Sprachen. Sprich sie, bis sie ohne Suchen kommen."))
            let cats = Array(Set(store.corpus.speech.map(\.cat)))
            ForEach(store.corpus.speechCats.keys.sorted().filter { cats.contains($0) }, id: \.self) { cat in
                Block {
                    Rubric(store.pick(store.corpus.speechCats[cat])).padding(.bottom, 10)
                    ForEach(store.corpus.speech.filter { $0.cat == cat }) { s in
                        VStack(alignment: .leading, spacing: 6) {
                            PassageText(store.lang == .de ? s.de : s.en, small: true)
                            Meta(store.lang == .de ? s.en : s.de, color: .ink4)
                        }.padding(.vertical, 10)
                    }
                }
            }
            Ornament()
        }
        .logosNavigation()
    }
}

// MARK: - voices

struct VoicesView: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    var body: some View {
        Page {
            PageHead(title: store.L("Voices", "Stimmen"),
                     sub: store.L("People who lived these questions: a scene, a line to keep, a move to use.",
                                  "Menschen, die diese Fragen gelebt haben: eine Szene, ein Satz, ein Zug."))
            ForEach(store.corpus.voices) { v in
                Button { router.push(.voice(v.id)) } label: {
                    RowLink(title: v.name, sub: v.years + " · " + (v.trad == "stoic" ? store.L("Stoic", "Stoisch") : store.L("Christian", "Christlich")) + "\n" + store.pick(v.hook)) {
                        if store.work("voiceWork", v.id)["seen"].truthy { Image(systemName: "checkmark").font(.caption).foregroundStyle(Color.forest) }
                    }
                }.buttonStyle(.plain)
            }
            Ornament()
        }
        .logosNavigation()
    }
}

struct VoiceView: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    let voiceId: String

    var body: some View {
        if let v = store.corpus.voice(voiceId) {
            Page {
                VStack(alignment: .leading, spacing: 6) {
                    Cite(v.years + " · " + (v.trad == "stoic" ? store.L("Stoic", "Stoisch") : store.L("Christian", "Christlich")))
                    HStack(alignment: .top) { Heading(v.name, level: 0); Spacer(); LangSwitch() }
                    Meta(store.pick(v.place))
                }.padding(.top, 12).padding(.bottom, 18)
                DoubleRule()
                Block { PassageText(store.pick(v.hook), italic: true) }
                Block { Rubric(store.L("The scene", "Die Szene")).padding(.bottom, 12); Paragraphs(text: store.pick(v.scene)) }
                Block { VoiceQuote(voice: v) }
                Rail(label: store.L("When to reach for this", "Wann du dazu greifst")) { Paragraphs(text: store.pick(v.use)) }
                Band(kind: .tension) { Rubric(store.L("Where it breaks", "Wo es bricht")); Paragraphs(text: store.pick(v.limit)) }
                Block(top: 18) {
                    HStack(alignment: .firstTextBaseline) { Heading(store.L("Use it", "Setz es ein"), level: 2); Spacer(); Cite("\(v.drill.secs ?? 60)s") }.padding(.bottom, 12)
                    PassageText(store.pick(v.drill.q), small: true)
                    SpeakDrill(question: store.pick(v.drill.q), hint: store.pick(v.drill.hint), model: store.pick(v.drill.model), secs: v.drill.secs ?? 60,
                               showQuestion: false,
                               text: store.workText("voiceWork", v.id), coach: store.workCoach("voiceWork", v.id),
                               previous: store.work("voiceWork", v.id)["prev"].array, revealed: store.workRevealed("voiceWork", v.id),
                               onRetry: { store.workRetry("voiceWork", v.id) })
                }
                if let cs = v.concepts, !cs.isEmpty {
                    Block {
                        Rubric(store.L("Connects to", "Verbunden mit")).padding(.bottom, 12)
                        Flow { ForEach(cs.compactMap(store.corpus.concept)) { c in Chip(title: store.pick(c.t)) { router.push(.concept(c.id)) } } }
                    }
                }
                if let i = store.corpus.voices.firstIndex(where: { $0.id == v.id }) {
                    let nx = store.corpus.voices[(i + 1) % store.corpus.voices.count]
                    Block(rule: false) { Button(store.L("Next voice", "Nächste Stimme") + ": " + nx.name) { router.pop(); router.push(.voice(nx.id)) }.buttonStyle(.outline) }
                }
                if let check = v.check {
                    DisclosureGroup { Meta(check).padding(.top, 8) } label: { Meta(store.L("How this was checked", "Wie das geprüft wurde")) }.tint(.ink3)
                }
                Ornament()
            }
            .logosNavigation(v.name)
            .onAppear { store.markSeen("voiceWork", v.id) }
        }
    }
}

struct VoiceQuote: View {
    @Environment(AppStore.self) private var store
    let voice: Voice
    var body: some View {
        let q = voice.quote, kind = q.kind ?? "pd"
        let parts: (main: String, note: String, under: String) = {
            if kind == "none" { return (store.pick(q.para), store.pick(store.corpus.voiceKind["none"]), "") }
            if store.lang == .de {
                if q.deKind == "orig" { return (q.de ?? "", kind == "own" ? "Originalwortlaut." : store.pick(store.corpus.voiceKind[kind]), "") }
                if q.deKind == "own" { return (q.de ?? "", store.pick(store.corpus.voiceKind["own"]), q.orig ?? "") }
                return (q.de ?? "", store.pick(store.corpus.voiceKind["paraphraseDe"]), (q.en ?? "") + ((q.orig ?? "").isEmpty ? "" : "  ·  " + (q.orig ?? "")))
            }
            return (q.en ?? "", store.pick(store.corpus.voiceKind[kind]), q.orig ?? "")
        }()
        VStack(alignment: .leading, spacing: 12) {
            PassageText((store.lang == .de ? "»" : "“") + parts.main + (store.lang == .de ? "«" : "”"), italic: true)
            if !parts.under.isEmpty { Text(parts.under).font(Typo.serifItalic(15)).foregroundStyle(Color.ink3) }
            HStack(spacing: 6) { Text(voice.name).font(Typo.meta).foregroundStyle(Color.ink2); Cite("· " + (q.src ?? "")) }
            if !parts.note.isEmpty { Meta(parts.note) }
            if kind != "none" {
                let on = store.isSaved("voice:" + voice.id)
                Chip(title: on ? "✓ " + store.L("In review", "In Wiederholung") : store.L("Learn it by heart", "Auswendig lernen"), on: on) {
                    if store.saveVoiceQuote(voice) { Feedback.shared.play(.save, muted: store.mute) }
                }.disabled(on)
            }
            if let also = q.also {
                Divider().overlay(Color.ruleSoft)
                PassageText("“" + ((store.lang == .de ? also.orig : nil) ?? also.en ?? "") + "”", small: true)
                Cite(also.src ?? "")
            }
        }
        .padding(18).background(Color.vellum2.opacity(0.55)).overlay(Rectangle().stroke(Color.ruleSoft))
    }
}

// MARK: - craft

struct CraftView: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    var body: some View {
        Page {
            PageHead(title: store.L("Craft", "Handwerk"),
                     sub: store.L("Figures of speech, taught from the texts you already know. Rewrite, say it, get coached.",
                                  "Redefiguren, gelehrt an Texten, die du schon kennst. Umschreiben, sprechen, Rückmeldung."))
            ForEach(store.corpus.figures) { f in
                Button { router.push(.figure(f.id)) } label: {
                    RowLink(title: store.pick(f.n), sub: f.term + "\n" + store.pick(f.def)) {
                        if store.work("craftWork", f.id)["seen"].truthy { Image(systemName: "checkmark").font(.caption).foregroundStyle(Color.forest) }
                    }
                }.buttonStyle(.plain)
            }
            Ornament()
        }
        .logosNavigation()
    }
}

struct FigureView: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    let figureId: String

    var body: some View {
        if let f = store.corpus.figure(figureId) {
            Page {
                VStack(alignment: .leading, spacing: 6) {
                    Cite(f.term)
                    HStack(alignment: .top) { Heading(store.pick(f.n), level: 0); Spacer(); LangSwitch() }
                }.padding(.top, 12).padding(.bottom, 18)
                DoubleRule()
                Block { PassageText(store.pick(f.def), italic: true) }
                Block {
                    Rubric(store.L("In the texts you already know", "In Texten, die du schon kennst")).padding(.bottom, 12)
                    ForEach(Array(f.specimens.enumerated()), id: \.offset) { _, sp in specimen(sp) }
                }
                Rail(label: store.L("Why it works", "Warum es wirkt")) { Paragraphs(text: store.pick(f.why)) }
                if let g = f.german { Rail(label: store.L("In German", "Im Deutschen")) { PassageText(store.pick(g), small: true) } }
                Block(top: 18) {
                    Heading(store.L("Rewrite it", "Schreib es um"), level: 2)
                    Meta(store.L("A flat sentence. Rewrite it using this figure, then say it aloud.", "Ein flacher Satz. Schreib ihn mit dieser Figur um und sprich ihn dann laut.")).padding(.top, 10)
                    Band { PassageText(store.pick(f.flat), small: true) }
                    SpeakDrill(question: store.pick(f.flat), hint: store.pick(f.def), model: store.pick(f.model), secs: 20,
                               placeholder: store.L("Your version.", "Deine Fassung."), minChars: 8, showQuestion: false,
                               text: store.workText("craftWork", f.id), coach: store.workCoach("craftWork", f.id),
                               previous: store.work("craftWork", f.id)["prev"].array, revealed: store.workRevealed("craftWork", f.id),
                               onRetry: { store.workRetry("craftWork", f.id) },
                               task: { .craft(figure: store.pick(f.n) + " (" + f.term + ")", def: store.pick(f.def), flat: store.pick(f.flat), answer: $0) })
                }
                if let i = store.corpus.figures.firstIndex(where: { $0.id == f.id }) {
                    let nx = store.corpus.figures[(i + 1) % store.corpus.figures.count]
                    Block(rule: false) { Button(store.L("Next figure", "Nächste Figur") + ": " + store.pick(nx.n)) { router.pop(); router.push(.figure(nx.id)) }.buttonStyle(.outline) }
                }
                Ornament()
            }
            .logosNavigation(store.pick(f.n))
            .onAppear { store.markSeen("craftWork", f.id) }
        }
    }

    @ViewBuilder func specimen(_ sp: Figure.Specimen) -> some View {
        if let vid = sp.voice, let v = store.corpus.voice(vid) {
            VStack(alignment: .leading, spacing: 8) {
                Text(v.name).font(Typo.serif(18)).foregroundStyle(Color.ink)
                Meta(store.pick(sp.note))
                LinkButton(title: store.L("Read the scene", "Die Szene lesen")) { router.push(.voice(v.id)) }
            }.padding(16).overlay(Rectangle().stroke(Color.ruleSoft)).padding(.bottom, 12)
        } else if let k = sp.k, let q = store.quote(k) {
            VStack(alignment: .leading, spacing: 8) {
                PassageText("“" + q.text + "”", small: true)
                Cite(q.label)
                Meta(store.pick(sp.note))
            }.padding(16).overlay(Rectangle().stroke(Color.ruleSoft)).padding(.bottom, 12)
        }
    }
}
