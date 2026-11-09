import AVFoundation
import NoGymKit

/// Plays the run's sounds.
///
/// Every cue is handed to the audio engine ahead of time, with the exact moment it
/// should play. The audio hardware then plays it on time by itself, even while the
/// screen is locked: the app has the "audio" background mode (see NoGym-Info.plist),
/// and a running audio engine keeps the app awake, like a music app.
@MainActor
final class CuePlayer {
    private let engine = AVAudioEngine()
    // Separate players, so a long breathing tone doesn't hold up a tick or a bell.
    private let chimes = AVAudioPlayerNode()
    private let ticks = AVAudioPlayerNode()
    private let breaths = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    nonisolated(unsafe) private var observers: [NSObjectProtocol] = []

    /// Called after a phone call or Siri ends, or the headphones change, so the
    /// run can schedule its sounds again.
    var onRestart: (@MainActor () -> Void)?

    init() {
        format = AVAudioFormat(standardFormatWithSampleRate: ToneSynth.defaultSampleRate, channels: 1)!
        for node in [chimes, ticks, breaths] {
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
        }
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil,
                                            queue: .main) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            guard raw == AVAudioSession.InterruptionType.ended.rawValue else { return }
            MainActor.assumeIsolated { self?.restart() }
        })
        observers.append(center.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine,
                                            queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.restart() }
        })
    }

    deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
    }

    var volume: Double {
        get { Double(engine.mainMixerNode.outputVolume) }
        set { engine.mainMixerNode.outputVolume = Float(newValue) }
    }

    /// Turns on the audio session and starts the engine.
    /// `.mixWithOthers` lets your own music keep playing under the cues.
    func activate() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            if !engine.isRunning { try engine.start() }
        } catch {
            print("Audio could not start: \(error)")
        }
    }

    func deactivate() {
        stopAll()
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Clears every sound that hasn't played yet.
    func stopAll() {
        for node in [chimes, ticks, breaths] { node.stop() }
    }

    /// Schedules `cues`, given that the run is at `elapsed` seconds right now.
    /// Cues before `elapsed` are skipped.
    func schedule(_ cues: [Cue], elapsed: TimeInterval) {
        activate()
        stopAll()
        let now = mach_absolute_time()
        for cue in cues where cue.at >= elapsed - 0.05 {
            guard let (sound, node) = buffer(for: cue.kind) else { continue }
            let delay = max(0, cue.at - elapsed)
            let when = AVAudioTime(hostTime: now + AVAudioTime.hostTime(forSeconds: delay))
            node.scheduleBuffer(sound, at: when, options: [], completionHandler: nil)
        }
        for node in [chimes, ticks, breaths] { node.play() }
    }

    /// Plays one sound right away, for the previews in the sound settings.
    func preview(_ kind: CueKind) {
        activate()
        guard let (sound, node) = buffer(for: kind) else { return }
        node.stop()
        node.scheduleBuffer(sound, at: nil, options: [], completionHandler: nil)
        node.play()
    }

    // MARK: - Buffers

    private func restart() {
        guard !engine.isRunning else { return }
        try? engine.start()
        onRestart?()
    }

    /// Each sound is made once and reused.
    private func buffer(for kind: CueKind) -> (AVAudioPCMBuffer, AVAudioPlayerNode)? {
        let rate = format.sampleRate
        switch kind {
        case .countdown:
            return cached("tick", ticks) { ToneSynth.countdownTick(sampleRate: rate) }
        case .boundary(_, let choice):
            return cached("sound-\(choice.rawValue)", chimes) { ToneSynth.samples(for: choice, sampleRate: rate) }
        case .breathe(let role, let duration):
            return cached("breath-\(role.rawValue)-\(duration)", breaths) {
                ToneSynth.breath(role, duration: duration, sampleRate: rate)
            }
        }
    }

    private func cached(_ key: String, _ node: AVAudioPlayerNode,
                        make: () -> [Float]) -> (AVAudioPCMBuffer, AVAudioPlayerNode)? {
        if let buffer = buffers[key] { return (buffer, node) }
        let samples = make()
        guard !samples.isEmpty,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0]
        else { return nil }
        buffer.frameLength = buffer.frameCapacity
        samples.withUnsafeBufferPointer { source in
            channel.update(from: source.baseAddress!, count: samples.count)
        }
        buffers[key] = buffer
        return (buffer, node)
    }
}
