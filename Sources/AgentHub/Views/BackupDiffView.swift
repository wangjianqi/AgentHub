import SwiftUI

struct BackupDiffView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedBackupID: BackupItem.ID?

    private var selectedBackup: BackupItem? {
        appState.backups.first { $0.id == selectedBackupID } ?? appState.backups.first
    }

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(L("backups.title"), subtitle: L("backups.subtitle"))
                    Spacer()
                    Button {
                        appState.reloadBackups()
                    } label: {
                        Label(L("button.refresh"), systemImage: "arrow.clockwise")
                    }
                }

                if appState.backups.isEmpty {
                    EmptyStateView(title: L("backups.empty.title"), message: L("backups.empty.message"), systemImage: "clock.arrow.circlepath")
                } else {
                    List(appState.backups, selection: $selectedBackupID) { backup in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(backup.originalPath)
                                .font(.headline)
                                .lineLimit(1)
                            Text(backup.createdAt.formatted(date: .abbreviated, time: .standard))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(backup.id)
                    }
                }
            }
            .padding(20)
            .frame(minWidth: 360)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let backup = selectedBackup {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Diff")
                                .font(.title2.weight(.semibold))
                            Text(L("backups.originalFile", backup.originalPath))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(L("backups.backupFile", backup.backupPath))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack {
                                RowActions(path: backup.originalPath)
                                RowActions(path: backup.backupPath)
                            }
                        }
                        .cardStyle()

                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(appState.diffLines(for: backup)) { line in
                                Text(line.text.isEmpty ? " " : line.text)
                                    .font(.system(.caption, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(background(for: line.kind))
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(10)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        EmptyStateView(title: L("backups.select.title"), message: L("backups.select.message"), systemImage: "doc.text.magnifyingglass")
                    }
                }
                .padding(20)
            }
        }
        .onAppear {
            if selectedBackupID == nil { selectedBackupID = appState.backups.first?.id }
        }
    }

    private func background(for kind: DiffLine.Kind) -> Color {
        switch kind {
        case .same: return Color.clear
        case .added: return Color.green.opacity(0.12)
        case .removed: return Color.red.opacity(0.12)
        }
    }
}
