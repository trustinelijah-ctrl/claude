import SwiftUI
import SwiftData

struct PieceDetailView: View {
    @Bindable var piece: Piece
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var addingTask = false
    @State private var confirmingDelete = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(piece.title).font(.displayTitle)
                    if !piece.composer.isEmpty { Text(piece.composer).foregroundStyle(Palette.inkSoft) }
                    if !piece.notes.isEmpty { Text(piece.notes).padding(.top, 4) }
                }
                .padding(.vertical, 6)
                Toggle("Show on Today", isOn: $piece.isCurrent)
            }
            Section {
                if piece.tasks.isEmpty {
                    Text("Break the piece into targets: the passage that trips you, the page turn, the ending.")
                        .foregroundStyle(Palette.inkSoft)
                }
                ForEach(piece.tasks.sorted { $0.createdAt > $1.createdAt }) { task in
                    NavigationLink { TaskDetailView(task: task) } label: { TaskRow(task: task) }
                }
                Button { addingTask = true } label: { Label("New target in this piece", systemImage: "plus") }
            } header: {
                Text("Targets")
            }
        }
        .canvasBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit", systemImage: "pencil") { editing = true }
                    Button("Delete piece", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $editing) { PieceEditorView(piece: piece) }
        .sheet(isPresented: $addingTask) { TaskEditorView(mode: .new(skill: nil, piece: piece)) }
        .confirmationDialog("Delete “\(piece.title)”?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete piece", role: .destructive) {
                context.delete(piece)
                try? context.save()
                dismiss()
            }
        } message: {
            Text("Its targets and their attempts stay; they're just no longer linked to a piece.")
        }
        .activeSessionBar()
    }
}

struct PieceEditorView: View {
    let piece: Piece?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var composer = ""
    @State private var notes = ""
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("Composer or artist", text: $composer)
                TextField("Notes: edition, why you chose it", text: $notes, axis: .vertical)
            }
            .canvasBackground()
            .navigationTitle(piece == nil ? "Add piece" : "Edit piece")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(title.isBlank) }
            }
            .onAppear {
                guard !loaded, let piece else { return }
                loaded = true
                title = piece.title
                composer = piece.composer
                notes = piece.notes
            }
        }
    }

    private func save() {
        let target = piece ?? {
            let created = Piece(title: title.trimmed)
            context.insert(created)
            return created
        }()
        target.title = title.trimmed
        target.composer = composer.trimmed
        target.notes = notes.trimmed
        try? context.save()
        dismiss()
    }
}
