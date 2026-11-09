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

        /// A fixture already on disk (one that was moved).
        init(root: URL) { self.root = root }

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
        try fixture.copies.cancelRestore()
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

    // MARK: Restore failures (codex-review-n1 #1, #2)

    /// A copy and a newer store: "before" in the copy, "before" + "after" in the store, the copy scheduled.
    func preparedRestore() throws -> (Fixture, SafetyCopyInfo) {
        let fixture = try Fixture()
        try fixture.addItems(["before"])
        let copy = try fixture.copies.make(from: fixture.storeURL, appVersion: "v")
        try fixture.addItems(["after"])
        try fixture.copies.scheduleRestore(copy)
        return (fixture, copy)
    }

    func storeFolderNames(_ fixture: Fixture) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: fixture.storeURL.deletingLastPathComponent().path).sorted()
    }

    /// Fails the `failing`-th move; other moves go through.
    func failingMove(_ failing: Int) -> (URL, URL) throws -> Void {
        var calls = 0
        return { source, target in
            calls += 1
            if calls == failing { throw CocoaError(.fileWriteUnknown) }
            try FileManager.default.moveItem(at: source, to: target)
        }
    }

    @Test(arguments: [1, 2])
    func aSwapThatFailsIsUndoneAndTodaysDataStays(failingMove step: Int) throws {
        // Step 1 sets the current store aside; step 2 moves the copy in.
        let (fixture, _) = try preparedRestore()
        var copies = fixture.copies
        copies.moveFile = failingMove(step)
        let outcome = SafetyCopyLaunch.run(storeURL: fixture.storeURL, copies: copies, model: Self.itemModel, appVersion: "v")
        guard case let .open(nil, nil, failure?) = outcome else { Issue.record("\(outcome)"); return }
        #expect(!failure.isEmpty)
        #expect(try fixture.itemNames() == ["after", "before"], "today's data, not the copy, not an empty store")
        #expect(copies.pendingRestore == nil, "the request is not retried")
        #expect(!copies.restoreWasInterrupted)
        #expect(try !storeFolderNames(fixture).contains { $0.hasPrefix(".") })
    }

    /// The state a crash leaves after the store was set aside and the copy's file moved in: the journal (tag `T1`),
    /// the store's files under `.replaced-T1-…`, the copy's `Data.store` in place, the request consumed.
    func crashMidSwap(_ fixture: Fixture, _ copy: SafetyCopyInfo) throws {
        let folder = fixture.storeURL.deletingLastPathComponent()
        let originals = SafetyCopies.storeFiles(for: fixture.storeURL).map(\.lastPathComponent)
            .filter { FileManager.default.fileExists(atPath: folder.appending(path: $0).path) }
        let journal: [String: Any] = ["tag": "T1", "originals": originals, "placed": copy.files.keys.sorted()]
        try JSONSerialization.data(withJSONObject: journal)
            .write(to: fixture.copies.directory.appending(path: SafetyCopies.journalName))
        for name in originals {
            try FileManager.default.moveItem(at: folder.appending(path: name), to: folder.appending(path: ".replaced-T1-\(name)"))
        }
        try FileManager.default.copyItem(at: fixture.copies.directory.appending(path: copy.folder).appending(path: "Data.store"),
                                         to: folder.appending(path: "Data.store"))
        try fixture.copies.cancelRestore()
    }

    @Test func aSwapInterruptedByACrashIsUndoneAtTheNextLaunch() throws {
        let (fixture, copy) = try preparedRestore()
        try crashMidSwap(fixture, copy)
        let outcome = SafetyCopyLaunch.run(storeURL: fixture.storeURL, copies: fixture.copies, model: Self.itemModel,
                                           appVersion: "v")
        guard case .open(nil, nil, _?) = outcome else { Issue.record("\(outcome)"); return }
        #expect(try fixture.itemNames() == ["after", "before"])
        #expect(!fixture.copies.restoreWasInterrupted)
        #expect(try !storeFolderNames(fixture).contains { $0.hasPrefix(".") })
    }

    /// codex-review-n1b #3: the container moved between the crash and the next launch.
    @Test func anInterruptedSwapIsUndoneWhereTheStoreIsNow() throws {
        let (fixture, copy) = try preparedRestore()
        try crashMidSwap(fixture, copy)
        let moved = FileManager.default.temporaryDirectory.appending(path: "SafetyCopyTests-moved-\(UUID().uuidString)")
        try FileManager.default.moveItem(at: fixture.root, to: moved)
        let storeURL = moved.appending(path: "store/Data.store")
        let copies = SafetyCopies(directory: moved.appending(path: "SafetyCopies", directoryHint: .isDirectory))
        let outcome = SafetyCopyLaunch.run(storeURL: storeURL, copies: copies, model: Self.itemModel, appVersion: "v")
        guard case .open(nil, nil, _?) = outcome else { Issue.record("\(outcome)"); return }
        let reopened = Fixture(root: moved)
        #expect(try reopened.itemNames() == ["after", "before"])
        #expect(!copies.restoreWasInterrupted)
    }

    /// codex-review-n1b #2: a journal that is there but cannot be read keeps the store closed — it is not "nothing to
    /// undo" — and the set-aside store waits for the next try.
    @Test func aJournalThatCannotBeReadKeepsTheStoreClosed() throws {
        let (fixture, copy) = try preparedRestore()
        try crashMidSwap(fixture, copy)
        let journal = fixture.copies.directory.appending(path: SafetyCopies.journalName)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: journal.path)
        let outcome = SafetyCopyLaunch.run(storeURL: fixture.storeURL, copies: fixture.copies, model: Self.itemModel,
                                           appVersion: "v")
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: journal.path)
        guard case .blocked = outcome else { Issue.record("\(outcome)"); return }
        #expect(fixture.copies.restoreWasInterrupted)
        #expect(try storeFolderNames(fixture).contains { $0.hasPrefix(".replaced-T1-") })
        // Readable again: the next try undoes it.
        let retried = SafetyCopyLaunch.run(storeURL: fixture.storeURL, copies: fixture.copies, model: Self.itemModel,
                                           appVersion: "v")
        guard case .open(nil, nil, _?) = retried else { Issue.record("\(retried)"); return }
        #expect(try fixture.itemNames() == ["after", "before"])
    }

    @Test func aDamagedJournalKeepsTheStoreClosed() throws {
        let (fixture, copy) = try preparedRestore()
        try crashMidSwap(fixture, copy)
        let journal: [String: Any] = ["tag": "T1", "originals": ["../../elsewhere"], "placed": []]
        try JSONSerialization.data(withJSONObject: journal)
            .write(to: fixture.copies.directory.appending(path: SafetyCopies.journalName))
        let outcome = SafetyCopyLaunch.run(storeURL: fixture.storeURL, copies: fixture.copies, model: Self.itemModel,
                                           appVersion: "v")
        guard case .blocked = outcome else { Issue.record("\(outcome)"); return }
    }

    /// codex-review-n1b #1: an earlier restore's set-aside files that could not be swept are never taken for a later
    /// restore's; that later restore failing part-way still returns to the data logged since.
    @Test func aLaterRestoreThatFailsReturnsToTheDataLoggedSince() throws {
        let (fixture, copy) = try preparedRestore()
        var keepsLeftovers = fixture.copies
        keepsLeftovers.removeFile = { url in
            if url.lastPathComponent.hasPrefix(".replaced-") { throw CocoaError(.fileWriteNoPermission) }
            try FileManager.default.removeItem(at: url)
        }
        #expect(try keepsLeftovers.performPendingRestore(to: fixture.storeURL) == copy)
        #expect(try storeFolderNames(fixture).contains { $0.hasPrefix(".replaced-") }, "the first restore's leftovers stay")
        try fixture.addItems(["logged after the restore"])
        try fixture.copies.scheduleRestore(copy)
        var failing = keepsLeftovers
        failing.moveFile = failingMove(2)
        let outcome = SafetyCopyLaunch.run(storeURL: fixture.storeURL, copies: failing, model: Self.itemModel, appVersion: "v")
        guard case .open(nil, nil, _?) = outcome else { Issue.record("\(outcome)"); return }
        #expect(try fixture.itemNames() == ["before", "logged after the restore"])
    }

    @Test func aSwapThatCannotBeUndoneKeepsTheStoreClosedUntilItIs() throws {
        let (fixture, _) = try preparedRestore()
        var broken = fixture.copies
        var calls = 0
        broken.moveFile = { source, target in
            calls += 1
            if calls >= 2 { throw CocoaError(.fileWriteUnknown) }   // the swap and its undo both fail
            try FileManager.default.moveItem(at: source, to: target)
        }
        let outcome = SafetyCopyLaunch.run(storeURL: fixture.storeURL, copies: broken, model: Self.itemModel, appVersion: "v")
        guard case .blocked = outcome else { Issue.record("\(outcome)"); return }
        #expect(broken.restoreWasInterrupted, "the journal stays for the next try")

        // Try Again with a working file system: undone, today's data back, the store may open.
        let retried = SafetyCopyLaunch.run(storeURL: fixture.storeURL, copies: fixture.copies, model: Self.itemModel,
                                           appVersion: "v")
        guard case .open(nil, nil, _?) = retried else { Issue.record("\(retried)"); return }
        #expect(try fixture.itemNames() == ["after", "before"])
    }

    @Test func aRequestThatCannotBeClearedLeavesTheStoreUntouched() throws {
        let (fixture, copy) = try preparedRestore()
        var copies = fixture.copies
        copies.removeFile = { url in
            if url.lastPathComponent == SafetyCopies.pendingRestoreName { throw CocoaError(.fileWriteNoPermission) }
            try FileManager.default.removeItem(at: url)
        }
        // The request stays armed, so the store must not open: the launch is blocked, the data untouched.
        let outcome = SafetyCopyLaunch.run(storeURL: fixture.storeURL, copies: copies, model: Self.itemModel, appVersion: "v")
        guard case .blocked = outcome else { Issue.record("\(outcome)"); return }
        #expect(try fixture.itemNames() == ["after", "before"])
        #expect(copies.pendingRestore == copy)
        #expect(try !storeFolderNames(fixture).contains { $0.hasPrefix(".") })
    }

    @Test func aCancelThatFailsSaysSo() throws {
        let (fixture, copy) = try preparedRestore()
        var copies = fixture.copies
        copies.removeFile = { _ in throw CocoaError(.fileWriteNoPermission) }
        #expect(throws: (any Error).self) { try copies.cancelRestore() }
        #expect(copies.pendingRestore == copy, "still armed, and the caller knows")
    }

    @Test func aCommittedSwapLeavesNothingBehind() throws {
        let (fixture, copy) = try preparedRestore()
        #expect(try fixture.copies.performPendingRestore(to: fixture.storeURL) == copy)
        #expect(try fixture.itemNames() == ["before"])
        #expect(!fixture.copies.restoreWasInterrupted)
        #expect(try !storeFolderNames(fixture).contains { $0.hasPrefix(".") })
    }
}
