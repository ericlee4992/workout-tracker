import Foundation
import Testing
import UIKit

@testable import WorkoutTracker

// Scanner accuracy, ticket 01 — the harness.
//
// The scanner's thresholds were tuned on rendered text and it had never been
// measured on a photograph. This runs the app's OWN pipeline — the same Vision
// configuration as `MachineLabelOCR.read`, the same `CatalogMatcher` against
// the shipped catalog — over a folder of real name-plate photos and writes a
// per-photo report. The number it prints is the gate for every change to the
// scanner from here on.
//
// The photos are gitignored (`.scratch/scanner-accuracy/corpus/*`); only the
// manifest (source URL + ground-truth label) and the reports are committed.
// With no photos present — CI, a fresh clone — this passes and writes nothing,
// so the unit suite's meaning does not depend on files outside the repo.
struct ScannerCorpusHarness {

    struct Entry: Decodable {
        var file: String
        var source: String
        var brand: String
        var model: String
        /// The catalog row's display name this plate should resolve to, or
        /// nil when the catalog has no such row (then "create new" is right).
        var catalogModel: String?
        var notes: String?
    }

    struct Row {
        var entry: Entry
        var read: String
        var top: CatalogMatch?
        var preselected: CatalogMatch?
        var suggestsNew: Bool
        var topRight: Bool
        var preselectRight: Bool
        var wrongPreselect: Bool
    }

    private static var repoRoot: URL {
        // …/WorkoutTrackerTests/ScannerCorpusHarness.swift → repo root.
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private static var corpusURL: URL {
        repoRoot.appending(path: ".scratch/scanner-accuracy/corpus", directoryHint: .isDirectory)
    }

    private static var reportURL: URL {
        repoRoot.appending(path: ".scratch/scanner-accuracy/reports/latest.md")
    }

    private static func expectedDisplayName(_ entry: Entry) -> String? {
        entry.catalogModel.map { "\(entry.brand) \($0)" }
    }

    @Test func measureTheCorpus() async throws {
        let manifestURL = Self.corpusURL.appending(path: "manifest.json")
        guard let data = try? Data(contentsOf: manifestURL) else {
            print("ScannerCorpusHarness: no manifest at \(manifestURL.path) — nothing to measure.")
            return
        }
        let entries = try JSONDecoder().decode([Entry].self, from: data)
        let present = entries.filter {
            FileManager.default.fileExists(atPath: Self.corpusURL.appending(path: $0.file).path)
        }
        guard !present.isEmpty else {
            print("ScannerCorpusHarness: manifest lists \(entries.count) photos, none present locally — nothing to measure.")
            return
        }

        let catalog = try SeedCatalog.bundled()
        let index = CatalogMatchIndex(models: catalog.equipmentModels.map {
            (id: $0.id, manufacturer: $0.manufacturer, modelName: $0.modelName)
        })

        var rows: [Row] = []
        for entry in present {
            let url = Self.corpusURL.appending(path: entry.file)
            guard let image = UIImage(contentsOfFile: url.path) else {
                Issue.record("\(entry.file) is not an image UIKit can open")
                continue
            }
            let reading: LabelReading
            do {
                reading = try await MachineLabelOCR.read(image)
            } catch {
                reading = LabelReading()
            }
            let matches = CatalogMatcher.rank(reading, in: index)
            let top = matches.first
            let preselected = CatalogMatcher.preselection(from: matches)
            let suggestsNew = CatalogMatcher.suggestsCreatingNew(matches)
            let expected = Self.expectedDisplayName(entry)
            func isRight(_ match: CatalogMatch?) -> Bool {
                guard let match else { return false }
                guard let expected else { return false }
                return "\(match.manufacturer) \(match.modelName)".caseInsensitiveCompare(expected) == .orderedSame
            }
            rows.append(Row(
                entry: entry,
                read: reading.text.replacingOccurrences(of: "\n", with: " / "),
                top: top,
                preselected: preselected,
                suggestsNew: suggestsNew,
                topRight: isRight(top),
                preselectRight: isRight(preselected),
                wrongPreselect: preselected != nil && !isRight(preselected)))
        }

        let inCatalog = rows.filter { $0.entry.catalogModel != nil }
        let notInCatalog = rows.filter { $0.entry.catalogModel == nil }
        let topRight = inCatalog.filter(\.topRight).count
        let preRight = inCatalog.filter(\.preselectRight).count
        let wrong = rows.filter(\.wrongPreselect).count
        let newAgreed = notInCatalog.filter(\.suggestsNew).count
        let unread = rows.filter { $0.read.isEmpty }.count

        var report = "# Scanner corpus report — \(Date().formatted(date: .abbreviated, time: .shortened))\n\n"
        report += "Photos measured: \(rows.count) (\(inCatalog.count) with a catalog row, \(notInCatalog.count) without). "
        report += "Pipeline: `MachineLabelOCR.read` + `CatalogMatcher.rank` on the shipped catalog.\n\n"
        report += "| Metric | Value |\n|---|---|\n"
        report += "| Top-1 right (of \(inCatalog.count) in catalog) | \(topRight) |\n"
        report += "| Preselected right | \(preRight) |\n"
        report += "| **Wrong preselections** | **\(wrong)** |\n"
        report += "| Create-new suggested when the row is absent (of \(notInCatalog.count)) | \(newAgreed) |\n"
        report += "| Nothing read at all | \(unread) |\n\n"
        report += "| Photo | Expected | Read | Top (score) | Pre | Right? | Notes |\n|---|---|---|---|---|---|---|\n"
        for row in rows {
            let expected = Self.expectedDisplayName(row.entry) ?? "— (not in catalog)"
            let topText = row.top.map { "\($0.manufacturer) \($0.modelName) (\(Int(($0.score * 100).rounded()))%)" } ?? "—"
            let pre = row.preselected == nil ? "" : (row.wrongPreselect ? "**WRONG**" : "yes")
            let right = row.entry.catalogModel == nil ? (row.suggestsNew ? "new ✓" : "new ✗") : (row.topRight ? "✓" : "✗")
            let read = row.read.isEmpty ? "(nothing)" : row.read.prefix(80).replacingOccurrences(of: "|", with: "¦")
            report += "| \(row.entry.file) | \(expected) | \(read) | \(topText) | \(pre) | \(right) | \(row.entry.notes ?? "") |\n"
        }
        try FileManager.default.createDirectory(at: Self.reportURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try report.write(to: Self.reportURL, atomically: true, encoding: .utf8)
        print(report)
        print("ScannerCorpusHarness: report written to \(Self.reportURL.path)")
    }
}
