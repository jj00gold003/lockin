import Foundation

public struct ScheduleWindow: Codable, Equatable, Sendable {
    /// Calendar.weekday semantics: 1 = Sunday ... 7 = Saturday
    public var weekday: Int
    /// Minute of day when the window starts (inclusive)
    public var startMinute: Int
    /// Minute of day when the window ends (exclusive)
    public var endMinute: Int

    public init(weekday: Int, startMinute: Int, endMinute: Int) {
        self.weekday = weekday; self.startMinute = startMinute; self.endMinute = endMinute
    }
}

public enum BlockLevel: String, Codable, CaseIterable, Sendable {
    case soft, hard
}

public enum BlockScope: String, Codable, CaseIterable, Sendable {
    case sessionOnly, scheduled
}

public struct RuleSnapshot: Equatable, Sendable {
    public var id: UUID
    public var bundleID: String
    public var level: BlockLevel
    public var scope: BlockScope
    public var windows: [ScheduleWindow]
    public var isEnabled: Bool

    public init(id: UUID, bundleID: String, level: BlockLevel, scope: BlockScope,
                windows: [ScheduleWindow], isEnabled: Bool) {
        self.id = id; self.bundleID = bundleID; self.level = level
        self.scope = scope; self.windows = windows; self.isEnabled = isEnabled
    }
}

public struct BlockDecision: Equatable, Sendable {
    public enum Action: Equatable, Sendable { case allow, soft, hard }
    public var action: Action
    public var ruleID: UUID?
    public static let allow = BlockDecision(action: .allow, ruleID: nil)

    public init(action: Action, ruleID: UUID?) {
        self.action = action
        self.ruleID = ruleID
    }
}

/// Pure-function evaluator: given rule snapshots and the current environment,
/// decides allow / soft / hard.
public struct BlockRuleEvaluator: Sendable {
    public init() {}

    public func evaluate(rules: [RuleSnapshot], frontmostBundleID: String,
                         isSessionActive: Bool, date: Date,
                         calendar: Calendar = .current) -> BlockDecision {
        let weekday = calendar.component(.weekday, from: date)
        let minuteOfDay = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        var best = BlockDecision.allow

        for rule in rules where rule.isEnabled && rule.bundleID == frontmostBundleID {
            let applies: Bool
            switch rule.scope {
            case .sessionOnly:
                applies = isSessionActive
            case .scheduled:
                applies = rule.windows.contains {
                    $0.weekday == weekday && minuteOfDay >= $0.startMinute && minuteOfDay < $0.endMinute
                }
            }
            guard applies else { continue }
            switch rule.level {
            case .hard:
                // Hard beats soft: return immediately on the first hard match.
                return BlockDecision(action: .hard, ruleID: rule.id)
            case .soft:
                best = BlockDecision(action: .soft, ruleID: rule.id)
            }
        }
        return best
    }
}
