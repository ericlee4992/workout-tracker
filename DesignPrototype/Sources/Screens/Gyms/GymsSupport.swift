import SwiftUI

// PROTOTYPE — Gyms area readouts the Store/Derived layers don't have yet (area-prefixed so the
// integrator can promote them): visits as distinct days, per-exercise use of a machine, the
// display groupings, the best-set series on a machine, the New Model prefill, and the capture
// variants this area reads from `router.variant`. Views live in GymsComponents.swift.

// MARK: - Groupings

enum GymsMachineGrouping: Int, CaseIterable, Identifiable {
    case bodyArea, exercise, alphabetical
    var id: Int { rawValue }
    /// Real app's grouping names.
    var title: String {
        switch self {
        case .bodyArea: "Body area"
        case .exercise: "Exercise"
        case .alphabetical: "A–Z"
        }
    }
}

struct GymsMachineGroup: Identifiable {
    var id: String
    var title: String?
    /// Body-area groups: the family colour of the header swatch (nil = Core, Full Body…).
    var family: MuscleFamily?
    /// Exercise groups: the rows show THIS exercise's numbers on each machine.
    var exerciseID: UUID?
    var machines: [Machine]
}

/// A machine's numbers for one row: the best (look's best mark) and when it was last used.
struct GymsMachineUse {
    var best: MachineBest?
    var lastUsed: Date?
}

/// Which gym a model picker opened for a NEW machine belongs to (the sheet only carries a
/// machine id). Set by the gym detail before presenting; falls back to the screen target.
@MainActor
enum GymsPickerContext {
    static var gymID: UUID?
}

extension Store {
    // MARK: Visits (distinct days)

    /// Gym stats with visits counted as distinct calendar days: a lift and a run on the same
    /// day are one visit (Derived.gymStats counts workouts). Promote into Derived.gymStats.
    func gymsVisitStats(_ gymID: UUID) -> GymStats {
        var stats = gymStats(gymID)
        let cal = Calendar.app
        stats.visits = Set(workouts.filter { $0.gymID == gymID }.map { cal.startOfDay(for: $0.startedAt) }).count
        return stats
    }

    /// Visits (distinct days) per week at a gym, the last `weeks` weeks (Mon–Sun), oldest first.
    func gymsWeeklyVisits(_ gymID: UUID, weeks: Int = 8) -> [Int] {
        let cal = Calendar.app
        guard let thisWeek = cal.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }
        let days = Set(workouts.filter { $0.gymID == gymID }.map { cal.startOfDay(for: $0.startedAt) })
        return (0..<weeks).map { i in
            let start = cal.date(byAdding: .weekOfYear, value: i - (weeks - 1), to: thisWeek)!
            let end = cal.date(byAdding: .weekOfYear, value: 1, to: start)!
            return days.filter { $0 >= start && $0 < end }.count
        }
    }

    /// Gyms for the Gyms tab: the Home gym first, then the most recently visited, then A–Z.
    var gymsTabOrder: [Gym] {
        let last = Dictionary(uniqueKeysWithValues: activeGyms.map { ($0.id, gymStats($0.id).lastVisit) })
        return activeGyms.sorted { a, b in
            if (a.id == selectedGymID) != (b.id == selectedGymID) { return a.id == selectedGymID }
            let la = last[a.id].flatMap { $0 } ?? .distantPast, lb = last[b.id].flatMap { $0 } ?? .distantPast
            if la != lb { return la > lb }
            return a.name.localizedCompare(b.name) == .orderedAscending
        }
    }

    // MARK: Machines

    func gymsCategory(of machine: Machine) -> EquipmentCategory? { model(machine.modelID)?.category }

    /// The row's numbers. With `exerciseID` (Exercise grouping) only that exercise's best and
    /// last use on this machine — or nothing when it was never done here (missing is not zero).
    func gymsMachineUse(_ machine: Machine, exerciseID: UUID? = nil) -> GymsMachineUse {
        let stats = machineStats(machine.id)
        guard let exerciseID else { return GymsMachineUse(best: stats.best, lastUsed: stats.lastUsed) }
        let last = workouts
            .filter { w in w.entries.contains { $0.machineID == machine.id && $0.exerciseID == exerciseID } }
            .map(\.startedAt).max()
        return GymsMachineUse(best: stats.bests.first { $0.exerciseID == exerciseID }, lastUsed: last)
    }

    /// The exercise a machine is "for" on the Body area list: its most-used exercise here, else
    /// its first. (The Pec Deck is used for Rear Delt Fly, so it sits with Shoulders, and the
    /// best on its row is that exercise's.)
    func gymsFocusExercise(of machine: Machine) -> Exercise? {
        exercise(machineStats(machine.id).best?.exerciseID ?? exerciseIDs(of: machine).first)
    }

    /// Machines at a gym, grouped for display only (D23). By exercise, a machine serving several
    /// exercises appears under each; by body area, once (its focus exercise's area).
    func gymsMachineGroups(gymID: UUID, grouping: GymsMachineGrouping) -> [GymsMachineGroup] {
        let machines = activeMachines(gymID: gymID)
        switch grouping {
        case .alphabetical:
            return machines.isEmpty ? [] : [GymsMachineGroup(id: "all", title: nil, machines: machines)]
        case .exercise:
            var byExercise: [UUID: [Machine]] = [:]
            var none: [Machine] = []
            for m in machines {
                let ids = exerciseIDs(of: m)
                if ids.isEmpty { none.append(m) }
                for id in ids { byExercise[id, default: []].append(m) }
            }
            var groups = byExercise.compactMap { id, list -> GymsMachineGroup? in
                guard let ex = exercise(id) else { return nil }
                return GymsMachineGroup(id: "ex-\(id)", title: ex.name, exerciseID: id, machines: list)
            }
            .sorted { ($0.title ?? "").localizedCompare($1.title ?? "") == .orderedAscending }
            if !none.isEmpty { groups.append(GymsMachineGroup(id: "none", title: "Uncategorized", machines: none)) }
            return groups
        case .bodyArea:
            enum Area: Hashable { case family(MuscleFamily), group(MuscleGroup), none }
            var byArea: [Area: [Machine]] = [:]
            for m in machines {
                let ex = gymsFocusExercise(of: m)
                let area: Area = ex?.family.map(Area.family) ?? ex?.muscleGroup.map(Area.group) ?? .none
                byArea[area, default: []].append(m)
            }
            var groups: [GymsMachineGroup] = []
            for f in MuscleFamily.allCases {
                if let list = byArea[.family(f)] {
                    groups.append(GymsMachineGroup(id: "f-\(f.rawValue)", title: f.label, family: f, machines: list))
                }
            }
            for g in MuscleGroup.allCases where g.family == nil {
                if let list = byArea[.group(g)] {
                    groups.append(GymsMachineGroup(id: "g-\(g.rawValue)", title: g.label, machines: list))
                }
            }
            if let list = byArea[.none] {
                groups.append(GymsMachineGroup(id: "none", title: "Uncategorized", machines: list))
            }
            return groups
        }
    }

    /// The progress-variation id for one best on a machine (links to the H06 chart).
    func gymsVariationID(machineID: UUID, best: MachineBest) -> String {
        "\(best.loadType.rawValue)|\(machineID.uuidString)|\(best.presetID?.uuidString ?? "")"
    }

    /// Best-set history for one record scope on this machine, one point per day.
    func gymsSeries(machineID: UUID, best: MachineBest) -> [ProgressPoint] {
        let variationID = gymsVariationID(machineID: machineID, best: best)
        guard let series = progressSeries(exerciseID: best.exerciseID, variationID: variationID),
              series.variation.id == variationID else { return [] }
        return series.points
    }

    /// D3: a machine picked by model is labelled by its movement when the model serves one
    /// exercise, otherwise by the model name.
    func gymsDefaultLabel(for model: EquipmentModel) -> String {
        if model.exerciseIDs.count == 1, let name = exercise(model.exerciseIDs.first)?.name { return name }
        return model.modelName
    }

    /// Active machines at a gym that use a model ("Chest Press 2" for the Insignia Chest Press).
    func gymsMachineLabels(usingModel modelID: UUID, gymID: UUID?) -> [String] {
        guard let gymID else { return [] }
        return activeMachines(gymID: gymID).filter { $0.modelID == modelID }.map(\.label)
    }

    /// "Seoul · lb" / "New York" for a gym card.
    func gymsSubtitle(_ gym: Gym) -> String {
        [gym.city, gym.defaultUnit?.label].compactMap { $0 }.joined(separator: " · ")
    }

    /// The unit a machine's "Gym" choice resolves to (gym default, else the app's).
    func gymsGymUnit(_ gymID: UUID) -> WeightUnit { gym(gymID)?.defaultUnit ?? displayUnit }

    /// New Model… from a search: the query's leading words become the manufacturer when they
    /// name a catalog manufacturer ("life fitness leg press" → Life Fitness / Leg Press);
    /// otherwise the whole query is the model (we can't tell which word is the maker).
    func gymsNewModelPrefill(_ query: String) -> (manufacturer: String, model: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return ("", "") }
        let words = trimmed.split(separator: " ").map(String.init)
        let styled: (String) -> String = { text in text == text.lowercased() ? text.capitalized : text }
        let makers = Set(models.map(\.manufacturer)).sorted { $0.count > $1.count }
        for maker in makers {
            let makerWords = maker.lowercased().split(separator: " ").map(String.init)
            guard words.count >= makerWords.count,
                  words.prefix(makerWords.count).map({ $0.lowercased() }) == makerWords else { continue }
            return (maker, styled(words.dropFirst(makerWords.count).joined(separator: " ")))
        }
        return ("", styled(trimmed))
    }
}

// MARK: - One relative-day rule for every look

/// "Today" / "Yesterday" / a weekday within this week ("Mon") / "Sep 17". Every look uses the
/// same words for the same fact (the looks vary only the typography), so the looks compare
/// side by side.
@MainActor
enum GymsDate {
    private static let weekday: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar.app
        f.locale = Calendar.app.locale
        f.setLocalizedDateFormatFromTemplate("EEE")
        return f
    }()

    static func label(_ date: Date, now: Date) -> String {
        let cal = Calendar.app
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: now)).day ?? 0
        if days <= 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        if let week = cal.dateInterval(of: .weekOfYear, for: now), week.contains(date) { return weekday.string(from: date) }
        return Format.shortDate(date)
    }

    /// "Deleted today" / "Deleted yesterday" / "Deleted Sep 2".
    static func deleted(_ date: Date, now: Date) -> String {
        let cal = Calendar.app
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: now)).day ?? 0
        switch days {
        case ...0: return "Deleted today"
        case 1: return "Deleted yesterday"
        default: return "Deleted \(Format.shortDate(date))"
        }
    }
}

extension WeightUnit? {
    /// SegmentedPills index for "Gym (lb) / App (lb) | kg | lb".
    var gymsSegment: Int {
        switch self {
        case .none: 0
        case .some(.kg): 1
        case .some(.lb): 2
        }
    }
    static func gymsFromSegment(_ index: Int) -> WeightUnit? {
        switch index {
        case 1: .kg
        case 2: .lb
        default: nil
        }
    }
}

// MARK: - Capture variants (router.variant, only for the state the shell opened)

/// View-level capture variants of this area. Each applies only when the shell opened the
/// matching ScreenID, so navigating later in the prototype never re-triggers them.
@MainActor
enum GymsCapture {
    static let iron = SampleData.gymID("Iron Temple")
    static func machine(_ label: String, gym: String = "Iron Temple") -> UUID { SampleData.machineID(gym, label) }

    /// `router.variant` when the shell opened `screen`, else nil.
    static func variant(_ screen: ScreenID, store: Store, router: Router) -> String? {
        store.currentScreen == screen ? router.variant : nil
    }

    /// Takes a one-shot state variant for `screen` (read on appear, then cleared so later
    /// navigation never re-applies it). Paging variants ("p2", "p3") stay for the scroll task.
    static func take(_ screen: ScreenID, store: Store, router: Router) -> String? {
        guard let v = variant(screen, store: store, router: router) else { return nil }
        if v != "p2" && v != "p3" { router.variant = nil }
        return v
    }

    /// G04 variants: other machines on the same page.
    static func machineOverride(_ variant: String?, store: Store) -> UUID? {
        switch variant {
        case "unused": machine("Smith Machine")
        case "nomodel": machine("Biceps Curl")
        case "assisted": machine("Assist Dip/Chin")
        case "usual": store.screenTarget.secondaryMachineID ?? machine("Seated Row")
        case "custom", "rename": customMachine(store: store)
        default: nil
        }
    }

    /// A user-made model on a new Iron Temple machine (the Custom tag, Rename Model…).
    static func customMachine(store: Store) -> UUID {
        if let existing = store.activeMachines(gymID: iron).first(where: { store.model($0.modelID)?.isSeeded == false }) {
            return existing.id
        }
        let modelID = store.addModel(manufacturer: "Rogue", modelName: "Monster Hack Squat", category: .plateLoaded,
                                     exerciseIDs: [SampleData.exerciseID("Hack Squat")])
        return store.addMachine(gymID: iron, label: "Hack Squat", modelID: modelID)
    }
}
