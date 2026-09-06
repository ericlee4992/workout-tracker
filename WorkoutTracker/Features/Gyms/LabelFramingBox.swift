import CoreGraphics

/// Scanner accuracy, ticket 03 — where on the preview the plate goes, and how
/// that box becomes the region Vision reads.
///
/// The box is the whole reason the neighbouring machine's plate, the frame
/// badge and the wall signage stop entering the reading: only text inside it
/// is recognised. Pure geometry, so the overlay the user sees and the region
/// the camera reads are computed by the same functions and cannot disagree.
///
/// The mapping from the box to the photo deliberately uses NOTHING from
/// AVFoundation's coordinate conversions. The first cut used
/// `metadataOutputRectConverted`, whose result is in the UNROTATED sensor
/// space — on a portrait phone the wide box became a tall strip
/// (codex-review-03). Instead: the photo is taken as the user saw it, the
/// preview fills the view with the photo's field (`resizeAspectFill`), so the
/// box maps into the UPRIGHT photo by aspect-fill arithmetic alone, which a
/// unit test can pin with numbers.
enum LabelFramingBox {

    /// Share of the view's width the box spans.
    static let widthFraction: CGFloat = 0.94
    /// Plates are wide and short; ~2.6:1 fits a Hammer Strength placard, a
    /// Cybex serial plate and a Life Fitness nameplate without clipping.
    static let aspectRatio: CGFloat = 2.0
    /// The box sits a little above centre: the thumb is at the bottom on the
    /// shutter, and a plate is usually at chest height while the phone tilts.
    static let verticalCentre: CGFloat = 0.42

    /// The box in the view's own coordinates (top-left origin).
    static func rect(in size: CGSize) -> CGRect {
        let width = min(size.width * widthFraction, size.height * aspectRatio * 0.9)
        let height = width / aspectRatio
        // Kept inside the view whatever its shape: on a very wide view the
        // above-centre placement would push the box past the top edge.
        let y = min(max(0, size.height * verticalCentre - height / 2), size.height - height)
        return CGRect(x: (size.width - width) / 2, y: y, width: width, height: height)
    }

    /// Vision's `regionOfInterest` (normalised, BOTTOM-left origin, in the
    /// upright photo) for `box` drawn on a view of `viewSize` that shows the
    /// upright photo of `imageSize` aspect-filled and centred — exactly what
    /// `AVCaptureVideoPreviewLayer` with `.resizeAspectFill` displays. Clamped
    /// to the photo; a degenerate input reads the whole photo rather than
    /// nothing.
    static func visionRegion(box: CGRect, viewSize: CGSize, imageSize: CGSize) -> CGRect {
        let whole = CGRect(x: 0, y: 0, width: 1, height: 1)
        guard viewSize.width > 0, viewSize.height > 0, imageSize.width > 0, imageSize.height > 0 else {
            return whole
        }
        // Aspect fill: the larger scale, then centred, so one axis overflows.
        let scale = max(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let shown = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let offset = CGPoint(x: (viewSize.width - shown.width) / 2, y: (viewSize.height - shown.height) / 2)
        // Box → upright photo, normalised, top-left origin.
        let topLeft = CGRect(
            x: (box.minX - offset.x) / shown.width,
            y: (box.minY - offset.y) / shown.height,
            width: box.width / shown.width,
            height: box.height / shown.height)
        let clamped = topLeft.intersection(whole)
        guard !clamped.isNull, clamped.width > 0, clamped.height > 0 else { return whole }
        return CGRect(x: clamped.minX, y: 1 - clamped.maxY, width: clamped.width, height: clamped.height)
    }
}
