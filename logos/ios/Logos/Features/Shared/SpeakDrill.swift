import SwiftUI

/// The app's central exercise, used by lessons, plans, voices, figures and
/// the rhetoric studio: say it aloud (the phone transcribes), get coached on
/// the words, try again with the one fix, then compare with a model answer.
struct SpeakDrill: View {
    @Environment(AppStore.self) private var store
    let question: String
    let hint: String
    let model: String
    var secs: Int = 60
    var exerciseLang: Lang? = nil
    var placeholder: String = ""
    var minChars = 15
    var showQuestion = true
    @Binding var text: String
    /// The stored coach reply, if any (persisted by the caller).
    @Binding var coach: String?
    var previous: [JSONValue] = []
    @Binding var revealed: Bool
    /// Archive the current attempt and clear the field.
    var onRetry: () -> Void

    @State private var speech = SpeechCapture()
    @State private var pending = false
    @State private var failure: CoachError?

    var lang: Lang { exerciseLang ?? store.lang }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showQuestion {
                HStack(alignment: .firstTextBaseline) {
                    Heading(store.L("Say it", "Sprich es"), level: 2)
                    Spacer()
                    Cite("\(secs)s")
                }
                .padding(.bottom, 12)
                Passage(question, small: true)
            }
            if !hint.isEmpty { Rail(label: store.L("How to build it", "Wie du es baust")) { Passage(hint, small: true, color: .ink2) } }
            if !previous.isEmpty { AttemptsView(previous: previous) }

            SpeakField(text: $text, speech: speech, lang: lang, secs: secs,
                       placeholder: placeholder.isEmpty ? store.L("Speak it aloud, then check the words here.", "Sprich es laut und prüfe dann hier die Worte.") : placeholder)
                .padding(.top, 8)

            if speech.elapsed > 3, !speech.isListening, !text.isEmpty {
                PaceNote(words: TextTools.wordCount(speech.transcript), seconds: speech.elapsed, target: secs)
            }

            coachSection.padding(.top, 18)

            if !revealed {
                Button(store.L("Show one way to say it", "Eine Art zeigen, es zu sagen")) {
                    withAnimation(.easeOut) { revealed = true }
                    Feedback.shared.play(.turn, muted: store.mute)
                }
                .buttonStyle(.ghost).padding(.top, 14)
            } else if !model.isEmpty {
                Rail(label: store.L("One way to say it", "Eine Art, es zu sagen")) { Passage(model, small: true) }
                    .transition(.opacity)
            }
        }
        .onDisappear { speech.stop() }
    }

    @ViewBuilder var coachSection: some View {
        if let c = coach, !c.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Rubric(store.L("Coach", "Coach"))
                CoachReply(text: c)
                Meta(store.L("This reads your words only. Pace, pauses and tone are for you to hear.",
                             "Das liest nur deine Worte. Tempo, Pausen und Ton hörst du selbst."))
                HStack(spacing: 14) {
                    Button(store.L("Say it again with that fix", "Noch einmal, mit dieser Korrektur")) {
                        onRetry(); failure = nil
                        Feedback.shared.play(.turn, muted: store.mute)
                    }.buttonStyle(.outlineSmall)
                    LinkButton(title: store.L("Review again", "Erneut prüfen")) { Task { await run() } }
                }
            }
        } else {
            let ready = text.trimmingCharacters(in: .whitespacesAndNewlines).count >= minChars
            Button {
                Task { await run() }
            } label: {
                HStack(spacing: 10) {
                    if pending { ProgressView().tint(.ink) }
                    Text(pending ? store.L("Reading it…", "Wird gelesen …") : store.L("Coach my answer", "Meine Antwort coachen"))
                }
            }
            .buttonStyle(.outline)
            .disabled(!ready || pending)
            if !ready { Meta(store.L("Say it first — the words appear as you speak.", "Sprich zuerst — die Worte erscheinen beim Sprechen.")).padding(.top, 10) }
            if let f = failure {
                Meta(f.reason(store.lang) + (f == .absent ? " " + store.L("Compare yours with the model answer in the meantime.", "Vergleiche deine Antwort solange mit der Musterantwort.") : ""),
                     color: .burgundy).padding(.top, 10)
            }
        }
    }

    func run() async {
        speech.stop()
        pending = true; failure = nil
        let r = await CoachClient().run(.coach(question: question, hint: hint, model: model, answer: text), exerciseLang: lang)
        pending = false
        switch r {
        case .success(let t): withAnimation { coach = t }; Feedback.shared.play(.right, muted: store.mute)
        case .failure(let e): failure = e
        }
    }
}

/// A text field with a microphone: speech is transcribed live into it.
struct SpeakField: View {
    @Environment(AppStore.self) private var store
    @Binding var text: String
    let speech: SpeechCapture
    let lang: Lang
    var secs: Int = 60
    var placeholder: String
    var minHeight: CGFloat = 150
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    if speech.isListening { speech.stop(); Feedback.shared.play(.tap, muted: store.mute) }
                    else {
                        focused = false
                        speech.start(lang: lang, existing: text, limit: TimeInterval(secs)) { text = $0 }
                        Feedback.shared.play(.tap, muted: store.mute)
                    }
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle().fill(speech.isListening ? Color.burgundy : Color.ink).frame(width: 34, height: 34)
                            Circle().stroke(Color.burgundy.opacity(0.35), lineWidth: 2)
                                .frame(width: 34 + CGFloat(speech.level) * 22, height: 34 + CGFloat(speech.level) * 22)
                                .opacity(speech.isListening ? 1 : 0)
                            Image(systemName: speech.isListening ? "stop.fill" : "mic.fill").font(.system(size: 14)).foregroundStyle(Color.vellum)
                        }
                        .frame(width: 56, height: 56)
                        .animation(.easeOut(duration: 0.1), value: speech.level)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(speech.isListening ? store.L("Listening — tap to stop", "Ich höre zu — tippen zum Beenden")
                                                    : store.L("Tap and speak", "Tippen und sprechen"))
                                .font(Typo.button).tracking(1.2).textCase(.uppercase).foregroundStyle(Color.ink)
                            Text(speech.isListening ? clock(speech.elapsed) + " / " + clock(Double(secs))
                                                    : (lang == .de ? "Deutsch" : "English") + " · " + store.L("on this device", "auf diesem Gerät"))
                                .font(Typo.counter).foregroundStyle(Color.ink3)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(speech.isListening ? "Stop listening" : "Start speaking")
                Spacer()
            }
            if speech.state == .denied {
                Meta(store.L("Microphone or speech recognition is off for LOGOS. You can type instead, or allow it in Settings.",
                             "Mikrofon oder Spracherkennung sind für LOGOS aus. Du kannst tippen oder es in den Einstellungen erlauben."), color: .burgundy)
            } else if speech.state == .unavailable {
                Meta(store.L("Speech recognition isn't available right now. Type roughly what you said.",
                             "Spracherkennung ist gerade nicht verfügbar. Schreib grob mit, was du gesagt hast."), color: .burgundy)
            }
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder).font(Typo.serif(17)).foregroundStyle(Color.ink4).padding(.horizontal, 17).padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(Typo.serif(17)).foregroundStyle(Color.ink).lineSpacing(4)
                    .scrollContentBackground(.hidden)
                    .focused($focused)
                    .padding(10)
                    .frame(minHeight: minHeight)
            }
            .background(Color.vellum2.opacity(0.6))
            .overlay(Rectangle().stroke(focused ? Color.bronze : Color.rule, lineWidth: 1))
        }
    }

    func clock(_ s: Double) -> String { let v = max(0, Int(s)); return "\(v / 60):" + String(format: "%02d", v % 60) }
}

struct PaceNote: View {
    @Environment(AppStore.self) private var store
    let words: Int
    let seconds: Double
    let target: Int
    var body: some View {
        let wpm = seconds > 0 ? Int(Double(words) / seconds * 60) : 0
        let note: String = {
            if wpm > 175 { return store.L("Fast. Slow down where the argument turns.", "Schnell. Werde langsamer, wo das Argument sich wendet.") }
            if wpm < 95 && words > 10 { return store.L("Slow. Fine if deliberate; tighten if you were searching for words.", "Langsam. In Ordnung, wenn bewusst; straffen, wenn du nach Worten gesucht hast.") }
            return store.L("A good speaking pace.", "Ein gutes Sprechtempo.")
        }()
        Meta("\(Int(seconds))s · \(wpm) " + store.L("words a minute", "Wörter pro Minute") + " — " + note +
             (Int(seconds) > target + 10 ? " " + store.L("Over time.", "Über der Zeit.") : ""))
            .padding(.top, 10)
    }
}

/// The coach's four labelled lines, laid out as the web does.
struct CoachReply: View {
    @Environment(AppStore.self) private var store
    let text: String
    var body: some View {
        if let c = TextTools.coachParse(text) {
            VStack(alignment: .leading, spacing: 0) {
                row("STRENGTH", store.L("What worked", "Was trug"), c, .forest)
                row("FIX", store.L("Change this next time", "Beim nächsten Mal ändern"), c, .burgundy)
                row("REWRITE", store.L("Your weakest sentence, rewritten", "Dein schwächster Satz, neu gefasst"), c, .bronze, passage: true)
                row("DEVICE", store.L("A move you could have used", "Ein Zug, den du hättest nutzen können"), c, .ink3)
            }
        } else {
            AnswerBox { Passage(text, small: true) }
        }
    }
    @ViewBuilder func row(_ k: String, _ label: String, _ c: [String: String], _ color: Color, passage: Bool = false) -> some View {
        if let v = c[k], !v.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Rubric(label, color: color)
                if passage { Passage(v, small: true, italic: true) } else { Text(v).font(Typo.serif(16.5)).foregroundStyle(Color.ink).fixedSize(horizontal: false, vertical: true) }
            }
            .padding(.vertical, 12)
            .overlay(alignment: .top) { Rectangle().fill(Color.ruleSoft).frame(height: 1) }
        }
    }
}

struct AttemptsView: View {
    @Environment(AppStore.self) private var store
    let previous: [JSONValue]
    @State private var open = false
    var body: some View {
        DisclosureGroup(isExpanded: $open) {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(previous.enumerated().reversed()), id: \.offset) { i, a in
                    VStack(alignment: .leading, spacing: 6) {
                        Meta(store.L("Attempt", "Versuch") + " \(i + 1)")
                        Passage(a["text"].string, small: true, color: .ink2)
                        if !a["coach"].string.isEmpty { CoachReply(text: a["coach"].string) }
                    }
                }
            }.padding(.top, 10)
        } label: {
            Rubric(store.L("Earlier attempts", "Frühere Versuche") + " · \(previous.count)")
        }
        .tint(.ink3)
        .padding(.vertical, 12)
    }
}

/// Binds a string field of a JSON record held in the store.
extension AppStore {
    func textBinding(get: @escaping () -> String, set: @escaping (String) -> Void) -> Binding<String> {
        Binding(get: get, set: set)
    }

    /// Standard drill bindings for voiceWork / craftWork records.
    func workText(_ bucket: String, _ id: String) -> Binding<String> {
        Binding(get: { self.work(bucket, id)["text"].string }, set: { v in self.setWork(bucket, id) { $0["text"] = .string(v) } })
    }
    func workCoach(_ bucket: String, _ id: String) -> Binding<String?> {
        Binding(get: { self.work(bucket, id)["coach"].stringValue },
                set: { v in self.setWork(bucket, id) { $0["coach"] = v.map(JSONValue.string) ?? nil; $0["coachTs"] = .number(self.nowMs) } })
    }
    func workRevealed(_ bucket: String, _ id: String) -> Binding<Bool> {
        Binding(get: { self.work(bucket, id)["revealed"].truthy }, set: { v in self.setWork(bucket, id) { $0["revealed"] = .bool(v) } })
    }
    func workRetry(_ bucket: String, _ id: String) {
        setWork(bucket, id) { r in
            var prev = r["prev"].array
            prev.append(["text": r["text"], "coach": r["coach"], "ts": .number(nowMs)])
            r["prev"] = .array(Array(prev.suffix(5)))
            r["text"] = ""; r["coach"] = nil
        }
    }
}
