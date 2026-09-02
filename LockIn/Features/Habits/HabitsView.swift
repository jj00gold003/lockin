import SwiftUI

struct HabitsView: View {
    @EnvironmentObject private var app: AppModel
    @State private var newHabitName = ""
    /// Repositories have no @Published state; bump to force re-render after mutations.
    @State private var refreshTick = 0

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            newHabitBar
            if app.habitRepo.habits().isEmpty {
                ContentUnavailableView("habits.empty", systemImage: "flame")
            } else {
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.m) {
                        ForEach(app.habitRepo.habits(), id: \.id) { habit in
                            HabitCard(habit: habit) { refreshTick += 1 }
                        }
                    }
                }
                .id(refreshTick)
            }
        }
        .padding(Theme.Spacing.m)
    }

    private var newHabitBar: some View {
        HStack {
            TextField("habits.add.placeholder", text: $newHabitName)
                .onSubmit(addHabit)
            Button {
                addHabit()
            } label: {
                Image(systemName: "plus.circle.fill")
            }
            .disabled(newHabitName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func addHabit() {
        let name = newHabitName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        _ = app.habitRepo.add(name: name)
        newHabitName = ""
        refreshTick += 1
    }
}

struct HabitCard: View {
    @EnvironmentObject private var app: AppModel
    let habit: Habit
    let onMutate: () -> Void
    @State private var today = Calendar.current.startOfDay(for: .now)

    var body: some View {
        Theme.Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                HStack(spacing: Theme.Spacing.s) {
                    Image(systemName: habit.iconSymbol)
                        .foregroundStyle(Theme.accent(for: .habits))
                    Text(habit.name).font(.headline)
                    Spacer()
                    streakBadge
                    checkInButton
                }
                heatmap
            }
        }
    }

    private var streakBadge: some View {
        let streak = app.habitRepo.streak(habitID: habit.id, today: today)
        return Label("\(streak)", systemImage: "flame.fill")
            .font(.callout.bold())
            .foregroundStyle(streak > 0 ? Theme.accent(for: .focus) : .secondary)
    }

    private var isCheckedToday: Bool {
        app.habitRepo.isCheckedIn(habit: habit, day: today)
    }

    private var checkInButton: some View {
        Button {
            if isCheckedToday {
                app.habitRepo.uncheckIn(habit: habit, day: today)
            } else {
                app.habitRepo.checkIn(habit: habit, day: today)
            }
            onMutate()
        } label: {
            Image(systemName: isCheckedToday ? "checkmark.circle.fill" : "circle.dashed")
                .font(.title2)
        }
        .buttonStyle(.plain)
        .tint(Theme.accent(for: .habits))
    }

    /// GitHub-style 16-week heatmap (column = week, row = weekday). LazyVGrid fills
    /// row-major across 16 columns, so days are emitted week-per-row, weekday down
    /// the column: cell (row r, col w) is start + w*7 + r days.
    private var heatmap: some View {
        let counts = app.habitRepo.logsByDay(habitID: habit.id, days: 16 * 7, today: today)
        let cal = Calendar.current
        let today0 = cal.startOfDay(for: today)
        let start = cal.date(byAdding: .day, value: -(16 * 7 - 1), to: today0)!
        let days: [Date] = (0..<7).flatMap { row in
            (0..<16).compactMap { cal.date(byAdding: .day, value: $0 * 7 + row, to: start) }
        }
        return LazyVGrid(columns: Array(repeating: GridItem(.fixed(12), spacing: 3), count: 16),
                         spacing: 3) {
            ForEach(days, id: \.self) { day in
                RoundedRectangle(cornerRadius: 2)
                    .fill(heatColor(counts[day] ?? 0))
                    .frame(width: 12, height: 12)
            }
        }
    }

    private func heatColor(_ count: Int) -> Color {
        guard count > 0 else { return Theme.accent(for: .habits).opacity(0.12) }
        return Theme.accent(for: .habits).opacity(min(1, 0.35 + 0.3 * Double(count)))
    }
}
