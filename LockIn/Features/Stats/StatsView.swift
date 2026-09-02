import SwiftUI
import Charts

struct StatsView: View {
    @EnvironmentObject private var app: AppModel

    // Data snapshots refreshed on a 30s timer. Assigning into @State updates
    // the views in place WITHOUT rebuilding view identity — the previous
    // `.id(refreshTick)` on the ScrollView reset the scroll position each tick.
    @State private var todaySeconds: TimeInterval = 0
    @State private var weekSeconds: TimeInterval = 0
    @State private var completionRate: Double?
    @State private var focusByDay: [(day: Date, seconds: TimeInterval)] = []
    @State private var blockEvents: [(day: Date, count: Int)] = []

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.m) {
                summaryRow
                focusChartCard
                blockChartCard
            }
            .padding(Theme.Spacing.m)
        }
        .onAppear(perform: refresh)
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            refresh()
        }
    }

    // MARK: - Snapshots

    /// Recomputes all displayed values and assigns them into @State.
    private func refresh() {
        todaySeconds = app.sessionRepo.focusSeconds(since: Calendar.current.startOfDay(for: .now))
        weekSeconds = app.sessionRepo.focusSeconds(since: weekStart)
        completionRate = app.sessionRepo.completionRate(days: 7)
        focusByDay = app.sessionRepo.focusSecondsByDay(days: 7)
        blockEvents = computeBlockEvents()
    }

    private func computeBlockEvents() -> [(day: Date, count: Int)] {
        let cal = Calendar.current
        let events = BlockLogStore.readAll()
        let grouped = Dictionary(grouping: events) { cal.startOfDay(for: $0.timestamp) }
        // (0..<7).compactMap{...}.reversed() yields ReversedCollection, not an Array;
        // wrap with Array(...) to satisfy the declared return type and Chart's key-path usage.
        return Array((0..<7).compactMap { offset in
            let day = cal.startOfDay(for: cal.date(byAdding: .day, value: -offset, to: .now)!)
            return (day, grouped[day]?.count ?? 0)
        }.reversed())
    }

    // MARK: - Pieces

    private var summaryRow: some View {
        HStack(spacing: Theme.Spacing.m) {
            StatTile(value: format(todaySeconds), labelKey: "stats.today",
                     icon: "timer", tint: Theme.accent(for: .focus))
            StatTile(value: format(weekSeconds), labelKey: "stats.week",
                     icon: "calendar", tint: Theme.accent(for: .tasks))
            StatTile(value: rateText, labelKey: "stats.completion",
                     icon: "checkmark.seal", tint: Theme.accent(for: .habits))
        }
    }

    private var focusChartCard: some View {
        Theme.Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                SectionHeader(titleKey: "stats.chart.focus")
                Chart(focusByDay, id: \.day) { point in
                    BarMark(
                        x: .value("stats.day", point.day, unit: .day),
                        y: .value("stats.minutes", point.seconds / 60)
                    )
                    .foregroundStyle(Theme.accent(for: .focus).gradient)
                    .cornerRadius(4)
                }
                .frame(height: 180)
            }
        }
    }

    private var blockChartCard: some View {
        Theme.Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                SectionHeader(titleKey: "stats.chart.blocked")
                Chart(blockEvents, id: \.day) { point in
                    LineMark(
                        x: .value("stats.day", point.day, unit: .day),
                        y: .value("stats.count", point.count)
                    )
                    .foregroundStyle(Theme.accent(for: .tasks))
                }
                .frame(height: 140)
            }
        }
    }

    private var rateText: String {
        guard let rate = completionRate else { return "–" }
        return String(format: "%.0f%%", rate * 100)
    }

    private var weekStart: Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
    }

    private func format(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600, m = (Int(seconds) % 3600) / 60
        return h > 0 ? String(format: "%dh %02dm", h, m) : String(format: "%dm", m)
    }
}
