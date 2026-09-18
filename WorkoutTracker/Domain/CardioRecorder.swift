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
    private(set) var currentSpeedMetersPerSecond: Double?
    private(set) var movementUpdatedAt: Date?
    private(set) var locationMessage: String?
    var errorMessage: String?
    @ObservationIgnored private weak var workout: Workout?
    @ObservationIgnored private weak var monitor: HeartRateMonitor?
    @ObservationIgnored private var context: ModelContext?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private let location = CLLocationManager()
    @ObservationIgnored private let pedometer = CMPedometer()
    @ObservationIgnored private var observedSegmentID: UUID?
    @ObservationIgnored private var observedStart: Date?
    @ObservationIgnored private var healthKitBaseline: Double = 0
    @ObservationIgnored private var lastSpeedPoint: (source: CardioDistanceSource, meters: Double, date: Date)?
    @ObservationIgnored private var gpsMeters: Double = 0
    @ObservationIgnored private var lastLocation: CardioRoutePoint?
    @ObservationIgnored private var routePortion = UUID()
    @ObservationIgnored private var shuttingDown = false

    override init() {
        super.init()
        location.delegate = self
        location.desiredAccuracy = kCLLocationAccuracyBest
        location.distanceFilter = 3
        location.pausesLocationUpdatesAutomatically = false
    }
    var current: CardioSegment? { workout?.unfinishedCardio }
    var freshSpeed: Double? {
        guard current?.isRunning == true, let date = movementUpdatedAt,
              Date().timeIntervalSince(date) <= 15 else { return nil }
        return currentSpeedMetersPerSecond
    }
    func attach(to workout: Workout, monitor: HeartRateMonitor) {
        if self.workout?.id != workout.id {
            stopSensors()
            self.workout = workout
            self.context = workout.modelContext
            observedSegmentID = nil; observedStart = nil
        }
        self.monitor = monitor
        shuttingDown = false
        (monitor.provider as? CardioMetricNotifying)?.onCardioMetrics = { [weak self] in self?.refresh() }
        if timer == nil {
            let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
        sync()
    }
    func start(_ activity: CardioActivity) {
        guard let workout, let context else { return }
        refresh()
        do {
            _ = try CardioSession(context: context).start(activity, in: workout)
            sync()
        } catch { errorMessage = error.localizedDescription }
    }
    func pause() {
        guard let segment = current, let context else { return }
        refresh()
        do { try CardioSession(context: context).pause(segment); sync() }
        catch { errorMessage = error.localizedDescription }
    }
    func resume() {
        guard let segment = current, let context else { return }
        do { try CardioSession(context: context).resume(segment); sync() }
        catch { errorMessage = error.localizedDescription }
    }
    func endCardio() {
        guard let segment = current, let context else { return }
        refresh()
        do { try CardioSession(context: context).end(segment); sync() }
        catch { errorMessage = error.localizedDescription }
    }
    func sync() {
        guard !shuttingDown else { return }
        let segment = current
        let phase = WorkoutSensorConfiguration(segmentID: segment?.id, activity: segment?.activity,
                                               paused: segment != nil && segment?.isRunning != true)
        if let provider = monitor?.provider as? WorkoutActivityProvider,
           provider.configuration != phase {
            Task { await provider.configure(phase) }
        }
        if observedSegmentID != segment?.id || observedStart != segment?.activeStartedAt {
            stopMotionAndLocation()
            let sameSegment = observedSegmentID == segment?.id
            observedSegmentID = segment?.id; observedStart = segment?.activeStartedAt
            healthKitBaseline = sameSegment ? (monitor?.provider.cardioReading?.distanceMeters ?? 0) : 0
            gpsMeters = 0; lastLocation = nil; routePortion = UUID(); lastSpeedPoint = nil
            currentSpeedMetersPerSecond = nil; movementUpdatedAt = nil
            if let segment, segment.isRunning { startMotionAndLocation(for: segment) }
        }
        refresh()
    }
    func refresh() {
        guard !shuttingDown, let workout, !workout.isDeleted,
              let segment = workout.unfinishedCardio, !segment.isDeleted, segment.isRunning,
              let start = segment.activeStartedAt else { return }
        let now = Date()
        segment.lastCheckpointAt = now
        if let sample = monitor?.current { segment.record(sample) }
        if let provider = monitor?.provider as? WorkoutActivityProvider,
           provider.configuration?.segmentID == segment.id {
            segment.activeEnergyKilocalories = provider.phaseActiveEnergy
            segment.basalEnergyKilocalories = provider.phaseBasalEnergy
            if !segment.activity.isOutdoor, let reading = provider.cardioReading,
               reading.date >= start, now.timeIntervalSince(reading.date) <= 15 {
                let meters = max(0, reading.distanceMeters - healthKitBaseline)
                segment.acceptDistance(meters, source: .healthKit, since: start)
                if segment.distanceSpans.last?.selectedSource == .healthKit {
                    updateSpeed(meters: meters, source: .healthKit, at: reading.date)
                }
            }
        }
        persist()
    }
    private func updateSpeed(meters: Double, source: CardioDistanceSource, at date: Date) {
        if let previous = lastSpeedPoint, previous.source == source {
            let seconds = date.timeIntervalSince(previous.date)
            guard seconds > 0 else { return }
            if seconds <= 20, meters >= previous.meters {
                currentSpeedMetersPerSecond = (meters - previous.meters) / seconds
                movementUpdatedAt = date
            } else { currentSpeedMetersPerSecond = nil }
        }
        lastSpeedPoint = (source, meters, date)
    }
    private func persist() {
        do { try context?.save() }
        catch { errorMessage = "Could not save cardio: \(error.localizedDescription)" }
    }
    private func startMotionAndLocation(for segment: CardioSegment) {
        guard !WorkoutTrackerStore.isUITestReset else { return }
        if segment.activity.isOutdoor {
            location.activityType = segment.activity == .outdoorCycle ? .otherNavigation : .fitness
            location.allowsBackgroundLocationUpdates = true
            location.showsBackgroundLocationIndicator = true
            startLocationIfAuthorized()
        } else if segment.activity.isWalkingOrRunning, CMPedometer.isDistanceAvailable(),
                  let start = segment.activeStartedAt {
            let id = segment.id
            pedometer.startUpdates(from: start) { [weak self] data, error in
                let meters = data?.distance?.doubleValue
                let end = data?.endDate
                Task { @MainActor in
                    guard let self, let segment = self.current, segment.id == id,
                          segment.activeStartedAt == start, let meters, let end else { return }
                    segment.acceptDistance(meters, source: .phoneMotion, since: start)
                    if segment.distanceSpans.last?.selectedSource == .phoneMotion {
                        self.updateSpeed(meters: meters, source: .phoneMotion, at: end)
                    }
                    segment.lastCheckpointAt = .now
                    self.persist()
                }
            }
        }
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
            locationMessage = "Location unavailable. You can enter distance manually."
        @unknown default: locationMessage = "Location unavailable."
        }
    }
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            guard let self, self.current?.isRunning == true, self.current?.activity.isOutdoor == true else { return }
            self.startLocationIfAuthorized()
        }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor [weak self] in self?.accept(locations) }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in self?.locationMessage = "GPS unavailable. Recording time continues." }
    }
    private func accept(_ locations: [CLLocation]) {
        guard let segment = current, segment.isRunning, segment.activity.isOutdoor,
              let start = segment.activeStartedAt else { return }
        for fix in locations.sorted(by: { $0.timestamp < $1.timestamp }) {
            var point = CardioRoutePoint(latitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude,
                                        date: fix.timestamp, accuracy: fix.horizontalAccuracy, portion: routePortion)
            guard point.date >= start, CardioMath.valid(point, asOf: .now) else { continue }
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
            segment.acceptDistance(gpsMeters, source: .gps, since: start)
            segment.lastCheckpointAt = .now
            locationMessage = nil
        }
        persist()
    }
    private func stopMotionAndLocation() {
        pedometer.stopUpdates(); location.stopUpdatingLocation()
        locationMessage = nil
    }
    private func stopSensors() {
        stopMotionAndLocation(); timer?.invalidate(); timer = nil
    }
    func stop() {
        refresh()
        shuttingDown = true
        stopSensors()
        (monitor?.provider as? CardioMetricNotifying)?.onCardioMetrics = nil
        monitor = nil; workout = nil; context = nil
        observedSegmentID = nil; observedStart = nil
    }
}
