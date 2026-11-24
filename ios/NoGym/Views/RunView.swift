import AVFoundation
import NoGymKit
import SwiftUI
import UIKit

/// The run screen. The current label is the biggest thing on it, the next
/// label comes second, and the countdown and progress bar sit between them.
/// When the sequence has a video, a second page loops the exercise's part of it.
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

/// The two pages of the run screen. Swiping either way flips between them.
private enum RunPage {
    case timer, video

    var other: RunPage { self == .timer ? .video : .timer }
}

private struct RunScreen: View {
    let session: RunSession
    let onStop: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @State private var isConfirmingStop = false

    // Video page
    /// Nil when the sequence has no video.
    @State private var looper: SegmentLooper?
    @State private var page: RunPage = .timer
    /// The segment for the current position, or nil when this exercise has none.
    @State private var segment: VideoSegment?
    /// True until you swipe to the timer. While it's true, the video page comes back
    /// on its own when an exercise with a video starts.
    @State private var prefersVideo = true
    /// How far the pages are pushed sideways, by a finger or an animation.
    @State private var offset: CGFloat = 0
    @State private var isFlipping = false
    @State private var pageWidth: CGFloat = 400
    @State private var showsVideoControls = false

    private var canShowVideo: Bool { looper != nil && segment != nil }

    var body: some View {
        // Redraws every frame while running, straight from the clock.
        TimelineView(.animation(minimumInterval: 1 / 30, paused: session.isPaused)) { context in
            let position = session.position(at: context.date)
            pages(position)
                .onChange(of: session.routine.videoSegment(at: position, in: session.timeline), initial: true) { _, new in
                    segment = new
                    looper?.show(new)
                    settlePage(animated: true)
                }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { pageWidth = max(1, $0) }
        .onAppear(perform: setUpVideo)
        .onDisappear { looper?.stop() }
        // Video stops while the app is in the background; start it again on return.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { looper?.setPaused(session.isPaused) }
        }
        .onChange(of: session.isPaused) { _, paused in
            looper?.setPaused(paused)
            if paused { showsVideoControls = true }
        }
        .confirmationDialog("End this sequence?", isPresented: $isConfirmingStop, titleVisibility: .visible) {
            Button("End", role: .destructive, action: onStop)
            Button("Keep going", role: .cancel) {}
        }
    }

    // MARK: - Paging

    private func pages(_ position: RunPosition) -> some View {
        ZStack {
            timerPage(position)
                .offset(x: offset(for: .timer))
            if let looper {
                videoPage(position, player: looper.player)
                    .offset(x: offset(for: .video))
                    // Kept alive off screen, so it's already playing when you swipe to it.
                    .opacity(canShowVideo || page == .video ? 1 : 0)
            }
        }
        .overlay(alignment: .top) {
            if canShowVideo { PageDots(page: page) }
        }
        .contentShape(Rectangle())
        .gesture(swipe, including: canShowVideo && !isFlipping ? .all : .subviews)
        .accessibilityAction(named: page == .timer ? "Show video" : "Show timer") {
            if canShowVideo { flip(direction: -1, byUser: true) }
        }
    }

    /// The page you're on sits at `offset`. The other one waits just off the side
    /// you're swiping towards, so swiping either way brings it in.
    private func offset(for candidate: RunPage) -> CGFloat {
        if candidate == page { return offset }
        return offset + (offset <= 0 ? pageWidth : -pageWidth)
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                offset = value.translation.width
            }
            .onEnded { value in
                let distance = value.predictedEndTranslation.width
                if abs(distance) > pageWidth * 0.4 || abs(value.translation.width) > pageWidth * 0.5 {
                    flip(direction: distance < 0 ? -1 : 1, byUser: true)
                } else {
                    withAnimation(.snappy) { offset = 0 }
                }
            }
    }

    /// Slides the other page in. -1 moves the pages to the left, 1 to the right.
    private func flip(direction: CGFloat, byUser: Bool) {
        let target = page.other
        if byUser { prefersVideo = target == .video }
        isFlipping = true
        withAnimation(.snappy(duration: 0.3)) {
            offset = direction * pageWidth
        } completion: {
            page = target
            offset = 0
            isFlipping = false
            if target == .video { showsVideoControls = session.isPaused }
            // The segment may have changed while the pages were moving.
            settlePage(animated: true)
        }
    }

    /// Hides the video page when the exercise has no video, and brings it back
    /// when one does, unless you swiped to the timer yourself.
    private func settlePage(animated: Bool) {
        guard !isFlipping else { return }
        let target: RunPage = canShowVideo && prefersVideo ? .video : .timer
        guard target != page else { return }
        if animated {
            // Going back to the timer slides right, like going back; the video comes in from the right.
            flip(direction: target == .timer ? 1 : -1, byUser: false)
        } else {
            page = target
        }
    }

    private func setUpVideo() {
        guard looper == nil, let video = session.routine.video else { return }
        let url = VideoLibrary.url(for: video)
        guard FileManager.default.fileExists(atPath: url.path()) else { return }
        let looper = SegmentLooper(url: url)
        self.looper = looper
        segment = session.routine.videoSegment(at: session.position(at: .now), in: session.timeline)
        looper.show(segment)
        looper.setPaused(session.isPaused)
        // Always start on the video when the first exercise has one.
        settlePage(animated: false)
    }

    // MARK: - Timer page

    private func timerPage(_ position: RunPosition) -> some View {
        let timeline = session.timeline
        let step = timelineStep(position.stepIndex)
        let upcoming = timelineStep(position.stepIndex + 1)
        let role = step?.interval.role
        let color = role?.color ?? .orange
        let ending = isEnding(position)

        return VStack(spacing: 20) {
            header(step: step)

            Spacer(minLength: 0)

            // Current label
            VStack(spacing: 8) {
                roleTag(step: step, color: color)
                currentLabel(step: step, position: position, size: 60)
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
        .background {
            ZStack {
                Color(uiColor: .systemBackground)
                color.opacity(0.08)
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Video page

    /// The looping video with the exercise and countdown on top. Tap to show the rest.
    private func videoPage(_ position: RunPosition, player: AVPlayer) -> some View {
        let step = timelineStep(position.stepIndex)
        let upcoming = timelineStep(position.stepIndex + 1)
        let color = step?.interval.role.color ?? .orange
        let ending = isEnding(position)

        return ZStack {
            VideoSurface(player: player)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            // Darkens the top and bottom so the text reads on any video.
            LinearGradient(colors: [.black.opacity(0.55), .clear, .clear, .black.opacity(0.7)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 16) {
                if showsVideoControls {
                    header(step: step)
                        .transition(.opacity)
                }

                Spacer(minLength: 0)

                VStack(spacing: 4) {
                    if showsVideoControls { roleTag(step: step, color: color).transition(.opacity) }
                    currentLabel(step: step, position: position, size: 44)
                    Text(Format.clock(position.remaining))
                        .font(.system(size: 80, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(ending ? Color.orange : Color.white)
                        .accessibilityAddTraits(.updatesFrequently)
                }
                .shadow(color: .black.opacity(0.6), radius: 8)

                if showsVideoControls {
                    VStack(spacing: 16) {
                        ProgressBar(fraction: position.fraction, color: ending ? .orange : color)
                            .frame(height: 10)
                        NextCard(upcoming: upcoming, isPrep: position.phase == .prep)
                        controls
                    }
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .foregroundStyle(.white)
        }
        .environment(\.colorScheme, .dark)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.25)) { showsVideoControls.toggle() }
        }
        // Fades the controls out again after a few seconds, unless paused.
        .task(id: showsVideoControls && !session.isPaused) {
            guard showsVideoControls, !session.isPaused else { return }
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.4)) { showsVideoControls = false }
        }
    }

    // MARK: - Shared parts

    private func timelineStep(_ index: Int) -> Step? {
        session.timeline.steps.indices.contains(index) ? session.timeline.steps[index] : nil
    }

    private func isEnding(_ position: RunPosition) -> Bool {
        position.displaySeconds <= 3 && position.phase == .active
    }

    private func roleTag(step: Step?, color: Color) -> some View {
        Text(step.map { $0.interval.role.title.uppercased() } ?? "GET READY")
            .font(.subheadline.weight(.bold))
            .tracking(2)
            .foregroundStyle(color)
    }

    private func currentLabel(step: Step?, position: RunPosition, size: CGFloat) -> some View {
        Text(step?.interval.displayLabel ?? (position.phase == .done ? "Done" : "Get ready"))
            .font(.system(size: size, weight: .bold))
            .minimumScaleFactor(0.4)
            .lineLimit(3)
            .multilineTextAlignment(.center)
            .contentTransition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: position.stepIndex)
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

/// Two dots that show which page you're on, and that there's another one.
private struct PageDots: View {
    let page: RunPage

    var body: some View {
        HStack(spacing: 6) {
            Circle().frame(width: 7, height: 7).opacity(page == .timer ? 1 : 0.4)
            Circle().frame(width: 7, height: 7).opacity(page == .video ? 1 : 0.4)
        }
        .foregroundStyle(page == .video ? Color.white : Color.secondary)
        .padding(.top, 2)
        .accessibilityHidden(true)
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
