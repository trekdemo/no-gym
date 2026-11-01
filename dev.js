'use strict';

// Development mode: a floating form (shown while hovering a header) for tuning
// the run view's layout ratios and cell styling live. Everything is inert unless
// switched on by having ?dev in the URL; without it nothing is loaded or applied.
(() => {
  const VALUES_KEY = 'no-gym.dev.values';
  const HIDE_DELAY_MS = 300;

  const params = new URLSearchParams(location.search);
  if (!params.has('dev') || params.get('dev') === '0') return;

  const root = document.documentElement;

  // Each control tunes one CSS variable declared in style.css.
  const GROUPS = [
    { title: 'Row heights', controls: [
      { name: '--row-header', label: 'Header', min: 0, max: 30, step: 0.5, unit: 'dvh' },
      { name: '--row-next', label: 'Next', min: 0, max: 40, step: 0.5, unit: 'dvh' },
      { name: '--row-bar', label: 'Clock bar', min: 0, max: 40, step: 0.5, unit: 'dvh' },
      { name: '--row-controls', label: 'Controls', min: 0, max: 40, step: 0.5, unit: 'dvh' },
    ] },
    { title: 'Cells', controls: [
      { name: '--run-gap', label: 'Gap', min: 0, max: 48, step: 1, unit: 'px' },
      { name: '--cell-padding', label: 'Padding', min: 0, max: 48, step: 1, unit: 'px' },
      { name: '--cell-radius', label: 'Radius', min: 0, max: 48, step: 1, unit: 'px' },
      { name: '--cell-border', label: 'Border width', min: 0, max: 12, step: 0.5, unit: 'px' },
      { name: '--edge-darken', label: 'Edge darken', min: 0, max: 100, step: 1, unit: '%' },
    ] },
  ];
  GROUPS.push({ title: 'Cell colours', controls: [
    { name: '--exercise-bg', label: 'Exercise bg' },
    { name: '--exercise-border', label: 'Exercise edge' },
    { name: '--next-bg', label: 'Next bg' },
    { name: '--next-border', label: 'Next edge' },
    { name: '--bar-bg', label: 'Clock bg' },
    { name: '--bar-border', label: 'Clock edge' },
    { name: '--pause-bg', label: 'Pause bg' },
    { name: '--resume-bg', label: 'Resume bg' },
    { name: '--pause-border', label: 'Pause edge' },
    { name: '--resume-border', label: 'Resume edge' },
    { name: '--stop-bg', label: 'Stop bg' },
    { name: '--stop-border', label: 'Stop edge' },
  ].map((control) => ({ ...control, color: true })) });
  const CONTROLS = GROUPS.flatMap((group) => group.controls);

  function loadValues() {
    try {
      return JSON.parse(localStorage.getItem(VALUES_KEY)) ?? {};
    } catch {
      return {};
    }
  }

  function saveValues(values) {
    try {
      localStorage.setItem(VALUES_KEY, JSON.stringify(values));
    } catch { /* tuning still works for this page view */ }
  }

  // The colour input only takes #rrggbb, so let a canvas turn any CSS colour into that.
  const canvas = document.createElement('canvas').getContext('2d');
  function toHex(color) {
    canvas.fillStyle = '#000000';
    canvas.fillStyle = color;
    if (canvas.fillStyle.startsWith('#')) return canvas.fillStyle;
    // Colours like color-mix() may serialise as rgb() or color(); read the pixel instead.
    canvas.clearRect(0, 0, 1, 1);
    canvas.fillRect(0, 0, 1, 1);
    const [r, g, b] = canvas.getImageData(0, 0, 1, 1).data;
    return `#${[r, g, b].map((channel) => channel.toString(16).padStart(2, '0')).join('')}`;
  }

  // Read the stylesheet's defaults before any override is applied.
  const defaults = Object.fromEntries(CONTROLS.map((control) => {
    const computed = getComputedStyle(root).getPropertyValue(control.name).trim();
    return [control.name, control.color ? toHex(computed) : parseFloat(computed)];
  }));
  const values = loadValues();

  const cssValue = ({ unit = '' }, value) => `${value}${unit}`;

  function apply(control, value) {
    root.style.setProperty(control.name, cssValue(control, value));
  }

  for (const control of CONTROLS) {
    if (control.name in values) apply(control, values[control.name]);
  }

  const panel = document.createElement('form');
  panel.id = 'dev-panel';
  panel.hidden = true;
  panel.addEventListener('submit', (event) => event.preventDefault());

  const style = document.createElement('style');
  style.textContent = `
    #dev-panel { position: fixed; top: 8px; right: 8px; z-index: 1000; width: min(280px, calc(100vw - 16px));
      max-height: calc(100dvh - 16px); overflow: auto; padding: 12px; display: grid; gap: 8px;
      border: 1px solid var(--border); border-radius: 12px; background: var(--surface); color: var(--text);
      box-shadow: 0 8px 28px rgb(0 0 0 / 0.25); font-size: 13px; }
    #dev-panel[hidden] { display: none; }
    #dev-panel h3 { margin: 4px 0 0; font-size: 11px; letter-spacing: 0.06em; text-transform: uppercase; color: var(--muted); }
    #dev-panel label { display: grid; grid-template-columns: 96px 1fr 58px; align-items: center; gap: 8px; }
    #dev-panel input { min-height: 0; padding: 0; border: 0; background: none; accent-color: var(--accent); }
    #dev-panel input[type=color] { height: 24px; width: 100%; cursor: pointer; }
    #dev-panel output { text-align: right; font-variant-numeric: tabular-nums; color: var(--muted); }
    #dev-panel .dev-actions { display: flex; gap: 6px; }
    #dev-panel button { flex: 1; min-height: 30px; padding: 0 8px; border-radius: 8px; font-size: 12px; }
  `;

  const outputs = new Map();
  const inputs = new Map();

  function show(control, value) {
    inputs.get(control.name).value = value;
    outputs.get(control.name).textContent = cssValue(control, value);
  }

  for (const group of GROUPS) {
    const title = document.createElement('h3');
    title.textContent = group.title;
    panel.append(title);
    for (const control of group.controls) {
      const input = document.createElement('input');
      if (control.color) input.type = 'color';
      else Object.assign(input, { type: 'range', min: control.min, max: control.max, step: control.step });
      const output = document.createElement('output');
      inputs.set(control.name, input);
      outputs.set(control.name, output);
      input.addEventListener('input', () => {
        const value = control.color ? input.value : Number(input.value);
        values[control.name] = value;
        apply(control, value);
        show(control, value);
        saveValues(values);
      });
      const label = document.createElement('label');
      label.append(control.label, input, output);
      panel.append(label);
      show(control, values[control.name] ?? defaults[control.name]);
    }
  }

  const reset = document.createElement('button');
  reset.type = 'button';
  reset.textContent = 'Reset';
  reset.addEventListener('click', () => {
    for (const control of CONTROLS) {
      delete values[control.name];
      root.style.removeProperty(control.name);
      show(control, defaults[control.name]);
    }
    saveValues(values);
  });

  const copy = document.createElement('button');
  copy.type = 'button';
  copy.textContent = 'Copy CSS';
  copy.addEventListener('click', async () => {
    // Only what was changed, so untouched variables keep following the theme.
    const lines = CONTROLS.filter(({ name }) => name in values)
      .map((control) => `  ${control.name}: ${cssValue(control, values[control.name])};`);
    if (lines.length === 0) lines.push('  /* nothing changed */');
    try {
      await navigator.clipboard.writeText(`:root {\n${lines.join('\n')}\n}`);
      copy.textContent = 'Copied';
    } catch {
      copy.textContent = 'Copy failed';
    }
    setTimeout(() => { copy.textContent = 'Copy CSS'; }, 1500);
  });

  const actions = document.createElement('div');
  actions.className = 'dev-actions';
  actions.append(reset, copy);
  panel.append(actions);

  // The panel is fixed-position and lives outside #app, so it never takes part in the layout.
  document.head.append(style);
  document.body.append(panel);

  let hideTimer = null;
  const isHeader = (target) => target instanceof Element && target.closest('header, .run-header');

  function open() {
    clearTimeout(hideTimer);
    panel.hidden = false;
  }

  function scheduleClose() {
    clearTimeout(hideTimer);
    hideTimer = setTimeout(() => { panel.hidden = true; }, HIDE_DELAY_MS);
  }

  // Delegated, because the app re-renders its headers on every screen change.
  document.addEventListener('mouseover', (event) => {
    if (isHeader(event.target) || panel.contains(event.target)) open();
  });
  document.addEventListener('mouseout', (event) => {
    // Keep the panel open while a slider is being dragged past its edge.
    if (event.buttons === 0 && (isHeader(event.target) || panel.contains(event.target))) scheduleClose();
  });
})();
