import CoreGraphics

/// Scanner accuracy, ticket 05 — which pixels leave the phone when the user
/// taps Ask AI: the framing box, not the frame (D53).
///
/// Pure geometry, so the crop the request carries is pinned by a unit test:
/// Vision's region (normalised, bottom-left origin, in the upright photo) →
/// a pixel rectangle (top-left origin) in that photo, with a small margin
/// so a plate whose edge sits on the box line is not sliced, clamped to the
/// photo. The whole photo only when there was no box — the library path,
/// where the user chose the photo themselves.
enum LabelCrop {
    /// Margin added on each side, as a fraction of the box's own size.
    static let margin: CGFloat = 0.08
    /// The experiment resized to 1568 px on the long side (≈ 2,900 input
    /// tokens a plate); the app sends the same.
    static let maxSide: CGFloat = 1568

    static func pixelRect(region: CGRect?, imageSize: CGSize) -> CGRect {
        let whole = CGRect(origin: .zero, size: imageSize)
        guard let region, imageSize.width > 0, imageSize.height > 0,
              region.width > 0, region.height > 0
        else { return whole }
        let width = region.width * imageSize.width
        let height = region.height * imageSize.height
        let inset = CGSize(width: width * margin, height: height * margin)
        let box = CGRect(
            x: region.minX * imageSize.width - inset.width,
            y: (1 - region.maxY) * imageSize.height - inset.height,
            width: width + 2 * inset.width,
            height: height + 2 * inset.height)
        let clamped = box.intersection(whole).integral
        guard !clamped.isNull, clamped.width >= 1, clamped.height >= 1 else { return whole }
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
