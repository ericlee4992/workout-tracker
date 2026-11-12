import Foundation

/// Nutrition N14 (D85): the goal setup's `Generator` for this session — the server signed in (no prompt: the user,
/// 2026-11-12), nil signed out so the calculation stands in. Any failure (offline, the limit, paused, an implausible
/// reply) answers nil: the calculation again. Cancellation (the page left) throws, so it is not taken for a failure.
@MainActor
enum GoalPlanService {
    static func generator(_ account: AccountStore) -> GoalSetupDraft.Generator? {
        guard TerraAccess.ready(account) else { return nil }
        if TerraAccess.fixture {
            return { _, _ in
                do { try await TerraAccess.fixtureDelay() }
                catch is CancellationError { throw CancellationError() }
                catch { return nil }
                return GoalPlanAI.parse(GoalPlanAI.fixtureReply)
            }
        }
        guard let client = TerraAccess.client(account) else { return nil }
        return { inputs, desiredKg in
            do {
                let data = try await client.complete(.nutritionGoals, json: GoalPlanAI.body(inputs, desiredKg: desiredKg))
                try Task.checkCancellation()
                return GoalPlanAI.parse(data)
            } catch is CancellationError {
                throw CancellationError()  // the page was left: not a failure (codex-review-n14 R5)
            } catch {
                return nil
            }
        }
    }
}
