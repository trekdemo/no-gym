import AVFoundation
import NoGymKit
import Observation
import SwiftUI
import UIKit

/// Loops one segment of a video, muted, for the run screen.
/// `AVPlayerLooper` queues copies of the segment, so the loop has no gap.
@MainActor
final class SegmentLooper {
    let player = AVQueuePlayer()
    private let asset: AVURLAsset
    private var looper: AVPlayerLooper?
    private var segment: VideoSegment?
    private var isPaused = false

    init(url: URL) {
        asset = AVURLAsset(url: url)
        player.isMuted = true
        // The run screen keeps the display on itself, and the timer's sounds own the audio.
        player.preventsDisplaySleepDuringVideoPlayback = false
        player.allowsExternalPlayback = false
    }

    /// Starts looping a segment. With nil it pauses on the last frame, so the page
    /// doesn't go black while it slides away.
    func show(_ segment: VideoSegment?) {
        guard segment != self.segment else { return }
        self.segment = segment
        guard let segment else {
            player.pause()
            return
        }
        looper?.disableLooping()
        looper = nil
        player.removeAllItems()
        let range = CMTimeRange(start: CMTime(seconds: segment.start, preferredTimescale: 600),
                                end: CMTime(seconds: segment.end, preferredTimescale: 600))
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(asset: asset), timeRange: range)
        if !isPaused { player.play() }
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
        if paused || segment == nil { player.pause() } else { player.play() }
    }

    func stop() {
        segment = nil
        looper?.disableLooping()
        looper = nil
        player.pause()
        player.removeAllItems()
    }
}

/// Plays a video for the trimmer: loops the selected segment, and while you drag
/// a handle it pauses and shows the frame under your finger.
@MainActor
@Observable
final class TrimPreview {
    let player: AVPlayer
    /// Where the player is, for the playhead.
    private(set) var currentTime: Double = 0
    @ObservationIgnored private var segment: VideoSegment
    @ObservationIgnored private var isScrubbing = false
    @ObservationIgnored private var observer: Any?

    init(url: URL, segment: VideoSegment) {
        player = AVPlayer(url: url)
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        self.segment = segment
    }

    /// Starts looping. Call `stop()` when the preview goes away.
    func start() {
        if observer == nil {
            observer = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: .main) { [weak self] time in
                MainActor.assumeIsolated { self?.tick(time.seconds) }
            }
        }
        seek(to: segment.start)
        player.play()
    }

    func stop() {
        player.pause()
        if let observer { player.removeTimeObserver(observer) }
        observer = nil
    }

    /// Shows the frame at `time` while a handle is being dragged.
    func scrub(to time: Double) {
        isScrubbing = true
        player.pause()
        currentTime = time
        seek(to: time)
    }

    /// Goes back to looping, with the new segment.
    func loop(_ segment: VideoSegment) {
        self.segment = segment
        isScrubbing = false
        start()
    }

    private func tick(_ time: Double) {
        guard !isScrubbing, time.isFinite else { return }
        currentTime = time
        if time >= segment.end || time < segment.start - 0.25 {
            seek(to: segment.start)
        }
    }

    private func seek(to time: Double) {
        player.seek(to: CMTime(seconds: time, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }
}

/// Shows an `AVPlayer`'s picture. Black bars fill the space the video doesn't.
struct VideoSurface: UIViewRepresentable {
    let player: AVPlayer
    var gravity: AVLayerVideoGravity = .resizeAspect

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.backgroundColor = .black
        view.playerLayer.player = player
        view.playerLayer.videoGravity = gravity
        return view
    }

    func updateUIView(_ view: PlayerView, context: Context) {
        if view.playerLayer.player !== player { view.playerLayer.player = player }
        view.playerLayer.videoGravity = gravity
    }

    final class PlayerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}

/// Evenly spaced frames of a video, for the trimmer's filmstrip.
enum Filmstrip {
    static func frames(of url: URL, duration: Double, count: Int) async -> [CGImage] {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 160, height: 160)
        var images: [CGImage] = []
        for index in 0..<count {
            let time = duration * (Double(index) + 0.5) / Double(count)
            if let frame = try? await generator.image(at: CMTime(seconds: time, preferredTimescale: 600)) {
                images.append(frame.image)
            }
        }
        return images
    }
}
