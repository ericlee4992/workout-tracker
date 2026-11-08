import SwiftUI

// Soft redesign S5 (D77): Train → My split. Off (the default) lets Today learn the order from history; In order and By
// weekday make Today follow the user's own split exactly. Saved as template ids in UserDefaults (`MySplitStore`) — a
// view preference, not workout data, so it never changes the stored format (S5 comes before N1's safety copy).

struct MySplitSheet: View {
    let templates: [WorkoutTemplate]
    @AppStorage(MySplitStore.key) private var splitData = Data()
    @AppStorage(UpNextOverride.key) private var overrideData = Data()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var mode = 0
    @State private var order: [UUID] = []
    @State private var days: [Int: UUID] = [:]
    @State private var loaded = false

    private static let modes = ["Off", "In order", "By weekday"]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if typeSize.isAccessibilitySize {
                        // Three pills do not fit at accessibility sizes ("By wee…"): one row per choice.
                        ForEach(Self.modes.indices, id: \.self) { index in
                            Button { mode = index } label: {
                                HStack {
                                    Text(Self.modes[index]).foregroundStyle(look.textPrimary)
                                    Spacer()
                                    if mode == index { Image(systemName: "checkmark").fontWeight(.semibold) }
                                }
                            }
                            .accessibilityAddTraits(mode == index ? .isSelected : [])
                        }
                        .lookListRows()
                    } else {
                        SegmentedPills(Self.modes, selection: $mode)
                            .accessibilityIdentifier("mySplitMode")
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                            .listRowBackground(Color.clear)
                    }
                } footer: {
                    Text(explanation).font(look.font.footnote).foregroundStyle(look.textSecondary)
                }
                switch mode {
                case 1: inOrder
                case 2: byWeekday
                default: EmptyView()
                }
            }
            .lookGroupedList()
            .environment(\.editMode, .constant(mode == 1 ? .active : .inactive))
            .navigationTitle("My Split")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                        .accessibilityIdentifier("mySplitSave")
                }
            }
            .onAppear(perform: load)
        }
    }

    private var explanation: String {
        switch mode {
        case 1: "Today suggests the template after the last one you did, in this order. After the last, it starts again."
        case 2: "Today suggests the template for that weekday. A day without one is a rest day."
        default: "Today suggests what usually comes next, learned from the order you train in."
        }
    }

    // MARK: In order

    @ViewBuilder private var inOrder: some View {
        Section {
            ForEach(order, id: \.self) { id in
                Text(name(id)).font(look.font.body).foregroundStyle(look.textPrimary)
                    .accessibilityIdentifier("mySplitOrderRow")
            }
            .onMove { order.move(fromOffsets: $0, toOffset: $1) }
            .onDelete { order.remove(atOffsets: $0) }
            let unused = templates.filter { !order.contains($0.id) }
            if !unused.isEmpty {
                Menu {
                    ForEach(unused) { template in
                        Button(template.name) { order.append(template.id) }
                    }
                } label: {
                    Label("Add Template", systemImage: "plus")
                }
                .accessibilityIdentifier("mySplitAdd")
            }
        } header: {
            LookSectionLabel(title: "Order")
        }
        .lookListRows()
    }

    // MARK: By weekday

    private var weekdays: [Int] {
        let first = Calendar.current.firstWeekday
        return (0..<7).map { (first - 1 + $0) % 7 + 1 }
    }

    @ViewBuilder private var byWeekday: some View {
        Section {
            ForEach(weekdays, id: \.self) { day in
                Picker(Calendar.current.weekdaySymbols[day - 1], selection: Binding(
                    get: { days[day] },
                    set: { days[day] = $0 })) {
                    Text("Rest").tag(UUID?.none)
                    ForEach(templates) { Text($0.name).tag(UUID?.some($0.id)) }
                }
                .accessibilityIdentifier("mySplitDay.\(day)")
            }
        } header: {
            LookSectionLabel(title: "Week")
        }
        .lookListRows()
    }

    // MARK: Load / save

    private var canSave: Bool {
        switch mode {
        case 1: !order.isEmpty
        case 2: !days.isEmpty
        default: true
        }
    }

    private func name(_ id: UUID) -> String { templates.first { $0.id == id }?.name ?? "" }

    private func load() {
        guard !loaded else { return }
        loaded = true
        switch MySplitStore.decode(splitData).pruned(to: Set(templates.map(\.id))) {
        case .off: mode = 0
        case .inOrder(let ids): mode = 1; order = ids
        case .byWeekday(let map): mode = 2; days = map
        }
        // A sensible start for In order: every template, by name.
        if order.isEmpty { order = templates.map(\.id) }
    }

    private func save() {
        let split: MySplit = switch mode {
        case 1: .inOrder(order)
        case 2: .byWeekday(days.compactMapValues { $0 })
        default: .off
        }
        splitData = MySplitStore.encode(split)
        // A new plan replaces the day's "Not today" choice.
        overrideData = Data()
        dismiss()
    }
}
