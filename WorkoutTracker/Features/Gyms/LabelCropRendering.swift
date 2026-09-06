import CoreGraphics
import UIKit

/// Scanner accuracy, ticket 05 — `LabelCrop` meets UIKit: the pixels.
extension LabelCrop {
    /// The bytes an ask sends: the box (plus `margin`) cut from the upright
    /// photo, no longer than `maxSide`, JPEG — or nil when there is no box
    /// worth the name, and then no ask is offered. Runs wherever it is
    /// called; nothing is written anywhere.
    static func jpeg(_ image: UIImage, region: CGRect) -> Data? {
        guard let upright = uprightCGImage(image) else { return nil }
        let size = CGSize(width: upright.width, height: upright.height)
        guard let rect = pixelRect(region: region, imageSize: size),
              let cropped = upright.cropping(to: rect) else { return nil }
        let cropSize = CGSize(width: cropped.width, height: cropped.height)
        let factor = scale(for: cropSize)
        let target = CGSize(
            width: max(1, (cropSize.width * factor).rounded()),
            height: max(1, (cropSize.height * factor).rounded()))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            UIImage(cgImage: cropped).draw(in: CGRect(origin: .zero, size: target))
        }
        return rendered.jpegData(compressionQuality: 0.85)
    }

    /// Pixels with the orientation tag applied, so the region — which is in
    /// the UPRIGHT photo's coordinates — indexes the right pixels.
    private static func uprightCGImage(_ image: UIImage) -> CGImage? {
        if image.imageOrientation == .up, image.scale == 1, let cgImage = image.cgImage {
            return cgImage
        }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }.cgImage
    }
}
