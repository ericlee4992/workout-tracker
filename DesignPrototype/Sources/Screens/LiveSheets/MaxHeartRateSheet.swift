import SwiftUI

// PROTOTYPE — L12 Heart Rate (zones setup). Two tiles are the two sources of a maximum: the
// measured maximum (a field you type into) and the one from your age (220 − age, from the date
// of birth row under the tiles). The tile in use is lit; tapping a tile picks it, typing picks
// Measured. There is no separate switch, so the controls can never disagree. Below, the zone
// ladder on the heart-rate plate (C: the ink slab): Zone 5 at the top, each rung its bpm range
// and its step on one shared scale, with your heart rate right now pinned above its rung.
// Everything moves as you type. Save: a measured maximum is only removed after a confirmation
// (the Store's rule is "a measured value wins", so keeping it would override the age).
// Variants: "ageBased" (the age in use, measured empty), "none" (no maximum, no date of birth).

enum LiveSheetsMaxSource: Hashable { case measured, age }

struct MaxHeartRateSheet: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var environmentTypeSize
    /// The sheet root sits outside its own `.dynamicTypeSize` override, so it resolves the
    /// prototype override itself (children read the environment as usual).
    private var typeSize: DynamicTypeSize { router.dynamicTypeOverride ?? environmentTypeSize }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var measuredText = ""
    @State private var hasBirthDate = false
    @State private var birthDate = SampleData.date(1990, 1, 1)
    @State private var source: LiveSheetsMaxSource = .measured
    @State private var confirmsRemoval = false
    @State private var loaded = false
    @State private var page: Int?
    @FocusState private var measuredFocused: Bool

    private var measured: Int? { Int(measuredText).flatMap { $0 > 0 ? $0 : nil } }
    private var ageBased: Int? {
        guard hasBirthDate, let age = Calendar.app.dateComponents([.year], from: birthDate, to: store.now).year else { return nil }
        return 220 - age
    }
    /// The source the zones use: the one picked when it has a value, else the other one.
    private var inUse: LiveSheetsMaxSource? {
        switch source {
        case .measured: measured != nil ? .measured : (ageBased != nil ? .age : nil)
        case .age: ageBased != nil ? .age : (measured != nil ? .measured : nil)
        }
    }
    private var resolved: Int? {
        switch inUse {
        case .measured: measured
        case .age: ageBased
        case nil: nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            LiveSheetsHeader(title: "Heart Rate",
                             leading: .cancel { router.dismissSheet() },
                             trailing: .commit("Save", enabled: true, action: save))
            LiveSheetsScroll(page: page) {
                VStack(alignment: .leading, spacing: 18) {
                    sourceTiles
                    birthDateRow
                    ladder
                        .padding(.top, 6)
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 8)
                .padding(.bottom, 48)
            }
        }
        .liveSheetsPresentation(look)
        .presentationDetents([.large])
        .sensoryFeedback(.selection, trigger: inUse)
        .confirmationDialog(ageBased.map { "Use \($0) bpm from your age?" } ?? "", isPresented: $confirmsRemoval,
                            titleVisibility: .visible) {
            Button(ageBased.map { "Use \($0) bpm" } ?? "Save", role: .destructive, action: commit)
            Button("Cancel", role: .cancel) {}
        } message: {
            if let saved = measured {
                Text("Your measured \(saved) bpm will be removed.")
            }
        }
        .onAppear(perform: load)
    }

    // MARK: Source tiles

    @ViewBuilder private var sourceTiles: some View {
        if typeSize.isAccessibilitySize {
            VStack(spacing: 12) { measuredTile; ageTile }
        } else {
            HStack(alignment: .top, spacing: 12) { measuredTile; ageTile }
        }
    }

    private var measuredTile: some View {
        let selected = inUse == .measured
        let empty = measuredText.isEmpty
        return VStack(alignment: .leading, spacing: 10) {
            tileHeader("Measured maximum", selected: selected)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                TextField("Measured maximum", text: $measuredText, prompt: Text(""))
                    .keyboardType(.numberPad)
                    .focused($measuredFocused)
                    .font(empty ? look.font.statNumber : look.font.heroNumber)
                    .foregroundStyle(look.liveSheetsChoiceText(selected))
                    .tint(selected && look.id.isPaperClub ? look.onAction : look.actionText)
                    .frame(minWidth: empty ? 6 : nil)
                    .fixedSize()
                    .onChange(of: measuredText) { _, text in
                        let digits = String(text.filter(\.isNumber).prefix(3))
                        if digits != text { measuredText = digits }
                        // Typing a value makes it the one in use.
                        if !digits.isEmpty && measuredFocused { choose(.measured) }
                    }
                Text("bpm").font(unitFont).foregroundStyle(look.liveSheetsChoiceSecondary(selected))
                Spacer(minLength: 4)
                Image(systemName: "pencil")
                    .font(.system(.footnote, weight: .bold))
                    .foregroundStyle(look.liveSheetsChoiceSecondary(selected))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, empty ? 12 : 0)
            .padding(.vertical, empty ? 9 : 0)
            .overlay {
                if empty {
                    RoundedRectangle(cornerRadius: look.radius.field, style: .continuous)
                        .strokeBorder(measuredFocused ? look.liveSheetsChoiceText(selected) : look.liveSheetsChoiceSecondary(selected),
                                      style: StrokeStyle(lineWidth: 1.5, dash: measuredFocused ? [] : [5, 4]))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
        .liveSheetsChoiceSurface(isSelected: selected)
        .contentShape(Rectangle())
        .onTapGesture {
            choose(.measured)
            measuredFocused = true
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var ageTile: some View {
        let selected = inUse == .age
        return Button {
            if !hasBirthDate { hasBirthDate = true }
            measuredFocused = false
            choose(.age)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                tileHeader("From age", selected: selected)
                if let ageBased {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(ageBased)")
                            .font(look.font.heroNumber)
                            .foregroundStyle(look.liveSheetsChoiceText(selected))
                            .contentTransition(.numericText(value: Double(ageBased)))
                        Text("bpm").font(unitFont).foregroundStyle(look.liveSheetsChoiceSecondary(selected))
                    }
                } else {
                    // The same empty well as the measured tile ("bpm" and its edit cue), so
                    // "Date of birth" is named once, on the row below.
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("bpm").font(unitFont)
                        Spacer(minLength: 4)
                        Image(systemName: "calendar.badge.plus").font(.system(.footnote, weight: .bold))
                    }
                    .foregroundStyle(look.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .accessibilityLabel("Add date of birth")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay {
                        RoundedRectangle(cornerRadius: look.radius.field, style: .continuous)
                            .strokeBorder(look.textSecondary, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
            .liveSheetsChoiceSurface(isSelected: selected)
            .contentShape(Rectangle())
        }
        .buttonStyle(.lookPressable)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func tileHeader(_ title: String, selected: Bool) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(title)
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(look.liveSheetsChoiceSecondary(selected))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(look.liveSheetsChoiceText(true))
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            }
        }
    }

    private var unitFont: Font {
        .system(.subheadline, design: look.id == .anatomy ? .rounded : .default, weight: .semibold)
    }

    // MARK: Date of birth

    private var birthDateRow: some View {
        // At accessibility sizes the label sits over the date instead of wrapping beside it.
        let layout = typeSize.isAccessibilitySize && hasBirthDate
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 10))
        return LookList {
            layout {
                Text("Date of birth")
                    .font(.system(.body, weight: .medium))
                    .foregroundStyle(look.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, typeSize.isAccessibilitySize && hasBirthDate ? 10 : 0)
                Spacer(minLength: 8)
                if hasBirthDate {
                  HStack(spacing: 10) {
                    DatePicker("Date of birth", selection: $birthDate, in: ...store.now, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .tint(look.actionText)
                    Button {
                        let apply = { hasBirthDate = false }
                        if reduceMotion { apply() } else { withAnimation(.snappy) { apply() } }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(look.textTertiary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove date of birth")
                  }
                } else {
                    Button {
                        let apply = { hasBirthDate = true; choose(.age) }
                        if reduceMotion { apply() } else { withAnimation(.snappy) { apply() } }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(look.id.isPaperClub ? look.textPrimary : look.textSecondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add date of birth")
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, 6)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        }
    }

    // MARK: Zone ladder

    private var ladder: some View {
        let bpm = store.currentBPM
        return HeartRatePlate(title: "Zones") {
            VStack(spacing: 14) {
                if let max = resolved {
                    let current = bpm.flatMap { Derived.zone(bpm: $0, max: max) }
                    ForEach(Array(Derived.zoneRows(max: max).reversed())) { row in
                        LiveSheetsZoneRung(row: row, max: max, currentBpm: row.zone == current ? bpm : nil)
                    }
                } else {
                    ForEach(Array(HeartRateZone.allCases.reversed())) { zone in
                        LiveSheetsZoneRung(zone: zone)
                    }
                }
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.35), value: resolved)
    }

    // MARK: Actions

    private func choose(_ next: LiveSheetsMaxSource) {
        guard next != source else { return }
        if reduceMotion { source = next } else { withAnimation(.snappy(duration: 0.25)) { source = next } }
    }

    /// Picking the age while a measured maximum exists would delete it (a measured value always
    /// wins in the Store), so that one case asks first.
    private func save() {
        if inUse == .age, measured != nil {
            confirmsRemoval = true
        } else {
            commit()
        }
    }

    private func commit() {
        store.settings.measuredMaxHeartRate = inUse == .age ? nil : measured
        store.settings.birthDate = hasBirthDate ? birthDate : nil
        router.dismissSheet()
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        let variant = LiveSheetsVariant.consume([.l12], store: store, router: router)
        page = LiveSheetsVariant.page(variant)
        measuredText = store.settings.measuredMaxHeartRate.map(String.init) ?? ""
        hasBirthDate = store.settings.birthDate != nil
        birthDate = store.settings.birthDate ?? SampleData.date(1990, 1, 1)
        source = store.settings.measuredMaxHeartRate != nil ? .measured : .age
        if LiveSheetsVariant.has(variant, "ageBased") {
            measuredText = ""
            hasBirthDate = true
            source = .age
        }
        if LiveSheetsVariant.has(variant, "none") {
            measuredText = ""
            hasBirthDate = false
            source = .measured
        }
    }
}

// MARK: - Zone rung

/// One rung: the zone's name and range, and its step on a shared bpm scale (lower → upper).
/// Your heart rate right now is a pin above its rung (a beating heart and the number on a
/// small stem), so the zone's own segment stays visible. Without a maximum the rung has no
/// range and its track is a dashed outline.
struct LiveSheetsZoneRung: View {
    var zone: HeartRateZone
    var row: ZoneRow?
    var max: Int?
    var currentBpm: Int?
    @Environment(\.look) private var look
    @Environment(\.lookOnSlab) private var onSlab
    @Environment(\.dynamicTypeSize) private var typeSize

    init(row: ZoneRow, max: Int, currentBpm: Int?) {
        zone = row.zone
        self.row = row
        self.max = max
        self.currentBpm = currentBpm
    }

    init(zone: HeartRateZone) {
        self.zone = zone
    }

    private var primary: Color { onSlab ? look.onSlab : look.textPrimary }
    private var secondary: Color { onSlab ? look.onSlabSecondary : look.textSecondary }
    private let pinHeight: CGFloat = 30

    private var rangeText: String? {
        guard let row else { return nil }
        switch (row.zone, row.upperBound) {
        case (.warm, let upper?): return "< \(upper)"
        case (_, let upper?): return "\(row.lowerBound)–\(upper - 1)"
        case (_, nil): return "\(row.lowerBound)+"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            let name = HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(zone.label)
                    .font(.system(.subheadline, design: look.id == .anatomy ? .rounded : .default, weight: .bold))
                    .foregroundStyle(row == nil ? secondary : primary)
                Text(zone.descriptionText)
                    .font(look.font.caption)
                    .foregroundStyle(secondary)
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
            }
            let range = HStack(alignment: .firstTextBaseline, spacing: 3) {
                if let rangeText {
                    Text(rangeText)
                        .font(look.id == .anatomy ? .system(.headline, design: .rounded, weight: .heavy).monospacedDigit()
                              : Font.system(.headline, weight: .heavy).width(.expanded).monospacedDigit())
                        .foregroundStyle(primary)
                        .contentTransition(.numericText())
                    Text("bpm").font(.system(.caption, weight: .semibold)).foregroundStyle(secondary)
                }
            }
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 2) { name; range }
            } else {
                HStack(alignment: .firstTextBaseline) { name; Spacer(minLength: 8); range }
            }
            track
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([zone.label, rangeText.map { "\($0) bpm" }, currentBpm.map { "now \($0) bpm" }]
            .compactMap { $0 }.joined(separator: ", "))
    }

    @ViewBuilder private var track: some View {
        if let row, let max {
            GeometryReader { geo in
                // One shared scale from 45 % of max to max: each zone is its own step of the
                // ladder (lower → upper), so the rungs climb to the right toward Zone 5.
                let lo = Double(max) * 0.45
                let span = Double(max) - lo
                let x = { (bpm: Double) in geo.size.width * CGFloat(Swift.min(1, Swift.max(0, (bpm - lo) / span))) }
                let start = x(Double(row.lowerBound))
                let end = x(Double(row.upperBound ?? max))
                let top: CGFloat = currentBpm == nil ? 0 : pinHeight
                ZStack(alignment: .topLeading) {
                    Capsule().fill(onSlab ? look.onSlab.opacity(0.10) : look.hairline)
                        .frame(width: geo.size.width, height: 8)
                        .offset(y: top)
                    Capsule().fill(look.zone(row.zone))
                        .frame(width: Swift.max(8, end - start), height: 8)
                        .offset(x: start, y: top)
                    if let currentBpm {
                        let px = x(Double(currentBpm))
                        // The stem runs from the pin down onto the track at the exact bpm.
                        Rectangle().fill(look.heartRate)
                            .frame(width: 2, height: 10)
                            .position(x: px, y: pinHeight - 5)
                        Circle().fill(look.heartRate)
                            .overlay { Circle().strokeBorder(onSlab ? look.slab : look.surfaceSheet, lineWidth: 2) }
                            .frame(width: 12, height: 12)
                            .position(x: px, y: top + 4)
                        HStack(spacing: 4) {
                            BeatingHeart(bpm: currentBpm, isFresh: true, font: .system(.caption, weight: .bold))
                            Text("\(currentBpm)")
                                .font(.system(.caption, weight: .heavy).monospacedDigit())
                                .foregroundStyle(primary)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(onSlab ? look.slab : (look.id == .anatomy ? look.surfaceSheet : look.surface)))
                        .overlay(Capsule().strokeBorder(look.heartRate, lineWidth: 1.5))
                        .fixedSize()
                        .position(x: Swift.min(geo.size.width - 30, Swift.max(30, px)), y: 10)
                    }
                }
            }
            .frame(height: currentBpm == nil ? 8 : pinHeight + 8)
        } else {
            Capsule()
                .strokeBorder(secondary.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .frame(height: 8)
        }
    }
}
