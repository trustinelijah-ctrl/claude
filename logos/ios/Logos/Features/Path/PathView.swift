import SwiftUI

struct PathView: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        let st = store.pathStats
        Page {
            PageHead(title: store.L("The Path", "Der Weg"),
                     sub: store.L("Twenty-nine units in eight stages. Every topic keeps the same order: the Christian account first, then the Stoic account, then the two side by side. Each unit says what you will be able to do afterwards.",
                                  "Neunundzwanzig Einheiten in acht Stufen. Jedes Thema hält dieselbe Ordnung: zuerst die christliche Darstellung, dann die stoische, dann beide nebeneinander. Jede Einheit sagt, was du danach kannst."))
            Block {
                HStack { Rubric(store.L("Completed", "Abgeschlossen")); Spacer(); Cite("\(st.done) / \(st.total)") }.padding(.bottom, 10)
                ProgressRule(fraction: Double(st.pct) / 100)
            }
            if let nx = store.pathNext {
                Block {
                    Rubric(store.L("Your next step", "Dein nächster Schritt")).padding(.bottom, 6)
                    Button { openUnit(nx.unit, store: store, router: router) } label: {
                        RowLink(title: store.unitTitle(nx.unit),
                                sub: store.L("Afterwards you will be able to", "Danach kannst du") + ": " + store.pick(nx.unit.can), titleSize: 21) {
                            Image(systemName: "arrow.right").foregroundStyle(Color.bronze)
                        }
                    }.buttonStyle(.plain)
                }
            }
            ForEach(store.corpus.path) { s in
                Block {
                    HStack(alignment: .firstTextBaseline) {
                        Heading(store.L("Stage", "Stufe") + " \(s.stage) · " + store.pick(s.name), level: 2)
                        Spacer()
                        Cite("\(s.units.filter(store.unitDone).count)/\(s.units.count)")
                    }
                    Meta(store.pick(s.aim)).padding(.top, 6).padding(.bottom, 10)
                    ForEach(s.units) { u in UnitRow(unit: u) }
                }
            }
            Ornament()
        }
    }
}

struct UnitRow: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    let unit: PathUnit

    var body: some View {
        let fin = store.unitDone(unit), ready = store.unitReady(unit), prog = store.unitProgress(unit)
        Button { openUnit(unit, store: store, router: router) } label: {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle().stroke(fin ? Color.forest : ready ? Color.ink : Color.rule, lineWidth: 1)
                    if fin { Circle().fill(Color.forest.opacity(0.1)) }
                    Text(fin ? "✓" : unit.id.replacingOccurrences(of: "u", with: ""))
                        .font(Typo.counter).foregroundStyle(fin ? Color.forest : ready ? Color.ink : Color.ink4)
                }
                .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.unitTitle(unit)).font(Typo.serif(17.5, .headline)).foregroundStyle(ready || fin ? Color.ink : Color.ink2)
                        .multilineTextAlignment(.leading)
                    Meta(store.unitKindName(unit) + (prog > 0 && prog < 100 ? " · \(prog)%" : ""))
                    if fin {
                        Meta(store.L("You can now", "Du kannst jetzt") + ": " + store.pick(unit.can), color: .forest).padding(.top, 4)
                    } else {
                        Meta(store.L("Afterwards", "Danach") + ": " + store.pick(unit.can)).padding(.top, 4)
                        if !ready {
                            Meta(store.L("Builds on", "Baut auf") + " " + store.unitMissing(unit).joined(separator: ", ") + ". " +
                                 store.L("You can start it anyway.", "Du kannst trotzdem beginnen."), color: .ink4).padding(.top, 2)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
