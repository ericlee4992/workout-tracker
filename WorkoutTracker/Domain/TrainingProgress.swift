import Foundation

// Soft redesign S4 (extends D63): training-wide charts on the Progress tab — workouts per week, training volume per
// week, running distance per week. Derived on read from finished workouts; nothing is stored but the pin.

/// A training-wide metric a Progress pin can chart, per calendar week.
enum TrainingMetric: String, CaseIterable, Codable, Sendable {
    case workoutsPerWeek, trainingVolume, runningDistance

    var title: String {
        switch self {
        case .workoutsPerWeek: "Workouts per week"
        case .trainingVolume: "Training volume"
        case .runningDistance: "Running distance"
        }
    }

    /// What it measures, under the title.
    var measures: String {
        switch self {
        case .workoutsPerWeek: "Finished workouts, per week"
        case .trainingVolume: "Weight × reps, per week"
        case .runningDistance: "Indoor and outdoor runs, per week"
        }
    }

    var glyph: String {
        switch self {
        case .workoutsPerWeek: "calendar"
        case .trainingVolume: "scalemass"
        case .runningDistance: "figure.run"
        }
    }
}

/// One finished workout, as the weekly charts read it.
struct TrainingWeekInput: Equatable, Sendable {
    var startedAt: Date
    /// `RecordsMath.totalVolumeKg`: warmups out, assisted and bodyweight out (the receipt's volume).
    var volumeKg: Double
    /// Recorded distance of the workout's indoor and outdoor runs.
    var runMeters: Double
}

struct TrainingWeekPoint: Equatable, Identifiable, Sendable {
    var id: Date { weekStart }
    var weekStart: Date
    /// Workouts, kilograms or metres — `TrainingProgressMath.weekly` converts for display.
    var value: Double
}

enum TrainingProgressMath {
    static let runActivities: Set<CardioActivity> = [.indoorRun, .outdoorRun]

    /// The weekly totals from the first week with any data to this week, at most `weeks` of them, oldest first. Weeks
    /// without a workout count as 0 (a week off is part of the picture), and this week is included so far.
    static func weekly(_ inputs: [TrainingWeekInput], metric: TrainingMetric, now: Date, weeks: Int = 12,
                       calendar: Calendar = .current) -> [TrainingWeekPoint] {
        func weekStart(_ date: Date) -> Date {
            calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        }
        let relevant = inputs.filter { input in
            switch metric {
            case .workoutsPerWeek: true
            case .trainingVolume: input.volumeKg > 0
            case .runningDistance: input.runMeters > 0
            }
        }
        guard let first = relevant.map(\.startedAt).min() else { return [] }
        let thisWeek = weekStart(now)
        var totals: [Date: Double] = [:]
        for input in relevant where input.startedAt <= now {
            let value: Double = switch metric {
            case .workoutsPerWeek: 1
            case .trainingVolume: input.volumeKg
            case .runningDistance: input.runMeters
            }
            totals[weekStart(input.startedAt), default: 0] += value
        }
        var points: [TrainingWeekPoint] = []
        var cursor = thisWeek
        let start = weekStart(first)
        while cursor >= start && points.count < weeks {
            points.append(TrainingWeekPoint(weekStart: cursor, value: totals[cursor] ?? 0))
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return points.reversed()
    }

    /// The workouts' inputs (finished, not deleted).
    static func inputs(_ workouts: [Workout]) -> [TrainingWeekInput] {
        workouts.compactMap { workout in
            guard let facts = HistoryWorkoutFacts(workout: workout) else { return nil }
            let runs = workout.recordedCardio.filter { runActivities.contains($0.activity) }
            return TrainingWeekInput(startedAt: workout.startedAt, volumeKg: facts.volumeKg,
                                     runMeters: runs.reduce(0) { $0 + ($1.distanceMeters ?? 0) })
        }
    }
}
