# Domain

This document describes the core entities of No Gym and the actions a user can do with them.

## Terms

| Term | Meaning |
|------|---------|
| **Workout** | A saved plan. It has a title, an optional description, a number of sets, and a list of exercises. |
| **Exercise** | One entry in a workout. It has a name and an optional rep count. |
| **Reps** | The number of repetitions. An exercise with no reps is not counted (for example, `REST`). |
| **Set** | One full pass through the list of exercises. |
| **Step** | One minute of work. One step is one exercise in one set. |
| **Run** | One live execution of a workout, with a timer. |
| **EMOM** | "Every minute on the minute". Each minute starts one new exercise. |

## Entities

A workout contains an ordered list of exercises. The order of the list is the order of the minutes.

```mermaid
classDiagram
    class Workout {
        id
        title
        description  (optional)
        sets  (whole number, 1 or more)
    }
    class Exercise {
        name
        reps  (optional, 1 or more)
    }
    class Run {
        startedAt
        pausedAt
        pausedTotal
    }
    class Step {
        set
        name
        reps
    }

    Workout "1" *-- "1..*" Exercise : contains, ordered
    Workout "1" <.. "0..1" Run : is run by
    Run "1" *-- "1..*" Step : is made of
```

### Workout rules

- A workout must have a title.
- `sets` must be a whole number of 1 or more. The default is 3.
- A workout must have at least one exercise.
- A rep count must be blank or a whole number of 1 or more. The default is 10.
- Workouts are saved in the browser local storage. They stay on the device.

### Run rules

A run is temporary. It is not saved. The app builds the steps from the workout:

`number of steps = sets × number of exercises`

`total time = number of steps` minutes (plus 10 seconds of preparation)

Example: a workout with 3 exercises and 2 sets has 6 steps. The run lasts 6 minutes.

```mermaid
flowchart LR
    W["Workout<br/>2 sets<br/>A, B, C"] --> S1["Set 1<br/>min 1: A<br/>min 2: B<br/>min 3: C"]
    S1 --> S2["Set 2<br/>min 4: A<br/>min 5: B<br/>min 6: C"]
```

## Actions

| Action | Where | Result |
|--------|-------|--------|
| Create a workout | List → **New workout** | The app saves a new workout. |
| Edit a workout | Card → **Edit** | The app replaces the saved workout. |
| Delete a workout | Editor → **Delete** (tap two times) | The app removes the workout. |
| Paste exercises | Editor → text area | The app reads one exercise for each line. |
| Copy exercises as text | Editor → **Copy exercises as text** | The app copies the exercises in the paste format. |
| Start a run | Card → **Start** | The timer begins with a preparation period. |
| Pause or resume | Run screen | The timer stops or continues. |
| Stop a run | Run screen → **Stop** (tap two times) | The run ends. The app goes back to the list. |

### Paste format

Write one exercise for each line. A leading number is the reps. The prefix `Min N:` is optional and the app ignores it. The order of the lines sets the order of the minutes.

```text
Min 1: 10 Deadlifts
Min 2: 10 Sit-Ups
Min 3: REST
```

| Line | Name | Reps |
|------|------|------|
| `Min 1: 10 Deadlifts` | Deadlifts | 10 |
| `Min 3: REST` | REST | none |

### Workout lifecycle

```mermaid
stateDiagram-v2
    [*] --> Saved : Create
    Saved --> Saved : Edit
    Saved --> [*] : Delete
    Saved --> Running : Start
    Running --> Saved : Stop or finish
```

## Run

A run has these phases:

1. **Prep**: 10 seconds. The screen shows "Get ready".
2. **Work**: one 60-second period for each step. The screen shows the current exercise and the next exercise.
3. **Done**: the app shows "Done!".

```mermaid
stateDiagram-v2
    [*] --> Prep : Start
    Prep --> Work : 10 s
    Work --> Work : 60 s, more steps
    Work --> Paused : Pause
    Paused --> Work : Resume
    Work --> Done : 60 s, last step
    Prep --> Paused : Pause
    Paused --> Prep : Resume
    Work --> [*] : Stop
    Prep --> [*] : Stop
    Done --> [*] : Back to workouts
```

### Run sequence

```mermaid
sequenceDiagram
    actor User
    participant App
    participant Timer
    User->>App: Tap Start
    App->>App: Build steps from workout
    App->>Timer: Begin 10 s prep
    loop Each step
        Timer-->>App: New minute starts
        App-->>User: Beep and show exercise
    end
    Timer-->>App: Last minute ends
    App-->>User: Beep and show "Done!"
```

### Cues

| Event | Cue |
|-------|-----|
| A new minute starts | Long beep and vibration |
| Last 3 seconds of a period | Short beep each second |
| The workout ends | Long beep and vibration |

The app keeps the screen on during a run. When the user leaves the run screen, the run ends.

The app finds the position from the clock time, not from a counter. A slow timer cannot make the clock drift.
