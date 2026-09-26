import SwiftUI
import UniformTypeIdentifiers

struct BackupFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    @AppStorage("logos.reminder.on") private var reminderOn = false
    @AppStorage("logos.reminder.minutes") private var reminderMinutes = 8 * 60
    @State private var exporting = false
    @State private var importing = false
    @State private var pendingImport: (JSONValue, AppStore.BackupSummary)?
    @State private var message: String?

    var body: some View {
        Page {
            PageHead(title: store.L("Settings", "Einstellungen"))
            Block {
                Heading(store.L("Sound and touch", "Ton und Haptik"), level: 3).padding(.bottom, 10)
                Toggle(isOn: Binding(get: { !store.mute }, set: { store.mute = !$0 })) {
                    Text(store.L("Soft tones on actions", "Leise Töne bei Aktionen")).font(Typo.serif(17))
                }.tint(.bronze)
            }
            Block {
                Heading(store.L("Bible wording", "Bibelwortlaut"), level: 3).padding(.bottom, 10)
                Flow {
                    ForEach(["plain", "classic"], id: \.self) { t in
                        Chip(title: store.lang == .de ? (store.corpus.translations[t]?.de ?? t) : (store.corpus.translations[t]?.en ?? t), on: store.translation == t) {
                            store.translation = t
                        }
                    }
                }
                Meta(store.pick(store.corpus.translations[store.translation]?.note) + " " +
                     store.L("Copyrighted modern translations cannot be bundled into an app like this.", "Urheberrechtlich geschützte moderne Übersetzungen können nicht in eine solche App aufgenommen werden.")).padding(.top, 10)
            }
            Block {
                Heading(store.L("A daily reminder", "Eine tägliche Erinnerung"), level: 3).padding(.bottom, 10)
                Toggle(isOn: $reminderOn) { Text(store.L("Remind me once a day", "Einmal am Tag erinnern")).font(Typo.serif(17)) }.tint(.bronze)
                if reminderOn {
                    DatePicker(store.L("At", "Um"), selection: Binding(
                        get: { Calendar.current.date(bySettingHour: reminderMinutes / 60, minute: reminderMinutes % 60, second: 0, of: Date()) ?? Date() },
                        set: { let c = Calendar.current.dateComponents([.hour, .minute], from: $0); reminderMinutes = (c.hour ?? 8) * 60 + (c.minute ?? 0) }),
                               displayedComponents: .hourAndMinute).font(Typo.meta)
                }
                Meta(store.L("Missing a day costs nothing. There are no streaks.", "Ein ausgelassener Tag kostet nichts. Es gibt keine Serien.")).padding(.top, 8)
            }
            .onChange(of: reminderOn) { _, _ in updateReminder() }
            .onChange(of: reminderMinutes) { _, _ in updateReminder() }

            Block {
                Heading(store.L("Your data", "Deine Daten"), level: 3).padding(.bottom, 10)
                Meta(store.L("Everything stays on this device unless you turn on sync. A backup file opens in the web app too, and a web backup opens here.",
                             "Alles bleibt auf diesem Gerät, außer du schaltest den Abgleich ein. Eine Sicherung öffnet sich auch in der Web-App, und eine Web-Sicherung öffnet sich hier."))
                Button(store.L("Sync with the web and other devices", "Mit dem Web und anderen Geräten abgleichen")) { router.push(.sync) }.buttonStyle(.solid).padding(.top, 16)
                Button(store.L("Export a backup", "Sicherung exportieren")) { exporting = true }.buttonStyle(.outline).padding(.top, 12)
                Button(store.L("Restore from a backup", "Aus Sicherung wiederherstellen")) { importing = true }.buttonStyle(.ghost).padding(.top, 12)
                if let s = pendingImport?.1 {
                    AnswerBox {
                        Meta(store.L("Valid backup. It contains \(s.notes) notes, \(s.cards) saved cards, \(s.sessions) speaking sessions and \(s.reflections) reflections. Your current data will be replaced, and you can undo it.",
                                     "Gültige Sicherung. Sie enthält \(s.notes) Notizen, \(s.cards) gespeicherte Karten, \(s.sessions) Sprechübungen und \(s.reflections) Reflexionen. Deine jetzigen Daten werden ersetzt, und du kannst das rückgängig machen."))
                        HStack {
                            Button(store.L("Replace my data", "Meine Daten ersetzen")) {
                                if let d = pendingImport?.0 { store.replaceDocument(d) }
                                pendingImport = nil
                                message = store.L("Restored. Undo is available on this screen.", "Wiederhergestellt. Rückgängig ist auf diesem Bildschirm möglich.")
                            }.buttonStyle(.solidSmall)
                            Button(store.L("Cancel", "Abbrechen")) { pendingImport = nil }.buttonStyle(.ghostSmall)
                        }
                    }.padding(.top, 14)
                }
                if store.rollback != nil {
                    LinkButton(title: store.L("Undo the restore", "Wiederherstellung rückgängig machen")) {
                        message = store.undoRestore() ? store.L("Previous data put back.", "Vorherige Daten zurückgesetzt.") : nil
                    }.padding(.top, 12)
                }
                if let m = message { Meta(m, color: .forest).padding(.top, 10) }
            }
            Block {
                Heading(store.L("Content", "Inhalt"), level: 3).padding(.bottom, 10)
                Meta(store.L("Lessons, voices and plans update from the website when a new version is published. You don't need an app update.",
                             "Lektionen, Stimmen und Pläne aktualisieren sich von der Website, sobald eine neue Fassung veröffentlicht ist. Ein App-Update ist nicht nötig."))
                Cite(store.L("Content version", "Inhaltsversion") + " " + store.corpus.version).padding(.top, 8)
            }
            Block(rule: false) {
                Meta("LOGOS · " + store.L("Scripture: World English Bible, KJV, Luther 1912 (public domain). Stoic texts from public-domain translations.",
                                          "Schrift: World English Bible, KJV, Luther 1912 (gemeinfrei). Stoische Texte aus gemeinfreien Übersetzungen."), color: .ink4)
            }
        }
        .logosNavigation(store.L("Settings", "Einstellungen"))
        .fileExporter(isPresented: $exporting, document: BackupFile(data: store.exportBackup()), contentType: .json,
                      defaultFilename: "logos-backup-" + store.todayKey) { r in
            if case .success = r { message = store.L("Backup saved.", "Sicherung gespeichert.") }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { r in
            guard case .success(let url) = r else { return }
            let ok = url.startAccessingSecurityScopedResource()
            defer { if ok { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { message = store.L("Could not read that file.", "Die Datei ließ sich nicht lesen."); return }
            switch AppStore.validateBackup(data) {
            case .success(let v): pendingImport = v; message = nil
            case .failure(let e): message = reason(e) + " " + store.L("Nothing has been changed.", "Es wurde nichts verändert.")
            }
        }
    }

    func reason(_ e: AppStore.BackupError) -> String {
        switch e {
        case .notJSON: return store.L("That is not valid JSON.", "Das ist kein gültiges JSON.")
        case .notObject: return store.L("The file is empty or not an object.", "Die Datei ist leer oder kein Objekt.")
        case .notLogos: return store.L("This is not a LOGOS backup.", "Das ist keine LOGOS-Sicherung.")
        case .noData: return store.L("The backup contains no data section.", "Die Sicherung enthält keinen Datenteil.")
        case .wrongType(let k): return store.L("Field is the wrong type: ", "Feld hat den falschen Typ: ") + k
        }
    }

    func updateReminder() {
        if reminderOn {
            Task {
                let ok = await Reminders.schedule(hour: reminderMinutes / 60, minute: reminderMinutes % 60, lang: store.lang)
                if !ok { await MainActor.run { reminderOn = false; message = store.L("Notifications are off for LOGOS in Settings.", "Mitteilungen sind für LOGOS in den Einstellungen aus.") } }
            }
        } else { Reminders.cancel() }
    }
}

/// End-to-end-encrypted sync with the web app and other devices.
struct SyncView: View {
    @Environment(AppStore.self) private var store
    @State private var code: SyncCode? = Keychain.get("sync").flatMap(SyncCode.init)
    @State private var entry = ""
    @State private var busy = false
    @State private var status: String?
    @State private var conflict: SyncRemote?
    @State private var showCode = false

    var lastSyncKey: String { "logos.sync.last." + (code?.id.prefix(12) ?? "") }
    var lastSync: Double { UserDefaults.standard.double(forKey: lastSyncKey) }

    var body: some View {
        Page {
            PageHead(title: store.L("Sync", "Abgleich"),
                     sub: store.L("Carry your progress between this phone, the website and other devices. Your data is encrypted on the device with a code only you hold; the server stores something it cannot read.",
                                  "Nimm deinen Fortschritt zwischen diesem Telefon, der Website und anderen Geräten mit. Deine Daten werden auf dem Gerät mit einem Code verschlüsselt, den nur du hast; der Server speichert etwas, das er nicht lesen kann."), showLang: false)
            if let code {
                Block {
                    Heading(store.L("Your sync code", "Dein Abgleich-Code"), level: 3).padding(.bottom, 10)
                    HStack {
                        Text(showCode ? code.display : String(repeating: "•", count: 4) + "-••••-••••-••••-" + String(code.display.suffix(4)))
                            .font(.system(size: 19, weight: .medium, design: .monospaced)).foregroundStyle(Color.ink).textSelection(.enabled)
                        Spacer()
                        Button(showCode ? store.L("Hide", "Verbergen") : store.L("Show", "Zeigen")) { showCode.toggle() }.buttonStyle(.ghostSmall)
                    }
                    HStack(spacing: 10) {
                        Button(store.L("Copy", "Kopieren")) { UIPasteboard.general.string = code.display; status = store.L("Copied.", "Kopiert.") }.buttonStyle(.outlineSmall)
                        ShareLink(item: code.display) { Text(store.L("Share", "Teilen")) }.buttonStyle(.outlineSmall)
                    }.padding(.top, 12)
                    Meta(store.L("Enter this code in the web app (Practice → Your data → Sync) or on another device. Anyone with it can read and replace your synced data, so keep it like a password. If you lose it, nobody can recover the synced copy; your data on this device is unaffected.",
                                 "Gib diesen Code in der Web-App (Üben → Deine Daten → Abgleich) oder auf einem anderen Gerät ein. Wer ihn hat, kann deine abgeglichenen Daten lesen und ersetzen, also bewahre ihn wie ein Passwort auf. Geht er verloren, kann niemand die abgeglichene Kopie wiederherstellen; deine Daten auf diesem Gerät bleiben unberührt."))
                        .padding(.top, 12)
                }
                Block {
                    Button { Task { await sync() } } label: { Text(busy ? store.L("Syncing…", "Gleiche ab …") : store.L("Sync now", "Jetzt abgleichen")) }
                        .buttonStyle(.solid).disabled(busy)
                    if lastSync > 0 { Meta(store.L("Last synced", "Zuletzt abgeglichen") + " " + store.daysAgo(lastSync)).padding(.top, 10) }
                    if let c = conflict {
                        AnswerBox {
                            Rubric(store.L("Both sides changed", "Beide Seiten haben sich geändert"), color: .burgundy)
                            Meta(store.L("This device and the synced copy were both changed since the last sync. Choose which to keep; the other is replaced (and this device's copy can be undone in Settings).",
                                         "Dieses Gerät und die abgeglichene Kopie wurden seit dem letzten Abgleich beide geändert. Wähle, was bleibt; das andere wird ersetzt (die Kopie dieses Geräts lässt sich in den Einstellungen wiederherstellen)."))
                            HStack {
                                Button(store.L("Keep this device", "Dieses Gerät behalten")) { Task { await push() } }.buttonStyle(.solidSmall)
                                Button(store.L("Take the other", "Die andere nehmen")) { apply(c) }.buttonStyle(.outlineSmall)
                            }
                        }.padding(.top, 14)
                    }
                    if let s = status { Meta(s, color: .ink2).padding(.top, 10) }
                }
                Block(rule: false) {
                    Button(store.L("Turn off sync on this device", "Abgleich auf diesem Gerät ausschalten"), role: .destructive) {
                        Keychain.set(nil, for: "sync"); self.code = nil; status = nil
                    }.buttonStyle(.ghost)
                }
            } else {
                Block {
                    Button(store.L("Turn on sync", "Abgleich einschalten")) {
                        let c = SyncCode.generate(); Keychain.set(c.normalized, for: "sync"); code = c; showCode = true
                        Task { await sync() }
                    }.buttonStyle(.solid)
                    Meta(store.L("Creates a new code and uploads an encrypted copy of this device's progress.",
                                 "Erzeugt einen neuen Code und lädt eine verschlüsselte Kopie dieses Geräts hoch.")).padding(.top, 10)
                }
                Block(rule: false) {
                    Heading(store.L("I already have a code", "Ich habe schon einen Code"), level: 3).padding(.bottom, 10)
                    TextField("ABCD-EFGH-JKLM-NPQR-STUV", text: $entry)
                        .font(.system(size: 18, design: .monospaced)).textInputAutocapitalization(.characters).autocorrectionDisabled()
                        .padding(12).overlay(Rectangle().stroke(Color.rule))
                    Button(store.L("Connect", "Verbinden")) {
                        guard let c = SyncCode(entry) else { status = store.L("That code is incomplete. It has 20 letters and digits.", "Der Code ist unvollständig. Er hat 20 Buchstaben und Ziffern."); return }
                        Keychain.set(c.normalized, for: "sync"); code = c
                        Task { await sync() }
                    }.buttonStyle(.outline).padding(.top, 12)
                    if let s = status { Meta(s, color: .burgundy).padding(.top, 10) }
                }
            }
        }
        .logosNavigation(store.L("Sync", "Abgleich"))
    }

    func sync() async {
        guard let code else { return }
        busy = true; status = nil; conflict = nil
        defer { busy = false }
        do {
            let remote = try await SyncClient(code: code).pull()
            switch SyncPlan.decide(local: store.modified, remote: remote?.updated, lastSync: lastSync) {
            case .push: await push()
            case .pull: if let r = remote { apply(r) }
            case .upToDate: status = store.L("Up to date.", "Auf dem neuesten Stand.")
            case .conflict:
                // A brand-new device with nothing done yet simply takes the synced copy.
                if lastSync == 0 && store.doc["extra"].array.isEmpty && store.doc["lessons"].object.isEmpty, let r = remote { apply(r) }
                else { conflict = remote }
            }
        } catch let e as SyncError {
            status = describe(e)
        } catch { status = describe(.network) }
    }

    func push() async {
        guard let code else { return }
        busy = true; defer { busy = false }
        let updated = max(store.modified, store.nowMs)
        do {
            try await SyncClient(code: code).push(doc: store.doc, updated: updated)
            UserDefaults.standard.set(updated, forKey: lastSyncKey)
            conflict = nil
            status = store.L("Uploaded. Other devices will pick this up when they sync.", "Hochgeladen. Andere Geräte übernehmen das beim nächsten Abgleich.")
            Feedback.shared.play(.save, muted: store.mute)
        } catch let e as SyncError { status = describe(e) } catch { status = describe(.network) }
    }

    func apply(_ r: SyncRemote) {
        var d = r.doc
        d["modified"] = .number(r.updated)
        store.replaceDocument(d)
        UserDefaults.standard.set(r.updated, forKey: lastSyncKey)
        conflict = nil
        status = store.L("Brought in the synced copy. Undo is in Settings.", "Abgeglichene Kopie übernommen. Rückgängig in den Einstellungen.")
        Feedback.shared.play(.done, muted: store.mute)
    }

    func describe(_ e: SyncError) -> String {
        switch e {
        case .network: return store.L("No connection. Nothing was changed.", "Keine Verbindung. Nichts wurde verändert.")
        case .wrongCode: return store.L("That code does not open the synced copy.", "Dieser Code öffnet die abgeglichene Kopie nicht.")
        case .corrupt: return store.L("The synced copy is unreadable. Nothing was changed here.", "Die abgeglichene Kopie ist unlesbar. Hier wurde nichts verändert.")
        case .server(let s): return store.L("The sync server answered \(s). Nothing was changed.", "Der Abgleich-Server antwortete \(s). Nichts wurde verändert.")
        }
    }
}
