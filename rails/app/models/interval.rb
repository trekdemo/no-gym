# One timed entry: a label, a duration in seconds, optional reps and a role (spec 3.2).
class Interval < Data.define(:label, :seconds, :reps, :role)
  ROLES = %w[work rest inhale hold exhale].freeze
  BREATHING_ROLES = %w[inhale hold exhale].freeze

  def initialize(label:, seconds:, reps: nil, role: "work")
    super
  end

  # "10 × Deadlifts", or just the label when there are no reps.
  def display_label
    reps.nil? ? label : "#{reps} × #{label}"
  end

  def breathing?
    BREATHING_ROLES.include?(role)
  end
end
