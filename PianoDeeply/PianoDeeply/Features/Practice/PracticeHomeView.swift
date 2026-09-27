import SwiftUI
import SwiftData
import PianoCore

/// The Practice tab: start or resume, your targets, your pieces.
struct PracticeHomeView: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Query(sort: \PracticeTask.createdAt, order: .reverse) private var tasks: [PracticeTask]
    @Query(sort: \Piece.createdAt, order: .reverse) private var pieces: [Piece]
    @State private var editingTask: TaskEditorView.Mode?
    @State private var addingPiece = false

    private var active: [PracticeTask] { tasks.filter { !$0.isArchived } }
    private var archived: [PracticeTask] { tasks.filter(\.isArchived) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Plan a session") { app.planSession() }
                        .buttonStyle(.primary)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                    Button {
                        app.startJustPlay(in: context)
                    } label: {
                        Label("Just play", systemImage: "music.note")
                    }
                    .buttonStyle(.secondary)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                }

                Section {
                    if active.isEmpty {
                        Text("A target is something you could check: “bars 9–12, hands together, no stops at 60”.")
                            .foregroundStyle(Palette.inkSoft)
                    }
                    ForEach(active) { task in
                        NavigationLink { TaskDetailView(task: task) } label: { TaskRow(task: task) }
                    }
                    Button { editingTask = .new(skill: nil, piece: nil) } label: {
                        Label("New target", systemImage: "plus")
                    }
                } header: {
                    Text("Targets")
                }

                Section {
                    if pieces.isEmpty {
                        Text("Add the pieces you're learning or keeping up. They show up on Today.")
                            .foregroundStyle(Palette.inkSoft)
                    }
                    ForEach(pieces) { piece in
                        NavigationLink { PieceDetailView(piece: piece) } label: { PieceRow(piece: piece) }
                    }
                    Button { addingPiece = true } label: {
                        Label("Add piece", systemImage: "plus")
                    }
                } header: {
                    Text("Pieces")
                }

                if !archived.isEmpty {
                    Section {
                        DisclosureGroup("Archived targets (\(archived.count))") {
                            ForEach(archived) { task in
                                NavigationLink { TaskDetailView(task: task) } label: { TaskRow(task: task) }
                            }
                        }
                    }
                }
            }
            .canvasBackground()
            .navigationTitle("Practice")
            .activeSessionBar()
            .sheet(item: $editingTask) { TaskEditorView(mode: $0) }
            .sheet(isPresented: $addingPiece) { PieceEditorView(piece: nil) }
        }
    }
}

struct TaskRow: View {
    let task: PracticeTask

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(task.title).font(.body.weight(.medium))
            HStack(spacing: 6) {
                if let skill = task.skill {
                    Text(skill.name)
                }
                if let last = task.lastAttempt {
                    Text("·")
                    Text("last \(last.date.dayHeading.lowercased())")
                } else {
                    Text(task.skill == nil ? "Not tried yet" : "· not tried yet")
                }
                if !task.pendingRetests.isEmpty {
                    Image(systemName: "snowflake").accessibilityLabel("Retest scheduled")
                }
            }
            .font(.subheadline)
            .foregroundStyle(Palette.inkSoft)
        }
        .padding(.vertical, 2)
    }
}

private struct PieceRow: View {
    let piece: Piece

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(piece.title).font(.body.weight(.medium))
                if piece.isCurrent {
                    Text("Current")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.brass)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Palette.brassWash, in: Capsule())
                }
            }
            if !piece.composer.isEmpty {
                Text(piece.composer).font(.subheadline).foregroundStyle(Palette.inkSoft)
            }
        }
        .padding(.vertical, 2)
    }
}

#if DEBUG
#Preview("Several weeks") {
    PracticeHomeView()
        .previewEnvironment(.severalWeeks)
}

#Preview("Empty") {
    PracticeHomeView()
        .previewEnvironment(.fresh)
}
#endif
