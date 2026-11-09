import Foundation

/// What an interval is for. The role picks the colour on the run screen
/// and, for breathing, the guide tone.
public enum Role: String, Codable, CaseIterable, Sendable {
    case work, rest, inhale, hold, exhale

    public var title: String {
        switch self {
        case .work: "Work"
        case .rest: "Rest"
        case .inhale: "Inhale"
        case .hold: "Hold"
        case .exhale: "Exhale"
        }
    }

    public var isBreathing: Bool { self == .inhale || self == .hold || self == .exhale }
}

/// One timed entry in a sequence: a label shown big on screen, for a number of seconds.
public struct Interval: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var label: String
    public var seconds: Double
    /// Optional repetition count, shown next to the label ("10 × Burpees").
    public var reps: Int?
    public var role: Role

    public init(id: UUID = UUID(), label: String, seconds: Double, reps: Int? = nil, role: Role = .work) {
        self.id = id
        self.label = label
        self.seconds = seconds
        self.reps = reps
        self.role = role
    }

    /// "10 × Burpees", or just the label when there are no reps.
    public var displayLabel: String {
        guard let reps else { return label }
        return "\(reps) × \(label)"
    }
}

/// A saved sequence. The UI calls it a "sequence"; the code calls it a routine
/// so it doesn't clash with Swift's own `Sequence`.
public struct Routine: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var notes: String
    public var template: Template
    /// How many times the list of intervals repeats. 1 or more.
    public var rounds: Int
    /// "Get ready" time before the first interval.
    public var prepSeconds: Double
    public var sound: SoundSettings

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        template: Template,
        rounds: Int,
        prepSeconds: Double = 10,
        sound: SoundSettings? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.template = template
        self.rounds = rounds
        self.prepSeconds = prepSeconds
        self.sound = sound ?? SoundSettings.defaults(for: template.kind)
    }

    /// The intervals of the first round, built from the template.
    public var intervals: [Interval] { template.intervals(round: 0) }

    public var timeline: Timeline { Timeline(routine: self) }

    /// Work time, without the prep.
    public var totalSeconds: Double { timeline.workDuration }

    /// Returns an error message to show, or nil when the routine can be saved.
    public func validationError() -> String? {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Give the sequence a title." }
        if rounds < 1 { return "Rounds must be at least 1." }
        if prepSeconds < 0 { return "Prep time can't be negative." }
        let intervals = timeline.steps.map(\.interval)
        if intervals.isEmpty { return "Add at least one interval." }
        if intervals.contains(where: { $0.label.trimmingCharacters(in: .whitespaces).isEmpty }) {
            return "Every interval needs a label."
        }
        if intervals.contains(where: { $0.seconds < 1 }) { return "Every interval must last at least 1 second." }
        if intervals.contains(where: { ($0.reps ?? 1) < 1 }) { return "Reps must be blank or at least 1." }
        return nil
    }
}
