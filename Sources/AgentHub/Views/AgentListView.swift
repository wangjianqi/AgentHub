import SwiftUI

struct AgentListView: View {
    @EnvironmentObject private var appState: AppState

    private var items: [AgentItem] {
        let query = appState.searchText.trimmed.lowercased()
        guard !query.isEmpty else { return appState.snapshot.agents }
        return appState.snapshot.agents.filter { item in
            [item.name, item.tool.rawValue, item.scope.localizedTitle, item.path, item.summary]
                .joined(separator: " ")
                .lowercased()
                .contains(query)
        }
    }

    var body: some View {
        if items.isEmpty {
            EmptyStateView(title: L("agents.empty.title"), message: L("agents.empty.message"), systemImage: "person.2.wave.2")
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    SectionTitle("Agents", subtitle: L("agents.section.subtitle", items.count))
                    ForEach(items) { item in
                        AgentRow(item: item)
                    }
                }
                .padding(20)
            }
        }
    }
}

struct AgentRow: View {
    let item: AgentItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "person.2.wave.2")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(item.name)
                        .font(.headline)
                    TagView(item.tool.rawValue)
                    TagView(item.scope.localizedTitle)
                }
                Text(item.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                Text(item.path)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer()
            RowActions(path: item.path)
        }
        .cardStyle()
    }
}
