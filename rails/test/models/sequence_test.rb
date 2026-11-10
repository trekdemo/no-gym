require "test_helper"

class SequenceTest < ActiveSupport::TestCase
  # Spec 13.1: each kind's starter, with its default rounds, is valid and uses that kind's sounds.
  SequenceTemplate::KINDS.each do |kind|
    test "#{kind} starter is valid and has the kind's default sounds" do
      sequence = Sequence.starter(kind)
      sequence.title = SequenceTemplate::TITLES[kind]
      assert_nil sequence.validation_error
      assert_equal SequenceTemplate::STARTER_ROUNDS[kind], sequence.rounds
      assert_equal SoundSettings::DEFAULTS[kind], sequence.sound
    end
  end

  test "sound defaults by kind" do
    assert_equal "last3", SoundSettings.defaults("tabata")["countdown"]
    breathing = SoundSettings.defaults("breathing")
    assert_equal [ "off", "none", "none", "bell", true, false, 0.6 ],
                 breathing.values_at("countdown", "intervalEnd", "roundEnd", "finish", "breathingGuide", "haptics", "volume")
    custom = SoundSettings.defaults("custom")
    assert_equal [ "chime", "bell", "bell" ], custom.values_at("intervalEnd", "roundEnd", "finish")
  end

  # Spec 13.1: every kind saved and loaded again equals the original.
  test "every kind survives a save and load" do
    sequences = SequenceTemplate::KINDS.map do |kind|
      Sequence.starter(kind).tap do |sequence|
        sequence.assign_attributes(title: SequenceTemplate::TITLES[kind], notes: "n", rounds: 2, prep_seconds: 5)
      end
    end
    relax = Sequence.starter("breathing")
    relax.assign_attributes(title: "478", rounds: 4, settings: SequenceTemplate::BREATHING_PRESETS["Relax 4-7-8"])
    sequences << relax

    sequences.each do |original|
      original.save!
      loaded = Sequence.find(original.id)
      %w[title notes kind settings rounds prep_seconds sound].each do |field|
        assert_equal original.public_send(field), loaded.public_send(field), "#{original.kind} #{field}"
      end
      assert_equal original.timeline.steps, loaded.timeline.steps
    end
  end

  # Spec 13.2: validation, one change at a time from a Custom starter.
  test "validation shows the first message that applies" do
    sequence = Sequence.starter("custom")
    sequence.assign_attributes(title: " ", rounds: 1)
    assert_equal "Give the sequence a title.", sequence.validation_error

    sequence.title = "Yoga"
    sequence.rounds = 0
    assert_equal "Rounds must be at least 1.", sequence.validation_error

    sequence.rounds = 1
    sequence.settings = { "intervals" => [] }
    assert_equal "Add at least one interval.", sequence.validation_error

    sequence.settings = { "intervals" => [ { "label" => "Pose", "seconds" => 0.5, "reps" => nil, "role" => "work" } ] }
    assert_equal "Every interval must last at least 1 second.", sequence.validation_error

    sequence.settings = { "intervals" => [ { "label" => "", "seconds" => 5, "reps" => nil, "role" => "work" } ] }
    assert_equal "Every interval needs a label.", sequence.validation_error

    sequence.kind = "emom"
    sequence.settings = { "stepSeconds" => 60, "exercises" => [ { "name" => "Squats", "reps" => 0 } ] }
    assert_equal "Reps must be blank or at least 1.", sequence.validation_error
  end

  test "negative prep is rejected" do
    sequence = Sequence.starter("tabata")
    sequence.assign_attributes(title: "T", prep_seconds: -1)
    assert_equal "Prep time can't be negative.", sequence.validation_error
  end

  test "an invalid sequence is not saved and carries a single message" do
    sequence = Sequence.starter("custom")
    sequence.title = "  "
    assert_not sequence.save
    assert_equal [ "Give the sequence a title." ], sequence.errors.full_messages
  end

  test "title and notes are trimmed on save" do
    sequence = Sequence.starter("tabata")
    sequence.assign_attributes(title: "  Legs  ", notes: "\n Hard. \n")
    sequence.save!
    assert_equal [ "Legs", "Hard." ], [ sequence.title, sequence.notes ]
  end

  test "new sequences go to the end of the list, and the order can change" do
    Sequence.delete_all
    a, b, c = %w[A B C].map { |title| Sequence.starter("tabata").tap { _1.title = title }.tap(&:save!) }
    assert_equal %w[A B C], Sequence.ordered.map(&:title)
    c.move(-1)
    assert_equal %w[A C B], Sequence.ordered.map(&:title)
    a.move(-1) # already first
    a.move(1)
    assert_equal %w[C A B], Sequence.ordered.map(&:title)
    b.reload.move(1) # already last
    assert_equal %w[C A B], Sequence.ordered.map(&:title)
  end

  test "the seeds create the four example sequences" do
    Sequence.delete_all
    load Rails.root.join("db/seeds.rb")
    assert_equal [ "Morning EMOM", "Classic Tabata", "Box breathing", "Evening stretch" ], Sequence.ordered.map(&:title)
    assert Sequence.all.all?(&:valid?)
    assert_equal [ "3 rounds · 9:00", "8 rounds · 4:00", "8 rounds · 2:08", "1 round · 3:30" ],
                 Sequence.ordered.map { Format.summary(_1) }
  end
end
