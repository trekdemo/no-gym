require "test_helper"

class SequencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    Sequence.delete_all
    @tabata = Sequence.starter("tabata").tap { _1.title = "Classic Tabata" }.tap(&:save!)
  end

  test "the list shows each card's title, kind, rounds and total time" do
    get root_path
    assert_response :success
    assert_select ".card-title", "Classic Tabata"
    assert_select ".card-meta", /Tabata · 8 rounds · 4:00/
    assert_select "a[href=?]", run_sequence_path(@tabata)
  end

  test "the empty state" do
    Sequence.delete_all
    get root_path
    assert_select ".empty", /No sequences yet.*Tap \+ to make your first one\./m
  end

  test "the template picker lists the four kinds" do
    get new_sequence_path
    assert_select "h1", "New sequence"
    assert_select ".kind strong", count: 4
    assert_select ".kind", /Every minute on the minute/
  end

  test "picking a kind opens the editor with its starter" do
    get new_sequence_path(kind: "emom")
    assert_select "h1", "New EMOM"
    assert_select "input[placeholder='Morning EMOM']"
    assert_select "[data-field=name]", count: 4 # three starter rows and the row template
    assert_select "[data-editor-target=total]", "9:00"

    get new_sequence_path(kind: "breathing")
    assert_select "label", "Breaths"
  end

  test "create saves a sequence with its template settings and sounds" do
    assert_difference "Sequence.count", 1 do
      post sequences_path, params: { sequence: {
        kind: "emom", title: "  Legs ", notes: "", rounds: "2", prep_seconds: "5",
        settings: { stepSeconds: "45", exercises: [ { name: "Squats", reps: "12" }, { name: "Rest", reps: "" } ] },
        sound: { countdown: "last5", intervalEnd: "wood_block", roundEnd: "none", finish: "bell",
                 breathingGuide: "0", haptics: "1", volume: "0.5" }
      } }
    end
    assert_redirected_to root_path

    sequence = Sequence.ordered.last
    assert_equal "Legs", sequence.title
    assert_equal({ "stepSeconds" => 45, "exercises" => [ { "name" => "Squats", "reps" => 12 }, { "name" => "Rest", "reps" => nil } ] },
                 sequence.settings)
    assert_equal "wood_block", sequence.sound["intervalEnd"]
    assert_equal 0.5, sequence.sound["volume"]
    assert_equal 1, sequence.position
  end

  test "an invalid sequence is not saved and shows the 'Can't save yet' dialog" do
    assert_no_difference "Sequence.count" do
      post sequences_path, params: { sequence: { kind: "custom", title: " ", rounds: "1", prep_seconds: "10",
                                                 settings: { intervals: [ { label: "Pose", seconds: "30", role: "work", reps: "" } ] } } }
    end
    assert_response :unprocessable_entity
    assert_select "dialog h2", "Can't save yet"
    assert_select "dialog p", "Give the sequence a title."
  end

  test "edit reopens the same form, and update saves it" do
    get edit_sequence_path(@tabata)
    assert_select "h1", "Edit sequence"
    assert_select "[data-field=workSeconds][value='20']"

    patch sequence_path(@tabata), params: { sequence: { title: "Legs", rounds: "4", prep_seconds: "0",
                                                        settings: { workSeconds: "30", restSeconds: "0", exercisesText: "Lunges\nSquats" } } }
    assert_redirected_to root_path
    @tabata.reload
    assert_equal [ "Legs", 4, 0.0 ], [ @tabata.title, @tabata.rounds, @tabata.prep_seconds ]
    assert_equal({ "workSeconds" => 30, "restSeconds" => 0, "exercises" => %w[Lunges Squats] }, @tabata.settings)
    assert_equal "tabata", @tabata.kind
  end

  test "delete" do
    assert_difference "Sequence.count", -1 do
      delete sequence_path(@tabata)
    end
    assert_redirected_to root_path
  end

  test "reorder" do
    other = Sequence.starter("custom").tap { _1.title = "Stretch" }.tap(&:save!)
    patch move_sequence_path(other, direction: "up")
    assert_redirected_to root_path(editing: 1)
    assert_equal [ "Stretch", "Classic Tabata" ], Sequence.ordered.map(&:title)
  end

  test "the run screen gets the sequence as JSON for the Stimulus controller" do
    get run_sequence_path(@tabata)
    assert_response :success
    data = JSON.parse(css_select("[data-controller=run]").first["data-run-sequence-value"])
    assert_equal "tabata", data["kind"]
    assert_equal 8, data["rounds"]
    assert_equal 10, data["prepSeconds"]
    assert_equal({ "workSeconds" => 20, "restSeconds" => 10, "exercises" => [] }, data["settings"])
    assert_equal "double_beep", data.dig("sound", "roundEnd")
    assert_select ".done-screen p", "Classic Tabata · 8 rounds · 4:00"
  end
end
