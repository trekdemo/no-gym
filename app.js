'use strict';

const STORAGE_KEY = 'no-gym.workouts';
const PREP_MS = 10_000;
const MINUTE_MS = 60_000;
const DISARM_MS = 3_000;
const DEFAULT_REPS = 10;
const DEFAULT_SETS = 3;

const app = document.getElementById('app');

// A workout is { id, title, description, sets, exercises: [{ name, reps }] }.
// The description is optional free text; workouts saved before it existed lack it.
// Reps are null for entries that aren't counted, like "REST".
const store = {
  all() {
    try {
      const saved = JSON.parse(localStorage.getItem(STORAGE_KEY));
      return Array.isArray(saved) ? saved : [];
    } catch {
      return [];
    }
  },
  find(id) {
    return this.all().find((workout) => workout.id === id);
  },
  save(workout) {
    const workouts = this.all();
    const index = workouts.findIndex(({ id }) => id === workout.id);
    if (index === -1) workouts.push(workout);
    else workouts[index] = workout;
    this.write(workouts);
  },
  remove(id) {
    this.write(this.all().filter((workout) => workout.id !== id));
  },
  write(workouts) {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(workouts));
  },
};

function h(tag, props = {}, ...children) {
  const element = document.createElement(tag);
  for (const [key, value] of Object.entries(props)) {
    if (key.startsWith('on')) element.addEventListener(key.slice(2), value);
    else if (key in element) element[key] = value;
    else element.setAttribute(key, value);
  }
  element.append(...children.flat().filter(Boolean));
  return element;
}

// Lucide icons (lucide.dev, v1.66.0, ISC licence).
const ICONS = {
  play: '<path d="M5 5a2 2 0 0 1 3.008-1.728l11.997 6.998a2 2 0 0 1 .003 3.458l-12 7A2 2 0 0 1 5 19z"/>',
  pause: '<rect x="14" y="3" width="5" height="18" rx="1"/><rect x="5" y="3" width="5" height="18" rx="1"/>',
  square: '<rect width="18" height="18" x="3" y="3" rx="2"/>',
};

// The label gives the icon's button its name for screen readers.
function icon(name, label) {
  const template = document.createElement('template');
  template.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" role="img" aria-label="${label}">${ICONS[name]}</svg>`;
  return template.content.firstElementChild;
}

// Destructive actions take a second tap, so a sweaty finger can't trigger them.
function confirmButton(label, armedLabel, onConfirm) {
  let disarmTimer = null;
  const button = h('button', {
    type: 'button',
    className: 'danger',
    onclick() {
      if (disarmTimer !== null) {
        clearTimeout(disarmTimer);
        onConfirm();
        return;
      }
      button.replaceChildren(armedLabel);
      button.classList.add('armed');
      disarmTimer = setTimeout(() => {
        disarmTimer = null;
        button.replaceChildren(label);
        button.classList.remove('armed');
      }, DISARM_MS);
    },
  }, label);
  return button;
}

function plural(count, noun) {
  return `${count} ${noun}${count === 1 ? '' : 's'}`;
}

function totalMinutes(workout) {
  return workout.sets * workout.exercises.length;
}

function describeStep({ reps, name }) {
  return reps === null ? name : `${reps} × ${name}`;
}

function newId() {
  return Date.now().toString(36) + Math.random().toString(36).slice(2, 8);
}

// --- Workout list ---

function renderList() {
  const workouts = store.all();
  app.replaceChildren(
    h('header', {},
      h('h1', {}, 'No Gym'),
      h('button', { type: 'button', className: 'primary', onclick: () => { location.hash = '#/new'; } }, 'New workout'),
    ),
    workouts.length === 0
      ? h('p', { className: 'muted empty' }, 'No workouts yet. Create one to start your first EMOM.')
      : h('ul', { className: 'cards' }, workouts.map(workoutCard)),
  );
}

function workoutCard(workout) {
  return h('li', { className: 'card' },
    h('h2', {}, workout.title),
    workout.description && h('p', { className: 'description' }, workout.description),
    h('p', { className: 'muted' },
      `${plural(workout.sets, 'set')} · ${plural(workout.exercises.length, 'exercise')} · ${totalMinutes(workout)} min`),
    h('div', { className: 'actions' },
      h('button', { type: 'button', className: 'primary', onclick: () => startRun(workout) }, 'Start'),
      h('button', { type: 'button', onclick: () => { location.hash = `#/edit/${workout.id}`; } }, 'Edit'),
    ),
  );
}

// --- Editor ---

// Reads one exercise per line, like "Min 1: 10 Deadlifts" or "Min 8: REST".
// Line order decides the order, so the minute numbers are only stripped.
function parseExercises(text) {
  return text
    .split('\n')
    .map((line) => line.trim().replace(/^min(?:ute)?\s*\d+\s*[:.\-–]\s*/i, ''))
    .filter((line) => line !== '')
    .map((line) => {
      const counted = line.match(/^(\d+)\s*[x×]?\s+(.+)$/i);
      return counted
        ? { name: counted[2], reps: Number(counted[1]) }
        : { name: line, reps: null };
    });
}

function parseReps(reps) {
  return reps === null || reps === '' ? null : Number(reps);
}

// Drafts hold raw input values, so names need trimming and reps parsing.
function cleanExercises(draftExercises) {
  return draftExercises
    .map(({ name, reps }) => ({ name: name.trim(), reps: parseReps(reps) }))
    .filter(({ name }) => name !== '');
}

// The inverse of parseExercises: "<reps> <name>" per line, or just the name when uncounted.
function formatExercises(exercises) {
  return exercises
    .map(({ reps, name }) => (reps === null ? name : `${reps} ${name}`) + '\n')
    .join('');
}

function validate(draft) {
  const title = draft.title.trim();
  const description = (draft.description ?? '').trim();
  const sets = Number(draft.sets);
  const exercises = cleanExercises(draft.exercises);

  if (title === '') return { error: 'Give the workout a title.' };
  if (!Number.isInteger(sets) || sets < 1) return { error: 'Sets must be a whole number of at least 1.' };
  if (exercises.length === 0) return { error: 'Add at least one exercise.' };
  if (exercises.some(({ reps }) => reps !== null && (!Number.isInteger(reps) || reps < 1))) {
    return { error: 'Reps must be blank or a whole number of at least 1.' };
  }
  return { workout: { id: draft.id, title, description, sets, exercises } };
}

function renderEditor(existing) {
  const draft = existing
    ? structuredClone(existing)
    : { id: newId(), title: '', description: '', sets: DEFAULT_SETS, exercises: [{ name: '', reps: DEFAULT_REPS }] };

  const rows = h('div', { className: 'rows' });
  const errorLine = h('p', { className: 'error', role: 'alert', hidden: true });

  function drawRows() {
    rows.replaceChildren(...draft.exercises.map((exercise, index) => h('div', { className: 'row' },
      h('input', {
        className: 'name',
        value: exercise.name,
        placeholder: 'Exercise',
        autocapitalize: 'sentences',
        'aria-label': `Exercise ${index + 1} name`,
        oninput: (event) => { exercise.name = event.target.value; },
      }),
      h('input', {
        className: 'reps',
        type: 'number',
        inputMode: 'numeric',
        min: 1,
        value: exercise.reps,
        placeholder: '–',
        'aria-label': `Exercise ${index + 1} reps`,
        oninput: (event) => { exercise.reps = event.target.value; },
      }),
      h('button', {
        type: 'button',
        className: 'icon',
        disabled: index === 0,
        'aria-label': `Move exercise ${index + 1} up`,
        onclick() {
          draft.exercises.splice(index - 1, 0, draft.exercises.splice(index, 1)[0]);
          drawRows();
        },
      }, '↑'),
      h('button', {
        type: 'button',
        className: 'icon',
        disabled: draft.exercises.length === 1,
        'aria-label': `Remove exercise ${index + 1}`,
        onclick() {
          draft.exercises.splice(index, 1);
          drawRows();
        },
      }, '×'),
    )));
  }
  drawRows();

  function showError(error) {
    errorLine.hidden = !error;
    errorLine.textContent = error ?? '';
  }

  const pastedText = h('textarea', {
    rows: 8,
    placeholder: 'Min 1: 10 Deadlifts\nMin 2: 10 Sit-Ups\nMin 3: REST',
    'aria-label': 'Exercises as text, one per line',
  });
  const pasteBox = h('details', { className: 'paste' },
    h('summary', {}, 'Paste as text'),
    pastedText,
    h('button', {
      type: 'button',
      onclick() {
        const exercises = parseExercises(pastedText.value);
        if (exercises.length === 0) {
          showError('Paste at least one exercise, one per line.');
          return;
        }
        showError(null);
        draft.exercises = exercises;
        drawRows();
        pastedText.value = '';
        pasteBox.open = false;
      },
    }, 'Replace exercises'),
    h('button', {
      type: 'button',
      async onclick(event) {
        const button = event.currentTarget;
        const exercises = cleanExercises(draft.exercises);
        if (exercises.length === 0) {
          showError('Add at least one exercise to export.');
          return;
        }
        showError(null);
        const text = formatExercises(exercises);
        try {
          await navigator.clipboard.writeText(text);
          button.textContent = 'Copied!';
          setTimeout(() => { button.textContent = 'Copy exercises as text'; }, 1500);
        } catch {
          // Clipboard access can be denied, so show the text to copy by hand.
          pastedText.value = text;
          pastedText.select();
        }
      },
    }, 'Copy exercises as text'),
  );

  function submit(event) {
    event.preventDefault();
    const { error, workout } = validate(draft);
    showError(error);
    if (error) return;
    try {
      store.save(workout);
      location.hash = '#/';
    } catch {
      showError('Could not save: browser storage is unavailable or full.');
    }
  }

  app.replaceChildren(
    h('header', {}, h('h1', {}, existing ? 'Edit workout' : 'New workout')),
    h('form', { onsubmit: submit, noValidate: true },
      h('label', { className: 'field' },
        h('span', {}, 'Title'),
        h('input', {
          value: draft.title,
          placeholder: 'Morning EMOM',
          autocapitalize: 'sentences',
          oninput: (event) => { draft.title = event.target.value; },
        }),
      ),
      h('label', { className: 'field' },
        h('span', {}, 'Description (optional)'),
        h('textarea', {
          rows: 3,
          value: draft.description ?? '',
          placeholder: 'Focus, equipment, notes…',
          autocapitalize: 'sentences',
          oninput: (event) => { draft.description = event.target.value; },
        }),
      ),
      h('label', { className: 'field sets' },
        h('span', {}, 'Sets'),
        h('input', {
          type: 'number',
          inputMode: 'numeric',
          min: 1,
          value: draft.sets,
          oninput: (event) => { draft.sets = event.target.value; },
        }),
      ),
      h('div', {},
        h('div', { className: 'legend' }, 'Exercises and reps — one per minute'),
        rows,
        h('button', {
          type: 'button',
          className: 'add',
          onclick() {
            draft.exercises.push({ name: '', reps: DEFAULT_REPS });
            drawRows();
            rows.lastElementChild.querySelector('.name').focus();
          },
        }, 'Add exercise'),
        pasteBox,
      ),
      errorLine,
      h('div', { className: 'form-actions' },
        h('button', { type: 'submit', className: 'primary' }, 'Save'),
        h('button', { type: 'button', onclick: () => { location.hash = '#/'; } }, 'Cancel'),
        existing && confirmButton('Delete', 'Tap again to delete', () => {
          store.remove(existing.id);
          location.hash = '#/';
        }),
      ),
    ),
  );
}

// --- Sound ---

let audio = null;

// Browsers only let audio start from a user gesture, so this runs on "Start".
function unlockAudio() {
  const AudioContextClass = window.AudioContext ?? window.webkitAudioContext;
  if (!AudioContextClass) return;
  audio ??= new AudioContextClass();
  audio.resume();
}

function beep(frequency, seconds) {
  if (!audio) return;
  const oscillator = audio.createOscillator();
  const gain = audio.createGain();
  oscillator.frequency.value = frequency;
  gain.gain.setValueAtTime(0.3, audio.currentTime);
  gain.gain.exponentialRampToValueAtTime(0.001, audio.currentTime + seconds);
  oscillator.connect(gain).connect(audio.destination);
  oscillator.start();
  oscillator.stop(audio.currentTime + seconds);
}

const countdownBeep = () => beep(660, 0.15);
const minuteBeep = () => {
  beep(990, 0.5);
  navigator.vibrate?.(300);
};

// --- Keep the screen on while training ---

let wakeLock = null;

async function holdWakeLock() {
  try {
    wakeLock = await navigator.wakeLock?.request('screen');
  } catch {
    wakeLock = null;
  }
}

function releaseWakeLock() {
  wakeLock?.release();
  wakeLock = null;
}

document.addEventListener('visibilitychange', () => {
  // The browser drops the lock whenever the page is hidden.
  if (document.visibilityState === 'visible' && run?.interval) holdWakeLock();
});

// --- EMOM run ---

let run = null;

function buildSteps(workout) {
  const steps = [];
  for (let set = 1; set <= workout.sets; set++) {
    for (const exercise of workout.exercises) steps.push({ ...exercise, set });
  }
  return steps;
}

// Position is derived from timestamps, so a throttled timer can't make the clock drift.
function runPosition(current, now = Date.now()) {
  const elapsed = (current.pausedAt ?? now) - current.startedAt - current.pausedTotal;
  if (elapsed < PREP_MS) return { phase: 'prep', index: -1, remainingMs: PREP_MS - elapsed, lengthMs: PREP_MS };

  const workElapsed = elapsed - PREP_MS;
  const index = Math.floor(workElapsed / MINUTE_MS);
  if (index >= current.steps.length) return { phase: 'done', index };
  return { phase: 'work', index, remainingMs: MINUTE_MS - (workElapsed % MINUTE_MS), lengthMs: MINUTE_MS };
}

function startRun(workout) {
  unlockAudio();
  holdWakeLock();
  run = {
    workout,
    steps: buildSteps(workout),
    startedAt: Date.now(),
    pausedAt: null,
    pausedTotal: 0,
    lastIndex: -1,
    lastSeconds: null,
    interval: null,
    view: null,
  };
  location.hash = `#/run/${workout.id}`;
}

function stopRun() {
  if (!run) return;
  clearInterval(run.interval);
  releaseWakeLock();
  run = null;
}

function togglePause() {
  if (run.pausedAt === null) {
    run.pausedAt = Date.now();
  } else {
    run.pausedTotal += Date.now() - run.pausedAt;
    run.pausedAt = null;
  }
  tick();
}

function renderRun() {
  const view = {
    status: h('p', { className: 'muted progress-label' }),
    clock: h('div', { className: 'clock', role: 'timer' }),
    fill: h('div', { className: 'clock fill', 'aria-hidden': 'true' }),
    exercise: h('p', { className: 'exercise' }),
    next: h('p', { className: 'next muted' }),
    pause: h('button', { type: 'button', className: 'primary', onclick: togglePause }),
    pauseIcon: icon('pause', 'Pause'),
    resumeIcon: icon('play', 'Resume'),
  };
  view.bar = h('div', { className: 'bar' }, view.clock, view.fill);
  run.view = view;

  app.replaceChildren(h('div', { className: 'timer run' },
    h('div', { className: 'run-header' },
      h('h2', {}, run.workout.title),
      view.status,
    ),
    view.exercise,
    view.next,
    view.bar,
    h('div', { className: 'run-controls' },
      view.pause,
      confirmButton(icon('square', 'Stop'), 'Tap again to stop', () => { location.hash = '#/'; }),
    ),
  ));

  tick();
  run.interval = setInterval(tick, 200);
}

function renderDone() {
  const { workout } = run;
  clearInterval(run.interval);
  run.interval = null;
  releaseWakeLock();
  app.replaceChildren(h('div', { className: 'timer' },
    h('div', { className: 'stage' },
      h('h1', {}, 'Done!'),
      h('p', { className: 'muted' },
        `${workout.title} · ${plural(workout.sets, 'set')} · ${totalMinutes(workout)} min`),
    ),
    h('div', { className: 'controls' },
      h('button', { type: 'button', className: 'primary', onclick: () => { location.hash = '#/'; } }, 'Back to workouts'),
    ),
  ));
}

function playCues(position, seconds) {
  if (position.index !== run.lastIndex) {
    minuteBeep();
  } else if (seconds !== run.lastSeconds && seconds <= 3) {
    countdownBeep();
  }
  run.lastIndex = position.index;
  run.lastSeconds = seconds;
}

function tick() {
  const position = runPosition(run);
  if (position.phase === 'done') {
    minuteBeep();
    renderDone();
    return;
  }

  const { view, steps, workout, pausedAt } = run;
  const seconds = Math.ceil(position.remainingMs / 1000);
  if (pausedAt === null) playCues(position, seconds);

  const isPrep = position.phase === 'prep';
  const step = steps[position.index];
  const upcoming = steps[position.index + 1];

  view.status.textContent = isPrep
    ? `${plural(workout.sets, 'set')} · ${totalMinutes(workout)} min`
    : `Set ${step.set} of ${workout.sets} · Minute ${position.index + 1} of ${steps.length}`;
  view.clock.textContent = seconds === 60 ? '1:00' : `0:${String(seconds).padStart(2, '0')}`;
  view.fill.textContent = view.clock.textContent;
  view.bar.classList.toggle('ending', seconds <= 3);
  view.fill.style.clipPath = `inset(0 ${(1 - position.remainingMs / position.lengthMs) * 100}% 0 0)`;
  view.exercise.textContent = isPrep ? 'Get ready' : describeStep(step);
  view.next.textContent = upcoming ? `Next: ${describeStep(upcoming)}` : 'Last one!';
  view.pause.replaceChildren(pausedAt === null ? view.pauseIcon : view.resumeIcon);
  view.pause.classList.toggle('warning', pausedAt === null);
}

// --- Routing ---

function route() {
  const [, screen, id] = location.hash.split('/');

  // Leaving the timer by any route, including the back button, ends the run.
  if (screen !== 'run') stopRun();

  if (screen === 'new') {
    renderEditor(null);
  } else if (screen === 'edit' && store.find(id)) {
    renderEditor(store.find(id));
  } else if (screen === 'run' && run) {
    renderRun();
  } else {
    if (location.hash !== '' && location.hash !== '#/') history.replaceState(null, '', '#/');
    renderList();
  }
}

window.addEventListener('hashchange', route);
route();
