import Foundation
import SwiftData

struct BlockRuleRepository {
    let context: ModelContext

    @discardableResult
    func add(bundleID: String, appDisplayName: String, level: String = "soft",
             scope: String = "sessionOnly", scheduleJSON: String = "[]") -> BlockRule {
        let rule = BlockRule(bundleID: bundleID, appDisplayName: appDisplayName,
                             level: level, scope: scope, scheduleJSON: scheduleJSON)
        context.insert(rule)
        try? context.save()
        return rule
    }

    func delete(_ rule: BlockRule) {
        context.delete(rule)
        try? context.save()
    }

    func all() -> [BlockRule] {
        (try? context.fetch(FetchDescriptor<BlockRule>())) ?? []
    }

    func setEnabled(_ rule: BlockRule, to enabled: Bool) {
        rule.isEnabled = enabled
        try? context.save()
    }
}
