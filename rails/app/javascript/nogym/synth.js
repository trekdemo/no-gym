// Sound design (spec 9). Every sound is made from sine waves, so there are no
// audio files. Each function returns mono samples from -1 to 1.

export const SOUND_CHOICES = ["none", "beep", "double_beep", "bell", "chime", "wood_block"]

// A sum of sine partials, with 5 ms linear attack and release ramps and an exponential decay.
export function tone(partials, seconds, decay, sampleRate) {
  const count = Math.floor(seconds * sampleRate)
  const out = new Float32Array(Math.max(0, count))
  if (count <= 0) return out
  const total = partials.reduce((sum, [, gain]) => sum + gain, 0)
  const ramp = 0.005 * sampleRate
  for (let i = 0; i < count; i++) {
    const t = i / sampleRate
    let value = 0
    for (const [frequency, gain] of partials) value += Math.sin(2 * Math.PI * frequency * t) * gain
    const attack = Math.min(1, i / ramp)
    const release = Math.min(1, (count - i) / ramp)
    out[i] = ((0.8 * value) / total) * attack * Math.exp(-decay * t) * release
  }
  return out
}

// Lays sounds over each other, each from its own offset in seconds.
// A mix that peaks above 0.9 is scaled down to a peak of 0.9.
export function mix(parts, sampleRate) {
  const length = Math.max(0, ...parts.map(([samples, offset]) => Math.floor(offset * sampleRate) + samples.length))
  const out = new Float32Array(length)
  for (const [samples, offset] of parts) {
    const start = Math.floor(offset * sampleRate)
    for (let i = 0; i < samples.length; i++) out[start + i] += samples[i]
  }
  const peak = out.reduce((max, value) => Math.max(max, Math.abs(value)), 0)
  if (peak > 0.9) for (let i = 0; i < out.length; i++) out[i] *= 0.9 / peak
  return out
}

// A soft tone whose pitch slides along an eased curve over the whole phase,
// fading in over the first 15 % and out over the last 15 %.
export function glide(from, to, seconds, sampleRate) {
  const count = Math.floor(seconds * sampleRate)
  const out = new Float32Array(Math.max(0, count))
  const fade = Math.max(1, count * 0.15)
  let phase = 0
  for (let i = 0; i < count; i++) {
    const progress = i / count
    const eased = 0.5 - 0.5 * Math.cos(Math.PI * progress)
    phase += (2 * Math.PI * (from + (to - from) * eased)) / sampleRate
    const envelope = Math.min(1, i / fade, (count - i) / fade)
    out[i] = ((0.35 * (Math.sin(phase) + 0.25 * Math.sin(2 * phase))) / 1.25) * envelope
  }
  return out
}

export function samples(choice, sampleRate = 44100) {
  switch (choice) {
    case "beep":
      return tone([[990, 1]], 0.5, 8, sampleRate)
    case "double_beep": {
      const one = tone([[880, 1]], 0.15, 10, sampleRate)
      return mix([[one, 0], [one, 0.25]], sampleRate)
    }
    case "bell":
      return tone([[660, 1], [660 * 2.76, 0.4], [660 * 5.4, 0.15]], 1.8, 2.5, sampleRate)
    case "chime": {
      const low = tone([[784, 1], [1568, 0.2]], 0.9, 4, sampleRate)
      const high = tone([[1047, 1], [2094, 0.2]], 1.0, 4, sampleRate)
      return mix([[low, 0], [high, 0.18]], sampleRate)
    }
    case "wood_block":
      return tone([[1200, 1], [2650, 0.5]], 0.12, 45, sampleRate)
    default:
      return new Float32Array(0)
  }
}

// The same short tick for every sequence.
export function countdownTick(sampleRate = 44100) {
  return tone([[660, 1]], 0.15, 12, sampleRate)
}

// A breathing guide tone that lasts the whole phase (the hold tone is short).
export function breath(role, duration, sampleRate = 44100) {
  switch (role) {
    case "inhale":
      return glide(220, 440, duration, sampleRate)
    case "exhale":
      return glide(440, 220, duration, sampleRate)
    case "hold":
      return tone([[165, 1], [330, 0.3]], Math.min(duration, 0.8), 4, sampleRate).map((value) => value * 0.6)
    default:
      return new Float32Array(0)
  }
}
