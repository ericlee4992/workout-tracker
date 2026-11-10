import SwiftUI
import UIKit

// Nutrition N7 — Today's log while a meal photo or a description is estimated (D82) and after: the progress card (the
// blurred photo with a percent ring, "Analyzing image", skeleton lines, "We'll notify you when done!"), a failed scan's
// card, and the logged entry — one entry named for the meal (D83) with its photo thumbnail, time, macros and calories.

enum ScanCopy {
    static func time(_ date: Date) -> String { date.formatted(date: .omitted, time: .shortened) }

    /// "12:40 PM · P 36 · C 70 · F 14 g".
    static func detail(time: Date?, _ macros: Macros) -> String {
        let grams = { (value: Double) in value.formatted(.number.precision(.fractionLength(0))) }
        let parts = [time.map(Self.time),
                     "P \(grams(macros.proteinGrams)) · C \(grams(macros.carbsGrams)) · F \(grams(macros.fatGrams)) g"]
        return parts.compactMap(\.self).joined(separator: " · ")
    }
}

/// A scan in flight or failed, at the top of Today's log.
struct ScanPendingCard: View {
    var scan: FoodScanQueue.Pending
    var retake: () -> Void
    var retry: () -> Void
    var manualAdd: () -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var tile: CGFloat = 112

    private var analyzing: Bool { scan.failure == nil }

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
                if let failure = scan.failure { failed(failure) } else { analyzingText }
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
            if let image = scan.preview {
                Color.black.overlay {
                    Image(uiImage: image).resizable().scaledToFill()
                        .blur(radius: analyzing ? 7 : 0)
                        .saturation(analyzing ? 1 : 0)
                        .overlay(Color.black.opacity(analyzing ? 0.28 : 0.45))
                }
                .clipped()
            } else {
                // A description: no photo.
                look.surfaceRaised.overlay {
                    Image(systemName: "text.bubble.fill").font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(look.textTertiary.opacity(0.5))
                }
            }
            if analyzing {
                PercentRing(startedAt: scan.startedAt, onPhoto: scan.preview != nil)
            } else {
                let ink = scan.preview == nil ? look.textPrimary : Color.white
                Image(systemName: "exclamationmark")
                    .font(.system(.title3, weight: .heavy))
                    .foregroundStyle(ink)
                    .frame(width: 46, height: 46)
                    .background(.black.opacity(scan.preview == nil ? 0 : 0.4), in: Circle())
                    .overlay { Circle().strokeBorder(ink.opacity(0.7), lineWidth: 2) }
                    .accessibilityHidden(true)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: Analysing

    private var analyzingText: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(scan.text == nil ? "Analyzing image" : "Analyzing description")
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

    private func failed(_ failure: FoodScanQueue.Failure) -> some View {
        let describe = scan.text != nil
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(FoodScanCopy.failureTitle(failure, describe: describe))
                    .font(look.font.headline)
                    .foregroundStyle(look.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button { withAnimation(.snappy) { FoodScanQueue.shared.dismiss(scan.id) } } label: {
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
            Text(FoodScanCopy.failureDetail(failure, describe: describe))
                .font(look.font.footnote)
                .foregroundStyle(look.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            WrapLayout(spacing: 8, lineSpacing: 8) {
                switch failure {
                case .nothingFound:
                    if !describe { small("Retake", symbol: "camera", id: "scanRetake", action: retake) }
                    small("Manual Add", symbol: "square.and.pencil", id: "scanManualAdd", action: manualAdd)
                case .limit:
                    small("Manual Add", symbol: "square.and.pencil", id: "scanManualAdd", action: manualAdd)
                case .offline, .other:
                    small("Try again", symbol: "arrow.clockwise", id: "scanTryAgain", action: retry)
                }
            }
            .padding(.top, 2)
        }
        .accessibilityIdentifier("scanFailed")
    }

    private func small(_ title: String, symbol: String, id: String, action: @escaping () -> Void) -> some View {
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
        .accessibilityIdentifier(id)
    }
}

/// The percent: the server reports none, so it rises over the typical ~5 s, slows near the end, and stops short of 100
/// until the estimate arrives (then the card becomes the entry) — D82.
private struct PercentRing: View {
    var startedAt: Date
    var onPhoto: Bool
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func percent(at date: Date) -> Int {
        let t = max(0, date.timeIntervalSince(startedAt))
        return min(95, Int((1 - exp(-t / 2.2)) * 100))
    }

    var body: some View {
        TimelineView(.periodic(from: startedAt, by: 0.1)) { timeline in
            let value = percent(at: timeline.date)
            let ink = onPhoto ? Color.white : look.textPrimary
            ZStack {
                Circle().stroke(ink.opacity(0.28), lineWidth: 5)
                Circle().trim(from: 0, to: Double(value) / 100)
                    .stroke(ink, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .linear(duration: 0.1), value: value)
                // Inside a fixed ring: capped, so it never truncates at large text sizes.
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

// MARK: - A logged scan

/// A scanned meal's photo, small and rounded; decoded once per entry (the stored JPEG is up to 1568 px).
struct ScanThumbnail: View {
    var entry: FoodEntry
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 56
    @Environment(\.look) private var look

    var body: some View {
        if let image = ScanThumbnailCache.image(for: entry) {
            Color.black.overlay { Image(uiImage: image).resizable().scaledToFill() }
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: look.radius.row, style: .continuous))
                .accessibilityHidden(true)
        }
    }
}

@MainActor
enum ScanThumbnailCache {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(for entry: FoodEntry) -> UIImage? {
        guard let data = entry.photo else { return nil }
        let key = "\(entry.id.uuidString)-\(data.count)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let image = UIImage(data: data)?.preparingThumbnail(of: CGSize(width: 240, height: 240)) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}

/// A scanned meal or a description in its meal: the thumbnail (a photo), the name, time and macros, its calories.
struct ScanEntryRow: View {
    var entry: FoodEntry
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let totals = NutritionMath.totals(of: entry)
        HStack(alignment: typeSize.isAccessibilitySize ? .top : .center, spacing: 12) {
            ScanThumbnail(entry: entry)
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(spacing: 12))
            layout {
                VStack(alignment: .leading, spacing: 3) {
                    Text(TodayFoodCopy.name(of: entry)).font(look.font.body.weight(.semibold))
                        .foregroundStyle(look.textPrimary)
                    Text(ScanCopy.detail(time: entry.loggedAt, totals)).font(look.font.footnote)
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

extension FoodEntry {
    /// A scanned meal or a description (N7): opened on the items screen, shown with its thumbnail.
    var isScan: Bool { photo != nil || !(items ?? []).isEmpty }
}
