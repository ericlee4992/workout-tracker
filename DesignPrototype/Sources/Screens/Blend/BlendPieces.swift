import SwiftUI

// DIRECTION C "Blend" — shared pieces. The dial is the cardio ring's geometry (square-ended ticks,
// nothing inside but type); nutrition is typographic (P / C / F monograms in Expanded Black).

/// A ring of square-ended ticks, lit up to `progress`.
struct TickDial<Center: View>: View {
    var progress: Double
    var ticks: Int
    var tint: Color
    var size: CGFloat
    var tickLength: CGFloat
    var tickWidth: CGFloat
    @ViewBuilder var center: Center
    @Environment(\.look) private var look

    var body: some View {
        let lit = Int((min(max(progress, 0), 1) * Double(ticks)).rounded())
        ZStack {
            ForEach(0..<ticks, id: \.self) { i in
                Rectangle()
                    .fill(i < lit ? tint : look.ringTrack)
                    .frame(width: tickWidth, height: tickLength)
                    .offset(y: -(size / 2 - tickLength / 2))
                    .rotationEffect(.degrees(Double(i) / Double(ticks) * 360))
            }
            center
        }
        .frame(width: size, height: size)
        .animation(.easeOut(duration: 0.5), value: lit)
        .accessibilityHidden(true)
    }
}

/// P / C / F in Expanded Black, in the macro's hue.
struct Monogram: View {
    var macro: BlendMacro
    var size: Font = .system(size: 13, weight: .black).width(.expanded)
    @Environment(\.look) private var look
    var body: some View {
        Text(macro.letter).font(size).foregroundStyle(macro.color(dark: look.isDark))
    }
}

/// A straight segmented rail (Astra's "measured marks"): square segments lit up to `progress`.
struct SegmentRail: View {
    var progress: Double
    var segments: Int = 20
    var tint: Color
    @Environment(\.look) private var look

    var body: some View {
        let lit = Int((min(max(progress, 0), 1) * Double(segments)).rounded())
        HStack(spacing: 3) {
            ForEach(0..<segments, id: \.self) { i in
                Rectangle().fill(i < lit ? tint : look.ringTrack).frame(height: 8)
            }
        }
        .animation(.easeOut(duration: 0.4), value: lit)
        .accessibilityHidden(true)
    }
}

/// Our week tiles as the day strip: ink fill + minutes = trained; a tan underline = food logged;
/// today dashed (Fable's signature 3).
struct BlendDayTiles: View {
    @Environment(Store.self) private var store
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var nutrition = SoftNutrition.shared

    var body: some View {
        let days = store.weekSummary.days
        HStack(spacing: 6) {
            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                let minutes = day.workouts.reduce(0) { $0 + $1.minutes }
                let trained = !day.workouts.isEmpty
                let food = index < nutrition.week.count && (nutrition.week[index] != nil || day.isToday)
                let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
                VStack(alignment: .leading, spacing: 0) {
                    Text(day.letter).font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(trained ? look.onDone.opacity(0.7) : (day.isFuture ? look.textTertiary : look.textSecondary))
                    Spacer(minLength: 0)
                    if trained && !typeSize.isAccessibilitySize {
                        Text("\(minutes)").font(look.font.smallNumber).foregroundStyle(look.onDone)
                            .minimumScaleFactor(0.7).lineLimit(1)
                    }
                }
                .padding(7)
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .topLeading)
                .background { if trained { shape.fill(look.done) } else if !day.isFuture { shape.fill(look.surface) } }
                .overlay {
                    if day.isToday && !trained {
                        shape.strokeBorder(look.textPrimary.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    } else if day.isFuture {
                        shape.strokeBorder(look.hairline, lineWidth: 1)
                    }
                }
                .overlay(alignment: .bottom) {
                    if food && !day.isFuture {
                        Capsule().fill(BlendMacro.carbs.color(dark: look.isDark)).frame(height: 4).padding(.horizontal, 8)
                            .offset(y: 8)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(day.letter)\(trained ? ", trained \(minutes) minutes" : "")\(food ? ", food logged" : "")")
            }
        }
        .padding(.bottom, 8)
    }
}

/// A receipt row: label leading, Expanded figure trailing, hairline between rows (signature 4).
struct ReceiptRow<Trailing: View>: View {
    var title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing
    @Environment(\.look) private var look

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(.body, weight: .semibold)).foregroundStyle(look.textPrimary)
                if let subtitle { Text(subtitle).font(.system(.footnote)).foregroundStyle(look.textSecondary) }
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

/// The mono pill in Blend: Expanded-free label (buttons stay standard width), ink / white.
struct BlendPill: View {
    var title: String
    var symbol: String?
    var outlined = false
    var action: () -> Void
    @Environment(\.look) private var look

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let symbol { Image(systemName: symbol).font(.system(.subheadline, weight: .bold)) }
                Text(title).font(.system(.subheadline, weight: .semibold))
            }
            .foregroundStyle(outlined ? look.textPrimary : look.onAction)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background { if outlined { Capsule().strokeBorder(look.textPrimary.opacity(0.2), lineWidth: 1.2) } else { Capsule().fill(look.action) } }
            .contentShape(Capsule())
        }
        .buttonStyle(.lookPressable)
    }
}
