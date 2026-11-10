# No Gym for the web

A Rails 8 + Hotwire build of the app described in [`docs/spec.md`](../docs/spec.md): a timer for sequences of timed intervals (EMOM, Tabata, breathing, custom).

- **The server stores sequences.** One `sequences` table keeps each sequence's title, notes, rounds, prep time, list position, and two JSON documents: the template's own settings (spec 3.3) and the sound settings (spec 3.4). Turbo handles the list, template picker and editor as plain HTML pages.
- **The run screen is a Stimulus controller.** `run_controller.js` reads the sequence as JSON and does spec sections 6–9 on the client: timeline, clock, cue schedule and Web Audio sounds. Nothing about a run is stored.

## Run it

You need Ruby 3.3+ and, for the JavaScript tests, Node 20+.

```bash
cd rails
bin/setup          # installs gems, creates the database with the four example sequences, starts the server
```

Then open <http://localhost:3000>. Later, start it with `bin/dev`.

## Tests

The acceptance examples in spec section 13 are tests here:

```bash
bin/rails test     # Ruby: model rules
npm test           # JavaScript: clock, cues and sound timing (Node's built-in runner, no npm install needed)
bin/ci             # both, plus setup and the seeds
```

| Spec | Ruby (`test/models`, `test/controllers`) | JavaScript (`test/javascript`) |
|------|------------------------------------------|--------------------------------|
| 13.1 Templates | `sequence_template_test.rb`, `sequence_test.rb` | `template.test.js` |
| 13.2 Validation | `sequence_test.rb` | |
| 13.3 Timeline and clock | `timeline_test.rb` | `template.test.js`, `clock.test.js` |
| 13.4 Cues, 8.5 scheduling | | `cues.test.js`, `audio.test.js` |
| 13.5 Breathing circle | | `breath.test.js` |
| 13.6 Formatting | `format_test.rb` | `format.test.js` |
| 13.7 Paste format | | `format.test.js` |
| 13.8 Sounds | | `synth.test.js` |

`sequences_controller_test.rb` covers the screens and storage (create, edit, validation dialog, delete, reorder, the run JSON).

## How the code is organised

```
app/models/
  sequence.rb            The stored sequence: validation (spec 5), list order, starters, run JSON.
  sequence_template.rb   Kinds, starters, presets and template expansion (spec 3.3, 4).
  timeline.rb            Steps in time (spec 6), for totals and validation.
  sound_settings.rb      Sound defaults by kind (spec 3.4).
  format.rb              Clock and duration text (spec 13.6).
app/javascript/nogym/    Plain ES modules, no DOM, loaded through importmap and tested with Node.
  template.js timeline.js clock.js cues.js breath.js format.js synth.js
  audio.js               CuePlayer: schedules cues on the Web Audio clock, one channel per cue type.
app/javascript/controllers/
  run_controller.js      The run screen (spec 10.5, 11).
  editor_controller.js   Live total time and breathing presets in the editor.
  rows_controller.js     Add, delete and reorder EMOM exercises and custom intervals.
  paste_controller.js    EMOM "Paste as text" and "Copy exercises as text".
  stepper_controller.js  − / + steppers.
  sound_preview_controller.js  Plays a sound when it's picked.
  unlock_controller.js   Unlocks audio from the tap on ▶ Start (browsers need a gesture).
```

The `nogym/*` modules import each other by their importmap names (`import … from "nogym/timeline"`). In Node, `package.json` maps the same names to `app/javascript/nogym/*.js` through its `exports` field, so the tests import exactly the files the browser runs.

## Web platform notes

These follow spec section 14:

- Audio starts on the tap that opens a run. If the page is reloaded on the run screen, a "Tap to turn on sound" button appears.
- Cues are scheduled ahead on the `AudioContext` clock, so they stay on time when the tab is throttled. When audio comes back after an interruption, or the page becomes visible again, the cues are scheduled again from the clock.
- The Screen Wake Lock is requested when a run starts and again whenever the page becomes visible.
- Vibration uses `navigator.vibrate` where it exists (not in iOS Safari).
- Leaving the run screen in any way, including the back button or a Turbo visit, stops the run.
- Keyboard: Space pauses and resumes, ← and → skip, Esc asks to stop.

Differences from the iOS app: there's no swipe-to-delete. Delete and reorder live in the list's Edit mode. "Sounds" is a section of the editor rather than its own screen.

## Production

The app has no encrypted credentials file. Set `SECRET_KEY_BASE` in production.
