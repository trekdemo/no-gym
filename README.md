# No Gym

A small EMOM (every minute on the minute) timer. Each minute is one exercise, and the list repeats for the number of sets, so a workout lasts `sets × exercises` minutes.

Workouts live in the browser's local storage. There is no backend or build step, and they stay on the device they were created on.

The editor also accepts a pasted list, one exercise per line. A leading number is the reps, and an entry without one has no rep count:

```text
Min 1: 10 Deadlifts
Min 2: 10 Sit-Ups
Min 3: REST
```

## Run locally

```bash
python3 -m http.server 8123
```

## Hosting

GitHub Pages serves the root of `main` at https://no-gym.gergo.dev. That needs a DNS record of `no-gym CNAME trekdemo.github.io`.
