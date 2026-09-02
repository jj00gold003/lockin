import Foundation
import SwiftData
import os

/// Unified save logging for repositories; prevents silent data loss
enum SaveLogger {
    private static let logger = Logger(subsystem: "com.lockin.app", category: "storage")

    static func save(_ context: ModelContext, file: String = #fileID, line: Int = #line) {
        do {
            try context.save()
        } catch {
            logger.error("SwiftData save failed at \(file, privacy: .public):\(line): \(error)")
        }
    }
}
