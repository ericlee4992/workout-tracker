import Foundation

/// A row the app upserts itself. CloudKit compatibility forbids
/// `@Attribute(.unique)` (T2), so "one row per key" is an app-side rule and
/// duplicates are always possible — after a sync, a crash mid-save, or two
/// devices writing at once.
///
/// The tie-break is deliberately total: latest `updatedAt`, ties broken by
/// `id`. `updatedAt` alone leaves same-instant duplicates resolving
/// arbitrarily, which would let preferences, gym memory, and rest overrides
/// disagree between one read and the next.
protocol CanonicalRow {
    var id: UUID { get }
    var updatedAt: Date { get }
}

extension Sequence where Element: CanonicalRow {
    /// The one row of this key that counts. nil when the sequence is empty.
    var canonical: Element? {
        self.max { ($0.updatedAt, $0.id.uuidString) < ($1.updatedAt, $1.id.uuidString) }
    }
}

extension AppPreferences: CanonicalRow {}
extension GymExerciseMemory: CanonicalRow {}
extension ExerciseRestOverride: CanonicalRow {}
