import SwiftUI

/// Public beta ticket 02: the welcome page's picture and the tour's picture of logging — sample content drawn with
/// the Look tokens, never the user's data, never interactive. Decorative to VoiceOver (the text carries the meaning).
struct OnboardingIllustration: View {
    enum Kind: Hashable { case welcome, logging }
    var kind: Kind
    @Environment(\.look) private var look

    var body: some View {
        Group {
            switch kind {
            case .welcome: welcome
            case .logging: logging
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
}
