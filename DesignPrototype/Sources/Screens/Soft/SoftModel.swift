import SwiftUI

// EXPLORATION (2026-11-07) — Direction B "Soft": calorie / macro tracking beside the workout log.
// Sample data only; nothing here is a real nutrition model yet.

struct SoftFood: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var detail: String
    var calories: Int
    var protein: Int
    var carbs: Int
    var fat: Int
    var time: String
    var meal: String = "Snack"
}

enum SoftMacro: CaseIterable, Identifiable {
    case protein, carbs, fat
    var id: Self { self }
    var name: String {
        switch self {
        case .protein: "Protein"
        case .carbs: "Carbs"
        case .fat: "Fat"
        }
    }
    var symbol: String {
        switch self {
        case .protein: "fish.fill"
        case .carbs: "leaf.fill"
        case .fat: "drop.fill"
        }
    }
    /// Quiet hues, used only for the small macro icons and their rings.
    var color: Color {
        switch self {
        case .protein: Color(hex: 0xD9665B)
        case .carbs: Color(hex: 0xC9944A)
        case .fat: Color(hex: 0x5B7FC9)
        }
    }
}

@MainActor @Observable
final class SoftNutrition {
    static let shared = SoftNutrition()

    let calorieGoal = 2_288
    let goals: [SoftMacro: Int] = [.protein: 149, .carbs: 261, .fat: 72]
    var today: [SoftFood] = [
        SoftFood(name: "Greek yogurt bowl", detail: "1 bowl", calories: 320, protein: 24, carbs: 38, fat: 8, time: "8:10 AM", meal: "Breakfast"),
        SoftFood(name: "Chicken rice bowl", detail: "large", calories: 640, protein: 46, carbs: 78, fat: 14, time: "12:40 PM", meal: "Lunch"),
        SoftFood(name: "Protein shake", detail: "1 scoop, oat milk", calories: 280, protein: 32, carbs: 22, fat: 6, time: "4:15 PM", meal: "Snack"),
    ]
    let recent: [SoftFood] = [
        SoftFood(name: "Pho", detail: "large bowl", calories: 500, protein: 30, carbs: 62, fat: 12, time: ""),
        SoftFood(name: "Protein shake", detail: "1 scoop, oat milk", calories: 280, protein: 32, carbs: 22, fat: 6, time: ""),
        SoftFood(name: "Fried egg", detail: "large", calories: 90, protein: 6, carbs: 0, fat: 7, time: ""),
        SoftFood(name: "Banana", detail: "medium", calories: 105, protein: 1, carbs: 27, fat: 0, time: ""),
    ]
    /// Calories eaten per day this week, Monday first (nil = not logged; today last logged).
    var week: [Int?] = [2_140, 2_310, 1_980, 2_205, 2_420, nil, nil]
    /// Body weight in lb, oldest first (about 12 weeks).
    let weights: [Double] = [180.2, 179.6, 179.9, 178.8, 178.1, 178.4, 177.2, 176.6, 176.9, 175.8, 175.1, 174.6,
                             174.9, 173.8, 173.2, 172.9, 172.4]
    let startWeight = 180.0
    let goalWeight = 170.0

    var eaten: Int { today.reduce(0) { $0 + $1.calories } }
    func eaten(_ macro: SoftMacro) -> Int {
        today.reduce(0) {
            switch macro {
            case .protein: $0 + $1.protein
            case .carbs: $0 + $1.carbs
            case .fat: $0 + $1.fat
            }
        }
    }

    func log(_ food: SoftFood, at time: String = "Now", meal: String = "Snack") {
        var copy = food
        copy.time = time
        copy.meal = meal
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) { today.append(copy) }
        lastLogged = copy
    }

    /// The last food added (for Undo).
    var lastLogged: SoftFood?
    func undoLast() {
        guard let last = lastLogged else { return }
        withAnimation(.snappy) { today.removeAll { $0.id == last.id } }
        lastLogged = nil
    }

    private init() {}
}

// MARK: - Shared Soft pieces

/// A progress ring with a small icon (or nothing) in the middle.
struct SoftRing: View {
    var progress: Double
    var symbol: String?
    var tint: Color
    var size: CGFloat
    var line: CGFloat = 8
    @Environment(\.look) private var look

    var body: some View {
        ZStack {
            Circle().stroke(look.ringTrack, lineWidth: line)
            Circle()
                .trim(from: 0, to: max(0.001, min(progress, 1)))
                .stroke(tint, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.26, weight: .semibold))
                    .foregroundStyle(tint)
            }
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: progress)
        .accessibilityHidden(true)
    }
}

/// "1,460 /2,288" — the figure big, the goal small.
struct SoftFigure: View {
    var value: String
    var goal: String?
    var size: Font = .system(size: 44, weight: .semibold)
    @Environment(\.look) private var look

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(value).font(size).monospacedDigit().foregroundStyle(look.textPrimary)
                .contentTransition(.numericText())
            if let goal {
                Text("/\(goal)").font(.system(.title3, weight: .medium)).monospacedDigit().foregroundStyle(look.textSecondary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

/// The black capsule (Mono action): "Log weight →", "Start", "Log".
struct SoftPillButton: View {
    var title: String
    var symbol: String?
    var trailingSymbol: String?
    var action: () -> Void
    @Environment(\.look) private var look

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let symbol { Image(systemName: symbol).font(.system(.subheadline, weight: .bold)) }
                Text(title).font(.system(.subheadline, weight: .semibold))
                if let trailingSymbol { Image(systemName: trailingSymbol).font(.system(.subheadline, weight: .bold)) }
            }
            .foregroundStyle(look.onAction)
            .padding(.horizontal, 16)
            .frame(minHeight: 40)
            .background(look.action, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.lookPressable)
    }
}

/// The outlined capsule: "Manual Add", "Voice Log", "+ Join"-style secondary actions.
struct SoftOutlineButton: View {
    var title: String
    var symbol: String?
    var action: () -> Void
    @Environment(\.look) private var look

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let symbol { Image(systemName: symbol).font(.system(.body, weight: .medium)) }
                Text(title).font(.system(.body, weight: .semibold))
            }
            .foregroundStyle(look.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(look.surface, in: Capsule())
            .overlay { Capsule().strokeBorder(look.textPrimary.opacity(0.14), lineWidth: 1) }
            .contentShape(Capsule())
        }
        .buttonStyle(.lookPressable)
    }
}

/// A section title in Soft: plain, bold, left aligned, with an optional trailing link.
struct SoftSectionTitle: View {
    var title: String
    var trailing: String?
    var action: (() -> Void)?
    @Environment(\.look) private var look

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(.title2, weight: .bold)).foregroundStyle(look.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let trailing, let action {
                Button(trailing, action: action)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(look.textSecondary)
            }
        }
    }
}
