import Foundation

// Browsing the catalog: search, filter, group (ticket 21).
//
// Everything here is **display only** (D23). Grouping and filtering decide
// what a list shows and in what order — never what gets logged, how a context
// snapshot is captured, or how records group. Nothing in this file is read
// while writing an entry, and no filter state reaches one.
//
// The seeded catalog is ~1900 models across 23 manufacturers, and this work
// runs on every keystroke of a search field. It therefore operates on plain
// value types built once (`CatalogModelIndex`) rather than on SwiftData rows:
// re-reading 1900 managed objects per keystroke is what makes a picker feel
// slow, not the string comparisons.
//
// D24 rule, enforced in one place (`matches`): a row is never hidden by a
// category it *lacks*. A user-created model with no equipment type, or a
// seeded model whose type the research never established, stays visible under
// "Uncategorized" instead of disappearing behind a filter.

// MARK: - Grouping modes

/// How the equipment-model picker is grouped.
enum CatalogGrouping: String, CaseIterable, Identifiable, Codable {
    case manufacturer
    case bodyArea
    case equipmentType
    /// One flat list — a short catalog (or a narrow search) does not need
    /// headers.
    case alphabetical

    var id: String { rawValue }

    var label: String {
        switch self {
        case .manufacturer: "Manufacturer"
        case .bodyArea: "Body area"
        case .equipmentType: "Equipment type"
        case .alphabetical: "A–Z"
        }
    }
}

/// How a gym's own machines are grouped.
enum MachineGrouping: String, CaseIterable, Identifiable, Codable {
    case exercise
    case bodyArea
    case alphabetical

    var id: String { rawValue }

    var label: String {
        switch self {
        case .exercise: "Exercise"
        case .bodyArea: "Body area"
        case .alphabetical: "A–Z"
        }
    }
}

/// The seeded exercises' `muscleGroup` vocabulary, head to toe. Sections come
/// out in this order rather than alphabetically, so "Chest" is not filed
/// between "Calves" and "Core".
enum BodyArea {
    static let order = [
        "Chest", "Back", "Shoulders", "Biceps", "Triceps", "Forearms", "Neck",
        "Quads", "Hamstrings", "Glutes", "Hips", "Calves", "Core", "Full Body",
    ]
}

// MARK: - Rows

/// One catalog model, reduced to what browsing needs.
struct CatalogModelRow: Identifiable, Equatable {
    let id: UUID
    let manufacturer: String
    let modelName: String
    let equipmentType: EquipmentCategory?
    /// Body areas served, from the linked exercises' `muscleGroup` — the
    /// existing catalog vocabulary, not a parallel taxonomy.
    let bodyAreas: [String]
    let isSeeded: Bool
    /// Normalised "manufacturer modelName", precomputed: the search haystack.
    let searchText: String

    init(
        id: UUID,
        manufacturer: String,
        modelName: String,
        equipmentType: EquipmentCategory? = nil,
        bodyAreas: [String] = [],
        isSeeded: Bool = true
    ) {
        self.id = id
        self.manufacturer = manufacturer
        self.modelName = modelName
        self.equipmentType = equipmentType
        self.bodyAreas = bodyAreas
        self.isSeeded = isSeeded
        self.searchText = CatalogBrowsing.normalize("\(manufacturer) \(modelName)")
    }

    var displayName: String { "\(manufacturer) \(modelName)" }
}

/// One exercise, reduced to what the Exercises tab needs to filter on.
struct CatalogExerciseRow: Identifiable, Equatable {
    let id: UUID
    let name: String
    let bodyArea: String?
    let equipmentTags: [EquipmentTag]
    let isSeeded: Bool
    let searchText: String

    init(
        id: UUID,
        name: String,
        bodyArea: String? = nil,
        equipmentTags: [EquipmentTag] = [],
        isSeeded: Bool = true
    ) {
        self.id = id
        self.name = name
        self.bodyArea = bodyArea
        self.equipmentTags = equipmentTags
        self.isSeeded = isSeeded
        self.searchText = CatalogBrowsing.normalize(name)
    }
}

/// One machine at a gym, reduced to what the gym detail list groups by.
struct MachineBrowseRow: Identifiable, Equatable {
    let id: UUID
    let label: String
    /// Exercises the machine's model serves — empty for a model-less machine.
    let exerciseNames: [String]
    let bodyAreas: [String]

    init(id: UUID, label: String, exerciseNames: [String] = [], bodyAreas: [String] = []) {
        self.id = id
        self.label = label
        self.exerciseNames = exerciseNames
        self.bodyAreas = bodyAreas
    }
}

// MARK: - Filters

/// Model-picker filter state. `searchText` is transient; the two category
/// filters are the ones remembered between visits (AppPreferences).
struct CatalogModelFilter: Equatable {
    var searchText: String = ""
    var bodyArea: String?
    var equipmentType: EquipmentCategory?

    /// Whether a *category* filter is on. Search is deliberately excluded —
    /// the search field shows its own state.
    var hasActiveFilters: Bool { bodyArea != nil || equipmentType != nil }

    static let none = CatalogModelFilter()
}

struct CatalogExerciseFilter: Equatable {
    var searchText: String = ""
    var bodyArea: String?
    var equipmentTag: EquipmentTag?

    var hasActiveFilters: Bool { bodyArea != nil || equipmentTag != nil }

    static let none = CatalogExerciseFilter()
}

// MARK: - Sections

/// A rendered group. `title == nil` is the ungrouped flat list.
struct CatalogSection<Row: Identifiable>: Identifiable {
    let title: String?
    let rows: [Row]

    var id: String { title ?? "" }
}

// MARK: - Index

/// The catalog as value types, built once per screen appearance. Also carries
/// the filter vocabularies actually present, so the filter menus offer body
/// areas and equipment types the catalog really has.
struct CatalogModelIndex {
    /// Sorted by manufacturer, then model name — which is also A–Z of the
    /// display name, so the flat list needs no second sort.
    let rows: [CatalogModelRow]
    let manufacturers: [String]
    let bodyAreas: [String]
    let equipmentTypes: [EquipmentCategory]

    init(rows: [CatalogModelRow]) {
        self.rows = rows.sorted(by: CatalogBrowsing.precedes)
        self.manufacturers = CatalogBrowsing
            .uniqueValues(rows.map(\.manufacturer))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        self.bodyAreas = CatalogBrowsing.bodyAreasPresent(in: rows.flatMap(\.bodyAreas))
        self.equipmentTypes = EquipmentCategory.allCases.filter { type in
            rows.contains { $0.equipmentType == type }
        }
    }

    static let empty = CatalogModelIndex(rows: [])
}

// MARK: - Pure browsing logic

enum CatalogBrowsing {
    static let uncategorized = "Uncategorized"

    // MARK: Search

    /// Lowercased, diacritic-folded, punctuation flattened to spaces. Both the
    /// haystack and the query go through this, so "iso lateral" finds
    /// "Iso-Lateral" and "hammer incline" finds "Hammer Strength … Incline
    /// Press" — the manufacturer and the model name are one haystack.
    static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive],
                                  locale: Locale(identifier: "en_US_POSIX"))
        let flattened = folded.map { character -> Character in
            character.isLetter || character.isNumber ? character : " "
        }
        return String(flattened).split(separator: " ").joined(separator: " ")
    }

    /// Search terms: every token must appear, in any order, anywhere in the
    /// haystack. Order-independence is the point — nobody types a catalog
    /// model's words in catalog order.
    static func tokens(_ searchText: String) -> [String] {
        normalize(searchText).split(separator: " ").map(String.init)
    }

    static func matches(_ haystack: String, tokens: [String]) -> Bool {
        tokens.allSatisfy { haystack.contains($0) }
    }

    // MARK: Models

    static func models(
        _ rows: [CatalogModelRow], matching filter: CatalogModelFilter
    ) -> [CatalogModelRow] {
        let tokens = tokens(filter.searchText)
        return rows.filter { row in
            // A row is only excluded by a category it *has* — an uncategorized
            // row survives every category filter (D24).
            if let bodyArea = filter.bodyArea,
               !row.bodyAreas.isEmpty, !row.bodyAreas.contains(bodyArea) {
                return false
            }
            if let type = filter.equipmentType,
               let rowType = row.equipmentType, rowType != type {
                return false
            }
            return matches(row.searchText, tokens: tokens)
        }
    }

    static func sections(
        _ rows: [CatalogModelRow], by grouping: CatalogGrouping
    ) -> [CatalogSection<CatalogModelRow>] {
        switch grouping {
        case .alphabetical:
            return flat(rows)
        case .manufacturer:
            return sections(rows, categories: { [$0.manufacturer] }, order: nil)
        case .bodyArea:
            return sections(rows, categories: \.bodyAreas, order: BodyArea.order)
        case .equipmentType:
            return sections(
                rows,
                categories: { $0.equipmentType.map { [$0.label] } ?? [] },
                order: EquipmentCategory.allCases.map(\.label))
        }
    }

    /// Filter then group, in the order that keeps the work proportional to
    /// what survives the filter.
    static func browse(
        _ index: CatalogModelIndex, filter: CatalogModelFilter, grouping: CatalogGrouping
    ) -> [CatalogSection<CatalogModelRow>] {
        sections(models(index.rows, matching: filter), by: grouping)
    }

    // MARK: Exercises

    static func exercises(
        _ rows: [CatalogExerciseRow], matching filter: CatalogExerciseFilter
    ) -> [CatalogExerciseRow] {
        let tokens = tokens(filter.searchText)
        return rows.filter { row in
            if let bodyArea = filter.bodyArea,
               let rowArea = row.bodyArea, rowArea != bodyArea {
                return false
            }
            if let tag = filter.equipmentTag,
               !row.equipmentTags.isEmpty, !row.equipmentTags.contains(tag) {
                return false
            }
            return matches(row.searchText, tokens: tokens)
        }
    }

    // MARK: Machines

    static func machineSections(
        _ rows: [MachineBrowseRow], by grouping: MachineGrouping
    ) -> [CatalogSection<MachineBrowseRow>] {
        switch grouping {
        case .alphabetical:
            return flat(rows)
        case .exercise:
            return sections(rows, categories: \.exerciseNames, order: nil)
        case .bodyArea:
            return sections(rows, categories: \.bodyAreas, order: BodyArea.order)
        }
    }

    // MARK: Section assembly

    /// Groups `rows` under every category each row carries (a multi-exercise
    /// station is findable under each body area it serves), leaving rows with
    /// no category in a trailing "Uncategorized" section rather than dropping
    /// them. Row order inside a section is the incoming order, so the caller's
    /// sort is the whole ordering story.
    static func sections<Row: Identifiable>(
        _ rows: [Row], categories: (Row) -> [String], order: [String]?
    ) -> [CatalogSection<Row>] {
        var grouped: [String: [Row]] = [:]
        var uncategorized: [Row] = []
        var seen: [String] = []
        for row in rows {
            let titles = uniqueValues(categories(row))
            if titles.isEmpty {
                uncategorized.append(row)
                continue
            }
            for title in titles {
                if grouped[title] == nil {
                    grouped[title] = []
                    seen.append(title)
                }
                grouped[title]?.append(row)
            }
        }

        let titles: [String]
        if let order {
            let ordered = order.filter { grouped[$0] != nil }
            let rest = seen.filter { !order.contains($0) }
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            titles = ordered + rest
        } else {
            titles = seen.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        }

        var result = titles.map { CatalogSection(title: $0, rows: grouped[$0] ?? []) }
        if !uncategorized.isEmpty {
            result.append(CatalogSection(title: Self.uncategorized, rows: uncategorized))
        }
        return result
    }

    static func flat<Row: Identifiable>(_ rows: [Row]) -> [CatalogSection<Row>] {
        rows.isEmpty ? [] : [CatalogSection(title: nil, rows: rows)]
    }

    // MARK: Helpers

    /// Order-preserving de-duplication.
    static func uniqueValues(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.filter { seen.insert($0).inserted }
    }

    /// The body areas present, in the catalog's head-to-toe order, with any
    /// vocabulary the order does not know appended alphabetically.
    static func bodyAreasPresent(in values: [String]) -> [String] {
        let present = Set(values)
        let known = BodyArea.order.filter(present.contains)
        let unknown = present.subtracting(BodyArea.order)
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        return known + unknown
    }

    /// Body area per exercise id, for turning a model's links into groups.
    static func bodyAreas(of exercises: [Exercise]) -> [UUID: String] {
        Dictionary(
            exercises.compactMap { exercise in
                exercise.muscleGroup.map { (exercise.id, $0) }
            },
            uniquingKeysWith: { first, _ in first })
    }

    /// A–Z by manufacturer, then model name; case-insensitive and stable.
    static func precedes(_ lhs: CatalogModelRow, _ rhs: CatalogModelRow) -> Bool {
        switch lhs.manufacturer.localizedCaseInsensitiveCompare(rhs.manufacturer) {
        case .orderedAscending: return true
        case .orderedDescending: return false
        case .orderedSame:
            return lhs.modelName.localizedCaseInsensitiveCompare(rhs.modelName)
                == .orderedAscending
        }
    }
}

// MARK: - Building the value types from persisted rows

// The single boundary between SwiftData and browsing. Building an index reads
// every model once; searching and grouping afterwards never touch the store.

extension CatalogModelIndex {
    static func build(models: [EquipmentModel], exercises: [Exercise]) -> CatalogModelIndex {
        let bodyAreas = CatalogBrowsing.bodyAreas(of: exercises)
        return CatalogModelIndex(rows: models.map { model in
            CatalogModelRow(
                id: model.id,
                manufacturer: model.manufacturer,
                modelName: model.modelName,
                equipmentType: model.equipmentType,
                bodyAreas: CatalogBrowsing.uniqueValues(
                    model.exerciseIDs.compactMap { bodyAreas[$0] }),
                isSeeded: model.isSeeded)
        })
    }
}

extension CatalogExerciseRow {
    init(_ exercise: Exercise) {
        self.init(
            id: exercise.id,
            name: exercise.name,
            bodyArea: exercise.muscleGroup,
            equipmentTags: exercise.equipmentTypeTags,
            isSeeded: exercise.isSeeded)
    }
}

extension MachineBrowseRow {
    /// A machine's groups come from its model's linked exercises; a model-less
    /// machine has none and lands in "Uncategorized" (never hidden).
    init(_ machine: MachineInstance, exercisesByID: [UUID: Exercise]) {
        let exercises = (machine.model?.exerciseIDs ?? []).compactMap { exercisesByID[$0] }
        self.init(
            id: machine.id,
            label: machine.label,
            exerciseNames: CatalogBrowsing.uniqueValues(exercises.map(\.name)),
            bodyAreas: CatalogBrowsing.uniqueValues(exercises.compactMap(\.muscleGroup)))
    }
}
