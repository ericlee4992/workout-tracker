import Foundation
import SwiftData

enum CardioActivity: String, Codable, CaseIterable, Identifiable, Sendable {
    case indoorWalk, indoorRun, indoorCycle, elliptical, rowing, stairStepper
    case outdoorWalk, outdoorRun, outdoorCycle
    var id: String { rawValue }
    var name: String {
        switch self {
        case .indoorWalk: "Indoor Walk"
        case .indoorRun: "Indoor Run"
        case .indoorCycle: "Indoor Cycle"
        case .elliptical: "Elliptical"
        case .rowing: "Rowing"
        case .stairStepper: "Stair Stepper"
        case .outdoorWalk: "Outdoor Walk"
        case .outdoorRun: "Outdoor Run"
        case .outdoorCycle: "Outdoor Cycle"
        }
    }
    var isOutdoor: Bool { [.outdoorWalk, .outdoorRun, .outdoorCycle].contains(self) }
    var isWalkingOrRunning: Bool { [.indoorWalk, .indoorRun, .outdoorWalk, .outdoorRun].contains(self) }
    var usesSpeed: Bool { [.indoorCycle, .outdoorCycle].contains(self) }
}

enum CardioDistanceUnit: String, Codable, CaseIterable, Identifiable, Sendable {
    case km, mi
    var id: String { rawValue }
    var metersPerUnit: Double { self == .km ? 1_000 : 1_609.344 }
    static var localeDefault: Self { Locale.current.measurementSystem == .us ? .mi : .km }
}

enum CardioDistanceSource: String, Codable, Sendable {
    case healthKit, phoneMotion, gps, mixed
    var label: String {
        switch self {
        case .healthKit: "HealthKit estimate"
        case .phoneMotion: "Phone motion estimate"
        case .gps: "GPS"
        case .mixed: "Mixed distance sources"
        }
    }
}

/// Alternative cumulative readings over the SAME app-owned sensor epoch. Pauses
/// do not create another epoch: a late HealthKit total already covers earlier motion.
struct CardioDistanceSpan: Codable, Equatable, Sendable {
    var start: Date
    var readings: [String: Double] = [:]
    var updatedAt: [String: Date] = [:]
    var selectedSourceRawValue: String?
    var selectedSource: CardioDistanceSource? { selectedSourceRawValue.flatMap(CardioDistanceSource.init(rawValue:)) }
    var meters: Double? { selectedSource.flatMap { readings[$0.rawValue] } }
    mutating func selectSource(asOf now: Date) {
        let priority: [CardioDistanceSource] = [.gps, .healthKit, .phoneMotion]
        if let fresh = priority.first(where: { source in
            guard readings[source.rawValue] != nil, let date = updatedAt[source.rawValue] else { return false }
            return (-2...15).contains(now.timeIntervalSince(date))
        }) {
            selectedSourceRawValue = fresh.rawValue
        } else if selectedSource == nil {
            // Distance totals remain useful after their stream goes quiet. Only
            // current pace expires; do not discard a delayed cumulative measurement.
            selectedSourceRawValue = priority.first { readings[$0.rawValue] != nil }?.rawValue
        }
    }
}

struct CardioInterval: Codable, Equatable, Sendable {
    var start: Date
    var end: Date
}

struct CardioRoutePoint: Codable, Equatable, Sendable, Identifiable {
    var id: UUID = UUID()
    var latitude: Double
    var longitude: Double
    var date: Date
    var accuracy: Double
    /// Different portions must never be joined across a pause or GPS outage.
    var portion: UUID
}

enum CardioMath {
    static func pace(seconds: Double, meters: Double?, unit: CardioDistanceUnit) -> Double? {
        guard let meters, meters.isFinite, meters > 0, seconds.isFinite, seconds > 0 else { return nil }
        return seconds / meters * unit.metersPerUnit
    }
    static func pace(speed: Double?, unit: CardioDistanceUnit) -> Double? {
        guard let speed, speed.isFinite, speed > 0 else { return nil }
        return unit.metersPerUnit / speed
    }
    static func paceText(_ seconds: Double?) -> String {
        guard let seconds, seconds.isFinite, seconds > 0, seconds < 360_000 else { return "—" }
        let value = Int(seconds.rounded())
        return String(format: "%d:%02d", value / 60, value % 60)
    }
    static func meters(between first: CardioRoutePoint, and second: CardioRoutePoint) -> Double {
        let factor = Double.pi / 180
        let dlat = (second.latitude - first.latitude) * factor
        let dlon = (second.longitude - first.longitude) * factor
        let a = pow(sin(dlat / 2), 2) + cos(first.latitude * factor) * cos(second.latitude * factor) * pow(sin(dlon / 2), 2)
        return 6_371_000 * 2 * asin(sqrt(min(1, max(0, a))))
    }
    static func valid(_ point: CardioRoutePoint, asOf now: Date) -> Bool {
        point.latitude.isFinite && point.longitude.isFinite && point.accuracy.isFinite
            && abs(point.latitude) <= 90 && abs(point.longitude) <= 180
            && point.accuracy >= 0 && point.accuracy <= 50
            && now.timeIntervalSince(point.date) >= -2 && now.timeIntervalSince(point.date) <= 15
    }
}

/// A cardio occurrence is not a strength set: mixing them would corrupt volume,
/// records and equipment history. Optional relationship/defaults preserve CloudKit compatibility.
@Model
final class CardioSegment {
    var id: UUID = UUID()
    var order: Int = 0
    var activityRawValue: String = CardioActivity.indoorWalk.rawValue
    var startedAt: Date = Date()
    var endedAt: Date?
    var activeStartedAt: Date?
    var accumulatedActiveSeconds: Double = 0
    var lastCheckpointAt: Date = Date()
    var intervalsData: Data?
    var routeData: Data?
    var distanceSpansData: Data?
    var automaticDistanceMeters: Double?
    var distanceSourceRawValue: String?
    var manualDistanceValue: Double?
    var manualDistanceUnitRawValue: String?
    var displayUnitRawValue: String = CardioDistanceUnit.km.rawValue
    var averageHeartRate: Int?
    var maxHeartRate: Int?
    var heartRateTotal: Int = 0
    var heartRateCount: Int = 0
    var lastHeartRateSampleID: UUID?
    var activeEnergyKilocalories: Double?
    var basalEnergyKilocalories: Double?
    var workout: Workout?

    init(activity: CardioActivity, order: Int, workout: Workout, at date: Date = .now,
         unit: CardioDistanceUnit = .localeDefault) {
        self.activityRawValue = activity.rawValue
        self.order = order
        self.workout = workout
        self.startedAt = date
        self.activeStartedAt = date
        self.lastCheckpointAt = date
        self.displayUnitRawValue = unit.rawValue
    }
    var activity: CardioActivity { CardioActivity(rawValue: activityRawValue) ?? .indoorWalk }
    var unit: CardioDistanceUnit { CardioDistanceUnit(rawValue: displayUnitRawValue) ?? .km }
    var source: CardioDistanceSource? { distanceSourceRawValue.flatMap(CardioDistanceSource.init(rawValue:)) }
    var isRunning: Bool { endedAt == nil && activeStartedAt != nil }
    var distanceMeters: Double? {
        if let value = manualDistanceValue, let raw = manualDistanceUnitRawValue,
           let unit = CardioDistanceUnit(rawValue: raw) { return value * unit.metersPerUnit }
        return automaticDistanceMeters
    }
    var distanceLabel: String { manualDistanceValue != nil ? "Entered distance" : source?.label ?? "No distance source" }
    var distanceSpans: [CardioDistanceSpan] {
        get { distanceSpansData.flatMap { try? JSONDecoder().decode([CardioDistanceSpan].self, from: $0) } ?? [] }
        set { distanceSpansData = try? JSONEncoder().encode(newValue) }
    }
    func acceptDistance(_ meters: Double, source: CardioDistanceSource, since epoch: Date,
                        at date: Date = .now, asOf now: Date = .now) {
        guard isRunning, epoch >= startedAt, meters.isFinite, meters >= 0, source != .mixed else { return }
        var spans = distanceSpans
        if !spans.contains(where: { $0.start == epoch }) { spans.append(CardioDistanceSpan(start: epoch)) }
        guard let index = spans.firstIndex(where: { $0.start == epoch }) else { return }
        if let previous = spans[index].updatedAt[source.rawValue], date < previous { return }
        spans[index].readings[source.rawValue] = max(spans[index].readings[source.rawValue] ?? 0, meters)
        spans[index].updatedAt[source.rawValue] = date
        spans[index].selectSource(asOf: now)
        distanceSpans = spans
        recomputeDistance()
    }
    func refreshDistanceSelection(since epoch: Date, asOf date: Date) {
        guard isRunning else { return }
        var spans = distanceSpans
        guard let index = spans.firstIndex(where: { $0.start == epoch }) else { return }
        // Closed epochs keep their logged source; only the current recording may
        // change sources. A future read of History must never reselect by wall clock.
        spans[index].selectSource(asOf: date)
        distanceSpans = spans
        recomputeDistance()
    }
    private func recomputeDistance() {
        let spans = distanceSpans
        let values = spans.compactMap(\.meters)
        automaticDistanceMeters = values.isEmpty ? nil : values.reduce(0, +)
        let sources = Set(spans.compactMap { $0.selectedSource?.rawValue })
        distanceSourceRawValue = sources.count > 1 ? CardioDistanceSource.mixed.rawValue : sources.first
    }
    var intervals: [CardioInterval] {
        get { intervalsData.flatMap { try? JSONDecoder().decode([CardioInterval].self, from: $0) } ?? [] }
        set { intervalsData = try? JSONEncoder().encode(newValue) }
    }
    var route: [CardioRoutePoint] {
        get { routeData.flatMap { try? JSONDecoder().decode([CardioRoutePoint].self, from: $0) } ?? [] }
        set { routeData = try? JSONEncoder().encode(newValue) }
    }
    func activeDuration(at date: Date = .now) -> Double {
        max(0, accumulatedActiveSeconds) + (activeStartedAt.map { max(0, date.timeIntervalSince($0)) } ?? 0)
    }
    var hasRecordedActivity: Bool { activeDuration(at: endedAt ?? lastCheckpointAt) >= 1 || (distanceMeters ?? 0) > 0 }
    func pause(at date: Date) {
        guard endedAt == nil, let start = activeStartedAt else { return }
        let end = max(start, date)
        accumulatedActiveSeconds += end.timeIntervalSince(start)
        intervals.append(CardioInterval(start: start, end: end))
        activeStartedAt = nil
        lastCheckpointAt = end
    }
    func resume(at date: Date) {
        guard endedAt == nil, activeStartedAt == nil else { return }
        activeStartedAt = max(date, lastCheckpointAt)
        lastCheckpointAt = activeStartedAt!
    }
    func end(at date: Date) {
        guard endedAt == nil else { return }
        pause(at: date)
        endedAt = max(date, lastCheckpointAt)
    }
    func record(_ sample: HeartRateSample, at now: Date = .now) {
        guard let start = activeStartedAt, endedAt == nil, sample.bpm > 0, sample.date >= start,
              !sample.isStale(asOf: now), sample.date <= now.addingTimeInterval(2), sample.id != lastHeartRateSampleID else { return }
        lastHeartRateSampleID = sample.id
        heartRateCount += 1
        heartRateTotal += sample.bpm
        averageHeartRate = Int((Double(heartRateTotal) / Double(heartRateCount)).rounded())
        maxHeartRate = max(maxHeartRate ?? sample.bpm, sample.bpm)
    }
}

extension Workout {
    var checkpointSamples: [HeartRateSample] {
        SensorCheckpointCodec.decode(sensorSamplesData)
    }
    var sensorConfiguration: WorkoutSensorConfiguration {
        if let segment = unfinishedCardio {
            return .init(segmentID: segment.id, activity: segment.activity, paused: !segment.isRunning)
        }
        // Ending cardio-only recording must not manufacture a strength workout
        // while the user reads the result or reaches for Finish.
        if !orderedCardio.isEmpty, entries?.isEmpty != false { return .idle }
        return .lifting
    }
    var orderedCardio: [CardioSegment] {
        (cardioSegments ?? []).filter { !$0.isDeleted }
            .sorted { ($0.order, $0.id.uuidString) < ($1.order, $1.id.uuidString) }
    }
    var unfinishedCardio: CardioSegment? { orderedCardio.last { $0.endedAt == nil } }
    var recordedCardio: [CardioSegment] { orderedCardio.filter(\.hasRecordedActivity) }
}

enum CardioSessionError: LocalizedError {
    case finishedWorkout, invalidDistance
    var errorDescription: String? {
        switch self {
        case .finishedWorkout: "This workout has already finished."
        case .invalidDistance: "Enter a distance of zero or more."
        }
    }
}

struct CardioSession {
    let context: ModelContext
    @discardableResult
    func start(_ activity: CardioActivity, in workout: Workout, at date: Date = .now,
               unit: CardioDistanceUnit = .localeDefault) throws -> CardioSegment {
        guard !workout.isDeleted, workout.finishedAt == nil else { throw CardioSessionError.finishedWorkout }
        for segment in workout.orderedCardio where segment.endedAt == nil { segment.end(at: date) }
        try RestTimerService(context: context).skip(workout)
        let segment = CardioSegment(activity: activity, order: (workout.orderedCardio.map(\.order).max() ?? -1) + 1,
                                    workout: workout, at: date, unit: unit)
        context.insert(segment)
        try context.save()
        return segment
    }
    func pause(_ segment: CardioSegment, at date: Date = .now) throws {
        guard !segment.isDeleted, segment.workout?.finishedAt == nil else { throw CardioSessionError.finishedWorkout }
        segment.pause(at: date); try context.save()
    }
    func resume(_ segment: CardioSegment, at date: Date = .now) throws {
        guard !segment.isDeleted, segment.workout?.finishedAt == nil else { throw CardioSessionError.finishedWorkout }
        segment.resume(at: date); try context.save()
    }
    func end(_ segment: CardioSegment, at date: Date = .now) throws {
        guard !segment.isDeleted else { return }
        segment.end(at: date); try context.save()
    }
    func enterDistance(_ text: String, unit: CardioDistanceUnit, for segment: CardioSegment) throws {
        guard !segment.isDeleted else { throw CardioSessionError.finishedWorkout }
        let oldValue = segment.manualDistanceValue
        let oldUnit = segment.manualDistanceUnitRawValue
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            segment.manualDistanceValue = nil; segment.manualDistanceUnitRawValue = nil
        } else {
            guard let value = Double(trimmed.replacingOccurrences(of: ",", with: ".")), value.isFinite, value >= 0, (value * unit.metersPerUnit).isFinite
            else { throw CardioSessionError.invalidDistance }
            segment.manualDistanceValue = value
            segment.manualDistanceUnitRawValue = unit.rawValue
        }
        segment.displayUnitRawValue = unit.rawValue
        if segment.workout?.finishedAt != nil,
           oldValue != segment.manualDistanceValue || oldUnit != segment.manualDistanceUnitRawValue {
            segment.workout?.historyEditedAt = .now
        }
        try context.save()
    }
    /// A relaunch cannot claim measurements in an unobserved interval.
    func recover(_ workout: Workout) throws {
        for segment in workout.orderedCardio where segment.isRunning {
            segment.pause(at: segment.lastCheckpointAt)
        }
        try context.save()
    }
}
