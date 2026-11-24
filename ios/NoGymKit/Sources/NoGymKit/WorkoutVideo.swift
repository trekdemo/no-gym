import Foundation

/// A part of a video, from `start` to `end` seconds. It loops on the run screen
/// while its exercise runs.
public struct VideoSegment: Codable, Hashable, Sendable {
    public var start: Double
    public var end: Double

    /// The shortest segment the trimmer allows.
    public static let minimumLength: Double = 0.5

    public init(start: Double, end: Double) {
        self.start = start
        self.end = end
    }

    public var length: Double { end - start }

    /// Keeps the segment inside a video of `duration` seconds and at least `minimumLength` long.
    /// A video shorter than `minimumLength` gets a segment covering all of it.
    public func clamped(to duration: Double) -> VideoSegment {
        let duration = max(0, duration)
        let minimum = min(Self.minimumLength, duration)
        let start = min(max(0, self.start), duration - minimum)
        let end = min(duration, max(self.end, start + minimum))
        return VideoSegment(start: start, end: end)
    }

    /// A first guess for a new segment: a few seconds from `start`, inside the video.
    public static func starter(at start: Double, duration: Double) -> VideoSegment {
        VideoSegment(start: start, end: start + 5).clamped(to: duration)
    }
}

/// The video attached to a sequence, and which part of it each exercise shows.
///
/// Segments belong to exercise names, not to single intervals: every interval
/// with the same label (ignoring case and surrounding spaces) shows the same segment,
/// in every round.
public struct WorkoutVideo: Codable, Hashable, Sendable {
    /// The video's file name in the app's own video folder. The app keeps its own copy.
    public var fileName: String
    /// Length of the whole video, in seconds.
    public var duration: Double
    /// Segments by exercise key (see `key(for:)`).
    public var segments: [String: VideoSegment]

    public init(fileName: String, duration: Double, segments: [String: VideoSegment] = [:]) {
        self.fileName = fileName
        self.duration = duration
        self.segments = segments
    }

    /// "  Push-Ups " and "push-ups" are the same exercise.
    public static func key(for label: String) -> String {
        label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    public func segment(for label: String) -> VideoSegment? {
        segments[Self.key(for: label)]
    }

    /// Sets or, with nil, clears the segment for an exercise. The segment is clamped to the video.
    public mutating func setSegment(_ segment: VideoSegment?, for label: String) {
        segments[Self.key(for: label)] = segment?.clamped(to: duration)
    }

    /// Drops the segments of exercises that are no longer in the sequence.
    public mutating func removeSegments(except labels: [String]) {
        let keep = Set(labels.map(Self.key(for:)))
        segments = segments.filter { keep.contains($0.key) }
    }
}

extension Timeline {
    /// Each different label once, in the order they first appear. These are the
    /// exercises the video editor lists. Tabata names from later rounds are included.
    public var exerciseLabels: [String] {
        var seen = Set<String>()
        var labels: [String] = []
        for step in steps {
            let label = step.interval.label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty, seen.insert(WorkoutVideo.key(for: label)).inserted else { continue }
            labels.append(label)
        }
        return labels
    }
}

extension Routine {
    /// The segment to loop at a run position, or nil when there's nothing to show.
    /// During prep it's the first step's segment, so you can watch what's coming.
    public func videoSegment(at position: RunPosition, in timeline: Timeline) -> VideoSegment? {
        guard let video else { return nil }
        let index: Int
        switch position.phase {
        case .prep: index = 0
        case .active: index = position.stepIndex
        case .done: return nil
        }
        guard timeline.steps.indices.contains(index) else { return nil }
        return video.segment(for: timeline.steps[index].interval.label)
    }
}
