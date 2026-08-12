import CoreGraphics
import CoreImage
import Foundation
import UIKit
import Vision

// Photo machine capture, ticket 01 — the camera-facing half: a photograph in, a
// `LabelReading` out.
//
// Lives in `Features/Gyms` rather than `Domain/`: it orchestrates a platform
// framework and speaks `UIImage`, while `Domain/` is value types and pure logic
// (CLAUDE.md, and codex-review finding 12). `LabelReading` and the matcher stay
// in Domain, where they can be tested without a camera.
//
// Vision's text recognition is on device and offline, which is the only kind
// that works in a basement gym and the only kind that keeps a photo of the
// user's gym from leaving their phone (D34). It also costs no dependency, which
// the project's no-third-party rule requires.

enum MachineLabelOCR {

    enum Failure: Error, LocalizedError {
        case unreadableImage
        case recognitionFailed(underlying: Error)
        case noTextFound

        var errorDescription: String? {
            switch self {
            case .unreadableImage:
                "That photo could not be opened."
            case .recognitionFailed(let underlying):
                "Could not read the photo: \(underlying.localizedDescription)"
            case .noTextFound:
                "No text found in that photo."
            }
        }
    }

    /// Reads a photograph as the user took it, off the main actor.
    ///
    /// Orientation matters twice over: Vision reads rotated text far worse than
    /// upright text, and this app orders lines by their vertical position to
    /// decide which one is the brand. A camera image is almost never `.up`
    /// (codex-review, finding 5).
    static func read(_ image: UIImage) async throws -> LabelReading {
        guard let cgImage = cgImage(from: image) else { throw Failure.unreadableImage }
        return try await read(cgImage, orientation: orientation(of: image))
    }

    static func read(
        _ image: CGImage, orientation: CGImagePropertyOrientation = .up
    ) async throws -> LabelReading {
        let reading = try await Task.detached(priority: .userInitiated) {
            try perform(image, orientation: orientation)
        }.value
        guard !reading.isEmpty else { throw Failure.noTextFound }
        return reading
    }

    /// Synchronous recognition. Separated so tests can call it directly on a
    /// rendered fixture without an async hop.
    static func perform(
        _ image: CGImage, orientation: CGImagePropertyOrientation = .up
    ) throws -> LabelReading {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        // Off deliberately: "Insignia", "Cybex", "Hammer Strength" and
        // "VSL019BP" are not dictionary words, and correction rewrites exactly
        // the distinctive tokens the matcher depends on.
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]

        let handler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])
        do {
            try handler.perform([request])
        } catch {
            throw Failure.recognitionFailed(underlying: error)
        }

        // Each line keeps its own box, so the sort below cannot drift out of
        // step with the text the way zipping two separately-filtered arrays
        // would.
        let lines = (request.results ?? []).compactMap {
            observation -> (line: LabelReading.Line, top: CGFloat)? in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return (
                LabelReading.Line(
                    text: text,
                    confidence: Double(candidate.confidence),
                    heightFraction: Double(observation.boundingBox.height)),
                observation.boundingBox.maxY)
        }
        // Vision's origin is bottom-left, and its boxes are already expressed in
        // the *oriented* image's coordinates, so "top of the plate" is the
        // largest maxY. Order matters to the manufacturer guess, which trusts
        // the brand line when the catalog does not recognise the brand.
        return LabelReading(lines: lines.sorted { $0.top > $1.top }.map(\.line))
    }

    // MARK: - Getting pixels out of a UIImage

    /// A `UIImage` from the photo library can be backed by a `CIImage` (a HEIC
    /// or an edited photo) and have no `cgImage` at all. Rendering it is a few
    /// lines; calling it unreadable would have been a lie.
    private static func cgImage(from image: UIImage) -> CGImage? {
        if let cgImage = image.cgImage { return cgImage }
        if let ciImage = image.ciImage {
            return CIContext().createCGImage(ciImage, from: ciImage.extent)
        }
        // Last resort: redraw it. Costs a copy, works for anything UIKit can
        // display.
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        return UIGraphicsImageRenderer(size: image.size, format: format)
            .image { _ in image.draw(at: .zero) }
            .cgImage
    }

    private static func orientation(of image: UIImage) -> CGImagePropertyOrientation {
        // A redrawn image (the fallback above) is already upright.
        guard image.cgImage != nil || image.ciImage != nil else { return .up }
        return CGImagePropertyOrientation(image.imageOrientation)
    }
}

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
