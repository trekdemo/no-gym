# A saved plan: a title, notes, a template, rounds, prep time and sounds (spec 3.1).
class Sequence < ApplicationRecord
  MESSAGES = {
    title: "Give the sequence a title.",
    rounds: "Rounds must be at least 1.",
    prep: "Prep time can't be negative.",
    no_intervals: "Add at least one interval.",
    label: "Every interval needs a label.",
    seconds: "Every interval must last at least 1 second.",
    reps: "Reps must be blank or at least 1."
  }.freeze

  scope :ordered, -> { order(:position, :id) }

  before_validation :trim_text
  before_create :append_to_list
  validate :first_problem

  # A new, unsaved sequence with the kind's starter content and default sounds.
  def self.starter(kind)
    raise ArgumentError, "unknown kind #{kind.inspect}" unless SequenceTemplate::KINDS.include?(kind)
    new(kind:, title: "", notes: "", settings: SequenceTemplate.starter_settings(kind),
        rounds: SequenceTemplate::STARTER_ROUNDS.fetch(kind), prep_seconds: 10, sound: SoundSettings.defaults(kind))
  end

  def template = SequenceTemplate.new(kind, settings)
  def timeline = Timeline.new(template, rounds, prep_seconds)

  # Work time, without the prep.
  def total_seconds = timeline.work_duration

  # The first message from spec 5 that applies, or nil when the sequence can be saved.
  def validation_error
    return MESSAGES[:title] if title.to_s.strip.empty?
    return MESSAGES[:rounds] if rounds.to_i < 1
    return MESSAGES[:prep] if prep_seconds.to_f.negative?

    intervals = timeline.steps.map(&:interval)
    return MESSAGES[:no_intervals] if intervals.empty?
    return MESSAGES[:label] if intervals.any? { |interval| interval.label.to_s.strip.empty? }
    return MESSAGES[:seconds] if intervals.any? { |interval| interval.seconds.to_f < 1 }
    MESSAGES[:reps] if intervals.any? { |interval| !interval.reps.nil? && interval.reps < 1 }
  end

  # What the run screen needs to do sections 6–9 on the client.
  def run_data
    {
      id:, title:, kind:, settings:, rounds:,
      prepSeconds: prep_seconds,
      sound: SoundSettings.normalize(sound, kind)
    }
  end

  # Moves the sequence one place up (-1) or down (+1) in the list.
  def move(by)
    list = self.class.ordered.to_a
    from = list.index(self)
    to = from + by
    return if to.negative? || to >= list.size

    list[from], list[to] = list[to], list[from]
    transaction do
      list.each_with_index { |sequence, index| sequence.update_column(:position, index) }
    end
  end

  private

  def trim_text
    self.title = title.to_s.strip
    self.notes = notes.to_s.strip
    self.prep_seconds = 0 if prep_seconds.nil?
    self.rounds = 0 if rounds.nil?
  end

  def append_to_list
    self.position = (self.class.maximum(:position) || -1) + 1
  end

  def first_problem
    message = validation_error
    errors.add(:base, message) if message
  end
end
