import Foundation

/// A sound you can pick for an event.
public enum SoundChoice: String, Codable, CaseIterable, Identifiable, Sendable {
    case off, beep, doubleBeep, bell, chime, wood

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .off: "None"
        case .beep: "Beep"
        case .doubleBeep: "Double beep"
        case .bell: "Bell"
        case .chime: "Chime"
        case .wood: "Wood block"
        }
    }
}

/// How many seconds of short ticks to play before an interval ends.
public enum CountdownStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case off, last3, last5

    public var id: String { rawValue }

    public var seconds: Int {
        switch self {
        case .off: 0
        case .last3: 3
        case .last5: 5
        }
    }

    public var title: String {
        switch self {
        case .off: "None"
        case .last3: "Last 3 seconds"
        case .last5: "Last 5 seconds"
        }
    }
}

/// Each sequence has its own sounds.
public struct SoundSettings: Codable, Hashable, Sendable {
    /// Short ticks before each interval ends.
    public var countdown: CountdownStyle
    /// Plays when an interval ends and the next one starts.
    public var intervalEnd: SoundChoice
    /// Plays when the last interval of a round ends.
    public var roundEnd: SoundChoice
    /// Plays when the whole sequence is done.
    public var finish: SoundChoice
    /// Rising tone on inhale, falling tone on exhale, soft low tone on hold.
    public var breathingGuide: Bool
    /// Vibrate on each new interval while the app is open.
    public var haptics: Bool
    /// From 0 to 1.
    public var volume: Double

    public init(
        countdown: CountdownStyle = .last3,
        intervalEnd: SoundChoice = .beep,
        roundEnd: SoundChoice = .doubleBeep,
        finish: SoundChoice = .bell,
        breathingGuide: Bool = false,
        haptics: Bool = true,
        volume: Double = 0.8
    ) {
        self.countdown = countdown
        self.intervalEnd = intervalEnd
        self.roundEnd = roundEnd
        self.finish = finish
        self.breathingGuide = breathingGuide
        self.haptics = haptics
        self.volume = volume
    }

    public static func defaults(for kind: TemplateKind) -> SoundSettings {
        switch kind {
        case .emom, .tabata:
            SoundSettings()
        case .breathing:
            SoundSettings(countdown: .off, intervalEnd: .off, roundEnd: .off, finish: .bell,
                          breathingGuide: true, haptics: false, volume: 0.6)
        case .custom:
            SoundSettings(countdown: .last3, intervalEnd: .chime, roundEnd: .bell, finish: .bell)
        }
    }
}
