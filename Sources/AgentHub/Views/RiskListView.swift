import SwiftUI

struct RiskListView: View {
    @EnvironmentObject private var appState: AppState

    private var items: [RiskIssue] {
        let query = appState.searchText.trimmed.lowercased()
        guard !query.isEmpty else { return appState.snapshot.risks }
        return appState.snapshot.risks.filter { item in
            [item.title, item.message, item.tool.rawValue, item.sourcePath ?? "", item.relatedName ?? "", item.severity.localizedTitle]
                .joined(separator: " ")
                .lowercased()
                .contains(query)
        }
    }

    var body: some View {
        if items.isEmpty {
            EmptyStateView(title: L("risks.empty.title"), message: L("risks.empty.message"), systemImage: "checkmark.shield")
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    SectionTitle(L("sidebar.risks"), subtitle: L("risks.section.subtitle", items.count))
                    ForEach(items) { item in
                        RiskRow(item: item)
                    }
                }
                .padding(20)
            }
        }
    }
}

struct RiskRow: View {
    @EnvironmentObject private var appState: AppState
    let item: RiskIssue

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    SeverityBadge(severity: item.severity)
                    Text(item.title)
                        .font(.headline)
                    TagView(item.tool.rawValue)
                }
                Text(item.message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if let relatedName = item.relatedName {
                    Text(L("risks.related", relatedName))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let sourcePath = item.sourcePath {
                    Text(sourcePath)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                }
            }
            Spacer()
            if let path = item.sourcePath, !path.contains("\n") {
                RowActions(path: path)
            }
        }
        .cardStyle()
    }
}
