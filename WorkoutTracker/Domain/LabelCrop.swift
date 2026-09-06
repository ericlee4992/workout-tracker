import CoreGraphics

/// Scanner accuracy, ticket 05 — which pixels leave the phone when the user
/// taps Ask AI: the framing box, not the frame (D53).
///
/// Pure geometry, so the crop the request carries is pinned by a unit test:
/// Vision's region (normalised, bottom-left origin, in the upright photo) →
/// a pixel rectangle (top-left origin) in that photo, with a small margin
/// so a plate whose edge sits on the box line is not sliced, clamped to the
/// photo. **Fails closed**: no box, or a degenerate one, is `nil` — and then
/// there is nothing to send and no Ask AI. The whole photo never leaves the
/// phone, not from the shutter and not from the library, where there is no
/// box at all (codex-review-05, high).
enum LabelCrop {
    /// Margin added on each side, as a fraction of the box's own size.
    static let margin: CGFloat = 0.08
    /// The experiment resized to 1568 px on the long side (≈ 2,900 input
    /// tokens a plate); the app sends the same.
    static let maxSide: CGFloat = 1568
    /// A crop may cover at most this share of the photo's area: a "box" that
    /// keeps less than a tenth of the photo out is the frame for practical
    /// purposes (codex-review-05c). The real box is far below this — on a
    /// portrait phone it spans well under half the photo — and the fixture
    /// plate is ~67 % of its canvas with the margin.
    static let maximumAreaShare: CGFloat = 0.9

    static func pixelRect(region: CGRect, imageSize: CGSize) -> CGRect? {
        let whole = CGRect(origin: .zero, size: imageSize)
        guard imageSize.width > 0, imageSize.height > 0,
              region.width > 0, region.height > 0,
              // The whole photo is not a box (a `visionRegion` fallback for
              // a degenerate view reads everything; it must not SEND everything).
              !(region.minX <= 0 && region.minY <= 0 && region.maxX >= 1 && region.maxY >= 1)
        else { return nil }
        let width = region.width * imageSize.width
        let height = region.height * imageSize.height
        let inset = CGSize(width: width * margin, height: height * margin)
        let box = CGRect(
            x: region.minX * imageSize.width - inset.width,
            y: (1 - region.maxY) * imageSize.height - inset.height,
            width: width + 2 * inset.width,
            height: height + 2 * inset.height)
        let clamped = box.intersection(whole).integral
        guard !clamped.isNull, clamped.width >= 1, clamped.height >= 1,
              // A box that the margin turns into (nearly) the frame is the
              // frame (codex-review-05b/05c): a tenth of the photo must stay out.
              clamped.width * clamped.height <= imageSize.width * imageSize.height * maximumAreaShare
        else { return nil }
        return clamped
    }

    /// The factor that brings the longer side down to `maxSide`; never
    /// upscales.
    static func scale(for size: CGSize) -> CGFloat {
        let longest = max(size.width, size.height)
        guard longest > maxSide, longest > 0 else { return 1 }
        return maxSide / longest
    }
}
