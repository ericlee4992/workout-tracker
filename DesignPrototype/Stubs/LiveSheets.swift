import SwiftUI

// PROTOTYPE STUB — replaced by Screens/LiveSheets when that area is built. Only compiled by scripts/capture.sh
// for OTHER areas' isolated builds. Keep every initializer identical to the real view.

struct ExercisePickerSheet: View { var body: some View { StubPlaceholder("Exercise picker") } }
struct AddByMachineSheet: View { var body: some View { StubPlaceholder("Add by machine") } }
struct EquipmentSheet: View { let entryID: UUID; var body: some View { StubPlaceholder("Equipment") } }
struct BarPickerSheet: View { let entryID: UUID; let setID: UUID?; var body: some View { StubPlaceholder("Bar") } }
struct PreviousPerformanceSheet: View { let entryID: UUID; var body: some View { StubPlaceholder("Previous") } }
struct RestSettingsSheet: View { let entryID: UUID; var body: some View { StubPlaceholder("Rest settings") } }
struct MaxHeartRateSheet: View { var body: some View { StubPlaceholder("Max heart rate") } }
