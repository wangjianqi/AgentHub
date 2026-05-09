import SwiftUI

struct MCPListView: View {
    @EnvironmentObject private var appState: AppState

    private var items: [MCPServerItem] {
        let query = appState.searchText.trimmed.lowercased()
        guard !query.isEmpty else { return appState.snapshot.mcpServers }
        return appState.snapshot.mcpServers.filter { item in
            [item.name, item.tool.rawValue, item.scope.localizedTitle, item.sourcePath, item.commandLine, item.envKeys.joined(separator: " ")]
                .joined(separator: " ")
                .lowercased()
                .contains(query)
        }
    }

    var body: some View {
        if items.isEmpty {
            EmptyStateView(title: L("mcp.empty.title"), message: L("mcp.empty.message"), systemImage: "server.rack")
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    HStack {
                        SectionTitle("MCP Servers", subtitle: L("mcp.section.subtitle", items.count))
                        Spacer()
                        Button {
                            appState.checkAllMCPServers()
                        } label: {
                            Label(L("button.checkAll"), systemImage: "checkmark.seal")
                        }
                    }
                    ForEach(items) { item in
                        MCPRow(item: item)
                    }
                }
                .padding(20)
            }
        }
    }
}

struct MCPRow: View {
    @EnvironmentObject private var appState: AppState
    let item: MCPServerItem
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: item.tool.iconName)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(item.name)
                            .font(.headline)
                        TagView(item.tool.rawValue)
                        TagView(item.scope.localizedTitle)
                        TagView(item.isEnabled ? L("mcp.enabled") : L("mcp.disabled"), systemImage: item.isEnabled ? "checkmark.circle" : "pause.circle")
                        if let check = appState.checkResult(for: item) {
                            CheckStatusBadge(status: check.status)
                        }
                    }

                    Text(item.commandLine.isEmpty ? L("mcp.noCommand") : item.commandLine)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(item.isEnabled ? .primary : .secondary)
                        .textSelection(.enabled)

                    HStack(spacing: 8) {
                        Text(item.sourcePath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        if !item.envKeys.isEmpty {
                            TagView("Env: \(item.envKeys.joined(separator: ", "))", systemImage: "key")
                        }
                        if let reason = item.disabledReason {
                            TagView(reason, systemImage: "info.circle")
                        }
                    }

                    if let check = appState.checkResult(for: item) {
                        Text(check.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    HStack(spacing: 8) {
                        Button {
                            appState.setMCPServer(item, enabled: !item.isEnabled)
                        } label: {
                            Label(item.isEnabled ? L("button.disable") : L("button.enable"), systemImage: item.isEnabled ? "pause.circle" : "play.circle")
                        }
                        .buttonStyle(.borderless)
                        .disabled(item.scope == .system)

                        Button {
                            appState.checkMCPServer(item)
                        } label: {
                            Label(L("button.check"), systemImage: "checkmark.seal")
                        }
                        .buttonStyle(.borderless)
                    }

                    HStack(spacing: 8) {
                        Button {
                            appState.copyToPasteboard(item.commandLine)
                        } label: {
                            Label(L("button.copyCommand"), systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        RowActions(path: item.sourcePath)
                    }
                }
            }

            DisclosureGroup(isExpanded: $expanded) {
                Text(item.rawSnippet.isEmpty ? L("mcp.noRawSnippet") : item.rawSnippet)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            } label: {
                Text(L("mcp.rawConfigSnippet"))
                    .font(.caption.weight(.medium))
            }
        }
        .cardStyle()
    }
}

struct CheckStatusBadge: View {
    let status: MCPCheckStatus

    var body: some View {
        Text(status.localizedTitle)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(background, in: Capsule())
            .foregroundStyle(foreground)
    }

    private var background: Color {
        switch status {
        case .ok: return Color.green.opacity(0.18)
        case .warning: return Color.orange.opacity(0.18)
        case .failed: return Color.red.opacity(0.18)
        case .skipped: return Color.gray.opacity(0.18)
        }
    }

    private var foreground: Color {
        switch status {
        case .ok: return .green
        case .warning: return .orange
        case .failed: return .red
        case .skipped: return .secondary
        }
    }
}
