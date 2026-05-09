import SwiftUI

struct ProfileListView: View {
    @EnvironmentObject private var appState: AppState
    @State private var newName = ""
    @State private var newNotes = ""
    @State private var selectedProfileID: MCPProfile.ID?

    private var selectedProfile: MCPProfile? {
        appState.profiles.first { $0.id == selectedProfileID } ?? appState.profiles.first
    }

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("Profiles", subtitle: L("profiles.subtitle"))

                VStack(alignment: .leading, spacing: 8) {
                    TextField(L("profiles.namePlaceholder"), text: $newName)
                    TextField(L("profiles.notesPlaceholder"), text: $newNotes)
                    Button {
                        appState.createProfile(name: newName, notes: newNotes)
                        newName = ""
                        newNotes = ""
                        selectedProfileID = appState.profiles.last?.id
                    } label: {
                        Label(L("profiles.create"), systemImage: "plus")
                    }
                }
                .cardStyle()

                List(appState.profiles, selection: $selectedProfileID) { profile in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.name)
                            .font(.headline)
                        Text(L("profiles.serverCount", profile.servers.count))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(profile.id)
                }
            }
            .padding(20)
            .frame(minWidth: 320)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let profile = selectedProfile {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile.name)
                                    .font(.title2.weight(.semibold))
                                Text(profile.notes.isEmpty ? L("profiles.noNotes") : profile.notes)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                Text(L("profiles.savePath", appState.profilesPath()))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                            Button {
                                appState.exportProfile(profile)
                            } label: {
                                Label(L("profiles.export"), systemImage: "doc.on.doc")
                            }
                            Button(role: .destructive) {
                                appState.deleteProfile(profile)
                                selectedProfileID = appState.profiles.first?.id
                            } label: {
                                Label(L("button.delete"), systemImage: "trash")
                            }
                        }
                        .cardStyle()

                        AddMCPToProfileCard(profile: profile)

                        VStack(alignment: .leading, spacing: 12) {
                            SectionTitle(L("profiles.innerMCP"), subtitle: L("profiles.innerMCP.subtitle", profile.servers.count))
                            if profile.servers.isEmpty {
                                Text(L("profiles.noMCP"))
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(profile.servers) { server in
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: server.tool.iconName)
                                            .frame(width: 24)
                                            .foregroundStyle(.secondary)
                                        VStack(alignment: .leading, spacing: 5) {
                                            HStack {
                                                Text(server.name)
                                                    .font(.headline)
                                                TagView(server.tool.rawValue)
                                                TagView(server.scope.localizedTitle)
                                            }
                                            Text(server.commandLine.isEmpty ? L("profiles.noRecordedCommand") : server.commandLine)
                                                .font(.system(.caption, design: .monospaced))
                                                .textSelection(.enabled)
                                            Text(server.sourcePath)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Button(role: .destructive) {
                                            appState.removeServer(server, from: profile)
                                        } label: {
                                            Label(L("button.remove"), systemImage: "minus.circle")
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                    .cardStyle()
                                }
                            }
                        }
                    } else {
                        EmptyStateView(title: L("profiles.empty.title"), message: L("profiles.empty.message"), systemImage: "rectangle.3.group")
                    }
                }
                .padding(20)
            }
        }
        .onAppear {
            if selectedProfileID == nil { selectedProfileID = appState.profiles.first?.id }
        }
    }
}

struct AddMCPToProfileCard: View {
    @EnvironmentObject private var appState: AppState
    let profile: MCPProfile
    @State private var selectedServerID: MCPServerItem.ID?

    private var selectedServer: MCPServerItem? {
        appState.snapshot.mcpServers.first { $0.id == selectedServerID } ?? appState.snapshot.mcpServers.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("profiles.addMCP"))
                .font(.headline)
            Picker("MCP", selection: $selectedServerID) {
                ForEach(appState.snapshot.mcpServers) { server in
                    Text("\(server.name) · \(server.tool.rawValue)").tag(Optional(server.id))
                }
            }
            HStack {
                Button {
                    if let selectedServer { appState.addServer(selectedServer, to: profile) }
                } label: {
                    Label(L("profiles.addToCurrent"), systemImage: "plus.circle")
                }
                .disabled(selectedServer == nil)
                Spacer()
            }
        }
        .cardStyle()
        .onAppear {
            if selectedServerID == nil { selectedServerID = appState.snapshot.mcpServers.first?.id }
        }
    }
}
