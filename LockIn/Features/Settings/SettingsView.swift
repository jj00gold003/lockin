import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var app: AppModel
    @Query private var rules: [BlockRule]
    @Query private var siteRules: [WebsiteRule]
    @Environment(\.modelContext) private var modelContext
    @State private var accessibilityGranted = AccessibilityGuard.isGranted()
    @State private var newDomain = ""
    @State private var showApplyError = false

    var body: some View {
        Form {
            Section {
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
                            Text("block.scope.always").tag("always")
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
            } header: {
                SectionHeader(titleKey: "settings.blacklist")
            }

            // Schedule editor: shown only for the selected rule when its
            // scope is "scheduled".
            if let selectedRule, selectedRule.scope == "scheduled" {
                Section {
                    scheduleEditor(for: selectedRule)
                } header: {
                    SectionHeader(titleKey: "settings.schedule.editor")
                }
            }

            Section {
                ForEach(siteRules.sorted { $0.domain < $1.domain }) { site in
                    HStack {
                        Text(site.domain)
                        Spacer()
                        Toggle("", isOn: websiteEnabledBinding(site)).labelsHidden()
                        Button(role: .destructive) {
                            app.websiteRepo.delete(site)
                            app.refreshHostsSync()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                HStack {
                    TextField("settings.websites.add.placeholder", text: $newDomain)
                        .onSubmit { addWebsite() }
                    Button("settings.websites.add") { addWebsite() }
                        .disabled(HostsContentBuilder.normalizeDomain(newDomain) == nil)
                }
                HStack {
                    Circle()
                        .fill(app.hostsInSync ? .green : .orange)
                        .frame(width: 10, height: 10)
                    Text(app.hostsInSync ? "settings.websites.synced" : "settings.websites.outOfSync")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("settings.websites.apply") {
                        if !app.applyHosts() {
                            showApplyError = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                                showApplyError = false
                            }
                        }
                    }
                }
                if showApplyError {
                    Text("settings.websites.admin.error")
                        .foregroundStyle(.red)
                }
                Text("settings.websites.secureDNS.note")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                SectionHeader(titleKey: "settings.websites.title")
            }

            Section {
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
            } header: {
                SectionHeader(titleKey: "settings.accessibility.title")
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 460)
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            accessibilityGranted = AccessibilityGuard.isGranted()
        }
    }

    // MARK: - Row selection (delete)

    // The table keeps Set<UUID> selection for multi-select delete; the
    // schedule editor edits the first selected rule (deterministic order).
    @State private var selectedRuleIDs = Set<UUID>()

    private var selectedRule: BlockRule? {
        rules.first { selectedRuleIDs.contains($0.id) }
    }

    // MARK: - Schedule editor (scope == "scheduled")

    // Calendar weekday semantics: 1 = Sunday ... 7 = Saturday.
    private let scheduleRows: [(key: String, weekday: Int)] = [
        ("settings.schedule.mon", 2),
        ("settings.schedule.tue", 3),
        ("settings.schedule.wed", 4),
        ("settings.schedule.thu", 5),
        ("settings.schedule.fri", 6),
        ("settings.schedule.sat", 7),
        ("settings.schedule.sun", 1),
    ]

    private static let defaultStartMinute = 9 * 60
    private static let defaultEndMinute = 18 * 60

    private func scheduleEditor(for rule: BlockRule) -> some View {
        ForEach(scheduleRows, id: \.weekday) { row in
            HStack {
                Toggle(isOn: dayEnabledBinding(rule, weekday: row.weekday)) {
                    Text(String(localized: String.LocalizationValue(row.key)))
                }
                Spacer()
                if windows(of: rule).contains(where: { $0.weekday == row.weekday }) {
                    Text("settings.schedule.start")
                        .foregroundStyle(.secondary)
                    DatePicker("", selection: timeBinding(rule, weekday: row.weekday, isStart: true),
                               displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .fixedSize()
                    Text("settings.schedule.end")
                        .foregroundStyle(.secondary)
                    DatePicker("", selection: timeBinding(rule, weekday: row.weekday, isStart: false),
                               displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .fixedSize()
                }
            }
        }
    }

    private func windows(of rule: BlockRule) -> [ScheduleWindow] {
        (try? JSONDecoder().decode([ScheduleWindow].self,
                                   from: Data(rule.scheduleJSON.utf8))) ?? []
    }

    /// Re-encodes the windows (sorted) into `rule.scheduleJSON` and persists.
    private func setWindows(_ rule: BlockRule, _ windows: [ScheduleWindow]) {
        let sorted = windows.sorted {
            ($0.weekday, $0.startMinute) < ($1.weekday, $1.startMinute)
        }
        guard let data = try? JSONEncoder().encode(sorted),
              let json = String(data: data, encoding: .utf8) else { return }
        app.ruleRepo.setScheduleJSON(rule, to: json)
    }

    /// Toggling a day on adds a default window; off removes that weekday's
    /// window entirely (editing replaces the weekday's window).
    private func dayEnabledBinding(_ rule: BlockRule, weekday: Int) -> Binding<Bool> {
        Binding<Bool>(
            get: { windows(of: rule).contains { $0.weekday == weekday } },
            set: { on in
                var ws = windows(of: rule)
                if on {
                    ws.append(ScheduleWindow(weekday: weekday,
                                             startMinute: Self.defaultStartMinute,
                                             endMinute: Self.defaultEndMinute))
                } else {
                    ws.removeAll { $0.weekday == weekday }
                }
                setWindows(rule, ws)
            }
        )
    }

    /// Hour/minute picker bound to a window's start or end minute. Clamps so
    /// start stays before the (exclusive) end.
    private func timeBinding(_ rule: BlockRule, weekday: Int, isStart: Bool) -> Binding<Date> {
        Binding<Date>(
            get: {
                let window = windows(of: rule).first { $0.weekday == weekday }
                let minutes = window.map { isStart ? $0.startMinute : $0.endMinute }
                    ?? (isStart ? Self.defaultStartMinute : Self.defaultEndMinute)
                return Calendar.current.date(bySettingHour: minutes / 60,
                                             minute: minutes % 60, second: 0, of: .now) ?? .now
            },
            set: { date in
                var ws = windows(of: rule)
                guard let idx = ws.firstIndex(where: { $0.weekday == weekday }) else { return }
                let minutes = Calendar.current.component(.hour, from: date) * 60
                    + Calendar.current.component(.minute, from: date)
                if isStart {
                    ws[idx].startMinute = min(minutes, ws[idx].endMinute - 1)
                } else {
                    ws[idx].endMinute = max(minutes, ws[idx].startMinute + 1)
                }
                setWindows(rule, ws)
            }
        )
    }

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

    // MARK: - Blocked websites (/etc/hosts)

    private func addWebsite() {
        guard HostsContentBuilder.normalizeDomain(newDomain) != nil else { return }
        _ = app.websiteRepo.add(domain: newDomain)
        newDomain = ""
        app.refreshHostsSync()
    }

    private func websiteEnabledBinding(_ site: WebsiteRule) -> Binding<Bool> {
        Binding(
            get: { site.isEnabled },
            set: {
                app.websiteRepo.setEnabled(site, to: $0)
                app.refreshHostsSync()
            }
        )
    }
}
