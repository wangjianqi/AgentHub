import SwiftUI

struct SkillListView: View {
    @EnvironmentObject private var appState: AppState

    private var items: [SkillItem] {
        let query = appState.searchText.trimmed.lowercased()
        guard !query.isEmpty else { return appState.snapshot.skills }
        return appState.snapshot.skills.filter { item in
            [item.name, item.tool.rawValue, item.scope.localizedTitle, item.path, item.summary]
                .joined(separator: " ")
                .lowercased()
                .contains(query)
        }
    }

    var body: some View {
        if items.isEmpty {
            EmptyStateView(title: L("skills.empty.title"), message: L("skills.empty.message"), systemImage: "wand.and.stars")
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    SectionTitle("Skills", subtitle: L("skills.section.subtitle", items.count))
                    ForEach(items) { item in
                        SkillRow(item: item)
                    }
                }
                .padding(20)
            }
        }
    }
}

struct SkillRow: View {
    let item: SkillItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "wand.and.stars")
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
