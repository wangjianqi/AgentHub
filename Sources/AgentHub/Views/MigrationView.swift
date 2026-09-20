import SwiftUI

struct MigrationView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedServerID: MCPServerItem.ID?
    @State private var targetTool: ToolKind = .claudeCode
    @State private var writeToConfig = false

    private var selectedServer: MCPServerItem? {
        appState.snapshot.mcpServers.first { $0.id == selectedServerID } ?? appState.snapshot.mcpServers.first
    }

    var body: some View {
        HSplitView {
            List(appState.snapshot.mcpServers, selection: $selectedServerID) { server in
                VStack(alignment: .leading, spacing: 4) {
                    Text(server.name)
                        .font(.headline)
                    Text("\(server.tool.rawValue) · \(server.sourcePath)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.vertical, 4)
                .tag(server.id)
            }
            .frame(minWidth: 280)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SectionTitle(L("migration.title"), subtitle: L("migration.subtitle"))

                    if let server = selectedServer {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(server.name)
                                .font(.title3.weight(.semibold))
                            Text(server.commandLine.isEmpty ? L("migration.noCommand") : server.commandLine)
                                .font(.system(.callout, design: .monospaced))
                                .textSelection(.enabled)
                            Text(L("migration.source", server.tool.rawValue, server.sourcePath))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Picker(L("migration.targetPlatform"), selection: $targetTool) {
                                ForEach(appState.migrationTargets) { tool in
                                    Text(tool.rawValue).tag(tool)
                                }
                            }
                            .pickerStyle(.menu)

                            Toggle(L("migration.writeDirectly"), isOn: $writeToConfig)
                                .toggleStyle(.switch)
                                .disabled(!appState.canWriteMCP(to: targetTool))

                            if !appState.canWriteMCP(to: targetTool) {
                                Text(L("migration.readOnlyTarget"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            HStack {
                                Button {
                                    appState.migrateMCPServer(server, to: targetTool, writeToConfig: writeToConfig)
                                } label: {
                                    Label(writeToConfig ? L("button.writeConfig") : L("button.copyMigrationSnippet"), systemImage: writeToConfig ? "square.and.arrow.down" : "doc.on.doc")
                                }
                                .buttonStyle(.borderedProminent)

                                Button {
                                    appState.copyToPasteboard(appState.migrationSnippet(for: server, targetTool: targetTool))
                                } label: {
                                    Label(L("button.copySnippet"), systemImage: "doc.on.doc")
                                }
                            }
                        }
                        .cardStyle()

                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("migration.preview"))
                                .font(.headline)
                            Text(appState.migrationSnippet(for: server, targetTool: targetTool))
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .cardStyle()
                    } else {
                        EmptyStateView(title: L("migration.empty.title"), message: L("migration.empty.message"), systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .padding(20)
            }
        }
        .onAppear {
            if selectedServerID == nil { selectedServerID = appState.snapshot.mcpServers.first?.id }
            if !appState.canWriteMCP(to: targetTool) { writeToConfig = false }
        }
        .onChange(of: targetTool) { newValue in
            if !appState.canWriteMCP(to: newValue) { writeToConfig = false }
        }
    }
}
