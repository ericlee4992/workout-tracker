import CoreData
import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

private final class SensorWriteCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var rowIDs: Set<String> = []
    private var saves = 0
    func observe(_ note: Notification) {
        let objects = note.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? []
        let ids = objects.filter { $0.entity.name?.hasSuffix("WorkoutSensorSample") == true }
            .map { $0.objectID.uriRepresentation().absoluteString }
        guard !ids.isEmpty else { return }
        lock.lock(); defer { lock.unlock() }
        rowIDs.formUnion(ids); saves += 1
    }
    var result: (rows: Int, saves: Int) {
        lock.lock(); defer { lock.unlock() }
        return (rowIDs.count, saves)
    }
}

@MainActor
struct SensorCheckpointWriteTests {
    @Test func oneHourOfHeartbeatsIsPersistedAsAppendOnlyRows() throws {
        let directory = URL.temporaryDirectory.appending(path: "sensor-write-probe-\(UUID())", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let counter = SensorWriteCounter()
        let token = NotificationCenter.default.addObserver(forName: .NSManagedObjectContextDidSave, object: nil, queue: nil) { counter.observe($0) }
        defer { NotificationCenter.default.removeObserver(token) }
        var legacyBlobBytes: Int64 = 0
        var length: Int64 = 0
        let began = Date()
        try autoreleasepool {
            let container = try WorkoutTrackerStore.makeContainer(url: directory.appending(path: "probe.store"))
            let context = ModelContext(container)
            let start = Date()
            let workout = try WorkoutSession(context: context).startWorkout(at: nil, on: start)
            let monitor = HeartRateMonitor(provider: DisabledHeartRateProvider())
            let recorder = CardioRecorder(collectsDeviceSensors: false)
            recorder.attach(to: workout, monitor: monitor)
            for second in 0..<3_600 {
                let sample = HeartRateSample(bpm: 120, date: start.addingTimeInterval(Double(second)), source: .fixture)
                length += Int64(try JSONEncoder().encode(sample).count + 1)
                legacyBlobBytes += length
                monitor.ingestForTesting(sample)
                recorder.refresh()
            }
            recorder.stop()
            #expect(try context.fetchCount(FetchDescriptor<WorkoutSensorSample>()) == 3_600)
            #expect(workout.checkpointSamples.count == 3_600)
        }
        let result = counter.result
        #expect(result.rows == 3_600)
        let bytes = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])
            .reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
        print("SENSOR_CHECKPOINT_WRITE_PROBE rows=\(result.rows) insert_save_notifications=\(result.saves) retained_store_bytes=\(bytes) legacy_repeated_blob_payload_bytes=\(legacyBlobBytes) elapsed_seconds=\(Date().timeIntervalSince(began))")
    }
}
