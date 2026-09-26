import SwiftUI

struct LibraryView: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    enum Section: String, CaseIterable { case sources, concepts, voices, commonplace, arguments, search }
    @State private var section: Section = .sources
    @State private var query = ""
    @State private var filter = "all"

    func title(_ s: Section) -> String {
        switch s {
        case .sources: return store.L("Sources", "Quellen")
        case .concepts: return store.L("Concepts", "Begriffe")
        case .voices: return store.L("Voices", "Stimmen")
        case .commonplace: return store.L("Commonplace", "Notizbuch")
        case .arguments: return store.L("Arguments", "Argumente")
        case .search: return store.L("Search", "Suche")
        }
    }

    var body: some View {
        Page {
            PageHead(title: store.L("Library", "Bibliothek"), sub: store.L("Where every idea can be traced back to.", "Wohin sich jeder Gedanke zurückverfolgen lässt."))
            Flow { ForEach(Section.allCases, id: \.self) { s in Chip(title: title(s), on: section == s) { withAnimation(.snappy) { section = s } } } }
                .padding(.vertical, 18)
            switch section {
            case .sources: sources
            case .concepts: concepts
            case .voices: voices
            case .commonplace: commonplace
            case .arguments: arguments
            case .search: SearchPanel(query: $query)
            }
            Ornament()
        }
    }

    @ViewBuilder var sources: some View {
        ForEach(["scripture", "stoic", "christian", "own"], id: \.self) { cat in
            let items = store.corpus.sources.filter { $0.cat == cat }
            if !items.isEmpty {
                Block {
                    Rubric(store.pick(store.corpus.sourceCats[cat])).padding(.bottom, 6)
                    ForEach(items) { s in
                        Button { router.push(.source(s.id)) } label: {
                            RowLink(title: s.title, sub: [s.author, s.edition ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")) {
                                if let p = s.progress { Cite("\(Int(p))%") }
                            }
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder var concepts: some View {
        TextField(store.L("Find a concept", "Begriff suchen"), text: $query)
            .font(Typo.serif(17)).padding(12).overlay(Rectangle().stroke(Color.rule))
        Flow {
            Chip(title: store.L("All", "Alle"), on: filter == "all") { filter = "all" }
            Chip(title: store.L("Developed", "Ausgearbeitet"), on: filter == "developed") { filter = "developed" }
            Chip(title: store.L("Weakest", "Schwächste"), on: filter == "weak") { filter = "weak" }
        }.padding(.vertical, 14)
        let q = query.lowercased()
        let list = store.corpus.concepts.filter { c in
            (q.isEmpty || (store.pick(c.t) + " " + store.pick(c.overview)).lowercased().contains(q)) &&
            (filter != "developed" || !(c.christian?.isEmpty ?? true)) &&
            (filter != "weak" || store.mastery(c.id) <= 1)
        }
        if list.isEmpty { EmptyNote(title: store.L("No concept matches that.", "Kein Begriff passt dazu.")) }
        ForEach(list) { c in
            Button { router.push(.concept(c.id)) } label: {
                RowLink(title: store.pick(c.t), sub: String(store.pick(c.overview).prefix(120)) + "…") { MasteryNotches(level: store.mastery(c.id)) }
            }.buttonStyle(.plain)
        }
    }

    @ViewBuilder var voices: some View {
        ForEach(store.corpus.voices) { v in
            Button { router.push(.voice(v.id)) } label: { RowLink(title: v.name, sub: v.years + " — " + store.pick(v.hook)) }.buttonStyle(.plain)
        }
    }

    @ViewBuilder var commonplace: some View {
        Button(store.L("Write something down", "Etwas notieren")) { router.push(.capture(nil)) }.buttonStyle(.outline).padding(.bottom, 10)
        let caps = store.captures
        if caps.isEmpty { EmptyNote(title: store.L("Nothing written yet.", "Noch nichts notiert.")) }
        ForEach(Array(caps.enumerated()), id: \.offset) { _, c in
            Button { router.push(.capture(c["id"].string)) } label: {
                RowLink(title: c["title"].string.isEmpty ? String(c["body"].string.prefix(60)) : c["title"].string,
                        sub: [store.pick(store.corpus.kinds[c["kind"].string]), store.conceptTitle(c["concept"].stringValue),
                              c["example"].truthy ? store.L("example", "Beispiel") : (c["ts"].doubleValue.map(store.daysAgo) ?? "")]
                            .filter { !$0.isEmpty }.joined(separator: " · "), titleSize: 17)
            }.buttonStyle(.plain)
        }
    }

    @ViewBuilder var arguments: some View {
        ForEach(store.corpus.arguments) { a in
            Button { router.push(.argument(a.id)) } label: { RowLink(title: store.pick(a.question), sub: store.pick(a.thesis)) }.buttonStyle(.plain)
        }
    }
}

struct MasteryNotches: View {
    let level: Int
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<6, id: \.self) { i in Rectangle().fill(i <= level ? Color.bronze : Color.rule).frame(width: 5, height: 12) }
        }.accessibilityLabel("Mastery \(level) of 5")
    }
}

/// Searches Scripture, passages, concepts, notes, cards, prompts, arguments and the speech bank in both languages.
struct SearchPanel: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    @Binding var query: String

    var body: some View {
        TextField(store.L("Search everything, in both languages", "Alles durchsuchen, in beiden Sprachen"), text: $query)
            .font(Typo.serif(17)).padding(12).overlay(Rectangle().stroke(Color.rule)).submitLabel(.search)
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        if q.count < 2 {
            Meta(store.L("Search Scripture, passages, concepts, your notes, arguments and speaking prompts — in English and German at once.",
                         "Durchsuche Schrift, Stellen, Begriffe, deine Notizen, Argumente und Sprechaufgaben — auf Englisch und Deutsch zugleich.")).padding(.top, 14)
        } else {
            results(q)
        }
    }

    func hit(_ s: String?, _ q: String) -> Bool { (s ?? "").lowercased().contains(q) }
    func both(_ l: LS?) -> String { (l?.en ?? "") + " " + (l?.de ?? "") }

    @ViewBuilder func results(_ q: String) -> some View {
        let concepts = store.corpus.concepts.filter { c in
            hit(both(c.t) + both(c.overview) + both(c.christian) + both(c.stoic) + both(c.agree) + both(c.tension) + both(c.position)
                + (c.lines ?? []).map(both).joined(), q)
        }
        let scripture = store.corpus.scripture.filter { hit($0.value.en + $0.value.de + ($0.value.pen ?? "") + ($0.value.pde ?? "") + $0.value.ref, q) }.map(\.key).sorted()
        let passages = store.corpus.passages.filter { hit($0.value.en + $0.value.de + $0.value.author + ($0.value.ref ?? ""), q) }.map(\.key).sorted()
        let notes = store.captures.filter { hit($0["title"].string + " " + $0["body"].string, q) }
        let voices = store.corpus.voices.filter { hit($0.name + both($0.hook) + both($0.scene), q) }
        let args = store.corpus.arguments.filter { hit(both($0.question) + both($0.thesis), q) }
        let speech = store.corpus.speech.filter { hit($0.en + $0.de, q) }
        let n = concepts.count + scripture.count + passages.count + notes.count + voices.count + args.count + speech.count
        if n == 0 { EmptyNote(title: store.L("Nothing found.", "Nichts gefunden.")) }
        group(store.L("Concepts", "Begriffe"), concepts.count) {
            ForEach(concepts) { c in Button { router.push(.concept(c.id)) } label: { RowLink(title: store.pick(c.t), titleSize: 17) }.buttonStyle(.plain) }
        }
        group(store.L("Scripture", "Schrift"), scripture.count) {
            ForEach(scripture.prefix(30), id: \.self) { k in
                Button { router.push(.scripture(k)) } label: { RowLink(title: store.scriptureRef(k), sub: String(store.scriptureText(k).prefix(90)) + "…", titleSize: 17) }.buttonStyle(.plain)
            }
        }
        group(store.L("Stoic passages", "Stoische Stellen"), passages.count) {
            ForEach(passages.prefix(30), id: \.self) { k in QuoteCard(key: k) }
        }
        group(store.L("Voices", "Stimmen"), voices.count) {
            ForEach(voices) { v in Button { router.push(.voice(v.id)) } label: { RowLink(title: v.name, titleSize: 17) }.buttonStyle(.plain) }
        }
        group(store.L("My notes", "Meine Notizen"), notes.count) {
            ForEach(Array(notes.enumerated()), id: \.offset) { _, c in
                Button { router.push(.capture(c["id"].string)) } label: { RowLink(title: c["title"].string, sub: String(c["body"].string.prefix(90)), titleSize: 17) }.buttonStyle(.plain)
            }
        }
        group(store.L("Arguments", "Argumente"), args.count) {
            ForEach(args) { a in Button { router.push(.argument(a.id)) } label: { RowLink(title: store.pick(a.question), titleSize: 17) }.buttonStyle(.plain) }
        }
        group(store.L("Speech bank", "Formulierungen"), speech.count) {
            ForEach(speech) { s in VStack(alignment: .leading, spacing: 4) { Passage(store.lang == .de ? s.de : s.en, small: true); Meta(store.lang == .de ? s.en : s.de, color: .ink4) }.padding(.vertical, 8) }
        }
    }

    @ViewBuilder func group<C: View>(_ title: String, _ count: Int, @ViewBuilder _ content: () -> C) -> some View {
        if count > 0 { Block { Rubric(title + " · \(count)").padding(.bottom, 6); content() } }
    }
}

// MARK: - details

struct ConceptView: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    let conceptId: String
    enum Tab: String, CaseIterable { case study, sources, position, speak }
    @State private var tab: Tab = .study

    var body: some View {
        if let c = store.corpus.concept(conceptId) {
            Page {
                VStack(alignment: .leading, spacing: 8) {
                    if let g = c.gloss { Cite(g) }
                    HStack(alignment: .top) { Heading(store.pick(c.t), level: 0); Spacer(); LangSwitch() }
                    HStack(spacing: 10) { MasteryNotches(level: store.mastery(c.id)); Meta(store.masteryName(store.mastery(c.id))) }
                }.padding(.top, 12).padding(.bottom, 16)
                DoubleRule()
                Flow {
                    Chip(title: store.L("Study", "Studium"), on: tab == .study) { tab = .study }
                    Chip(title: store.L("Sources", "Quellen"), on: tab == .sources) { tab = .sources }
                    Chip(title: store.L("Position", "Position"), on: tab == .position) { tab = .position }
                    Chip(title: store.L("Speak", "Sprechen"), on: tab == .speak) { tab = .speak }
                }.padding(.vertical, 16)
                switch tab {
                case .study: study(c)
                case .sources: sources(c)
                case .position: position(c)
                case .speak: speak(c)
                }
                if let rel = c.related, !rel.isEmpty {
                    Block {
                        Rubric(store.L("Related", "Verwandt")).padding(.bottom, 12)
                        Flow { ForEach(rel.compactMap(store.corpus.concept)) { r in Chip(title: store.pick(r.t)) { router.push(.concept(r.id)) } } }
                    }
                }
                if store.corpus.lessons[c.id] != nil {
                    Block(rule: false) {
                        Button(store.L("Take this as today's lesson", "Als heutige Lektion nehmen")) {
                            store.openLesson(c.id); router.push(.lesson, on: .today)
                        }.buttonStyle(.outline)
                    }
                }
                Ornament()
            }
            .logosNavigation(store.pick(c.t))
        }
    }

    @ViewBuilder func section(_ label: String, _ text: LS?, kind: BandKind? = nil) -> some View {
        if let t = text, !t.isEmpty {
            if let kind { Band(kind: kind) { Rubric(label); Paragraphs(text: store.pick(t)) } }
            else { Block { Rubric(label).padding(.bottom, 10); Paragraphs(text: store.pick(t)) } }
        }
    }

    @ViewBuilder func study(_ c: Concept) -> some View {
        section(store.L("Overview", "Überblick"), c.overview)
        section(store.L("The Christian view", "Die christliche Sicht"), c.christian)
        section(store.L("The Stoic view", "Die stoische Sicht"), c.stoic)
        section(store.L("Where they agree", "Wo sie übereinstimmen"), c.agree, kind: .agree)
        section(store.L("Where they differ", "Wo sie sich unterscheiden"), c.tension, kind: .tension)
        if let lines = c.lines, !lines.isEmpty {
            Block {
                Rubric(store.L("Memorable lines", "Merksätze")).padding(.bottom, 10)
                ForEach(Array(lines.enumerated()), id: \.offset) { _, l in Passage(store.pick(l), small: true, italic: true).padding(.bottom, 10) }
            }
        }
        if let a = c.application, !a.isEmpty { Rail(label: store.L("Try this week", "Diese Woche")) { Paragraphs(text: store.pick(a)) } }
    }

    @ViewBuilder func sources(_ c: Concept) -> some View {
        Block {
            Rubric(store.L("Scripture", "Schrift")).padding(.bottom, 12)
            ForEach(c.scripture ?? [], id: \.self) { k in QuoteCard(key: k, concept: c.id) }
        }
        Block {
            Rubric(store.L("Stoic sources", "Stoische Quellen")).padding(.bottom, 12)
            ForEach(c.sources ?? [], id: \.self) { k in QuoteCard(key: k, concept: c.id) }
        }
    }

    @ViewBuilder func position(_ c: Concept) -> some View {
        section(store.L("My position", "Meine Position"), c.position)
        if let obs = c.objections, !obs.isEmpty {
            ForEach(Array(obs.enumerated()), id: \.offset) { i, o in
                Band(kind: .tension) { Rubric(store.L("Objection", "Einwand") + " \(i + 1)"); Passage(store.pick(o), small: true) }
                if let r = c.responses, r.indices.contains(i) {
                    Band(kind: .agree) { Rubric(store.L("Response", "Antwort")); Passage(store.pick(r[i]), small: true) }
                }
            }
        }
    }

    @ViewBuilder func speak(_ c: Concept) -> some View {
        section(store.L("In thirty seconds", "In dreißig Sekunden"), c.speak?.s30)
        section(store.L("In two minutes", "In zwei Minuten"), c.speak?.m2)
        section(store.L("In five minutes", "In fünf Minuten"), c.speak?.m5)
        Block(rule: false) {
            Button(store.L("Practise it in the studio", "Im Studio üben")) { store.lastConcept = c.id; router.push(.rhetoric, on: .practice) }.buttonStyle(.outline)
        }
    }
}

struct SourceView: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    let sourceId: String
    var body: some View {
        if let s = store.corpus.source(sourceId) {
            let passages = store.corpus.passages.filter { _, p in
                (s.id == "med" && p.author == "Marcus Aurelius") || (s.id == "ench" && p.author == "Epictetus") ||
                (s.id == "sen" && p.work == "Letters to Lucilius") || (s.id == "brev" && p.work == "On the Shortness of Life")
            }.map(\.key).sorted()
            let scriptureKeys = s.id == "bible" ? store.corpus.scripture.keys.sorted { store.scriptureRef($0).localizedStandardCompare(store.scriptureRef($1)) == .orderedAscending } : []
            Page {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) { Heading(s.title, level: 0); Spacer(); LangSwitch() }
                    Meta([s.author, s.edition ?? "", s.id == "bible" ? store.translationName : ""].filter { !$0.isEmpty }.joined(separator: " · "))
                }.padding(.top, 12).padding(.bottom, 16)
                DoubleRule()
                if let p = s.progress {
                    Block {
                        HStack { Rubric(store.L("Reading progress", "Lesefortschritt")); Spacer(); Cite("\(Int(p))%") }.padding(.bottom, 8)
                        ProgressRule(fraction: p / 100)
                    }
                }
                if let n = s.note { Rail(label: store.L("Note", "Notiz")) { Paragraphs(text: store.pick(n)) } }
                if !passages.isEmpty {
                    Block { Rubric(store.L("Passages held", "Gehaltene Stellen")).padding(.bottom, 14); ForEach(passages, id: \.self) { k in QuoteCard(key: k) } }
                }
                if !scriptureKeys.isEmpty {
                    Block {
                        Rubric(store.L("Passages held", "Gehaltene Stellen")).padding(.bottom, 8)
                        ForEach(scriptureKeys, id: \.self) { k in
                            Button { router.push(.scripture(k)) } label: {
                                RowLink(title: store.scriptureRef(k), sub: String(store.scriptureText(k).prefix(80)) + "…", titleSize: 16)
                            }.buttonStyle(.plain)
                        }
                    }
                }
                Ornament()
            }
            .logosNavigation(s.title)
        }
    }
}

struct ScriptureView: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    let key: String
    var body: some View {
        if let s = store.corpus.scripture[key] {
            let inConcepts = store.corpus.concepts.filter { ($0.scripture ?? []).contains(key) }
            Page {
                HStack(alignment: .top) { Heading(store.scriptureRef(key), level: 0); Spacer(); LangSwitch() }.padding(.top, 12).padding(.bottom, 16)
                DoubleRule()
                Block(top: 24) {
                    QuoteCard(key: key, concept: inConcepts.first?.id)
                    Cite(store.translationName)
                }
                if let ctx = s.ctx { Rail(label: store.L("In its setting", "Im Zusammenhang")) { Paragraphs(text: store.pick(ctx)) } }
                Block {
                    Rubric(store.translation == "plain" ? store.L("Classic wording", "Klassischer Wortlaut") : store.L("Plain wording", "Einfacher Wortlaut")).padding(.bottom, 8)
                    Passage(store.translation == "plain" ? (store.lang == .de ? s.de : s.en) : ((store.lang == .de ? s.pde : s.pen) ?? ""), small: true, color: .ink2)
                }
                if !inConcepts.isEmpty {
                    Block {
                        Rubric(store.L("Where it is used", "Wo es vorkommt")).padding(.bottom, 12)
                        Flow { ForEach(inConcepts) { c in Chip(title: store.pick(c.t)) { router.push(.concept(c.id)) } } }
                    }
                }
                Ornament()
            }
            .logosNavigation(store.scriptureRef(key))
        }
    }
}

struct ArgumentView: View {
    @Environment(AppStore.self) private var store
    let argumentId: String
    var body: some View {
        if let a = store.corpus.argument(argumentId) {
            Page {
                Heading(store.pick(a.question), level: 1).padding(.top, 12).padding(.bottom, 16)
                DoubleRule()
                Block { Rubric(store.L("Thesis", "These")).padding(.bottom, 8); Passage(store.pick(a.thesis)) }
                if let w = a.why { Block { Rubric(store.L("Why", "Warum")).padding(.bottom, 8); Paragraphs(text: store.pick(w)) } }
                if !(a.scripture.isEmpty && a.sources.isEmpty) {
                    Block { Rubric(store.L("Grounds", "Gründe")).padding(.bottom, 12); ForEach(a.scripture + a.sources, id: \.self) { k in QuoteCard(key: k, concept: a.concept) } }
                }
                if let o = a.objection { Band(kind: .tension) { Rubric(store.L("Objection", "Einwand")); Paragraphs(text: store.pick(o)) } }
                if let s = a.steelman { Band(kind: .tension) { Rubric(store.L("At its strongest", "In stärkster Form")); Paragraphs(text: store.pick(s)) } }
                if let r = a.response { Band(kind: .agree) { Rubric(store.L("Response", "Antwort")); Paragraphs(text: store.pick(r)) } }
                if let c = a.counter { Block { Rubric(store.L("Their counter", "Ihre Erwiderung")).padding(.bottom, 8); Paragraphs(text: store.pick(c)) } }
                if let l = a.limits { Rail(label: store.L("Limits", "Grenzen")) { Paragraphs(text: store.pick(l)) } }
                if let s = a.s30 { Block { Rubric(store.L("In thirty seconds", "In dreißig Sekunden")).padding(.bottom, 8); Passage(store.pick(s), small: true) } }
                if let l = a.line { Block(rule: false) { Passage(store.pick(l), italic: true) } }
                Ornament()
            }
            .logosNavigation()
        }
    }
}

struct CaptureEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    let captureId: String?
    @State private var kind = "thought"
    @State private var title = ""
    @State private var body_ = ""
    @State private var concept = ""
    @State private var tags = ""
    @State private var loaded = false
    @State private var speech = SpeechCapture()

    var body: some View {
        Page {
            PageHead(title: captureId == nil ? store.L("Write it down", "Notieren") : store.L("Note", "Notiz"), showLang: false)
            Block {
                Rubric(store.L("Kind", "Art")).padding(.bottom, 10)
                Flow { ForEach(store.corpus.kinds.keys.sorted(), id: \.self) { k in Chip(title: store.pick(store.corpus.kinds[k]), on: kind == k) { kind = k } } }
            }
            Block {
                TextField(store.L("Title", "Titel"), text: $title).font(Typo.h3).padding(.bottom, 14)
                SpeakField(text: $body_, speech: speech, lang: store.lang, secs: 300, placeholder: store.L("What struck you, and why.", "Was dich getroffen hat, und warum."), minHeight: 200)
                Rubric(store.L("Topic", "Thema")).padding(.top, 18).padding(.bottom, 6)
                Picker("", selection: $concept) {
                    Text("—").tag("")
                    ForEach(store.corpus.concepts) { c in Text(store.pick(c.t)).tag(c.id) }
                }.pickerStyle(.menu).tint(.ink)
                TextField(store.L("Tags, separated by commas", "Schlagworte, durch Kommas getrennt"), text: $tags).font(Typo.meta).padding(.top, 12)
            }
            Block(rule: false) {
                Button(store.L("Save", "Speichern")) {
                    store.saveCapture(id: captureId, kind: kind, title: title, body: body_, concept: concept.isEmpty ? nil : concept,
                                      tags: tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
                    Feedback.shared.play(.save, muted: store.mute)
                    router.pop()
                }.buttonStyle(.solid).disabled(body_.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && title.isEmpty)
                if let id = captureId {
                    Button(store.L("Delete", "Löschen"), role: .destructive) { store.deleteCapture(id); router.pop() }.buttonStyle(.ghost).padding(.top, 12)
                }
            }
        }
        .logosNavigation()
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let id = captureId, let c = store.captures.first(where: { $0["id"].string == id }) {
                kind = c["kind"].stringValue ?? "thought"; title = c["title"].string; body_ = c["body"].string
                concept = c["concept"].stringValue ?? ""; tags = c["tags"].array.map(\.string).joined(separator: ", ")
            } else { concept = store.lastConcept }
        }
        .onDisappear { speech.stop() }
    }
}
