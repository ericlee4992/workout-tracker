import CoreGraphics
import CoreImage
import CoreText
import Foundation
import SwiftData
import Testing
import UIKit

@testable import WorkoutTracker

// Photo machine capture, ticket 01 — the one test that runs the whole chain:
// pixels → Vision → matcher → a catalog row. The label is rendered here rather
// than checked in as a photo, so the test is hermetic and the fixture is
// readable in the diff.
//
// Vision itself is Apple's; these tests are not trying to measure it. They are
// checking that this app hands it a sane image, reads its output in the right
// order, and feeds the matcher something it can work with.

struct MachineLabelOCRTests {

    /// Draws a name-plate-ish image: brand small on top, model large beneath,
    /// a load rating and a warning in the corner like the real thing.
    private func renderLabel(
        brand: String, model: String, extras: [String] = [],
        size: CGSize = CGSize(width: 1_600, height: 620)
    ) -> CGImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            /// Draws centred, shrinking the type until the line fits — a
            /// clipped fixture would test Vision's guess at half a word
            /// rather than this app's handling of a legible plate.
            func draw(_ text: String, y: CGFloat, size fontSize: CGFloat) {
                var font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
                var string = NSAttributedString(string: text, attributes: [.font: font])
                while string.size().width > size.width - 80, font.pointSize > 12 {
                    font = UIFont.systemFont(ofSize: font.pointSize - 4, weight: .semibold)
                    string = NSAttributedString(string: text, attributes: [.font: font])
                }
                let attributed = NSAttributedString(
                    string: text,
                    attributes: [.font: font, .foregroundColor: UIColor.black])
                attributed.draw(
                    at: CGPoint(x: (size.width - attributed.size().width) / 2, y: y))
            }

            draw(brand, y: 60, size: 64)
            draw(model, y: 200, size: 96)
            for (index, extra) in extras.enumerated() {
                draw(extra, y: 400 + CGFloat(index) * 60, size: 40)
            }
        }
        return image.cgImage!
    }

    /// Pixels turned 90° clockwise, with no orientation metadata — the raw
    /// buffer a sideways camera hands over.
    private func rotatedClockwise(_ image: CGImage) -> CGImage {
        let size = CGSize(width: image.height, height: image.width)
        return UIGraphicsImageRenderer(size: size).image { context in
            let cgContext = context.cgContext
            cgContext.translateBy(x: size.width, y: 0)
            cgContext.rotate(by: .pi / 2)
            UIImage(cgImage: image).draw(at: .zero)
        }.cgImage!
    }

    private func realCatalogIndex() throws -> CatalogMatchIndex {
        CatalogMatchIndex(models: try SeedCatalog.bundled().equipmentModels.map {
            (id: $0.id, manufacturer: $0.manufacturer, modelName: $0.modelName)
        })
    }

    private func makeIndex() -> CatalogMatchIndex {
        CatalogMatchIndex(models: [
            (id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!,
             manufacturer: "Life Fitness", modelName: "Insignia Series Chest Press"),
            (id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A2")!,
             manufacturer: "Life Fitness", modelName: "Insignia Series Shoulder Press"),
            (id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A3")!,
             manufacturer: "Hammer Strength", modelName: "Select Seated Leg Press"),
        ])
    }

    @Test func readsARenderedNamePlateTopLineFirst() throws {
        let image = renderLabel(
            brand: "LIFE FITNESS", model: "Insignia Series Chest Press",
            extras: ["MAX 300 LB"])
        let reading = try MachineLabelOCR.perform(image)

        #expect(!reading.isEmpty)
        let text = MachineLabelText.normalized(reading.text)
        #expect(text.contains("life fitness"))
        #expect(text.contains("chest press"))
        #expect(reading.lines.first?.text.uppercased().contains("LIFE FITNESS") == true,
                "lines must come back top of the plate first, got: \(reading.text)")
        // The model name is set larger than the brand, and Vision's boxes
        // should say so — the create-new guess leans on this.
        let brandLine = try #require(reading.lines.first)
        let modelLine = try #require(reading.lines.first { $0.text.lowercased().contains("chest") })
        #expect(modelLine.heightFraction > brandLine.heightFraction)
    }

    /// Scanner accuracy, ticket 03: only text inside the region is read. The
    /// rendered plate has the brand at the top, the model in the middle and a
    /// rating at the bottom; a band around the middle reads the model alone.
    @Test func onlyTextInsideTheRegionOfInterestIsRead() throws {
        let image = renderLabel(
            brand: "LIFE FITNESS", model: "Insignia Series Chest Press",
            extras: ["MAX 300 LB"])
        // 620 px tall: model at y 200–~310 from the top → Vision y ≈ 0.50–0.68.
        let middle = CGRect(x: 0, y: 0.42, width: 1, height: 0.33)
        let reading = try MachineLabelOCR.perform(image, regionOfInterest: middle)
        let text = MachineLabelText.normalized(reading.text)
        #expect(text.contains("chest press"), "read: \(reading.text)")
        #expect(!text.contains("life fitness"), "the brand line is above the box: \(reading.text)")
        #expect(!text.contains("300"), "the rating is below the box: \(reading.text)")
        // The whole image still reads everything.
        let whole = MachineLabelText.normalized(try MachineLabelOCR.perform(image).text)
        #expect(whole.contains("life fitness") && whole.contains("300"))
    }

    /// The region is expressed in the UPRIGHT image's coordinates: a photo
    /// taken sideways, tagged with its orientation, reads the same band.
    @Test func theRegionOfInterestFollowsTheOrientation() async throws {
        let upright = renderLabel(brand: "LIFE FITNESS", model: "Insignia Series Chest Press", extras: ["MAX 300 LB"])
        let rotated = UIImage(cgImage: rotatedClockwise(upright), scale: 1, orientation: .left)
        let middle = CGRect(x: 0, y: 0.42, width: 1, height: 0.33)
        let reading = try await MachineLabelOCR.read(rotated, regionOfInterest: middle)
        let text = MachineLabelText.normalized(reading.text)
        #expect(text.contains("chest press"), "read: \(reading.text)")
        #expect(!text.contains("life fitness") && !text.contains("300"), "read: \(reading.text)")
    }

    @Test func aPhotographedPlateFindsItsCatalogRow() throws {
        let image = renderLabel(
            brand: "LIFE FITNESS", model: "Insignia Series Chest Press",
            extras: ["MAX 300 LB", "READ MANUAL BEFORE USE"])
        let reading = try MachineLabelOCR.perform(image)
        let matches = CatalogMatcher.rank(reading, in: makeIndex())

        let best = try #require(matches.first, "read: \(reading.text)")
        #expect(best.modelName == "Insignia Series Chest Press")
        let preselected = CatalogMatcher.preselection(from: matches)
        #expect(
            preselected?.modelName == "Insignia Series Chest Press",
            "scored \(best.score) on \(reading.text)")
    }

    /// A camera image is almost never `.up`. Vision reads rotated text badly,
    /// and this app orders lines by vertical position to decide which one is
    /// the brand — so the orientation the photo was taken at has to reach the
    /// request (codex-review, finding 5).
    @Test func aRotatedPhotoIsReadUpright() async throws {
        let upright = renderLabel(
            brand: "LIFE FITNESS", model: "Insignia Series Chest Press")
        // What a phone held sideways actually produces: sideways *pixels* plus
        // the orientation tag that says which way is up. Only the tag makes it
        // legible, which is the whole point of passing it to Vision.
        let rotated = UIImage(
            cgImage: rotatedClockwise(upright), scale: 1, orientation: .left)

        let reading = try await MachineLabelOCR.read(rotated)
        let text = MachineLabelText.normalized(reading.text)
        #expect(text.contains("chest press"), "read: \(reading.text)")
        #expect(
            reading.lines.first?.text.uppercased().contains("LIFE FITNESS") == true,
            "the brand must still come out on top, got: \(reading.text)")
    }

    /// Upside down as well as sideways — a plate photographed from above a
    /// machine is a real way to hold a phone.
    @Test func anUpsideDownPhotoIsReadUpright() async throws {
        let upright = renderLabel(
            brand: "LIFE FITNESS", model: "Insignia Series Chest Press")
        let flipped = UIImage(
            cgImage: rotatedClockwise(rotatedClockwise(upright)), scale: 1, orientation: .down)

        let reading = try await MachineLabelOCR.read(flipped)
        let text = MachineLabelText.normalized(reading.text)
        #expect(text.contains("chest press"), "read: \(reading.text)")
        #expect(
            reading.lines.first?.text.uppercased().contains("LIFE FITNESS") == true,
            "the brand must still come out on top, got: \(reading.text)")
    }

    /// A photo from the library can be `CIImage`-backed (HEIC, or edited) and
    /// have no `cgImage` at all. Calling that unreadable would be a lie.
    @Test func aCIImageBackedPhotoIsStillReadable() async throws {
        let rendered = renderLabel(
            brand: "LIFE FITNESS", model: "Insignia Series Chest Press")
        let ciBacked = UIImage(ciImage: CIImage(cgImage: rendered))
        #expect(ciBacked.cgImage == nil, "precondition: no CGImage backing")

        let reading = try await MachineLabelOCR.read(ciBacked)
        #expect(MachineLabelText.normalized(reading.text).contains("chest press"))
    }

    @Test func aBlankPhotoReportsThatItSawNothing() async {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 400))
        let blank = renderer.image { context in
            UIColor.lightGray.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 400, height: 400))
        }.cgImage!

        await #expect(throws: MachineLabelOCR.Failure.self) {
            _ = try await MachineLabelOCR.read(blank)
        }
    }

    /// The case the thresholds are tuned against, on the real catalog: a Life
    /// Fitness Insignia chest press shares "Insignia Series" and its brand with
    /// five stablemates. The right row must be preselected and stand clear of
    /// them, or a misread of the single distinguishing word ("Chest") would
    /// pick the wrong machine and quietly split the user's history (D23/D33).
    @Test func theRightRowIsPreselectedAndStandsClearOfItsStablemates() throws {
        let index = try realCatalogIndex()
        let matches = CatalogMatcher.rank(
            LabelReading.lines(["LIFE FITNESS", "Insignia Series Chest Press", "MAX 300 LB"]),
            in: index, limit: 6)

        let preselected = try #require(CatalogMatcher.preselection(from: matches))
        #expect(preselected.modelName == "Insignia Series Chest Press")
        #expect(matches.count > 1, "the stablemates still belong in the list")
        let runnerUp = try #require(matches.dropFirst().first)
        let gap = preselected.score - runnerUp.score
        #expect(
            gap >= CatalogMatcher.preselectionMargin,
            "runner-up \(runnerUp.modelName) at \(runnerUp.score) is \(gap) from \(preselected.score)")
    }

    /// The index the app really builds — 1877 seeded rows — has to be cheap
    /// enough to construct and query while the user waits on a tap.
    @Test func indexingAndRankingTheRealCatalogIsFastEnough() throws {
        let catalog = try SeedCatalog.bundled()
        let started = Date()
        let index = CatalogMatchIndex(models: catalog.equipmentModels.map {
            (id: $0.id, manufacturer: $0.manufacturer, modelName: $0.modelName)
        })
        let built = Date()
        let matches = CatalogMatcher.rank(
            LabelReading.lines(["LIFE FITNESS", "Insignia Series Chest Press", "MAX 300 LB"]),
            in: index)
        let ranked = Date()

        #expect(index.entries.count > 1_000, "sanity: this is the shipped catalog")
        #expect(!matches.isEmpty)
        #expect(matches.first?.manufacturer == "Life Fitness")
        // Loose on purpose: the point is catching an accidental O(n²), not
        // timing a particular Mac.
        #expect(built.timeIntervalSince(started) < 5, "index build took too long")
        #expect(ranked.timeIntervalSince(built) < 2, "ranking took too long")
    }
}
