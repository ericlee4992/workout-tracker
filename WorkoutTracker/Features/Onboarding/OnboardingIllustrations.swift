import SwiftUI

/// Public beta ticket 02: each walkthrough page's picture — sample content drawn with the Look tokens, never the
/// user's data. Decorative to VoiceOver (the headline and line carry the meaning).
struct OnboardingIllustration: View {
    var kind: OnboardingPage.Illustration
    @Environment(\.look) private var look

    var body: some View {
        Group {
            switch kind {
            case .welcome: welcome
            case .logging: logging
            case .machines: machines
            case .progress: progress
            case .ai: ai
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: Pages

    private var welcome: some View {
        VStack(spacing: 18) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 88, weight: .bold))
                .foregroundStyle(look.action)
            HStack(spacing: 6) {
                ForEach(MuscleFamily.allCases, id: \.self) { family in
                    MuscleMap(family: family, size: 46)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var logging: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Chest Press").font(look.font.cardTitle).foregroundStyle(look.textPrimary)
            Text("Life Fitness · Signature").font(look.font.caption).foregroundStyle(look.textSecondary)
            VStack(spacing: 6) {
                setRow(number: 1, weight: "135", reps: "10", done: true)
                setRow(number: 2, weight: "145", reps: "8", done: true)
                setRow(number: 3, weight: "145", reps: "8", done: false)
            }
            .padding(.top, 4)
            restBar
        }
        .padding(look.space.panelPadding)
        .lookSurface(.card)
    }

    private var machines: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Downtown Gym").font(look.font.cardTitle).foregroundStyle(look.textPrimary)
                .padding(.bottom, 10)
            machineRow("Chest Press", detail: "Life Fitness", last: "145 lb × 8")
            divider
            machineRow("Leg Press", detail: "Hammer Strength", last: "320 lb × 10")
            divider
            machineRow("Lat Pulldown", detail: "Matrix", last: "120 lb × 12")
            HStack(spacing: 8) {
                Image(systemName: "camera.viewfinder").font(.body.weight(.semibold))
                Text("Scan Machine").font(look.font.subhead.weight(.semibold))
            }
            .foregroundStyle(look.actionText)
            .padding(.top, 12)
        }
        .padding(look.space.panelPadding)
        .lookSurface(.card)
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("320 lb × 10").font(look.font.heroNumber).foregroundStyle(look.textPrimary)
                    Text("Best · Leg Press").font(look.font.caption).foregroundStyle(look.textSecondary)
                }
                Spacer(minLength: 8)
                Text("New best")
                    .font(look.font.badge)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(look.done, in: RoundedRectangle(cornerRadius: look.radius.badge))
                    .foregroundStyle(look.onDone)
            }
            sparkline
                .frame(height: 54)
            FamilyStrip(families: [.chest, .back, .legs], size: 30)
        }
        .padding(look.space.panelPadding)
        .lookSurface(.card)
    }

    private var ai: some View {
        VStack(spacing: 10) {
            aiRow(symbol: "camera.viewfinder", title: "Scan Machine", detail: "Photo → machine and its exercises")
            aiRow(symbol: "sparkles", title: "Ask AI for Templates", detail: "Goals and days → a week to edit")
        }
    }

    // MARK: Pieces

    private func setRow(number: Int, weight: String, reps: String, done: Bool) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(look.font.smallNumber)
                .frame(width: 30, height: 30)
                .background(done ? look.done : look.field, in: RoundedRectangle(cornerRadius: look.radius.marker))
                .foregroundStyle(done ? look.onDone : look.textSecondary)
            Text("\(weight) lb").font(look.font.fieldNumber).foregroundStyle(look.textPrimary)
            Text("×").foregroundStyle(look.textTertiary)
            Text(reps).font(look.font.fieldNumber).foregroundStyle(look.textPrimary)
            Spacer()
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(done ? look.done : look.textTertiary)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(look.surfaceRaised, in: RoundedRectangle(cornerRadius: look.radius.row))
    }

    private var restBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "timer").font(.body.weight(.semibold))
            Text("Rest").font(look.font.subhead.weight(.semibold))
            Spacer()
            Text("1:24").font(look.font.statNumber)
        }
        .foregroundStyle(look.onAction)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(look.live, in: RoundedRectangle(cornerRadius: look.radius.bar))
        .padding(.top, 6)
    }

    private func machineRow(_ name: String, detail: String, last: String) -> some View {
        HStack(spacing: 12) {
            LookIcon(LookIcon.machine, style: .body).foregroundStyle(look.textSecondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(look.font.body).foregroundStyle(look.textPrimary)
                Text(detail).font(look.font.caption).foregroundStyle(look.textSecondary)
            }
            Spacer(minLength: 8)
            Text(last).font(look.font.subhead).monospacedDigit().foregroundStyle(look.textSecondary)
        }
        .padding(.vertical, 8)
    }

    private var divider: some View {
        Rectangle().fill(look.hairline).frame(height: 1)
    }

    private var sparkline: some View {
        GeometryReader { proxy in
            let values: [CGFloat] = [0.25, 0.32, 0.30, 0.45, 0.52, 0.50, 0.66, 0.74, 0.92]
            Path { path in
                for (index, value) in values.enumerated() {
                    let x = proxy.size.width * CGFloat(index) / CGFloat(values.count - 1)
                    let y = proxy.size.height * (1 - value)
                    if index == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(look.action, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
    }

    private func aiRow(symbol: String, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(look.actionText)
                .frame(width: 44, height: 44)
                .background(look.surfaceRaised, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(look.font.headline).foregroundStyle(look.textPrimary)
                Text(detail).font(look.font.caption).foregroundStyle(look.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(look.space.panelPadding)
        .lookSurface(.card)
    }
}
