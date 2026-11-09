import CoreData
import Foundation
import Observation
import SwiftData

/// Nutrition N1: opens the user's store only after the safety copy (`SafetyCopyLaunch`). When the copy before a format
/// change fails, the store stays closed until the user chooses Try Again or Continue Without a Copy
/// (`SafetyCopyFailedView`); a restore chosen in Settings waits for the next launch behind `SafetyRestorePendingView`.
@MainActor @Observable
final class StoreGate {
    /// The open store; nil only while the copy failure waits for the user.
    private(set) var container: ModelContainer?
    private(set) var copyFailure: String?
    /// The copy waiting to be restored at the next launch.
    private(set) var pendingRestore: SafetyCopyInfo?
    /// The copy restored at this launch (the app says so once).
    var restoredThisLaunch: SafetyCopyInfo?

    let copies: SafetyCopies
    @ObservationIgnored private let attemptCopy: () -> SafetyCopyLaunch.Outcome
    @ObservationIgnored private let openStore: () -> ModelContainer

    init(copies: SafetyCopies, attemptCopy: @escaping () -> SafetyCopyLaunch.Outcome,
         openStore: @escaping () -> ModelContainer) {
        self.copies = copies
        self.attemptCopy = attemptCopy
        self.openStore = openStore
        apply(attemptCopy())
    }

    func tryAgain() { apply(attemptCopy()) }

    func continueWithoutCopy() {
        copyFailure = nil
        latestCopy = copies.list().first
        container = openStore()
    }

    func scheduleRestore(_ copy: SafetyCopyInfo) throws {
        try copies.scheduleRestore(copy)
        UserDefaults.standard.removeObject(forKey: Self.restoreFailureKey)
        pendingRestore = copy
    }

    func cancelRestore() {
        copies.cancelRestore()
        pendingRestore = nil
    }

    /// Settings shows the newest copy (the one from before the latest format change). Read at launch, the only time
    /// a copy is made or pruned.
    private(set) var latestCopy: SafetyCopyInfo?

    /// A restore that could not be carried out at launch; shown in Settings until another restore is chosen.
    static let restoreFailureKey = "safetyCopy.restoreFailure"

    private func apply(_ outcome: SafetyCopyLaunch.Outcome) {
        switch outcome {
        case let .copyFailed(message):
            copyFailure = message
        case let .open(restored, _, restoreFailure):
            if let restoreFailure { UserDefaults.standard.set(restoreFailure, forKey: Self.restoreFailureKey) }
            if restored != nil { UserDefaults.standard.removeObject(forKey: Self.restoreFailureKey) }
            restoredThisLaunch = restored
            copyFailure = nil
            latestCopy = copies.list().first
            container = openStore()
        }
    }
}

extension StoreGate {
    /// The gate for this launch: the user's store behind the safety copy, or a UI test's throwaway store.
    static func forThisLaunch(prepare: @escaping (ModelContainer) -> Void) -> StoreGate {
        let arguments = ProcessInfo.processInfo.arguments
        if WorkoutTrackerStore.isUITestReset {
            let copies = SafetyCopies(directory: URL.cachesDirectory.appending(path: "UITestSafetyCopies",
                                                                                 directoryHint: .isDirectory))
            try? FileManager.default.removeItem(at: copies.directory)
            if arguments.contains(SafetyCopyFixture.copyArgument) { SafetyCopyFixture.seed(copies) }
            let fails = arguments.contains(SafetyCopyFixture.failArgument)
            return StoreGate(copies: copies, attemptCopy: {
                fails ? .copyFailed(SafetyCopyFixture.failureMessage) : .open(restored: nil, copied: nil, restoreFailure: nil)
            }, openStore: {
                do {
                    let container = try WorkoutTrackerStore.makeUITestContainer()
                    prepare(container)
                    return container
                } catch { fatalError("Failed to create ModelContainer: \(error)") }
            })
        }
        let copies = WorkoutTrackerStore.safetyCopies
        let storeURL = WorkoutTrackerStore.defaultStoreURL
        #if DEBUG
        // Debug builds only: `-safetyCopyRehearsal` treats this launch as a format change (the Simulator rehearsal).
        let forceCopy = arguments.contains("-safetyCopyRehearsal")
        #else
        let forceCopy = false
        #endif
        return StoreGate(copies: copies, attemptCopy: {
            SafetyCopyLaunch.run(
                storeURL: storeURL, copies: copies,
                model: NSManagedObjectModel.makeManagedObjectModel(for: WorkoutTrackerStore.modelTypes),
                appVersion: WorkoutTrackerStore.appVersion, forceCopy: forceCopy)
        }, openStore: {
            do {
                let container = try WorkoutTrackerStore.makeContainer()
                prepare(container)
                return container
            } catch { fatalError("Failed to create ModelContainer: \(error)") }
        })
    }
}

/// UI-test stand-ins (only beside `-uiTestReset`): a kept copy for the Settings row, or a failed copy at launch.
enum SafetyCopyFixture {
    static let copyArgument = "-uiTestSafetyCopy"
    static let failArgument = "-uiTestSafetyCopyFails"
    static let failureMessage = SafetyCopyError.notEnoughSpace(needed: 48_000_000, available: 12_000_000)
        .localizedDescription
    /// 9 November 2026, 1:30 PM in the simulator's time zone — fixed, so captures do not change day to day.
    static var date: Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 13, minute: 30)) ?? .now
    }

    static func seed(_ copies: SafetyCopies) {
        let info = SafetyCopyInfo(folder: SafetyCopies.folderName(for: date), date: date, appVersion: "0.1.0 (10)",
                                  files: ["default.store": 4])
        let folder = copies.directory.appending(path: info.folder, directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? Data("copy".utf8).write(to: folder.appending(path: "default.store"))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try? encoder.encode(info).write(to: folder.appending(path: SafetyCopies.manifestName))
    }
}
