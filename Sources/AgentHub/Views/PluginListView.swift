import SwiftUI

struct PluginListView: View {
    @EnvironmentObject private var appState: AppState

    private var items: [PluginItem] {
        let query = appState.searchText.trimmed.lowercased()
        guard !query.isEmpty else { return appState.snapshot.plugins }
        return appState.snapshot.plugins.filter { item in
            [item.name, item.tool.rawValue, item.scope.localizedTitle, item.path ?? "", item.sourcePath ?? "", item.summary]
                .joined(separator: " ")
                .lowercased()
                .contains(query)
        }
    }

    var body: some View {
        if items.isEmpty {
            EmptyStateView(title: L("plugins.empty.title"), message: L("plugins.empty.message"), systemImage: "puzzlepiece.extension")
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    SectionTitle("Plugins", subtitle: L("plugins.section.subtitle", items.count))
                    ForEach(items) { item in
                        PluginRow(item: item)
                    }
                }
                .padding(20)
            }
        }
    }
}

struct PluginRow: View {
    let item: PluginItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "puzzlepiece.extension")
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
                if let path = item.path ?? item.sourcePath {
                    Text(path)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if let path = item.path ?? item.sourcePath {
                RowActions(path: path)
            }
        }
        .cardStyle()
    }
}
