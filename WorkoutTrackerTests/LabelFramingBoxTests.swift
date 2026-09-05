import CoreGraphics
import Testing

@testable import WorkoutTracker

/// Scanner accuracy, ticket 03 — the framing box is drawn and read from the
/// same geometry, and its preview rectangle becomes Vision's region.
struct LabelFramingBoxTests {

    @Test func theBoxIsPlateShapedCentredAndInsideTheView() {
        let size = CGSize(width: 390, height: 700)
        let box = LabelFramingBox.rect(in: size)
        #expect(abs(box.midX - size.width / 2) < 0.01)
        #expect(box.width / box.height == LabelFramingBox.aspectRatio)
        #expect(box.width <= size.width * LabelFramingBox.widthFraction + 0.01)
        #expect(box.minX >= 0 && box.maxX <= size.width && box.minY >= 0 && box.maxY <= size.height)
        #expect(box.midY < size.height / 2, "a little above centre, away from the thumb on the shutter")
    }

    @Test func aWideViewDoesNotProduceABoxTallerThanTheView() {
        let box = LabelFramingBox.rect(in: CGSize(width: 2_000, height: 200))
        #expect(box.height < 200 && box.minY >= 0 && box.maxY <= 200)
    }

    /// The metadata rectangle has a top-left origin; Vision's region has a
    /// bottom-left origin. A box at the top of the preview is a region at the
    /// top of the image — i.e. a LARGE Vision y.
    @Test func theMetadataRectangleIsFlippedIntoVisionsCoordinates() {
        let top = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.2)
        let region = LabelFramingBox.visionRegion(fromMetadataRect: top)
        #expect(abs(region.minX - 0.1) < 1e-9 && abs(region.minY - 0.7) < 1e-9)
        #expect(abs(region.width - 0.8) < 1e-9 && abs(region.height - 0.2) < 1e-9)
        // Anything outside the image is clamped; nothing sensible left → whole image.
        let overflowing = CGRect(x: -0.2, y: 0.5, width: 1.4, height: 0.9)
        let clamped = LabelFramingBox.visionRegion(fromMetadataRect: overflowing)
        #expect(abs(clamped.minX) < 1e-9 && abs(clamped.minY) < 1e-9)
        #expect(abs(clamped.width - 1) < 1e-9 && abs(clamped.height - 0.5) < 1e-9)
        #expect(LabelFramingBox.visionRegion(fromMetadataRect: .zero) == CGRect(x: 0, y: 0, width: 1, height: 1))
    }
}
