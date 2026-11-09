import Foundation
import NoGymKit
import Observation
import SwiftUI

/// Keeps the saved sequences in a JSON file in the app's Documents folder.
/// Screens read `routines`, and SwiftUI redraws them when it changes.
@MainActor
@Observable
final class RoutineStore {
    private(set) var routines: [Routine] = []
    /// Set when the file can't be read or written, so a screen can show it.
    var lastError: String?

    private let fileURL: URL

    init(fileURL: URL = URL.documentsDirectory.appending(path: "routines.json")) {
        self.fileURL = fileURL
        load()
    }

    func routine(id: Routine.ID) -> Routine? {
        routines.first { $0.id == id }
    }

    /// Adds a new routine, or replaces the saved one with the same id.
    func save(_ routine: Routine) {
        if let index = routines.firstIndex(where: { $0.id == routine.id }) {
            routines[index] = routine
        } else {
            routines.append(routine)
        }
        write()
    }

    func delete(id: Routine.ID) {
        routines.removeAll { $0.id == id }
        write()
    }

    func delete(at offsets: IndexSet) {
        routines.remove(atOffsets: offsets)
        write()
    }

    func move(from source: IndexSet, to destination: Int) {
        routines.move(fromOffsets: source, toOffset: destination)
        write()
    }

    // MARK: - File

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path()) else {
            // First launch: start with one example of each template.
            routines = Self.examples
            write()
            return
        }
        do {
            routines = try JSONDecoder().decode([Routine].self, from: Data(contentsOf: fileURL))
        } catch {
            lastError = "Could not read saved sequences: \(error.localizedDescription)"
        }
    }

    private func write() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(routines).write(to: fileURL, options: .atomic)
            lastError = nil
        } catch {
            lastError = "Could not save: \(error.localizedDescription)"
        }
    }

    static let examples: [Routine] = [
        Routine(
            title: "Morning EMOM",
            notes: "Kettlebell or bodyweight.",
            template: .emom(EmomConfig(exercises: [
                Exercise(name: "Deadlifts", reps: 10),
                Exercise(name: "Sit-ups", reps: 10),
                Exercise(name: "Rest"),
            ])),
            rounds: 3
        ),
        Routine(
            title: "Classic Tabata",
            template: .tabata(TabataConfig(exercises: ["Squats", "Push-ups", "Mountain climbers", "Burpees"])),
            rounds: 8
        ),
        Routine(
            title: "Box breathing",
            notes: "Breathe in through the nose, out through the mouth.",
            template: .breathing(.box),
            rounds: 8,
            prepSeconds: 5
        ),
        Routine(
            title: "Evening stretch",
            template: .custom([
                Interval(label: "Child's pose", seconds: 45),
                Interval(label: "Switch", seconds: 5, role: .rest),
                Interval(label: "Pigeon, left", seconds: 45),
                Interval(label: "Switch", seconds: 5, role: .rest),
                Interval(label: "Pigeon, right", seconds: 45),
                Interval(label: "Switch", seconds: 5, role: .rest),
                Interval(label: "Forward fold", seconds: 60),
            ]),
            rounds: 1
        ),
    ]
}
