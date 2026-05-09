import Foundation

struct RiskAnalyzer {
    static func analyze(
        installations: [ToolInstallation],
        configFiles: [ConfigFileItem],
        mcpServers: [MCPServerItem],
        skills: [SkillItem],
        agents: [AgentItem],
        hooks: [HookItem],
        plugins: [PluginItem]
    ) -> [RiskIssue] {
        var issues: [RiskIssue] = []

        issues.append(contentsOf: analyzeMissingTools(installations))
        issues.append(contentsOf: analyzeMCP(mcpServers))
        issues.append(contentsOf: analyzeHooks(hooks))
        issues.append(contentsOf: analyzeMarkdownFiles(skills: skills, agents: agents))
        issues.append(contentsOf: analyzePlugins(plugins))
        issues.append(contentsOf: analyzeDuplicateServers(mcpServers))

        return issues.sorted {
            if $0.severity.weight != $1.severity.weight { return $0.severity.weight > $1.severity.weight }
            return $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }

    private static func analyzeMissingTools(_ installations: [ToolInstallation]) -> [RiskIssue] {
        installations.compactMap { item in
            guard item.status == .missing else { return nil }
            return RiskIssue(
                severity: .info,
                title: L("risk.missingExecutable.title"),
                message: L("risk.missingExecutable.message", item.executableName),
                tool: item.tool,
                sourcePath: nil,
                relatedName: item.executableName
            )
        }
    }

    private static func analyzeMCP(_ servers: [MCPServerItem]) -> [RiskIssue] {
        var issues: [RiskIssue] = []
        for server in servers {
            let text = [server.commandLine, server.rawSnippet, server.envKeys.joined(separator: " ")].joined(separator: "\n")
            let lower = text.lowercased()

            if lower.contains("curl") && (lower.contains("| sh") || lower.contains("| bash")) {
                issues.append(RiskIssue(
                    severity: .high,
                    title: L("risk.mcpPipeScript.title"),
                    message: L("risk.mcpPipeScript.message"),
                    tool: server.tool,
                    sourcePath: server.sourcePath,
                    relatedName: server.name
                ))
            }

            if lower.contains("rm -rf") || lower.contains("chmod 777") || lower.contains("sudo ") {
                issues.append(RiskIssue(
                    severity: .high,
                    title: L("risk.mcpPrivileged.title"),
                    message: L("risk.mcpPrivileged.message"),
                    tool: server.tool,
                    sourcePath: server.sourcePath,
                    relatedName: server.name
                ))
            }

            if lower.contains("npx") || lower.contains("uvx") || lower.contains("bunx") || lower.contains("pipx") {
                issues.append(RiskIssue(
                    severity: .low,
                    title: L("risk.mcpRemoteRunner.title"),
                    message: L("risk.mcpRemoteRunner.message"),
                    tool: server.tool,
                    sourcePath: server.sourcePath,
                    relatedName: server.name
                ))
            }

            let sensitiveKeys = server.envKeys.filter { key in
                let lowerKey = key.lowercased()
                return lowerKey.contains("token") || lowerKey.contains("secret") || lowerKey.contains("key") || lowerKey.contains("password")
            }
            if !sensitiveKeys.isEmpty {
                issues.append(RiskIssue(
                    severity: .medium,
                    title: L("risk.mcpSensitiveEnv.title"),
                    message: L("risk.mcpSensitiveEnv.message", sensitiveKeys.joined(separator: ", ")),
                    tool: server.tool,
                    sourcePath: server.sourcePath,
                    relatedName: server.name
                ))
            }
        }
        return issues
    }

    private static func analyzeHooks(_ hooks: [HookItem]) -> [RiskIssue] {
        hooks.flatMap { hook -> [RiskIssue] in
            var issues: [RiskIssue] = []
            let text = [hook.command, hook.rawSnippet].compactMap { $0 }.joined(separator: "\n").lowercased()
            if text.contains("curl") && (text.contains("| sh") || text.contains("| bash")) {
                issues.append(RiskIssue(
                    severity: .high,
                    title: L("risk.hookPipeScript.title"),
                    message: L("risk.hookPipeScript.message"),
                    tool: hook.tool,
                    sourcePath: hook.sourcePath,
                    relatedName: hook.name
                ))
            }
            if text.contains("rm -rf") || text.contains("sudo ") || text.contains("chmod 777") {
                issues.append(RiskIssue(
                    severity: .high,
                    title: L("risk.hookRiskyCommand.title"),
                    message: L("risk.hookRiskyCommand.message"),
                    tool: hook.tool,
                    sourcePath: hook.sourcePath,
                    relatedName: hook.name
                ))
            }
            return issues
        }
    }

    private static func analyzeMarkdownFiles(skills: [SkillItem], agents: [AgentItem]) -> [RiskIssue] {
        var issues: [RiskIssue] = []

        for skill in skills {
            let text = readText(atAbbreviatedPath: skill.path).lowercased()
            if containsHighRiskInstruction(text) {
                issues.append(RiskIssue(
                    severity: .medium,
                    title: L("risk.skillRiskyKeywords.title"),
                    message: L("risk.skillRiskyKeywords.message"),
                    tool: skill.tool,
                    sourcePath: skill.path,
                    relatedName: skill.name
                ))
            }
        }

        for agent in agents {
            let text = readText(atAbbreviatedPath: agent.path).lowercased()
            if containsHighRiskInstruction(text) {
                issues.append(RiskIssue(
                    severity: .medium,
                    title: L("risk.agentRiskyKeywords.title"),
                    message: L("risk.agentRiskyKeywords.message"),
                    tool: agent.tool,
                    sourcePath: agent.path,
                    relatedName: agent.name
                ))
            }
        }

        return issues
    }

    private static func analyzePlugins(_ plugins: [PluginItem]) -> [RiskIssue] {
        var issues: [RiskIssue] = []
        for plugin in plugins {
            let text = [plugin.name, plugin.summary, plugin.path, plugin.sourcePath].compactMap { $0 }.joined(separator: "\n").lowercased()
            if text.contains("http://") || text.contains("https://") || text.contains("npm") || text.contains("npx") {
                issues.append(RiskIssue(
                    severity: .low,
                    title: L("risk.pluginRemote.title"),
                    message: L("risk.pluginRemote.message"),
                    tool: plugin.tool,
                    sourcePath: plugin.path ?? plugin.sourcePath,
                    relatedName: plugin.name
                ))
            }
            if containsHighRiskInstruction(text) {
                issues.append(RiskIssue(
                    severity: .medium,
                    title: L("risk.pluginRiskyKeywords.title"),
                    message: L("risk.pluginRiskyKeywords.message"),
                    tool: plugin.tool,
                    sourcePath: plugin.path ?? plugin.sourcePath,
                    relatedName: plugin.name
                ))
            }
        }
        return issues
    }

    private static func analyzeDuplicateServers(_ servers: [MCPServerItem]) -> [RiskIssue] {
        let grouped = Dictionary(grouping: servers, by: { $0.name.lowercased() })
        return grouped.compactMap { _, items in
            guard items.count > 1 else { return nil }
            let tools = Set(items.map { $0.tool.rawValue }).sorted().joined(separator: ", ")
            return RiskIssue(
                severity: .low,
                title: L("risk.duplicateMCP.title"),
                message: L("risk.duplicateMCP.message", tools),
                tool: items.first?.tool ?? .unknown,
                sourcePath: items.map { $0.sourcePath }.joined(separator: "\n"),
                relatedName: items.first?.name
            )
        }
    }

    private static func containsHighRiskInstruction(_ text: String) -> Bool {
        let keywords = [
            "curl", "wget", "bash", "zsh", "shell", "sudo", "rm -rf",
            "chmod", "osascript", "launchctl", "keychain", "token", "secret"
        ]
        return keywords.contains { text.contains($0) }
    }

    private static func readText(atAbbreviatedPath path: String) -> String {
        let resolved: String
        if path.hasPrefix("~/") {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            resolved = home + String(path.dropFirst(1))
        } else {
            resolved = path
        }
        return (try? String(contentsOfFile: resolved, encoding: .utf8)) ?? ""
    }
}
