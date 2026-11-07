import SwiftUI

// PROPOSAL (2026-11) — the accent that replaces violet. The user: "I don't really like the
// purple… keep it simple and elegant." Mono is the recommendation: the app already speaks in
// ink and flood, and the muscle families, heart rate and destruction keep their own hues, so a
// colourless action never competes with them. Sand is a quiet warm alternative; Violet is
// today's, for comparison.

enum ProposalAccent: String, CaseIterable {
    case mono, sand, violet

    var label: String {
        switch self {
        case .mono: "MONO"
        case .sand: "SAND"
        case .violet: "VIOLET"
        }
    }

    var next: ProposalAccent {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }

    /// (action, onAction) per scheme.
    func colors(dark: Bool) -> (action: Color, onAction: Color)? {
        switch (self, dark) {
        case (.mono, true): (Color(hex: 0xF4F6F8), Color(hex: 0x060708))
        case (.mono, false): (Color(hex: 0x0B0C0E), .white)
        case (.sand, true): (Color(hex: 0xE6D5BC), Color(hex: 0x16140F))
        case (.sand, false): (Color(hex: 0x6E5A3E), .white)
        case (.violet, _): nil
        }
    }

    /// The live instrument on the ink rest slab (always dark): the accent's light form.
    var onSlab: Color? {
        switch self {
        case .mono: Color(hex: 0xF4F6F8)
        case .sand: Color(hex: 0xE6D5BC)
        case .violet: nil
        }
    }
}

extension Look {
    var liveOnSlab: Color { liveOnSlabOverride ?? live }

    /// The look with the proposal's accent. `live`: the live workout's look (Paper structure),
    /// which also loses its hard offset shadow (the user: "make it plain 2d").
    func withAccent(_ accent: ProposalAccent, live isLiveLook: Bool) -> Look {
        var look = self
        if isLiveLook { look.shadowInk = .clear }
        guard let c = accent.colors(dark: isDark) else { return look }
        look.action = c.action
        look.onAction = c.onAction
        look.actionText = c.action
        look.live = c.action
        look.liveOnSlabOverride = accent.onSlab
        if isLiveLook {
            look.selection = c.action
            look.segmentFill = c.action
        }
        return look
    }
}
