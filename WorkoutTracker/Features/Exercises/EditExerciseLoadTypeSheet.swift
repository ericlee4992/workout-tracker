import SwiftData
import SwiftUI

// Milestone 8, ticket 02 — correcting an exercise's load type; Floodlight ticket 08, E05.
//
// WHY THIS EXISTS: the assisted maths was always right. `RecordsMath` ranks
// assisted lower-is-better and excludes it from e1RM, and `isLoggable` already
// accepts 0 for assisted and bodyweight-plus. What the user could not do was
// FIX A WRONG TAG. `loadType` was set once, at creation, and never again — so a
// supported dip logged as `weighted` ranked heaviest-wins forever, and the only
// escape was a different exercise, which splits history (D23, D36).
//
// The four types are tiles with the selected type's one line (user decision 3, ticket 08: the
// prototype's shortened copy). Choosing a different type brings in the consequence as a two-row
// ledger — sets logged from now on take the new type; the sets already logged keep theirs (history
// is frozen, D23). Save is the one filled command, on only after a change.

struct EditExerciseLoadTypeSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let exercise: Exercise
    @State private var loadType: LoadType = .weighted
    @State private var loaded = false
    @State private var savedTick = 0
    @State private var headerHeight: CGFloat = 0
    @State private var bodyHeight: CGFloat = 0

    private var originalLoadType: LoadType {
        exercise.isDeleted ? .weighted : exercise.loadType
    }
    private var changed: Bool { loaded && loadType != originalLoadType }

    var body: some View {
        VStack(spacing: 0) {
            ExercisesSheetHeader(title: "Load Type", subtitle: exercise.isDeleted ? nil : exercise.name,
                                 cancel: { dismiss() },
                                 trailing: .commit("Save", enabled: changed, identifier: "saveLoadType", action: save))
                .exercisesMeasureHeight($headerHeight)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ExercisesLoadTypeGrid(selection: $loadType)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("editLoadTypePicker")
                    if changed {
                        consequence
                            .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 10)
                .padding(.bottom, 28)
                .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.84), value: changed)
            }
            .scrollIndicators(.hidden)
            .exercisesMeasureContent($bodyHeight)
        }
        // Fitted: the sheet grows by the ledger when a different type is chosen.
        .exercisesSheetChrome(fitted: headerHeight + bodyHeight)
        .sensoryFeedback(.success, trigger: savedTick)
        .onAppear {
            guard !loaded, !exercise.isDeleted else { return }
            loadType = exercise.loadType
            loaded = true
        }
    }

    // MARK: Consequence

    /// What the change touches (sets from now on → the new type) and what it leaves alone (the
    /// sets already logged keep theirs, counted so "does not rewrite the past" is a number).
    private var consequence: some View {
        // By the type each set was logged UNDER (its snapshot), not the exercise's current type — a
        // corrected exercise's older sets keep the old one, and history can hold several
        // (codex-review-08 #3). One row per type.
        let logged = ExerciseOverview.loggedSetCounts(of: exercise)
        return VStack(spacing: 0) {
            ledgerRow(symbol: "arrow.forward.circle", text: "Sets you log from now on", type: loadType, emphasized: true)
            ForEach(logged, id: \.loadType) { item in
                LookDivider().padding(.leading, 52)
                ledgerRow(symbol: "clock.arrow.circlepath",
                          text: "\(item.sets) set\(item.sets == 1 ? "" : "s") already logged",
                          type: item.loadType, emphasized: false)
                    .accessibilityIdentifier("editLoadTypeHistoryNote")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.panel)
    }

    private func ledgerRow(symbol: String, text: String, type: LoadType, emphasized: Bool) -> some View {
        let ax = typeSize.isAccessibilitySize
        let layout = ax ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 10))
        return HStack(alignment: ax ? .top : .center, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(emphasized ? look.textPrimary : look.textSecondary)
                .frame(width: 26)
            layout {
                Text(text)
                    .font(.system(.subheadline, weight: emphasized ? .semibold : .regular))
                    .foregroundStyle(emphasized ? look.textPrimary : look.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !ax { Spacer(minLength: 4) }
                ExercisesTag(type.badge, symbol: type.rankSymbol)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(text): \(type.badge)")
    }

    private func save() {
        guard !exercise.isDeleted else { dismiss(); return }
        guard changed else { return }
        exercise.loadType = loadType
        // Marks the row so `CatalogSeeder` stops overwriting it. Without this
        // the correction survives only until the next catalog version and then
        // silently reverts (see the field's own comment).
        exercise.loadTypeUserOverridden = true
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save load type: \(error)")
        }
        savedTick += 1
        dismiss()
    }
}
