import Foundation

/// Makes the app's sounds from sine waves, so there are no audio files to ship.
/// It returns mono samples from -1 to 1; the audio player turns them into buffers.
public enum ToneSynth {
    public static let defaultSampleRate: Double = 44_100

    public static func samples(for choice: SoundChoice, sampleRate: Double = defaultSampleRate) -> [Float] {
        switch choice {
        case .off:
            return []
        case .beep:
            return tone(partials: [(990, 1)], seconds: 0.5, decay: 8, sampleRate: sampleRate)
        case .doubleBeep:
            let one = tone(partials: [(880, 1)], seconds: 0.15, decay: 10, sampleRate: sampleRate)
            return mix([(one, 0), (one, 0.25)], sampleRate: sampleRate)
        case .bell:
            return tone(partials: [(660, 1), (660 * 2.76, 0.4), (660 * 5.4, 0.15)],
                        seconds: 1.8, decay: 2.5, sampleRate: sampleRate)
        case .chime:
            let low = tone(partials: [(784, 1), (1568, 0.2)], seconds: 0.9, decay: 4, sampleRate: sampleRate)
            let high = tone(partials: [(1047, 1), (2094, 0.2)], seconds: 1.0, decay: 4, sampleRate: sampleRate)
            return mix([(low, 0), (high, 0.18)], sampleRate: sampleRate)
        case .wood:
            return tone(partials: [(1200, 1), (2650, 0.5)], seconds: 0.12, decay: 45, sampleRate: sampleRate)
        }
    }

    /// The short tick of the countdown, like the HTML prototype's 660 Hz beep.
    public static func countdownTick(sampleRate: Double = defaultSampleRate) -> [Float] {
        tone(partials: [(660, 1)], seconds: 0.15, decay: 12, sampleRate: sampleRate)
    }

    /// A breathing guide tone that lasts the whole phase.
    /// Inhale rises from 220 Hz to 440 Hz, exhale falls back, and hold is a short soft low tone.
    public static func breath(_ role: Role, duration: TimeInterval, sampleRate: Double = defaultSampleRate) -> [Float] {
        switch role {
        case .inhale:
            return glide(from: 220, to: 440, seconds: duration, sampleRate: sampleRate)
        case .exhale:
            return glide(from: 440, to: 220, seconds: duration, sampleRate: sampleRate)
        case .hold:
            return tone(partials: [(165, 1), (330, 0.3)], seconds: min(duration, 0.8), decay: 4, sampleRate: sampleRate)
                .map { $0 * 0.6 }
        case .work, .rest:
            return []
        }
    }

    // MARK: - Building blocks

    /// A sum of sine partials with a short attack and an exponential decay.
    static func tone(partials: [(frequency: Double, gain: Double)], seconds: Double, decay: Double,
                     sampleRate: Double) -> [Float] {
        let count = Int(seconds * sampleRate)
        guard count > 0 else { return [] }
        let total = partials.reduce(0) { $0 + $1.gain }
        let attack = 0.005 * sampleRate
        var out = [Float](repeating: 0, count: count)
        for i in 0..<count {
            let t = Double(i) / sampleRate
            var value = 0.0
            for partial in partials {
                value += sin(2 * .pi * partial.frequency * t) * partial.gain
            }
            let envelope = min(1, Double(i) / attack) * exp(-decay * t)
            // Fade the very end so the cut is silent.
            let tail = min(1, Double(count - i) / attack)
            out[i] = Float(0.8 * value / total * envelope * tail)
        }
        return out
    }

    /// A soft tone whose pitch slides over the whole phase. It fades in and out
    /// over the first and last 15 %, so it feels like a breath rather than a beep.
    static func glide(from start: Double, to end: Double, seconds: Double, sampleRate: Double) -> [Float] {
        let count = Int(seconds * sampleRate)
        guard count > 0 else { return [] }
        var out = [Float](repeating: 0, count: count)
        var phase = 0.0
        let fade = max(1, Double(count) * 0.15)
        for i in 0..<count {
            let progress = Double(i) / Double(count)
            // Ease the pitch change so it starts and ends gently.
            let eased = 0.5 - 0.5 * cos(.pi * progress)
            let frequency = start + (end - start) * eased
            phase += 2 * .pi * frequency / sampleRate
            let envelope = min(1, Double(i) / fade, Double(count - i) / fade)
            let value = sin(phase) + 0.25 * sin(2 * phase)
            out[i] = Float(0.35 * value / 1.25 * envelope)
        }
        return out
    }

    /// Lays several sounds over each other, each starting at its own offset in seconds.
    static func mix(_ parts: [(samples: [Float], offset: Double)], sampleRate: Double) -> [Float] {
        let length = parts.map { Int($0.offset * sampleRate) + $0.samples.count }.max() ?? 0
        var out = [Float](repeating: 0, count: length)
        for part in parts {
            let start = Int(part.offset * sampleRate)
            for (i, sample) in part.samples.enumerated() { out[start + i] += sample }
        }
        let peak = out.map(abs).max() ?? 0
        return peak > 0.9 ? out.map { $0 * 0.9 / peak } : out
    }
}
