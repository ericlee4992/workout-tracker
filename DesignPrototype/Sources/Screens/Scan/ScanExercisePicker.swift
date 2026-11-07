import SwiftUI

// "Change exercises" (pushed inside the scan sheet): which exercises this machine serves.
// It opens on what fits this machine — a "Suggested" group: the AI's exercises (sparkles) and
// the machine exercises of the same body areas — then every exercise by body area, each header
// marked with its family colour. The limit is visible ("2/6") instead of silent; at the limit
// the other rows dim and a 7th tap shakes the counter with a warning haptic. The picked ones sit
// on top as removable chips. Every tap writes through to the scan result (Back is the commit).
// Capture variants: "exercises-query" (typed search), "exercises-none" (no results),
// "exercises-full" (6/6).

struct ScanExercisePicker: View {
    var onBack: () -> Void
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @ScanReduceMotion private var reduceMotion
    @State private var query = ""
    @State private var refusals = 0
    @State private var toggles = 0
    @State private var appliedVariant = false

    private static let limit = 6

    private var selected: [UUID] { store.scan.result?.exerciseIDs ?? [] }
    /// What the simulated AI proposed for this photo.
    private var proposed: [UUID] { ScanSimulator.result(kind: store.scan.demoKind).exerciseIDs }

    /// The AI's exercises, then the machine exercises of the same muscle groups.
    private var suggested: [Exercise] {
        let seeds = (proposed + selected).compactMap { store.exercise($0) }
        let groups = Set(seeds.compactMap(\.muscleGroup))
        var seen = Set<UUID>()
        let related = store.exercises
            .filter { e in e.muscleGroup.map(groups.contains) == true && (e.tags.contains(.machine) || e.tags.contains(.smith)) }
            .sorted { $0.name < $1.name }
        return (seeds + related).filter { seen.insert($0.id).inserted }
    }

    var body: some View {
        let searching = !query.trimmingCharacters(in: .whitespaces).isEmpty
        let suggestedIDs = searching ? Set<UUID>() : Set(suggested.map(\.id))
        let sections = store.exerciseSections(query: query)
            .map { (group: $0.group, exercises: $0.exercises.filter { !suggestedIDs.contains($0.id) }) }
            .filter { !$0.exercises.isEmpty }
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SearchFieldView(text: $query, prompt: "Search exercises")
                    if !selected.isEmpty {
                        ScanFlowLayout(spacing: 8) {
                            ForEach(selected, id: \.self) { id in
                                if let exercise = store.exercise(id) {
                                    Chip(exercise.name, symbol: "xmark", isSelected: true) { toggle(id) }
                                        .accessibilityLabel("Remove \(exercise.name)")
                                }
                            }
                        }
                    }
                    if !searching {
                        group(title: "Suggested", marker: AnyView(sparkleMarker), exercises: suggested, showsGroup: true)
                    }
                    ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                        group(title: section.group?.label ?? "Uncategorized",
                              marker: AnyView(familyMarker(section.group?.family)), exercises: section.exercises, showsGroup: false)
                    }
                    if searching && sections.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(.title, weight: .semibold))
                                .foregroundStyle(look.textTertiary)
                                .accessibilityHidden(true)
                            Text("No exercises match “\(query)”")
                                .font(look.font.headline)
                                .foregroundStyle(look.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 48)
                    }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .lookSheetGround()
        .sensoryFeedback(.warning, trigger: refusals)
        .sensoryFeedback(.selection, trigger: toggles)
        .onAppear(perform: applyVariant)
    }

    private func applyVariant() {
        guard !appliedVariant else { return }
        appliedVariant = true
        if router.scanVariant("query") { query = "curl" }
        if router.scanVariant("none") { query = "zercher" }
        if router.scanVariant("full") {
            let legs = ["Hack Squat", "Calf Raise", "Leg Press", "Leg Extension", "Seated Calf Raise", "Smith Machine Squat"]
            store.scanSetExercises(legs.map(SampleData.exerciseID))
        }
    }

    private var header: some View {
        ZStack {
            Text("Exercises")
                .font(look.font.navTitle)
                .foregroundStyle(look.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 96)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .accessibilityAddTraits(.isHeader)
            HStack {
                GlassIconButton("chevron.left", accessibilityLabel: "Back", action: onBack)
                Spacer()
                ScanLimitCounter(count: selected.count, limit: Self.limit, refusals: refusals)
            }
        }
        .padding(.horizontal, look.space.margin)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: Groups

    private func group(title: String, marker: AnyView, exercises: [Exercise], showsGroup: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                marker
                Text(title)
                    .font(.system(.footnote, weight: .bold))
                    .fontDesign(look.id == .anatomy ? .rounded : nil)
                    .foregroundStyle(look.textSecondary)
            }
            .padding(.leading, 4)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            LookList(separatorInset: 16) {
                ForEach(exercises) { exercise in row(exercise, showsGroup: showsGroup) }
            }
        }
    }

    private var sparkleMarker: some View {
        Image(systemName: "sparkles")
            .font(.system(.caption, weight: .bold))
            .foregroundStyle(look.id.isPaperClub ? look.actionText : look.selection)
            .accessibilityHidden(true)
    }

    /// The family's colour as a small swatch (C: its washed sticker tint with an ink edge).
    @ViewBuilder private func familyMarker(_ family: MuscleFamily?) -> some View {
        if let family {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(look.family(family))
                .frame(width: 12, height: 12)
                .overlay {
                    if look.id.isPaperClub {
                        RoundedRectangle(cornerRadius: 3, style: .continuous).strokeBorder(look.textPrimary, lineWidth: 1.2)
                    }
                }
                .accessibilityHidden(true)
        } else {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .strokeBorder(look.textTertiary, lineWidth: 1.2)
                .frame(width: 12, height: 12)
                .accessibilityHidden(true)
        }
    }

    private func row(_ exercise: Exercise, showsGroup: Bool) -> some View {
        let isOn = selected.contains(exercise.id)
        let full = selected.count >= Self.limit
        return Button { toggle(exercise.id) } label: {
            HStack(spacing: 12) {
                ScanCheck(selected: isOn)
                Text(exercise.name)
                    .font(.system(.body, weight: isOn ? .semibold : .regular))
                    .fontDesign(look.id == .anatomy ? .rounded : nil)
                    .foregroundStyle(look.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if proposed.contains(exercise.id) {
                    Image(systemName: "sparkles")
                        .font(.system(.footnote, weight: .semibold))
                        .foregroundStyle(look.textSecondary)
                        .accessibilityLabel("Proposed by AI")
                }
                Spacer(minLength: 8)
                if showsGroup, let group = exercise.muscleGroup {
                    Text(group.label)
                        .font(look.font.footnote)
                        .foregroundStyle(look.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(minHeight: 50)
            .contentShape(Rectangle())
            .opacity(full && !isOn ? 0.4 : 1)
        }
        .buttonStyle(.lookPressable)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func toggle(_ id: UUID) {
        var ids = selected
        if let i = ids.firstIndex(of: id) {
            ids.remove(at: i)
        } else {
            guard ids.count < Self.limit else { refusals += 1; return }
            ids.append(id)
        }
        toggles += 1
        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8)) { store.scanSetExercises(ids) }
    }
}

/// A multi-select mark: an open circle, filled with the look's selection and a check when on.
private struct ScanCheck: View {
    var selected: Bool
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 24

    var body: some View {
        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: side, weight: selected ? .semibold : .regular))
            .symbolRenderingMode(.palette)
            .foregroundStyle(selected ? (look.id.isPaperClub ? look.onAction : look.onDone) : look.textTertiary,
                             look.id.isPaperClub ? look.action : look.selection)
            .contentTransition(.symbolEffect(.replace))
            .accessibilityHidden(true)
    }
}

/// "2/6": the count big, the limit small. At the limit the count takes the selection colour.
/// A refused 7th pick shakes it (Reduce Motion: it stays put; the haptic still fires).
private struct ScanLimitCounter: View {
    var count: Int
    var limit: Int
    var refusals: Int
    @Environment(\.look) private var look
    @ScanReduceMotion private var reduceMotion

    var body: some View {
        let still = reduceMotion
        let full = count >= limit
        return HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text("\(count)").font(look.font.smallNumber)
                .foregroundStyle(full ? (look.id.isPaperClub ? look.actionText : look.selection) : look.textPrimary)
                .contentTransition(.numericText(value: Double(count)))
            Text("/\(limit)").font(look.font.subhead.weight(.semibold)).foregroundStyle(look.textSecondary)
        }
        .monospacedDigit()
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .glassEffect(.regular, in: Capsule())
        .keyframeAnimator(initialValue: CGFloat(0), trigger: refusals) { view, x in
            view.offset(x: still ? 0 : x)
        } keyframes: { _ in
            KeyframeTrack {
                LinearKeyframe(-8, duration: 0.05)
                LinearKeyframe(8, duration: 0.08)
                LinearKeyframe(-6, duration: 0.08)
                LinearKeyframe(4, duration: 0.07)
                LinearKeyframe(0, duration: 0.06)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) of \(limit) exercises")
    }
}
