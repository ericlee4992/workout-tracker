import SwiftUI

// EXPLORATION (2026-11-07) — Soft "Profile" (settings, goals, and the places that were tabs:
// Gyms, Exercises, History), the floating + menu, Log Food, Scan Food and Log Weight.

// MARK: - Profile

struct SoftProfileScreen: View {
    @Environment(\.look) private var look

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Profile").font(.system(.largeTitle, weight: .bold)).foregroundStyle(look.textPrimary).padding(.top, 6)
                HStack(spacing: 16) {
                    ZStack {
                        Circle().fill(look.textPrimary)
                        Image(systemName: "person.fill").font(.system(.title, weight: .semibold)).foregroundStyle(look.onAction)
                    }
                    .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Your name").font(.system(.title3, weight: .semibold)).foregroundStyle(look.textPrimary)
                        Text("Signed in with Apple").font(.system(.subheadline)).foregroundStyle(look.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(look.textTertiary)
                }
                .padding(18)
                .lookSurface(.panel)

                group("Training") {
                    link("History", "clock.arrow.circlepath") { HistoryScreen() }
                    link("Gyms", "building.2") { GymsScreen() }
                    link("Exercises", "list.bullet.rectangle") { ExercisesScreen() }
                    link("Units, rest and appearance", "slider.horizontal.3") { SettingsScreen() }
                }
                group("Goals & tracking") {
                    row("Nutrition goals", "scope", value: "2,288 cal")
                    row("Body weight goal", "flag", value: "170 lb")
                    row("Apple Health", "heart", value: "On")
                }
                group("Help") {
                    row("Show Tour", "map")
                    row("What's New", "sparkles.rectangle.stack")
                    row("Send Feedback", "bubble.left.and.text.bubble.right")
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .lookScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .proposalScreen("profile")
    }

    private func group<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(.headline, weight: .medium)).foregroundStyle(look.textSecondary).padding(.leading, 4)
            VStack(spacing: 0) {
                Group(subviews: content()) { rows in
                    ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                        if i > 0 { LookDivider().padding(.leading, 58) }
                        row
                    }
                }
            }
            .lookSurface(.panel)
        }
    }

    private func label(_ title: String, _ symbol: String, value: String? = nil) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.system(.body)).frame(width: 26).foregroundStyle(look.textPrimary)
            Text(title).font(.system(.body, weight: .medium)).foregroundStyle(look.textPrimary)
            Spacer()
            if let value { Text(value).font(.system(.subheadline)).foregroundStyle(look.textSecondary) }
            Image(systemName: "chevron.right").font(.system(.footnote, weight: .semibold)).foregroundStyle(look.textTertiary)
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 58)
        .contentShape(Rectangle())
    }

    private func link<D: View>(_ title: String, _ symbol: String, @ViewBuilder destination: @escaping () -> D) -> some View {
        NavigationLink { destination() } label: { label(title, symbol) }.buttonStyle(.plain)
    }

    private func row(_ title: String, _ symbol: String, value: String? = nil) -> some View {
        Button {} label: { label(title, symbol, value: value) }.buttonStyle(.plain)
    }
}

// MARK: - The + menu

enum SoftCover: String, Identifiable {
    case logFood, scanFood, logWeight
    var id: String { rawValue }
}

/// The floating +: four large choices over a dimmed screen.
struct SoftAddMenu: View {
    @Binding var shown: Bool
    var choose: (String) -> Void
    @Environment(\.look) private var look
    @State private var appeared = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Rectangle().fill(.black.opacity(look.isDark ? 0.55 : 0.32)).ignoresSafeArea()
                .accessibilityHidden(true)
                .onTapGesture { close() }
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    card("Start workout", "dumbbell.fill", "train")
                    card("Log food", "magnifyingglass", "logFood")
                }
                HStack(spacing: 14) {
                    card("Log weight", "scalemass.fill", "logWeight")
                    card("Scan food", "camera.viewfinder", "scanFood")
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 130)
            .scaleEffect(appeared ? 1 : 0.92, anchor: .bottom)
            .opacity(appeared ? 1 : 0)
            Button(action: close) {
                Image(systemName: "xmark").font(.system(.title2, weight: .semibold)).foregroundStyle(look.onAction)
                    .frame(width: 62, height: 62)
                    .background(look.action, in: Circle())
            }
            .padding(.trailing, 18).padding(.bottom, 3)
            .accessibilityLabel("Close")
        }
        .onAppear { withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) { appeared = true } }
    }

    private func card(_ title: String, _ symbol: String, _ key: String) -> some View {
        Button { shown = false; choose(key) } label: {
            VStack(spacing: 12) {
                Image(systemName: symbol).font(.system(size: 28, weight: .semibold))
                Text(title).font(.system(.headline, weight: .semibold))
            }
            .foregroundStyle(look.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 124)
            .background(look.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.lookPressable)
    }

    private func close() { withAnimation(.easeOut(duration: 0.18)) { shown = false } }
}

// MARK: - Log food

struct SoftLogFoodScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.look) private var look
    @State private var nutrition = SoftNutrition.shared
    @State private var tab = "All"
    @State private var text = ""
    @State private var added: Set<String> = []
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("Log Food").font(.system(.headline, weight: .semibold)).foregroundStyle(look.textPrimary)
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "arrow.left").font(.system(.body, weight: .semibold)).foregroundStyle(look.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(look.surface, in: Circle())
                            .shadow(color: .black.opacity(look.isDark ? 0 : 0.08), radius: 8, y: 2)
                    }
                    .accessibilityLabel("Back")
                    Spacer()
                }
            }
            .padding(.horizontal, 20).padding(.top, 8)
            HStack(spacing: 22) {
                ForEach(["All", "My foods", "My meals", "Saved"], id: \.self) { t in
                    Button { withAnimation(.snappy) { tab = t } } label: {
                        VStack(spacing: 8) {
                            Text(t).font(.system(.body, weight: tab == t ? .semibold : .medium))
                                .foregroundStyle(tab == t ? look.textPrimary : look.textSecondary)
                            Capsule().fill(tab == t ? look.textPrimary : .clear).frame(height: 2)
                        }
                        .fixedSize()
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 20).padding(.top, 18)
            LookDivider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(look.textSecondary).padding(.top, 2)
                        TextField("Describe what you ate", text: $text, axis: .vertical)
                            .lineLimit(2...4)
                            .focused($focused)
                    }
                    .padding(16)
                    .background(look.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(look.textPrimary.opacity(focused ? 0.9 : 0.15), lineWidth: 1.5) }
                    Text("Recently logged").font(.system(.title3, weight: .bold)).foregroundStyle(look.textPrimary).padding(.top, 6)
                    ForEach(nutrition.recent) { food in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(food.name).font(.system(.headline)).foregroundStyle(look.textPrimary)
                                HStack(spacing: 6) {
                                    Image(systemName: "flame.fill").font(.system(.caption)).foregroundStyle(look.textSecondary)
                                    Text("\(food.calories) cal · \(food.detail)").font(.system(.subheadline)).foregroundStyle(look.textSecondary)
                                }
                            }
                            Spacer()
                            Button {
                                nutrition.log(food)
                                withAnimation(.snappy) { _ = added.insert(food.name) }
                            } label: {
                                Image(systemName: added.contains(food.name) ? "checkmark" : "plus")
                                    .font(.system(.body, weight: .semibold))
                                    .foregroundStyle(added.contains(food.name) ? look.onAction : look.textPrimary)
                                    .frame(width: 44, height: 44)
                                    .background(added.contains(food.name) ? look.action : look.surface, in: Circle())
                                    .contentTransition(.symbolEffect(.replace))
                            }
                            .accessibilityLabel("Add \(food.name)")
                        }
                        .padding(16)
                        .background(look.surfaceRaised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                }
                .padding(20)
            }
            HStack(spacing: 12) {
                SoftOutlineButton(title: "Manual Add", symbol: "list.bullet.rectangle") {}
                SoftOutlineButton(title: "Voice Log", symbol: "mic") {}
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
        .lookScreenBackground()
        .proposalScreen("logFood")
    }
}

// MARK: - Scan food (camera mock: the Simulator has no camera)

struct SoftScanFoodScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var mode = "Scan food"
    @State private var result = false
    @State private var nutrition = SoftNutrition.shared

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x6B6258), Color(hex: 0x3A352F)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            viewfinder
            VStack {
                HStack {
                    circleButton("xmark", "Close") { dismiss() }
                    Spacer()
                    circleButton("questionmark", "Help") {}
                }
                .padding(.horizontal, 20)
                Spacer()
                HStack(spacing: 10) {
                    ForEach([("Scan food", "camera.viewfinder"), ("Barcode", "barcode"), ("Food label", "list.bullet.rectangle")], id: \.0) { m in
                        Button { withAnimation(.snappy) { mode = m.0 } } label: {
                            VStack(spacing: 6) {
                                Image(systemName: m.1).font(.system(.title3, weight: .semibold))
                                Text(m.0).font(.system(.footnote, weight: .semibold))
                            }
                            .foregroundStyle(mode == m.0 ? Color.black : .white)
                            .frame(maxWidth: .infinity, minHeight: 72)
                            .background(mode == m.0 ? Color.white : Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                Button { withAnimation(.spring) { result = true } } label: {
                    Circle().fill(.white).frame(width: 72, height: 72)
                        .overlay { Circle().strokeBorder(.white.opacity(0.4), lineWidth: 6).padding(-8) }
                }
                .padding(.vertical, 24)
                .accessibilityLabel("Take photo")
            }
        }
        .sheet(isPresented: $result) { resultSheet.presentationDetents([.height(330)]) }
        .preferredColorScheme(.dark)
    }

    private var viewfinder: some View {
        GeometryReader { geo in
            let w = geo.size.width * 0.78, h = geo.size.height * 0.42
            ZStack {
                ForEach(0..<4, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .trim(from: CGFloat(i) * 0.25 + 0.06, to: CGFloat(i) * 0.25 + 0.19)
                        .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                }
                .frame(width: w, height: h)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: -60)
        }
    }

    private var resultSheet: some View {
        let food = SoftFood(name: "Chicken rice bowl", detail: "large", calories: 640, protein: 46, carbs: 78, fat: 14, time: "")
        return VStack(alignment: .leading, spacing: 16) {
            Text(food.name).font(.system(.title2, weight: .bold))
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(food.calories)").font(.system(size: 40, weight: .semibold)).monospacedDigit()
                Text("cal").foregroundStyle(.secondary)
            }
            HStack(spacing: 18) {
                ForEach(SoftMacro.allCases) { m in
                    let g = m == .protein ? food.protein : (m == .carbs ? food.carbs : food.fat)
                    Label("\(g)g \(m.name.lowercased())", systemImage: m.symbol)
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(m.color)
                }
            }
            Spacer()
            Button {
                nutrition.log(food)
                result = false
                dismiss()
            } label: {
                Text("Log it").font(.system(.headline)).foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(.white, in: Capsule())
            }
        }
        .padding(24)
    }

    private func circleButton(_ symbol: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(.body, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 48, height: 48).background(.white.opacity(0.18), in: Circle())
        }
        .accessibilityLabel(label)
    }
}

// MARK: - Log weight

struct SoftLogWeightSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.look) private var look
    @State private var weight = 172.4

    var body: some View {
        VStack(spacing: 22) {
            Text("Log weight").font(.system(.headline)).foregroundStyle(look.textPrimary).padding(.top, 20)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(weight.formatted(.number.precision(.fractionLength(1)))).font(.system(size: 64, weight: .semibold)).monospacedDigit()
                    .contentTransition(.numericText(value: weight))
                Text("lb").font(.system(.title2, weight: .medium)).foregroundStyle(look.textSecondary)
            }
            .foregroundStyle(look.textPrimary)
            HStack(spacing: 16) {
                stepButton("minus") { weight -= 0.2 }
                stepButton("plus") { weight += 0.2 }
            }
            Spacer()
            Button { dismiss() } label: {
                Text("Save").font(.system(.headline)).foregroundStyle(look.onAction)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(look.action, in: Capsule())
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(look.ground)
    }

    private func stepButton(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button { withAnimation(.snappy) { action() } } label: {
            Image(systemName: symbol).font(.system(.title3, weight: .semibold)).foregroundStyle(look.textPrimary)
                .frame(width: 64, height: 52)
                .background(look.surface, in: Capsule())
                .overlay { Capsule().strokeBorder(look.hairline) }
        }
    }
}

// MARK: - Tab bar

/// The floating capsule of five tabs (the + circle is gone: food has its own pill).
struct SoftTabBar: View {
    var selection: SoftTab
    var select: (SoftTab) -> Void
    @Environment(\.look) private var look
    @State private var options = SoftOptions.shared

    private var items: [(SoftTab, String, String)] {
        options.layout == .foodTab
            ? [(.today, "Today", "house"), (.train, "Train", "dumbbell"), (.food, "Food", "fork.knife"),
               (.history, "History", "clock.arrow.circlepath"), (.progress, "Progress", "chart.bar")]
            : [(.today, "Today", "house"), (.train, "Train", "dumbbell"), (.history, "History", "clock.arrow.circlepath"),
               (.progress, "Progress", "chart.bar"), (.profile, "Profile", "person.crop.circle")]
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.0) { item in
                let on = item.0 == selection
                Button { select(item.0) } label: {
                    VStack(spacing: 3) {
                        Image(systemName: on && item.2 != "clock.arrow.circlepath" ? item.2 + ".fill" : item.2)
                            .font(.system(size: 19, weight: on ? .semibold : .regular))
                            .frame(height: 24)
                        Text(item.1).font(.system(size: 11, weight: on ? .semibold : .medium))
                    }
                    .foregroundStyle(on ? look.textPrimary : look.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background { if on { Capsule().fill(look.textPrimary.opacity(look.isDark ? 0.14 : 0.07)).padding(3) } }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(4)
        .glassEffect(.regular, in: Capsule())
        .padding(.horizontal, 18)
        .padding(.bottom, 2)
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }
}

/// "Log food": a black pill above the tab bar, only on the screens where food lives.
struct SoftLogFoodPill: View {
    var action: () -> Void
    @Environment(\.look) private var look

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus").font(.system(.subheadline, weight: .bold))
                Text("Log food").font(.system(.headline, weight: .semibold))
            }
            .foregroundStyle(look.onAction)
            .padding(.horizontal, 22).frame(minHeight: 50)
            .background(look.action, in: Capsule())
            .shadow(color: .black.opacity(0.16), radius: 10, y: 4)
        }
        .buttonStyle(.lookPressable)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.horizontal, 22)
    }
}
