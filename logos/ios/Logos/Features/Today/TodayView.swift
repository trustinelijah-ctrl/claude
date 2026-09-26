import SwiftUI

extension AppStore {
    var longDate: String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: now())
        let en = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
        let de = ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"]
        let m = c.month! - 1
        return lang == .de ? "\(c.day!). \(de[m]) \(c.year!)" : "\(en[m]) \(c.day!), \(c.year!)"
    }
    var greeting: String {
        let h = Calendar.current.component(.hour, from: now())
        if h < 5 { return L("Still awake.", "Noch wach.") }
        if h < 12 { return L("Good morning.", "Guten Morgen.") }
        if h < 18 { return L("Good afternoon.", "Guten Tag.") }
        return L("Good evening.", "Guten Abend.")
    }
    func daysAgo(_ ts: Double) -> String {
        let d = Int(((nowMs - ts) / Self.day).rounded())
        if d <= 0 { return L("today", "heute") }
        if d == 1 { return L("yesterday", "gestern") }
        if d < 30 { return L("\(d) days ago", "vor \(d) Tagen") }
        let m = Int((Double(d) / 30).rounded())
        return L("\(m) months ago", "vor \(m) Monaten")
    }
}

/// Opens a path unit on the right surface, as the web's "unit" action does.
@MainActor
func openUnit(_ u: PathUnit, store: AppStore, router: Router) {
    switch u.kind {
    case "plan": router.push(.plan(u.ref))
    case "module": router.push(.module(u.ref))
    default:
        store.openLesson(u.ref)
        router.push(.lesson)
    }
    Feedback.shared.play(.turn, muted: store.mute)
}

struct Masthead: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("LOGOS").font(.system(size: 15, weight: .semibold)).tracking(6).foregroundStyle(Color.ink)
                    Meta(store.longDate)
                }
                Spacer()
                LangSwitch()
                Button { router.push(.settings) } label: {
                    Image(systemName: "gearshape").font(.system(size: 17)).foregroundStyle(Color.ink2)
                        .frame(width: 44, height: 38).overlay(Rectangle().stroke(Color.rule, lineWidth: 1))
                }
                .buttonStyle(.plain).accessibilityLabel(store.L("Settings", "Einstellungen"))
            }
            .padding(.top, 14).padding(.bottom, 18)
            DoubleRule()
        }
    }
}

struct TodayView: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        Page {
            Masthead()
            Heading(store.greeting, level: 0).padding(.top, 26).padding(.bottom, 8)

            let cur = store.doc["lessons"][store.todayKey]
            if cur["opened"].truthy && !cur["done"].truthy, let les = store.corpus.concept(cur["id"].string) {
                Block {
                    Rubric(store.L("Today's lesson, in progress", "Lektion von heute, begonnen"), color: .bronze)
                    Heading(store.pick(les.t), level: 2).padding(.top, 10)
                    StepRail(total: 6, current: max(0, cur["step"].int - 1)).padding(.top, 4)
                    Button(store.L("Resume", "Weitermachen")) { router.push(.lesson) }.buttonStyle(.solid)
                }
            }

            LeafBlock()
            ContinuityBlock()
            pathBlock
            memoryBlock
            Ornament()
        }
    }

    @ViewBuilder var pathBlock: some View {
        let st = store.pathStats
        if let nx = store.pathNext {
            Block {
                Rubric(store.L("Stage", "Stufe") + " \(nx.stage.stage) · " + store.pick(nx.stage.name) + " · \(st.done)/\(st.total)")
                ProgressRule(fraction: Double(st.pct) / 100).padding(.top, 10).padding(.bottom, 20)
                Heading(store.unitTitle(nx.unit), level: 2)
                Meta(store.unitKindName(nx.unit)).padding(.top, 8)
                PassageText(store.L("Afterwards you will be able to", "Danach kannst du") + ": " + store.pick(nx.unit.can), small: true).padding(.top, 14)
                if !nx.unit.assumes.isEmpty {
                    Meta(store.L("This assumes you can already do what", "Das setzt voraus, dass du bereits kannst, was") + " " +
                         nx.unit.assumes.compactMap(store.corpus.unit).map(store.unitTitle).joined(separator: ", ") + " " +
                         store.L("established.", "vermittelt hat.")).padding(.top, 12)
                }
                Button(store.L("Continue the path", "Auf dem Weg weiter")) { openUnit(nx.unit, store: store, router: router) }
                    .buttonStyle(.solid).padding(.top, 20)
                Button(store.L("See the whole path", "Ganzen Weg ansehen")) { router.tab = .path }
                    .buttonStyle(.ghost).padding(.top, 10)
            }
        } else {
            Block {
                PassageText(store.L("You have been through every unit. Running a track again is not repetition — the speaking answers come out differently now.",
                                "Du hast jede Einheit durchlaufen. Einen Weg erneut zu gehen ist keine Wiederholung — die Sprechantworten fallen jetzt anders aus."), small: true)
                Button(store.L("Open the path", "Den Weg öffnen")) { router.tab = .path }.buttonStyle(.solid).padding(.top, 18)
            }
        }
    }

    @ViewBuilder var memoryBlock: some View {
        let due = store.dueItems.count
        Block(rule: false) {
            Rail(label: store.L("Memory", "Gedächtnis")) {
                if due > 0 {
                    Text("\(due) " + (due == 1 ? store.L("recall due", "Abruf fällig") : store.L("recalls due", "Abrufe fällig")))
                        .font(Typo.h3).foregroundStyle(Color.ink).contentTransition(.numericText())
                    Button(store.L("Begin review", "Wiederholung beginnen")) { router.push(.memorySession, on: .review) }
                        .buttonStyle(.solidSmall).padding(.top, 6)
                } else {
                    Meta(store.L("Nothing due. The queue fills as you save things.", "Nichts fällig. Die Warteschlange füllt sich, während du speicherst."))
                }
            }
        }
    }
}

/// One voice or one figure a day — worth reading even if you tap nothing.
struct LeafBlock: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    @State private var leaf: (kind: String, id: String)?

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 0)
                .onAppear { if leaf == nil { leaf = store.leafOfDay() } }
            if let lf = leaf, lf.kind == "voice", let v = store.corpus.voice(lf.id) {
                Block {
                    Rubric(store.L("Today's voice", "Stimme des Tages") + " · " + v.name)
                    PassageText(store.pick(v.hook), italic: true).padding(.top, 14)
                    Meta(store.pick(v.place)).padding(.top, 12)
                    VStack(alignment: .leading, spacing: 8) {
                        Rubric(store.L("Could you answer this?", "Könntest du darauf antworten?"))
                        PassageText(store.pick(v.drill.q), small: true, color: .ink2)
                    }.padding(.top, 20)
                    Button(store.L("Read the scene — about four minutes", "Die Szene lesen — etwa vier Minuten")) { router.push(.voice(v.id)) }
                        .buttonStyle(.outline).padding(.top, 18)
                }
            } else if let lf = leaf, let f = store.corpus.figure(lf.id) {
                Block {
                    Rubric(store.L("Today's figure", "Figur des Tages") + " · " + store.pick(f.n))
                    if let k = f.specimens.first(where: { $0.k != nil })?.k, let q = store.quote(k) {
                        PassageText("“" + q.text + "”", italic: true).padding(.top, 14)
                        Cite(q.label).padding(.top, 8)
                    }
                    Meta(store.pick(f.def)).padding(.top, 12)
                    VStack(alignment: .leading, spacing: 8) {
                        Rubric(store.L("Make this sentence land", "Bring diesen Satz zum Sitzen"))
                        PassageText(store.pick(f.flat), small: true, color: .ink2)
                    }.padding(.top, 20)
                    Button(store.L("Try it — about two minutes", "Versuch es — etwa zwei Minuten")) { router.push(.figure(f.id)) }
                        .buttonStyle(.outline).padding(.top, 18)
                }
            }
        }
    }
}

/// The last coached answer not yet re-attempted: the best reason to come back.
struct ContinuityBlock: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    var body: some View {
        if let it = store.lastCoached() {
            Block {
                Rail(label: store.L("Where you left off", "Wo du stehen geblieben bist")) {
                    Meta(it.title + " · " + store.daysAgo(it.ts))
                    if !it.text.isEmpty {
                        PassageText("“" + (it.text.count > 180 ? String(it.text.prefix(177)) + "…" : it.text) + "”", small: true, color: .ink2)
                    }
                    Rubric(store.L("The one thing to change", "Die eine Sache, die du ändern wolltest"), color: .burgundy).padding(.top, 6)
                    Text(it.fix).font(Typo.serif(16.5)).foregroundStyle(Color.ink).fixedSize(horizontal: false, vertical: true)
                    Button(store.L("Say it again, better", "Noch einmal, besser")) {
                        switch it.target {
                        case .planDay(let p, let d): router.push(.planDay(p, d))
                        case .voice(let v): router.push(.voice(v))
                        case .figure(let f): router.push(.figure(f))
                        }
                    }.buttonStyle(.outlineSmall).padding(.top, 8)
                }
            }
        }
    }
}
