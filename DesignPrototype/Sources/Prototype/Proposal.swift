import SwiftUI
import UIKit

// PROTOTYPE CHROME — the 2026-11 "evolve the look" proposal (impeccable critique of 2026-11-06).
// The screens in this prototype draw the PROPOSED design. "Now" shows a real screenshot of the
// shipped app (build 9 code, sample data, 2026-11-06) for the screen you are on, so the
// comparison is against the real app, not this prototype's older September screens.

@MainActor @Observable
final class Proposal {
    static let shared = Proposal()

    /// Show the real app's screenshot for the current screen instead of the proposal.
    var showNow = false
    /// Live workout: Finish in the bottom bar (proposed) or at the top right (today).
    var finishAtBottom = true
    /// Which real screenshot "Now" shows: workout, template, live, cardio, finish, history.
    var currentKey = "workout"

    private init() { showNow = UserDefaults.standard.bool(forKey: "now") }

    /// Screens that have a "Now" capture.
    static let keys: Set<String> = ["workout", "template", "live", "cardio", "finish", "history"]

    func nowImage(dark: Bool, large: Bool) -> UIImage? {
        guard Proposal.keys.contains(currentKey) else { return nil }
        let variant = large ? "dark-axl" : (dark ? "dark" : "light")
        for name in ["now-\(currentKey)-\(variant)", "now-\(currentKey)-\(dark ? "dark" : "light")"] {
            if let url = Bundle.main.url(forResource: name, withExtension: "png"),
               let image = UIImage(contentsOfFile: url.path) { return image }
        }
        return nil
    }
}

extension View {
    /// Marks the screen the "Now" switch should show a capture for.
    func proposalScreen(_ key: String) -> some View {
        onAppear { Proposal.shared.currentKey = key }
    }
}

/// The real app's capture, full screen, under the switcher pill. Taps on it do nothing.
struct NowCaptureLayer: View {
    var dark: Bool
    var large: Bool
    @State private var proposal = Proposal.shared

    var body: some View {
        if proposal.showNow {
            ZStack(alignment: .bottom) {
                Color.black.ignoresSafeArea()
                if let image = proposal.nowImage(dark: dark, large: large) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text("No capture of today's app for this screen.\nSwitch back to New.")
                        .font(.system(.body, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                Text("NOW · the shipped app (screenshot)")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.yellow, in: Capsule())
                    .foregroundStyle(.black)
                    .padding(.bottom, 26)
            }
            .contentShape(Rectangle())
            .ignoresSafeArea()
            .transition(.opacity)
        }
    }
}

// MARK: - Shared proposed pieces

/// "Add something" rows: a plain surface row with a + disc. Dashed outlines are kept for
/// unlogged values in the live workout only.
struct ProposedMakeRow: View {
    var title: String
    var symbol: String
    var action: () -> Void
    @Environment(\.look) private var look

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                IconDisc(symbol: symbol, size: 32, context: .onSurface)
                Text(title)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(look.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.lookPressable)
        .lookSurface(.card)
    }
}
