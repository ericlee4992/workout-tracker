import SwiftData
import SwiftUI

/// UI redesign ticket 11: a template, opened from its tile — the user:
/// "when users click template they should be able to view the list of
/// exercises in the template." Floodlight redesign: the name, the families it trains (target
/// sets per family), how often it ran, the exercises ("N sets · r, r, r reps", rest, the
/// equipment it starts on at this gym, a superset pair joined by a chain link), cardio
/// targets, and Delete Template… at the end. Start is the one filled command, pinned at the
/// thumb; Edit is in the bar.
struct TemplateDetailView: View {
    var template: WorkoutTemplate
    /// The Start screen's chosen gym — machines resolve to the last-used
    /// there when the template starts (ticket 15).
    var gym: Gym?
    var onWorkoutStarted: (Workout) -> Void

    @State private var request: WorkoutStartRequest?
    @State private var showingEditor = false
    /// Ticket 15: Delete lives here, confirmed — the tile's long-press menu
    /// deleted the wrong template on the phone and is gone.
    @State private var confirmingDelete = false
    /// View-owned: set BEFORE the model is deleted, so a re-evaluation after
    /// the save never renders a deleted model (`isDeleted` flips back to false
    /// once saved — codex-review-15). The screen goes blank and pops.
    @State private var deleted = false
    @State private var titleInBar = false
    @Query(filter: #Predicate<Workout> { $0.finishedAt != nil })
    private var finishedWorkouts: [Workout]
    @Query(
        filter: #Predicate<Workout> { $0.finishedAt == nil },
        sort: [SortDescriptor(\Workout.startedAt, order: .reverse)])
    private var activeWorkouts: [Workout]
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private var isGone: Bool { deleted || template.isDeleted }

    var body: some View {
        // A deleted template (while this screen is on the stack) renders empty rather than faulting.
        let items = isGone ? [] : WorkoutTemplateService.orderedItems(of: template)
        ScrollView {
            if !isGone {
                VStack(alignment: .leading, spacing: look.space.section) {
                    header(items)
                    if stats.timesRun > 0 { TemplateStatsPanel(stats: stats) }
                    if !items.isEmpty { exercises(items) }
                    if template.hasUnknownCardioTargets {
                        Text("Some cardio targets are unavailable in this version.")
                            .font(look.font.footnote).foregroundStyle(look.textSecondary)
                    }
                    if !template.plannedCardio.isEmpty { cardio }
                    // The destructive command last, never primary (ios-design).
                    DestructiveRowButton("Delete Template…") { confirmingDelete = true }
                        .accessibilityIdentifier("deleteTemplate")
                        .padding(.top, 12)
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 4)
                .padding(.bottom, 44)
            }
        }
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: Bool.self) { geo in
            geo.contentOffset.y + geo.contentInsets.top > 56
        } action: { _, past in
            withAnimation(.easeInOut(duration: 0.18)) { titleInBar = past }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { if !isGone { startBar(items) } }
        .lookScreenBackground()
        .navigationTitle(isGone ? "" : template.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(look.ground, for: .navigationBar)
        .toolbarBackgroundVisibility(titleInBar ? .visible : .hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(isGone ? "" : template.name)
                    .font(look.font.navTitle)
                    .foregroundStyle(look.textPrimary)
                    .lineLimit(1)
                    .opacity(titleInBar ? 1 : 0)
                    .accessibilityHidden(!titleInBar)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showingEditor = true }
                    .font(.system(.body, weight: .semibold))
                    .accessibilityIdentifier("editTemplate")
            }
        }
        .alert("Delete Template", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive, action: deleteTemplate)
            Button("Cancel", role: .cancel) {}
        } message: {
            // The consequence, in one line: the plan goes, the record stays (D23).
            Text("Workouts already logged from it are kept.")
        }
        .workoutStartFlow(request: $request, gym: gym, onWorkoutStarted: onWorkoutStarted)
        .sheet(isPresented: $showingEditor) {
            TemplateEditorSheet(template: template)
        }
        // No identifier on the whole screen: one here is inherited by the
        // capsule in the safe-area inset and hides `startTemplate`.
    }

    private var stats: TemplateStats {
        let id = template.id
        return TemplateStats.byTemplate(finishedWorkouts.filter { $0.sourceTemplateID == id })[id] ?? .none
    }

    // MARK: Header: name, summary, families

    private func header(_ items: [TemplateItem]) -> some View {
        let counts = familyCounts(items)
        let trained = counts.contains { $0.sets > 0 }
        return VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                if template.generatedForGymID != nil {
                    Label("Ask AI", systemImage: "sparkles")
                        .font(.system(.footnote, weight: .semibold))
                        .foregroundStyle(look.textSecondary)
                }
                Text(template.name)
                    .font(look.font.largeTitle)
                    .foregroundStyle(look.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if let summary = summary(items) {
                    Text(summary).font(.system(.subheadline)).foregroundStyle(look.textSecondary)
                }
                if let source = template.generatedForGymID, source != gym?.id {
                    Label("Created for another gym. Check equipment before starting.", systemImage: look.gymSymbol)
                        .font(look.font.footnote)
                        .foregroundStyle(look.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
                }
            }
            if trained {
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        // AX sizes: only the families this template trains, as rows (map · name · sets).
                        FamilyTallyGroup(counts: counts.filter { $0.sets > 0 }, mapSize: 50, appearDelay: 0.1, spacing: 10)
                    } else {
                        // Untrained families keep their unlit map but carry no "0 sets".
                        FamilyTallyGroup(counts: counts, mapSize: 50, appearDelay: 0.15, stagger: 0.06, hidesZeroCounts: true)
                    }
                }
                .accessibilityIdentifier("templateFamilies")
            }
        }
    }

    /// Target sets per family, all five head to toe (zero = not in the template). An exercise
    /// with no family (Core, Full Body) counts toward none.
    private func familyCounts(_ items: [TemplateItem]) -> [FamilyCount] {
        var counts: [MuscleFamily: Int] = [:]
        for item in items {
            if let family = MuscleFamily(muscleGroup: item.exercise?.muscleGroup) {
                counts[family, default: 0] += item.editableTargets.count
            }
        }
        return MuscleFamily.allCases.map { FamilyCount(family: $0, sets: counts[$0] ?? 0) }
    }

    /// "5 exercises · 18 sets".
    private func summary(_ items: [TemplateItem]) -> String? {
        let sets = items.reduce(0) { $0 + $1.editableTargets.count }
        var parts: [String] = []
        if !items.isEmpty { parts.append(HistoryRendering.pluralized(items.count, "exercise", "exercises")) }
        if sets > 0 { parts.append(HistoryRendering.pluralized(sets, "set", "sets")) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: Exercises

    private func exercises(_ items: [TemplateItem]) -> some View {
        let labels = Supersets.memberLabels(groupIDs: items.map(\.supersetGroupID))
        let rows = Array(zip(items, labels))
        return VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Exercises")
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.0.id) { index, pair in
                    if index > 0 {
                        // A superset member after its partner: the seam carries the chain link.
                        let linked = pair.1 != nil && pair.1 != "A" && rows[index - 1].1 != nil
                            && rows[index - 1].0.supersetGroupID == pair.0.supersetGroupID
                        LookDivider().padding(.leading, linked ? 18 : 0)
                            .overlay { if linked { TemplateLinkSeal() } }
                            .zIndex(1)
                    }
                    row(pair.0, letter: pair.1)
                }
            }
            .lookSurface(.panel)
        }
    }

    private func row(_ item: TemplateItem, letter: String?) -> some View {
        let stack = dynamicTypeSize.isAccessibilitySize
        let layout = stack ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
                           : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        return layout {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.exercise?.name ?? "Missing exercise")
                        .font(Font.system(.headline, weight: .heavy).width(.expanded))
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let letter { TemplateSupersetTag(letter: letter) }
                }
                // The user kept this caption (2026-09-11): "N sets · r, r, r reps".
                Text(item.editableTargets.summary)
                    .font(look.font.subhead)
                    .foregroundStyle(look.textSecondary)
                equipmentLine(item)
            }
            if !stack { Spacer(minLength: 8) }
            if let rest = item.plannedRestSeconds {
                HStack(spacing: 4) {
                    Image(systemName: "timer").font(.system(.footnote, weight: .semibold))
                    Text(Format.duration(seconds: rest))
                        .font(.system(.subheadline, weight: .semibold))
                        .monospacedDigit()
                }
                .foregroundStyle(look.textSecondary)
                .padding(.top, stack ? 0 : 2)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Rest \(Format.duration(seconds: rest))")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("templateExercise.\(item.exercise?.name ?? "")")
    }

    /// What the row starts on at this gym — the same resolution Start uses
    /// (`WorkoutTemplateService.resolvedMachine`), else the template's free-weight tag.
    @ViewBuilder private func equipmentLine(_ item: TemplateItem) -> some View {
        if let exercise = item.exercise,
           let machine = try? WorkoutTemplateService(context: modelContext).resolvedMachine(for: exercise, in: template, at: gym) {
            equipmentLabel(machine.label, symbol: LookIcon.machine)
        } else if let tag = item.preferredEquipmentTag {
            equipmentLabel(tag.label, symbol: tag == .machine ? LookIcon.machine : "dumbbell")
        } else if template.generatedForGymID != nil, let exercise = item.exercise,
                  !(gym?.activeMachines.contains { $0.supportedExerciseIDs.contains(exercise.id) } ?? false) {
            Label("No matching machine at this gym", systemImage: "exclamationmark.circle")
                .font(look.font.footnote)
                .foregroundStyle(look.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func equipmentLabel(_ text: String, symbol: String) -> some View {
        HStack(spacing: 6) {
            LookIcon(symbol, style: .footnote)
            Text(text)
        }
        .font(look.font.footnote)
        .foregroundStyle(look.textSecondary)
    }

    // MARK: Planned cardio

    private var cardio: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Cardio targets")
            LookList {
                ForEach(template.plannedCardio) { target in
                    LookRow(target.activity.name, symbol: target.activity.symbol, value: target.summary, showsChevron: false)
                }
            }
        }
    }

    // MARK: Start

    private func startBar(_ items: [TemplateItem]) -> some View {
        let what: String? = items.isEmpty
            ? template.plannedCardio.first?.activity.name
            : HistoryRendering.pluralized(items.count, "exercise", "exercises")
        let subtitle = [gym?.name, what].compactMap { $0 }.joined(separator: " · ")
        return Group {
            if let active = activeWorkouts.first, !active.isDeleted, active.sourceTemplateID == template.id {
                // This template is the workout that is running: Start would only ask to replace
                // it with itself, so the pinned command resumes it (as Home's Resume capsule does).
                let sets = WorkoutSession.orderedEntries(of: active).flatMap { $0.sets ?? [] }
                TemplateStartCapsule(title: "Resume workout",
                                     subtitle: sets.isEmpty ? nil : "\(sets.filter { $0.completedAt != nil }.count)/\(sets.count) sets",
                                     startedAt: active.startedAt) {
                    if let workout = try? WorkoutSession(context: modelContext).resumableWorkout() {
                        onWorkoutStarted(workout)
                    }
                }
                .accessibilityIdentifier("resumeTemplateWorkout")
            } else {
                TemplateStartCapsule(subtitle: subtitle.isEmpty ? nil : subtitle) {
                    request = WorkoutStartRequest(template: template)
                }
                .disabled(items.isEmpty && template.plannedCardio.isEmpty)
                .accessibilityIdentifier("startTemplate")
            }
        }
        .padding(.horizontal, look.space.margin)
        .padding(.top, 22)
        .padding(.bottom, 10)
        .background {
            // Rows scroll under the capsule and fade out beneath it (the AXL capture, ticket 11).
            LinearGradient(stops: [.init(color: look.ground.opacity(0), location: 0),
                                   .init(color: look.ground.opacity(0.92), location: 0.42),
                                   .init(color: look.ground, location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
        }
    }

    private func deleteTemplate() {
        guard !deleted, !template.isDeleted else { return }
        deleted = true
        do {
            try WorkoutTemplateService(context: modelContext).delete(template)
            dismiss()
        } catch {
            assertionFailure("Failed to delete template: \(error)")
        }
    }
}
