import SwiftUI

// PROPOSAL (2026-11) — the Workout tab's lead: the template due next, with ONE Start.

/// The template done longest ago, as the screen's one decision: its name, the families it
/// trains, its exercises on one line, when it was last done, and Start.
struct ProposedUpNextCard: View {
    let template: Template
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let stats = store.templateStats(template.id)
        let names = template.items.compactMap { store.exercise($0.exerciseID)?.name }
        VStack(alignment: .leading, spacing: 14) {
            Button { router.push(.templateDetail(templateID: template.id)) } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 10) {
                        Text(template.name)
                            .font(look.font.title)
                            .foregroundStyle(look.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .font(.system(.footnote, weight: .bold))
                            .foregroundStyle(look.textTertiary)
                    }
                    FamilyStrip(families: store.families(ofTemplate: template.id), size: typeSize.isAccessibilitySize ? 40 : 34, spacing: 4)
                    Text(exerciseLine(names))
                        .font(look.font.subhead)
                        .foregroundStyle(look.textSecondary)
                        .lineLimit(typeSize.isAccessibilitySize ? 4 : 2)
                        .fixedSize(horizontal: false, vertical: true)
                    if let line = lastLine(stats) {
                        Label(line, systemImage: "clock.arrow.circlepath")
                            .font(look.font.footnote)
                            .foregroundStyle(look.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the template")

            TemplatesStartCapsule(subtitle: startSubtitle) {
                _ = store.startLifting(templateID: template.id)
            }
        }
        .padding(16)
        .lookSurface(.panel)
    }

    private func exerciseLine(_ names: [String]) -> String {
        if typeSize.isAccessibilitySize || names.count <= 3 { return names.joined(separator: " · ") }
        return names.prefix(3).joined(separator: " · ") + " · +\(names.count - 3)"
    }

    private func lastLine(_ stats: TemplateStats) -> String? {
        guard let last = stats.lastRun else { return nil }
        var parts = ["Last done \(look.lastDoneLabel(last, now: store.now))"]
        if let avg = stats.averageDurationSeconds { parts.append("about \(avg / 60) min") }
        return parts.joined(separator: " · ")
    }

    private var startSubtitle: String? {
        let gym = store.selectedGym?.name
        let count = template.items.isEmpty ? nil : Format.count(template.items.count, "exercise")
        let parts = [gym, count].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// The two other ways to start, one step quieter than the template's Start.
struct ProposedQuickStarts: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
        layout {
            Button { store.startLifting() } label: {
                Label("Start Lifting", systemImage: "figure.strengthtraining.traditional")
            }
            .buttonStyle(.lookSecondary)
            Button { router.present(.cardioPicker) } label: {
                Label("Start Cardio", systemImage: "figure.run")
            }
            .buttonStyle(.lookSecondary)
        }
    }
}
