import CoreData
import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

/// Nutrition N1: the safety copy against real SQLite stores in a temporary folder.
///
/// The stores are written through Core Data, which can close a store when asked (`remove`): SwiftData has no public
/// close, and a container it still holds checkpoints its write-ahead log while a test copies the files — the copy then
/// rightly reports itself incomplete. The copy and restore work on the files, whichever framework wrote them; the
/// Simulator rehearsal (ticket N1) runs them on the app's own SwiftData store.
@Suite struct SafetyCopyTests {
    /// A one-entity model ("Item", a name) — the test's stand-in data.
    static let itemModel: NSManagedObjectModel = {
        let name = NSAttributeDescription()
        name.name = "name"
        name.attributeType = .stringAttributeType
        name.isOptional = false
        let item = NSEntityDescription()
        item.name = "Item"
        item.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        item.properties = [name]
        let model = NSManagedObjectModel()
        model.entities = [item]
        return model
    }()
    static let appModel = NSManagedObjectModel.makeManagedObjectModel(for: WorkoutTrackerStore.modelTypes)

    struct Fixture {
        let root: URL
        var storeURL: URL { root.appending(path: "store/Data.store") }
        var copies: SafetyCopies { SafetyCopies(directory: root.appending(path: "SafetyCopies", directoryHint: .isDirectory)) }

        init() throws {
            root = FileManager.default.temporaryDirectory.appending(path: "SafetyCopyTests-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: root.appending(path: "store"), withIntermediateDirectories: true)
        }

        /// Opens the store with `model`, runs `body`, and closes the store before returning.
        func withStore<T>(_ model: NSManagedObjectModel = SafetyCopyTests.itemModel,
                          _ body: (NSManagedObjectContext) throws -> T) throws -> T {
            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
            let store = try coordinator.addPersistentStore(type: .sqlite, at: storeURL)
            defer { try? coordinator.remove(store) }
            let context = NSManagedObjectContext(.privateQueue)
            context.persistentStoreCoordinator = coordinator
            return try context.performAndWait { try body(context) }
        }

        func addItems(_ names: [String]) throws {
            try withStore { context in
                for name in names {
                    NSEntityDescription.insertNewObject(forEntityName: "Item", into: context).setValue(name, forKey: "name")
                }
                try context.save()
            }
        }

        func itemNames() throws -> [String] {
            try withStore { context in
                try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "Item"))
                    .compactMap { $0.value(forKey: "name") as? String }.sorted()
            }
        }
    }

    // MARK: When

    @Test func theAppsModelIsAvailableForTheCheck() {
        #expect(Self.appModel != nil)
    }

    @Test func noStoreMeansNoCopy() throws {
        let fixture = try Fixture()
        #expect(!SafetyCopies.storeNeedsCopy(at: fixture.storeURL, model: Self.appModel))
    }

    @Test func aStoreInTodaysAppFormatNeedsNoCopy() throws {
        let fixture = try Fixture()
        let model = try #require(Self.appModel)
        try fixture.withStore(model) { _ in }
        #expect(!SafetyCopies.storeNeedsCopy(at: fixture.storeURL, model: model))
    }

    @Test func aStoreInAnotherFormatNeedsACopy() throws {
        let fixture = try Fixture()
        let model = try #require(Self.appModel)
        try fixture.withStore(model) { _ in }
        // Another model stands in for an update that changes the format — both ways round.
        #expect(SafetyCopies.storeNeedsCopy(at: fixture.storeURL, model: Self.itemModel))
        let other = try Fixture()
        try other.addItems(["a"])
        #expect(SafetyCopies.storeNeedsCopy(at: other.storeURL, model: model))
    }

    @Test func anUnreadableStoreCountsAsAChange() throws {
        let fixture = try Fixture()
        try Data("not a database".utf8).write(to: fixture.storeURL)
        #expect(SafetyCopies.storeNeedsCopy(at: fixture.storeURL, model: Self.appModel))
    }

    // MARK: Copy and prune

    @Test func aCopyHoldsEveryStoreFileAndItsManifest() throws {
        let fixture = try Fixture()
        try fixture.addItems(["a", "b", "c"])
        let present = SafetyCopies.storeFiles(for: fixture.storeURL).filter { FileManager.default.fileExists(atPath: $0.path) }
        let copy = try fixture.copies.make(from: fixture.storeURL, appVersion: "0.1.0 (10)")
        #expect(Set(copy.files.keys) == Set(present.map(\.lastPathComponent)))
        #expect(copy.files.keys.contains("Data.store"))
        for file in present {
            let copied = fixture.copies.directory.appending(path: copy.folder).appending(path: file.lastPathComponent)
            #expect(FileManager.default.contentsEqual(atPath: file.path, andPath: copied.path))
        }
        #expect(fixture.copies.list() == [copy])
        #expect(copy.appVersion == "0.1.0 (10)")
    }

    @Test func onlyTheLastTwoCopiesAreKept() throws {
        let fixture = try Fixture()
        try fixture.addItems(["a"])
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let made = try (0..<3).map {
            try fixture.copies.make(from: fixture.storeURL, now: start.addingTimeInterval(Double($0) * 86_400), appVersion: "v")
        }
        #expect(fixture.copies.list() == [made[2], made[1]])
    }

    @Test func notEnoughSpaceMakesNoCopyAndLeavesNothingBehind() throws {
        let fixture = try Fixture()
        try fixture.addItems(["a"])
        var copies = fixture.copies
        copies.availableBytes = { _ in 1_000 }
        #expect(throws: SafetyCopyError.self) { try copies.make(from: fixture.storeURL, appVersion: "v") }
        #expect(copies.list().isEmpty)
        #expect(try FileManager.default.contentsOfDirectory(atPath: copies.directory.path).isEmpty)
    }

    @Test func aCopyThatFailsPartWayLeavesNoHalfCopy() throws {
        let fixture = try Fixture()
        try fixture.addItems(["a"])
        // A side file, so the store has at least two files and the second one fails.
        try Data("side".utf8).write(to: URL(fileURLWithPath: fixture.storeURL.path + "-shm"), options: .atomic)
        var copies = fixture.copies
        var calls = 0
        copies.copyFile = { source, target in
            calls += 1
            if calls == 2 { throw CocoaError(.fileWriteOutOfSpace) }
            try FileManager.default.copyItem(at: source, to: target)
        }
        #expect(throws: (any Error).self) { try copies.make(from: fixture.storeURL, appVersion: "v") }
        #expect(copies.list().isEmpty)
        #expect(try FileManager.default.contentsOfDirectory(atPath: copies.directory.path).isEmpty)
    }

    // MARK: Restore

    @Test func restoringBringsBackTheDataAsItWasWhenCopied() throws {
        let fixture = try Fixture()
        try fixture.addItems(["before 1", "before 2"])
        let copy = try fixture.copies.make(from: fixture.storeURL, appVersion: "v")
        try fixture.addItems(["after 1", "after 2", "after 3"])
        #expect(try fixture.itemNames().count == 5)

        try fixture.copies.scheduleRestore(copy)
        #expect(fixture.copies.pendingRestore == copy)
        let restored = try fixture.copies.performPendingRestore(to: fixture.storeURL)
        #expect(restored == copy)
        #expect(try fixture.itemNames() == ["before 1", "before 2"])
        #expect(fixture.copies.pendingRestore == nil)
        #expect(fixture.copies.list() == [copy], "the copy stays after it is restored")
    }

    @Test func aRestoreThatFailsKeepsTodaysDataAndIsNotRetried() throws {
        let fixture = try Fixture()
        try fixture.addItems(["before"])
        let copy = try fixture.copies.make(from: fixture.storeURL, appVersion: "v")
        try fixture.addItems(["after"])
        try fixture.copies.scheduleRestore(copy)
        var copies = fixture.copies
        copies.copyFile = { _, _ in throw CocoaError(.fileWriteOutOfSpace) }
        #expect(throws: (any Error).self) { try copies.performPendingRestore(to: fixture.storeURL) }
        #expect(try fixture.itemNames() == ["after", "before"])
        #expect(copies.pendingRestore == nil)
        let storeFolder = try FileManager.default.contentsOfDirectory(atPath: fixture.storeURL.deletingLastPathComponent().path)
        #expect(!storeFolder.contains { $0.hasPrefix(".restoring-") })
    }

    @Test func aCancelledRestoreDoesNothing() throws {
        let fixture = try Fixture()
        try fixture.addItems(["a"])
        let copy = try fixture.copies.make(from: fixture.storeURL, appVersion: "v")
        try fixture.copies.scheduleRestore(copy)
        fixture.copies.cancelRestore()
        #expect(try fixture.copies.performPendingRestore(to: fixture.storeURL) == nil)
    }

    @Test func aPendingRestoresCopyIsNeverPruned() throws {
        let fixture = try Fixture()
        try fixture.addItems(["a"])
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let oldest = try fixture.copies.make(from: fixture.storeURL, now: start, appVersion: "v")
        try fixture.copies.scheduleRestore(oldest)
        for day in 1...2 {
            try fixture.copies.make(from: fixture.storeURL, now: start.addingTimeInterval(Double(day) * 86_400), appVersion: "v")
        }
        #expect(fixture.copies.list().contains(oldest))
    }

    // MARK: Launch

    @Test func anOrdinaryLaunchMakesNoCopy() throws {
        let fixture = try Fixture()
        try fixture.addItems(["a"])
        let outcome = SafetyCopyLaunch.run(storeURL: fixture.storeURL, copies: fixture.copies,
                                           model: Self.itemModel, appVersion: "v")
        #expect(outcome == .open(restored: nil, copied: nil, restoreFailure: nil))
        #expect(fixture.copies.list().isEmpty)
    }

    @Test func aFormatChangeMakesExactlyOneCopyBeforeTheOpen() throws {
        let fixture = try Fixture()
        try fixture.addItems(["a"])
        let outcome = SafetyCopyLaunch.run(storeURL: fixture.storeURL, copies: fixture.copies,
                                           model: Self.appModel, appVersion: "v")
        guard case let .open(nil, copied?, nil) = outcome else { Issue.record("\(outcome)"); return }
        #expect(fixture.copies.list() == [copied])
    }

    @Test func aFailedCopyStopsTheOpen() throws {
        let fixture = try Fixture()
        try fixture.addItems(["a"])
        var copies = fixture.copies
        copies.availableBytes = { _ in 0 }
        let outcome = SafetyCopyLaunch.run(storeURL: fixture.storeURL, copies: copies, model: Self.itemModel,
                                           appVersion: "v", forceCopy: true)
        guard case let .copyFailed(message) = outcome else { Issue.record("\(outcome)"); return }
        #expect(message.contains("Not enough free space"))
    }

    @Test func aRestoredStoreIsNotCopiedAgainOnItsOpen() throws {
        let fixture = try Fixture()
        try fixture.addItems(["before"])
        let copy = try fixture.copies.make(from: fixture.storeURL, appVersion: "v")
        try fixture.addItems(["after"])
        try fixture.copies.scheduleRestore(copy)
        let outcome = SafetyCopyLaunch.run(storeURL: fixture.storeURL, copies: fixture.copies,
                                           model: Self.appModel, appVersion: "v")
        #expect(outcome == .open(restored: copy, copied: nil, restoreFailure: nil))
        #expect(fixture.copies.list() == [copy])
        #expect(try fixture.itemNames() == ["before"])
    }

    @Test func aFailedRestoreIsReportedAndTheLaunchStillDecidesOnACopy() throws {
        let fixture = try Fixture()
        try fixture.addItems(["a"])
        let copy = try fixture.copies.make(from: fixture.storeURL, appVersion: "v")
        try fixture.copies.scheduleRestore(copy)
        var copies = fixture.copies
        copies.copyFile = { _, _ in throw CocoaError(.fileWriteOutOfSpace) }
        let outcome = SafetyCopyLaunch.run(storeURL: fixture.storeURL, copies: copies, model: Self.itemModel, appVersion: "v")
        guard case let .open(nil, nil, failure?) = outcome else { Issue.record("\(outcome)"); return }
        #expect(!failure.isEmpty)
    }
}
