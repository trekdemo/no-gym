// The breathing circle's scale (spec 10.5): it grows on inhale, shrinks on
// exhale, and stays where it was on hold.
export const SMALL = 0.45

export function breathScale(timeline, stepIndex, fraction, small = SMALL) {
  const steps = timeline.steps
  if (stepIndex < 0 || stepIndex >= steps.length) return small
  const eased = 0.5 - 0.5 * Math.cos(Math.PI * Math.min(1, Math.max(0, fraction)))
  switch (steps[stepIndex].interval.role) {
    case "inhale":
      return small + (1 - small) * eased
    case "exhale":
      return 1 - (1 - small) * eased
    case "hold":
      for (let index = stepIndex - 1; index >= 0; index--) {
        const role = steps[index].interval.role
        if (role === "inhale") return 1
        if (role === "exhale") return small
      }
      return small
    default:
      return small
  }
}
