import SwiftUI

// PROTOTYPE — E05 Load Type. The four types as tiles, each with which way its records rank
// (assisted is the one that points down), and the selected type's one line. Choosing a
// different type brings in the consequence as a two-line ledger — sets you log from now on
// take the new type, the sets already logged keep theirs (history is frozen, D23 — the
// decision number is no longer shown), each with its badge. Save is the one filled command,
// on only after a change. Opens as a short sheet over the exercise.

struct LoadTypeSheet: View {
    let exerciseID: UUID

    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    /// The sheet root sits outside the prototype's type override (applied inside), so read it too.
    private var isAX: Bool { (router.dynamicTypeOverride ?? typeSize).isAccessibilitySize }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selection: LoadType = .weighted
    @State private var prepared = false
    @State private var savedTick = 0
    @State private var headerHeight: CGFloat = 0
    @State private var bodyHeight: CGFloat = 0

    private var original: LoadType { store.exercise(exerciseID)?.loadType ?? .weighted }
    private var changed: Bool { prepared && selection != original }

    var body: some View {
        VStack(spacing: 0) {
            ExercisesSheetHeader(title: "Load Type", subtitle: store.exercise(exerciseID)?.name,
                                 cancel: { router.dismissSheet() },
                                 trailing: .commit("Save", enabled: changed, action: save))
                .exercisesMeasureHeight($headerHeight)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ExercisesLoadTypeGrid(selection: $selection)
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
        .exercisesSheetPresentation(look, fitted: headerHeight + bodyHeight)
        .sensoryFeedback(.success, trigger: savedTick)
        .onAppear(perform: prepare)
    }

    // MARK: Consequence

    /// A two-line ledger: what the change touches (sets from now on → the new type) and what it
    /// leaves alone (the sets already logged keep theirs). The badges carry the types.
    private var consequence: some View {
        let logged = store.exercisesLoggedSetCount(exerciseID)
        return VStack(spacing: 0) {
            ledgerRow(symbol: "arrow.forward.circle", text: "Sets you log from now on", type: selection, emphasized: true)
                .celebrate(selection)
            if logged > 0 {
                LookDivider().padding(.leading, 52)
                ledgerRow(symbol: "clock.arrow.circlepath", text: "\(Format.count(logged, "set")) already logged",
                          type: original, emphasized: false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.panel)
    }

    private func ledgerRow(symbol: String, text: String, type: LoadType, emphasized: Bool) -> some View {
        let layout = isAX ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 10))
        return HStack(alignment: isAX ? .top : .center, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(emphasized ? look.textPrimary : look.textSecondary)
                .frame(width: 26)
            layout {
                Text(text)
                    .font(.system(.subheadline, design: look.id == .anatomy ? .rounded : .default,
                                  weight: emphasized ? .semibold : .regular))
                    .foregroundStyle(emphasized ? look.textPrimary : look.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !isAX { Spacer(minLength: 4) }
                ExercisesTag(type.badge, symbol: type.exercisesRankSymbol)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(text): \(type.badge)")
    }

    // MARK: Actions

    private func save() {
        guard changed else { return }
        store.setLoadType(selection, exerciseID: exerciseID)
        savedTick += 1
        router.dismissSheet()
    }

    private func prepare() {
        guard !prepared else { return }
        selection = original
        prepared = true
        if let variant = ExercisesVariant.consume(.e05, store: store, router: router),
           ExercisesVariant.has(variant, "changed") {
            selection = .assisted
        }
    }
}
