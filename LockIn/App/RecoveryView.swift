import SwiftUI

/// Task 13 crash recovery: shown over the whole UI when an orphaned
/// "running" session survives a crash / force-quit.
struct RecoveryView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        if let session = app.pendingRecovery {
            ZStack {
                Color.black.opacity(0.35).ignoresSafeArea()
                Theme.Card {
                    VStack(spacing: Theme.Spacing.m) {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.accent(for: .focus))
                        Text("recovery.title")
                            .font(.headline)
                        Text(session.startedAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: Theme.Spacing.s) {
                            Button("recovery.continue") {
                                app.resolveRecovery(.continueWork)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.accent(for: .focus))
                            Button("recovery.end") {
                                app.resolveRecovery(.markCompleted)
                            }
                            Button("recovery.discard", role: .destructive) {
                                app.resolveRecovery(.discard)
                            }
                        }
                    }
                    .padding(Theme.Spacing.l)
                }
            }
        }
    }
}
