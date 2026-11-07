import SwiftUI

// Add Exercise… on a past workout: search, then the catalog grouped by body area (head to
// toe). Picking one adds it as defined today (no equipment guessed) and opens its first set.
// History-owned so the shell's live-workout picker keeps adding to the live session.

struct HistoryExercisePickerSheet: View {
    var onPick: (UUID) -> Void
    @Environment(Store.self) private var store
    @Environment(\.look) private var look
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        let sections = store.exerciseSections(query: query)
        VStack(spacing: 0) {
            ZStack {
                Text("Add Exercise")
                    .font(look.font.navTitle)
                    .foregroundStyle(look.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                HStack {
                    GlassCapsuleButton("Cancel") { dismiss() }
                    Spacer()
                }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 14)
            .padding(.bottom, 10)
            SearchFieldView(text: $query, prompt: "Search exercises")
                .padding(.horizontal, look.space.margin)
                .padding(.bottom, 12)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.group?.label ?? "Uncategorized")
                                .font(.system(.footnote, weight: .semibold))
                                .foregroundStyle(look.textSecondary)
                                .padding(.leading, 4)
                                .accessibilityAddTraits(.isHeader)
                            HistoryListPanel {
                                ForEach(section.exercises) { exercise in
                                    Button {
                                        dismiss()
                                        onPick(exercise.id)
                                    } label: {
                                        HStack(spacing: 10) {
                                            Text(exercise.name)
                                                .font(.system(.body, weight: .semibold))
                                                .foregroundStyle(look.textPrimary)
                                            Spacer(minLength: 8)
                                            if exercise.loadType != .weighted { HistoryTextBadge(exercise.loadType.badge) }
                                            Image(systemName: "plus")
                                                .font(.system(.footnote, weight: .bold))
                                                .foregroundStyle(look.textSecondary)
                                        }
                                        .padding(.horizontal, 16)
                                        .frame(maxWidth: .infinity, minHeight: 50)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(HistoryRowPressStyle())
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.immediately)
        }
        .lookSheetGround()
        .presentationBackground(look.groundSheet)
        .presentationDetents([.large])
    }
}
