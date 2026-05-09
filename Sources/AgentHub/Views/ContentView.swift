import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
    case dashboard
    case mcp
    case profiles
    case migration
    case backups
    case skills
    case agents
    case hooks
    case plugins
    case risks
    case configs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return L("sidebar.dashboard")
        case .mcp: return "MCP"
        case .profiles: return "Profiles"
        case .migration: return L("sidebar.migration")
        case .backups: return L("sidebar.backups")
        case .skills: return "Skills"
        case .agents: return "Agents"
        case .hooks: return "Hooks"
        case .plugins: return "Plugins"
        case .risks: return L("sidebar.risks")
        case .configs: return L("sidebar.configs")
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: return "chart.bar.doc.horizontal"
        case .mcp: return "server.rack"
        case .profiles: return "rectangle.3.group"
        case .migration: return "arrow.triangle.2.circlepath"
        case .backups: return "clock.arrow.circlepath"
        case .skills: return "wand.and.stars"
        case .agents: return "person.2.wave.2"
        case .hooks: return "link.badge.plus"
        case .plugins: return "puzzlepiece.extension"
        case .risks: return "exclamationmark.triangle"
        case .configs: return "doc.text.magnifyingglass"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selected: SidebarItem? = .dashboard

    var body: some View {
        NavigationSplitView {
            List(selection: $selected) {
                ForEach(SidebarItem.allCases) { item in
                    Label(item.title, systemImage: item.systemImage)
                        .tag(item)
                }
            }
            .navigationTitle("AgentHub")
            .frame(minWidth: 210)
        } detail: {
            VStack(spacing: 0) {
                ToolbarHeader()
                Divider()
                detailView
            }
        }
        .alert("AgentHub", isPresented: Binding(
            get: { appState.operationMessage != nil },
            set: { if !$0 { appState.operationMessage = nil } }
        )) {
            Button(L("common.ok"), role: .cancel) { appState.operationMessage = nil }
        } message: {
            Text(appState.operationMessage ?? "")
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selected ?? .dashboard {
        case .dashboard:
            DashboardView()
        case .mcp:
            MCPListView()
        case .profiles:
            ProfileListView()
        case .migration:
            MigrationView()
        case .backups:
            BackupDiffView()
        case .skills:
            SkillListView()
        case .agents:
            AgentListView()
        case .hooks:
            HookListView()
        case .plugins:
            PluginListView()
        case .risks:
            RiskListView()
        case .configs:
            ConfigFileListView()
        }
    }
}

struct ToolbarHeader: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var languageManager: LanguageManager

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L("toolbar.title"))
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            TextField(L("toolbar.searchPlaceholder"), text: $appState.searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)

            if appState.isScanning {
                ProgressView()
                    .scaleEffect(0.8)
            }

            Menu {
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        languageManager.setLanguage(language)
                        appState.refresh()
                    } label: {
                        HStack {
                            Text(language.menuTitle)
                            if language == languageManager.language { Text("✓") }
                        }
                    }
                }
            } label: {
                Label(languageManager.language.menuTitle, systemImage: "globe")
            }

            Button {
                appState.chooseWorkspace()
            } label: {
                Label(L("button.chooseProject"), systemImage: "folder")
            }

            if appState.workspaceURL != nil {
                Button {
                    appState.clearWorkspace()
                } label: {
                    Label(L("button.clearProject"), systemImage: "xmark.circle")
                }
            }

            Button {
                appState.refresh()
            } label: {
                Label(L("button.refresh"), systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: [.command])
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var subtitle: String {
        let date = appState.snapshot.scannedAt.formatted(date: .abbreviated, time: .standard)
        if let workspace = appState.workspaceURL?.path {
            return L("toolbar.subtitle.workspace", date, workspace)
        }
        return L("toolbar.subtitle.default", date)
    }
}
