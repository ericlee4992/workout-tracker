import SwiftUI

/// N15 (D87): the bookmark in a food screen's bar — filled in the action colour when the food (or meal) is saved. The
/// same face as `SelectedFoodView`'s, so saving reads the same wherever a food opens. It acts at once (no Save needed),
/// as it does there.
struct SaveBookmark: View {
    var isSaved: Bool
    var saveLabel: String
    var removeLabel: String
    var identifier: String
    var action: () -> Void
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            withAnimation(reduceMotion ? nil : .snappy) { action() }
        } label: {
            Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(isSaved ? look.action : look.textPrimary)
                .contentTransition(reduceMotion ? .opacity : .symbolEffect(.replace))
        }
        .accessibilityLabel(isSaved ? removeLabel : saveLabel)
        .accessibilityIdentifier(identifier)
        .accessibilityValue(isSaved ? "Saved" : "")
        .sensoryFeedback(.selection, trigger: isSaved)
    }
}
