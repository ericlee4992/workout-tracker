import CoreData
import Foundation
import SwiftData

/// Nutrition N1 (public-beta ticket 11): an automatic copy of the user's data, on the phone, taken before an update opens
/// the store in a new stored format for the first time — testers cannot make backups, and a conversion that goes wrong
/// would otherwise have nothing to go back to. The user's decisions (2026-11-09): the copy is the store's own files
/// (`.store`, `-wal`, `-shm`, copied while closed — an exact restore; no JSON, which the new build could only write after
/// converting); only when the format changes, never on ordinary launches; Application Support/`SafetyCopies` (in the
/// iPhone's own backup, not in Files); the last 2 copies; restore from Profile with a confirmation naming the copy's date.
///
/// Restoring brings back the old-format files, so the same build converts them again on the next open: restore is for
/// a later build that fixes a bad conversion, or for undoing data lost by one.
struct SafetyCopyInfo: Codable, Equatable, Identifiable, Sendable {
    /// The copy's folder name inside `SafetyCopies` (also its identity).
    var folder: String
    var date: Date
    /// The app version and build that made the copy (the build whose first open converts the data).
    var appVersion: String
    /// Each copied file's name (relative to the store's folder) and size.
    var files: [String: Int64]
    var id: String { folder }
    var totalBytes: Int64 { files.values.reduce(0, +) }
}

enum SafetyCopyError: Error, Equatable, LocalizedError {
    case notEnoughSpace(needed: Int64, available: Int64)
    case incomplete(String)

    var errorDescription: String? {
        switch self {
        case let .notEnoughSpace(needed, available):
            let format = ByteCountFormatter()
            return "Not enough free space: the copy needs \(format.string(fromByteCount: needed)), "
                + "this iPhone has \(format.string(fromByteCount: available)) free."
        case let .incomplete(file):
            return "The copy of \(file) was incomplete."
        }
    }
}

/// The copies folder and every operation on it. File-system work only; no SwiftData context is open while it runs.
struct SafetyCopies {
    static let keep = 2
    static let manifestName = "manifest.json"
    static let pendingRestoreName = "restore-pending.json"
    /// About 10 MB on top of the files themselves, so a copy never takes the last of the phone's space.
    static let spaceMargin: Int64 = 10_000_000

    let directory: URL
    var fileManager: FileManager = .default
    /// Copies one file; injected by tests to simulate a full disk.
    var copyFile: (URL, URL) throws -> Void = { try FileManager.default.copyItem(at: $0, to: $1) }
    /// Free space where the copies are written; nil when unknown (the copy is then attempted).
    var availableBytes: (URL) -> Int64? = { url in
        (try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))?
            .volumeAvailableCapacityForImportantUsage
    }

    /// The store and its SQLite side files, in the order they are copied.
    static func storeFiles(for storeURL: URL) -> [URL] {
        [storeURL, URL(fileURLWithPath: storeURL.path + "-wal"), URL(fileURLWithPath: storeURL.path + "-shm")]
    }

    /// Whether opening the store at `storeURL` with `model` would convert it: the store exists and its metadata does not
    /// match the model (the same entity version hashes that decide whether SwiftData migrates — `StoreFormatGuardTests`).
    /// An existing store whose metadata cannot be read also counts: the open is about to fail or rewrite it.
    static func storeNeedsCopy(at storeURL: URL, model: NSManagedObjectModel?,
                               fileManager: FileManager = .default) -> Bool {
        guard fileManager.fileExists(atPath: storeURL.path) else { return false }
        guard let model,
              let metadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(
                  ofType: NSSQLiteStoreType, at: storeURL, options: nil)
        else { return true }
        return !model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
    }

    /// Copies the store's files into a new folder: written under a hidden name first and renamed when complete, so an
    /// interrupted copy never appears in `list()`. Then prunes to the last `keep`.
    @discardableResult
    func make(from storeURL: URL, now: Date = .now, appVersion: String) throws -> SafetyCopyInfo {
        let now = Date(timeIntervalSince1970: now.timeIntervalSince1970.rounded(.down))  // the manifest keeps seconds
        let sources = Self.storeFiles(for: storeURL).filter { fileManager.fileExists(atPath: $0.path) }
        let sizes = try sources.map { try size(of: $0) }
        let needed = sizes.reduce(0, +) + Self.spaceMargin
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        if let available = availableBytes(directory), available < needed {
            throw SafetyCopyError.notEnoughSpace(needed: needed, available: available)
        }
        let staging = directory.appending(path: ".partial-\(UUID().uuidString)", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        do {
            var files: [String: Int64] = [:]
            for (source, expected) in zip(sources, sizes) {
                let target = staging.appending(path: source.lastPathComponent)
                try copyFile(source, target)
                guard try size(of: target) == expected else { throw SafetyCopyError.incomplete(source.lastPathComponent) }
                files[source.lastPathComponent] = expected
            }
            let info = SafetyCopyInfo(folder: Self.folderName(for: now), date: now, appVersion: appVersion, files: files)
            try JSONEncoder.safetyCopy.encode(info).write(to: staging.appending(path: Self.manifestName))
            let final = directory.appending(path: info.folder, directoryHint: .isDirectory)
            if fileManager.fileExists(atPath: final.path) { try fileManager.removeItem(at: final) }
            try fileManager.moveItem(at: staging, to: final)
            prune()
            return info
        } catch {
            try? fileManager.removeItem(at: staging)
            throw error
        }
    }

    /// The complete copies, newest first (a folder without a readable manifest is ignored).
    func list() -> [SafetyCopyInfo] {
        let folders = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return folders
            .filter { !$0.lastPathComponent.hasPrefix(".") }
            .compactMap { folder in
                (try? Data(contentsOf: folder.appending(path: Self.manifestName)))
                    .flatMap { try? JSONDecoder.safetyCopy.decode(SafetyCopyInfo.self, from: $0) }
            }
            .sorted { $0.date > $1.date }
    }

    /// Keeps the newest `keep` copies; removes older ones and any interrupted (hidden) copy.
    func prune(keeping keep: Int = SafetyCopies.keep) {
        let pending = pendingRestore?.folder
        for old in list().dropFirst(keep) where old.folder != pending {
            try? fileManager.removeItem(at: directory.appending(path: old.folder, directoryHint: .isDirectory))
        }
        let folders = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for partial in folders where partial.lastPathComponent.hasPrefix(".partial-") {
            try? fileManager.removeItem(at: partial)
        }
    }

    // MARK: Restore — confirmed in the app, carried out at the next launch before the store opens

    /// The copy the user chose to restore, waiting for the next launch.
    var pendingRestore: SafetyCopyInfo? {
        (try? Data(contentsOf: directory.appending(path: Self.pendingRestoreName)))
            .flatMap { try? JSONDecoder.safetyCopy.decode(SafetyCopyInfo.self, from: $0) }
    }

    func scheduleRestore(_ copy: SafetyCopyInfo) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder.safetyCopy.encode(copy).write(to: directory.appending(path: Self.pendingRestoreName),
                                                      options: .atomic)
    }

    func cancelRestore() {
        try? fileManager.removeItem(at: directory.appending(path: Self.pendingRestoreName))
    }

    /// Replaces the store's files with the pending copy's, if one is pending; returns it. Call only while no container
    /// has the store open. The copy's files are first staged beside the store, so a failure part-way leaves the current
    /// store as it was. The request is cleared whatever happens, so a failing restore cannot repeat on every launch.
    func performPendingRestore(to storeURL: URL) throws -> SafetyCopyInfo? {
        guard let copy = pendingRestore else { return nil }
        defer { cancelRestore() }
        let folder = directory.appending(path: copy.folder, directoryHint: .isDirectory)
        let storeFolder = storeURL.deletingLastPathComponent()
        var staged: [(URL, URL)] = []
        do {
            for name in copy.files.keys.sorted() {
                let source = folder.appending(path: name)
                let target = storeFolder.appending(path: name)
                let temporary = storeFolder.appending(path: ".restoring-\(name)")
                if fileManager.fileExists(atPath: temporary.path) { try fileManager.removeItem(at: temporary) }
                try copyFile(source, temporary)
                guard try size(of: temporary) == copy.files[name] else { throw SafetyCopyError.incomplete(name) }
                staged.append((temporary, target))
            }
        } catch {
            for (temporary, _) in staged { try? fileManager.removeItem(at: temporary) }
            throw error
        }
        // The current files go; the copy's take their place. A side file the copy has none of (it was taken with an
        // empty write-ahead log) must not survive next to the restored store.
        for current in Self.storeFiles(for: storeURL) where fileManager.fileExists(atPath: current.path) {
            try fileManager.removeItem(at: current)
        }
        for (temporary, target) in staged { try fileManager.moveItem(at: temporary, to: target) }
        return copy
    }

    // MARK: Helpers

    static func folderName(for date: Date) -> String {
        let format = ISO8601DateFormatter()
        format.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        return format.string(from: date).replacingOccurrences(of: ":", with: "-")
    }

    private func size(of url: URL) throws -> Int64 {
        (try fileManager.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
    }
}

/// What launch does before the store opens (`WorkoutTrackerApp`): a pending restore first; otherwise a copy when the
/// format is about to change. A copy that fails stops the open — the user decides (try again, or continue without one).
enum SafetyCopyLaunch {
    enum Outcome: Equatable {
        /// Open the store. `restored`: the copy just put back; `copied`: the copy just made; `restoreFailure`: a pending
        /// restore that could not be carried out (the current data stays).
        case open(restored: SafetyCopyInfo?, copied: SafetyCopyInfo?, restoreFailure: String?)
        /// Do not open yet: the copy before a format change failed.
        case copyFailed(String)
    }

    /// `forceCopy` stands in for a format change (a Debug-only rehearsal on the Simulator).
    static func run(storeURL: URL, copies: SafetyCopies, model: NSManagedObjectModel?, appVersion: String,
                    forceCopy: Bool = false, now: Date = .now) -> Outcome {
        var restoreFailure: String?
        do {
            if let restored = try copies.performPendingRestore(to: storeURL) {
                // The restored files are themselves a kept copy: no second copy of them before this open.
                return .open(restored: restored, copied: nil, restoreFailure: nil)
            }
        } catch {
            restoreFailure = error.localizedDescription
        }
        guard forceCopy || SafetyCopies.storeNeedsCopy(at: storeURL, model: model, fileManager: copies.fileManager) else {
            return .open(restored: nil, copied: nil, restoreFailure: restoreFailure)
        }
        do {
            let copy = try copies.make(from: storeURL, now: now, appVersion: appVersion)
            return .open(restored: nil, copied: copy, restoreFailure: restoreFailure)
        } catch {
            return .copyFailed(error.localizedDescription)
        }
    }
}

private extension JSONEncoder {
    static var safetyCopy: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return encoder
    }
}

private extension JSONDecoder {
    static var safetyCopy: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
