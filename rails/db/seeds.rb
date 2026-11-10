# The four example sequences a new install starts with (spec 11, "First use").
# Runs once: an existing list is left alone.
return if Sequence.exists?

def example(kind, title:, settings:, rounds:, notes: "", prep_seconds: 10)
  Sequence.create!(kind:, title:, notes:, settings:, rounds:, prep_seconds:, sound: SoundSettings.defaults(kind))
end

example "emom", title: "Morning EMOM", notes: "Kettlebell or bodyweight.", rounds: 3, settings: {
  "stepSeconds" => 60,
  "exercises" => [
    { "name" => "Deadlifts", "reps" => 10 },
    { "name" => "Sit-ups", "reps" => 10 },
    { "name" => "Rest", "reps" => nil }
  ]
}

example "tabata", title: "Classic Tabata", rounds: 8, settings: {
  "workSeconds" => 20, "restSeconds" => 10,
  "exercises" => [ "Squats", "Push-ups", "Mountain climbers", "Burpees" ]
}

example "breathing", title: "Box breathing", notes: "Breathe in through the nose, out through the mouth.",
  rounds: 8, prep_seconds: 5, settings: SequenceTemplate::BREATHING_PRESETS["Box 4-4-4-4"].dup

stretch = [
  [ "Child's pose", 45, "work" ], [ "Switch", 5, "rest" ],
  [ "Pigeon, left", 45, "work" ], [ "Switch", 5, "rest" ],
  [ "Pigeon, right", 45, "work" ], [ "Switch", 5, "rest" ],
  [ "Forward fold", 60, "work" ]
]
example "custom", title: "Evening stretch", rounds: 1, settings: {
  "intervals" => stretch.map { |label, seconds, role| { "label" => label, "seconds" => seconds, "reps" => nil, "role" => role } }
}
