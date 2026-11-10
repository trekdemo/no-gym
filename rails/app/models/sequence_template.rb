# The kind of a sequence and its own settings (spec 3.3). It builds the
# intervals of each round from them (spec 4).
#
# Settings are stored as a JSON document with the spec's field names, so the
# same shape travels to the run screen:
#
#   emom      { "stepSeconds" => 60, "exercises" => [{ "name" => "Squats", "reps" => 15 }] }
#   tabata    { "workSeconds" => 20, "restSeconds" => 10, "exercises" => ["Squats"] }
#   breathing { "inhale" => 4, "holdIn" => 4, "exhale" => 4, "holdOut" => 4 }
#   custom    { "intervals" => [{ "label" => "Pose", "seconds" => 45, "reps" => nil, "role" => "work" }] }
class SequenceTemplate
  KINDS = %w[emom tabata breathing custom].freeze

  TITLES = { "emom" => "EMOM", "tabata" => "Tabata", "breathing" => "Breathing", "custom" => "Custom" }.freeze

  DESCRIPTIONS = {
    "emom" => "Every minute on the minute. Each minute starts a new exercise.",
    "tabata" => "Work and rest pairs, like 20 s on and 10 s off, for 8 rounds.",
    "breathing" => "Inhale, hold and exhale with guide tones. Box, 4-7-8 and more.",
    "custom" => "Any list of labels and durations. Good for yoga and stretching."
  }.freeze

  ICONS = { "emom" => "⏱", "tabata" => "🔥", "breathing" => "🌬", "custom" => "☰" }.freeze

  TITLE_PLACEHOLDERS = {
    "emom" => "Morning EMOM", "tabata" => "Leg day Tabata",
    "breathing" => "Calm down", "custom" => "Evening stretch"
  }.freeze

  STARTER_ROUNDS = { "emom" => 3, "tabata" => 8, "breathing" => 6, "custom" => 1 }.freeze

  BREATHING_PRESETS = {
    "Box 4-4-4-4" => { "inhale" => 4, "holdIn" => 4, "exhale" => 4, "holdOut" => 4 },
    "Relax 4-7-8" => { "inhale" => 4, "holdIn" => 7, "exhale" => 8, "holdOut" => 0 },
    "Coherent 5.5-5.5" => { "inhale" => 5.5, "holdIn" => 0, "exhale" => 5.5, "holdOut" => 0 }
  }.freeze

  STARTERS = {
    "emom" => {
      "stepSeconds" => 60,
      "exercises" => [
        { "name" => "Burpees", "reps" => 10 },
        { "name" => "Squats", "reps" => 15 },
        { "name" => "Rest", "reps" => nil }
      ]
    },
    "tabata" => { "workSeconds" => 20, "restSeconds" => 10, "exercises" => [] },
    "breathing" => BREATHING_PRESETS["Box 4-4-4-4"],
    "custom" => {
      "intervals" => [
        { "label" => "Child's pose", "seconds" => 45, "reps" => nil, "role" => "work" },
        { "label" => "Switch", "seconds" => 5, "reps" => nil, "role" => "rest" }
      ]
    }
  }.freeze

  def self.starter_settings(kind)
    STARTERS.fetch(kind).deep_dup
  end

  # Turns submitted form values into clean settings for `kind`: numbers become
  # numbers, blank reps become nil, and unknown keys are dropped.
  def self.normalize(kind, raw)
    raw = (raw || {}).to_h.stringify_keys
    case kind
    when "emom"
      {
        "stepSeconds" => number(raw["stepSeconds"], 60),
        "exercises" => rows(raw["exercises"]).map do |row|
          { "name" => row["name"].to_s, "reps" => reps(row["reps"]) }
        end
      }
    when "tabata"
      names = raw.key?("exercisesText") ? raw["exercisesText"].to_s.split(/\r?\n/) : Array(raw["exercises"]).map(&:to_s)
      {
        "workSeconds" => number(raw["workSeconds"], 20),
        "restSeconds" => number(raw["restSeconds"], 10),
        "exercises" => names
      }
    when "breathing"
      %w[inhale holdIn exhale holdOut].to_h { |key| [ key, number(raw[key], 0) ] }
    when "custom"
      {
        "intervals" => rows(raw["intervals"]).map do |row|
          role = Interval::ROLES.include?(row["role"]) ? row["role"] : "work"
          { "label" => row["label"].to_s, "seconds" => number(row["seconds"], 0), "reps" => reps(row["reps"]), "role" => role }
        end
      }
    else
      {}
    end
  end

  # Form arrays arrive either as an array of hashes or as a hash keyed by index.
  def self.rows(value)
    rows = value.is_a?(Hash) ? value.sort_by { |key, _| key.to_s.to_i }.map(&:last) : Array(value)
    rows.select { |row| row.respond_to?(:to_h) }.map { |row| row.to_h.stringify_keys }
  end

  # Whole numbers stay integers, so the form shows "60" rather than "60.0".
  def self.number(value, default)
    return default if value.nil? || value.to_s.strip.empty?
    float = Float(value, exception: false)
    return default if float.nil?
    float == float.to_i ? float.to_i : float
  end

  def self.reps(value)
    return nil if value.nil? || value.to_s.strip.empty?
    Integer(value.to_s.strip, 10, exception: false)
  end

  private_class_method :rows, :number, :reps

  attr_reader :kind, :settings

  def initialize(kind, settings)
    @kind = kind.to_s
    @settings = (settings || {}).to_h.deep_stringify_keys
  end

  # The intervals of one round. `round` starts at 0. Only Tabata changes
  # between rounds: it moves on to the next exercise name.
  def intervals(round = 0)
    case kind
    when "emom"
      seconds = settings["stepSeconds"].to_f
      Array(settings["exercises"]).map do |exercise|
        name = exercise["name"].to_s
        Interval.new(label: name, seconds:, reps: exercise["reps"], role: name.casecmp?("rest") ? "rest" : "work")
      end
    when "tabata"
      names = Array(settings["exercises"]).map { |name| name.to_s.strip }.reject(&:empty?)
      label = names.empty? ? "Work" : names[round % names.size]
      result = [ Interval.new(label:, seconds: settings["workSeconds"].to_f, role: "work") ]
      rest = settings["restSeconds"].to_f
      result << Interval.new(label: "Rest", seconds: rest, role: "rest") if rest > 0
      result
    when "breathing"
      [
        [ "Inhale", settings["inhale"], "inhale" ],
        [ "Hold", settings["holdIn"], "hold" ],
        [ "Exhale", settings["exhale"], "exhale" ],
        [ "Hold", settings["holdOut"], "hold" ]
      ].filter_map do |label, seconds, role|
        Interval.new(label:, seconds: seconds.to_f, role:) if seconds.to_f > 0
      end
    when "custom"
      Array(settings["intervals"]).map do |interval|
        Interval.new(label: interval["label"].to_s, seconds: interval["seconds"].to_f,
                     reps: interval["reps"], role: interval["role"].presence || "work")
      end
    else
      []
    end
  end

  def title = TITLES.fetch(kind, kind.titleize)
  def icon = ICONS.fetch(kind, "")
end
