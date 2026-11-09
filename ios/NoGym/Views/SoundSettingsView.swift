import NoGymKit
import SwiftUI

/// The sounds of one sequence. Picking a sound plays it, so you can hear the choice.
struct SoundSettingsView: View {
    @Binding var sound: SoundSettings
    @State private var player = CuePlayer()

    var body: some View {
        Form {
            Section {
                Picker("Countdown", selection: $sound.countdown) {
                    ForEach(CountdownStyle.allCases) { Text($0.title).tag($0) }
                }
                previewRow("Tick", kind: .countdown)
            } footer: {
                Text("Short ticks before each interval ends.")
            }

            Section {
                soundPicker("Interval ends", selection: $sound.intervalEnd, boundary: .interval)
                soundPicker("Round ends", selection: $sound.roundEnd, boundary: .round)
                soundPicker("Sequence done", selection: $sound.finish, boundary: .finish)
            } footer: {
                Text("When two sounds fall at the same moment, the bigger event wins: done, then round, then interval. If a sound is None, the next one down plays instead.")
            }

            Section {
                Toggle("Breathing guide", isOn: $sound.breathingGuide)
                if sound.breathingGuide {
                    previewRow("Inhale", kind: .breathe(.inhale, duration: 4))
                    previewRow("Hold", kind: .breathe(.hold, duration: 4))
                    previewRow("Exhale", kind: .breathe(.exhale, duration: 4))
                }
            } footer: {
                Text("A rising tone while you breathe in, a falling tone while you breathe out, and a soft low tone when you hold. Plays on Inhale, Hold and Exhale intervals.")
            }

            Section {
                LabeledContent("Volume") {
                    Slider(value: $sound.volume, in: 0...1, onEditingChanged: { editing in
                        if !editing { player.preview(.boundary(.interval, sound.intervalEnd == .off ? .beep : sound.intervalEnd)) }
                    })
                }
                Toggle("Vibrate on each interval", isOn: $sound.haptics)
            } footer: {
                Text("Sounds mix with your music. The ring/silent switch doesn't mute them, so turn the volume down with the side buttons if you need to.")
            }
        }
        .navigationTitle("Sounds")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { player.volume = sound.volume }
        .onChange(of: sound.volume) { _, volume in player.volume = volume }
        .onDisappear { player.deactivate() }
    }

    private func soundPicker(_ title: String, selection: Binding<SoundChoice>, boundary: Boundary) -> some View {
        Picker(title, selection: selection) {
            ForEach(SoundChoice.allCases) { Text($0.title).tag($0) }
        }
        .onChange(of: selection.wrappedValue) { _, choice in
            player.preview(.boundary(boundary, choice))
        }
    }

    private func previewRow(_ title: String, kind: CueKind) -> some View {
        Button {
            player.preview(kind)
        } label: {
            Label("Play \(title.lowercased())", systemImage: "play.circle")
        }
    }
}
