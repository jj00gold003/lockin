import Foundation
import SwiftData

struct BlockRuleRepository {
    let context: ModelContext

    @discardableResult
    func add(bundleID: String, appDisplayName: String, level: String = "soft",
             scope: String = "always", scheduleJSON: String = "[]") -> BlockRule {
        let rule = BlockRule(bundleID: bundleID, appDisplayName: appDisplayName,
                             level: level, scope: scope, scheduleJSON: scheduleJSON)
        context.insert(rule)
        SaveLogger.save(context)
        return rule
    }

    func delete(_ rule: BlockRule) {
        context.delete(rule)
        SaveLogger.save(context)
    }

    func all() -> [BlockRule] {
        (try? context.fetch(FetchDescriptor<BlockRule>())) ?? []
    }

    func setEnabled(_ rule: BlockRule, to enabled: Bool) {
        rule.isEnabled = enabled
        SaveLogger.save(context)
    }

    /// Replaces the rule's schedule windows (already JSON-encoded by the
    /// caller) and persists through SaveLogger.
    func setScheduleJSON(_ rule: BlockRule, to json: String) {
        rule.scheduleJSON = json
        SaveLogger.save(context)
    }
}
