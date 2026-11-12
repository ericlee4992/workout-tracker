import Foundation

/// Nutrition N14 (D85): the goal setup's `Generator` for this session — the server signed in (no prompt: the user,
/// 2026-11-12), nil signed out so the calculation stands in. Any failure (offline, the limit, paused, an implausible
/// reply) answers nil: the calculation again.
@MainActor
enum GoalPlanService {
    static func generator(_ account: AccountStore) -> GoalSetupDraft.Generator? {
        guard TerraAccess.ready(account) else { return nil }
        if TerraAccess.fixture {
            return { _, _ in
                do { try await TerraAccess.fixtureDelay() } catch { return nil }
                return GoalPlanAI.parse(GoalPlanAI.fixtureReply)
            }
        }
        guard let client = TerraAccess.client(account) else { return nil }
        return { inputs, desiredKg in
            guard let data = try? await client.complete(.nutritionGoals, json: GoalPlanAI.body(inputs, desiredKg: desiredKg))
            else { return nil }
            return GoalPlanAI.parse(data)
        }
    }
}
