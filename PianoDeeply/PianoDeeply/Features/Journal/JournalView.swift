import SwiftUI
import SwiftData
import PianoCore

/// Evidence, newest first: attempts (cold and after practice kept distinct),
/// sessions, recordings, notes, and pieces started.
struct JournalView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case all, cold, recordings, notes
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: "Everything"
            case .cold: "Cold passes and retests"
            case .recordings: "With recordings"
            case .notes: "Notes and sessions"
            }
        }
    }

    private enum Entry: Identifiable {
        case attempt(Attempt)
        case recording(Recording)
        case session(PracticeSession)
        case note(JournalNote)
        case piece(Piece)

        var id: String {
            switch self {
            case .attempt(let a): "a-\(a.id)"
            case .recording(let r): "r-\(r.id)"
            case .session(let s): "s-\(s.id)"
            case .note(let n): "n-\(n.id)"
            case .piece(let p): "p-\(p.id)"
            }
        }

        var date: Date {
            switch self {
            case .attempt(let a): a.date
            case .recording(let r): r.createdAt
            case .session(let s): s.startedAt
            case .note(let n): n.date
            case .piece(let p): p.createdAt
            }
        }
    }

    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Query(sort: \Attempt.date, order: .reverse) private var attempts: [Attempt]
    @Query(sort: \Recording.createdAt, order: .reverse) private var recordings: [Recording]
    @Query(filter: #Predicate<PracticeSession> { $0.endedAt != nil }, sort: \PracticeSession.startedAt, order: .reverse)
    private var sessions: [PracticeSession]
    @Query(sort: \JournalNote.date, order: .reverse) private var notes: [JournalNote]
    @Query(sort: \Piece.createdAt, order: .reverse) private var pieces: [Piece]

    @State private var filter: Filter = .all
    @State private var writingNote = false
    @State private var editingNote: JournalNote?

    private func makeEntries() -> [Entry] {
        var result: [Entry] = []
        switch filter {
        case .all:
            result += attempts.map(Entry.attempt)
            result += recordings.filter { $0.attempt == nil }.map(Entry.recording)
            result += sessions.map(Entry.session)
            result += notes.map(Entry.note)
            result += pieces.map(Entry.piece)
        case .cold:
            result += attempts.filter { $0.phase == .cold }.map(Entry.attempt)
        case .recordings:
            result += attempts.filter { $0.recording != nil }.map(Entry.attempt)
            result += recordings.filter { $0.attempt == nil }.map(Entry.recording)
        case .notes:
            result += sessions.map(Entry.session)
            result += notes.map(Entry.note)
        }
        return result.sorted { $0.date > $1.date }
    }

    private func days(of entries: [Entry]) -> [(day: Date, entries: [Entry])] {
        let calendar = Calendar.current
        return Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }
            .map { (day: $0.key, entries: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }

    private var comparison: BeforeNow? {
        EvidenceComparison.latestPair(in: attempts.compactMap(\.evidencePoint))
    }

    var body: some View {
        let entries = makeEntries()
        return NavigationStack {
            Group {
                if entries.isEmpty && filter == .all {
                    emptyState
                } else {
                    list(entries)
                }
            }
            .background(Palette.canvas.ignoresSafeArea())
            .navigationTitle("Journal")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { writingNote = true } label: { Label("Write a note", systemImage: "square.and.pencil") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Show", selection: $filter) {
                            ForEach(Filter.allCases) { Text($0.label).tag($0) }
                        }
                    } label: {
                        Label("Filter", systemImage: filter == .all ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $writingNote) { NoteEditorView(note: nil) }
            .sheet(item: $editingNote) { NoteEditorView(note: $0) }
            .activeSessionBar()
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nothing here yet", systemImage: "book.closed")
        } description: {
            Text("Cold first passes, practice notes, retests, and recordings collect here, newest first. Nothing is added for you.")
        } actions: {
            Button("Start practice") { app.planSession() }
                .buttonStyle(.borderedProminent)
            Button("Write a note") { writingNote = true }
        }
    }

    private func list(_ entries: [Entry]) -> some View {
        List {
            if filter == .all, let comparison,
               let task = attempts.first(where: { $0.task?.id == comparison.taskID })?.task {
                Section {
                    BeforeNowContent(pair: comparison, taskTitle: task.title, attempts: task.attempts)
                } header: {
                    Text("Before → Now → Next")
                }
            }

            if entries.isEmpty {
                Text("Nothing matches “\(filter.label)”.")
                    .foregroundStyle(Palette.inkSoft)
            }

            ForEach(days(of: entries), id: \.day) { day in
                Section(day.day.dayHeading) {
                    ForEach(day.entries) { entry in
                        row(for: entry)
                    }
                    .onDelete { offsets in
                        offsets.map { day.entries[$0] }.forEach { delete($0) }
                        try? context.save()
                    }
                }
            }
        }
        .canvasBackground()
    }

    @ViewBuilder
    private func row(for entry: Entry) -> some View {
        switch entry {
        case .attempt(let attempt):
            NavigationLink { AttemptEditorView(attempt: attempt) } label: { JournalAttemptRow(attempt: attempt) }
        case .recording(let recording):
            RecordingRow(recording: recording)
        case .session(let session):
            NavigationLink { SessionDetailView(session: session) } label: { JournalSessionRow(session: session) }
        case .note(let note):
            Button { editingNote = note } label: {
                Label { Text(note.text).lineLimit(4).foregroundStyle(Palette.ink) } icon: {
                    Image(systemName: "text.quote").foregroundStyle(Palette.forest)
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        case .piece(let piece):
            NavigationLink { PieceDetailView(piece: piece) } label: {
                Label("Started \(piece.title)", systemImage: "music.quarternote.3")
            }
            .deleteDisabled(true)
        }
    }

    private func delete(_ entry: Entry) {
        switch entry {
        case .attempt(let a): context.delete(a)
        case .recording(let r): RecordingStore.delete(r, in: context)
        case .session(let s): context.delete(s)
        case .note(let n): context.delete(n)
        case .piece: break
        }
    }
}

private struct JournalAttemptRow: View {
    let attempt: Attempt

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(attempt.task?.title ?? "Deleted target").font(.body.weight(.semibold))
            HStack(spacing: 8) {
                PhaseBadge(attempt: attempt)
                if let tempo = attempt.tempo {
                    Text("\(tempo) bpm").font(.subheadline.monospacedDigit()).foregroundStyle(Palette.inkSoft)
                }
                Text(attempt.date.formatted(date: .omitted, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkSoft)
            }
            if let context = attempt.task?.contextSummary, !context.isEmpty {
                Text(context).font(.subheadline).foregroundStyle(Palette.inkSoft)
            }
            if !attempt.observation.isBlank { Text(attempt.observation).lineLimit(4) }
            if !attempt.nextStep.isBlank {
                Text("Next: \(attempt.nextStep)").font(.subheadline).foregroundStyle(Palette.inkSoft)
            }
            if let recording = attempt.recording {
                PlayButton(recording: recording)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct JournalSessionRow: View {
    let session: PracticeSession

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(session.kind == .justPlay ? "Just played · \(session.practisedMinutesText)" : "Practice · \(session.practisedMinutesText)",
                  systemImage: session.kind == .justPlay ? "music.note" : "pianokeys")
                .font(.body.weight(.semibold))
            if let task = session.focusTask {
                Text("Focus: \(task.title)").font(.subheadline).foregroundStyle(Palette.inkSoft)
            }
            if !session.closingEasier.isBlank { Text("Easier: \(session.closingEasier)").lineLimit(3) }
            if !session.closingNext.isBlank {
                Text("Next: \(session.closingNext)").font(.subheadline).foregroundStyle(Palette.inkSoft)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Before → Now → Next for one comparable pair. The comparison is between
/// the user's own entries; the app doesn't judge the playing.
struct BeforeNowContent: View {
    let pair: BeforeNow
    let taskTitle: String?
    let attempts: [Attempt]

    private func attempt(for point: EvidencePoint) -> Attempt? {
        attempts.first { $0.id == point.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let taskTitle {
                Text(taskTitle).font(.displayHeadline)
            }
            Text("\(pair.phase.label) compared with \(pair.phase.label.lowercased())")
                .font(.subheadline)
                .foregroundStyle(Palette.inkSoft)

            AdaptiveStack(spacing: 14) {
                column(title: "Before", point: pair.before)
                Image(systemName: "arrow.right")
                    .foregroundStyle(Palette.inkSoft)
                    .accessibilityHidden(true)
                column(title: "Now", point: pair.now)
            }

            if let change = pair.tempoChange, change != 0 {
                Text(change > 0 ? "\(change) bpm faster, by your own count." : "\(-change) bpm slower, by your own count.")
                    .font(.subheadline.weight(.medium))
            }

            if let next = pair.next {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Next").font(.headline)
                    Text(next)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func column(title: String, point: EvidencePoint) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(point.date.formatted(date: .abbreviated, time: .omitted))
                .font(.subheadline)
                .foregroundStyle(Palette.inkSoft)
            if let tempo = point.tempo {
                Text("\(tempo) bpm").font(.subheadline.monospacedDigit())
            }
            if !point.observation.isBlank {
                Text(point.observation).font(.subheadline).lineLimit(4)
            }
            if let recording = attempt(for: point)?.recording {
                PlayButton(recording: recording, label: "Play \(title.lowercased())")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NoteEditorView: View {
    let note: JournalNote?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var loaded = false
    @State private var deleteOnExit = false
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                TextField("A small discovery, a question, something you heard.", text: $text, axis: .vertical)
                    .lineLimit(4...20)
                    .focused($focused)
                if let note {
                    Section {
                        Button("Delete note", role: .destructive) {
                            deleteOnExit = true
                            dismiss()
                        }
                    }
                }
            }
            .canvasBackground()
            .navigationTitle(note == nil ? "New note" : "Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(text.isBlank) }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                text = note?.text ?? ""
                focused = note == nil
            }
        }
        .onDisappear {
            guard deleteOnExit, let note else { return }
            context.delete(note)
            try? context.save()
        }
    }

    private func save() {
        if let note {
            note.text = text.trimmed
        } else {
            context.insert(JournalNote(text: text.trimmed))
        }
        try? context.save()
        dismiss()
    }
}

/// Read and edit a finished session's notes.
struct SessionDetailView: View {
    @Bindable var session: PracticeSession
    @Environment(\.modelContext) private var context

    var body: some View {
        Form {
            Section {
                LabeledContent("Date", value: session.startedAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Played", value: session.practisedMinutesText)
                if session.kind == .practice {
                    LabeledContent("Planned", value: "\(session.plannedMinutes) min")
                }
                if let task = session.focusTask {
                    NavigationLink { TaskDetailView(task: task) } label: {
                        LabeledContent("Focus", value: task.title)
                    }
                }
            }
            if session.kind == .practice {
                Section("Focused problem") {
                    TextField("Smaller exercise", text: $session.focusSmallerExercise, axis: .vertical)
                    TextField("What fixed it", text: $session.focusCorrection, axis: .vertical)
                    TextField("Variation", text: $session.focusVariation, axis: .vertical)
                    TextField("Back into the music", text: $session.focusReintegration, axis: .vertical)
                }
                let notes = session.stepNotes.filter { !$0.value.isBlank }
                if !notes.isEmpty {
                    Section("Step notes") {
                        ForEach(notes.keys.sorted(), id: \.self) { key in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(SessionStepKind(rawValue: key)?.title ?? key).font(.subheadline.weight(.semibold))
                                Text(notes[key] ?? "")
                            }
                        }
                    }
                }
                Section("Closing note") {
                    TextField("What got easier", text: $session.closingEasier, axis: .vertical)
                    TextField("Next time", text: $session.closingNext, axis: .vertical)
                }
            }
            if !session.attempts.isEmpty {
                Section("Attempts") {
                    ForEach(session.attempts.sorted { $0.date < $1.date }) { attempt in
                        NavigationLink { AttemptEditorView(attempt: attempt) } label: { AttemptListRow(attempt: attempt) }
                    }
                }
            }
            if !session.recordings.isEmpty {
                Section("Recordings") {
                    ForEach(session.recordings.sorted { $0.createdAt < $1.createdAt }) { RecordingRow(recording: $0) }
                }
            }
        }
        .canvasBackground()
        .navigationTitle(session.kind == .justPlay ? "Just play" : "Session")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { try? context.save() }
    }
}

#if DEBUG
#Preview("Empty journal") {
    JournalView()
        .previewEnvironment(.fresh)
}

#Preview("Several weeks") {
    JournalView()
        .previewEnvironment(.severalWeeks)
}
#endif
