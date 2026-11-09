import NoGymKit
import SwiftUI

/// The run screen. The current label is the biggest thing on it, the next
/// label comes second, and the countdown and progress bar sit between them.
struct RunView: View {
    let routine: Routine
    let onClose: () -> Void
    @State private var session: RunSession?

    var body: some View {
        Group {
            if let session {
                if session.isFinished {
                    DoneView(routine: routine, onClose: onClose)
                } else {
                    RunScreen(session: session, onStop: onClose)
                }
            } else {
                Color.clear
            }
        }
        .onAppear {
            guard session == nil else { return }
            let session = RunSession(routine: routine)
            self.session = session
            session.start()
        }
        .onDisappear { session?.stop() }
    }
}

private struct RunScreen: View {
    let session: RunSession
    let onStop: () -> Void
    @State private var isConfirmingStop = false

    var body: some View {
        // Redraws every frame while running, straight from the clock.
        TimelineView(.animation(minimumInterval: 1 / 30, paused: session.isPaused)) { context in
            let position = session.position(at: context.date)
            content(position)
        }
        .confirmationDialog("End this sequence?", isPresented: $isConfirmingStop, titleVisibility: .visible) {
            Button("End", role: .destructive, action: onStop)
            Button("Keep going", role: .cancel) {}
        }
    }

    private func content(_ position: RunPosition) -> some View {
        let timeline = session.timeline
        let step = timeline.steps.indices.contains(position.stepIndex) ? timeline.steps[position.stepIndex] : nil
        let upcomingIndex = position.stepIndex + 1
        let upcoming = timeline.steps.indices.contains(upcomingIndex) ? timeline.steps[upcomingIndex] : nil
        let role = step?.interval.role
        let color = role?.color ?? .orange
        let ending = position.displaySeconds <= 3 && position.phase == .active

        return VStack(spacing: 20) {
            header(step: step)

            Spacer(minLength: 0)

            // Current label
            VStack(spacing: 8) {
                Text(step.map { $0.interval.role.title.uppercased() } ?? "GET READY")
                    .font(.subheadline.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(color)
                Text(step?.interval.displayLabel ?? (position.phase == .done ? "Done" : "Get ready"))
                    .font(.system(size: 60, weight: .bold))
                    .minimumScaleFactor(0.4)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: position.stepIndex)
            }
            .frame(maxWidth: .infinity)

            if let role, role.isBreathing {
                BreathingCircle(scale: timeline.breathScale(stepIndex: position.stepIndex, fraction: position.fraction),
                                color: color)
                    .frame(height: 180)
            }

            // Countdown
            Text(Format.clock(position.remaining))
                .font(.system(size: 96, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(ending ? Color.orange : Color.primary)
                .accessibilityAddTraits(.updatesFrequently)

            ProgressBar(fraction: position.fraction, color: ending ? .orange : color)
                .frame(height: 14)

            // Next label
            NextCard(upcoming: upcoming, isPrep: position.phase == .prep)

            Spacer(minLength: 0)

            controls
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(color.opacity(0.08).ignoresSafeArea())
    }

    private func header(step: Step?) -> some View {
        let timeline = session.timeline
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.routine.title).font(.headline)
                Group {
                    if let step {
                        Text("Round \(step.round) of \(timeline.rounds) · Step \(step.indexInRound + 1) of \(timeline.stepsPerRound)")
                    } else {
                        Text("\(Format.plural(timeline.rounds, "round")) · \(Format.clock(timeline.workDuration))")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
            Spacer()
            if session.isPaused {
                Text("PAUSED")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(.orange, in: Capsule())
                    .foregroundStyle(.white)
            }
        }
    }

    private var controls: some View {
        HStack {
            controlButton("xmark", label: "Stop", size: 56) { isConfirmingStop = true }
            Spacer()
            controlButton("backward.end.fill", label: "Previous", size: 56) { session.skipBackward() }
            Spacer()
            Button {
                session.togglePause()
            } label: {
                Image(systemName: session.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 34, weight: .bold))
                    .frame(width: 88, height: 88)
                    .background(session.isPaused ? Color.green : Color.orange, in: Circle())
                    .foregroundStyle(.white)
            }
            .accessibilityLabel(session.isPaused ? "Resume" : "Pause")
            Spacer()
            controlButton("forward.end.fill", label: "Next", size: 56) { session.skipForward() }
            Spacer()
            // Keeps the play button centred.
            Color.clear.frame(width: 56, height: 56)
        }
        .buttonStyle(.plain)
    }

    private func controlButton(_ symbol: String, label: String, size: CGFloat,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .frame(width: size, height: size)
                .background(.thinMaterial, in: Circle())
        }
        .accessibilityLabel(label)
    }
}

private struct NextCard: View {
    let upcoming: Step?
    let isPrep: Bool

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(upcoming?.interval.role.color ?? .secondary)
                .frame(width: 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(isPrep ? "FIRST" : "NEXT")
                    .font(.caption.weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                Text(upcoming?.interval.displayLabel ?? "Last one!")
                    .font(.title.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
            }
            Spacer()
            if let upcoming {
                Text(Format.duration(upcoming.duration))
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 88)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 18))
    }
}

/// Fills from left to right as the current interval passes.
private struct ProgressBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.2))
                Capsule().fill(color).frame(width: geometry.size.width * fraction)
            }
        }
        .accessibilityHidden(true)
    }
}

/// A circle that grows as you breathe in and shrinks as you breathe out.
struct BreathingCircle: View {
    let scale: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.25), lineWidth: 2)
            Circle()
                .fill(color.gradient)
                .scaleEffect(scale)
                .shadow(color: color.opacity(0.4), radius: 20 * scale)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

private struct DoneView: View {
    let routine: Routine
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 96))
                .foregroundStyle(.green)
            Text("Done!").font(.largeTitle.bold())
            Text("\(routine.title) · \(Format.summary(routine))")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button(action: onClose) {
                Text("Back to sequences").bold().frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }
}
