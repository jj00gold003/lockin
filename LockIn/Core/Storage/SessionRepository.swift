import Foundation
import SwiftData

struct SessionRepository {
    let context: ModelContext

    @discardableResult
    func start(type: String, taskID: UUID?, at: Date = .now) -> FocusSession {
        let session = FocusSession(type: type, taskID: taskID, startedAt: at)
        context.insert(session)
        try? context.save()
        return session
    }

    func finish(id: UUID, status: String, interruptions: Int, blocks: Int = 0, at: Date = .now) {
        guard let session = find(id: id) else { return }
        session.status = status
        session.endedAt = at
        session.interruptionCount = interruptions
        session.blockCount = blocks
        try? context.save()
    }

    func incomplete() -> [FocusSession] {
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { $0.status == "running" }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Crash/force-quit recovery: settle a leftover running session
    func resolve(id: UUID, to status: String, endedAt: Date) {
        finish(id: id, status: status, interruptions: 0, at: endedAt)
    }

    func focusSeconds(since date: Date) -> TimeInterval {
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { $0.startedAt >= date && $0.status != "running" }
        )
        let sessions = (try? context.fetch(descriptor)) ?? []
        return sessions.reduce(0) { total, session in
            guard let end = session.endedAt else { return total }
            return total + max(0, end.timeIntervalSince(session.startedAt))
        }
    }

    /// Per-day focus seconds for the last N days (including today), returned in ascending day order
    func focusSecondsByDay(days: Int, calendar: Calendar = .current, now: Date = .now) -> [(day: Date, seconds: TimeInterval)] {
        let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -(days - 1), to: now)!)
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { $0.startedAt >= start && $0.status != "running" }
        )
        let sessions = (try? context.fetch(descriptor)) ?? []
        var buckets: [Date: TimeInterval] = [:]
        for session in sessions {
            guard let end = session.endedAt else { continue }
            var cursor = calendar.startOfDay(for: session.startedAt)
            while cursor <= end {
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: cursor)!
                let segStart = max(cursor, session.startedAt)
                let segEnd = min(dayEnd, end)
                if segEnd > segStart { buckets[cursor, default: 0] += segEnd.timeIntervalSince(segStart) }
                cursor = dayEnd
            }
        }
        return (0..<days).compactMap { offset in
            let day = calendar.startOfDay(for: calendar.date(byAdding: .day, value: offset - (days - 1), to: now)!)
            return (day, buckets[day] ?? 0)
        }
    }

    private func find(id: UUID) -> FocusSession? {
        var descriptor = FetchDescriptor<FocusSession>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
