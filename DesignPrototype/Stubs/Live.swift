import SwiftUI

// PROTOTYPE STUB — replaced by Screens/Live when that area is built. Only compiled by scripts/capture.sh
// for OTHER areas' isolated builds. Keep every initializer identical to the real view.

/// Stub: shows the Cardio area's panel when the session's focus is cardio, so the Cardio
/// area can see its work in an isolated build.
struct LiveWorkoutScreen: View {
    @Environment(Store.self) private var store
    var body: some View {
        if store.session?.focus == .cardio {
            CardioLivePanel()
        } else {
            StubPlaceholder("Live workout")
        }
    }
}
