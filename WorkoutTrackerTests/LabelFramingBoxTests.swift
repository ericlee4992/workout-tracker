import CoreGraphics
import Testing

@testable import WorkoutTracker

/// Scanner accuracy, ticket 03 — the framing box is drawn and read from the
/// same geometry, and maps into the upright photo by aspect-fill arithmetic
/// alone (codex-review-03: the AVFoundation metadata conversion is in the
/// unrotated sensor space and turned the wide box into a tall strip).
struct LabelFramingBoxTests {

    private func close(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) < 1e-6 && abs(a.minY - b.minY) < 1e-6
            && abs(a.width - b.width) < 1e-6 && abs(a.height - b.height) < 1e-6
    }

    @Test func theBoxIsPlateShapedCentredAndInsideTheView() {
        let size = CGSize(width: 390, height: 700)
        let box = LabelFramingBox.rect(in: size)
        #expect(abs(box.midX - size.width / 2) < 0.01)
        #expect(box.width / box.height == LabelFramingBox.aspectRatio)
        #expect(box.width <= size.width * LabelFramingBox.widthFraction + 0.01)
        #expect(box.minX >= 0 && box.maxX <= size.width && box.minY >= 0 && box.maxY <= size.height)
        #expect(box.midY < size.height / 2, "a little above centre, away from the thumb on the shutter")
    }

    @Test func aWideViewDoesNotProduceABoxOutsideTheView() {
        let box = LabelFramingBox.rect(in: CGSize(width: 2_000, height: 200))
        #expect(box.height < 200 && box.minY >= 0 && box.maxY <= 200)
    }

    /// A portrait view showing a portrait 3:4 photo aspect-filled: the photo
    /// is wider than the view, so it overflows horizontally and the box maps
    /// to a narrower share of the photo's width; vertically it maps 1:1.
    @Test func aBoxOnAPortraitPreviewMapsIntoTheUprightPortraitPhoto() {
        let view = CGSize(width: 400, height: 800)
        let photo = CGSize(width: 3_024, height: 4_032)  // upright 3:4
        // Fill: scale = max(400/3024, 800/4032) = 800/4032; shown = 600 × 800, offset x = -100.
        let box = CGRect(x: 50, y: 200, width: 300, height: 100)
        let region = LabelFramingBox.visionRegion(box: box, viewSize: view, imageSize: photo)
        // x: (50+100)/600 = 0.25, width 300/600 = 0.5; y from the top 200/800 = 0.25,
        // height 100/800 = 0.125 → Vision (bottom-left) y = 1 − (0.25+0.125) = 0.625.
        #expect(close(region, CGRect(x: 0.25, y: 0.625, width: 0.5, height: 0.125)), "\(region)")
        #expect(region.width > region.height, "a wide box stays a wide region — never a tall strip")
    }

    /// The other overflow: a photo taller than the view (a squarer view).
    @Test func aTallPhotoOverflowsVerticallyAndTheBoxMapsAccordingly() {
        let view = CGSize(width: 400, height: 400)
        let photo = CGSize(width: 300, height: 400)  // scale = 400/300; shown 400 × 533.3, offset y = -66.7
        let box = CGRect(x: 0, y: 0, width: 400, height: 100)
        let region = LabelFramingBox.visionRegion(box: box, viewSize: view, imageSize: photo)
        let top = 66.666_667 / 533.333_333, height = 100 / 533.333_333
        #expect(close(region, CGRect(x: 0, y: 1 - (top + height), width: 1, height: height)), "\(region)")
    }

    @Test func degenerateInputsReadTheWholePhoto() {
        let whole = CGRect(x: 0, y: 0, width: 1, height: 1)
        #expect(LabelFramingBox.visionRegion(box: .zero, viewSize: .zero, imageSize: CGSize(width: 1, height: 1)) == whole)
        #expect(LabelFramingBox.visionRegion(box: CGRect(x: -500, y: -500, width: 10, height: 10),
                                             viewSize: CGSize(width: 400, height: 800),
                                             imageSize: CGSize(width: 300, height: 400)) == whole,
                "a box entirely off the photo")
    }
}
