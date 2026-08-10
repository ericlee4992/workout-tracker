import Foundation
import SwiftData

// Ticket 17 D1 — the remembered gym on the Start screen. The gym is what the
// whole equipment-aware model hangs off (machines, memory, prefill layers),
// so re-picking it every launch was a tax on the differentiator. It is stored
// as a scalar id on AppPreferences and resolved through here.

enum GymSelection {

    /// The gym a stored selection resolves to, or nil for "No gym".
    ///
    /// A missing or archived gym degrades to "No gym" rather than being
    /// resurrected: archival is how a gym leaves the pickers (ticket 10), and
    /// a remembered id must not be a back door around that.
    static func resolve(id: UUID?, among gyms: [Gym]) -> Gym? {
        guard let id else { return nil }
        return gyms.first { $0.id == id && !$0.archived }
    }

    /// Persists the pick (nil = "No gym") on the canonical preferences row.
    static func remember(_ gym: Gym?, in context: ModelContext, at date: Date = .now) throws {
        let preferences = try AppPreferences.canonical(in: context)
        if preferences.selectedGymID != gym?.id {
            preferences.selectedGymID = gym?.id
            preferences.updatedAt = date
        }
        // `canonical` may have inserted the first-ever row, so save on any
        // pending change — not only on a changed selection.
        if context.hasChanges {
            try context.save()
        }
    }
}
