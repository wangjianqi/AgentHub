import Foundation

final class ConfigEditor {
    private let fileManager = FileManager.default
    private let registry: PlatformRegistry

    init(registry: PlatformRegistry = .default) {
        self.registry = registry
    }

    func setMCPServer(_ server: MCPServerItem, enabled: Bool) throws -> ConfigEditResult {
        let url = URL(fileURLWithPath: resolvePath(server.sourcePath))
        guard fileManager.fileExists(atPath: url.path) else {
            throw ConfigEditorError.fileNotFound(server.sourcePath)
        }
        let backup = try backupFile(at: url)

        if url.pathExtension.lowercased() == "toml" {
            let before = try String(contentsOf: url, encoding: .utf8)
            let after = updateTOMLEnabledState(text: before, serverName: server.name, enabled: enabled)
            try after.write(to: url, atomically: true, encoding: .utf8)
        } else {
            let object = JSONScanner.loadObject(from: url, allowJSONC: true) ?? [String: Any]()
            let update = updateJSONMCPEnabled(object: object, serverName: server.name, enabled: enabled)
            guard update.changed else { throw ConfigEditorError.mcpNotFound(server.name) }
            let data = try JSONSerialization.data(withJSONObject: update.object, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: url, options: .atomic)
        }

        return ConfigEditResult(
            title: enabled ? L("edit.enabledMCP") : L("edit.disabledMCP"),
            message: L("edit.mcpWritten", server.name, url.abbreviatedPath),
            originalPath: url.abbreviatedPath,
            backupPath: backup.abbreviatedPath,
            changed: true
        )
    }

    func addMCPServer(_ server: MCPServerItem, to targetTool: ToolKind) throws -> ConfigEditResult {
        guard let target = registry.platform(for: targetTool), let spec = target.primaryUserConfig else {
            throw ConfigEditorError.unsupportedTarget(targetTool.rawValue)
        }
        guard let url = target.resolve(spec: spec, home: fileManager.homeDirectoryForCurrentUser, workspace: nil) else {
            throw ConfigEditorError.unsupportedTarget(targetTool.rawValue)
        }

        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let backup = fileManager.fileExists(atPath: url.path) ? try backupFile(at: url) : nil

        switch spec.format {
        case .toml:
            let old = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            let snippet = migrationSnippet(for: server, targetTool: targetTool)
            let text = old.trimmed.isEmpty ? snippet + "\n" : old.trimmed + "\n\n" + snippet + "\n"
            try text.write(to: url, atomically: true, encoding: .utf8)
        case .json, .jsonc:
            let object = JSONScanner.loadObject(from: url, allowJSONC: true) ?? [String: Any]()
            let updated = addJSONMCPServer(object: object, server: server, targetTool: targetTool)
            let data = try JSONSerialization.data(withJSONObject: updated, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: url, options: .atomic)
        }

        return ConfigEditResult(
            title: L("edit.mcpMigrated"),
            message: L("edit.mcpMigratedMessage", server.name, targetTool.rawValue),
            originalPath: url.abbreviatedPath,
            backupPath: backup?.abbreviatedPath,
            changed: true
        )
    }

    func migrationSnippet(for server: MCPServerItem, targetTool: ToolKind) -> String {
        let escapedName = server.name.replacingOccurrences(of: "\"", with: "\\\"")
        let argsArray = server.args.map { "\"\($0.replacingOccurrences(of: "\"", with: "\\\""))\"" }.joined(separator: ", ")
        let command = server.command ?? ""
        let escapedCommand = command.replacingOccurrences(of: "\"", with: "\\\"")

        if targetTool == .codex {
            var lines = [
                "[mcp_servers.\(server.name)]",
                "command = \"\(escapedCommand)\""
            ]
            if !server.args.isEmpty { lines.append("args = [\(argsArray)]") }
            if !server.envKeys.isEmpty {
                lines.append("[mcp_servers.\(server.name).env]")
                for key in server.envKeys { lines.append("\(key.replacingOccurrences(of: "header:", with: "")) = \"<FILL_ME>\"") }
            }
            return lines.joined(separator: "\n")
        }

        let container = preferredMCPContainerKey(for: targetTool)
        var lines = [
            "{",
            "  \"\(container)\": {",
            "    \"\(escapedName)\": {",
            "      \"command\": \"\(escapedCommand)\""
        ]
        if !server.args.isEmpty { lines.append("      ,\"args\": [\(argsArray)]") }
        if !server.envKeys.isEmpty {
            lines.append("      ,\"env\": {")
            let envLines = server.envKeys.map { "        \"\($0.replacingOccurrences(of: "header:", with: ""))\": \"<FILL_ME>\"" }
            lines.append(envLines.joined(separator: ",\n"))
            lines.append("      }")
        }
        lines += ["    }", "  }", "}"]
        return lines.joined(separator: "\n")
    }

    @discardableResult
    func backupFile(at url: URL) throws -> URL {
        guard fileManager.fileExists(atPath: url.path) else { throw ConfigEditorError.fileNotFound(url.abbreviatedPath) }
        let backupsRoot = try backupsDirectory()
        let timestamp = Self.backupTimestampFormatter.string(from: Date())
        let safeOriginal = url.path.replacingOccurrences(of: "/", with: "__")
        let targetDir = backupsRoot.appendingPathComponent(timestamp, isDirectory: true)
        try fileManager.createDirectory(at: targetDir, withIntermediateDirectories: true)
        let target = targetDir.appendingPathComponent(safeOriginal)
        try fileManager.copyItem(at: url, to: target)
        return target
    }

    func listBackups() -> [BackupItem] {
        guard let backupsRoot = try? backupsDirectory(), fileManager.fileExists(atPath: backupsRoot.path) else { return [] }
        guard let enumerator = fileManager.enumerator(at: backupsRoot, includingPropertiesForKeys: [.creationDateKey, .fileSizeKey, .isRegularFileKey], options: [.skipsHiddenFiles]) else { return [] }
        var result: [BackupItem] = []
        for case let url as URL in enumerator {
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
            let values = try? url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
            let originalPath = restoreOriginalPath(fromBackupFileName: url.lastPathComponent)
            result.append(BackupItem(
                originalPath: originalPath,
                backupPath: url.abbreviatedPath,
                createdAt: values?.creationDate ?? Date.distantPast,
                bytes: Int64(values?.fileSize ?? 0)
            ))
        }
        return result.sorted { $0.createdAt > $1.createdAt }
    }

    func diff(backup: BackupItem) -> [DiffLine] {
        let backupURL = URL(fileURLWithPath: resolvePath(backup.backupPath))
        let originalURL = URL(fileURLWithPath: backup.originalPath)
        let old = ((try? String(contentsOf: backupURL, encoding: .utf8)) ?? "").components(separatedBy: .newlines)
        let new = ((try? String(contentsOf: originalURL, encoding: .utf8)) ?? "").components(separatedBy: .newlines)
        return DiffService.diff(oldLines: old, newLines: new)
    }

    private func updateJSONMCPEnabled(object: Any, serverName: String, enabled: Bool) -> (object: Any, changed: Bool) {
        if var dictionary = object as? [String: Any] {
            for key in ["mcpServers", "mcp_servers", "mcp", "servers"] where dictionary[key] != nil {
                if var servers = dictionary[key] as? [String: Any], var server = servers[serverName] as? [String: Any] {
                    server["disabled"] = !enabled
                    servers[serverName] = server
                    dictionary[key] = servers
                    return (dictionary, true)
                }
            }
            for (key, value) in dictionary {
                let nested = updateJSONMCPEnabled(object: value, serverName: serverName, enabled: enabled)
                if nested.changed {
                    dictionary[key] = nested.object
                    return (dictionary, true)
                }
            }
            return (dictionary, false)
        }
        if var array = object as? [Any] {
            for index in array.indices {
                let nested = updateJSONMCPEnabled(object: array[index], serverName: serverName, enabled: enabled)
                if nested.changed {
                    array[index] = nested.object
                    return (array, true)
                }
            }
            return (array, false)
        }
        return (object, false)
    }

    private func addJSONMCPServer(object: Any, server: MCPServerItem, targetTool: ToolKind) -> Any {
        var root = (object as? [String: Any]) ?? [:]
        let containerKey = preferredMCPContainerKey(for: targetTool)
        var container = (root[containerKey] as? [String: Any]) ?? [:]
        var serverConfig: [String: Any] = [:]
        if let command = server.command { serverConfig["command"] = command }
        if !server.args.isEmpty { serverConfig["args"] = server.args }
        if !server.envKeys.isEmpty {
            var env: [String: String] = [:]
            for key in server.envKeys { env[key.replacingOccurrences(of: "header:", with: "")] = "<FILL_ME>" }
            serverConfig["env"] = env
        }
        serverConfig["disabled"] = false
        container[server.name] = serverConfig
        root[containerKey] = container
        return root
    }

    private func updateTOMLEnabledState(text: String, serverName: String, enabled: Bool) -> String {
        let lines = text.components(separatedBy: .newlines)
        let targetSections = ["mcp_servers.\(serverName)", "mcpServers.\(serverName)"]
        var result: [String] = []
        var inTarget = false
        var inserted = false

        func isSection(_ line: String) -> String? {
            let trimmed = line.trimmed
            guard trimmed.hasPrefix("["), trimmed.hasSuffix("]") else { return nil }
            return String(trimmed.dropFirst().dropLast()).trimmed
        }

        for line in lines {
            if let section = isSection(line) {
                if inTarget && !inserted {
                    result.append("disabled = \(!enabled)")
                    inserted = true
                }
                inTarget = targetSections.contains(section)
                inserted = false
                result.append(line)
                continue
            }

            if inTarget {
                let normalized = line.trimmed.lowercased()
                if normalized.hasPrefix("disabled") || normalized.hasPrefix("disable") || normalized.hasPrefix("enabled") {
                    if !inserted {
                        result.append("disabled = \(!enabled)")
                        inserted = true
                    }
                    continue
                }
            }
            result.append(line)
        }
        if inTarget && !inserted { result.append("disabled = \(!enabled)") }
        return result.joined(separator: "\n")
    }

    private func preferredMCPContainerKey(for tool: ToolKind) -> String {
        switch tool {
        case .openCode: return "mcp"
        default: return "mcpServers"
        }
    }

    private func backupsDirectory() throws -> URL {
        let appSupport = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = appSupport.appendingPathComponent("AgentHub/Backups", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func restoreOriginalPath(fromBackupFileName fileName: String) -> String {
        fileName.replacingOccurrences(of: "__", with: "/")
    }

    private func resolvePath(_ path: String) -> String {
        if path.hasPrefix("~/") {
            return fileManager.homeDirectoryForCurrentUser.path + String(path.dropFirst(1))
        }
        return path
    }

    private static let backupTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}

enum ConfigEditorError: LocalizedError {
    case fileNotFound(String)
    case mcpNotFound(String)
    case unsupportedTarget(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path): return L("error.fileNotFound", path)
        case .mcpNotFound(let name): return L("error.mcpNotFound", name)
        case .unsupportedTarget(let name): return L("error.unsupportedTarget", name)
        }
    }
}

struct DiffService {
    static func diff(oldLines: [String], newLines: [String]) -> [DiffLine] {
        let maxOld = oldLines.count
        let maxNew = newLines.count
        var table = Array(repeating: Array(repeating: 0, count: maxNew + 1), count: maxOld + 1)
        if maxOld > 0 && maxNew > 0 {
            for i in stride(from: maxOld - 1, through: 0, by: -1) {
                for j in stride(from: maxNew - 1, through: 0, by: -1) {
                    if oldLines[i] == newLines[j] {
                        table[i][j] = table[i + 1][j + 1] + 1
                    } else {
                        table[i][j] = max(table[i + 1][j], table[i][j + 1])
                    }
                }
            }
        }

        var i = 0
        var j = 0
        var result: [DiffLine] = []
        while i < maxOld && j < maxNew {
            if oldLines[i] == newLines[j] {
                result.append(DiffLine(kind: .same, text: "  " + oldLines[i]))
                i += 1
                j += 1
            } else if table[i + 1][j] >= table[i][j + 1] {
                result.append(DiffLine(kind: .removed, text: "- " + oldLines[i]))
                i += 1
            } else {
                result.append(DiffLine(kind: .added, text: "+ " + newLines[j]))
                j += 1
            }
        }
        while i < maxOld { result.append(DiffLine(kind: .removed, text: "- " + oldLines[i])); i += 1 }
        while j < maxNew { result.append(DiffLine(kind: .added, text: "+ " + newLines[j])); j += 1 }
        return result
    }
}
