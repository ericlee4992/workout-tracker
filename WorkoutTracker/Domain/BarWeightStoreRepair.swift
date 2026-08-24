import Foundation
import SwiftData

/// One-time, idempotent repair for the short-lived schema that stored a bar's
/// as-entered value but not its normalized kilograms. The column remains
/// optional so SwiftData/CloudKit can migrate it; this pass makes every actual
/// bar row satisfy the complete D25 storage triple immediately after open.
enum BarWeightStoreRepair {
    @discardableResult
    static func backfill(in context: ModelContext) throws -> Int {
        let candidates = try context.fetch(
            FetchDescriptor<SetRecord>(predicate: #Predicate {
                $0.barWeightValue != nil && $0.barNormalizedKg == nil
            }))
        var repaired = 0
        for set in candidates {
            guard let bar = set.resolvedBarWeight else {
                // Invalid old provenance cannot honestly remain in bar mode.
                set.barWeightValue = nil
                set.barNormalizedKg = nil
                repaired += 1
                continue
            }
            set.barNormalizedKg = bar.normalizedKg
            repaired += 1
        }
        if repaired > 0 { try context.save() }
        return repaired
    }
}
