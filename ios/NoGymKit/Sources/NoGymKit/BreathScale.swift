import Foundation

extension Timeline {
    /// The size of the breathing circle, from `small` to 1.
    /// It grows on inhale, shrinks on exhale, and stays where it was on hold.
    public func breathScale(stepIndex: Int, fraction: Double, small: Double = 0.45) -> Double {
        guard steps.indices.contains(stepIndex) else { return small }
        // Ease in and out, so the circle moves like a breath.
        let eased = 0.5 - 0.5 * cos(.pi * min(1, max(0, fraction)))
        switch steps[stepIndex].interval.role {
        case .inhale:
            return small + (1 - small) * eased
        case .exhale:
            return 1 - (1 - small) * eased
        case .hold:
            // Look back for the last inhale or exhale.
            for index in stride(from: stepIndex - 1, through: 0, by: -1) {
                switch steps[index].interval.role {
                case .inhale: return 1
                case .exhale: return small
                default: continue
                }
            }
            return small
        case .work, .rest:
            return small
        }
    }
}
