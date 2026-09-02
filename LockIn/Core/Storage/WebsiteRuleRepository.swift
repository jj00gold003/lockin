import Foundation
import SwiftData

struct WebsiteRuleRepository {
    let context: ModelContext

    /// Adds a rule for the normalized domain; returns nil when the raw input
    /// cannot be normalized into a valid domain (caller shows feedback).
    @discardableResult
    func add(domain raw: String) -> WebsiteRule? {
        guard let domain = HostsContentBuilder.normalizeDomain(raw) else { return nil }
        let rule = WebsiteRule(domain: domain)
        context.insert(rule)
        SaveLogger.save(context)
        return rule
    }

    func delete(_ rule: WebsiteRule) {
        context.delete(rule)
        SaveLogger.save(context)
    }

    func all() -> [WebsiteRule] {
        (try? context.fetch(FetchDescriptor<WebsiteRule>())) ?? []
    }

    func setEnabled(_ rule: WebsiteRule, to enabled: Bool) {
        rule.isEnabled = enabled
        SaveLogger.save(context)
    }
}
