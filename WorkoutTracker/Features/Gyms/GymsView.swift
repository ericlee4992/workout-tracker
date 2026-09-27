import SwiftData
import SwiftUI

/// The Gyms tab (Floodlight redesign ticket 06): one card per gym — its monogram, name, city and
/// unit, the Current badge, visits / last visit / machines and the last eight weeks — then Add
/// Gym… and the deleted gyms with Restore. With no gyms, one invitation.
struct GymsView: View {
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Gym.name) private var allGyms: [Gym]
    @Query(filter: #Predicate<Workout> { $0.finishedAt != nil }) private var finished: [Workout]
    @Query private var allPreferences: [AppPreferences]
    @State private var showingAddGym = false
    /// The cards are Buttons that push a gym's id (its page pushes its machines itself).
    @State private var path: [UUID] = []
    @State private var titleInBar = false
    @State private var showsDeleted = false

    private var gyms: [Gym] { allGyms.filter { !$0.archived } }
    private var deletedGyms: [Gym] { allGyms.filter(\.archived) }
    private var currentGymID: UUID? {
        GymSelection.resolve(id: AppPreferences.canonical(of: allPreferences)?.selectedGymID, among: gyms)?.id
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if gyms.isEmpty && deletedGyms.isEmpty {
                    empty
                } else {
                    list
                }
            }
            .lookScreenBackground()
            .gymsInlineTitle("Gyms", visible: titleInBar)
            .navigationDestination(for: UUID.self) { gymID in
                // A gym deleted from its own page pops back here; a stale id shows nothing.
                if let gym = allGyms.first(where: { $0.id == gymID && !$0.archived }) {
                    GymDetailView(gym: gym)
                }
            }
            .sheet(isPresented: $showingAddGym) {
                GymEditorSheet()
            }
        }
    }

    // MARK: List (G01)

    private var list: some View {
        let visits = GymOverviewMath.visitInputs(finished)
        let facts = Dictionary(uniqueKeysWithValues: gyms.map {
            ($0.id, GymOverviewMath.visits(of: $0.id, in: visits, now: .now))
        })
        let order = GymOverviewMath.order(gyms.map { (id: $0.id, name: $0.name) }, current: currentGymID,
                                          lastVisit: facts.compactMapValues(\.lastVisit))
        let byID = Dictionary(gyms.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                LookNavTitle("Gyms")
                    .padding(.top, 2)
                    .padding(.bottom, look.space.section - 6)
                VStack(spacing: look.space.grid + 2) {
                    ForEach(order.compactMap { byID[$0] }) { gym in
                        GymCard(gym: gym, visits: facts[gym.id] ?? .none, isCurrent: gym.id == currentGymID) {
                            path.append(gym.id)
                        }
                        .accessibilityIdentifier("gymRow.\(gym.name)")
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.94).combined(with: .opacity))
                    }
                    MakeRow(title: "Add Gym…") { showingAddGym = true }
                        .accessibilityIdentifier("addGym")
                }
                .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.82), value: order)
                if !deletedGyms.isEmpty {
                    DeletedGymsList(gyms: deletedGyms, expanded: $showsDeleted)
                        .padding(.top, look.space.section)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.bottom, 32)
            .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: deletedGyms.map(\.id))
        }
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: Bool.self) { geo in
            geo.contentOffset.y + geo.contentInsets.top > (typeSize.isAccessibilitySize ? 70 : 46)
        } action: { _, past in
            withAnimation(.easeInOut(duration: 0.18)) { titleInBar = past }
        }
    }

    // MARK: Empty (G02)

    private var empty: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                LookNavTitle("Gyms").padding(.top, 2)
                VStack(spacing: 22) {
                    GymsEmptyEmblem()
                    Text("No gyms yet")
                        .font(look.font.title2)
                        .foregroundStyle(look.textPrimary)
                        .multilineTextAlignment(.center)
                    StartCapsule(title: "Add Gym…", symbol: "plus") { showingAddGym = true }
                        .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : 300)
                        .padding(.top, 6)
                        .accessibilityIdentifier("addGym")
                }
                .frame(maxWidth: .infinity)
                .padding(.top, typeSize.isAccessibilitySize ? 40 : 150)
            }
            .padding(.horizontal, look.space.margin)
            .padding(.bottom, 40)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

// MARK: - Gym card

/// A gym: identity (monogram), place (city · unit), use (visits, last visit, machines) as big
/// numbers with small labels, and once visited the last eight weeks. One button.
struct GymCard: View {
    var gym: Gym
    var visits: GymVisits
    var isCurrent: Bool
    var action: () -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                header
                LookDivider()
                GymStatStrip(stats: stats, embedded: true, columns: 3)
                // Never visited: nothing to draw yet (eight empty weeks would say nothing).
                if visits.visits > 0 { GymVisitRhythm(counts: visits.weekly) }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lookSurface(.tile)
            .contentShape(RoundedRectangle(cornerRadius: look.radius.tile, style: .continuous))
        }
        .buttonStyle(.lookPressable)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
    }

    private var stats: [GymStat] {
        var items = [GymStat.count(visits.visits, "Visit", "Visits")]
        if let last = visits.lastVisit { items.append(.day(last, "Last visit")) }
        let machines = gym.activeMachines.count
        items.append(.count(machines, "Machine", "Machines"))
        return items
    }

    private var header: some View {
        HStack(alignment: typeSize.isAccessibilitySize ? .top : .center, spacing: 12) {
            GymMonogram(name: gym.name, size: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(gym.name)
                    .font(look.font.cardTitle)
                    .foregroundStyle(look.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle = gym.placeLine {
                    Text(subtitle)
                        .font(look.font.subhead)
                        .foregroundStyle(look.textSecondary)
                }
                if isCurrent && typeSize.isAccessibilitySize { GymCurrentBadge().padding(.top, 4) }
            }
            Spacer(minLength: 8)
            if isCurrent && !typeSize.isAccessibilitySize { GymCurrentBadge() }
            Image(systemName: "chevron.right")
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(look.textTertiary)
        }
    }

    private var accessibilityText: String {
        var parts = [gym.name]
        if isCurrent { parts.append("Current") }
        if let city = gym.city { parts.append(city) }
        if let unit = gym.defaultUnit { parts.append(unit.rawValue) }
        parts.append("\(visits.visits) visit\(visits.visits == 1 ? "" : "s")")
        if let last = visits.lastVisit { parts.append("Last visit \(GymOverviewMath.relativeDay(last, now: .now))") }
        let machines = gym.activeMachines.count
        parts.append("\(machines) machine\(machines == 1 ? "" : "s")")
        // The rhythm the card draws, spoken as its cells read (the card replaces its children).
        if visits.visits > 0 {
            parts.append("Visits per week, last 8 weeks: \(visits.weekly.map(String.init).joined(separator: ", "))")
        }
        return parts.joined(separator: ", ")
    }
}

extension Gym {
    /// "Seoul · lb": the city and the gym's own unit, each only when set.
    var placeLine: String? {
        let line = [city, defaultUnit?.rawValue].compactMap { $0 }.joined(separator: " · ")
        return line.isEmpty ? nil : line
    }
}

// MARK: - Deleted gyms

/// One quiet row with the count that opens in place (no page for two rows); each gym keeps its
/// monogram and gets Restore — a check, a success tap, and the card returns above.
private struct DeletedGymsList: View {
    var gyms: [Gym]
    @Binding var expanded: Bool
    @Environment(\.modelContext) private var modelContext
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var restoring: Set<UUID> = []
    @State private var restoredTick = 0

    var body: some View {
        LookList(separatorInset: 16) {
            Button {
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.28)) { expanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "trash")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(look.textSecondary)
                        .frame(width: 28)
                    Text("Deleted gyms")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(look.textPrimary)
                    Spacer(minLength: 8)
                    Text(verbatim: "\(gyms.count)")
                        .font(look.font.fieldNumber)
                        .foregroundStyle(look.textSecondary)
                    Image(systemName: "chevron.down")
                        .font(.system(.footnote, weight: .semibold))
                        .foregroundStyle(look.textTertiary)
                        .rotationEffect(.degrees(expanded ? 0 : -90))
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(expanded ? "Expanded" : "Collapsed")
            .accessibilityIdentifier("deletedGyms")
            if expanded {
                ForEach(gyms) { gym in
                    row(gym).transition(.opacity)
                }
            }
        }
        .sensoryFeedback(.success, trigger: restoredTick)
    }

    private func row(_ gym: Gym) -> some View {
        let isRestoring = restoring.contains(gym.id)
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        return layout {
            HStack(spacing: 12) {
                GymMonogram(name: gym.name, size: 36).opacity(0.72)
                VStack(alignment: .leading, spacing: 2) {
                    Text(gym.name)
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let subtitle = gym.placeLine {
                        Text(subtitle).font(look.font.footnote).foregroundStyle(look.textSecondary)
                    }
                }
            }
            if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
            Button { restore(gym) } label: {
                ZStack {
                    Text("Restore").opacity(isRestoring ? 0 : 1)
                    Image(systemName: "checkmark")
                        .font(.system(.subheadline, weight: .heavy))
                        .opacity(isRestoring ? 1 : 0)
                        .scaleEffect(isRestoring ? 1 : 0.4)
                }
            }
            .buttonStyle(QuietPillStyle())
            .disabled(isRestoring)
            .accessibilityLabel("Restore \(gym.name)")
            .accessibilityIdentifier("restoreGym.\(gym.name)")
            .padding(.leading, typeSize.isAccessibilitySize ? 48 : 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
    }

    private func restore(_ gym: Gym) {
        guard !restoring.contains(gym.id) else { return }
        restoredTick += 1
        if reduceMotion { commit(gym); return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { _ = restoring.insert(gym.id) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) {
                commit(gym)
                restoring.remove(gym.id)
            }
        }
    }

    private func commit(_ gym: Gym) {
        do { try EquipmentLifecycle(context: modelContext).restore(gym) }
        catch { assertionFailure("Failed to restore gym: \(error)") }
    }
}

/// The building in a disc inside a dashed ring: an empty place waiting for its first gym.
private struct GymsEmptyEmblem: View {
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .largeTitle) private var disc: CGFloat = 92

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(look.dash, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                .frame(width: disc + 36, height: disc + 36)
            Image(systemName: "building.2")
                .font(.system(size: disc * 0.4, weight: .semibold))
                .foregroundStyle(look.textPrimary)
                .frame(width: disc, height: disc)
                .background {
                    Circle().fill(look.surface).overlay { Circle().strokeBorder(look.hairline, lineWidth: 1) }
                }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: WorkoutTrackerStore.schema,
        configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
    container.mainContext.insert(Gym(name: "Gangnam Fitness", city: "Seoul", defaultUnit: .kg))
    container.mainContext.insert(Gym(name: "Hotel Gym"))
    return GymsView()
        .modelContainer(container)
}
