import Foundation
import SwiftData

// Machine settings 01 (D91): "My settings" — the user's own setup note for one gym machine × one exercise ("Seat 4 ·
// chest pad 3 · hurt my elbow at 4").
//
// Current, not history: the note is never copied into the D23 snapshot, never shown in History, never sent to AI and
// never put on the Lock Screen. It is owned by the machine (cascade, AGENTS.md's delete rules) and keyed by a scalar
// exercise id, like `GymExerciseMemory`. CloudKit forbids `@Attribute(.unique)`, so "one note per machine × exercise" is
// an app-side rule: duplicates can exist after a sync, and the canonical row (latest `updatedAt`, then `id`) is the
// one that counts. A blank canonical row means "no note" — clearing a note blanks the row instead of deleting it, so a
// failed save can be undone exactly, and an older duplicate can never resurface behind a cleared one.

@Model
final class MachineSettingsNote {
    var id: UUID = UUID()
    /// The exercise this note is for, as a scalar id: the note is about using this machine for that movement.
    var exerciseID: UUID = UUID()
    /// As typed, trimmed. Empty means no note.
    var text: String = ""
    var updatedAt: Date = Date()
    var machine: MachineInstance?

    init(id: UUID = UUID(), exerciseID: UUID, text: String, updatedAt: Date = Date(), machine: MachineInstance? = nil) {
        self.id = id
        self.exerciseID = exerciseID
        self.text = text
        self.updatedAt = updatedAt
        self.machine = machine
    }
}

extension MachineSettingsNote: CanonicalRow {}

struct MachineSettings {
    let context: ModelContext

    /// The note for this machine and exercise, or nil when there is none (or it was cleared). Reads the machine's own
    /// rows, so a view showing it follows edits without a fetch.
    static func note(on machine: MachineInstance?, exerciseID: UUID?) -> String? {
        guard let machine, !machine.isDeleted, let exerciseID else { return nil }
        let text = (machine.settingsNotes ?? []).filter { !$0.isDeleted && $0.exerciseID == exerciseID }.canonical?.text
        guard let text, !text.isEmpty else { return nil }
        return text
    }

    /// Saves the note (trimmed; blank clears it). Updates the canonical row of this machine × exercise, or adds one.
    /// On a failed save the row is put back as it was and the error is rethrown, so nothing of the edit stays pending.
    func save(_ text: String, on machine: MachineInstance, exerciseID: UUID, at date: Date = .now,
              save: (ModelContext) throws -> Void = { try $0.save() }) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let existing = (machine.settingsNotes ?? []).filter { !$0.isDeleted && $0.exerciseID == exerciseID }.canonical
        if let existing {
            guard existing.text != trimmed else { return }
            let previous = (existing.text, existing.updatedAt)
            existing.text = trimmed
            // Never older than it was (codex-review-01 #1): with the clock set back, an earlier date would hand the
            // canonical place to an older duplicate, and a cleared note would resurface. The id tie-break already
            // favours this row, so an equal date keeps it canonical too.
            existing.updatedAt = max(previous.1, date)
            do { try save(context) } catch {
                existing.text = previous.0
                existing.updatedAt = previous.1
                throw error
            }
        } else {
            guard !trimmed.isEmpty else { return }
            let note = MachineSettingsNote(exerciseID: exerciseID, text: trimmed, updatedAt: date)
            context.insert(note)
            note.machine = machine
            do { try save(context) } catch {
                note.machine = nil
                context.delete(note)
                throw error
            }
        }
    }

    /// Whether a finished workout used this machine for this exercise (by the D23 snapshot, so a later rename or model
    /// correction does not change the answer). The first-use hint shows only when this is false — during the first
    /// workout on the machine, and never after it.
    func hasFinishedHistory(machineID: UUID, exerciseID: UUID) throws -> Bool {
        let machine: UUID? = machineID
        let entries = try context.fetch(FetchDescriptor<ExerciseEntry>(
            predicate: #Predicate { $0.snapshotMachineID == machine && $0.snapshotExerciseID == exerciseID }))
        return entries.contains { $0.workout?.finishedAt != nil }
    }
}
