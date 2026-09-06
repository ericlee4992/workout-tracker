import CoreGraphics
import Testing
import UIKit
@testable import WorkoutTracker

/// Scanner accuracy, ticket 05 — the PIXELS an ask sends, from an
/// EXIF-oriented photo like the shutter's (codex-review-05: the rectangle
/// arithmetic alone did not prove the orientation wiring).
struct LabelCropRenderingTests {

    /// Sensor pixels 400 × 200: left half red, right half blue. Tagged
    /// `.right` (rotate 90° clockwise to display) the UPRIGHT photo is
    /// 200 × 400 with red on TOP and blue below — the way a portrait phone's
    /// photo arrives from `AVCapturePhoto`.
    private func orientedPhoto() -> UIImage {
        let size = CGSize(width: 400, height: 200)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let sensor = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
            UIColor.blue.setFill()
            context.fill(CGRect(x: 200, y: 0, width: 200, height: 200))
        }
        return UIImage(cgImage: sensor.cgImage!, scale: 1, orientation: .right)
    }

    private func decoded(_ jpeg: Data) throws -> (size: CGSize, centre: (r: CGFloat, g: CGFloat, b: CGFloat)) {
        let image = try #require(UIImage(data: jpeg))
        let cgImage = try #require(image.cgImage)
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try #require(CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        // Draw the whole image into one pixel: its mean colour.
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return (image.size, (CGFloat(pixel[0]) / 255, CGFloat(pixel[1]) / 255, CGFloat(pixel[2]) / 255))
    }

    @Test func theTopBoxOfAnOrientedPhotoIsItsTopPixels() throws {
        // Vision region, bottom-left origin: the top 40 % of the upright photo,
        // inset from the sides so it is a box.
        let region = CGRect(x: 0.1, y: 0.6, width: 0.8, height: 0.4)
        let jpeg = try #require(LabelCrop.jpeg(orientedPhoto(), region: region))
        let result = try decoded(jpeg)
        // Upright photo is 200 × 400; box 160 × 160 at y 0…160; margin 8 % = 12.8 → ~186 × 173 (clamped at the top).
        #expect(abs(result.size.width - 186) <= 2, "got \(result.size)")
        #expect(abs(result.size.height - 173) <= 2, "got \(result.size)")
        #expect(result.centre.r > 0.8 && result.centre.b < 0.2, "the top of the upright photo is red, got \(result.centre)")
    }

    @Test func theBottomBoxOfAnOrientedPhotoIsItsBottomPixels() throws {
        let region = CGRect(x: 0.1, y: 0, width: 0.8, height: 0.4)
        let jpeg = try #require(LabelCrop.jpeg(orientedPhoto(), region: region))
        let result = try decoded(jpeg)
        #expect(result.centre.b > 0.8 && result.centre.r < 0.2, "the bottom of the upright photo is blue, got \(result.centre)")
    }

    @Test func aBigCropIsResizedToTheExperimentsLongSide() throws {
        let size = CGSize(width: 4_000, height: 1_000)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let big = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.green.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        let jpeg = try #require(LabelCrop.jpeg(big, region: CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)))
        let result = try decoded(jpeg)
        #expect(result.size.width <= LabelCrop.maxSide && result.size.height <= LabelCrop.maxSide)
        #expect(result.size.width > LabelCrop.maxSide - 2, "the long side is brought to maxSide, got \(result.size)")
    }

    @Test func theFrameItselfIsNeverEncoded() {
        #expect(LabelCrop.jpeg(orientedPhoto(), region: CGRect(x: 0, y: 0, width: 1, height: 1)) == nil)
        // A box the margin turns into the frame is the frame (codex-review-05b).
        #expect(LabelCrop.jpeg(orientedPhoto(), region: CGRect(x: 0.02, y: 0.04, width: 0.96, height: 0.92)) == nil)
        // The fixture's own box survives its margin — it is a box.
        #expect(LabelCrop.jpeg(ScanFixture.image(), region: ScanFixture.plateRegion) != nil)
    }
}
