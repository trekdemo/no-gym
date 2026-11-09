import Foundation

/// The four kinds of sequence you can start from.
public enum TemplateKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case emom, tabata, breathing, custom

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .emom: "EMOM"
        case .tabata: "Tabata"
        case .breathing: "Breathing"
        case .custom: "Custom"
        }
    }

    public var summary: String {
        switch self {
        case .emom: "Every minute on the minute. Each minute starts a new exercise."
        case .tabata: "Work and rest pairs, like 20 s on and 10 s off, for 8 rounds."
        case .breathing: "Inhale, hold and exhale with guide tones. Box, 4-7-8 and more."
        case .custom: "Any list of labels and durations. Good for yoga and stretching."
        }
    }

    /// An SF Symbols name for the template.
    public var symbol: String {
        switch self {
        case .emom: "stopwatch"
        case .tabata: "flame"
        case .breathing: "wind"
        case .custom: "list.bullet"
        }
    }
}

/// One exercise in an EMOM. It gets the whole step (usually a minute).
public struct Exercise: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var reps: Int?

    public init(id: UUID = UUID(), name: String, reps: Int? = nil) {
        self.id = id
        self.name = name
        self.reps = reps
    }
}

public struct EmomConfig: Codable, Hashable, Sendable {
    public var stepSeconds: Double
    public var exercises: [Exercise]

    public init(stepSeconds: Double = 60, exercises: [Exercise]) {
        self.stepSeconds = stepSeconds
        self.exercises = exercises
    }
}

public struct TabataConfig: Codable, Hashable, Sendable {
    public var workSeconds: Double
    public var restSeconds: Double
    /// Exercise names. Each round uses the next name, and the list starts over at the end.
    /// When empty, every work interval is labelled "Work".
    public var exercises: [String]

    public init(workSeconds: Double = 20, restSeconds: Double = 10, exercises: [String] = []) {
        self.workSeconds = workSeconds
        self.restSeconds = restSeconds
        self.exercises = exercises
    }
}

public struct BreathingConfig: Codable, Hashable, Sendable {
    public var inhale: Double
    public var holdIn: Double
    public var exhale: Double
    public var holdOut: Double

    public init(inhale: Double, holdIn: Double, exhale: Double, holdOut: Double) {
        self.inhale = inhale
        self.holdIn = holdIn
        self.exhale = exhale
        self.holdOut = holdOut
    }

    public static let box = BreathingConfig(inhale: 4, holdIn: 4, exhale: 4, holdOut: 4)
    public static let relax478 = BreathingConfig(inhale: 4, holdIn: 7, exhale: 8, holdOut: 0)
    public static let coherent = BreathingConfig(inhale: 5.5, holdIn: 0, exhale: 5.5, holdOut: 0)

    public static let presets: [(name: String, config: BreathingConfig)] = [
        ("Box 4-4-4-4", .box),
        ("Relax 4-7-8", .relax478),
        ("Coherent 5.5-5.5", .coherent),
    ]

    public var cycleSeconds: Double { inhale + holdIn + exhale + holdOut }
}

/// A sequence's recipe. It keeps the template's own settings, so the editor
/// can reopen the same form, and it builds the intervals from them.
public enum Template: Codable, Hashable, Sendable {
    case emom(EmomConfig)
    case tabata(TabataConfig)
    case breathing(BreathingConfig)
    case custom([Interval])

    public var kind: TemplateKind {
        switch self {
        case .emom: .emom
        case .tabata: .tabata
        case .breathing: .breathing
        case .custom: .custom
        }
    }

    /// A fresh template with sensible defaults, for "New sequence".
    public static func starter(_ kind: TemplateKind) -> Template {
        switch kind {
        case .emom:
            .emom(EmomConfig(exercises: [
                Exercise(name: "Burpees", reps: 10),
                Exercise(name: "Squats", reps: 15),
                Exercise(name: "Rest"),
            ]))
        case .tabata:
            .tabata(TabataConfig())
        case .breathing:
            .breathing(.box)
        case .custom:
            .custom([
                Interval(label: "Child's pose", seconds: 45, role: .work),
                Interval(label: "Switch", seconds: 5, role: .rest),
            ])
        }
    }

    /// Default number of rounds for a new sequence of this kind.
    public static func starterRounds(_ kind: TemplateKind) -> Int {
        switch kind {
        case .emom: 3
        case .tabata: 8
        case .breathing: 6
        case .custom: 1
        }
    }

    /// The intervals of one round. `round` starts at 0.
    /// Only Tabata changes between rounds: it moves on to the next exercise name.
    public func intervals(round: Int) -> [Interval] {
        switch self {
        case .emom(let config):
            return config.exercises.map {
                Interval(id: $0.id, label: $0.name, seconds: config.stepSeconds, reps: $0.reps,
                         role: $0.name.localizedCaseInsensitiveCompare("rest") == .orderedSame ? .rest : .work)
            }
        case .tabata(let config):
            let names = config.exercises.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            let name = names.isEmpty ? "Work" : names[round % names.count]
            var result = [Interval(label: name, seconds: config.workSeconds, role: .work)]
            if config.restSeconds > 0 {
                result.append(Interval(label: "Rest", seconds: config.restSeconds, role: .rest))
            }
            return result
        case .breathing(let config):
            // A hold of 0 seconds is left out, so 4-7-8 has no second hold.
            let phases: [(String, Double, Role)] = [
                ("Inhale", config.inhale, .inhale),
                ("Hold", config.holdIn, .hold),
                ("Exhale", config.exhale, .exhale),
                ("Hold", config.holdOut, .hold),
            ]
            return phases
                .filter { $0.1 > 0 }
                .map { Interval(label: $0.0, seconds: $0.1, role: $0.2) }
        case .custom(let intervals):
            return intervals
        }
    }
}

// MARK: - Editing helpers

/// Each config as a read-write property, so a SwiftUI form can bind to it:
/// `$routine.template.tabataConfig.workSeconds`. Setting one switches the template to that kind.
extension Template {
    public var emomConfig: EmomConfig {
        get { if case .emom(let config) = self { config } else { EmomConfig(exercises: []) } }
        set { self = .emom(newValue) }
    }

    public var tabataConfig: TabataConfig {
        get { if case .tabata(let config) = self { config } else { TabataConfig() } }
        set { self = .tabata(newValue) }
    }

    public var breathingConfig: BreathingConfig {
        get { if case .breathing(let config) = self { config } else { .box } }
        set { self = .breathing(newValue) }
    }

    public var customIntervals: [Interval] {
        get { if case .custom(let intervals) = self { intervals } else { [] } }
        set { self = .custom(newValue) }
    }
}
