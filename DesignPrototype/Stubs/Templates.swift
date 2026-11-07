import SwiftUI

// PROTOTYPE STUB — replaced by Screens/Templates when that area is built. Only compiled by scripts/capture.sh
// for OTHER areas' isolated builds. Keep every initializer identical to the real view.

struct TemplateDetailScreen: View { let templateID: UUID; var body: some View { StubPlaceholder("Template") } }
struct TemplateEditorSheet: View { let templateID: UUID?; var body: some View { StubPlaceholder("Template editor") } }
struct SaveAsTemplateSheet: View { let workoutID: UUID; var body: some View { StubPlaceholder("Save as template") } }
extension View { func templateDriftPresenter() -> some View { self } }
