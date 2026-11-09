import NoGymKit
import SwiftUI
import UIKit

// The template-specific part of the editor. Each section edits its template's config.

// MARK: - EMOM

struct EmomSection: View {
    @Binding var config: EmomConfig
    @State private var pasted = ""
    @State private var copied = false

    var body: some View {
        Section {
            SecondsStepper(title: "Each step", value: $config.stepSeconds, range: 10...600, step: 5)
        } footer: {
            Text("Usually one minute. The exercise starts at the top of each step; the rest of the step is rest.")
        }

        Section {
            ForEach($config.exercises, editActions: .all) { $exercise in
                HStack {
                    TextField("Exercise", text: $exercise.name)
                    TextField("Reps", text: repsText($exercise.reps))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 56)
                }
            }
            Button("Add exercise", systemImage: "plus") {
                config.exercises.append(Exercise(name: "", reps: 10))
            }
        } header: {
            Text("Exercises · one per step")
        } footer: {
            Text("Leave reps empty for things you don't count, like Rest. Swipe to delete, hold and drag to reorder.")
        }

        Section("Paste as text") {
            TextField("Min 1: 10 Deadlifts\nMin 2: 10 Sit-ups\nMin 3: Rest", text: $pasted, axis: .vertical)
                .lineLimit(3...8)
                .font(.callout.monospaced())
            Button("Replace exercises") {
                let exercises = Format.parseExercises(pasted)
                guard !exercises.isEmpty else { return }
                config.exercises = exercises
                pasted = ""
            }
            .disabled(pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button(copied ? "Copied!" : "Copy exercises as text") {
                UIPasteboard.general.string = Format.formatExercises(config.exercises)
                copied = true
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    copied = false
                }
            }
        }
    }
}

/// Edits an optional whole number as text: empty means no reps.
func repsText(_ reps: Binding<Int?>) -> Binding<String> {
    Binding(
        get: { reps.wrappedValue.map(String.init) ?? "" },
        set: { reps.wrappedValue = Int($0.filter(\.isNumber)) }
    )
}

// MARK: - Tabata

struct TabataSection: View {
    @Binding var config: TabataConfig

    var body: some View {
        Section("Intervals") {
            SecondsStepper(title: "Work", value: $config.workSeconds, range: 5...600, step: 5)
            SecondsStepper(title: "Rest", value: $config.restSeconds, range: 0...600, step: 5)
        }
        Section {
            TextField("Squats\nPush-ups", text: exerciseLines, axis: .vertical)
                .lineLimit(2...8)
        } header: {
            Text("Exercises (optional)")
        } footer: {
            Text("One per line. Each round moves on to the next one. Leave empty to show “Work”.")
        }
    }

    private var exerciseLines: Binding<String> {
        Binding(
            get: { config.exercises.joined(separator: "\n") },
            // Empty lines are kept while you type; the template skips them.
            set: { config.exercises = $0.components(separatedBy: "\n") }
        )
    }
}

// MARK: - Breathing

struct BreathingSection: View {
    @Binding var config: BreathingConfig

    var body: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(BreathingConfig.presets, id: \.name) { preset in
                        Button(preset.name) { config = preset.config }
                            .buttonStyle(.bordered)
                            .tint(config == preset.config ? Color.accentColor : Color.secondary)
                    }
                }
            }
        } header: {
            Text("Presets")
        }
        Section {
            SecondsStepper(title: "Inhale", value: $config.inhale, range: 1...20, step: 0.5)
            SecondsStepper(title: "Hold", value: $config.holdIn, range: 0...30, step: 0.5)
            SecondsStepper(title: "Exhale", value: $config.exhale, range: 1...20, step: 0.5)
            SecondsStepper(title: "Hold", value: $config.holdOut, range: 0...30, step: 0.5)
        } header: {
            Text("One breath · \(Format.duration(config.cycleSeconds))")
        } footer: {
            Text("A hold of 0 s is skipped.")
        }
    }
}

// MARK: - Custom

struct CustomSection: View {
    @Binding var intervals: [Interval]

    var body: some View {
        Section {
            ForEach($intervals, editActions: .all) { $interval in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("Label", text: $interval.label)
                            .font(.headline)
                        Picker("Type", selection: $interval.role) {
                            ForEach(Role.allCases, id: \.self) { role in
                                Text(role.title).tag(role)
                            }
                        }
                        .labelsHidden()
                        .tint(interval.role.color)
                    }
                    SecondsStepper(title: "Duration", value: $interval.seconds, range: 1...3600,
                                   step: interval.seconds < 10 ? 1 : 5)
                    TextField("Reps (optional)", text: repsText($interval.reps))
                        .keyboardType(.numberPad)
                        .font(.subheadline)
                }
                .padding(.vertical, 4)
            }
            Button("Add interval", systemImage: "plus") {
                let last = intervals.last
                intervals.append(Interval(label: "", seconds: last?.seconds ?? 30, role: last?.role ?? .work))
            }
        } header: {
            Text("Intervals · one round")
        } footer: {
            Text("The type sets the colour. Inhale, Hold and Exhale also play breathing tones. Swipe to delete, hold and drag to reorder.")
        }
    }
}
