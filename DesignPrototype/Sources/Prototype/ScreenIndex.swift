import SwiftUI

// PROTOTYPE CHROME — jump to any screen or state of the redesign with fresh sample data.
// Deliberately plain system styling so it never reads as part of the design.

struct ScreenIndex: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(LookModel.self) private var lookModel
    @Environment(\.dismiss) private var dismiss
    @Binding var showGallery: Bool

    /// Extra states reachable through a variant of a screen.
    private static let variants: [ScreenID: [(String, String)]] = [
        .l04: [("degraded", "No heart-rate reading")],
        .c04: [("gpsLost", "GPS lost")],
        .s03: [("failure", "Identification failed")],
        .g07: [("empty", "Nothing deleted (Gangnam Fitness)")],
        .x03: [("failure", "Export failed")],
        .l07: [("empty", "No machines yet")],
    ]

    var body: some View {
        @Bindable var lookModel = lookModel
        NavigationStack {
            List {
                Section("Look") {
                    Picker("Look", selection: $lookModel.id) {
                        ForEach(LookID.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    Picker("Appearance (★ look)", selection: $lookModel.appearance) {
                        ForEach(Appearance.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    Toggle("Large text (AccessibilityL)", isOn: Binding(
                        get: { router.dynamicTypeOverride != nil },
                        set: { router.dynamicTypeOverride = $0 ? .accessibility1 : nil }))
                    Button("Component gallery") {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showGallery = true }
                    }
                }
                ForEach(ScreenID.rows, id: \.row) { row in
                    Section(row.name) {
                        ForEach(row.screens) { screen in
                            entry(screen, variant: nil, subtitle: screen.note)
                            ForEach(Self.variants[screen] ?? [], id: \.0) { variant in
                                entry(screen, variant: variant.0, subtitle: variant.1)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Screens")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
    }

    private func entry(_ screen: ScreenID, variant: String?, subtitle: String) -> some View {
        Button {
            dismiss()
            Launch.open(screen, variant: variant, store: store, router: router)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(screen.rawValue)
                    .font(.system(.footnote, design: .monospaced).weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(variant == nil ? screen.title : "\(screen.title) · variant")
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
    }
}
