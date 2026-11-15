import CoreGraphics
import Testing
@testable import WorkoutTracker

/// Which pixels of a label photo leave the phone: the framing box with a small margin, never the frame (D53's
/// crop rule, kept for Scan Food's label photos). Moved from the removed plate Ask AI tests (scanner accuracy 07).
struct LabelCropTests {
    @Test func theCropIsTheBoxWithAMarginInTheUprightPhoto() {
        // Vision region: bottom-left origin. Box 50% wide × 25% tall, its
        // left edge at 10%, its bottom at 20% → its top at 45% from the
        // bottom = 55% from the top.
        let region = CGRect(x: 0.1, y: 0.2, width: 0.5, height: 0.25)
        let rect = LabelCrop.pixelRect(region: region, imageSize: CGSize(width: 1_000, height: 2_000))
        // Box in pixels: x 100, y 1100, w 500, h 500; margin 8% of each side = 40.
        #expect(rect == CGRect(x: 60, y: 1_060, width: 580, height: 580))
    }

    @Test func theCropIsClampedToThePhoto() throws {
        let size = CGSize(width: 1_000, height: 2_000)
        let edge = try #require(LabelCrop.pixelRect(region: CGRect(x: 0, y: 0.9, width: 1, height: 0.1), imageSize: size))
        #expect(edge.minX == 0 && edge.minY == 0 && edge.maxX == 1_000)
    }

    /// The whole photo never leaves the phone: no box, a degenerate box, or
    /// a box that IS the frame yield nothing to send (codex-review-05, high).
    @Test func noBoxMeansNothingToSend() {
        let size = CGSize(width: 1_000, height: 2_000)
        #expect(LabelCrop.pixelRect(region: .zero, imageSize: size) == nil)
        #expect(LabelCrop.pixelRect(region: CGRect(x: 0, y: 0, width: 1, height: 1), imageSize: size) == nil)
        #expect(LabelCrop.pixelRect(region: CGRect(x: 0.1, y: 0.1, width: 0.5, height: 0.2), imageSize: .zero) == nil)
        #expect(LabelCrop.pixelRect(region: CGRect(x: 2, y: 2, width: 0.5, height: 0.2), imageSize: size) == nil, "a box entirely outside the photo")
        #expect(LabelCrop.pixelRect(region: CGRect(x: 0.02, y: 0.04, width: 0.96, height: 0.92), imageSize: CGSize(width: 1_600, height: 500)) == nil, "a near-frame box whose margin reaches every edge")
        #expect(LabelCrop.pixelRect(region: CGRect(x: 0.0725, y: 0.04, width: 0.9, height: 0.92), imageSize: CGSize(width: 2_000, height: 800)) == nil, "all but one pixel column is the frame (codex-review-05c)")
        #expect(LabelCrop.pixelRect(region: CGRect(x: 0.05, y: 0.05, width: 0.9, height: 0.9), imageSize: size) == nil, "a box covering nine tenths of the photo before its margin")
        #expect(LabelCrop.pixelRect(region: CGRect(x: 0.02, y: 0.3, width: 0.96, height: 0.4), imageSize: size) != nil, "a wide box that keeps top and bottom out is still a box")
        #expect(LabelCrop.pixelRect(region: ScanFixture.plateRegion, imageSize: CGSize(width: 2_000, height: 800)) != nil, "the fixture plate (≈ 67 % with its margin) is a box")
    }

    @Test func theCropIsResizedToTheExperimentsLongSideAndNeverUpscaled() {
        #expect(abs(LabelCrop.scale(for: CGSize(width: 4_032, height: 1_500)) - 1_568.0 / 4_032.0) < 1e-9)
        #expect(LabelCrop.scale(for: CGSize(width: 800, height: 300)) == 1)
    }
}
