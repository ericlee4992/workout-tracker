import SwiftUI
import Charts

// DIRECTION C "Blend" — Today, Food, Library, Progress, Log food. Sample data (SoftNutrition).

// MARK: - Today

struct BlendTodayScreen: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var nutrition = SoftNutrition.shared
    @State private var options = BlendOptions.shared
    @State private var showLogFood = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LookNavTitle("Today", subtitle: store.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                BlendDayTiles()
                BlendCaloriesCard()
                BlendMacros()
                SectionHeader("Training", level: .page).padding(.top, 6)
                BlendTrainingCard()
                SectionHeader("Meals", level: .page).padding(.top, 6)
                BlendMealsReceipt { showLogFood = true }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .lookScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { router.push(.settings) } label: { Image(systemName: "gearshape").foregroundStyle(look.textPrimary) }
                    .accessibilityLabel("Settings")
            }
        }
        .fullScreenCover(isPresented: $showLogFood) { BlendLogFoodScreen().environment(\.look, look) }
        .proposalScreen("today")
    }
}

/// `1,240 /2,288` in Expanded Black beside the 24-tick ink dial.
struct BlendCaloriesCard: View {
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var nutrition = SoftNutrition.shared

    var body: some View {
        let eaten = nutrition.eaten, goal = nutrition.calorieGoal
        let pct = Int((Double(eaten) / Double(goal) * 100).rounded())
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16)) : AnyLayout(HStackLayout(spacing: 16))
        layout {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(eaten.formatted()).font(.system(size: 40, weight: .black).width(.expanded)).monospacedDigit()
                        .foregroundStyle(look.textPrimary).contentTransition(.numericText())
                    Text("/\(goal.formatted())").font(.system(.subheadline, weight: .medium).width(.expanded))
                        .foregroundStyle(look.textSecondary)
                }
                .lineLimit(1).minimumScaleFactor(0.6)
                Text("Calories eaten · \(max(0, goal - eaten).formatted()) left")
                    .font(.system(.subheadline, weight: .medium)).foregroundStyle(look.textSecondary)
            }
            Spacer(minLength: 0)
            TickDial(progress: Double(eaten) / Double(goal), ticks: 24, tint: look.textPrimary, size: 96, tickLength: 12, tickWidth: 4) {
                Text("\(pct)%").font(.system(.headline, weight: .heavy).width(.expanded)).foregroundStyle(look.textPrimary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.panel)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Calories eaten, \(eaten) of \(goal)")
    }
}

/// Protein · Carbs · Fat: Fable's ticked dials with monograms, or Astra's segmented rails.
struct BlendMacros: View {
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var nutrition = SoftNutrition.shared
    @State private var options = BlendOptions.shared

    var body: some View {
        if options.macros == .dials && !typeSize.isAccessibilitySize { dials } else { rails }
    }

    private var dials: some View {
        HStack(spacing: 8) {
            ForEach(BlendMacro.allCases) { m in
                let eaten = nutrition.eaten(m.soft), goal = nutrition.goals[m.soft] ?? 1
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text("\(eaten)").font(.system(.title3, weight: .heavy).width(.expanded)).monospacedDigit()
                            .foregroundStyle(look.textPrimary).contentTransition(.numericText())
                        Text("/\(goal)g").font(.system(.caption, weight: .medium)).foregroundStyle(look.textSecondary)
                    }
                    .lineLimit(1).minimumScaleFactor(0.7)
                    TickDial(progress: Double(eaten) / Double(goal), ticks: 12, tint: m.color(dark: look.isDark), size: 62, tickLength: 9, tickWidth: 4) {
                        Monogram(macro: m, size: .system(size: 17, weight: .black).width(.expanded))
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lookSurface(.card)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(m.name), \(eaten) of \(goal) grams")
            }
        }
    }

    private var rails: some View {
        VStack(spacing: 14) {
            ForEach(BlendMacro.allCases) { m in
                let eaten = nutrition.eaten(m.soft), goal = nutrition.goals[m.soft] ?? 1
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Monogram(macro: m)
                        Text(m.name).font(.system(.subheadline, weight: .semibold)).foregroundStyle(look.textPrimary)
                        Spacer()
                        Text("\(eaten)").font(.system(.headline, weight: .heavy).width(.expanded)).monospacedDigit()
                            .foregroundStyle(look.textPrimary).contentTransition(.numericText())
                        Text("/ \(goal) g").font(.system(.footnote, weight: .medium)).foregroundStyle(look.textSecondary)
                    }
                    SegmentRail(progress: Double(eaten) / Double(goal), tint: m.color(dark: look.isDark))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(m.name), \(eaten) of \(goal) grams")
            }
        }
        .padding(18)
        .lookSurface(.panel)
    }
}

/// The next template (muscle figures, Expanded name, Mono Start) — before the session; after it,
/// the card collapses to one receipt row.
struct BlendTrainingCard: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look

    var body: some View {
        if let next = store.sortedTemplates.min(by: { (store.templateStats($0.id).lastRun ?? .distantPast) < (store.templateStats($1.id).lastRun ?? .distantPast) }) {
            let names = next.items.compactMap { store.exercise($0.exerciseID)?.name }
            VStack(alignment: .leading, spacing: 12) {
                Button { router.push(.templateDetail(templateID: next.id)) } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(next.name).font(look.font.title).foregroundStyle(look.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(.footnote, weight: .bold)).foregroundStyle(look.textTertiary)
                        }
                        FamilyStrip(families: store.families(ofTemplate: next.id), size: 36, spacing: 4)
                        Text(names.prefix(3).joined(separator: " · ") + (names.count > 3 ? " · +\(names.count - 3)" : ""))
                            .font(look.font.subhead).foregroundStyle(look.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                TemplatesStartCapsule(subtitle: [store.selectedGym?.name, Format.count(next.items.count, "exercise")].compactMap { $0 }.joined(separator: " · ")) {
                    _ = store.startLifting(templateID: next.id)
                }
            }
            .padding(16)
            .lookSurface(.panel)
        }
    }
}

/// Meals as a receipt; an empty meal shows a + (one tap opens Log food).
struct BlendMealsReceipt: View {
    var logFood: () -> Void
    @Environment(\.look) private var look
    @State private var nutrition = SoftNutrition.shared

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(["Breakfast", "Lunch", "Dinner", "Snack"].enumerated()), id: \.offset) { i, meal in
                if i > 0 { LookDivider() }
                let foods = nutrition.today.filter { $0.meal == meal }
                ReceiptRow(title: meal, subtitle: foods.isEmpty ? "Nothing logged" : foods.map(\.name).joined(separator: ", ")) {
                    if foods.isEmpty {
                        Button(action: logFood) {
                            Image(systemName: "plus").font(.system(.subheadline, weight: .bold)).foregroundStyle(look.textPrimary)
                                .frame(width: 36, height: 36).overlay { Circle().strokeBorder(look.textPrimary.opacity(0.2)) }
                        }
                        .accessibilityLabel("Log \(meal)")
                    } else {
                        Text(foods.reduce(0) { $0 + $1.calories }.formatted())
                            .font(.system(.headline, weight: .heavy).width(.expanded)).monospacedDigit().foregroundStyle(look.textPrimary)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .lookSurface(.panel)
    }
}

// MARK: - Food (tab)

struct BlendFoodScreen: View {
    @Environment(\.look) private var look
    @State private var nutrition = SoftNutrition.shared
    @State private var showLogFood = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LookNavTitle("Food", subtitle: "Today")
                BlendCaloriesCard()
                BlendMacros()
                SectionHeader("Diary", level: .page).padding(.top, 6)
                VStack(spacing: 0) {
                    ForEach(Array(nutrition.today.enumerated()), id: \.element.id) { i, food in
                        if i > 0 { LookDivider() }
                        ReceiptRow(title: food.name, subtitle: "\(food.meal) · \(food.time)") {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("\(food.calories)").font(.system(.headline, weight: .heavy).width(.expanded)).monospacedDigit()
                                    .foregroundStyle(look.textPrimary)
                                BlendMacroChips(food: food)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .lookSurface(.panel)
                HStack { Spacer(); BlendPill(title: "Log food", symbol: "plus") { showLogFood = true }; Spacer() }
                SectionHeader("Saved foods", level: .page).padding(.top, 6)
                VStack(spacing: 0) {
                    ForEach(Array(nutrition.recent.enumerated()), id: \.element.id) { i, food in
                        if i > 0 { LookDivider() }
                        ReceiptRow(title: food.name, subtitle: food.detail) {
                            Text("\(food.calories) cal").font(.system(.subheadline, weight: .semibold)).foregroundStyle(look.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .lookSurface(.panel)
            }
            .padding(.horizontal, look.space.margin)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .lookScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showLogFood) { BlendLogFoodScreen().environment(\.look, look) }
        .proposalScreen("food")
    }
}

struct BlendMacroChips: View {
    let food: SoftFood
    @Environment(\.look) private var look
    var body: some View {
        HStack(spacing: 8) {
            ForEach(BlendMacro.allCases) { m in
                let g = m == .protein ? food.protein : (m == .carbs ? food.carbs : food.fat)
                HStack(spacing: 2) {
                    Monogram(macro: m, size: .system(size: 10, weight: .black).width(.expanded))
                    Text("\(g)").font(.system(.caption, weight: .semibold)).monospacedDigit().foregroundStyle(look.textSecondary)
                }
            }
        }
    }
}

// MARK: - Library (tab variant)

struct BlendLibraryScreen: View {
    @Environment(\.look) private var look

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LookNavTitle("Library", subtitle: nil)
                VStack(spacing: 0) {
                    row("Gyms", "building.2") { GymsScreen() }
                    LookDivider().padding(.leading, 54)
                    row("Exercises", "list.bullet.rectangle") { ExercisesScreen() }
                    LookDivider().padding(.leading, 54)
                    row("History", "clock.arrow.circlepath") { HistoryScreen() }
                }
                .lookSurface(.panel)
                VStack(spacing: 0) {
                    row("Foods", "fork.knife") { BlendFoodScreen() }
                    LookDivider().padding(.leading, 54)
                    row("Meals", "takeoutbag.and.cup.and.straw") { BlendFoodScreen() }
                }
                .lookSurface(.panel)
            }
            .padding(.horizontal, look.space.margin)
        }
        .lookScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .proposalScreen("library")
    }

    private func row<D: View>(_ title: String, _ symbol: String, @ViewBuilder destination: @escaping () -> D) -> some View {
        NavigationLink { destination() } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol).frame(width: 24).foregroundStyle(look.textPrimary)
                Text(title).font(.system(.body, weight: .semibold)).foregroundStyle(look.textPrimary)
                Spacer()
                Image(systemName: "chevron.right").font(.system(.footnote, weight: .bold)).foregroundStyle(look.textTertiary)
            }
            .padding(.horizontal, 16).frame(minHeight: 56).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Progress: Body · Strength · Fuel

struct BlendProgressScreen: View {
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @State private var nutrition = SoftNutrition.shared
    @State private var section = 0
    @State private var showLogWeight = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LookNavTitle("Progress", subtitle: nil)
                SegmentedPills(["Body", "Strength", "Fuel"], selection: $section)
                switch section {
                case 1: strength
                case 2: fuel
                default: body_
                }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .lookScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLogWeight) { SoftLogWeightSheet().presentationDetents([.medium]) }
        .proposalScreen("progress")
    }

    private var current: Double { nutrition.weights.last ?? 0 }

    private var body_: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(current.formatted(.number.precision(.fractionLength(1)))).font(.system(size: 40, weight: .black).width(.expanded))
                        Text("lb").font(.system(.title3, weight: .semibold).width(.expanded)).foregroundStyle(look.textSecondary)
                    }
                    .foregroundStyle(look.textPrimary).monospacedDigit()
                    Spacer()
                    BlendPill(title: "Log weight") { showLogWeight = true }
                }
                SegmentRail(progress: (nutrition.startWeight - current) / (nutrition.startWeight - nutrition.goalWeight), segments: 20, tint: look.textPrimary)
                HStack {
                    Text("Start \(Int(nutrition.startWeight)) lb")
                    Spacer()
                    Text("Goal \(Int(nutrition.goalWeight)) lb")
                }
                .font(.system(.subheadline, weight: .medium)).foregroundStyle(look.textSecondary)
            }
            .padding(18).lookSurface(.panel)
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Trend")
                Chart {
                    ForEach(Array(nutrition.weights.enumerated()), id: \.offset) { i, w in
                        LineMark(x: .value("Week", i), y: .value("lb", w)).foregroundStyle(look.textPrimary)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                    }
                    RuleMark(y: .value("Goal", nutrition.goalWeight))
                        .lineStyle(StrokeStyle(lineWidth: 1)).foregroundStyle(BlendMacro.carbs.color(dark: look.isDark))
                }
                .chartYScale(domain: 168...182).chartXAxis(.hidden)
                .chartYAxis { AxisMarks(position: .trailing, values: [170, 175, 180]) { _ in AxisValueLabel().foregroundStyle(look.textSecondary) } }
                .frame(height: 170)
            }
            .padding(18).lookSurface(.panel)
        }
    }

    private var strength: some View {
        let lifts: [(String, String, String)] = [("Seated Chest Press", "110 × 8", "+11%"), ("Leg Press", "320 × 10", "+8%"), ("Lat Pulldown", "140 × 8", "+5%")]
        return VStack(spacing: 0) {
            ForEach(Array(lifts.enumerated()), id: \.offset) { i, lift in
                if i > 0 { LookDivider() }
                Button { router.push(.exerciseDetail(exerciseID: SampleData.exerciseID(lift.0))) } label: {
                    ReceiptRow(title: lift.0, subtitle: "\(lift.2) since first session") {
                        Text(lift.1).font(.system(.headline, weight: .heavy).width(.expanded)).monospacedDigit().foregroundStyle(look.textPrimary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16).lookSurface(.panel)
    }

    private var fuel: some View {
        let logged = nutrition.week.compactMap { $0 }
        return VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                Chart {
                    ForEach(0..<7, id: \.self) { i in
                        if let v = (i == 5 ? nutrition.eaten : nutrition.week[i]) {
                            BarMark(x: .value("Day", "\(i)"), y: .value("cal", v), width: .ratio(0.62))
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .foregroundStyle(i == 5 ? look.textPrimary : look.textPrimary.opacity(0.22))
                        }
                    }
                    RuleMark(y: .value("Goal", nutrition.calorieGoal)).foregroundStyle(BlendMacro.carbs.color(dark: look.isDark))
                }
                .chartXAxis { AxisMarks { v in AxisValueLabel { if let s = v.as(String.self), let i = Int(s) { Text(["M","T","W","T","F","S","S"][i]).foregroundStyle(look.textSecondary) } } } }
                .chartYAxis(.hidden)
                .frame(height: 150)
            }
            .padding(18).lookSurface(.panel)
            VStack(spacing: 0) {
                ReceiptRow(title: "Daily average", subtitle: "\(logged.count) days logged") {
                    Text((logged.reduce(0, +) / max(1, logged.count)).formatted()).font(.system(.headline, weight: .heavy).width(.expanded)).foregroundStyle(look.textPrimary)
                }
                LookDivider()
                ReceiptRow(title: "Goal", subtitle: nil) {
                    Text(nutrition.calorieGoal.formatted()).font(.system(.headline, weight: .heavy).width(.expanded)).foregroundStyle(look.textPrimary)
                }
            }
            .padding(.horizontal, 16).lookSurface(.panel)
        }
    }
}

// MARK: - Log food (one-tap +, Undo)

struct BlendLogFoodScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.look) private var look
    @State private var nutrition = SoftNutrition.shared
    @State private var meal = "Lunch"
    @State private var text = ""
    @State private var added: [String: UUID] = [:]
    @State private var toast: String?
    @State private var showScan = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: { Image(systemName: "chevron.left").font(.system(.body, weight: .semibold)).foregroundStyle(look.textPrimary).frame(width: 44, height: 44) }
                    .accessibilityLabel("Back")
                Spacer()
            }
            .padding(.horizontal, 8)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    LookNavTitle("Log food", subtitle: nil)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(["Breakfast", "Lunch", "Dinner", "Snack"], id: \.self) { m in
                                Button { withAnimation(.snappy) { meal = m } } label: {
                                    Text(m).font(.system(.subheadline, weight: .semibold))
                                        .foregroundStyle(meal == m ? look.onAction : look.textPrimary)
                                        .padding(.horizontal, 14).frame(minHeight: 36)
                                        .background { if meal == m { Capsule().fill(look.action) } else { Capsule().strokeBorder(look.textPrimary.opacity(0.18)) } }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(look.textSecondary)
                        TextField("Search or describe what you ate", text: $text)
                    }
                    .padding(14)
                    .background(look.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(look.textPrimary.opacity(0.16), lineWidth: 1.2) }
                    SectionHeader("Recent")
                    VStack(spacing: 0) {
                        ForEach(Array(nutrition.recent.enumerated()), id: \.element.id) { i, food in
                            if i > 0 { LookDivider() }
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(food.name).font(.system(.body, weight: .semibold)).foregroundStyle(look.textPrimary)
                                    BlendMacroChips(food: food)
                                }
                                Spacer()
                                Text("\(food.calories)").font(.system(.headline, weight: .heavy).width(.expanded)).monospacedDigit().foregroundStyle(look.textPrimary)
                                Button {
                                    nutrition.log(food, meal: meal)
                                    if let id = nutrition.lastLogged?.id { added[food.name] = id }
                                    withAnimation(.snappy) { toast = "\(food.name) added to \(meal)" }
                                } label: {
                                    let done = added[food.name] != nil
                                    Image(systemName: done ? "checkmark" : "plus").font(.system(.subheadline, weight: .bold))
                                        .foregroundStyle(look.onAction)
                                        .frame(width: 36, height: 36).background(look.action, in: Circle())
                                        .contentTransition(.symbolEffect(.replace))
                                }
                                .accessibilityLabel("Add \(food.name)")
                            }
                            .padding(.vertical, 12)
                        }
                    }
                    .padding(.horizontal, 16)
                    .lookSurface(.panel)
                }
                .padding(.horizontal, look.space.margin)
            }
            if let toast {
                HStack {
                    Text(toast).font(.system(.subheadline, weight: .semibold)).foregroundStyle(look.onSlab)
                    Spacer()
                    Button("Undo") {
                        nutrition.undoLast()
                        added = [:]
                        withAnimation(.snappy) { self.toast = nil }
                    }
                    .font(.system(.subheadline, weight: .bold)).foregroundStyle(look.onSlab)
                }
                .padding(.horizontal, 18).frame(minHeight: 52)
                .background(Color(hex: 0x0B0C0E), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, look.space.margin)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            HStack(spacing: 10) {
                BlendPill(title: "Scan", symbol: "camera.viewfinder") { showScan = true }
                BlendPill(title: "Manual", outlined: true) {}
                BlendPill(title: "Voice", symbol: "mic", outlined: true) {}
            }
            .padding(.vertical, 12)
        }
        .lookScreenBackground()
        .fullScreenCover(isPresented: $showScan) { SoftScanFoodScreen() }
        .proposalScreen("logFood")
    }
}
