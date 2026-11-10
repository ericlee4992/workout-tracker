import SwiftUI

// Nutrition N7 (MOCK) — Today's log while a meal photo is analysed (D82) and after: the progress card (the blurred photo
// with a percent ring, "Analyzing image", skeleton lines, "We'll notify you when done!"), a failed scan's card, and the
// logged photo entry — as one entry named for the meal, or as one entry per item under the photo (both mocked; open).

enum ScanCopy {
    static func time(_ date: Date) -> String { date.formatted(date: .omitted, time: .shortened) }

    /// "12:40 PM · P 36 · C 70 · F 14 g".
    static func detail(time: Date?, _ macros: Macros) -> String {
        let grams = { (value: Double) in value.formatted(.number.precision(.fractionLength(0))) }
        let parts = [time.map(Self.time),
                     "P \(grams(macros.proteinGrams)) · C \(grams(macros.carbsGrams)) · F \(grams(macros.fatGrams)) g"]
        return parts.compactMap(\.self).joined(separator: " · ")
    }

    static func failureTitle(_ failure: ScanMockFailure) -> String {
        switch failure {
        case .nothingFound: "No food found"
        case .dailyLimit: "Daily limit reached"
        case .offline: "Couldn't analyze"
        }
    }

    static func failureDetail(_ failure: ScanMockFailure) -> String {
        switch failure {
        case .nothingFound: "Try a closer photo, or add it by hand."
        case .dailyLimit: "30 meal photos a day. More at 7:00 PM."
        case .offline: "No connection. Your photo is kept until you try again."
        }
    }
}

/// A scan in flight or failed, at the top of Today's log.
struct ScanPendingCard: View {
    var scan: ScanMockPending
    var retake: () -> Void
    var manualAdd: () -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var tile: CGFloat = 112

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0)) : AnyLayout(HStackLayout(alignment: .center, spacing: 0))
        layout {
            // One frame decides the photo's size (two nested ones let the photo spill past its dimming).
            photo
                .frame(width: typeSize.isAccessibilitySize ? nil : tile)
                .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : nil)
                .frame(height: typeSize.isAccessibilitySize ? 180 : nil)
                .frame(minHeight: typeSize.isAccessibilitySize ? nil : tile,
                       maxHeight: typeSize.isAccessibilitySize ? nil : .infinity)
                .clipped()
            Group {
                switch scan.state {
                case .analyzing: analyzing
                case .failed(let failure): failed(failure)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .lookSurface(.panel)
        .clipShape(RoundedRectangle(cornerRadius: look.radius.panel, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("scanPending")
    }

    // MARK: The photo with its ring

    private var photo: some View {
        ZStack {
            if let image = scan.image {
                Color.black.overlay {
                    Image(uiImage: image).resizable().scaledToFill()
                        .blur(radius: scan.state == .analyzing ? 7 : 0)
                        .saturation(scan.state == .analyzing ? 1 : 0)
                        .overlay(Color.black.opacity(scan.state == .analyzing ? 0.28 : 0.45))
                }
                .clipped()
            } else {
                // A description: no photo.
                look.surfaceRaised.overlay {
                    Image(systemName: "text.bubble.fill").font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(look.textTertiary.opacity(0.5))
                }
            }
            switch scan.state {
            case .analyzing: PercentRing(scan: scan, onPhoto: scan.image != nil)
            case .failed:
                Image(systemName: "exclamationmark")
                    .font(.system(.title3, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(.black.opacity(0.4), in: Circle())
                    .overlay { Circle().strokeBorder(.white.opacity(0.7), lineWidth: 2) }
                    .accessibilityHidden(true)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: Analysing

    private var analyzing: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(scan.image == nil ? "Analyzing description" : "Analyzing image")
                .font(look.font.headline)
                .foregroundStyle(look.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            SkeletonLines()
            Text("We'll notify you when done!")
                .font(look.font.footnote)
                .foregroundStyle(look.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Failed

    private func failed(_ failure: ScanMockFailure) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(ScanCopy.failureTitle(failure))
                    .font(look.font.headline)
                    .foregroundStyle(look.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button { FoodScanMock.shared.dismiss(scan.id) } label: {
                    Image(systemName: "xmark").font(.system(.footnote, weight: .bold))
                        .foregroundStyle(look.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, -14)
                .padding(.trailing, -12)
                .accessibilityLabel("Remove")
                .accessibilityIdentifier("scanPendingRemove")
            }
            Text(ScanCopy.failureDetail(failure))
                .font(look.font.footnote)
                .foregroundStyle(look.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            WrapLayout(spacing: 8, lineSpacing: 8) {
                switch failure {
                case .nothingFound:
                    small("Retake", symbol: "camera", action: retake)
                    small("Manual Add", symbol: "square.and.pencil", action: manualAdd)
                case .dailyLimit:
                    small("Manual Add", symbol: "square.and.pencil", action: manualAdd)
                case .offline:
                    small("Try again", symbol: "arrow.clockwise") { FoodScanMock.shared.retry(scan.id) }
                }
            }
            .padding(.top, 2)
        }
        .accessibilityIdentifier("scanFailed.\(failure.rawValue)")
    }

    private func small(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(look.textPrimary)
                .padding(.horizontal, 14)
                .frame(minHeight: 40)
                .background(look.surfaceRaised, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.lookPressable)
        .frame(minHeight: 44)
    }
}

/// The percent: the server reports none, so it rises over the typical ~5 s, slows near the end, and completes when the
/// answer arrives (D82).
private struct PercentRing: View {
    var scan: ScanMockPending
    var onPhoto: Bool
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func percent(at date: Date) -> Int {
        if let frozen = scan.frozenPercent { return frozen }
        let t = date.timeIntervalSince(scan.startedAt)
        return min(95, Int((1 - exp(-t / 2.2)) * 100))
    }

    var body: some View {
        TimelineView(.periodic(from: scan.startedAt, by: 0.1)) { timeline in
            let value = percent(at: timeline.date)
            let ink = onPhoto ? Color.white : look.textPrimary
            ZStack {
                Circle().stroke(ink.opacity(0.28), lineWidth: 5)
                Circle().trim(from: 0, to: Double(value) / 100)
                    .stroke(ink, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .linear(duration: 0.1), value: value)
                // Inside a fixed ring: capped, so "100%" never truncates at large text sizes.
                Text("\(value)%")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 8)
                    .dynamicTypeSize(...DynamicTypeSize.xLarge)
            }
            .frame(width: 66, height: 66)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(value) percent")
            .accessibilityIdentifier("scanPercent")
        }
    }
}

/// Placeholder lines where the name and numbers will appear; a soft shimmer (none under Reduce Motion).
private struct SkeletonLines: View {
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lit = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            bar.frame(width: 120)
            HStack(spacing: 6) { bar; bar; bar }
        }
        .frame(maxWidth: 220, alignment: .leading)
        .opacity(lit ? 0.55 : 1)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { lit = true }
        }
        .accessibilityHidden(true)
    }

    private var bar: some View { Capsule().fill(look.ringTrack).frame(height: 9) }
}

// MARK: - Logged photo entries

/// A small rounded photo; a description or label entry has none (nil → nothing drawn).
struct ScanThumbnail: View {
    var image: UIImage?
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 56
    @Environment(\.look) private var look

    var body: some View {
        if let image {
            Color.black.overlay { Image(uiImage: image).resizable().scaledToFill() }
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: look.radius.row, style: .continuous))
                .accessibilityHidden(true)
        }
    }
}

/// Option A — the photo is ONE entry named for the meal: thumbnail, name, time and macros, its calories trailing.
struct ScanEntryRow: View {
    var entry: ScanMockEntry
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let totals = entry.totals
        HStack(alignment: typeSize.isAccessibilitySize ? .top : .center, spacing: 12) {
            ScanThumbnail(image: entry.image)
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(spacing: 12))
            layout {
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.name).font(look.font.body.weight(.semibold)).foregroundStyle(look.textPrimary)
                    Text(ScanCopy.detail(time: entry.time, totals)).font(look.font.footnote)
                        .foregroundStyle(look.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text("\(TodayFoodCopy.calories(totals.calories)) cal")
                    .font(look.font.subhead.weight(.semibold)).monospacedDigit().foregroundStyle(look.textPrimary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

/// Option B — one entry PER ITEM under the photo: the photo's row (thumbnail, "Photo · 5 items", time, total), then each
/// item as its own entry, indented under it.
struct ScanPerItemGroup: View {
    var entry: ScanMockEntry
    var open: () -> Void
    var openItem: (ScanMockItem) -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: open) {
                HStack(spacing: 12) {
                    ScanThumbnail(image: entry.image)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Photo · \(entry.items.count) items").font(look.font.body.weight(.semibold))
                            .foregroundStyle(look.textPrimary)
                        Text("\(ScanCopy.time(entry.time)) · \(TodayFoodCopy.calories(entry.totals.calories)) cal")
                            .font(look.font.footnote).monospacedDigit().foregroundStyle(look.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right").font(.system(.footnote, weight: .semibold))
                        .foregroundStyle(look.textTertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.lookPressable)
            .accessibilityIdentifier("scanPhotoGroup")
            ForEach(entry.items) { item in
                Divider().overlay(look.hairline).padding(.leading, typeSize.isAccessibilitySize ? 32 : 84)
                Button { openItem(item) } label: { itemRow(item) }
                    .buttonStyle(.lookPressable)
                    .accessibilityIdentifier("scanItemEntry.\(item.name)")
            }
        }
    }

    private func itemRow(_ item: ScanMockItem) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name).font(look.font.body.weight(.semibold)).foregroundStyle(look.textPrimary)
                Text("\(item.portion) · \(ScanCopy.detail(time: nil, item.macros))").font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(TodayFoodCopy.calories(item.calories)) cal")
                .font(look.font.subhead.weight(.semibold)).monospacedDigit().foregroundStyle(look.textPrimary)
        }
        .padding(.leading, typeSize.isAccessibilitySize ? 32 : 84)
        .padding(.trailing, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

// MARK: - Mock switcher (the interactive prototype only)

/// A small floating control on Today in the mock: which option the photo entries show, how the next scan ends, and the
/// signed-out / camera-off / first-scan states. Never in the wired build.
struct ScanMockSwitcher: View {
    @State private var mock = FoodScanMock.shared
    @Environment(\.look) private var look

    var body: some View {
        Menu {
            Picker("Photo entries", selection: $mock.grouping) {
                ForEach(ScanMockGrouping.allCases) { Text($0.label).tag($0) }
            }
            Picker("Next scan", selection: $mock.nextFailure) {
                Text("Succeeds").tag(ScanMockFailure?.none)
                ForEach(ScanMockFailure.allCases) { Text($0.label).tag(Optional($0)) }
            }
            Toggle("Signed in", isOn: $mock.signedIn)
            Toggle("Camera allowed", isOn: $mock.cameraAllowed)
            Toggle("Photo consent given", isOn: $mock.consentGiven)
        } label: {
            Label("Mock", systemImage: "slider.horizontal.3")
                .font(.system(.footnote, weight: .bold))
                .foregroundStyle(Color.black)
                .padding(.horizontal, 10)
                .frame(minHeight: 30)
                .background(.yellow, in: Capsule())
                .dynamicTypeSize(...DynamicTypeSize.large)
        }
        .accessibilityIdentifier("scanMockSwitcher")
    }
}
