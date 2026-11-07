import SwiftUI
import Testing
import UIKit
@testable import WorkoutTracker

// Soft redesign S1 (D67): the Soft tokens keep text readable on every surface it sits on —
// WCAG 2.x contrast ≥ 4.5:1 for body text tiers, ≥ 3:1 for the Mono action against its
// surroundings. The prototype's lighter greys (#8A8A90 / #7C7C82) failed this and were deepened;
// this pins the result so a later token edit cannot quietly undo it.

private func luminance(_ color: Color) -> Double {
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
    func lin(_ c: CGFloat) -> Double {
        let c = Double(c)
        return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
}

private func contrast(_ a: Color, _ b: Color) -> Double {
    let la = luminance(a), lb = luminance(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
}

struct SoftLookContrastTests {
    @Test(arguments: [Look.softLight, Look.softDark])
    func textTiersReadOnEverySurface(look: Look) {
        let grounds = [look.ground, look.surface, look.surfaceRaised]
        for ground in grounds {
            #expect(contrast(look.textPrimary, ground) >= 4.5)
            #expect(contrast(look.textSecondary, ground) >= 4.5)
            #expect(contrast(look.textTertiary, ground) >= 4.5)
        }
    }

    @Test(arguments: [Look.softLight, Look.softDark])
    func monoActionReads(look: Look) {
        #expect(contrast(look.onAction, look.action) >= 4.5)
        #expect(contrast(look.action, look.surface) >= 3)
        #expect(contrast(look.action, look.ground) >= 3)
    }

    @Test(arguments: [true, false])
    func liveWorkoutSlabShowsTheLiveRing(dark: Bool) {
        let live = Look.live(dark: dark)
        // The ink rest slab: the live ring and Skip use `liveOnSlab`, never the ink action.
        #expect(contrast(live.liveOnSlab, live.slab) >= 3)
        #expect(contrast(live.onSlab, live.slab) >= 4.5)
        // Flat buttons: no hard offset shadow (the user: "make it plain 2d").
        #expect(UIColor(live.shadowInk).cgColor.alpha == 0)
    }

    @Test func softUsesNoExpandedOrVioletTokens() {
        for look in [Look.softLight, Look.softDark, Look.live(dark: true), Look.live(dark: false)] {
            for color in [look.action, look.actionText, look.live, look.selection] {
                // Violet #B25CFF / #7A2EE0 had blue well above red and green; Mono is grey.
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
                #expect(abs(r - g) < 0.02 && abs(g - b) < 0.03)
            }
        }
    }
}
