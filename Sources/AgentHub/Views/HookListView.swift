import SwiftUI

struct HookListView: View {
    @EnvironmentObject private var appState: AppState

    private var items: [HookItem] {
        let query = appState.searchText.trimmed.lowercased()
        guard !query.isEmpty else { return appState.snapshot.hooks }
        return appState.snapshot.hooks.filter { item in
            [item.name, item.tool.rawValue, item.scope.localizedTitle, item.sourcePath, item.event ?? "", item.command ?? "", item.rawSnippet]
                .joined(separator: " ")
                .lowercased()
                .contains(query)
        }
    }

    var body: some View {
        if items.isEmpty {
            EmptyStateView(title: L("hooks.empty.title"), message: L("hooks.empty.message"), systemImage: "link.badge.plus")
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    SectionTitle("Hooks", subtitle: L("hooks.section.subtitle", items.count))
                    ForEach(items) { item in
                        HookRow(item: item)
                    }
                }
                .padding(20)
            }
        }
    }
}

struct HookRow: View {
    let item: HookItem
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "link.badge.plus")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(item.name)
                            .font(.headline)
                        TagView(item.tool.rawValue)
                        TagView(item.scope.localizedTitle)
                        if let event = item.event {
                            TagView(event, systemImage: "bolt")
                        }
                    }
                    Text(item.command ?? L("hooks.noCommand"))
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                    Text(item.sourcePath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                RowActions(path: item.sourcePath)
            }

            DisclosureGroup(isExpanded: $expanded) {
                Text(item.rawSnippet)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            } label: {
                Text(L("hooks.rawSnippet"))
                    .font(.caption.weight(.medium))
            }
        }
        .cardStyle()
    }
}
