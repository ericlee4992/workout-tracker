import UIKit

/// Test-only camera stand-in: the Simulator has no camera, so Scan Machine's fixture (`TerraAccess.fixture`) shows
/// and sends this rendered name plate instead, and `LabelCrop`'s unit tests crop it. (Its own launch flag,
/// `-uiTestScanFixture`, drove the on-device label reader removed in tester feedback 01, D88.)
enum ScanFixture {
    /// The rendered plate's own edges as a framing box (Vision region,
    /// bottom-left origin): `plate` above, normalised on the canvas.
    static let plateRegion = CGRect(x: 0.1, y: 0.1875, width: 0.8, height: 0.625)

    /// A rendered name plate for a model the seeded catalog really contains,
    /// on a dark canvas around it — so the plate's box is a BOX: inset enough
    /// that `LabelCrop`'s margin still leaves canvas out (codex-review-05b; its
    /// unit tests crop this image).
    static func image() -> UIImage {
        let canvas = CGSize(width: 2_000, height: 800)
        let plate = CGRect(x: 200, y: 150, width: 1_600, height: 500)
        return UIGraphicsImageRenderer(size: canvas).image { context in
            UIColor.darkGray.setFill()
            context.fill(CGRect(origin: .zero, size: canvas))
            UIColor.white.setFill()
            context.fill(plate)
            draw("LIFE FITNESS", in: canvas, y: plate.minY + 60, fontSize: 64)
            draw("Insignia Series Chest Press", in: canvas, y: plate.minY + 200, fontSize: 88)
            draw("MAX 300 LB", in: canvas, y: plate.minY + 380, fontSize: 40)
        }
    }

    private static func draw(_ text: String, in size: CGSize, y: CGFloat, fontSize: CGFloat) {
        let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        let string = NSAttributedString(
            string: text, attributes: [.font: font, .foregroundColor: UIColor.black])
        string.draw(at: CGPoint(x: (size.width - string.size().width) / 2, y: y))
    }
}
