import CoreLocation
import CoreMotion
import Foundation
import Observation
import SwiftData

/// Owned by the workout's root coordinator, so minimising or locking the screen
/// does not destroy route collection. UI never owns sensors or measurement state.
@MainActor
@Observable
final class CardioRecorder: NSObject, CLLocationManagerDelegate {
    private(set) var measurementTime: Date = .now
    private(set) var currentSpeedMetersPerSecond: Double?
    private(set) var movementUpdatedAt: Date?
    private(set) var locationMessage: String?
    var errorMessage: String?
    // The active recording owns its model until stop. A weak reference can disappear
    // on minimise and drop GPS fixes even though the session is still running.
    @ObservationIgnored private var workout: Workout?
    @ObservationIgnored private weak var monitor: HeartRateMonitor?
    @ObservationIgnored private var context: ModelContext?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private let location = CLLocationManager()
    @ObservationIgnored private let pedometer = CMPedometer()
    @ObservationIgnored private var observedSegmentID: UUID?
    @ObservationIgnored private var observedStart: Date?
    @ObservationIgnored private var distanceEpoch: Date?
    @ObservationIgnored private var phoneMeters: Double = 0
    @ObservationIgnored private var phoneBaseline: Double = 0
    @ObservationIgnored private var motionStartedAt: Date?
    @ObservationIgnored private let collectsDeviceSensors: Bool
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private var lastSpeedPoint: (source: CardioDistanceSource, meters: Double, date: Date)?
    @ObservationIgnored private var gpsMeters: Double = 0
    @ObservationIgnored private var lastLocation: CardioRoutePoint?
    @ObservationIgnored private var routePortion = UUID()
    @ObservationIgnored private var shuttingDown = false
    @ObservationIgnored private var configurationGeneration = 0
    private final class EnergyBaselines { var values: [UUID: (active: Double?, basal: Double?)] = [:] }
    @ObservationIgnored private var energyBaselines = EnergyBaselines()
    @ObservationIgnored private var checkpointSampleCount = 0

    init(collectsDeviceSensors: Bool = !WorkoutTrackerStore.isUITestReset,
         clock: @escaping () -> Date = { .now }) {
        self.collectsDeviceSensors = collectsDeviceSensors
        self.clock = clock
        super.init()
        location.delegate = self
        location.desiredAccuracy = kCLLocationAccuracyBest
        location.distanceFilter = 3
        location.pausesLocationUpdatesAutomatically = false
    }
    deinit { timer?.invalidate() }

    var current: CardioSegment? { workout?.unfinishedCardio }
    var freshSpeed: Double? {
        guard current?.isRunning == true, let date = movementUpdatedAt,
              (-2...15).contains(measurementTime.timeIntervalSince(date)) else { return nil }
        return currentSpeedMetersPerSecond
    }
    var currentHeartRate: HeartRateSample? {
        guard let start = current?.activeStartedAt,
              let sample = monitor?.samples.filter({ $0.date >= start && $0.date <= measurementTime.addingTimeInterval(2) })
                .current(asOf: measurementTime), !sample.isStale(asOf: measurementTime) else { return nil }
        return sample
    }
    func attach(to workout: Workout, monitor: HeartRateMonitor) {
        if self.workout?.id != workout.id {
            stopSensors()
            self.workout = workout
            self.context = workout.modelContext
            observedSegmentID = nil; observedStart = nil; distanceEpoch = nil
            energyBaselines = EnergyBaselines()
            checkpointSampleCount = monitor.samples.count
        }
        self.monitor = monitor
        shuttingDown = false
        (monitor.provider as? CardioMetricNotifying)?.onCardioMetrics = { [weak self] in self?.refresh() }
        (monitor.provider as? WorkoutActivityProvider)?.onPhaseStarted = { [weak self] phase, source in
            self?.beginIndoorMeasurement(phase: phase, start: source.collectionStartedAt)
        }
        let baselines = energyBaselines
        (monitor.provider as? WorkoutActivityProvider)?.onPhaseFinished = { [weak workout, baselines] phase, source in
            guard let workout, !workout.isDeleted, let id = phase.segmentID,
                  let segment = workout.orderedCardio.first(where: { $0.id == id }) else { return }
            let base = baselines.values[id]
            segment.activeEnergyKilocalories = WorkoutActivityProvider.sum(base?.active, source.activeEnergyKilocalories)
            segment.basalEnergyKilocalories = WorkoutActivityProvider.sum(base?.basal, source.basalEnergyKilocalories)
            try? workout.modelContext?.save()
        }
        if timer == nil {
            let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
        sync()
    }
    func start(_ activity: CardioActivity, plannedTargetID: UUID? = nil) {
        guard let workout, let context else { return }
        refresh()
        do {
            _ = try CardioSession(context: context).start(activity, in: workout, at: clock(), plannedTargetID: plannedTargetID)
            sync()
        } catch { errorMessage = error.localizedDescription }
    }
    func pause() {
        guard let segment = current, let context else { return }
        refresh()
        do { try CardioSession(context: context).pause(segment, at: clock()); sync() }
        catch { errorMessage = error.localizedDescription }
    }
    func resume() {
        guard let segment = current, let context else { return }
        do { try CardioSession(context: context).resume(segment, at: clock()); sync() }
        catch { errorMessage = error.localizedDescription }
    }
    func endCardio() {
        guard let segment = current, let context else { return }
        refresh()
        do { try CardioSession(context: context).end(segment, at: clock()); sync() }
        catch { errorMessage = error.localizedDescription }
    }
    func sync() {
        guard !shuttingDown else { return }
        let segment = current
        let phase = workout?.sensorConfiguration ?? .idle
        configurationGeneration += 1
        let generation = configurationGeneration
        if let provider = monitor?.provider as? WorkoutActivityProvider {
            Task { [weak self] in
                guard let self, !self.shuttingDown, self.configurationGeneration == generation else { return }
                await provider.configure(phase)
            }
        }
        if observedSegmentID != segment?.id || observedStart != segment?.activeStartedAt {
            stopMotionAndLocation()
            let sameSegment = observedSegmentID == segment?.id
            observedSegmentID = segment?.id; observedStart = segment?.activeStartedAt
            if !sameSegment {
                if let segment {
                    energyBaselines.values[segment.id] = (segment.activeEnergyKilocalories, segment.basalEnergyKilocalories)
                }
                distanceEpoch = segment.flatMap { $0.activity.isOutdoor ? max($0.startedAt, clock()) : nil }
                phoneMeters = 0; gpsMeters = 0
            }
            phoneBaseline = phoneMeters
            lastLocation = nil; routePortion = UUID(); lastSpeedPoint = nil
            currentSpeedMetersPerSecond = nil; movementUpdatedAt = nil
            if let segment, segment.isRunning { startMotionAndLocation(for: segment) }
        }
        refresh()
    }
    func refresh() {
        guard !shuttingDown else { return }
        measurementTime = clock()
        guard let workout, !workout.isDeleted else { return }
        // New beats are appended as individual rows. The small scalar checkpoint
        // and per-segment aggregates commit with them; no growing blob is rewritten.
        if let monitor, let context {
            if checkpointSampleCount > monitor.samples.count { checkpointSampleCount = monitor.samples.count }
            for sample in monitor.samples.dropFirst(checkpointSampleCount) {
                context.insert(WorkoutSensorSample(sample: sample, workout: workout))
            }
            checkpointSampleCount = monitor.samples.count
            workout.sensorActiveEnergyCheckpoint = monitor.provider.activeEnergyKilocalories
            workout.sensorBasalEnergyCheckpoint = monitor.provider.basalEnergyKilocalories
            workout.sensorMaxHeartRateBpm = monitor.maxHeartRate?.bpm
            workout.sensorMaxHeartRateEstimated = monitor.maxHeartRate?.isEstimated
        }
        guard let segment = workout.unfinishedCardio, !segment.isDeleted, segment.isRunning,
              let start = segment.activeStartedAt else { persist(); return }
        let now = measurementTime
        segment.lastCheckpointAt = now
        if let sample = currentHeartRate { segment.record(sample, at: now) }
        if let provider = monitor?.provider as? WorkoutActivityProvider,
           provider.configuration?.segmentID == segment.id {
            let base = energyBaselines.values[segment.id]
            segment.activeEnergyKilocalories = WorkoutActivityProvider.sum(base?.active, provider.phaseActiveEnergy)
            segment.basalEnergyKilocalories = WorkoutActivityProvider.sum(base?.basal, provider.phaseBasalEnergy)
            if !segment.activity.isOutdoor, let reading = provider.cardioReading, let epoch = distanceEpoch,
               reading.date >= epoch, reading.distanceMeters.isFinite, reading.distanceMeters >= 0 {
                segment.acceptDistance(reading.distanceMeters, source: .healthKit, since: epoch,
                                       at: reading.date, asOf: now)
                if segment.distanceSpans.last?.selectedSource == .healthKit, reading.date >= start,
                   (-2...15).contains(now.timeIntervalSince(reading.date)) {
                    updateSpeed(meters: reading.distanceMeters, source: .healthKit, at: reading.date)
                }
            }
        }
        if let epoch = distanceEpoch { segment.refreshDistanceSelection(since: epoch, asOf: now) }
        persist()
    }
    private func updateSpeed(meters: Double, source: CardioDistanceSource, at date: Date) {
        if let previous = lastSpeedPoint, previous.source == source {
            let seconds = date.timeIntervalSince(previous.date)
            guard seconds > 0 else { return }
            if seconds <= 20, meters >= previous.meters {
                let speed = (meters - previous.meters) / seconds
                currentSpeedMetersPerSecond = speed.isFinite && speed <= 60 ? speed : nil
                movementUpdatedAt = date
            } else { currentSpeedMetersPerSecond = nil }
        } else {
            currentSpeedMetersPerSecond = nil; movementUpdatedAt = nil
        }
        lastSpeedPoint = (source, meters, date)
    }
    private func persist() {
        do { try context?.save() }
        catch { errorMessage = "Could not save cardio: \(error.localizedDescription)" }
    }
    private func startMotionAndLocation(for segment: CardioSegment) {
        if segment.activity.isOutdoor {
            guard collectsDeviceSensors else { return }
            location.activityType = segment.activity == .outdoorCycle ? .otherNavigation : .fitness
            location.allowsBackgroundLocationUpdates = true
            location.showsBackgroundLocationIndicator = true
            startLocationIfAuthorized()
        } else if let provider = monitor?.provider as? WorkoutActivityProvider,
                  let phase = provider.configuration, !phase.paused {
            beginIndoorMeasurement(phase: phase, start: provider.collectionStartedAt)
        }
    }

    private func beginIndoorMeasurement(phase: WorkoutSensorConfiguration, start collectionStart: Date?) {
        guard let segment = current, segment.id == phase.segmentID,
              !segment.activity.isOutdoor, segment.isRunning, let activeStart = segment.activeStartedAt else { return }
        // Align phone-motion and HealthKit counters to the actual collection start,
        // after authorisation/setup. They must cover the same window to be alternatives.
        if distanceEpoch == nil { distanceEpoch = max(segment.startedAt, collectionStart ?? clock()) }
        guard segment.activity.isWalkingOrRunning, let epoch = distanceEpoch else { return }
        let start = max(activeStart, epoch)
        guard motionStartedAt != start else { return }
        motionStartedAt = start
        guard collectsDeviceSensors, CMPedometer.isDistanceAvailable() else { return }
        let id = segment.id
        pedometer.startUpdates(from: start) { [weak self] data, error in
            let meters = data?.distance?.doubleValue
            let end = data?.endDate
            Task { @MainActor in
                guard let self, self.current?.id == id, self.motionStartedAt == start else { return }
                if error != nil { self.locationMessage = "Motion data unavailable." }
                guard let meters, let end else { return }
                self.acceptPhoneDistance(meters, at: end, since: start, segmentID: id)
            }
        }
    }

    func acceptPhoneDistance(_ meters: Double, at date: Date, since start: Date, segmentID: UUID) {
        measurementTime = clock()
        guard let segment = current, segment.id == segmentID, segment.isRunning,
              motionStartedAt == start, date >= start, let epoch = distanceEpoch,
              meters.isFinite, meters >= 0, (phoneBaseline + meters).isFinite else { return }
        phoneMeters = phoneBaseline + meters
        segment.acceptDistance(phoneMeters, source: .phoneMotion, since: epoch,
                               at: date, asOf: clock())
        if segment.distanceSpans.last?.selectedSource == .phoneMotion {
            updateSpeed(meters: phoneMeters, source: .phoneMotion, at: date)
        }
        segment.lastCheckpointAt = clock()
        persist()
    }

    private func startLocationIfAuthorized() {
        switch location.authorizationStatus {
        case .notDetermined:
            locationMessage = "Allow location to record distance and your route."
            location.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            locationMessage = location.accuracyAuthorization == .reducedAccuracy
                ? "Precise Location is off. Route accuracy is limited." : "Waiting for GPS…"
            location.startUpdatingLocation()
        case .denied, .restricted:
            locationMessage = "Location unavailable."
        @unknown default: locationMessage = "Location unavailable."
        }
    }
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            guard let self, self.collectsDeviceSensors,
                  self.current?.isRunning == true, self.current?.activity.isOutdoor == true else { return }
            self.startLocationIfAuthorized()
        }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor [weak self] in self?.accept(locations) }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            guard let self, self.collectsDeviceSensors,
                  self.current?.isRunning == true, self.current?.activity.isOutdoor == true else { return }
            self.locationMessage = "GPS unavailable. Recording time continues."
        }
    }
    func accept(_ locations: [CLLocation]) {
        measurementTime = clock()
        guard let segment = current, segment.isRunning, segment.activity.isOutdoor,
              let start = segment.activeStartedAt, let epoch = distanceEpoch else { return }
        for fix in locations.sorted(by: { $0.timestamp < $1.timestamp }) {
            var point = CardioRoutePoint(latitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude,
                                        date: fix.timestamp, accuracy: fix.horizontalAccuracy, portion: routePortion)
            guard point.date >= start, CardioMath.valid(point, asOf: clock()) else { continue }
            if let previous = lastLocation {
                let dt = point.date.timeIntervalSince(previous.date)
                guard dt > 0 else { continue }
                let distance = CardioMath.meters(between: previous, and: point)
                if dt > 20 {
                    routePortion = UUID(); point.portion = routePortion
                } else {
                    guard distance / dt < (segment.activity.usesSpeed ? 45 : 20) else { continue }
                    gpsMeters += distance
                    updateSpeed(meters: gpsMeters, source: .gps, at: point.date)
                }
            }
            lastLocation = point
            segment.route.append(point)
            segment.acceptDistance(gpsMeters, source: .gps, since: epoch, at: point.date, asOf: clock())
            segment.lastCheckpointAt = clock()
            locationMessage = nil
        }
        persist()
    }
    private func stopMotionAndLocation() {
        pedometer.stopUpdates(); motionStartedAt = nil; location.stopUpdatingLocation()
        locationMessage = nil
    }
    private func stopSensors() {
        stopMotionAndLocation(); timer?.invalidate(); timer = nil
    }
    func stop() {
        refresh()
        shuttingDown = true
        configurationGeneration += 1
        stopSensors()
        (monitor?.provider as? CardioMetricNotifying)?.onCardioMetrics = nil
        (monitor?.provider as? WorkoutActivityProvider)?.onPhaseStarted = nil
        // Keep onPhaseFinished until the provider stops: its weak-workout sink
        // banks the final statistic, even after this recorder releases the screen.
        monitor = nil; workout = nil; context = nil
        observedSegmentID = nil; observedStart = nil
    }
}
