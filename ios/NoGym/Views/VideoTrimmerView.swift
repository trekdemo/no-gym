import NoGymKit
import SwiftUI

/// Picks the part of the sequence's video that loops while one exercise runs.
/// Drag the yellow handles to set the start and end, or drag the middle to move the whole part.
struct VideoTrimmerView: View {
    let video: WorkoutVideo
    let label: String
    let onSave: (VideoSegment?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var segment: VideoSegment
    @State private var preview: TrimPreview
    private let hadSegment: Bool

    init(video: WorkoutVideo, label: String, onSave: @escaping (VideoSegment?) -> Void) {
        self.video = video
        self.label = label
        self.onSave = onSave
        let existing = video.segment(for: label)
        hadSegment = existing != nil
        // A new part starts where the furthest one so far ends: demo videos are usually in order.
        let start = video.segments.values.map(\.end).max() ?? 0
        let initial = existing ?? VideoSegment.starter(at: start < video.duration ? start : 0, duration: video.duration)
        _segment = State(initialValue: initial)
        _preview = State(initialValue: TrimPreview(url: VideoLibrary.url(for: video), segment: initial))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VideoSurface(player: preview.player)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .frame(maxHeight: .infinity)

                HStack {
                    timeLabel("Start", segment.start)
                    Spacer()
                    VStack(spacing: 2) {
                        Text("Length").font(.caption).foregroundStyle(.secondary)
                        Text(String(format: "%.1f s", segment.length)).font(.headline).monospacedDigit()
                    }
                    Spacer()
                    timeLabel("End", segment.end)
                }

                TrimBar(url: VideoLibrary.url(for: video), duration: video.duration, segment: $segment,
                        playhead: preview.currentTime,
                        onScrub: preview.scrub(to:),
                        onScrubEnd: preview.loop)
                    .frame(height: 60)

                HStack(spacing: 16) {
                    nudge("Start", value: \.start)
                    nudge("End", value: \.end)
                }

                if hadSegment {
                    Button("Remove video for \(label)", role: .destructive) {
                        onSave(nil)
                        dismiss()
                    }
                }
            }
            .padding()
            .navigationTitle(label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave(segment)
                        dismiss()
                    }
                    .bold()
                }
            }
        }
        .onAppear { preview.start() }
        .onDisappear { preview.stop() }
    }

    private func timeLabel(_ title: String, _ seconds: Double) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(Format.timecode(seconds)).font(.headline).monospacedDigit()
        }
    }

    /// −/+ buttons that move one edge by a tenth of a second, for fine tuning.
    private func nudge(_ title: String, value: WritableKeyPath<VideoSegment, Double>) -> some View {
        HStack(spacing: 4) {
            Button { move(value, by: -0.1) } label: { Image(systemName: "minus") }
                .accessibilityLabel("\(title) earlier")
            Text(title).font(.subheadline).frame(minWidth: 40)
            Button { move(value, by: 0.1) } label: { Image(systemName: "plus") }
                .accessibilityLabel("\(title) later")
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity)
    }

    private func move(_ edge: WritableKeyPath<VideoSegment, Double>, by delta: Double) {
        var moved = segment
        moved[keyPath: edge] += delta
        // Keep the other edge where it is, unless the part would get too short.
        if edge == \.start {
            moved.start = min(max(0, moved.start), moved.end - VideoSegment.minimumLength)
        } else {
            moved.end = max(min(video.duration, moved.end), moved.start + VideoSegment.minimumLength)
        }
        segment = moved.clamped(to: video.duration)
        preview.loop(segment)
    }
}

/// A filmstrip of the whole video with a yellow frame around the selected part,
/// like the trimmer in Photos.
private struct TrimBar: View {
    let url: URL
    let duration: Double
    @Binding var segment: VideoSegment
    let playhead: Double
    let onScrub: (Double) -> Void
    let onScrubEnd: (VideoSegment) -> Void

    @State private var frames: [CGImage] = []
    @State private var dragStart: VideoSegment?

    private let handleWidth: CGFloat = 18
    private let frameCount = 10

    var body: some View {
        GeometryReader { geometry in
            let track = max(1, geometry.size.width - handleWidth * 2)
            let x = { (time: Double) in handleWidth + CGFloat(time / max(duration, 0.001)) * track }
            let startX = x(segment.start)
            let endX = x(segment.end)

            ZStack(alignment: .leading) {
                // Filmstrip
                HStack(spacing: 0) {
                    ForEach(frames.indices, id: \.self) { index in
                        Image(decorative: frames[index], scale: 1)
                            .resizable()
                            .scaledToFill()
                            .frame(width: track / CGFloat(max(frames.count, 1)), height: geometry.size.height)
                            .clipped()
                    }
                }
                .frame(width: track, height: geometry.size.height, alignment: .leading)
                .background(Color.secondary.opacity(0.3))
                .offset(x: handleWidth)

                // Dim what's outside the selection.
                Rectangle().fill(.black.opacity(0.55))
                    .frame(width: max(0, startX - handleWidth))
                    .offset(x: handleWidth)
                Rectangle().fill(.black.opacity(0.55))
                    .frame(width: max(0, geometry.size.width - handleWidth - endX))
                    .offset(x: endX)

                // The selection: drag it to move the whole part.
                Rectangle()
                    .strokeBorder(Color.yellow, lineWidth: 4)
                    .contentShape(Rectangle())
                    .frame(width: endX - startX + handleWidth * 2)
                    .offset(x: startX - handleWidth)
                    .gesture(drag(track: track) { start, delta in
                        let length = start.length
                        let from = min(max(0, start.start + delta), duration - length)
                        return (VideoSegment(start: from, end: from + length), from)
                    })

                // Playhead
                if playhead >= segment.start, playhead <= segment.end {
                    Capsule().fill(.white)
                        .frame(width: 3, height: geometry.size.height + 8)
                        .offset(x: x(playhead) - 1.5)
                        .allowsHitTesting(false)
                }

                handle(systemImage: "chevron.compact.left")
                    .offset(x: startX - handleWidth)
                    .gesture(drag(track: track) { start, delta in
                        let from = min(max(0, start.start + delta), start.end - VideoSegment.minimumLength)
                        return (VideoSegment(start: from, end: start.end), from)
                    })
                    .accessibilityLabel("Start")
                    .accessibilityValue(Format.timecode(segment.start))

                handle(systemImage: "chevron.compact.right")
                    .offset(x: endX)
                    .gesture(drag(track: track) { start, delta in
                        let to = max(min(duration, start.end + delta), start.start + VideoSegment.minimumLength)
                        return (VideoSegment(start: start.start, end: to), to)
                    })
                    .accessibilityLabel("End")
                    .accessibilityValue(Format.timecode(segment.end))
            }
            .frame(height: geometry.size.height)
        }
        .task(id: url) {
            frames = await Filmstrip.frames(of: url, duration: duration, count: frameCount)
        }
    }

    private func handle(systemImage: String) -> some View {
        Rectangle()
            .fill(Color.yellow)
            .frame(width: handleWidth)
            .overlay {
                Image(systemName: systemImage)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.black)
            }
            // A wider touch area than the handle itself.
            .contentShape(Rectangle().inset(by: -12))
    }

    /// A drag that changes the segment. `update` gets the segment as it was when the
    /// drag began and the movement in seconds, and returns the new segment and the time to show.
    private func drag(track: CGFloat,
                      update: @escaping (VideoSegment, Double) -> (VideoSegment, Double)) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let start = dragStart ?? segment
                dragStart = start
                let delta = Double(value.translation.width / track) * duration
                let (moved, shown) = update(start, delta)
                segment = moved
                onScrub(shown)
            }
            .onEnded { _ in
                dragStart = nil
                onScrubEnd(segment)
            }
    }
}
