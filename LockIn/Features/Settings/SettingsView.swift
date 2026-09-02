import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var app: AppModel
    @Query private var rules: [BlockRule]
    @Environment(\.modelContext) private var modelContext
    @State private var accessibilityGranted = AccessibilityGuard.isGranted()

    var body: some View {
        Form {
            Section("settings.blacklist") {
                Table(rules, selection: $selectedRuleIDs) {
                    TableColumn("settings.blacklist.app") { rule in
                        Text(rule.appDisplayName)
                    }
                    TableColumn("settings.blacklist.level") { rule in
                        Picker("", selection: levelBinding(rule)) {
                            Text("settings.blacklist.level.soft").tag("soft")
                            Text("settings.blacklist.level.hard").tag("hard")
                        }
                        .labelsHidden()
                    }
                    TableColumn("settings.blacklist.scope") { rule in
                        Picker("", selection: scopeBinding(rule)) {
                            Text("settings.blacklist.scope.session").tag("sessionOnly")
                            Text("settings.blacklist.scope.scheduled").tag("scheduled")
                        }
                        .labelsHidden()
                    }
                    TableColumn("settings.blacklist.enabled") { rule in
                        Toggle("", isOn: enabledBinding(rule)).labelsHidden()
                    }
                }
                .frame(minHeight: 200)
                HStack {
                    Button("settings.blacklist.add") { addApp() }
                    Spacer()
                    Button(role: .destructive) {
                        deleteSelected()
                    } label: {
                        Label("common.delete", systemImage: "trash")
                    }
                    .disabled(selectedRuleIDs.isEmpty)
                }
            }

            Section("settings.accessibility.title") {
                HStack {
                    Circle()
                        .fill(accessibilityGranted ? .green : .orange)
                        .frame(width: 10, height: 10)
                    Text("settings.accessibility.description")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if accessibilityGranted {
                        Text("settings.accessibility.granted")
                            .foregroundStyle(.green)
                    } else {
                        Button("settings.accessibility.grant") {
                            AccessibilityGuard.request()
                            AccessibilityGuard.openSystemSettings()
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 460)
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            accessibilityGranted = AccessibilityGuard.isGranted()
        }
    }

    // MARK: - Row selection (delete)

    @State private var selectedRuleIDs = Set<UUID>()

    private func deleteSelected() {
        for rule in rules where selectedRuleIDs.contains(rule.id) {
            app.ruleRepo.delete(rule)
        }
        selectedRuleIDs.removeAll()
    }

    // MARK: - Add app via NSOpenPanel

    private func addApp() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let bundle = Bundle(url: url),
              let bundleID = bundle.bundleIdentifier else { return }
        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String
            ?? url.deletingPathExtension().lastPathComponent
        _ = app.ruleRepo.add(bundleID: bundleID, appDisplayName: name)
    }

    // MARK: - Bindings (persist via modelContext)

    private func levelBinding(_ rule: BlockRule) -> Binding<String> {
        Binding(get: { rule.level }, set: { rule.level = $0; try? modelContext.save() })
    }
    private func scopeBinding(_ rule: BlockRule) -> Binding<String> {
        Binding(get: { rule.scope }, set: { rule.scope = $0; try? modelContext.save() })
    }
    private func enabledBinding(_ rule: BlockRule) -> Binding<Bool> {
        Binding(get: { rule.isEnabled }, set: { rule.isEnabled = $0; try? modelContext.save() })
    }
}
