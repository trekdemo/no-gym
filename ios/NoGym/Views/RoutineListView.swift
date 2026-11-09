import NoGymKit
import SwiftUI

/// The home screen: your saved sequences.
struct RoutineListView: View {
    @Environment(RoutineStore.self) private var store
    @State private var isCreating = false
    @State private var editing: Routine?
    @State private var running: Routine?

    var body: some View {
        NavigationStack {
            List {
                if let error = store.lastError {
                    Text(error).foregroundStyle(.red)
                }
                ForEach(store.routines) { routine in
                    RoutineRow(routine: routine) { running = routine }
                        .contentShape(Rectangle())
                        .onTapGesture { editing = routine }
                }
                .onDelete(perform: store.delete(at:))
                .onMove(perform: store.move(from:to:))
            }
            .overlay {
                if store.routines.isEmpty {
                    ContentUnavailableView("No sequences yet", systemImage: "timer",
                                           description: Text("Tap + to make your first one."))
                }
            }
            .navigationTitle("No Gym")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .primaryAction) {
                    Button("New sequence", systemImage: "plus") { isCreating = true }
                }
            }
            .sheet(isPresented: $isCreating) {
                NewRoutineFlow()
            }
            .sheet(item: $editing) { routine in
                NavigationStack {
                    RoutineEditorView(routine: routine, isNew: false) { editing = nil }
                }
            }
            .fullScreenCover(item: $running) { routine in
                RunView(routine: routine) { running = nil }
            }
        }
    }
}

private struct RoutineRow: View {
    let routine: Routine
    let onStart: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(routine.title).font(.headline)
                if !routine.notes.isEmpty {
                    Text(routine.notes).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                }
                HStack(spacing: 6) {
                    Label(routine.template.kind.title, systemImage: routine.template.kind.symbol)
                    Text("·")
                    Text(Format.summary(routine)).monospacedDigit()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onStart) {
                Image(systemName: "play.fill")
                    .font(.title3)
                    .frame(width: 48, height: 48)
                    .background(Color.accentColor, in: Circle())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start \(routine.title)")
        }
        .padding(.vertical, 4)
    }
}

/// "New sequence": pick a template, then fill in the editor.
private struct NewRoutineFlow: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TemplatePickerView()
                .navigationDestination(for: TemplateKind.self) { kind in
                    RoutineEditorView(
                        routine: Routine(title: "", template: .starter(kind), rounds: Template.starterRounds(kind)),
                        isNew: true
                    ) { dismiss() }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
    }
}
