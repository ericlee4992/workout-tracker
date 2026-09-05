import CoreGraphics

/// Scanner accuracy, ticket 03 — where on the preview the plate goes, and how
/// that box becomes the region Vision reads.
///
/// The box is the whole reason the neighbouring machine's plate, the frame
/// badge and the wall signage stop entering the reading: only text inside it
/// is recognised. Pure geometry, so the overlay the user sees and the region
/// the camera reads are computed by the same function and cannot disagree.
enum LabelFramingBox {

    /// Share of the view's width the box spans.
    static let widthFraction: CGFloat = 0.88
    /// Plates are wide and short; ~2.6:1 fits a Hammer Strength placard, a
    /// Cybex serial plate and a Life Fitness nameplate without clipping.
    static let aspectRatio: CGFloat = 2.6
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

    /// A metadata-output rectangle (normalised, top-left origin, as
    /// `AVCaptureVideoPreviewLayer.metadataOutputRectConverted` returns) as
    /// Vision's `regionOfInterest` (normalised, BOTTOM-left origin), clamped
    /// to the image.
    static func visionRegion(fromMetadataRect rect: CGRect) -> CGRect {
        let clamped = rect.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard !clamped.isNull, clamped.width > 0, clamped.height > 0 else {
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        return CGRect(x: clamped.minX, y: 1 - clamped.maxY, width: clamped.width, height: clamped.height)
    }
}
