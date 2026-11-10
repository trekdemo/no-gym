require "test_helper"

# Spec 13.3, the timeline part: prep 10 and Tabata 20/10 over 2 rounds.
class TimelineTest < ActiveSupport::TestCase
  setup do
    template = SequenceTemplate.new("tabata", "workSeconds" => 20, "restSeconds" => 10, "exercises" => [])
    @timeline = Timeline.new(template, 2, 10)
  end

  test "steps, rounds and duration" do
    assert_equal [ 10, 30, 40, 60 ], @timeline.steps.map(&:start)
    assert_equal 70, @timeline.duration
    assert_equal 60, @timeline.work_duration
    assert_equal [ 1, 1, 2, 2 ], @timeline.steps.map(&:round)
    assert_equal [ 0, 1, 0, 1 ], @timeline.steps.map(&:index_in_round)
    assert_equal 2, @timeline.steps_per_round
  end

  test "last in round" do
    assert @timeline.last_in_round?(1)
    assert_not @timeline.last_in_round?(2)
    assert @timeline.last_in_round?(3)
  end

  test "with no steps the duration is the prep" do
    timeline = Timeline.new(SequenceTemplate.new("custom", "intervals" => []), 3, 10)
    assert_equal 10, timeline.duration
    assert_equal 0, timeline.work_duration
  end
end
