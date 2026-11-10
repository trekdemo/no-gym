require "test_helper"

# Spec 13.1: templates.
class SequenceTemplateTest < ActiveSupport::TestCase
  def tabata(**settings)
    SequenceTemplate.new("tabata", { "workSeconds" => 20, "restSeconds" => 10, "exercises" => [] }.merge(settings.stringify_keys))
  end

  test "Tabata 20/10, 8 rounds, prep 10" do
    timeline = Timeline.new(tabata, 8, 10)
    assert_equal 16, timeline.steps.size
    assert_equal 240, timeline.work_duration
    assert_equal "4:00", Format.clock(timeline.work_duration)
    assert_equal 250, timeline.duration
    assert_equal %w[work rest], timeline.steps.first(2).map { _1.interval.role }
  end

  test "Tabata names cycle through rounds and blank names are dropped" do
    timeline = Timeline.new(tabata(exercises: [ "Squats", " ", "Push-ups" ]), 4, 0)
    labels = timeline.steps.select { _1.interval.role == "work" }.map { _1.interval.label }
    assert_equal %w[Squats Push-ups Squats Push-ups], labels
  end

  test "Tabata work 30, rest 0 has only the work interval" do
    assert_equal [ "Work" ], tabata(workSeconds: 30, restSeconds: 0).intervals(0).map(&:label)
  end

  test "Breathing 4-7-8 leaves out the empty hold" do
    template = SequenceTemplate.new("breathing", SequenceTemplate::BREATHING_PRESETS["Relax 4-7-8"])
    assert_equal %w[Inhale Hold Exhale], template.intervals(0).map(&:label)
  end

  test "Breathing Coherent is inhale, exhale" do
    template = SequenceTemplate.new("breathing", SequenceTemplate::BREATHING_PRESETS["Coherent 5.5-5.5"])
    assert_equal %w[inhale exhale], template.intervals(0).map(&:role)
  end

  test "Breathing Box has 4 intervals" do
    assert_equal 4, SequenceTemplate.new("breathing", SequenceTemplate::BREATHING_PRESETS["Box 4-4-4-4"]).intervals(0).size
  end

  test "EMOM uses the step length and marks rest" do
    template = SequenceTemplate.new("emom", "stepSeconds" => 60, "exercises" => [
      { "name" => "Deadlifts", "reps" => 10 }, { "name" => "REST", "reps" => nil }
    ])
    intervals = template.intervals(0)
    assert_equal [ 60, 60 ], intervals.map(&:seconds)
    assert_equal %w[work rest], intervals.map(&:role)
    assert_equal [ "10 × Deadlifts", "REST" ], intervals.map(&:display_label)
  end

  test "custom repeats the same list every round" do
    template = SequenceTemplate.new("custom", SequenceTemplate.starter_settings("custom"))
    assert_equal template.intervals(0), template.intervals(5)
  end

  test "normalize turns form values into typed settings" do
    emom = SequenceTemplate.normalize("emom", "stepSeconds" => "45", "exercises" => [
      { "name" => "Squats", "reps" => "12" }, { "name" => "Rest", "reps" => "" }
    ])
    assert_equal({ "stepSeconds" => 45, "exercises" => [
      { "name" => "Squats", "reps" => 12 }, { "name" => "Rest", "reps" => nil }
    ] }, emom)

    tabata = SequenceTemplate.normalize("tabata", "workSeconds" => "20", "restSeconds" => "0", "exercisesText" => "Squats\r\n\r\nLunges")
    assert_equal [ "Squats", "", "Lunges" ], tabata["exercises"]
    assert_equal 0, tabata["restSeconds"]

    breathing = SequenceTemplate.normalize("breathing", "inhale" => "5.5", "holdIn" => "0", "exhale" => "5.5", "holdOut" => "0")
    assert_equal 5.5, breathing["inhale"]

    custom = SequenceTemplate.normalize("custom", "intervals" => { "1" => { "label" => "B", "seconds" => "5", "role" => "rest", "reps" => "" },
                                                           "0" => { "label" => "A", "seconds" => "30", "role" => "bogus", "reps" => "3" } })
    assert_equal [ [ "A", 30, 3, "work" ], [ "B", 5, nil, "rest" ] ], custom["intervals"].map(&:values)
  end
end
