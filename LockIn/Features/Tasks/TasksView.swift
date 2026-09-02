import SwiftUI
import SwiftData

struct TasksView: View {
    @Environment(\.modelContext) private var modelContext
    private var taskRepo: TaskRepository { TaskRepository(context: modelContext) }

    @Query(sort: [SortDescriptor(\TaskItem.priority, order: .reverse),
                  SortDescriptor(\TaskItem.createdAt)])
    private var tasks: [TaskItem]

    /// Incomplete tasks first, preserving the query's priority/createdAt order
    /// within each group. (Bool is not Comparable, so isCompleted cannot be a
    /// SortDescriptor key path.)
    private var orderedTasks: [TaskItem] {
        tasks.filter { !$0.isCompleted } + tasks.filter { $0.isCompleted }
    }

    @State private var newTitle = ""
    @State private var newPriority = 1

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            newTaskBar
            if tasks.isEmpty {
                ContentUnavailableView("tasks.empty", systemImage: "checklist")
            } else {
                List {
                    ForEach(orderedTasks) { task in
                        taskRow(task)
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding(Theme.Spacing.m)
    }

    private var newTaskBar: some View {
        HStack(spacing: Theme.Spacing.s) {
            TextField("tasks.add.placeholder", text: $newTitle)
                .onSubmit(addTask)
            Picker("", selection: $newPriority) {
                Text("tasks.priority.high").tag(2)
                Text("tasks.priority.medium").tag(1)
                Text("tasks.priority.low").tag(0)
            }
            .frame(width: 110)
            Button {
                addTask()
            } label: {
                Image(systemName: "plus.circle.fill")
            }
            .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func addTask() {
        let title = newTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        taskRepo.add(title: title, priority: newPriority)
        newTitle = ""
    }

    private func taskRow(_ task: TaskItem) -> some View {
        HStack(spacing: Theme.Spacing.s) {
            Button {
                taskRepo.toggleComplete(task)
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isCompleted ? Theme.accent(for: .tasks) : .secondary)
            }
            .buttonStyle(.plain)

            Circle()
                .fill(priorityColor(task.priority))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .strikethrough(task.isCompleted)
                if task.accumulatedSeconds > 0 {
                    Text(String(format: String(localized: "tasks.focused"), Int(task.accumulatedSeconds / 60)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let due = task.dueDate {
                Text(due, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                taskRepo.delete(task)
            } label: {
                Label("common.delete", systemImage: "trash")
            }
        }
    }

    private func priorityColor(_ priority: Int) -> Color {
        switch priority {
        case 2: Theme.accent(for: .focus)
        case 1: Theme.accent(for: .tasks)
        default: .secondary
        }
    }
}
