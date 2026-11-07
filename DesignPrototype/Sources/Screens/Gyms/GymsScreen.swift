import SwiftUI

// G01 Gyms (tab root) and G02 Gyms — Empty.
// Gym cards carry identity (monogram), place (city · unit) and use (visits, last visit,
// machines) as big numbers with small labels. The Home gym is marked "Current". Add Gym… is
// the dashed "make one" row; with no gyms it becomes the screen's one filled command.

struct GymsScreen: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look

    var body: some View {
        let gyms = store.gymsTabOrder
        Group {
            if gyms.isEmpty {
                GymsEmptyState { router.present(.editGym(gymID: nil)) }
            } else {
                GymsList(gyms: gyms)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .lookScreenBackground()
        .proposalScreen("gyms")
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - G01 list

private struct GymsList: View {
    var gyms: [Gym]
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scroll = ScrollPosition(edge: .top)
    @State private var showsDeleted = false
    @State private var appeared = false

    var body: some View {
        let deleted = store.deletedGyms
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                LookNavTitle("Gyms")
                    .padding(.top, 12)
                    .padding(.bottom, look.space.section - 6)
                VStack(spacing: look.space.grid + 2) {
                    ForEach(gyms) { gym in
                        GymsCard(gym: gym, stats: store.gymsVisitStats(gym.id), isCurrent: gym.id == store.selectedGymID) {
                            router.push(.gymDetail(gymID: gym.id))
                        }
                        .transition(reduceMotion ? .opacity : .asymmetric(insertion: .scale(scale: 0.94).combined(with: .opacity),
                                                                           removal: .opacity))
                    }
                    GymsMakeRow(title: "Add Gym…") { router.present(.editGym(gymID: nil)) }
                }
                .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.82), value: gyms.map(\.id))
                if !deleted.isEmpty {
                    GymsDeletedGyms(gyms: deleted, expanded: $showsDeleted)
                        .padding(.top, look.space.section)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.bottom, 32)
            .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: deleted.map(\.id))
        }
        .scrollPosition($scroll)
        .gymsCapturePaging(router.variant, position: $scroll)
        .scrollIndicators(.hidden)
        .onAppear(perform: appear)
    }

    /// G01 capture variants: "fresh" (a gym with no city, never visited), "deleted" (Gangnam
    /// Fitness deleted: the Deleted Gyms list open with Restore).
    private func appear() {
        guard !appeared else { return }
        appeared = true
        switch GymsCapture.take(.g01, store: store, router: router) {
        case "fresh":
            store.addGym(name: "Garage Gym", city: nil, unit: nil)
            // It sorts last (never visited): bring it into view.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { scroll.scrollTo(edge: .bottom) }
        case "deleted":
            store.deleteGym(SampleData.gymID("Gangnam Fitness"))
            showsDeleted = true
        default: break
        }
    }
}

/// Deleted gyms: one quiet row with the count that opens in place (no page for two rows);
/// each gym keeps its monogram and gets Restore. Restoring checks, taps, and the card
/// returns to the list above.
private struct GymsDeletedGyms: View {
    var gyms: [Gym]
    @Binding var expanded: Bool
    @Environment(Store.self) private var store
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
                    Text("\(gyms.count)")
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
            .buttonStyle(GymsRowPressStyle())
            .accessibilityValue(expanded ? "Expanded" : "Collapsed")
            if expanded {
                ForEach(gyms) { gym in
                    row(gym)
                        .transition(.opacity)
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
                GymsMonogram(name: gym.name, size: 36).opacity(0.72)
                VStack(alignment: .leading, spacing: 2) {
                    Text(gym.name)
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    let subtitle = store.gymsSubtitle(gym)
                    if !subtitle.isEmpty {
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
            .buttonStyle(GymsQuietPillStyle())
            .disabled(isRestoring)
            .accessibilityLabel("Restore \(gym.name)")
            .padding(.leading, typeSize.isAccessibilitySize ? 48 : 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
    }

    private func restore(_ gym: Gym) {
        guard !restoring.contains(gym.id) else { return }
        restoredTick += 1
        if reduceMotion { store.restoreGym(gym.id); return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { _ = restoring.insert(gym.id) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) {
                store.restoreGym(gym.id)
                restoring.remove(gym.id)
            }
        }
    }
}

// MARK: - Gym card

struct GymsCard: View {
    var gym: Gym
    var stats: GymStats
    var isCurrent: Bool
    var action: () -> Void
    @Environment(Store.self) private var store
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                header
                if look.id != .anatomy { LookDivider() }
                GymsStatStrip(stats: statItems, embedded: true, columns: 3)
                // Never visited: nothing to draw yet (eight empty weeks would say nothing).
                if stats.visits > 0 { GymsVisitRhythm(counts: store.gymsWeeklyVisits(gym.id)) }
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

    private var statItems: [GymsStat] {
        var items = [GymsStat.count(stats.visits, stats.visits == 1 ? "Visit" : "Visits")]
        if let last = stats.lastVisit {
            items.append(GymsStat(value: GymsDate.label(last, now: store.now), label: "Last visit", isWord: true))
        }
        items.append(GymsStat.count(stats.machineCount, stats.machineCount == 1 ? "Machine" : "Machines"))
        return items
    }

    @ViewBuilder private var header: some View {
        let subtitle = store.gymsSubtitle(gym)
        HStack(alignment: typeSize.isAccessibilitySize ? .top : .center, spacing: 12) {
            GymsMonogram(name: gym.name, size: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(gym.name)
                    .font(look.font.cardTitle)
                    .foregroundStyle(look.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(look.font.subhead)
                        .foregroundStyle(look.textSecondary)
                }
                if isCurrent && typeSize.isAccessibilitySize { GymsCurrentBadge().padding(.top, 4) }
            }
            Spacer(minLength: 8)
            if isCurrent && !typeSize.isAccessibilitySize { GymsCurrentBadge() }
            Image(systemName: "chevron.right")
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(look.textTertiary)
        }
    }

    private var accessibilityText: String {
        var parts = [gym.name]
        if isCurrent { parts.append("Current") }
        if let city = gym.city { parts.append(city) }
        if let unit = gym.defaultUnit { parts.append(unit.label) }
        parts.append(Format.count(stats.visits, "visit"))
        if let last = stats.lastVisit { parts.append("Last visit \(GymsDate.label(last, now: store.now))") }
        parts.append(Format.count(stats.machineCount, "machine"))
        return parts.joined(separator: ", ")
    }
}

/// The Home gym, a state (not a control): the look's selection lozenge. A lit white, B pearl,
/// C cobalt ink on the pressed-paper fill (no outline: C outlines only what you can press).
struct GymsCurrentBadge: View {
    @Environment(\.look) private var look

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: look.gymSymbol).font(.system(.caption2, weight: .bold))
            Text("Current").font(.system(.caption, weight: .bold))
        }
        .foregroundStyle(look.selection)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(look.selectionFill, in: Capsule())
        .fixedSize()
    }
}

// MARK: - G02 empty

private struct GymsEmptyState: View {
    var add: () -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                LookNavTitle("Gyms").padding(.top, 12)
                VStack(spacing: 22) {
                    GymsEmptyEmblem()
                    Text("No gyms yet")
                        .font(look.font.title2)
                        .foregroundStyle(look.textPrimary)
                        .multilineTextAlignment(.center)
                    GymsPrimaryCapsule(title: "Add Gym…", symbol: "plus", action: add)
                        .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : 300)
                        .padding(.top, 6)
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

/// The building in a disc inside a dashed ring: an empty place waiting for its first gym.
private struct GymsEmptyEmblem: View {
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .largeTitle) private var disc: CGFloat = 92

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(look.id.isPaperClub ? look.outline : look.dash,
                              style: StrokeStyle(lineWidth: look.id.isPaperClub ? 2 : 1.5, dash: [6, 5]))
                .frame(width: disc + 36, height: disc + 36)
            Image(systemName: "building.2")
                .font(.system(size: disc * 0.4, weight: .semibold))
                .foregroundStyle(look.textPrimary)
                .frame(width: disc, height: disc)
                .background {
                    switch look.id {
                    case .floodlight: Circle().fill(look.surface).overlay { Circle().strokeBorder(look.hairline, lineWidth: 1) }
                    case .anatomy: Circle().fill(look.controlFill)
                    case .paper, .carbon: Circle().fill(look.surface).overlay { Circle().strokeBorder(look.outline, lineWidth: 2) }
                    }
                }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Visit rhythm (visits per week, last 8 weeks)

/// Eight weeks of visits at a gym, oldest to this week. A: lit scoreboard cells with the count.
/// B: pearl bars by count. C: punched weeks. This week unvisited is the dashed "today" mark.
struct GymsVisitRhythm: View {
    var counts: [Int]
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .caption) private var cellHeight: CGFloat = 22

    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        layout {
            Text("Last 8 weeks")
                .font(.system(.caption, weight: look.id == .floodlight ? .regular : .semibold))
                .foregroundStyle(look.textSecondary)
                .fixedSize()
            HStack(alignment: .bottom, spacing: look.id == .anatomy ? 0 : 4) {
                ForEach(Array(counts.enumerated()), id: \.offset) { index, count in
                    cell(count, isThisWeek: index == counts.count - 1)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: look.id == .anatomy ? cellHeight + 6 : cellHeight)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Visits per week, last 8 weeks: \(counts.map(String.init).joined(separator: ", "))")
    }

    @ViewBuilder
    private func cell(_ count: Int, isThisWeek: Bool) -> some View {
        switch look.id {
        case .floodlight:
            let shape = RoundedRectangle(cornerRadius: 5, style: .continuous)
            if count > 0 {
                Text("\(count)")
                    .font(Font.system(.caption2, weight: .heavy).width(.expanded).monospacedDigit())
                    .foregroundStyle(look.onDone)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(look.done, in: shape)
            } else if isThisWeek {
                shape.strokeBorder(look.dash, style: StrokeStyle(lineWidth: 1.2, dash: [3, 2.5]))
            } else {
                shape.fill(look.ringTrack)
            }
        case .anatomy:
            let maxCount = CGFloat(max(3, counts.max() ?? 1))
            if count > 0 {
                RoundedRectangle(cornerRadius: 5, style: .continuous).fill(look.done)
                    .frame(width: 16, height: 8 + (cellHeight - 2) * CGFloat(count) / maxCount)
            } else if isThisWeek {
                // The open slot this week: a dashed outline as wide and as tall as one visit.
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(look.textSecondary, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2.5]))
                    .frame(width: 16, height: 8 + (cellHeight - 2) / maxCount)
            } else {
                RoundedRectangle(cornerRadius: 4, style: .continuous).fill(look.dayDotPast).frame(width: 16, height: 6)
            }
        case .paper, .carbon:
            let side = min(cellHeight, 22)
            if count > 0 {
                Image(systemName: "checkmark")
                    .font(.system(size: side * 0.48, weight: .heavy))
                    .foregroundStyle(look.onDone)
                    .frame(width: side, height: side)
                    .background(look.done, in: Circle())
            } else if isThisWeek {
                Circle().strokeBorder(look.actionText, style: StrokeStyle(lineWidth: 1.6, dash: [3, 2.2]))
                    .frame(width: side, height: side)
            } else {
                Circle().strokeBorder(look.dayDotFuture, lineWidth: 1.5).frame(width: side, height: side)
            }
        }
    }
}
