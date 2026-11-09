# No Gym for iOS

A native iPhone app for timed sequences: EMOM, Tabata, breathing, yoga, stretching, or anything custom.

A **sequence** is a list of intervals. Each interval has a label and a duration, and the whole list repeats for a number of **rounds**. New sequences start from a template:

| Template | What you set | Example |
|----------|--------------|---------|
| **EMOM** | Step length (usually 1 min) and a list of exercises with optional reps | 10 Deadlifts, 10 Sit-ups, Rest × 3 rounds |
| **Tabata** | Work and rest seconds, plus optional exercise names that change every round | 20 s / 10 s × 8 rounds = 4:00 |
| **Breathing** | Inhale, hold, exhale and hold seconds, with presets | Box 4-4-4-4, Relax 4-7-8, Coherent 5.5-5.5 |
| **Custom** | Any list of label + duration + type (work, rest, inhale, hold, exhale) | Yoga poses with 5 s switches |

The run screen puts the **current label** first and the **next label** second, with a big countdown and progress bar between them. You can pause, skip forwards or backwards, and stop. Breathing intervals show a circle that grows as you breathe in and shrinks as you breathe out.

Each sequence has its own **sounds**: countdown ticks (last 3 or 5 seconds), an interval-end sound, a round-end sound, a finish sound, and breathing guide tones (rising on inhale, falling on exhale, soft and low on hold). Sounds keep playing on time when the phone is locked, and they mix with your music.

## What you need

- A Mac with **Xcode 16 or newer**. It's free from the Mac App Store.
- An iPhone on **iOS 18 or newer**, or the iPhone simulator that comes with Xcode.
- An Apple ID. A free one is enough to run the app on your own phone.

## Run it for the first time

1. Open `ios/NoGym.xcodeproj` in Xcode by double-clicking it.
2. Wait a few seconds while Xcode loads the `NoGymKit` package (it shows a spinner in the top bar).
3. **Pick a place to run it.** At the top of the window, next to the play ▶ button, click the device menu and choose a simulator such as *iPhone 16*.
4. Press **⌘R** (or click ▶). The simulator starts and opens the app.

### On your own iPhone

1. In Xcode, click the blue **NoGym** project at the top of the left sidebar, then the **NoGym** target, then the **Signing & Capabilities** tab.
2. Under **Team**, choose your Apple ID. If it isn't there, choose *Add an Account…* and sign in.
3. If Xcode complains about the **Bundle Identifier**, change `app.nogym.NoGym` to something only you would use, like `com.yourname.nogym`.
4. Plug in your iPhone with a cable, unlock it, and tap *Trust* if it asks.
5. On the iPhone, turn on **Settings → Privacy & Security → Developer Mode** and restart it when it asks. You only need to do this once.
6. Pick your iPhone in Xcode's device menu and press **⌘R**.
7. The first time, the iPhone may say the developer isn't trusted. Go to **Settings → General → VPN & Device Management**, tap your Apple ID, and tap *Trust*.

With a free Apple ID, the app keeps working for 7 days. After that, run it from Xcode again.

## How the code is organised

```
ios/
├── NoGym.xcodeproj    The Xcode project. Open this.
├── NoGym-Info.plist   One setting: the "audio" background mode, so sounds play while locked.
├── NoGym/             The app: screens, sound and saving.
│   ├── NoGymApp.swift           Where the app starts.
│   ├── Store/RoutineStore.swift Saves sequences as JSON on the phone.
│   ├── Run/RunSession.swift     One live run: pause, skip, haptics, keeping the screen on.
│   ├── Audio/CuePlayer.swift    Plays the sounds at exact moments on the audio clock.
│   └── Views/                   The screens (SwiftUI).
└── NoGymKit/          The rules, with no UI. You can test it on its own.
    ├── Sources/NoGymKit/
    │   ├── Routine.swift        A sequence, its intervals, and validation.
    │   ├── Template.swift       EMOM, Tabata, Breathing and Custom, and how each builds its intervals.
    │   ├── Timeline.swift       Lays the rounds out in time.
    │   ├── RunClock.swift       Works out where the run is from timestamps, with pause and skip.
    │   ├── CueSchedule.swift    Lists every sound of a run and when it plays.
    │   ├── SoundSettings.swift  The sound choices of a sequence.
    │   ├── ToneSynth.swift      Makes the sounds from sine waves (no audio files).
    │   └── Format.swift         "4:00", "1 min 30 s", and the EMOM paste format.
    └── Tests/                   Tests for all of the above.
```

New Swift files that you put in the `NoGym/` folder appear in Xcode by themselves.

## Tests

The rules in `NoGymKit` have tests. To run them in Xcode, open `ios/NoGymKit/Package.swift` and press **⌘U**. To run them in Terminal:

```bash
cd ios/NoGymKit
swift test
```

## Notes

- **Timing.** The run's position comes from the clock, not from a counter, the same way as in the HTML prototype. A late screen update can't make the timer drift.
- **Locked phone.** When a run starts or resumes, every sound is scheduled on the audio clock. The phone plays the sounds even if the app's code is paused in the background. While a run is open, the screen stays on.
- **Silent switch.** Like a music app, the sounds ignore the ring/silent switch. Use the volume buttons, or the volume slider in a sequence's sounds.
- **App icon.** The icon is still empty. To add one, drop a 1024 × 1024 PNG into `NoGym/Assets.xcassets/AppIcon`.
