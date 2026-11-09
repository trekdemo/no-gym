import NoGymKit
import SwiftUI

/// Create or edit a sequence. The middle of the form depends on the template.
struct RoutineEditorView: View {
    @Environment(RoutineStore.self) private var store
    @State private var draft: Routine
    @State private var error: String?
    @State private var isConfirmingDelete = false
    let isNew: Bool
    let onFinish: () -> Void

    init(routine: Routine, isNew: Bool, onFinish: @escaping () -> Void) {
        _draft = State(initialValue: routine)
        self.isNew = isNew
        self.onFinish = onFinish
    }

    var body: some View {
        Form {
            Section {
                TextField("Title", text: $draft.title, prompt: Text(placeholderTitle))
                    .font(.headline)
                TextField("Notes (optional)", text: $draft.notes, axis: .vertical)
                    .lineLimit(1...4)
            }

            switch draft.template.kind {
            case .emom: EmomSection(config: $draft.template.emomConfig)
            case .tabata: TabataSection(config: $draft.template.tabataConfig)
            case .breathing: BreathingSection(config: $draft.template.breathingConfig)
            case .custom: CustomSection(intervals: $draft.template.customIntervals)
            }

            Section {
                Stepper(value: $draft.rounds, in: 1...99) {
                    LabeledContent(draft.template.kind == .breathing ? "Breaths" : "Rounds",
                                   value: "\(draft.rounds)")
                }
                SecondsStepper(title: "Get ready", value: $draft.prepSeconds, range: 0...60, step: 5)
                LabeledContent("Total time", value: Format.clock(draft.totalSeconds))
                    .monospacedDigit()
            } footer: {
                Text("The whole list repeats for each round.")
            }

            Section {
                NavigationLink {
                    SoundSettingsView(sound: $draft.sound)
                } label: {
                    Label("Sounds", systemImage: "speaker.wave.2")
                }
            }

            if !isNew {
                Section {
                    Button("Delete sequence", role: .destructive) { isConfirmingDelete = true }
                }
            }
        }
        .navigationTitle(isNew ? "New \(draft.template.kind.title)" : "Edit sequence")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isNew {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onFinish)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save).bold()
            }
        }
        .alert("Can't save yet", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
        .confirmationDialog("Delete \(draft.title)?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                store.delete(id: draft.id)
                onFinish()
            }
        }
    }

    private var placeholderTitle: String {
        switch draft.template.kind {
        case .emom: "Morning EMOM"
        case .tabata: "Leg day Tabata"
        case .breathing: "Calm down"
        case .custom: "Evening stretch"
        }
    }

    private func save() {
        var routine = draft
        routine.title = routine.title.trimmingCharacters(in: .whitespacesAndNewlines)
        routine.notes = routine.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if let message = routine.validationError() {
            error = message
            return
        }
        store.save(routine)
        onFinish()
    }
}

/// A stepper for seconds that shows "45 s" or "1 min 30 s".
struct SecondsStepper: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 5

    var body: some View {
        Stepper(value: $value, in: range, step: step) {
            LabeledContent(title, value: Format.duration(value))
                .monospacedDigit()
        }
    }
}
