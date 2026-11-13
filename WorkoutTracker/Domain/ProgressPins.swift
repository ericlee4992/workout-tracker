import Foundation

// Public beta ticket 16 (D63): the charts the user pinned to the Progress tab.
//
// A pin is a VIEW PREFERENCE, not workout data: it lives as JSON in UserDefaults, outside the SwiftData store, so adding
// the tab changes nothing the phone stores about workouts (no store-format change, no Gate S, ticket 11 stays deferred).
// Consequence, accepted by the user: a reinstall resets the pins; workouts are untouched.

/// What a pinned chart shows. Lifting metrics are `ExerciseProgressView`'s; cardio has no heart-rate view (D63).
enum ProgressPinMetric: String, Codable, CaseIterable, Sendable {
    case bestSet, volume, e1rm
    case distance, pace, time

    static let lifting: [ProgressPinMetric] = [.bestSet, .volume, .e1rm]
    static let cardio: [ProgressPinMetric] = [.distance, .pace, .time]

    var isCardio: Bool { Self.cardio.contains(self) }

    /// The metrics a variation can chart: volume and 1RM are weighted-only (D20 — anything else draws a flat zero).
    static func lifting(for loadType: LoadType) -> [ProgressPinMetric] {
        loadType == .weighted ? lifting : [.bestSet]
    }

    /// The label on screen. Cycling shows speed where the others show pace.
    func title(for activity: CardioActivity? = nil) -> String {
        switch self {
        case .bestSet: "Best set"
        case .volume: "Volume"
        case .e1rm: "1RM"
        case .distance: "Distance"
        case .pace: activity?.usesSpeed == true ? "Speed" : "Pace"
        case .time: "Time"
        }
    }
}

/// A lifting pin's variation: the one the user picked, or whichever has the most history (D63 "Most used").
enum PinnedLiftVariation: Codable, Equatable, Sendable {
    case mostUsed
    /// Every axis of `ProgressVariationKey`, stored flat so the JSON never depends on Swift's enum encoding of
    /// `ProgressEquipment`.
    case fixed(loadType: LoadType, machineID: UUID?, freeWeightTag: EquipmentTag?, presetID: UUID?)

    init(_ key: ProgressVariationKey) {
        switch key.equipment {
        case .machine(let id): self = .fixed(loadType: key.loadType, machineID: id, freeWeightTag: nil, presetID: key.presetID)
        case .freeWeight(let tag): self = .fixed(loadType: key.loadType, machineID: nil, freeWeightTag: tag, presetID: key.presetID)
        case .unrecorded: self = .fixed(loadType: key.loadType, machineID: nil, freeWeightTag: nil, presetID: key.presetID)
        // "All machines" (D87) is a choice made on the chart, never offered when pinning (`AddChartSheet` lists
        // `rankedVariations`, which has no pool) and not storable in this flat shape: it falls back to Most used.
        case .anyMachine: self = .mostUsed
        }
    }

    /// The variation to chart: the fixed one, or the most-trained in `sets` (nil when there is no history).
    func resolve(in sets: [RecordSetInput]) -> ProgressVariationKey? {
        switch self {
        case .mostUsed:
            return ProgressSeriesMath.defaultVariation(in: sets)
        case let .fixed(loadType, machineID, freeWeightTag, presetID):
            return ProgressVariationKey(
                loadType: loadType, equipment: ProgressEquipment(machineID: machineID, freeWeightTag: freeWeightTag),
                presetID: presetID)
        }
    }
}

struct ProgressPin: Codable, Identifiable, Equatable, Sendable {
    enum Subject: Codable, Equatable, Sendable {
        case lift(exerciseID: UUID, variation: PinnedLiftVariation)
        /// The activity's raw value, so an activity a later build removes decodes and is skipped, not a decode failure.
        case cardio(activity: String)
        /// Soft redesign S4: a training-wide weekly chart. ON DISK it is the cardio shape with the activity
        /// "training.<metric>": a build from before S4 decodes it as an unknown activity and quietly skips it (the
        /// rule above), instead of failing the whole list — which would drop every pin. Consequence: changing this
        /// encoding would make older builds lose all pins.
        case training(TrainingMetric)
        /// Nutrition N10: a body or food chart — on disk the same way, the activity "nutrition.<chart>", so an older
        /// build skips it as an unknown activity (and a later build skips a chart it no longer has).
        case nutrition(NutritionChart)

        private static let trainingPrefix = "training."
        private static let nutritionPrefix = "nutrition."
        private enum Key: String, CodingKey { case lift, cardio }
        private enum LiftKey: String, CodingKey { case exerciseID, variation }
        private enum CardioKey: String, CodingKey { case activity }

        // The same JSON as the synthesised coding of the two original cases ({"lift":{…}} / {"cardio":{…}}), so pins
        // saved before S4 read unchanged.
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Key.self)
            if container.contains(.lift) {
                let lift = try container.nestedContainer(keyedBy: LiftKey.self, forKey: .lift)
                self = .lift(exerciseID: try lift.decode(UUID.self, forKey: .exerciseID),
                             variation: try lift.decode(PinnedLiftVariation.self, forKey: .variation))
            } else {
                let cardio = try container.nestedContainer(keyedBy: CardioKey.self, forKey: .cardio)
                let raw = try cardio.decode(String.self, forKey: .activity)
                if raw.hasPrefix(Self.trainingPrefix),
                   let metric = TrainingMetric(rawValue: String(raw.dropFirst(Self.trainingPrefix.count))) {
                    self = .training(metric)
                } else if raw.hasPrefix(Self.nutritionPrefix),
                          let chart = NutritionChart(rawValue: String(raw.dropFirst(Self.nutritionPrefix.count))) {
                    self = .nutrition(chart)
                } else {
                    self = .cardio(activity: raw)
                }
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: Key.self)
            switch self {
            case let .lift(exerciseID, variation):
                var lift = container.nestedContainer(keyedBy: LiftKey.self, forKey: .lift)
                try lift.encode(exerciseID, forKey: .exerciseID)
                try lift.encode(variation, forKey: .variation)
            case let .cardio(activity):
                var cardio = container.nestedContainer(keyedBy: CardioKey.self, forKey: .cardio)
                try cardio.encode(activity, forKey: .activity)
            case let .training(metric):
                var cardio = container.nestedContainer(keyedBy: CardioKey.self, forKey: .cardio)
                try cardio.encode(Self.trainingPrefix + metric.rawValue, forKey: .activity)
            case let .nutrition(chart):
                var cardio = container.nestedContainer(keyedBy: CardioKey.self, forKey: .cardio)
                try cardio.encode(Self.nutritionPrefix + chart.rawValue, forKey: .activity)
            }
        }
    }

    var id = UUID()
    var subject: Subject
    var metric: ProgressPinMetric

    var exerciseID: UUID? {
        if case .lift(let id, _) = subject { return id }
        return nil
    }

    var activity: CardioActivity? {
        if case .cardio(let raw) = subject { return CardioActivity(rawValue: raw) }
        return nil
    }

    var training: TrainingMetric? {
        if case .training(let metric) = subject { return metric }
        return nil
    }

    var nutrition: NutritionChart? {
        if case .nutrition(let chart) = subject { return chart }
        return nil
    }

    /// The metric to draw: a lifting pin's Volume or 1RM falls back to Best set when its variation is not weighted
    /// (a "Most used" pin can move to an assisted variation); a stored metric of the other kind falls back to the
    /// kind's default.
    func shownMetric(loadType: LoadType?) -> ProgressPinMetric {
        switch subject {
        case .lift:
            let allowed = ProgressPinMetric.lifting(for: loadType ?? .weighted)
            return allowed.contains(metric) ? metric : .bestSet
        case .cardio:
            return metric.isCardio ? metric : .distance
        case .training, .nutrition:
            // The training metric or chart is the subject; the stored metric is a placeholder older builds can decode.
            return metric
        }
    }
}

/// The pins in their saved order. Unreadable data reads as no pins: losing a view preference must never block launch.
enum ProgressPinStore {
    static let key = "progressPins.v1"

    static func load(_ defaults: UserDefaults = .standard) -> [ProgressPin] {
        decode(defaults.data(forKey: key))
    }

    static func save(_ pins: [ProgressPin], _ defaults: UserDefaults = .standard) {
        defaults.set(encode(pins), forKey: key)
    }

    static func decode(_ data: Data?) -> [ProgressPin] {
        guard let data, !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([ProgressPin].self, from: data)) ?? []
    }

    static func encode(_ pins: [ProgressPin]) -> Data {
        (try? JSONEncoder().encode(pins)) ?? Data()
    }

    /// Moves the pin one place up (-1) or down (+1); out-of-range moves change nothing.
    static func move(_ id: UUID, by offset: Int, in pins: [ProgressPin]) -> [ProgressPin] {
        guard let index = pins.firstIndex(where: { $0.id == id }) else { return pins }
        let target = index + offset
        guard pins.indices.contains(target) else { return pins }
        var moved = pins
        moved.swapAt(index, target)
        return moved
    }
}
