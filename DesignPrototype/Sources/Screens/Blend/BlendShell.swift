import SwiftUI

// DIRECTION C "Blend" — navigation. Tabs: Today · Train · Food · Progress (Fable) or Today · Train ·
// Progress · Library (Astra). The +: a black circle beside the bar opening 2×2 ink slabs (Fable), or
// a labelled "+ Add" bar above the tabs on Today / Progress opening a list (Astra).

enum BlendTab: Hashable { case today, train, food, progress, library }

struct BlendTabBar: View {
    var selection: BlendTab
    var select: (BlendTab) -> Void
    var add: () -> Void
    @Environment(\.look) private var look
    @State private var options = BlendOptions.shared

    private var items: [(BlendTab, String, String)] {
        options.tabs == .food
            ? [(.today, "Today", "sun.max"), (.train, "Train", "dumbbell"), (.food, "Food", "fork.knife"), (.progress, "Progress", "chart.bar")]
            : [(.today, "Today", "sun.max"), (.train, "Train", "dumbbell"), (.progress, "Progress", "chart.bar"), (.library, "Library", "books.vertical")]
    }

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 0) {
                ForEach(items, id: \.0) { item in
                    let on = item.0 == selection
                    Button { select(item.0) } label: {
                        VStack(spacing: 3) {
                            Image(systemName: on ? item.2 + ".fill" : item.2)
                                .font(.system(size: 19, weight: on ? .semibold : .regular)).frame(height: 24)
                            Text(item.1).font(.system(size: 11, weight: on ? .bold : .medium))
                        }
                        .foregroundStyle(on ? look.textPrimary : look.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background { if on { Capsule().fill(look.textPrimary.opacity(look.isDark ? 0.14 : 0.07)).padding(3) } }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(4)
            .glassEffect(.regular, in: Capsule())
            if options.add == .circle {
                Button(action: add) {
                    Image(systemName: "plus").font(.system(size: 24, weight: .semibold)).foregroundStyle(look.onAction)
                        .frame(width: 62, height: 62).background(look.action, in: Circle())
                        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
                }
                .accessibilityLabel("Add")
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 2)
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }
}

/// Astra's accessory: a labelled "+ Add" bar above the tabs (Today and Progress only).
struct BlendAddBar: View {
    var action: () -> Void
    @Environment(\.look) private var look
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus").font(.system(.subheadline, weight: .bold))
                Text("Add").font(.system(.headline, weight: .semibold))
                Spacer()
                Text("Food · Scan · Weight · Workout").font(.system(.footnote, weight: .medium)).foregroundStyle(look.onAction.opacity(0.7))
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(look.onAction)
            .padding(.horizontal, 18).frame(minHeight: 50)
            .background(look.action, in: Capsule())
        }
        .buttonStyle(.lookPressable)
        .padding(.horizontal, 18)
        .padding(.bottom, 8)
    }
}

/// Fable's quick add: four ink slabs (the rest slab's material) rising from the +.
struct BlendInkAddMenu: View {
    @Binding var shown: Bool
    var choose: (String) -> Void
    @Environment(\.look) private var look
    @State private var appeared = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Rectangle().fill(look.ground.opacity(0.72)).background(.ultraThinMaterial).ignoresSafeArea()
                .onTapGesture { close() }.accessibilityHidden(true)
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    slab("Log food", "fork.knife", "logFood")
                    slab("Scan food", "camera.viewfinder", "scanFood")
                }
                HStack(spacing: 10) {
                    slab("Log weight", "scalemass", "logWeight")
                    slab("Start lifting", "figure.strengthtraining.traditional", "train")
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 92)
            .offset(y: appeared ? 0 : 24)
            .opacity(appeared ? 1 : 0)
            Button(action: close) {
                Image(systemName: "xmark").font(.system(size: 22, weight: .semibold)).foregroundStyle(look.onAction)
                    .frame(width: 62, height: 62).background(look.action, in: Circle())
            }
            .padding(.trailing, 18).padding(.bottom, 3)
            .accessibilityLabel("Close")
        }
        .onAppear { withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) { appeared = true } }
    }

    private func slab(_ title: String, _ symbol: String, _ key: String) -> some View {
        Button { shown = false; choose(key) } label: {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: symbol).font(.system(size: 24, weight: .semibold))
                Text(title).font(.system(.headline, weight: .heavy).width(.expanded))
            }
            .foregroundStyle(Color(hex: 0xF4F6F8))
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .bottomLeading)
            .background(look.isDark ? Color(hex: 0x1F1F23) : Color(hex: 0x0E0E10), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay { if look.isDark { RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.1)) } }
            .contentShape(Rectangle())
        }
        .buttonStyle(.lookPressable)
    }

    private func close() { withAnimation(.easeOut(duration: 0.18)) { shown = false } }
}

/// Astra's list: four full-width rows in a sheet.
struct BlendAddList: View {
    var choose: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.look) private var look

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add").font(look.font.title).foregroundStyle(look.textPrimary).padding(.top, 24)
            VStack(spacing: 0) {
                row("Log food", "fork.knife", "logFood")
                LookDivider().padding(.leading, 54)
                row("Scan food", "camera.viewfinder", "scanFood")
                LookDivider().padding(.leading, 54)
                row("Log weight", "scalemass", "logWeight")
                LookDivider().padding(.leading, 54)
                row("Start workout", "figure.strengthtraining.traditional", "train")
            }
            .lookSurface(.panel)
            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(look.ground)
    }

    private func row(_ title: String, _ symbol: String, _ key: String) -> some View {
        Button { dismiss(); choose(key) } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol).font(.system(.body, weight: .semibold)).frame(width: 24)
                Text(title).font(.system(.body, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right").font(.system(.footnote, weight: .bold)).foregroundStyle(look.textTertiary)
            }
            .foregroundStyle(look.textPrimary)
            .padding(.horizontal, 16).frame(minHeight: 58).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Train's Library section (Food-tab variant): Gyms and Exercises live here, History too.
struct BlendTrainLibrary: View {
    @Environment(\.look) private var look

    var body: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Library", level: .page)
            VStack(spacing: 0) {
                row("History", "clock.arrow.circlepath") { HistoryScreen() }
                LookDivider().padding(.leading, 54)
                row("Exercises", "list.bullet.rectangle") { ExercisesScreen() }
                LookDivider().padding(.leading, 54)
                row("Gyms", "building.2") { GymsScreen() }
            }
            .lookSurface(.panel)
        }
    }

    private func row<D: View>(_ title: String, _ symbol: String, @ViewBuilder destination: @escaping () -> D) -> some View {
        NavigationLink { destination() } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol).frame(width: 24).foregroundStyle(look.textPrimary)
                Text(title).font(.system(.body, weight: .semibold)).foregroundStyle(look.textPrimary)
                Spacer()
                Image(systemName: "chevron.right").font(.system(.footnote, weight: .bold)).foregroundStyle(look.textTertiary)
            }
            .padding(.horizontal, 16).frame(minHeight: 56).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
