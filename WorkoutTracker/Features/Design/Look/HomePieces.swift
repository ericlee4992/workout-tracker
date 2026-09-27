import SwiftUI

// Home pieces every look draws differently: the gym picker and the template tile.
// They take plain values (never the Store).

// MARK: - Gym picker

/// The Home gym picker: pin disc · gym name · city · unit tag · ⌃⌄.
/// A: a full-width row. B: a content-hugging capsule. C: a full-width pressable card with
/// the city under the name. AX sizes (every SPEC): the city and the unit move under the name.
struct GymPickerButton: View {
    var name: String
    var city: String?
    var unit: WeightUnit?
    var action: () -> Void = {}
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var disc: CGFloat = 36
    @ScaledMetric(relativeTo: .body) private var minHeight: CGFloat = 56

    /// `name == nil`-style empty states belong to the screen; pass the gym's name and city.
    init(name: String, city: String? = nil, unit: WeightUnit? = nil, action: @escaping () -> Void = {}) {
        self.name = name
        self.city = city
        self.unit = unit
        self.action = action
    }

    private var stacked: Bool { typeSize.isAccessibilitySize }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                IconDisc(symbol: look.gymSymbol, size: disc, context: .onSurface)
                    .background { if look.id == .floodlight { Circle().fill(look.surfaceRaised) } }
                if stacked {
                    VStack(alignment: .leading, spacing: 4) {
                        nameText
                        HStack(spacing: 8) {
                            if let city { cityText(city) }
                            unitTag
                            chevron
                        }
                    }
                    Spacer(minLength: 0)
                } else if look.id.isPaperClub {
                    VStack(alignment: .leading, spacing: 0) {
                        nameText
                        if let city { cityText(city) }
                    }
                    Spacer(minLength: 8)
                    unitTag
                    chevron
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        nameText
                        if let city { cityText(city) }
                    }
                    if look.id == .floodlight { Spacer(minLength: 8) }
                    unitTag
                    chevron
                }
            }
            .foregroundStyle(look.textPrimary)
            .padding(.leading, 10)
            .padding(.trailing, 12)
            .padding(.vertical, 8)
            .frame(minHeight: minHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lookSurface(.tile, radius: radius)
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
        .buttonStyle(.lookPressable)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([name, city, unit?.label].compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(.isButton)
    }

    private var radius: CGFloat {
        switch look.id {
        case .floodlight: 14
        case .paper, .carbon: 16
        }
    }

    private var nameText: some View {
        Text(name)
            .font(.system(.body, weight: look.id.isPaperClub ? .bold : .semibold))
            .foregroundStyle(look.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func cityText(_ city: String) -> some View {
        Text(city)
            .font(look.id.isPaperClub ? look.font.footnote : look.font.subhead)
            .foregroundStyle(look.textSecondary)
            .lineLimit(1)
    }

    @ViewBuilder private var unitTag: some View {
        if let unit {
            Text(unit.label)
                .font(.system(.subheadline, weight: .bold))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background {
                    switch look.id {
                    case .floodlight: EmptyView()
                    case .paper, .carbon: RoundedRectangle(cornerRadius: 6).fill(look.surface)
                    }
                }
                .overlay { if look.id.isPaperClub { RoundedRectangle(cornerRadius: 6).strokeBorder(look.outline, lineWidth: 1.5) } }
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.up.chevron.down")
            .font(.system(.footnote, weight: .semibold))
            .foregroundStyle(look.textSecondary)
    }
}

// MARK: - Template tile

/// A template tile for the two-column grid (no long-press). Put tiles in a `Grid` so a row's
/// tiles share one height (the tile fills it, top-aligned).
/// A: maps, name, last-done line, then up to four exercise lines ("+ N more").
/// B: maps, name, two exercises, then "+N more" leading and the last-done date trailing.
/// C: a washed family band over a rule, name in New York, two exercises + "+N more", last done.
/// `lastDone` is worded per look by `look.lastDoneLabel` (A "Sep 23", B "Wed", C "Yesterday").
struct TemplateTile: View {
    var name: String
    var families: [MuscleFamily]
    var exercises: [String]
    var lastDone: Date?
    var now: Date
    var action: () -> Void = {}
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    init(name: String, families: [MuscleFamily], exercises: [String], lastDone: Date?, now: Date,
         action: @escaping () -> Void = {}) {
        self.name = name
        self.families = families
        self.exercises = exercises
        self.lastDone = lastDone
        self.now = now
        self.action = action
    }

    /// Names shown before "+N more". AX sizes list every exercise (A SPEC §9).
    private var shown: [String] {
        if typeSize.isAccessibilitySize { return exercises }
        let limit = look.id == .floodlight ? 4 : 3
        if exercises.count <= limit { return exercises }
        return Array(exercises.prefix(limit - 1))
    }
    private var more: Int { exercises.count - shown.count }
    private var moreText: String? {
        guard more > 0 else { return nil }
        return look.id == .floodlight ? "+ \(more) more" : "+\(more) more"
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                if look.id.isPaperClub {
                    FamilyBand(families: families, height: typeSize.isAccessibilitySize ? 96 : 76)
                    Rectangle().fill(look.outline).frame(height: look.stroke.pressable)
                }
                content
                    .padding(14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: look.radius.tile, style: .continuous))
            .lookSurface(.tile)
            .contentShape(RoundedRectangle(cornerRadius: look.radius.tile, style: .continuous))
        }
        .buttonStyle(.lookPressable)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder private var content: some View {
        switch look.id {
        case .floodlight:
            VStack(alignment: .leading, spacing: 0) {
                FamilyStrip(families: families, size: 30)
                Text(name).font(look.font.tileTitle).foregroundStyle(look.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
                if let lastDone { lastDoneLine(lastDone).padding(.top, 4) }
                exerciseLines.padding(.top, 12)
            }
        case .paper, .carbon:
            VStack(alignment: .leading, spacing: 0) {
                Text(name).font(look.font.tileTitle).foregroundStyle(look.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                exerciseLines.padding(.top, 6)
                Spacer(minLength: 10)
                if let lastDone { lastDoneLine(lastDone) }
            }
        }
    }

    private var exerciseLines: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(Array(shown.enumerated()), id: \.offset) { _, line in
                Text(line).lineLimit(typeSize.isAccessibilitySize ? nil : 1)
            }
            if let moreText {
                Text(moreText).foregroundStyle(look.id == .floodlight ? look.textTertiary : look.textSecondary)
            }
        }
        .font(look.font.footnote)
        .foregroundStyle(look.textSecondary)
    }

    private func lastDoneLine(_ date: Date) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.arrow.circlepath")
            Text(look.lastDoneLabel(date, now: now))
        }
        .font(.system(.caption, weight: .semibold))
        .foregroundStyle(look.id == .floodlight ? look.textTertiary : (look.id.isPaperClub ? look.textPrimary : look.textSecondary))
    }

    private var accessibilityText: String {
        var parts = [name, exercises.joined(separator: ", ")]
        if let lastDone { parts.append("Last done \(look.lastDoneLabel(lastDone, now: now))") }
        return parts.joined(separator: ". ")
    }
}
