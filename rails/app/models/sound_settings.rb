# Each sequence's sounds (spec 3.4). Stored as a JSON document on the sequence.
module SoundSettings
  COUNTDOWNS = { "off" => "None", "last3" => "Last 3 seconds", "last5" => "Last 5 seconds" }.freeze

  CHOICES = {
    "none" => "None", "beep" => "Beep", "double_beep" => "Double beep",
    "bell" => "Bell", "chime" => "Chime", "wood_block" => "Wood block"
  }.freeze

  BASE = {
    "countdown" => "last3", "intervalEnd" => "beep", "roundEnd" => "double_beep", "finish" => "bell",
    "breathingGuide" => false, "haptics" => true, "volume" => 0.8
  }.freeze

  DEFAULTS = {
    "emom" => BASE,
    "tabata" => BASE,
    "breathing" => BASE.merge(
      "countdown" => "off", "intervalEnd" => "none", "roundEnd" => "none", "finish" => "bell",
      "breathingGuide" => true, "haptics" => false, "volume" => 0.6
    ),
    "custom" => BASE.merge("intervalEnd" => "chime", "roundEnd" => "bell")
  }.freeze

  module_function

  def defaults(kind)
    DEFAULTS.fetch(kind, BASE).dup
  end

  # Cleans submitted values. Anything missing or unknown falls back to the kind's default.
  def normalize(raw, kind)
    raw = (raw || {}).to_h.stringify_keys
    base = defaults(kind)
    pick = ->(key, allowed) { allowed.key?(raw[key]) ? raw[key] : base[key] }
    volume = Float(raw["volume"], exception: false) || base["volume"]
    {
      "countdown" => pick.("countdown", COUNTDOWNS),
      "intervalEnd" => pick.("intervalEnd", CHOICES),
      "roundEnd" => pick.("roundEnd", CHOICES),
      "finish" => pick.("finish", CHOICES),
      "breathingGuide" => raw.key?("breathingGuide") ? boolean(raw["breathingGuide"]) : base["breathingGuide"],
      "haptics" => raw.key?("haptics") ? boolean(raw["haptics"]) : base["haptics"],
      "volume" => volume.clamp(0.0, 1.0)
    }
  end

  def boolean(value)
    ActiveModel::Type::Boolean.new.cast(value) || false
  end
end
