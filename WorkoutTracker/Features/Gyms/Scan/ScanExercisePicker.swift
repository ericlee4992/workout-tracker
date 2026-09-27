import SwiftUI

// Floodlight redesign ticket 07 — "Change exercises" (pushed): which exercises a model-less
// machine serves. It opens on what fits this machine — "Suggested": the AI's picks (sparkles)
// and the machine exercises of the same muscle groups — then every exercise by muscle group,
// each header marked with its family colour. The limit is visible ("2/6") instead of silent
// (D56 allows six); at the limit the other rows dim and another tap shakes the counter with a
// warning haptic. The picked ones sit on top as removable chips. Every tap writes through to
// the binding (Back is the commit). The machine form's "Choose exercises" uses it too.

struct ScanExercisePicker: View {
    var exercises: [Exercise]
    /// What the AI proposed (marked with sparkles in Suggested); empty from the form.
    var proposed: [UUID]
    @Binding var selected: [UUID]
    var limit = 6
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var query = ""
    @State private var refusals = 0
    @State private var toggles = 0
    @State private var shake: CGFloat = 0
    /// Suggested is computed once per visit, so a row does not jump groups as it is ticked.
    @State private var suggestedIDs: [UUID]?

    private var searching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        let suggested = searching ? [] : (suggestedIDs ?? []).compactMap(exercise(_:))
        let suggestedSet = Set(suggested.map(\.id))
        let sections = groupedSections(excluding: suggestedSet)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SearchFieldView(text: $query, prompt: "Search exercises")
                if !selected.isEmpty {
                    WrapLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(selected, id: \.self) { id in
                            if let exercise = exercise(id) {
                                Chip(exercise.name, symbol: "xmark", isSelected: true) { toggle(id) }
                                    .accessibilityLabel("Remove \(exercise.name)")
                            }
                        }
                    }
                }
                if !suggested.isEmpty {
                    section(title: "Suggested", family: nil, rows: suggested, sparkles: Set(proposed))
                }
                ForEach(sections, id: \.title) { group in
                    section(title: group.title, family: MuscleFamily(muscleGroup: group.title), rows: group.rows, sparkles: [])
                }
                if suggested.isEmpty && sections.isEmpty {
                    Text("No exercises match")
                        .font(look.font.subhead)
                        .foregroundStyle(look.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .lookSheetGround()
        .navigationTitle("Exercises")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { counter }
        }
        .onAppear {
            if suggestedIDs == nil {
                suggestedIDs = ScanMachine.suggestedExercises(
                    proposed: proposed, selected: selected,
                    among: exercises.map {
                        .init(id: $0.id, name: $0.name, muscleGroup: $0.muscleGroup,
                              isMachine: $0.equipmentTypeTags.contains(.machine) || $0.equipmentTypeTags.contains(.smith))
                    })
            }
        }
        .sensoryFeedback(.warning, trigger: refusals)
        .sensoryFeedback(.selection, trigger: toggles)
    }

    private var counter: some View {
        Text("\(selected.count)/\(limit)")
            .font(look.font.fieldNumber)
            .monospacedDigit()
            .foregroundStyle(selected.count >= limit ? look.textPrimary : look.textSecondary)
            .padding(.horizontal, 10)
            .frame(minHeight: 30)
            .background(look.surfaceRaised, in: Capsule())
            .offset(x: shake)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(selected.count) of \(limit) exercises")
            .accessibilityIdentifier("scanExerciseCount")
    }

    private func exercise(_ id: UUID) -> Exercise? { exercises.first { $0.id == id } }

    private func groupedSections(excluding: Set<UUID>) -> [(title: String, rows: [Exercise])] {
        let matching = exercises.filter {
            !excluding.contains($0.id) && (!searching || $0.name.localizedCaseInsensitiveContains(query))
        }
        let grouped = Dictionary(grouping: matching) { $0.muscleGroup ?? "Other" }
        return grouped.keys.sorted { a, b in
            if (a == "Other") != (b == "Other") { return b == "Other" }
            return a < b
        }
        .map { key in (key, grouped[key]!.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) }
    }

    private func section(title: String, family: MuscleFamily?, rows: [Exercise], sparkles: Set<UUID>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let family {
                    Circle().fill(look.family(family)).frame(width: 9, height: 9).accessibilityHidden(true)
                } else {
                    Image(systemName: "sparkles").font(.system(.footnote, weight: .bold))
                        .foregroundStyle(look.textSecondary).accessibilityHidden(true)
                }
                Text(title)
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(look.textSecondary)
                    .accessibilityAddTraits(.isHeader)
            }
            .padding(.leading, 4)
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, exercise in
                    if index > 0 { LookDivider().padding(.leading, 16) }
                    row(exercise, sparkles: sparkles.contains(exercise.id))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: look.radius.panel, style: .continuous))
            .lookSurface(.panel)
        }
    }

    private func row(_ exercise: Exercise, sparkles: Bool) -> some View {
        let isOn = selected.contains(exercise.id)
        let atLimit = !isOn && selected.count >= limit
        return Button { toggle(exercise.id) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(exercise.name)
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(look.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        if sparkles {
                            Image(systemName: "sparkles")
                                .font(.system(.caption, weight: .bold))
                                .foregroundStyle(look.textSecondary)
                                .accessibilityLabel("Suggested by AI")
                        }
                    }
                    if let group = exercise.muscleGroup, searching {
                        Text(group).font(look.font.footnote).foregroundStyle(look.textSecondary)
                    }
                }
                Spacer(minLength: 8)
                ScanRadio(selected: isOn)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
            .opacity(atLimit ? 0.45 : 1)
        }
        .buttonStyle(.lookPressable)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier("scanExercise.\(exercise.name)")
    }

    private func toggle(_ id: UUID) {
        if let index = selected.firstIndex(of: id) {
            selected.remove(at: index)
            toggles += 1
        } else if selected.count < limit {
            selected.append(id)
            toggles += 1
        } else {
            refusals += 1
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.12, dampingFraction: 0.2)) { shake = 8 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { shake = 0 }
            }
        }
    }
}
