require "test_helper"

# Spec 13.6: formatting.
class FormatTest < ActiveSupport::TestCase
  test "clock rounds up and shows hours from one hour" do
    assert_equal [ "0:00", "0:05", "4:00", "1:02:03" ], [ 0, 4.2, 240, 3723 ].map { Format.clock(_1) }
  end

  test "duration" do
    assert_equal [ "20 s", "5.5 s", "1 min", "1 min 30 s" ], [ 20, 5.5, 60, 90 ].map { Format.duration(_1) }
  end

  test "summary" do
    sequence = Sequence.starter("tabata")
    assert_equal "8 rounds · 4:00", Format.summary(sequence)
  end

  test "plural" do
    assert_equal [ "1 round", "2 rounds" ], [ 1, 2 ].map { Format.plural(_1, "round") }
  end
end
