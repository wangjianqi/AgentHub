import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionTitle(L("dashboard.title"), subtitle: L("dashboard.subtitle"))

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 14)], spacing: 14) {
                    StatCard(title: "MCP Servers", value: "\(snapshot.mcpServers.count)", subtitle: L("dashboard.stat.mcp"), systemImage: "server.rack")
                    StatCard(title: "Skills", value: "\(snapshot.skills.count)", subtitle: L("dashboard.stat.skills"), systemImage: "wand.and.stars")
                    StatCard(title: "Agents", value: "\(snapshot.agents.count)", subtitle: L("dashboard.stat.agents"), systemImage: "person.2.wave.2")
                    StatCard(title: "Plugins", value: "\(snapshot.plugins.count)", subtitle: L("dashboard.stat.plugins"), systemImage: "puzzlepiece.extension")
                    StatCard(title: "Profiles", value: "\(appState.profiles.count)", subtitle: L("dashboard.stat.profiles"), systemImage: "rectangle.3.group")
                    StatCard(title: L("sidebar.backups"), value: "\(appState.backups.count)", subtitle: L("dashboard.stat.backups"), systemImage: "clock.arrow.circlepath")
                    StatCard(title: L("sidebar.risks"), value: "\(snapshot.risks.count)", subtitle: L("dashboard.stat.risks"), systemImage: "exclamationmark.triangle")
                }

                HStack(alignment: .top, spacing: 14) {
                    installationsCard
                    riskCard
                }

                configSummaryCard
            }
            .padding(20)
        }
    }

    private var snapshot: AuditSnapshot { appState.snapshot }

    private var installationsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("dashboard.installations"))
                .font(.headline)
            ForEach(snapshot.installations) { item in
                HStack(spacing: 10) {
                    Image(systemName: item.tool.iconName)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.tool.rawValue)
                            .font(.subheadline.weight(.medium))
                        Text(item.executablePath ?? L("dashboard.notFoundInPath", item.executableName))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    TagView(item.status.localizedTitle, systemImage: item.status == .installed ? "checkmark.circle" : "questionmark.circle")
                }
                Divider()
            }
        }
        .cardStyle()
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var riskCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("dashboard.mainRisks"))
                .font(.headline)
            if snapshot.risks.isEmpty {
                Text(L("dashboard.noRisks"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(snapshot.risks.prefix(5)) { risk in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            SeverityBadge(severity: risk.severity)
                            Text(risk.title)
                                .font(.subheadline.weight(.medium))
                            Spacer()
                        }
                        Text(risk.relatedName ?? risk.tool.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Divider()
                }
            }
        }
        .cardStyle()
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var configSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("dashboard.configScan"))
                .font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 10)], spacing: 10) {
                ForEach(snapshot.configFiles) { file in
                    HStack(spacing: 10) {
                        Image(systemName: file.exists ? "doc.text" : "doc.badge.questionmark")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(file.path)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                            Text("\(file.tool.rawValue) · \(file.scope.localizedTitle)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .cardStyle()
    }
}

struct SeverityBadge: View {
    let severity: RiskSeverity

    var body: some View {
        Text(severity.localizedTitle)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(background, in: Capsule())
            .foregroundStyle(foreground)
    }

    private var background: Color {
        switch severity {
        case .high: return Color.red.opacity(0.18)
        case .medium: return Color.orange.opacity(0.18)
        case .low: return Color.yellow.opacity(0.22)
        case .info: return Color.blue.opacity(0.16)
        }
    }

    private var foreground: Color {
        switch severity {
        case .high: return .red
        case .medium: return .orange
        case .low: return .primary
        case .info: return .blue
        }
    }
}
