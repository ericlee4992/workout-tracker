import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

// Ticket 21 — browsing the catalog: search, filter, group. Pure logic, so
// these tests are the specification: the views only render what these
// functions return.

struct CatalogBrowsingTests {

    // MARK: Fixtures

    private func model(
        _ manufacturer: String,
        _ name: String,
        type: EquipmentCategory? = nil,
        areas: [String] = [],
        seeded: Bool = true
    ) -> CatalogModelRow {
        CatalogModelRow(
            id: UUID(), manufacturer: manufacturer, modelName: name,
            equipmentType: type, bodyAreas: areas, isSeeded: seeded)
    }

    /// A miniature catalog with the shapes that matter: two manufacturers, a
    /// multi-area station, and a user-created row with no metadata at all.
    private func sampleRows() -> [CatalogModelRow] {
        [
            model("Hammer Strength", "Iso-Lateral Incline Press",
                  type: .plateLoaded, areas: ["Chest"]),
            model("Hammer Strength", "Select Chest Press",
                  type: .selectorized, areas: ["Chest"]),
            model("Hammer Strength", "HD Elite Power Rack",
                  type: .rackOrSmith, areas: ["Quads", "Chest", "Shoulders", "Back"]),
            model("Life Fitness", "Insignia Series Leg Press",
                  type: .selectorized, areas: ["Quads"]),
            model("Life Fitness", "Dual Adjustable Pulley",
                  type: .cable, areas: ["Chest", "Back", "Triceps", "Biceps"]),
            model("Acme", "Garage Chest Press", seeded: false),
        ]
    }

    // MARK: Search

    @Test func searchMatchesManufacturerAndModelTogether() {
        let rows = sampleRows()
        let hits = CatalogBrowsing.models(
            rows, matching: CatalogModelFilter(searchText: "hammer incline"))

        #expect(hits.map(\.modelName) == ["Iso-Lateral Incline Press"])
    }

    @Test func searchTokensAreOrderIndependent() {
        let rows = sampleRows()
        let forward = CatalogBrowsing.models(
            rows, matching: CatalogModelFilter(searchText: "hammer incline"))
        let backward = CatalogBrowsing.models(
            rows, matching: CatalogModelFilter(searchText: "incline hammer"))

        #expect(forward.map(\.id) == backward.map(\.id))
    }

    @Test func searchIgnoresPunctuationCaseAndDiacritics() {
        let rows = sampleRows()

        // "Iso-Lateral" is one hyphenated word; typing it as two must work.
        #expect(CatalogBrowsing.models(
            rows, matching: CatalogModelFilter(searchText: "ISO lateral")).count == 1)
        #expect(CatalogBrowsing.models(
            rows, matching: CatalogModelFilter(searchText: "iso-lateral")).count == 1)
        #expect(CatalogBrowsing.models(
            [model("Tëchnogym", "Sélection Lég Press")],
            matching: CatalogModelFilter(searchText: "technogym selection")).count == 1)
    }

    @Test func emptySearchKeepsEveryRow() {
        let rows = sampleRows()
        #expect(CatalogBrowsing.models(rows, matching: .none).count == rows.count)
        #expect(CatalogBrowsing.models(
            rows, matching: CatalogModelFilter(searchText: "   ")).count == rows.count)
    }

    // MARK: Filters

    @Test func bodyAreaAndEquipmentTypeFiltersCombine() {
        let rows = sampleRows()

        let chest = CatalogBrowsing.models(
            rows, matching: CatalogModelFilter(bodyArea: "Chest"))
        #expect(Set(chest.map(\.modelName)) == [
            "Iso-Lateral Incline Press", "Select Chest Press", "HD Elite Power Rack",
            "Dual Adjustable Pulley", "Garage Chest Press",
        ])

        let chestPlateLoaded = CatalogBrowsing.models(
            rows, matching: CatalogModelFilter(bodyArea: "Chest", equipmentType: .plateLoaded))
        // The user row survives (it claims neither attribute); everything that
        // does claim one and disagrees is gone.
        #expect(Set(chestPlateLoaded.map(\.modelName)) == [
            "Iso-Lateral Incline Press", "Garage Chest Press",
        ])
    }

    @Test func filtersCombineWithSearch() {
        let rows = sampleRows()
        let hits = CatalogBrowsing.models(
            rows,
            matching: CatalogModelFilter(
                searchText: "press", bodyArea: "Quads", equipmentType: .selectorized))

        // The uncategorized user row still answers the search — filters only
        // remove rows that positively contradict them.
        #expect(hits.map(\.modelName) == ["Insignia Series Leg Press", "Garage Chest Press"])

        let narrower = CatalogBrowsing.models(
            rows,
            matching: CatalogModelFilter(
                searchText: "leg press", bodyArea: "Quads", equipmentType: .selectorized))
        #expect(narrower.map(\.modelName) == ["Insignia Series Leg Press"])
    }

    @Test func aRowIsNeverHiddenByACategoryItLacks() {
        // D24: user-created rows have no body area and no equipment type, and
        // must stay reachable under every filter combination.
        let user = model("Acme", "Garage Chest Press", seeded: false)
        for area in BodyArea.order {
            for type in EquipmentCategory.allCases {
                let hits = CatalogBrowsing.models(
                    [user], matching: CatalogModelFilter(bodyArea: area, equipmentType: type))
                #expect(hits.count == 1, "\(area)/\(type.label) hid a user row")
            }
        }
    }

    @Test func hasActiveFiltersIgnoresSearchText() {
        #expect(CatalogModelFilter(searchText: "hammer").hasActiveFilters == false)
        #expect(CatalogModelFilter(bodyArea: "Chest").hasActiveFilters)
        #expect(CatalogModelFilter(equipmentType: .cable).hasActiveFilters)
    }

    // MARK: Grouping

    @Test func manufacturerGroupingIsAlphabeticalAndKeepsRowOrder() {
        let index = CatalogModelIndex(rows: sampleRows())
        let sections = CatalogBrowsing.sections(index.rows, by: .manufacturer)

        #expect(sections.map(\.title) == ["Acme", "Hammer Strength", "Life Fitness"])
        #expect(sections[1].rows.map(\.modelName) == [
            "HD Elite Power Rack", "Iso-Lateral Incline Press", "Select Chest Press",
        ])
    }

    @Test func bodyAreaGroupingUsesTheCatalogVocabularyOrder() {
        let index = CatalogModelIndex(rows: sampleRows())
        let sections = CatalogBrowsing.sections(index.rows, by: .bodyArea)

        // Head to toe, not alphabetical — and the row with no body area last.
        #expect(sections.map(\.title) == [
            "Chest", "Back", "Shoulders", "Biceps", "Triceps", "Quads",
            CatalogBrowsing.uncategorized,
        ])
        #expect(sections.last?.rows.map(\.modelName) == ["Garage Chest Press"])
    }

    @Test func aMultiAreaStationAppearsUnderEachAreaItServes() {
        let index = CatalogModelIndex(rows: sampleRows())
        let sections = CatalogBrowsing.sections(index.rows, by: .bodyArea)
        let pulley = "Dual Adjustable Pulley"
        let appearances = sections.filter { $0.rows.contains { $0.modelName == pulley } }

        #expect(Set(appearances.compactMap(\.title)) == ["Chest", "Back", "Triceps", "Biceps"])
    }

    @Test func equipmentTypeGroupingPutsUncategorizedLast() {
        let index = CatalogModelIndex(rows: sampleRows())
        let sections = CatalogBrowsing.sections(index.rows, by: .equipmentType)

        #expect(sections.map(\.title) == [
            EquipmentCategory.selectorized.label,
            EquipmentCategory.plateLoaded.label,
            EquipmentCategory.cable.label,
            EquipmentCategory.rackOrSmith.label,
            CatalogBrowsing.uncategorized,
        ])
    }

    @Test func alphabeticalGroupingIsOneUnheadedSection() {
        let index = CatalogModelIndex(rows: sampleRows())
        let sections = CatalogBrowsing.sections(index.rows, by: .alphabetical)

        #expect(sections.count == 1)
        #expect(sections[0].title == nil)
        #expect(sections[0].rows.map(\.displayName) == index.rows.map(\.displayName))
        // A–Z of the display name, which is manufacturer then model.
        #expect(sections[0].rows.first?.displayName == "Acme Garage Chest Press")
        #expect(sections[0].rows.last?.displayName == "Life Fitness Insignia Series Leg Press")
    }

    @Test func groupingIsStableAcrossRepeatedRuns() {
        let index = CatalogModelIndex(rows: sampleRows().shuffled())
        let other = CatalogModelIndex(rows: sampleRows().shuffled())

        for grouping in CatalogGrouping.allCases {
            let first = CatalogBrowsing.sections(index.rows, by: grouping)
            let second = CatalogBrowsing.sections(other.rows, by: grouping)
            #expect(first.map(\.title) == second.map(\.title))
            #expect(first.map { $0.rows.map(\.displayName) }
                    == second.map { $0.rows.map(\.displayName) })
        }
    }

    @Test func emptyResultsProduceNoSections() {
        let index = CatalogModelIndex(rows: sampleRows())
        let sections = CatalogBrowsing.browse(
            index, filter: CatalogModelFilter(searchText: "nothing matches this"),
            grouping: .manufacturer)

        #expect(sections.isEmpty)
    }

    // MARK: Index vocabularies

    @Test func indexOffersOnlyTheVocabularyThatIsPresent() {
        let index = CatalogModelIndex(rows: sampleRows())

        #expect(index.manufacturers == ["Acme", "Hammer Strength", "Life Fitness"])
        #expect(index.bodyAreas == ["Chest", "Back", "Shoulders", "Biceps", "Triceps", "Quads"])
        #expect(index.equipmentTypes == [.selectorized, .plateLoaded, .cable, .rackOrSmith])
    }

    // MARK: Exercises

    private func exerciseRows() -> [CatalogExerciseRow] {
        [
            CatalogExerciseRow(
                id: UUID(), name: "Seated Chest Press", bodyArea: "Chest",
                equipmentTags: [.machine]),
            CatalogExerciseRow(
                id: UUID(), name: "Incline Bench Press", bodyArea: "Chest",
                equipmentTags: [.barbell]),
            CatalogExerciseRow(
                id: UUID(), name: "Lat Pulldown", bodyArea: "Back",
                equipmentTags: [.machine, .cable]),
            CatalogExerciseRow(
                id: UUID(), name: "Landmine Press", bodyArea: nil,
                equipmentTags: [], isSeeded: false),
        ]
    }

    @Test func exerciseFiltersCombineAndSpareUncategorizedRows() {
        let rows = exerciseRows()

        #expect(CatalogBrowsing.exercises(
            rows, matching: CatalogExerciseFilter(bodyArea: "Chest")).map(\.name)
            == ["Seated Chest Press", "Incline Bench Press", "Landmine Press"])

        #expect(CatalogBrowsing.exercises(
            rows, matching: CatalogExerciseFilter(bodyArea: "Chest", equipmentTag: .barbell))
            .map(\.name) == ["Incline Bench Press", "Landmine Press"])

        // A cable filter keeps a multi-tag exercise that carries the tag.
        #expect(CatalogBrowsing.exercises(
            rows, matching: CatalogExerciseFilter(equipmentTag: .cable)).map(\.name)
            == ["Lat Pulldown", "Landmine Press"])
    }

    @Test func exerciseSearchIsMultiToken() {
        let rows = exerciseRows()
        #expect(CatalogBrowsing.exercises(
            rows, matching: CatalogExerciseFilter(searchText: "press incline")).map(\.name)
            == ["Incline Bench Press"])
    }

    // MARK: Machines

    @Test func machinesGroupByExerciseAndBodyArea() {
        let rows = [
            MachineBrowseRow(
                id: UUID(), label: "Chest press by the window",
                exerciseNames: ["Seated Chest Press"], bodyAreas: ["Chest"]),
            MachineBrowseRow(
                id: UUID(), label: "Blue leg press",
                exerciseNames: ["Leg Press"], bodyAreas: ["Quads"]),
            MachineBrowseRow(id: UUID(), label: "Unlabelled rack"),
        ]

        let byExercise = CatalogBrowsing.machineSections(rows, by: .exercise)
        #expect(byExercise.map(\.title)
                == ["Leg Press", "Seated Chest Press", CatalogBrowsing.uncategorized])

        let byArea = CatalogBrowsing.machineSections(rows, by: .bodyArea)
        #expect(byArea.map(\.title) == ["Chest", "Quads", CatalogBrowsing.uncategorized])

        // A–Z stays available: one section, incoming order, no headers.
        let flat = CatalogBrowsing.machineSections(rows, by: .alphabetical)
        #expect(flat.count == 1)
        #expect(flat[0].title == nil)
        #expect(flat[0].rows.map(\.label) == rows.map(\.label))
    }

    // MARK: Performance

    /// Filtering must stay comfortably interactive while typing: the shipped
    /// catalog is ~1900 models and every keystroke refilters all of them.
    @Test func filteringTheWholeCatalogIsFastEnoughToTypeAgainst() {
        let rows = (0..<2_000).map { index in
            model("Manufacturer \(index % 25)", "Model \(index) Chest Press",
                  type: EquipmentCategory.allCases[index % 5],
                  areas: [BodyArea.order[index % BodyArea.order.count]])
        }
        let catalog = CatalogModelIndex(rows: rows)

        let start = Date()
        // One pass per character of a realistic query, plus grouping.
        for query in ["m", "ma", "man", "manu", "manufacturer 3 chest"] {
            let sections = CatalogBrowsing.browse(
                catalog,
                filter: CatalogModelFilter(searchText: query, bodyArea: "Chest"),
                grouping: .manufacturer)
            #expect(!sections.isEmpty)
        }
        let elapsed = Date().timeIntervalSince(start)

        #expect(elapsed < 1.0, "filtering 2000 rows five times took \(elapsed)s")
    }

    // MARK: Building from persisted rows

    @Test func indexBuildsFromPersistedRowsAndMarksUserModels() throws {
        let schema = WorkoutTrackerStore.schema
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)

        let chest = Exercise(
            name: "Seated Chest Press", equipmentTypeTags: [.machine],
            muscleGroup: "Chest", isSeeded: true)
        let row = Exercise(
            name: "Seated Row", equipmentTypeTags: [.machine],
            muscleGroup: "Back", isSeeded: true)
        context.insert(chest)
        context.insert(row)
        context.insert(EquipmentModel(
            manufacturer: "Hammer Strength", modelName: "Iso-Lateral Chest/Row",
            exerciseIDs: [chest.id, row.id], equipmentType: .plateLoaded, isSeeded: true))
        context.insert(EquipmentModel(
            manufacturer: "Acme", modelName: "Garage Press",
            exerciseIDs: [chest.id], isSeeded: false))
        try context.save()

        let index = CatalogModelIndex.build(
            models: try context.fetch(FetchDescriptor<EquipmentModel>()),
            exercises: try context.fetch(FetchDescriptor<Exercise>()))

        #expect(index.rows.map(\.displayName) == [
            "Acme Garage Press", "Hammer Strength Iso-Lateral Chest/Row",
        ])
        let hammer = try #require(index.rows.last)
        #expect(hammer.bodyAreas == ["Chest", "Back"])
        #expect(hammer.equipmentType == .plateLoaded)
        #expect(hammer.isSeeded)
        let acme = try #require(index.rows.first)
        #expect(acme.isSeeded == false)
        #expect(acme.equipmentType == nil)

        // The user model is grouped, not hidden: it has a body area from its
        // linked exercise but no equipment type.
        let sections = CatalogBrowsing.sections(index.rows, by: .equipmentType)
        #expect(sections.last?.title == CatalogBrowsing.uncategorized)
        #expect(sections.last?.rows.map(\.displayName) == ["Acme Garage Press"])
    }

    // MARK: The shipped catalog

    @Test func shippedCatalogIsBrowsableAtScale() throws {
        let catalog = try SeedCatalog.bundled()
        let bodyAreas = Dictionary(
            catalog.exercises.compactMap { exercise in
                exercise.muscleGroup.map { (exercise.id, $0) }
            },
            uniquingKeysWith: { first, _ in first })
        let index = CatalogModelIndex(rows: catalog.equipmentModels.map { model in
            CatalogModelRow(
                id: model.id, manufacturer: model.manufacturer, modelName: model.modelName,
                equipmentType: model.equipmentType,
                bodyAreas: CatalogBrowsing.uniqueValues(
                    model.exerciseIDs.compactMap { bodyAreas[$0] }))
        })

        // Every model reaches a body-area group (every exercise has one), and
        // all but a handful carry an equipment type — the few the research left
        // undetermined are honest nils, not guesses.
        #expect(index.rows.allSatisfy { !$0.bodyAreas.isEmpty })
        let untyped = index.rows.filter { $0.equipmentType == nil }
        #expect(untyped.count < 20, "\(untyped.count) shipped models have no equipment type")
        #expect(index.equipmentTypes.count == EquipmentCategory.allCases.count)

        // The ticket's example: "hammer incline" reaches the machine in one go.
        let hits = CatalogBrowsing.models(
            index.rows, matching: CatalogModelFilter(searchText: "hammer incline"))
        #expect(hits.count <= 12, "\(hits.count) rows still match 'hammer incline'")
        #expect(hits.contains { $0.displayName.contains("Iso-Lateral Incline Press") })

        // Filtering to one manufacturer's plate-loaded chest machines is a
        // short list rather than a scroll through 1887 rows.
        let narrowed = CatalogBrowsing.models(
            index.rows,
            matching: CatalogModelFilter(
                searchText: "hammer", bodyArea: "Chest", equipmentType: .plateLoaded))
        #expect(!narrowed.isEmpty)
        #expect(narrowed.count < 60)
    }
}
