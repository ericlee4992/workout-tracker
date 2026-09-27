import SwiftData
import SwiftUI

/// Ticket 06's add-gym form, doubling as the edit form (D2, ticket 17): the fields a gym is
/// created with are exactly the fields it can be corrected with.
///
/// Floodlight redesign ticket 06 (G05): a live preview of the gym's card answers every keystroke;
/// then Name and City, and the default unit as three plain choices (the first names the unit it
/// resolves to). Editing adds the one consequence line and Delete Gym… (confirmed; archived
/// underneath, D10, and restorable from the Gyms list). Add needs a name; Save a name and a change.
struct GymEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// nil = create a new gym; non-nil = edit that gym in place.
    var gym: Gym?
    var onSave: (Gym) -> Void = { _ in }
    @Query private var allPreferences: [AppPreferences]
    @State private var saveFailure: String?
    @State private var name = ""
    @State private var city = ""
    @State private var unitIndex = 0
    @State private var loaded = false
    @State private var confirmDelete = false
    @FocusState private var focus: Field?

    private enum Field { case name, city }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedCity: String { city.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var defaultUnit: WeightUnit? { .fromUnitChoice(unitIndex) }

    private var canCommit: Bool {
        guard !trimmedName.isEmpty else { return false }
        guard let gym else { return true }
        return trimmedName != gym.name || (trimmedCity.isEmpty ? nil : trimmedCity) != gym.city
            || defaultUnit != gym.defaultUnit
    }

    private var appUnit: WeightUnit {
        UnitPrecedence.defaultUnit(
            machineUnit: nil, gymUnit: nil,
            appPreference: AppPreferences.canonical(of: allPreferences)?.unitPreference)
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(cancel: { dismiss() }, title: gym == nil ? "New Gym" : "Edit Gym", commit: save,
                        commitTitle: gym == nil ? "Add" : "Save", commitEnabled: canCommit,
                        commitIdentifier: "saveGym", reflowsTitle: true)
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.section - 4) {
                    if let saveFailure {
                        Text(saveFailure).font(look.font.footnote).foregroundStyle(look.destructive)
                    }
                    preview
                    LookList {
                        field("Name", prompt: "Required", text: $name, which: .name, identifier: "gymName")
                        field("City", prompt: "Optional", text: $city, which: .city, identifier: "gymCity")
                    }
                    unitSection
                    if gym != nil {
                        DestructiveRowButton("Delete Gym…") { confirmDelete = true }
                            .accessibilityIdentifier("deleteGym")
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .lookSheetGround()
        .presentationDragIndicator(.visible)
        .onAppear(perform: load)
        .alert("Delete \(gym?.name ?? "gym")?", isPresented: $confirmDelete) {
            Button("Delete Gym", role: .destructive, action: deleteGym)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Logged workouts keep the gym's name.")
        }
    }

    // MARK: Preview

    private var preview: some View {
        let shownName = trimmedName.isEmpty ? (gym == nil ? "New Gym" : "") : trimmedName
        let place = [trimmedCity.isEmpty ? nil : trimmedCity, defaultUnit?.rawValue].compactMap { $0 }
            .joined(separator: " · ")
        return HStack(spacing: 14) {
            GymMonogram(name: shownName, size: 56)
                .id(GymMonogram.initials(shownName))
                .transition(reduceMotion ? .opacity : .scale(scale: 0.8).combined(with: .opacity))
            VStack(alignment: .leading, spacing: 3) {
                Text(shownName)
                    .font(look.font.cardTitle)
                    .foregroundStyle(trimmedName.isEmpty ? look.textTertiary : look.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if !place.isEmpty {
                    Text(place)
                        .font(look.font.subhead)
                        .foregroundStyle(look.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.tile)
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .snappy(duration: 0.25),
                   value: GymMonogram.initials(shownName))
        .accessibilityElement(children: .combine)
    }

    // MARK: Fields

    private func field(_ label: String, prompt: String, text: Binding<String>, which: Field,
                       identifier: String) -> some View {
        let ax = typeSize.isAccessibilitySize
        let layout = ax ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            Text(label)
                .font(.system(.body, weight: .medium))
                .foregroundStyle(look.textSecondary)
                .frame(minWidth: ax ? nil : 56, alignment: .leading)
            TextField(label, text: text, prompt: Text(prompt).foregroundStyle(look.textTertiary))
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(look.textPrimary)
                .tint(look.actionText)
                .textInputAutocapitalization(.words)
                .submitLabel(which == .name ? .next : .done)
                .focused($focus, equals: which)
                .onSubmit { focus = which == .name ? .city : nil }
                .accessibilityLabel(Text(label))
                .accessibilityIdentifier(identifier)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, ax ? 10 : 0)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { focus = which }
    }

    private var unitSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Default unit")
                .font(look.font.headline)
                .foregroundStyle(look.textPrimary)
                .padding(.leading, 4)
            UnitChoice(options: ["App (\(appUnit.rawValue))", "kg", "lb"], selection: $unitIndex)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("gymUnitPicker")
            // D2: a correction changes what comes next, never what was logged.
            if gym != nil {
                Text("Future sets only. Logged sets keep their unit.")
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
                    .padding(.horizontal, 4)
            }
        }
    }

    // MARK: Actions

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let gym else { return }
        name = gym.name
        city = gym.city ?? ""
        unitIndex = gym.defaultUnit.unitChoiceIndex
    }

    private func save() {
        guard canCommit else { return }
        do {
            if let gym {
                try EquipmentLifecycle(context: modelContext).update(
                    gym, name: name, city: city, defaultUnit: defaultUnit)
                onSave(gym)
            } else {
                let created = Gym(
                    name: trimmedName,
                    city: trimmedCity.isEmpty ? nil : trimmedCity,
                    defaultUnit: defaultUnit)
                modelContext.insert(created)
                try modelContext.save()
                onSave(created)
            }
        } catch {
            saveFailure = error.localizedDescription
            return
        }
        dismiss()
    }

    /// Delete = archive (D10): the gym leaves the pickers and the Home selection (the remembered
    /// id is cleared, and Home drops its cached pick), its workouts keep their snapshot name, and
    /// the Gyms list can restore it.
    private func deleteGym() {
        guard let gym else { return }
        do {
            try EquipmentLifecycle(context: modelContext).archive(gym)
            if AppPreferences.canonical(of: allPreferences)?.selectedGymID == gym.id {
                try GymSelection.remember(nil, in: modelContext)
            }
            dismiss()
        } catch {
            saveFailure = error.localizedDescription
        }
    }
}
