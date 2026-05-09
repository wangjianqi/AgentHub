import SwiftUI

struct ConfigFileListView: View {
    @EnvironmentObject private var appState: AppState

    private var items: [ConfigFileItem] {
        let query = appState.searchText.trimmed.lowercased()
        guard !query.isEmpty else { return appState.snapshot.configFiles }
        return appState.snapshot.configFiles.filter { item in
            [item.path, item.tool.rawValue, item.scope.localizedTitle, item.summary]
                .joined(separator: " ")
                .lowercased()
                .contains(query)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                SectionTitle(L("configs.title"), subtitle: L("configs.subtitle", items.count))
                ForEach(items) { item in
                    ConfigFileRow(item: item)
                }
            }
            .padding(20)
        }
    }
}

struct ConfigFileRow: View {
    @EnvironmentObject private var appState: AppState
    let item: ConfigFileItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.exists ? "doc.text" : "doc.badge.questionmark")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(item.path)
                        .font(.headline)
                        .lineLimit(1)
                    TagView(item.tool.rawValue)
                    TagView(item.scope.localizedTitle)
                    TagView(item.exists ? L("configs.exists") : L("configs.missing"))
                }
                Text(item.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if item.exists {
                VStack(alignment: .trailing, spacing: 8) {
                    Button {
                        appState.backupConfig(path: item.path)
                    } label: {
                        Label(L("button.backup"), systemImage: "clock.arrow.circlepath")
                    }
                    .buttonStyle(.borderless)
                    RowActions(path: item.path)
                }
            }
        }
        .cardStyle()
    }
}
