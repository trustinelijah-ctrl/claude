#if DEBUG
import SwiftUI
import SwiftData
import PianoCore

extension View {
    /// Everything a screen needs in a preview: sample data and the app's
    /// shared objects.
    @MainActor
    func previewEnvironment(_ scenario: PreviewData.Scenario) -> some View {
        previewEnvironment(container: PreviewData.container(scenario))
    }

    @MainActor
    func previewEnvironment(container: ModelContainer) -> some View {
        modelContainer(container)
            .environment(AppState())
            .environment(AudioRecorder())
            .environment(AudioPlayer())
            .tint(Palette.forest)
    }
}

/// Sample content for Xcode previews only. The shipping app starts empty
/// apart from the starter subskills, all "Not explored".
@MainActor
enum PreviewData {
    enum Scenario {
        case fresh
        case partialInventory
        case activeSession
        case pausedSession
        case severalWeeks
        case longBreak
    }

    static func container(_ scenario: Scenario) -> ModelContainer {
        let container = try! ModelContainer(for: Schema(AppSchema.models),
                                            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        SkillSeeder.insertStarterSkills(into: context)
        switch scenario {
        case .fresh:
            break
        case .partialInventory:
            addInventory(samples: [.familiarPiece, .scaleInversion], daysAgo: 1, to: context)
        case .activeSession, .pausedSession:
            let task = PracticeTask(title: "Bars 9–12, left hand, no stops", contextNote: "Nocturne, Henle edition")
            context.insert(task)
            let session = PracticeSession(kind: .practice, plan: SessionPlanner.template(minutes: 30), focusTask: task,
                                          startedAt: .now.addingTimeInterval(-17 * 60))
            session.currentStepIndex = 2
            session.focusSmallerExercise = "Beats 3–4 of bar 10 only, then the jump into bar 11."
            context.insert(session)
            let cold = Attempt(task: task, phase: .cold, date: .now.addingTimeInterval(-9 * 60))
            cold.tempo = 60
            cold.errorCategory = .coordination
            cold.observation = "Left hand lands late on the jump into bar 11."
            cold.session = session
            context.insert(cold)
            if scenario == .pausedSession { session.pause(at: .now.addingTimeInterval(-3 * 60)) }
        case .severalWeeks:
            addHistory(endingDaysAgo: 0, to: context)
        case .longBreak:
            addHistory(endingDaysAgo: 19, to: context)
        }
        try? context.save()
        return container
    }

    private static func day(_ daysAgo: Int, hour: Int = 18) -> Date {
        let start = Calendar.current.startOfDay(for: .now)
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: start) ?? start
        return date.addingTimeInterval(TimeInterval(hour * 3600))
    }

    private static func addInventory(samples: [InventorySample], daysAgo: Int, to context: ModelContext) {
        for sample in samples {
            let task = PracticeTask(title: sample.taskTitle)
            task.inventorySample = sample
            context.insert(task)
            let attempt = Attempt(task: task, phase: .cold, date: day(daysAgo))
            attempt.observation = sample == .familiarPiece
                ? "First page mostly there. Lost it at the key change."
                : "C major fine; F major thumb crossing bumps in the right hand."
            context.insert(attempt)
            context.insert(Retest(task: task, dueDate: InventorySample.recheckInterval.dueDate(from: attempt.date),
                                  context: "Four-week inventory check. " + Retest.context(from: attempt),
                                  scheduledAt: attempt.date))
        }
    }

    private static func addHistory(endingDaysAgo offset: Int, to context: ModelContext) {
        let skills = (try? context.fetch(FetchDescriptor<Skill>())) ?? []
        let coordination = Skill(branch: .technique, name: "Left-hand coordination",
                                 evidence: "Left-hand pattern steady under a moving right hand at 72 bpm.", sortOrder: 9)
        coordination.state = .slowlyPlayable
        coordination.isBottleneck = true
        context.insert(coordination)
        skills.first { $0.name == "ii–V–I" }?.state = .understood
        skills.first { $0.name == "Easy sight-reading" }?.state = .slowlyPlayable
        skills.first { $0.name == "Free playing" }?.state = .fluent

        let nocturne = Piece(title: "Nocturne in E minor, Op. 72 No. 1", composer: "Chopin")
        nocturne.createdAt = day(offset + 30)
        context.insert(nocturne)

        addInventory(samples: InventorySample.allCases, daysAgo: offset + 30, to: context)

        let passage = PracticeTask(title: "Bars 9–12, left hand, no stops", contextNote: "Henle edition, fingering 5-2-1",
                                   skill: coordination, piece: nocturne)
        passage.createdAt = day(offset + 26)
        context.insert(passage)

        let history: [(Int, AttemptPhase, Int?, String, String, ExperimentOutcome?)] = [
            (26, .cold, 56, "Stopped twice at the jump into bar 11.", "Left hand alone, beats 3–4 only.", nil),
            (26, .afterPractice, 60, "Hands separately clean. Together, the jump still late.", "Try the jump with eyes on the left hand.", .partly),
            (19, .cold, 60, "One stop, at the same jump.", "Jump at 60, eyes on the left hand.", nil),
            (12, .afterPractice, 72, "Jump clean five times in a row.", "Try the turn in bar 12 cold next time.", .worked),
            (5, .cold, 68, "No stops. Bar 12 turn rushed.", "Bar 12 turn with the metronome on 2 and 4.", nil),
        ]
        for (daysAgo, phase, tempo, observation, next, outcome) in history {
            let attempt = Attempt(task: passage, phase: phase, date: day(offset + daysAgo, hour: phase == .cold ? 18 : 19))
            attempt.tempo = tempo
            attempt.observation = observation
            attempt.nextStep = next
            attempt.outcome = outcome
            if phase == .cold && daysAgo == 26 { attempt.errorCategory = .coordination }
            context.insert(attempt)
        }
        context.insert(Retest(task: passage, dueDate: day(offset, hour: 0), context: "After practice · 72 bpm · “Jump clean five times in a row.”",
                              scheduledAt: day(offset + 3)))

        let chords = PracticeTask(title: "ii–V–I in F and B♭, smooth voice leading", skill: skills.first { $0.name == "ii–V–I" })
        chords.createdAt = day(offset + 15)
        context.insert(chords)
        let chordAttempt = Attempt(task: chords, phase: .afterPractice, date: day(offset + 8))
        chordAttempt.observation = "F is automatic. B♭ needs a beat to find the C7→F7 move."
        chordAttempt.nextStep = "B♭ cold, then G."
        context.insert(chordAttempt)
        context.insert(Retest(task: chords, dueDate: Calendar.current.date(byAdding: .day, value: 3, to: .now)!,
                              context: "After practice · “F is automatic.”", scheduledAt: day(offset + 8)))

        for (daysAgo, minutes, easier, next) in [
            (26, 30, "Hands separately feel settled.", "Jump into bar 11 with eyes on the left hand."),
            (12, 32, "The jump into bar 11, even at 72.", "Turn in bar 12, cold."),
            (5, 25, "", "Metronome on 2 and 4 for bar 12."),
        ] {
            let session = PracticeSession(kind: .practice, plan: SessionPlanner.template(minutes: 30), focusTask: passage,
                                          startedAt: day(offset + daysAgo, hour: 17))
            session.clock = SessionClock(accumulated: TimeInterval(minutes * 60), runningSince: nil)
            session.endedAt = session.startedAt.addingTimeInterval(TimeInterval(minutes * 60 + 120))
            session.closingEasier = easier
            session.closingNext = next
            context.insert(session)
        }
        let played = PracticeSession(kind: .justPlay, startedAt: day(offset + 2, hour: 21))
        played.clock = SessionClock(accumulated: 22 * 60, runningSince: nil)
        played.endedAt = played.startedAt.addingTimeInterval(22 * 60)
        context.insert(played)

        context.insert(JournalNote(text: "Playing the left hand alone with the pedal made the harmony make sense. The jump is to the next chord, not a random note.",
                                   date: day(offset + 18, hour: 20)))
    }
}
#endif
