import SwiftUI

// PROTOTYPE STUB — replaced by Screens/Gyms when that area is built. Only compiled by scripts/capture.sh
// for OTHER areas' isolated builds. Keep every initializer identical to the real view.

struct GymsScreen: View { var body: some View { StubPlaceholder("Gyms") } }
struct GymDetailScreen: View { let gymID: UUID; var body: some View { StubPlaceholder("Gym") } }
struct MachineDetailScreen: View { let machineID: UUID; var body: some View { StubPlaceholder("Machine") } }
struct EditGymSheet: View { let gymID: UUID?; var body: some View { StubPlaceholder("Edit gym") } }
struct ModelPickerSheet: View { let machineID: UUID?; var body: some View { StubPlaceholder("Model picker") } }
struct DeletedMachinesScreen: View { let gymID: UUID; var body: some View { StubPlaceholder("Deleted machines") } }
