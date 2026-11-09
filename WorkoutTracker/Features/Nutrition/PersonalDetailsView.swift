import SwiftData
import SwiftUI

/// Nutrition N3 (D80) — Profile → Settings → Personal details: the one place for weight, height, date of birth and
/// sex, read by the nutrition goals, the heart rate zones (the same `AppPreferences.birthDate` the zones sheet edits)
/// and the AI. Each row opens a small editor; every save brings the stored goal up to date (`NutritionGoalStore`).
struct PersonalDetailsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.look) private var look
    @Query private var allPreferences: [AppPreferences]
    @Query(sort: \BodyWeightEntry.measuredAt, order: .reverse) private var weights: [BodyWeightEntry]
    @State private var editing: Field?
    @State private var saveFailure: String?

    enum Field: String, Identifiable { case weight, height, birthDate, sex; var id: String { rawValue } }

    private var preferences: AppPreferences? { AppPreferences.canonical(of: allPreferences) }
    private var usCustomary: Bool { AppUnitSystem.resolve(preference: preferences?.unitPreference) == .usCustomary }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: look.space.section) {
                LookNavTitle("Personal details")
                LookList(separatorInset: 54) {
                    ProfileRow("Weight", symbol: "scalemass", value: weights.first.map(DetailFormat.weight) ?? "Not set") {
                        editing = .weight
                    }
                    .accessibilityIdentifier("personalWeight")
                    ProfileRow("Height", symbol: "ruler", value: heightText) { editing = .height }
                        .accessibilityIdentifier("personalHeight")
                    ProfileRow("Date of birth", symbol: "calendar",
                               value: preferences?.birthDate?.formatted(date: .abbreviated, time: .omitted) ?? "Not set") {
                        editing = .birthDate
                    }
                    .accessibilityIdentifier("personalBirthDate")
                    sexRow
                }
                Text("Used for your nutrition goals, heart rate zones and AI suggestions.")
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 2)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .lookScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { field in editor(field) }
        .alert("Couldn't save", isPresented: Binding(get: { saveFailure != nil }, set: { if !$0 { saveFailure = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(saveFailure ?? "") }
    }

    private var heightText: String {
        guard let value = preferences?.heightValue, let unit = preferences?.heightUnit else { return "Not set" }
        return DetailFormat.height(value: value, unit: unit)
    }

    /// Sex is a choice of three: a menu showing the current value (ios-design: a collapsed picker keeps its value and
    /// disclosure, never the primary style).
    private var sexRow: some View {
        Menu {
            Picker("Sex", selection: Binding(
                get: { preferences?.sex },
                set: { sex in if let sex { save { $0.sex = sex } } })) {
                ForEach(BiologicalSex.allCases, id: \.self) { Text($0.label).tag(Optional($0)) }
            }
        } label: {
            ProfileRow("Sex", symbol: "person", value: preferences?.sex?.label ?? "Not set", action: nil)
        }
        .accessibilityIdentifier("personalSex")
    }

    @ViewBuilder private func editor(_ field: Field) -> some View {
        switch field {
        case .weight:
            let unit: WeightUnit = weights.first?.unit ?? (usCustomary ? .lb : .kg)
            NumberEditorSheet(title: "Weight", unit: unit.rawValue, initial: weights.first?.value, fractionDigits: 1,
                              range: unit == .lb ? 50...800 : 20...360, fieldID: "weightField") { value in
                commit { context in context.insert(BodyWeightEntry(measuredAt: .now, value: value, unit: unit)) }
            }
        case .height:
            HeightEditorSheet(usCustomary: usCustomary, initialCm: preferences?.heightCm) { value, unit in
                save { $0.setHeight(value: value, unit: unit) }
            }
        case .birthDate:
            BirthDateEditorSheet(initial: preferences?.birthDate) { date in save { $0.birthDate = date } }
        case .sex:
            EmptyView()
        }
    }

    private func save(_ change: @escaping (AppPreferences) -> Void) {
        commit { context in
            let preferences = try AppPreferences.canonical(in: context)
            change(preferences)
            preferences.updatedAt = .now
        }
    }

    /// Writes the change, then brings the goal up to date (it follows Personal details).
    private func commit(_ change: (ModelContext) throws -> Void) {
        do {
            try change(modelContext)
            try modelContext.save()
            try NutritionGoalStore.update(in: modelContext)
        } catch {
            saveFailure = error.localizedDescription
        }
    }
}
