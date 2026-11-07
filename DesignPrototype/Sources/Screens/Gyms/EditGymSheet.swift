import SwiftUI

// G05 New Gym / Edit Gym. A live preview of the gym's card (monogram, name, city · unit)
// answers every keystroke; then Name, City, and the default unit as three plain choices (the
// first names the unit it resolves to). Edit mode adds the one consequence line and Delete
// Gym… (confirmed; logged workouts keep the gym's name).
//
// Save is live only once a field differs from the stored gym; Add once a name is typed.
// Capture variants (G05): "new" (Add Gym… over G05's gym), "newname" (New Gym with a name and
// city typed: Add live), "delete" (the Delete Gym alert).

struct EditGymSheet: View {
    let gymID: UUID?

    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    @State private var name = ""
    @State private var city = ""
    @State private var unit = 0
    @State private var loaded = false
    @State private var confirmDelete = false
    @State private var captureNew = false
    @FocusState private var focus: Field?

    private enum Field { case name, city }

    private var isNew: Bool { gymID == nil || captureNew }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var cityValue: String? { city.trimmingCharacters(in: .whitespaces).nilIfEmpty }
    /// New: a name. Edit: a name, and something differs from the stored gym.
    private var canCommit: Bool {
        guard !trimmedName.isEmpty else { return false }
        guard !isNew, let gym = store.gym(gymID) else { return true }
        return trimmedName != gym.name || cityValue != gym.city || WeightUnit?.gymsFromSegment(unit) != gym.defaultUnit
    }
    /// This view sits above its own type-size override, so read the override directly.
    private var isAX: Bool { (router.dynamicTypeOverride ?? typeSize).isAccessibilitySize }

    var body: some View {
        VStack(spacing: 0) {
            GymsSheetHeader(title: isNew ? "New Gym" : "Edit Gym", cancel: { dismiss() },
                            commitTitle: isNew ? "Add" : "Save", commitEnabled: canCommit, commit: save)
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.section - 4) {
                    preview
                    fields
                    unitSection
                    if !isNew {
                        DestructiveRowButton("Delete Gym…") { confirmDelete = true }
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
        .presentationBackground(look.groundSheet)
        .presentationDragIndicator(.visible)
        .gymsSheetTypeOverride(router.dynamicTypeOverride)
        .onAppear(perform: load)
        .alert("Delete \(store.gym(gymID)?.name ?? "gym")?", isPresented: $confirmDelete) {
            Button("Delete Gym", role: .destructive, action: deleteGym)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Logged workouts keep the gym's name.")
        }
    }

    // MARK: Preview

    private var preview: some View {
        let shownName = trimmedName.isEmpty ? (isNew ? "New Gym" : "") : trimmedName
        let unitLabel = WeightUnit?.gymsFromSegment(unit)?.label
        let subtitle = [city.trimmingCharacters(in: .whitespaces).nilIfEmpty, unitLabel].compactMap { $0 }.joined(separator: " · ")
        return HStack(spacing: 14) {
            GymsMonogram(name: shownName, size: 56)
                .id(GymsMonogram.initials(shownName))
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            VStack(alignment: .leading, spacing: 3) {
                Text(shownName)
                    .font(look.font.cardTitle)
                    .foregroundStyle(trimmedName.isEmpty ? look.textTertiary : look.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(look.font.subhead)
                        .foregroundStyle(look.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.tile)
        .animation(.snappy(duration: 0.25), value: GymsMonogram.initials(shownName))
        .accessibilityElement(children: .combine)
    }

    // MARK: Fields

    private var fields: some View {
        LookList {
            field("Name", prompt: "Required", text: $name, which: .name)
            field("City", prompt: "Optional", text: $city, which: .city)
        }
    }

    private func field(_ label: String, prompt: String, text: Binding<String>, which: Field) -> some View {
        let layout = isAX ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            Text(label)
                .font(.system(.body, weight: .medium))
                .foregroundStyle(look.textSecondary)
                .frame(minWidth: isAX ? nil : 56, alignment: .leading)
            TextField(label, text: text, prompt: Text(prompt).foregroundStyle(look.textTertiary))
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(look.textPrimary)
                .tint(look.actionText)
                .textInputAutocapitalization(.words)
                .submitLabel(which == .name ? .next : .done)
                .focused($focus, equals: which)
                .onSubmit { focus = which == .name ? .city : nil }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, isAX ? 10 : 0)
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
            GymsUnitChoice(options: ["App (\(store.displayUnit.label))", "kg", "lb"], selection: $unit)
            if !isNew {
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
        switch gymID == store.screenTarget.gymID ? GymsCapture.take(.g05, store: store, router: router) : nil {
        case "new": captureNew = true
        case "newname":
            captureNew = true
            name = "Peak Performance"
            city = "Busan"
        case "delete": DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { confirmDelete = true }
        default: break
        }
        if !isNew, let gym = store.gym(gymID) {
            name = gym.name
            city = gym.city ?? ""
            unit = gym.defaultUnit.gymsSegment
        } else {
            unit = 0
        }
    }

    private func save() {
        guard canCommit else { return }
        if !isNew, var gym = store.gym(gymID) {
            gym.name = trimmedName
            gym.city = cityValue
            gym.defaultUnit = WeightUnit?.gymsFromSegment(unit)
            store.updateGym(gym)
        } else {
            store.addGym(name: trimmedName, city: cityValue, unit: WeightUnit?.gymsFromSegment(unit),
                         select: store.activeGyms.isEmpty)
        }
        dismiss()
    }

    private func deleteGym() {
        guard let gymID else { return }
        store.deleteGym(gymID)
        router.gymsPath = NavigationPath()
        dismiss()
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
