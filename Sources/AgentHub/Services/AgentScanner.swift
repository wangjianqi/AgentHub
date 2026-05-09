import Foundation

final class AgentScanner {
    private let fileManager = FileManager.default
    private let home: URL
    private let registry: PlatformRegistry

    init(home: URL = FileManager.default.homeDirectoryForCurrentUser, registry: PlatformRegistry = .default) {
        self.home = home
        self.registry = registry
    }

    func scan(workspace: URL?) -> AuditSnapshot {
        var installations: [ToolInstallation] = []
        var configFiles: [ConfigFileItem] = []
        var mcpServers: [MCPServerItem] = []
        var skills: [SkillItem] = []
        var agents: [AgentItem] = []
        var hooks: [HookItem] = []
        var plugins: [PluginItem] = []

        for platform in registry.platforms {
            installations.append(scanInstallation(platform))

            for config in platform.resolvedConfigFiles(home: home, workspace: workspace) {
                scanConfigFile(
                    url: config.url,
                    format: config.format,
                    tool: platform.tool,
                    scope: config.scope,
                    configFiles: &configFiles,
                    mcpServers: &mcpServers,
                    hooks: &hooks,
                    plugins: &plugins
                )
            }

            for directory in platform.resolvedSkillDirectories(home: home, workspace: workspace) {
                skills.append(contentsOf: scanSkillDirectory(directory.url, tool: platform.tool, scope: directory.scope))
            }

            for directory in platform.resolvedAgentDirectories(home: home, workspace: workspace) {
                agents.append(contentsOf: scanAgentDirectory(directory.url, tool: platform.tool, scope: directory.scope))
            }

            for directory in platform.resolvedPluginDirectories(home: home, workspace: workspace) {
                plugins.append(contentsOf: scanPluginDirectory(directory.url, tool: platform.tool, scope: directory.scope))
            }
        }

        mcpServers.sort { lhs, rhs in
            if lhs.tool.rawValue != rhs.tool.rawValue { return lhs.tool.rawValue < rhs.tool.rawValue }
            if lhs.scope.rawValue != rhs.scope.rawValue { return lhs.scope.rawValue < rhs.scope.rawValue }
            return lhs.name < rhs.name
        }
        skills.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        agents.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        hooks.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        plugins.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        let risks = RiskAnalyzer.analyze(
            installations: installations,
            configFiles: configFiles,
            mcpServers: mcpServers,
            skills: skills,
            agents: agents,
            hooks: hooks,
            plugins: plugins
        )

        return AuditSnapshot(
            scannedAt: Date(),
            workspacePath: workspace?.path,
            installations: installations,
            configFiles: configFiles,
            mcpServers: mcpServers,
            skills: skills,
            agents: agents,
            hooks: hooks,
            plugins: plugins,
            risks: risks
        )
    }

    private func scanInstallation(_ platform: PlatformDefinition) -> ToolInstallation {
        let executablePath = CommandRunner.which(platform.executableName)
        let version = executablePath.flatMap { CommandRunner.version(command: $0, candidates: platform.versionArgs) }
        return ToolInstallation(
            tool: platform.tool,
            executableName: platform.executableName,
            status: executablePath == nil ? .missing : .installed,
            executablePath: executablePath,
            version: version,
            configPaths: platform.installConfigHints(home: home)
        )
    }

    private func scanConfigFile(
        url: URL,
        format: ConfigFormat,
        tool: ToolKind,
        scope: ConfigScope,
        configFiles: inout [ConfigFileItem],
        mcpServers: inout [MCPServerItem],
        hooks: inout [HookItem],
        plugins: inout [PluginItem]
    ) {
        let exists = fileManager.fileExists(atPath: url.path)
        configFiles.append(configFileItem(for: url, tool: tool, scope: scope, exists: exists))
        guard exists else { return }

        switch format {
        case .json, .jsonc:
            guard let object = JSONScanner.loadObject(from: url, allowJSONC: format == .jsonc) else { return }
            mcpServers.append(contentsOf: JSONScanner.parseMCPServers(object: object, tool: tool, scope: scope, sourcePath: url.abbreviatedPath))
            hooks.append(contentsOf: JSONScanner.parseHooks(object: object, tool: tool, scope: scope, sourcePath: url.abbreviatedPath))
            plugins.append(contentsOf: JSONScanner.parsePlugins(object: object, tool: tool, scope: scope, sourcePath: url.abbreviatedPath))
        case .toml:
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
            mcpServers.append(contentsOf: TOMLScanner.parseMCPServers(text: text, tool: tool, scope: scope, sourcePath: url.abbreviatedPath))
            hooks.append(contentsOf: TOMLScanner.parsePotentialHooks(text: text, tool: tool, scope: scope, sourcePath: url.abbreviatedPath))
        }
    }

    private func scanSkillDirectory(_ directory: URL, tool: ToolKind, scope: ConfigScope) -> [SkillItem] {
        guard fileManager.fileExists(atPath: directory.path) else { return [] }
        guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { return [] }

        var result: [SkillItem] = []
        for case let fileURL as URL in enumerator {
            guard fileURL.lastPathComponent == "SKILL.md" else { continue }
            let parent = fileURL.deletingLastPathComponent()
            let name = parent.lastPathComponent
            let text = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
            let summary = summarizeMarkdown(text) ?? L("summary.notExtracted")
            result.append(SkillItem(name: name, tool: tool, scope: scope, path: fileURL.abbreviatedPath, summary: summary))
        }
        return result
    }

    private func scanAgentDirectory(_ directory: URL, tool: ToolKind, scope: ConfigScope) -> [AgentItem] {
        guard fileManager.fileExists(atPath: directory.path) else { return [] }
        guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { return [] }

        let allowedExtensions = Set(["md", "json", "jsonc", "yaml", "yml", "toml", "txt"])
        var result: [AgentItem] = []
        for case let fileURL as URL in enumerator {
            guard allowedExtensions.contains(fileURL.pathExtension.lowercased()) else { continue }
            let name = fileURL.deletingPathExtension().lastPathComponent
            let text = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
            let summary = summarizeMarkdown(text) ?? text.firstNonEmptyLine(maxLength: 160) ?? L("summary.notExtracted")
            result.append(AgentItem(name: name, tool: tool, scope: scope, path: fileURL.abbreviatedPath, summary: summary))
        }
        return result
    }

    private func scanPluginDirectory(_ directory: URL, tool: ToolKind, scope: ConfigScope) -> [PluginItem] {
        guard fileManager.fileExists(atPath: directory.path) else { return [] }
        guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey], options: [.skipsHiddenFiles]) else { return [] }

        let allowedExtensions = Set(["js", "ts", "mjs", "cjs", "json", "jsonc"])
        var result: [PluginItem] = []
        var seen: Set<String> = []

        for case let fileURL as URL in enumerator {
            guard allowedExtensions.contains(fileURL.pathExtension.lowercased()) else { continue }
            let name = fileURL.deletingPathExtension().lastPathComponent
            let key = fileURL.path
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            let text = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
            let summary = text.firstNonEmptyLine(maxLength: 160) ?? L("summary.localPluginFile")
            result.append(PluginItem(name: name, tool: tool, scope: scope, path: fileURL.abbreviatedPath, sourcePath: nil, summary: summary))
        }
        return result
    }

    private func configFileItem(for url: URL, tool: ToolKind, scope: ConfigScope, exists: Bool) -> ConfigFileItem {
        var bytes: Int?
        var summary = exists ? L("summary.configFound") : L("summary.configMissing")
        if exists, let attributes = try? fileManager.attributesOfItem(atPath: url.path) {
            bytes = attributes[.size] as? Int
            if let bytes { summary = L("summary.configFoundWithSize", ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)) }
        }
        return ConfigFileItem(tool: tool, scope: scope, path: url.abbreviatedPath, exists: exists, bytes: bytes, summary: summary)
    }

    private func summarizeMarkdown(_ text: String) -> String? {
        let lines = text.components(separatedBy: .newlines).map { $0.trimmed }
        for line in lines {
            guard !line.isEmpty else { continue }
            if line == "---" { continue }
            if line.hasPrefix("#") {
                return line.replacingOccurrences(of: "#", with: "").trimmed.nilIfEmpty
            }
            if line.contains(":") && line.count < 120 {
                continue
            }
            return line.count > 180 ? String(line.prefix(180)) + "…" : line
        }
        return nil
    }
}
