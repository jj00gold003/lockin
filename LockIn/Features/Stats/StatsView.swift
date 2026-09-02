import SwiftUI
import Charts

struct StatsView: View {
    @EnvironmentObject private var app: AppModel
    @State private var refreshTick = 0

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.m) {
                summaryRow
                Theme.Card {
                    Chart(app.sessionRepo.focusSecondsByDay(days: 7), id: \.day) { point in
                        BarMark(
                            x: .value("stats.day", point.day, unit: .day),
                            y: .value("stats.minutes", point.seconds / 60)
                        )
                        .foregroundStyle(Theme.accent(for: .focus).gradient)
                        .cornerRadius(4)
                    }
                    .frame(height: 180)
                }
                Theme.Card {
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
            .padding(Theme.Spacing.m)
        }
        .id(refreshTick)
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            refreshTick += 1
        }
    }

    private var summaryRow: some View {
        HStack(spacing: Theme.Spacing.m) {
            statCard(value: format(app.sessionRepo.focusSeconds(since: Calendar.current.startOfDay(for: .now))),
                     labelKey: "stats.today")
            statCard(value: format(app.sessionRepo.focusSeconds(since: weekStart)),
                     labelKey: "stats.week")
        }
    }

    private var weekStart: Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
    }

    private var blockEvents: [(day: Date, count: Int)] {
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

    private func statCard(value: String, labelKey: String) -> some View {
        Theme.Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(value).font(.system(size: 28, weight: .bold, design: .rounded)).monospacedDigit()
                Text(String(localized: String.LocalizationValue(labelKey)))
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func format(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600, m = (Int(seconds) % 3600) / 60
        return h > 0 ? String(format: "%dh %02dm", h, m) : String(format: "%dm", m)
    }
}
