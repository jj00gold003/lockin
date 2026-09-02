import Foundation
import AppKit
import Combine

struct BlockEvent: Codable {
    var timestamp: Date
    var bundleID: String
    var seconds: TimeInterval
}

/// Block audit log: JSONL append-only writes (spec 4.3); read side loads all.
enum BlockLogStore {
    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LockIn", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("blocks.jsonl")
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let newline = Data("\n".utf8)

    static func append(bundleID: String, seconds: TimeInterval, at: Date = .now) {
        let event = BlockEvent(timestamp: at, bundleID: bundleID, seconds: seconds)
        guard let data = try? encoder.encode(event) else { return }
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            _ = try? handle.seekToEnd()
            _ = try? handle.write(data + newline)
            try? handle.close()
        } else {
            try? (data + newline).write(to: fileURL)
        }
    }

    static func readAll() -> [BlockEvent] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return data.split(separator: UInt8(ascii: "\n")).compactMap {
            try? decoder.decode(BlockEvent.self, from: Data($0))
        }
    }
}

@MainActor
final class BlockerController: ObservableObject {
    @Published private(set) var activeBlock: BlockDecision?

    private let evaluator = BlockRuleEvaluator()
    private var monitor: FrontmostAppMonitor?
    private var rulesProvider: () -> [RuleSnapshot] = { [] }
    private var sessionActive: () -> Bool = { false }
    private var reevaluateTimer: Timer?
    private var blockedSince: [String: Date] = [:] // bundleID -> first block moment
    private var cancellables: Set<AnyCancellable> = []

    func start(monitor: FrontmostAppMonitor,
               rulesProvider: @escaping () -> [RuleSnapshot],
               sessionActive: @escaping () -> Bool) {
        reevaluateTimer?.invalidate()
        reevaluateTimer = nil
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        self.monitor = monitor
        self.rulesProvider = rulesProvider
        self.sessionActive = sessionActive
        monitor.$frontmostBundleID
            .sink { [weak self] _ in self?.reevaluate() }
            .store(in: &cancellables)
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.reevaluate() }
        }
        RunLoop.main.add(timer, forMode: .common)
        reevaluateTimer = timer
    }

    func reevaluate() {
        guard let monitor else { return }
        let bundleID = monitor.frontmostBundleID ?? ""
        let decision = evaluator.evaluate(
            rules: rulesProvider(),
            frontmostBundleID: bundleID,
            isSessionActive: sessionActive(),
            date: .now
        )
        if decision.action == .allow {
            if let since = blockedSince.removeValue(forKey: bundleID) {
                BlockLogStore.append(bundleID: bundleID, seconds: Date.now.timeIntervalSince(since))
            }
            activeBlock = nil
        } else {
            if blockedSince[bundleID] == nil { blockedSince[bundleID] = .now }
            activeBlock = decision
        }
    }
}
