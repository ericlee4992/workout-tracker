import SwiftUI

// PROTOTYPE STUB — replaced by Screens/History when that area is built. Only compiled by scripts/capture.sh
// for OTHER areas' isolated builds. Keep every initializer identical to the real view.

struct HistoryScreen: View { var body: some View { StubPlaceholder("History") } }
struct HistoryCalendarSheet: View { var body: some View { StubPlaceholder("Calendar") } }
struct WorkoutDetailScreen: View { let workoutID: UUID; var body: some View { StubPlaceholder("Workout detail") } }
struct EditSetSheet: View { let workoutID: UUID; let entryID: UUID; let setID: UUID; var body: some View { StubPlaceholder("Edit set") } }
struct ProgressChartScreen: View { let exerciseID: UUID; let variationID: String?; var body: some View { StubPlaceholder("Progress") } }
