import Foundation

public enum Format {
    /// "0:05", "4:00", "1:02:03". Rounds up, like the countdown.
    public static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, secs) }
        return String(format: "%d:%02d", minutes, secs)
    }

    /// "20 s", "1 min", "1 min 30 s", "5.5 s".
    public static func duration(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return seconds.rounded() == seconds ? "\(Int(seconds)) s" : String(format: "%.1f s", seconds)
        }
        let whole = Int(seconds.rounded())
        let minutes = whole / 60
        let rest = whole % 60
        return rest == 0 ? "\(minutes) min" : "\(minutes) min \(rest) s"
    }

    public static func plural(_ count: Int, _ noun: String) -> String {
        "\(count) \(noun)\(count == 1 ? "" : "s")"
    }

    /// "8 rounds · 4:00"
    public static func summary(_ routine: Routine) -> String {
        "\(plural(routine.rounds, "round")) · \(clock(routine.totalSeconds))"
    }

    // MARK: - EMOM paste format, as in the HTML prototype

    /// Reads one exercise per line, like "Min 1: 10 Deadlifts" or "Min 8: REST".
    /// The "Min N:" prefix is optional and ignored; the line order sets the order.
    public static func parseExercises(_ text: String) -> [Exercise] {
        text.split(whereSeparator: \.isNewline).compactMap { rawLine in
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            if let prefix = line.range(of: #"^min(ute)?\s*\d+\s*[:.\-–]\s*"#, options: [.regularExpression, .caseInsensitive]) {
                line.removeSubrange(prefix)
            }
            guard !line.isEmpty else { return nil }
            if let counted = line.range(of: #"^\d+\s*[x×]?\s+"#, options: [.regularExpression, .caseInsensitive]) {
                let digits = line[counted].prefix { $0.isNumber }
                let name = line[counted.upperBound...].trimmingCharacters(in: .whitespaces)
                if let reps = Int(digits), !name.isEmpty { return Exercise(name: name, reps: reps) }
            }
            return Exercise(name: line)
        }
    }

    /// The reverse of `parseExercises`: "<reps> <name>" per line, or just the name.
    public static func formatExercises(_ exercises: [Exercise]) -> String {
        exercises.map { exercise in
            (exercise.reps.map { "\($0) \(exercise.name)" } ?? exercise.name) + "\n"
        }.joined()
    }
}
