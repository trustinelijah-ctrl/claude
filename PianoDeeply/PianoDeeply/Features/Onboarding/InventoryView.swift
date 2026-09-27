import SwiftUI
import SwiftData
import PianoCore

/// The six samples, each logged as a cold attempt on its own task, with a
/// cold retest four weeks out for a like-for-like comparison.
struct InventoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var tasks: [PracticeTask]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(InventorySample.allCases) { sample in
                        NavigationLink {
                            InventorySampleView(sample: sample)
                        } label: {
                            InventoryRow(sample: sample, task: Inventory.task(for: sample, in: tasks))
                        }
                    }
                } footer: {
                    Text("Each sample gets a cold retest four weeks after you log it. You can skip any of them.")
                }
            }
            .canvasBackground()
            .navigationTitle("Inventory")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

enum Inventory {
    static func task(for sample: InventorySample, in tasks: [PracticeTask]) -> PracticeTask? {
        tasks.first { $0.inventorySample == sample }
    }

    static func isDone(_ sample: InventorySample, in tasks: [PracticeTask]) -> Bool {
        task(for: sample, in: tasks)?.lastColdAttempt != nil
    }

    static func doneCount(in tasks: [PracticeTask]) -> Int {
        InventorySample.allCases.filter { isDone($0, in: tasks) }.count
    }
}

private struct InventoryRow: View {
    let sample: InventorySample
    let task: PracticeTask?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: task?.lastColdAttempt != nil ? "checkmark.circle.fill" : sample.branch.symbol)
                .font(.title3)
                .foregroundStyle(task?.lastColdAttempt != nil ? Palette.forest : Palette.inkSoft)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(sample.title).font(.body.weight(.medium))
                if let attempt = task?.lastColdAttempt {
                    Text("Logged \(attempt.date.dayHeading.lowercased())")
                        .font(.subheadline)
                        .foregroundStyle(Palette.inkSoft)
                } else {
                    Text("Not yet").font(.subheadline).foregroundStyle(Palette.inkSoft)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

struct InventorySampleView: View {
    let sample: InventorySample

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AudioRecorder.self) private var recorder
    @Query private var tasks: [PracticeTask]

    @State private var whatItWas = ""
    @State private var tempoText = ""
    @State private var observation = ""
    @State private var nextStep = ""
    @State private var take = TakeHolder()

    private var recordingOwner: String { "inventory-\(sample.rawValue)" }
    private var existingTask: PracticeTask? { Inventory.task(for: sample, in: tasks) }

    var body: some View {
        Form {
            Section {
                Text(sample.instruction)
                    .font(.body)
                    .padding(.vertical, 4)
            }

            if let task = existingTask, let first = task.lastColdAttempt {
                Section("Already logged") {
                    VStack(alignment: .leading, spacing: 6) {
                        PhaseBadge(attempt: first)
                        Text(first.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline).foregroundStyle(Palette.inkSoft)
                        if !first.observation.isBlank { Text(first.observation) }
                    }
                    NavigationLink("Open this task") { TaskDetailView(task: task) }
                }
            }

            Section {
                RecordControl(owner: recordingOwner, title: "Inventory: \(sample.title)") { [take] made in
                    made.task = existingTask
                    take.recording = made
                }
                if let recording = take.recording {
                    RecordingRow(recording: recording)
                }
            } header: {
                Text("Record it (optional)")
            }

            Section("What you played") {
                if sample == .familiarPiece || sample == .easyReading || sample == .melodyByEar || sample == .chordProgression {
                    TextField(placeholder, text: $whatItWas, axis: .vertical)
                }
                TempoField(text: $tempoText)
                TextField("What did you notice?", text: $observation, axis: .vertical)
                    .lineLimit(3...8)
                TextField("Anything to try next? (optional)", text: $nextStep, axis: .vertical)
            }

            Section {
                Button(existingTask?.lastColdAttempt == nil ? "Save sample" : "Save another cold pass", action: save)
                    .buttonStyle(.primary)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
        }
        .canvasBackground()
        .navigationTitle(sample.title)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { recorder.stop(ifOwnedBy: recordingOwner) }
    }

    private var placeholder: String {
        switch sample {
        case .familiarPiece: "Which piece, and from where?"
        case .easyReading: "What did you read?"
        case .melodyByEar: "Which melody?"
        default: "Which progression, in which key?"
        }
    }

    private func save() {
        recorder.stop(ifOwnedBy: recordingOwner)
        let task = existingTask ?? {
            let task = PracticeTask(title: sample.taskTitle)
            task.inventorySample = sample
            context.insert(task)
            return task
        }()
        if !whatItWas.isBlank, task.contextNote.isBlank { task.contextNote = whatItWas.trimmed }

        let attempt = Attempt(task: task, phase: .cold)
        attempt.tempo = TempoField.parse(tempoText)
        attempt.observation = observation.trimmed
        attempt.nextStep = nextStep.trimmed
        context.insert(attempt)

        if let recording = take.recording {
            recording.attempt = attempt
            recording.task = task
        }

        let due = InventorySample.recheckInterval.dueDate(from: attempt.date)
        if !task.pendingRetests.contains(where: { Calendar.current.isDate($0.dueDate, inSameDayAs: due) }) {
            context.insert(Retest(task: task, dueDate: due, context: "Four-week inventory check. " + Retest.context(from: attempt)))
        }
        try? context.save()
        dismiss()
    }
}

#if DEBUG
#Preview("Partly done") {
    InventoryView()
        .previewEnvironment(.partialInventory)
}
#endif
