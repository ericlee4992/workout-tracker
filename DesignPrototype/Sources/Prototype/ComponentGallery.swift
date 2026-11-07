import SwiftUI

// A paged gallery of every Look component with the shared scenario's values, so each look
// can be captured and compared with the direction renders. `-look <id>` and
// `-galleryPage <n>` pick the look and page at launch.

// MARK: - Sample values (the shared scenario)

struct GallerySample {
    var week: WeekSummary
    var finish: FinishSummary
    var familySets: [FamilyCount]
    var hrSlots: [HRSlot]
    var zoneSeconds: [Int]
    var maxHeartRate: Int
    var progress: [ProgressChartPoint]
    var templates: [TemplateSample]

    struct TemplateSample: Identifiable {
        var id: String { name }
        var name: String
        var families: [MuscleFamily]
        var exercises: [String]
        var lastDone: Date?
    }

    static let shared: GallerySample = {
        let world = SampleData.world()
        let exercises = Dictionary(uniqueKeysWithValues: world.exercises.map { ($0.id, $0) })
        let week = Derived.weekSummary(history: world.workouts, exercises: exercises, now: SampleData.today)
        let push = SampleData.todayPushDay().build(SampleData.index(world))
        let finish = Derived.finishSummary(for: push, history: world.workouts, exercises: exercises,
                                           unit: .lb, maxHeartRate: 185)
        var counts: [MuscleFamily: Int] = [:]
        var order: [MuscleFamily] = []
        for entry in push.entries {
            guard let family = exercises[entry.exerciseID]?.family else { continue }
            if counts[family] == nil { order.append(family) }
            counts[family, default: 0] += entry.countedSets.count
        }
        let slots = push.heartRate?.series.map { Derived.hrSlots(series: $0, durationSeconds: push.durationSeconds, maxSlots: 52) } ?? []
        let values: [Double] = [95, 100, 105, 105, 110, 110, 115, 112.5, 120]
        let days = [28, 25, 21, 18, 14, 11, 7, 4, 0]
        var best = 0.0
        let progress = zip(values, days).map { value, ago -> ProgressChartPoint in
            let isRecord = value > best && best > 0
            best = max(best, value)
            return ProgressChartPoint(date: SampleData.today.addingTimeInterval(Double(-ago) * 86_400), value: value, isRecord: isRecord)
        }
        let templates = world.templates.filter { !$0.isAI }.map { template in
            GallerySample.TemplateSample(
                name: template.name,
                families: Derived.families(of: template, exercises: exercises),
                exercises: template.items.compactMap { exercises[$0.exerciseID]?.name },
                lastDone: Derived.templateStats(templateID: template.id, history: world.workouts).lastRun)
        }
        return GallerySample(week: week, finish: finish, familySets: order.map { FamilyCount(family: $0, sets: counts[$0] ?? 0) },
                             hrSlots: slots, zoneSeconds: push.heartRate?.zoneSeconds ?? [],
                             maxHeartRate: 185, progress: progress, templates: templates)
    }()
}

// MARK: - Gallery

struct ComponentGallery: View {
    @Bindable var model: LookModel
    @State var page: Int
    @Environment(\.colorScheme) private var systemScheme

    static let pages = ["Tokens", "Home", "Maps & tiles", "Live", "Set states", "Finish", "Finish data", "Lists & controls"]

    /// `-axl YES`: the gallery content at AX1 (the chrome stays at its own size).
    private let axl = UserDefaults.standard.bool(forKey: "axl")
    /// Finish pages sit on the sheet ground (the finish is a sheet).
    private var isSheetPage: Bool { page == 5 || page == 6 }

    var body: some View {
        let look = model.look(system: systemScheme)
        VStack(spacing: 0) {
            GalleryChrome(model: model, page: $page)
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.section) {
                    pageContent
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .modifier(SheetPage(active: isSheetPage))
            .modifier(AXOverride(active: axl))
            .id("\(model.id.rawValue)-\(page)")
        }
        .lookScreenBackground()
        .lookLayer(model)
        .animation(.easeInOut(duration: 0.25), value: model.id)
    }

    @ViewBuilder private var pageContent: some View {
        switch page {
        case 0: TokensPage()
        case 1: HomePage()
        case 2: MapsPage()
        case 3: LivePage()
        case 4: SetStatesPage()
        case 5: FinishPage()
        case 6: FinishDataPage()
        default: ListsPage()
        }
    }
}

private struct SheetPage: ViewModifier {
    var active: Bool
    func body(content: Content) -> some View {
        if active { content.lookSheetGround() } else { content }
    }
}

private struct AXOverride: ViewModifier {
    var active: Bool
    func body(content: Content) -> some View {
        if active { content.dynamicTypeSize(.accessibility1) } else { content }
    }
}

/// Prototype chrome: visually distinct from every look (system material, SF Mono).
private struct GalleryChrome: View {
    @Bindable var model: LookModel
    @Binding var page: Int

    var body: some View {
        HStack(spacing: 8) {
            Button { model.id = model.id.previous } label: { Image(systemName: "chevron.left") }
            Text(model.id.displayName).frame(minWidth: 110)
            Button { model.id = model.id.next } label: { Image(systemName: "chevron.right") }
            Spacer()
            Button { page = max(0, page - 1) } label: { Image(systemName: "chevron.up") }
            Text("\(page + 1)/\(ComponentGallery.pages.count) \(ComponentGallery.pages[min(page, ComponentGallery.pages.count - 1)])")
                .lineLimit(1)
            Button { page = min(ComponentGallery.pages.count - 1, page + 1) } label: { Image(systemName: "chevron.down") }
        }
        .font(.system(.caption, design: .monospaced, weight: .medium))
        .foregroundStyle(.primary)
        .padding(.horizontal, 14)
        .frame(height: 36)
        .background(.regularMaterial, in: Capsule())
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .environment(\.colorScheme, .dark)
        .dynamicTypeSize(...DynamicTypeSize.large)
    }
}

private struct GalleryLabel: View {
    var text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(.caption2, design: .monospaced, weight: .medium))
            .foregroundStyle(.secondary)
            .dynamicTypeSize(...DynamicTypeSize.large)
    }
}

// MARK: - Pages

private struct TokensPage: View {
    @Environment(\.look) private var look

    var body: some View {
        LookNavTitle("Workout", subtitle: "Thursday, September 24")
        VStack(alignment: .leading, spacing: 10) {
            swatchRow([("ground", look.ground), ("surface", look.surface), ("raised", look.surfaceRaised),
                       ("field", look.field), ("hairline", look.hairline)])
            swatchRow([("text", look.textPrimary), ("text2", look.textSecondary), ("text3", look.textTertiary),
                       ("action", look.action), ("actionTx", look.actionText)])
            swatchRow([("done", look.done), ("new best", look.positive), ("heart", look.heartRate),
                       ("destroy", look.destructive), ("slab", look.slab)])
            swatchRow([("warmup", look.warmup), ("drop", look.drop), ("failure", look.failure),
                       ("ring", look.ringTrack), ("last", look.comparisonLast)])
            swatchRow(MuscleFamily.allCases.map { ($0.label, look.family($0)) })
            swatchRow(MuscleFamily.allCases.map { ($0.label + " tint", look.familyTint($0)) })
            swatchRow(HeartRateZone.allCases.map { ($0.rawValue == 0 ? "WU" : "Z\($0.rawValue)", look.zone($0)) })
        }
        VStack(alignment: .leading, spacing: 6) {
            Text("Workout saved").font(look.font.title)
            Text("Templates").font(look.font.sectionTitle)
            Text("Seated Chest Press").font(look.font.cardTitle)
            Text("Push Day").font(look.font.tileTitle)
            Text("Iron Temple · headline").font(look.font.headline)
            Text("Body — Life Fitness Insignia Series").font(look.font.body)
            Text("Subhead — 5 exercises · 22 sets").font(look.font.subhead)
            Text("Footnote — Active calories").font(look.font.footnote)
            Text("Caption — Sep 23").font(look.font.caption)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("52:10").font(look.font.bigNumber).fixedSize()
                Text("18:42").font(look.font.timer)
                Text("128").font(look.font.statNumber)
                Text("14").font(look.font.smallNumber)
                Text("110").font(look.font.fieldNumber)
            }
            HStack(spacing: 16) {
                Text("SET · PREVIOUS · WEIGHT").font(look.font.columnHeader).tracking(look.columnTracking)
                Text("Start Lifting").font(look.font.button)
            }
        }
        .foregroundStyle(look.textPrimary)
    }

    private func swatchRow(_ items: [(String, Color)]) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 6).fill(item.1).frame(height: 30)
                        .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(look.textTertiary.opacity(0.35), lineWidth: 0.5) }
                    Text(item.0).font(.system(size: 9, design: .monospaced)).foregroundStyle(look.textSecondary)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct HomePage: View {
    @Environment(\.look) private var look
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Spacer(); GlassIconButton("gearshape", accessibilityLabel: "Settings") }
            LookNavTitle("Workout", subtitle: look.id.isPaperClub ? "Thursday, September 24" : "Thursday, Sep 24")
        }
        VStack(spacing: 14) {
            GymPickerButton(name: "Iron Temple", city: "Seoul", unit: .lb)
            StartPair()
        }
        WeekWidget(summary: GallerySample.shared.week)
        LookTabBar(selection: .constant(.workout)).padding(.horizontal, -look.space.margin)
    }
}

private struct MapsPage: View {
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GalleryLabel("MuscleMap lit / unlit · FamilyStrip")
            HStack(spacing: 10) {
                ForEach(MuscleFamily.allCases) { MuscleMap(family: $0, lit: $0 != .chest, size: 56) }
            }
            FamilyStrip(families: [.chest, .back, .shoulders, .arms, .legs], size: 30)
        }
        VStack(alignment: .leading, spacing: 12) {
            GalleryLabel("FamilyTallyGroup (finish working sets)")
            // A and B show all five (B hides zero counts); C shows only the trained groups.
            FamilyTallyGroup(counts: look.id.isPaperClub ? GallerySample.shared.familySets : MuscleFamily.allCases.map { family in
                FamilyCount(family: family, sets: GallerySample.shared.familySets.first { $0.family == family }?.sets ?? 0)
            }, hidesZeroCounts: look.id == .anatomy)
        }
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Templates", level: .page)
            let t = ["Leg Day", "Whole Body"].compactMap { name in GallerySample.shared.templates.first { $0.name == name } }
            if typeSize.isAccessibilitySize {
                // Every SPEC: templates become one column at AX sizes; the make tiles stack.
                VStack(spacing: look.space.grid) {
                    ForEach(t) { tile in
                        TemplateTile(name: tile.name, families: tile.families, exercises: tile.exercises,
                                     lastDone: tile.lastDone, now: SampleData.today)
                    }
                    MakeTile(title: "New Template…", symbol: "plus")
                    MakeTile(title: "Ask AI for Templates", symbol: "sparkles")
                }
            } else {
                Grid(horizontalSpacing: look.space.grid, verticalSpacing: look.space.grid) {
                    GridRow {
                        ForEach(t) { tile in
                            TemplateTile(name: tile.name, families: tile.families, exercises: tile.exercises,
                                         lastDone: tile.lastDone, now: SampleData.today)
                        }
                    }
                    GridRow {
                        MakeTile(title: "New Template…", symbol: "plus")
                        MakeTile(title: "Ask AI for Templates", symbol: "sparkles")
                    }
                }
            }
        }
    }
}

private struct LivePage: View {
    @State private var set3Done = false
    @State private var remaining = 84
    @Environment(\.look) private var look

    var body: some View {
        LiveTopBar(title: "Push Day")
        VStack(spacing: 12) {
            LiveTopBarTitleRow(title: "Push Day")
            LiveHeaderLine(gym: "Iron Temple", elapsed: 18 * 60 + 42, done: set3Done ? 8 : 7, total: 18)
            VitalsStrip(hr: 128, zone: .two, activeCal: 96, volume: set3Done ? 5_000 : 4_120)
            ExerciseCardSample(set3Done: $set3Done)
        }
        .padding(.top, -12)
        RestBar(remaining: remaining, total: 120,
                next: set3Done ? look.nextExerciseLabel("Incline Chest Press")
                    : look.nextSetLabel(number: 3, value: SetValue(weight: 110, unit: .lb, reps: 8), rowUnit: .lb),
                onAdd15: { remaining += 15 }, onSkip: { remaining = 0 })
            .onAppear {
                // `-galleryComplete YES`: complete set 3 after a beat to show the post-completion state.
                guard UserDefaults.standard.bool(forKey: "galleryComplete"), !set3Done else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    set3Done = true
                    remaining = 120
                }
            }
    }
}

/// The live cover's top bar, composed from glass chrome (the real one belongs to Live):
/// minimise (+ Cancel in A and B) · title · Finish. At AX sizes the chrome is capped; A and C
/// move the title into the list (LiveTopBarTitleRow), B keeps it and truncates it first.
private struct LiveTopBar: View {
    var title: String
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    private var titleInBar: Bool { !typeSize.isAccessibilitySize || look.id == .anatomy }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                GlassIconButton("chevron.down", accessibilityLabel: "Minimize")
                if !look.id.isPaperClub {
                    GlassCapsuleButton("Cancel", role: look.id == .floodlight ? .destructive : .normal)
                }
            }
            .layoutPriority(1)
            Spacer(minLength: 4)
            if titleInBar {
                HStack(spacing: 6) {
                    Text(title).font(look.font.navTitle).lineLimit(1)
                    Image(systemName: "pencil").font(.caption).foregroundStyle(look.textSecondary)
                }
                .foregroundStyle(look.textPrimary)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                Spacer(minLength: 4)
            }
            GlassCapsuleButton("Finish").layoutPriority(1)
        }
    }
}

/// A and C at AX sizes: the workout name leaves the bar and becomes the first line of content.
private struct LiveTopBarTitleRow: View {
    var title: String
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize && look.id != .anatomy {
            HStack(spacing: 8) {
                Text(title).font(look.font.title2).foregroundStyle(look.textPrimary)
                Image(systemName: "pencil").font(.body).foregroundStyle(look.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
        }
    }
}

/// An exercise card composed from the foundation pieces (the real one belongs to Live).
private struct ExerciseCardSample: View {
    @Binding var set3Done: Bool
    @Environment(\.look) private var look

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ExerciseCardHeader("Seated Chest Press",
                               subtitle: look.id == .anatomy ? "Target: 3 sets · 10, 8, 8 reps" : nil)
            EquipmentRow(title: "Chest Press 2", subtitle: "Life Fitness Insignia Series Chest Press")
            SetColumnHeader().padding(.top, 4)
            VStack(spacing: 4) {
                SetRowView(kind: .warmup, number: 0, last: v(45, 12), weight: 45, unit: .lb, reps: 12, state: .completed)
                SetRowView(kind: .working, number: 1, last: v(100, 10), weight: 100, unit: .lb, reps: 10, state: .completed)
                SetRowView(kind: .working, number: 2, last: v(105, 8), weight: 110, unit: .lb, reps: 8, state: .completed, badge: .newBest)
                SetRowView(kind: .working, number: 3, last: v(105, 8), weight: 110, unit: .lb, reps: 8,
                           state: set3Done ? .completed : .prefilled, isNextUp: !set3Done, isResting: true,
                           onCheck: { set3Done.toggle() })
            }
            AddSetRow()
        }
        .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 14)
        .lookSurface(.card)
    }

    private func v(_ w: Double, _ r: Int) -> SetValue { SetValue(weight: w, unit: .lb, reps: r) }
}

private struct SetStatesPage: View {
    @Environment(\.look) private var look
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GalleryLabel("Typed · empty · next · F · D · first")
            VStack(spacing: 4) {
                SetColumnHeader()
                SetRowView(kind: .working, number: 4, last: v(110, 8), weight: 115, unit: .lb, reps: 6, state: .typed)
                SetRowView(kind: .working, number: 5, last: nil, weight: nil, unit: .lb, reps: nil, state: .empty)
                SetRowView(kind: .working, number: 3, last: v(105, 8), weight: 110, unit: .lb, reps: 8,
                           state: .prefilled, isNextUp: true, isResting: false)
                SetRowView(kind: .failure, number: 0, last: v(105, 6), weight: 105, unit: .lb, reps: 7, state: .completed)
                SetRowView(kind: .drop, number: 0, last: v(90, 12), weight: 90, unit: .lb, reps: 12, state: .prefilled)
                SetRowView(kind: .working, number: 1, last: nil, weight: 60, unit: .kg, reps: 10, state: .completed, badge: .firstTime)
            }
            .padding(12)
            .lookSurface(.card)
        }
        VStack(alignment: .leading, spacing: 12) {
            GalleryLabel("NewBestBadge · stale vitals · rest final 10 s")
            HStack(spacing: 16) {
                NewBestBadge(kind: .newBest)
                NewBestBadge(kind: .firstTime)
            }
            VitalsStrip(hr: 131, zone: .two, isStale: true, staleSeconds: 12, activeCal: 96, volume: 4_120)
            VitalsStrip(hr: nil, zone: nil, activeCal: nil, volume: 4_120)
            RestBar(remaining: 8, total: 120, next: look.nextExerciseLabel("Incline Chest Press"))
        }
        VStack(alignment: .leading, spacing: 12) {
            GalleryLabel("Rings")
            HStack(spacing: 18) {
                SetsRing(done: 7, total: 18)
                SetsRing(done: 30, total: 36)
                RestRing(progress: 0.7)
                RestRing(progress: 0.07, isFinal: true)
                    .environment(\.lookOnSlab, look.id.isPaperClub)
                    .padding(6)
                    .background { if look.id.isPaperClub { RoundedRectangle(cornerRadius: 12).fill(look.slab) } }
            }
        }
    }

    private func v(_ w: Double, _ r: Int) -> SetValue { SetValue(weight: w, unit: .lb, reps: r) }
}

private struct FinishPage: View {
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let sample = GallerySample.shared
        Group {
            if look.id == .anatomy {
                status.padding(16).frame(maxWidth: .infinity, alignment: .leading).lookSurface(.card)
            } else {
                status
            }
        }
        VStack(spacing: look.id.isPaperClub ? 14 : 10) {
            PrimaryButton("View in History", symbol: "clock.arrow.circlepath")
            Button { } label: {
                Label("Save as Template", systemImage: "square.on.square")
            }
            .buttonStyle(.lookSecondary)
        }
        VStack(alignment: .leading, spacing: look.space.header) {
            if !look.id.isPaperClub { SectionHeader("Workout details") }
            StatPairGrid(tiles: sample.finish.tiles)
        }
    }

    /// Ring beside the headline block (the block moves under it at AX sizes, A/C SPEC §9).
    private var status: some View {
        let sample = GallerySample.shared
        let layout = typeSize.isAccessibilitySize && look.id != .anatomy
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
            : AnyLayout(HStackLayout(spacing: 16))
        return layout {
            FinishStatusRing(segments: sample.familySets)
            VStack(alignment: .leading, spacing: 4) {
                if look.id.isPaperClub {
                    Text("Push Day").font(.system(.subheadline, weight: .semibold)).foregroundStyle(look.textSecondary)
                }
                Text("Workout saved").font(look.font.title).foregroundStyle(look.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if look.id == .floodlight {
                    // A SPEC §10: "Push Day · Iron Temple", then "5 exercises · 22 sets".
                    Text("Push Day · Iron Temple").font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(look.textPrimary).padding(.top, 2)
                    Text("5 exercises · 22 sets").font(look.font.caption).foregroundStyle(look.textSecondary)
                    FamilyStrip(families: sample.familySets.map(\.family), size: 30).padding(.top, 6)
                } else {
                    Text(sample.finish.summaryLine).font(look.font.subhead).foregroundStyle(look.textSecondary)
                }
            }
        }
    }
}

private struct FinishDataPage: View {
    @Environment(\.look) private var look
    var body: some View {
        let sample = GallerySample.shared
        VStack(alignment: .leading, spacing: look.space.header) {
            // B's render has no header here (its title lives in the card).
            if look.id != .anatomy { SectionHeader(look.id.isPaperClub ? "Last time" : "Last Push Day") }
            ComparisonBars(context: look.id == .anatomy ? "vs Push Day, Sep 17" : (look.id.isPaperClub ? "Push Day" : nil),
                           lastLabel: "Sep 17", last: 17_400, today: 18_450, unit: "lb")
        }
        HeartRatePlate {
            HeartRateRangeChart(slots: sample.hrSlots, maxHeartRate: sample.maxHeartRate,
                                startLabel: look.id == .anatomy ? "6:12 PM" : "0:00",
                                endLabel: look.id == .anatomy ? "7:04 PM" : "52:10")
            ZoneBreakdown(seconds: sample.zoneSeconds)
        }
    }
}

private struct ListsPage: View {
    @State private var toggle = true
    @State private var segment = 0
    @State private var rest = 120
    @State private var search = ""
    @Environment(\.look) private var look

    var body: some View {
        SheetHeader(title: "New Gym").padding(.horizontal, -look.space.margin)
        LookList(header: "Iron Temple") {
            LookRow("Machines", symbol: LookIcon.machine, value: "14", action: {})
            LookRow("Chest Press 2", subtitle: "Used 12 times · best 110 lb × 8", symbol: LookIcon.machine, action: {})
            LookToggleRow("Suppress template update prompts", isOn: $toggle)
        }
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Chip("All", isSelected: true)
                Chip("Chest")
                Chip("Machines", symbol: LookIcon.machine)
            }
            SegmentedPills(["Lifting", "Cardio"], selection: $segment)
            HStack {
                NumberStepperPill(value: $rest, range: 0...600, step: 15) { Format.rest($0) }
                Spacer()
            }
            SearchFieldView(text: $search, prompt: "Search exercises")
        }
        ProgressLineChart(points: GallerySample.shared.progress, unit: "lb", height: 150)
        DestructiveRowButton("Discard Workout…")
        EmptyStateView(symbol: "building.2", title: "No machines yet", actionTitle: "Scan Machine")
    }
}
