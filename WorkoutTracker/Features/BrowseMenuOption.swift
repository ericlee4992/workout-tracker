import SwiftUI

/// One choice inside a browsing menu (ticket 21): grouping modes, body-area
/// and equipment-type filters, on the model picker, the gym's machine list and
/// the Exercises tab.
///
/// Deliberately a `Button` rather than a `Picker` row. A `Picker` inside a
/// menu renders options the caller cannot label, so neither the checkmark nor
/// the accessibility identifier is under our control — and these menus are how
/// the UI test reaches a single model in a 1887-model catalog.
struct BrowseMenuOption: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            if isSelected {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }
}
