import SwiftUI

extension SensoryFeedback {
    static var setComplete: SensoryFeedback { .impact(weight: .medium, intensity: 0.8) }
    static var restDone: SensoryFeedback { .success }
    static var workoutStart: SensoryFeedback { .impact(weight: .heavy, intensity: 0.8) }
}
