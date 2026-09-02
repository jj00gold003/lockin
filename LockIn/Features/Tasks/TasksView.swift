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
    @State private var editingTask: TaskItem?
    @FocusState private var newTaskFocused: Bool

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            newTaskBar
            if tasks.isEmpty {
                ContentUnavailableView("tasks.empty", systemImage: "checklist")
            } else {
                List {
                    ForEach(orderedTasks) { task in
                        TaskRow(task: task,
                                onToggle: { taskRepo.toggleComplete(task) },
                                onEdit: { editingTask = task },
                                onDelete: { taskRepo.delete(task) })
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding(Theme.Spacing.m)
        .sheet(item: $editingTask) { task in
            TaskEditSheet(task: task)
        }
    }

    private var newTaskBar: some View {
        HStack(spacing: Theme.Spacing.s) {
            TextField("tasks.add.placeholder", text: $newTitle)
                .focused($newTaskFocused)
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

    /// Keep focus in the title field so several tasks can be entered back to back.
    private func addTask() {
        let title = newTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        taskRepo.add(title: title, priority: newPriority)
        newTitle = ""
        newTaskFocused = true
    }
}

// MARK: - Row

private struct TaskRow: View {
    let task: TaskItem
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var hovered = false

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isCompleted ? Theme.accent(for: .tasks) : .secondary)
            }
            .buttonStyle(.plain)

            Button(action: onEdit) {
                HStack(spacing: Theme.Spacing.s) {
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
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
                    .opacity(hovered ? 1 : 0)
            }
            .buttonStyle(.plain)
        }
        .onHover { hovered = $0 }
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
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

// MARK: - Edit sheet

struct TaskEditSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let task: TaskItem

    @State private var title = ""
    @State private var notes = ""
    @State private var priority = 1
    @State private var hasDue = false
    @State private var dueDate = Calendar.current.startOfDay(for: .now)
    @State private var estimated = 0

    var body: some View {
        Form {
            Section("task.edit") {
                TextField("", text: $title)
                VStack(alignment: .leading, spacing: 4) {
                    Text("task.notes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.3))
                        )
                }
                Picker("", selection: $priority) {
                    Text("tasks.priority.high").tag(2)
                    Text("tasks.priority.medium").tag(1)
                    Text("tasks.priority.low").tag(0)
                }
            }

            Section("task.due") {
                Toggle("task.due.has", isOn: $hasDue)
                if hasDue {
                    DatePicker("task.due", selection: $dueDate,
                               displayedComponents: .date)
                }
            }

            Section("task.estimated") {
                Stepper(value: $estimated, in: 0...99) {
                    HStack {
                        Text("task.estimated")
                        Spacer()
                        Text("\(estimated)")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                HStack {
                    Spacer()
                    Button("common.cancel", role: .cancel) { dismiss() }
                    Button("task.save", action: save)
                        .keyboardShortcut(.defaultAction)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 480)
        .onAppear(perform: populate)
    }

    private func populate() {
        title = task.title
        notes = task.notes
        priority = task.priority
        hasDue = task.dueDate != nil
        dueDate = task.dueDate ?? Calendar.current.startOfDay(for: .now)
        estimated = task.estimatedPomodoros
    }

    private func save() {
        task.title = title.trimmingCharacters(in: .whitespaces)
        task.notes = notes
        task.priority = priority
        task.dueDate = hasDue ? dueDate : nil
        task.estimatedPomodoros = estimated
        SaveLogger.save(modelContext)
        dismiss()
    }
}
