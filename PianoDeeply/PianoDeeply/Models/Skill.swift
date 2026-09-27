import Foundation
import SwiftData
import PianoCore

/// A subskill on the map, such as "Scales & thumb crossings" under Technique.
@Model
final class Skill {
    var id: UUID = UUID()
    var branchRaw: String = SkillBranch.technique.rawValue
    var name: String = ""
    var evidence: String = ""
    var stateRaw: String = SkillState.notExplored.rawValue
    var isBottleneck: Bool = false
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    var stateChangedAt: Date?

    @Relationship(deleteRule: .nullify, inverse: \PracticeTask.skill)
    var tasks: [PracticeTask] = []

    init(branch: SkillBranch, name: String, evidence: String, sortOrder: Int) {
        self.branchRaw = branch.rawValue
        self.name = name
        self.evidence = evidence
        self.sortOrder = sortOrder
    }

    var branch: SkillBranch {
        get { SkillBranch(rawValue: branchRaw) ?? .technique }
        set { branchRaw = newValue.rawValue }
    }

    var state: SkillState {
        get { SkillState(rawValue: stateRaw) ?? .notExplored }
        set {
            guard newValue.rawValue != stateRaw else { return }
            stateRaw = newValue.rawValue
            stateChangedAt = .now
        }
    }

    /// The most recent attempt on any task linked to this skill.
    var lastAttempt: Attempt? {
        tasks.flatMap(\.attempts).max { $0.date < $1.date }
    }
}

enum SkillSeeder {
    private static let seededKey = "skillsSeeded.v1"

    /// Adds the starter subskills once. They start as "Not explored"; if the
    /// user later deletes them all, they stay deleted.
    static func seedIfNeeded(_ context: ModelContext, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: seededKey) else { return }
        let existing = (try? context.fetchCount(FetchDescriptor<Skill>())) ?? 0
        if existing == 0 {
            insertStarterSkills(into: context)
            try? context.save()
        }
        defaults.set(true, forKey: seededKey)
    }

    static func insertStarterSkills(into context: ModelContext) {
        for branch in SkillBranch.allCases {
            for (index, template) in branch.starterSubskills.enumerated() {
                context.insert(Skill(branch: branch, name: template.name, evidence: template.evidence, sortOrder: index))
            }
        }
    }

    /// Only one bottleneck at a time, so the Today suggestion has one clear reason.
    static func markBottleneck(_ skill: Skill, in skills: [Skill]) {
        let newValue = !skill.isBottleneck
        for other in skills where other.isBottleneck { other.isBottleneck = false }
        skill.isBottleneck = newValue
    }
}
