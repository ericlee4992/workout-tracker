import SwiftUI

// PROTOTYPE — T01: a template, opened from its Home tile. Name, the families it trains (sets
// per family), how often it ran, the exercises ("N sets · r, r, r reps", rest, the equipment it
// resolves to at this gym, a superset pair joined by the editor's chain link), cardio targets,
// and Delete Template… at the end. Start is the one filled command, pinned at the thumb. Edit
// is in the bar.
//
// Capture variants (`-screen T01 -variant …`): live (the shared scenario's Push Day is running,
// minimised: 18:42, 7/18), delete (the confirmation), fresh (a template that has never run),
// ai (an Ask AI template made for another gym), p2 / end (scrolled).

struct TemplateDetailScreen: View {
    let templateID: UUID
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false
    @State private var titleInBar = false
    @State private var deleting = false
    /// A capture variant's sample template shown instead of `templateID` (fresh, ai).
    @State private var variantID: UUID?

    private var shownID: UUID { variantID ?? templateID }

    var body: some View {
        Group {
            if let template = store.template(shownID), !deleting {
                // Keyed by the template: a variant's template gets fresh maps (their lit state is set on appear).
                content(template).id(shownID)
            } else {
                Color.clear
            }
        }
        .lookScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: applyVariant)
    }

    private func applyVariant() {
        guard store.currentScreen == .t01, let variant = router.variant else { return }
        switch variant {
        case "live":
            // The shared scenario (W02): Push Day running 18:42, 7/18 sets, minimised, so the
            // pinned command is Resume. Same sample data; the pushed screen stays.
            if store.session == nil { store.reset(to: .w02) }
        case "delete":
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { confirmDelete = true }
        case "fresh", "ai":
            let template = variant == "ai" ? TemplatesSamples.aiTemplate : TemplatesSamples.freshTemplate
            store.saveTemplate(template)
            variantID = template.id
        default:
            break
        }
    }

    // MARK: Screen

    private func content(_ t: Template) -> some View {
        let stats = store.templateStats(t.id)
        return ScrollView {
            VStack(alignment: .leading, spacing: look.space.section) {
                header(t)
                if stats.timesRun > 0 { TemplatesStatsPanel(stats: stats, now: store.now) }
                if !t.items.isEmpty { exercises(t) }
                if !t.cardio.isEmpty { cardio(t) }
                // PROPOSAL: Delete Template… lives in the "…" menu, not beside Start.
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 4)
            .padding(.bottom, 44)
        }
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: Bool.self) { geo in
            geo.contentOffset.y + geo.contentInsets.top > 56
        } action: { _, past in
            withAnimation(.easeInOut(duration: 0.18)) { titleInBar = past }
        }
        .modifier(TemplatesVariantScroll(variant: router.variant, active: store.currentScreen == .t01))
        .safeAreaInset(edge: .bottom, spacing: 0) { startBar(t) }
        // Scrolled: the bar takes the solid ground, so nothing shows through under the status
        // bar, the title and the bar buttons.
        .toolbarBackground(look.ground, for: .navigationBar)
        .toolbarBackgroundVisibility(titleInBar ? .visible : .hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(t.name)
                    .font(look.font.navTitle)
                    .foregroundStyle(look.textPrimary)
                    .lineLimit(1)
                    .opacity(titleInBar ? 1 : 0)
                    .accessibilityHidden(!titleInBar)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { router.present(.templateEditor(templateID: t.id)) }
                    .font(.system(.body, weight: .semibold))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Delete Template…", systemImage: "trash", role: .destructive) { confirmDelete = true }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(look.textPrimary)
                }
                .accessibilityLabel("More")
            }
        }
        .proposalScreen("template")
        .alert("Delete Template", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Workouts already logged from it are kept.")
        }
    }

    // MARK: Header: name, summary, families

    private func header(_ t: Template) -> some View {
        let counts = store.templatesFamilyCounts(items: t.items)
        return VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                if t.isAI {
                    Label("Ask AI", systemImage: "sparkles")
                        .font(.system(.footnote, weight: .semibold))
                        .foregroundStyle(look.textSecondary)
                }
                Text(t.name)
                    .font(look.font.largeTitle)
                    .foregroundStyle(look.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if !t.templatesSummary.isEmpty {
                    Text(t.templatesSummary)
                        .font(.system(.subheadline, weight: look.id == .floodlight ? .regular : .semibold))
                        .foregroundStyle(look.textSecondary)
                }
                if let made = t.generatedForGymID, let current = store.selectedGymID, made != current {
                    // Existing copy (kept); shown only when a gym is chosen and it is not the one the AI planned for.
                    Label("Created for another gym. Check equipment before starting.", systemImage: look.gymSymbol)
                        .font(look.font.footnote)
                        .foregroundStyle(look.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
                }
            }
            if typeSize.isAccessibilitySize, counts.contains(where: { $0.sets > 0 }) {
                // AX sizes: only the families this template trains, as rows (map · name · sets).
                FamilyTallyGroup(counts: counts.filter { $0.sets > 0 }, mapSize: 50, appearDelay: 0.1, spacing: 10)
            } else if counts.contains(where: { $0.sets > 0 }) {
                switch look.id {
                case .floodlight:
                    // Untrained families keep their unlit map but carry no "0 sets".
                    FamilyTallyGroup(counts: counts, mapSize: 50, appearDelay: 0.15, stagger: 0.06, hidesZeroCounts: true)
                case .anatomy:
                    FamilyTallyGroup(counts: counts, mapSize: 58, appearDelay: 0.15, stagger: 0.09, hidesZeroCounts: true)
                case .paper, .carbon:
                    FamilyTallyGroup(counts: counts.filter { $0.sets > 0 }, mapSize: 54, appearDelay: 0.1, spacing: 10)
                }
            }
        }
    }

    // MARK: Exercises

    /// Items grouped into blocks: a single exercise, or a superset run (joined by chain links).
    private struct Block: Identifiable {
        var items: [TemplateItem]
        var isSuperset: Bool
        var id: UUID { items[0].id }
    }

    private func blocks(_ t: Template) -> [Block] {
        let labels = store.supersetLabels(ofTemplate: t.id)
        var result: [Block] = []
        for item in t.items {
            if labels[item.id] != nil, labels[item.id] != "A", let last = result.last, last.isSuperset,
               last.items.last?.supersetGroup == item.supersetGroup {
                result[result.count - 1].items.append(item)
            } else {
                result.append(Block(items: [item], isSuperset: labels[item.id] != nil))
            }
        }
        return result
    }

    private func exercises(_ t: Template) -> some View {
        let labels = store.supersetLabels(ofTemplate: t.id)
        let groups = blocks(t)
        return VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Exercises")
            VStack(spacing: 0) {
                ForEach(Array(groups.enumerated()), id: \.element.id) { index, block in
                    if index > 0 { LookDivider() }
                    VStack(spacing: 0) {
                        ForEach(Array(block.items.enumerated()), id: \.element.id) { i, item in
                            if i > 0 {
                                // The seam between superset members carries the editor's filled link.
                                LookDivider().padding(.leading, 18)
                                    .overlay { TemplatesLinkSeal() }
                                    .zIndex(1)
                            }
                            row(item, letter: labels[item.id])
                        }
                    }
                }
            }
            .lookSurface(.panel)
        }
    }

    private var rowTitleFont: Font {
        switch look.id {
        case .floodlight: Font.system(.headline, weight: .heavy).width(.expanded)
        case .anatomy: .system(.headline, design: .rounded, weight: .bold)
        case .paper, .carbon: .system(.headline, design: .serif, weight: .heavy)
        }
    }

    private func row(_ item: TemplateItem, letter: String?) -> some View {
        // Tapping a row opens the exercise (its records and progress): the history a row can't hold.
        Button { router.push(.exerciseDetail(exerciseID: item.exerciseID)) } label: {
            HStack(alignment: .center, spacing: 10) {
                rowContent(item, letter: letter)
                Image(systemName: "chevron.right")
                    .font(.system(.footnote, weight: .bold))
                    .foregroundStyle(look.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.leading, 18)
            .padding(.trailing, 14)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(TemplatesRowPressStyle())
        .accessibilityElement(children: .combine)
    }

    private func rowContent(_ item: TemplateItem, letter: String?) -> some View {
        let name = store.exercise(item.exerciseID)?.name ?? "Missing exercise"
        let equipment = store.templatesEquipment(for: item, gymID: store.selectedGymID)
        let stack = typeSize.isAccessibilitySize
        let layout = stack ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
                           : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        return layout {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(name)
                        .font(rowTitleFont)
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let letter { TemplatesSupersetTag(letter: letter) }
                }
                Text(Format.targets(item.targetReps))
                    .font(look.font.subhead)
                    .foregroundStyle(look.textSecondary)
                // PROPOSAL: no machine line that only repeats the exercise's name.
                if let equipment, equipment.label != name {
                    HStack(spacing: 6) {
                        LookIcon(equipment.symbol, style: .footnote)
                        Text(equipment.label)
                    }
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
                } else if unmatched(item) {
                    Label("No matching machine at this gym", systemImage: "exclamationmark.circle")
                        .font(look.font.footnote)
                        .foregroundStyle(look.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if !stack { Spacer(minLength: 8) }
            if let rest = item.restSeconds {
                HStack(spacing: 4) {
                    Image(systemName: "timer").font(.system(.footnote, weight: .semibold))
                    Text(Format.rest(rest))
                        .font(.system(.subheadline, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
                        .monospacedDigit()
                }
                .foregroundStyle(look.textSecondary)
                .padding(.top, stack ? 0 : 2)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Rest \(Format.rest(rest))")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// An Ask AI row whose exercise nothing at the chosen gym serves (existing rule; needs a gym).
    private func unmatched(_ item: TemplateItem) -> Bool {
        guard store.template(shownID)?.isAI == true, item.equipmentTag == nil, let gym = store.selectedGymID else { return false }
        return store.machines(for: item.exerciseID, gymID: gym).isEmpty
    }

    // MARK: Planned cardio

    private func cardio(_ t: Template) -> some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Cardio targets")
            LookList {
                ForEach(t.cardio) { plan in
                    LookRow(plan.activity.name, symbol: plan.activity.symbol, value: plan.templatesSummary, showsChevron: false)
                }
            }
        }
    }

    // MARK: Start

    private func startBar(_ t: Template) -> some View {
        let gym = store.selectedGym?.name
        let what: String? = t.items.isEmpty ? t.cardio.first?.activity.name : Format.count(t.items.count, "exercise")
        let subtitle = [gym, what].compactMap { $0 }.joined(separator: " · ")
        return Group {
            if let s = store.session, s.templateID == t.id {
                // This template is the workout that is running: Start would only ask to replace
                // it with itself, so the pinned command resumes it (as Home's Resume capsule does).
                TemplatesStartCapsule(title: "Resume workout",
                                      subtitle: s.totalSetCount > 0 ? "\(s.completedSetCount)/\(s.totalSetCount) sets" : nil,
                                      elapsed: store.sessionElapsed) { store.resume() }
            } else {
                TemplatesStartCapsule(subtitle: subtitle.isEmpty ? nil : subtitle) { start(t) }
                    .disabled(t.items.isEmpty && t.cardio.isEmpty)
            }
        }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 22)
            .padding(.bottom, 10)
            .background {
                LinearGradient(stops: [.init(color: look.ground.opacity(0), location: 0),
                                       .init(color: look.ground.opacity(0.92), location: 0.42),
                                       .init(color: look.ground, location: 1)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea(edges: .bottom)
                    .allowsHitTesting(false)
            }
    }

    private func start(_ t: Template) {
        switch store.startLifting(templateID: t.id) {
        case .started:
            // The live cover rises; pop this screen underneath so minimising lands on Home.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { dismiss() }
        case .needsConfirmation:
            break // templateDriftPresenter shows "A workout is already in progress".
        }
    }

    private func delete() {
        deleting = true
        dismiss()
        let id = shownID
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { store.deleteTemplate(id) }
    }
}
