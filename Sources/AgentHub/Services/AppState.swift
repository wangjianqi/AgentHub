import AppKit
import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var snapshot: AuditSnapshot = .empty
    @Published private(set) var isScanning = false
    @Published var workspaceURL: URL?
    @Published var searchText: String = ""
    @Published var operationMessage: String?
    @Published private(set) var checkResults: [String: MCPCheckResult] = [:]
    @Published private(set) var profiles: [MCPProfile] = []
    @Published private(set) var backups: [BackupItem] = []

    private let scanner = AgentScanner()
    private let editor = ConfigEditor()
    private let profileStore = ProfileStore()

    init() {
        profiles = profileStore.load()
        reloadBackups()
        refresh()
    }

    func refresh() {
        isScanning = true
        snapshot = scanner.scan(workspace: workspaceURL)
        isScanning = false
        reloadBackups()
    }

    func chooseWorkspace() {
        let panel = NSOpenPanel()
        panel.title = L("panel.chooseWorkspace")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        if panel.runModal() == .OK {
            workspaceURL = panel.url
            refresh()
        }
    }

    func clearWorkspace() {
        workspaceURL = nil
        refresh()
    }

    func revealInFinder(path: String) {
        let resolved = resolvePath(path)
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: resolved)])
    }

    func openFile(path: String) {
        let resolved = resolvePath(path)
        NSWorkspace.shared.open(URL(fileURLWithPath: resolved))
    }

    func copyToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    func setMCPServer(_ server: MCPServerItem, enabled: Bool) {
        do {
            let result = try editor.setMCPServer(server, enabled: enabled)
            operationMessage = resultMessage(result)
            refresh()
        } catch {
            operationMessage = L("message.operationFailed", error.localizedDescription)
        }
    }

    func backupConfig(path: String) {
        do {
            let url = URL(fileURLWithPath: resolvePath(path))
            let backup = try editor.backupFile(at: url)
            operationMessage = L("message.backupCreated", path, backup.abbreviatedPath)
            reloadBackups()
        } catch {
            operationMessage = L("message.backupFailed", error.localizedDescription)
        }
    }

    func checkMCPServer(_ server: MCPServerItem) {
        let result = MCPHealthChecker.check(server: server)
        checkResults[server.stableKey] = result
        operationMessage = L("message.checkOne", server.name, result.title, result.detail)
    }

    func checkAllMCPServers() {
        for server in snapshot.mcpServers {
            checkResults[server.stableKey] = MCPHealthChecker.check(server: server)
        }
        operationMessage = L("message.checkAllDone", snapshot.mcpServers.count)
    }

    func checkResult(for server: MCPServerItem) -> MCPCheckResult? {
        checkResults[server.stableKey]
    }

    func migrateMCPServer(_ server: MCPServerItem, to targetTool: ToolKind, writeToConfig: Bool) {
        if writeToConfig {
            do {
                let result = try editor.addMCPServer(server, to: targetTool)
                operationMessage = resultMessage(result)
                refresh()
            } catch {
                operationMessage = L("message.migrationFailed", error.localizedDescription)
            }
        } else {
            let snippet = editor.migrationSnippet(for: server, targetTool: targetTool)
            copyToPasteboard(snippet)
            operationMessage = L("message.migrationSnippetCopied", targetTool.rawValue)
        }
    }

    func migrationSnippet(for server: MCPServerItem, targetTool: ToolKind) -> String {
        editor.migrationSnippet(for: server, targetTool: targetTool)
    }

    func reloadBackups() {
        backups = editor.listBackups()
    }

    func diffLines(for backup: BackupItem) -> [DiffLine] {
        editor.diff(backup: backup)
    }

    func createProfile(name: String, notes: String) {
        let normalized = name.trimmed
        guard !normalized.isEmpty else {
            operationMessage = L("message.profileNameEmpty")
            return
        }
        profiles.append(MCPProfile(name: normalized, notes: notes.trimmed))
        saveProfiles()
        operationMessage = L("message.profileCreated", normalized)
    }

    func deleteProfile(_ profile: MCPProfile) {
        profiles.removeAll { $0.id == profile.id }
        saveProfiles()
    }

    func addServer(_ server: MCPServerItem, to profile: MCPProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        let ref = MCPProfileServer(server: server)
        if profiles[index].servers.contains(where: { $0.stableKey == ref.stableKey }) {
            operationMessage = L("message.profileAlreadyContainsMCP")
            return
        }
        profiles[index].servers.append(ref)
        profiles[index].updatedAt = Date()
        saveProfiles()
        operationMessage = L("message.profileMCPAdded", server.name, profiles[index].name)
    }

    func removeServer(_ server: MCPProfileServer, from profile: MCPProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[index].servers.removeAll { $0.id == server.id }
        profiles[index].updatedAt = Date()
        saveProfiles()
    }

    func exportProfile(_ profile: MCPProfile) {
        let lines = profile.servers.map { server in
            "- [\(server.tool.rawValue)] \(server.name) · \(server.commandLine) · \(server.sourcePath)"
        }
        let output = "# \(profile.name)\n\n\(profile.notes)\n\n" + lines.joined(separator: "\n")
        copyToPasteboard(output)
        operationMessage = L("message.profileExported", profile.name)
    }

    func profilesPath() -> String {
        profileStore.profilesPath()
    }

    private func saveProfiles() {
        profileStore.save(profiles)
    }

    private func resultMessage(_ result: ConfigEditResult) -> String {
        var message = "\(result.title)\n\n\(result.message)"
        if let backupPath = result.backupPath {
            message += L("message.backupPathSuffix", backupPath)
        }
        return message
    }

    private func resolvePath(_ path: String) -> String {
        if path.hasPrefix("~/") {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            return home + String(path.dropFirst(1))
        }
        return path
    }
}
