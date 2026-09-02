import SwiftUI

struct HabitsView: View {
    @EnvironmentObject private var app: AppModel
    @State private var newHabitName = ""
    /// Repositories have no @Published state; bump to force re-render after mutations.
    @State private var refreshTick = 0
    @FocusState private var newHabitFocused: Bool

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            newHabitBar
            if app.habitRepo.habits().isEmpty {
                EmptyStateView(icon: "flame", titleKey: "habits.empty",
                               tint: Theme.accent(for: .habits))
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

    private var canAdd: Bool {
        !newHabitName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var newHabitBar: some View {
        HStack(spacing: Theme.Spacing.s) {
            TextField("habits.add.placeholder", text: $newHabitName)
                .textFieldStyle(.plain)
                .font(Theme.Typography.body)
                .focused($newHabitFocused)
                .onSubmit(addHabit)

            Button {
                addHabit()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(
                        Circle().fill(canAdd
                                      ? AnyShapeStyle(Theme.accent(for: .habits))
                                      : AnyShapeStyle(Color.primary.opacity(0.15)))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canAdd)
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, 6)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.control)
                .strokeBorder(newHabitFocused
                              ? Theme.accent(for: .habits).opacity(0.45)
                              : Color.clear)
        }
        .animation(Theme.Motion.hover, value: newHabitFocused)
    }

    private func addHabit() {
        let name = newHabitName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        _ = app.habitRepo.add(name: name)
        newHabitName = ""
        newHabitFocused = true
        refreshTick += 1
    }
}

struct HabitCard: View {
    @EnvironmentObject private var app: AppModel
    let habit: Habit
    let onMutate: () -> Void
    @State private var today = Calendar.current.startOfDay(for: .now)
    @State private var showDeleteConfirm = false
    @State private var hovered = false

    var body: some View {
        Theme.Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                header
                heatmap
            }
        }
        .onHover { hovered = $0 }
        .animation(Theme.Motion.hover, value: hovered)
        .contextMenu {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("common.delete", systemImage: "trash")
            }
        }
        .confirmationDialog(
            Text("habit.delete.confirm.title"),
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "common.delete"), role: .destructive) {
                app.habitRepo.delete(habit)
                onMutate()
            }
            Button(String(localized: "common.cancel"), role: .cancel) {}
        } message: {
            Text("\(habit.name) — \(String(localized: "habit.delete.confirm.message"))")
        }
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: habit.iconSymbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.accent(for: .habits))
                .frame(width: 28, height: 28)
                .background(Theme.accent(for: .habits).opacity(0.14),
                            in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
            Text(habit.name)
                .font(Theme.Typography.headline)
                .foregroundStyle(.primary)
            Spacer()
            HStack(spacing: Theme.Spacing.xs) {
                weeklyProgressBadge
                streakBadge
                checkInButton
                deleteButton
            }
        }
    }

    private var deleteButton: some View {
        Button {
            showDeleteConfirm = true
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .opacity(hovered ? 1 : 0)
        }
        .buttonStyle(.plain)
        .help(String(localized: "common.delete"))
    }

    private var streakBadge: some View {
        let streak = app.habitRepo.streak(habitID: habit.id, today: today)
        let tint = streak > 0 ? Theme.accent(for: .focus) : Color.secondary
        return Label("\(streak)", systemImage: "flame.fill")
            .font(Theme.Typography.caption.bold())
            .monospacedDigit()
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12), in: Capsule())
    }

    /// Weekly completion: check-ins within the current calendar week, x/7
    private var weeklyProgressBadge: some View {
        let counts = app.habitRepo.logsByDay(habitID: habit.id, days: 7, today: today)
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let done = counts.filter { $0.key >= weekStart && $0.key <= today && $0.value > 0 }.count
        return Label("\(done)/\(habit.targetPerWeek)", systemImage: "calendar")
            .font(Theme.Typography.caption)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.06), in: Capsule())
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
        return LazyVGrid(columns: Array(repeating: GridItem(.fixed(11), spacing: 3), count: 16),
                         spacing: 3) {
            ForEach(days, id: \.self) { day in
                RoundedRectangle(cornerRadius: 3)
                    .fill(heatColor(counts[day] ?? 0))
                    .frame(width: 11, height: 11)
            }
        }
    }

    private func heatColor(_ count: Int) -> Color {
        guard count > 0 else { return Color.primary.opacity(0.06) }
        return Theme.accent(for: .habits).opacity(min(1, 0.35 + 0.3 * Double(count)))
    }
}
