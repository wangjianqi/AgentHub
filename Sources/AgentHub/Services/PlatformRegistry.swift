import Foundation

enum ConfigFormat {
    case json
    case jsonc
    case toml
}

enum PathRoot {
    case home
    case workspace
    case absolute
}

struct ConfigPathSpec {
    let root: PathRoot
    let path: String
    let scope: ConfigScope
    let format: ConfigFormat
}

struct DirectorySpec {
    let root: PathRoot
    let path: String
    let scope: ConfigScope
}

struct PlatformDefinition: Identifiable {
    var id: ToolKind { tool }
    let tool: ToolKind
    let executableName: String
    let versionArgs: [[String]]
    let configFiles: [ConfigPathSpec]
    let skillDirectories: [DirectorySpec]
    let agentDirectories: [DirectorySpec]
    let pluginDirectories: [DirectorySpec]
    let extraConfigPathHints: [String]

    func resolvedConfigFiles(home: URL, workspace: URL?) -> [(url: URL, scope: ConfigScope, format: ConfigFormat)] {
        configFiles.compactMap { spec in
            guard let url = resolve(root: spec.root, path: spec.path, home: home, workspace: workspace) else { return nil }
            return (url, spec.scope, spec.format)
        }
    }

    func resolvedSkillDirectories(home: URL, workspace: URL?) -> [(url: URL, scope: ConfigScope)] {
        skillDirectories.compactMap { spec in
            guard let url = resolve(root: spec.root, path: spec.path, home: home, workspace: workspace) else { return nil }
            return (url, spec.scope)
        }
    }

    func resolvedAgentDirectories(home: URL, workspace: URL?) -> [(url: URL, scope: ConfigScope)] {
        agentDirectories.compactMap { spec in
            guard let url = resolve(root: spec.root, path: spec.path, home: home, workspace: workspace) else { return nil }
            return (url, spec.scope)
        }
    }

    func resolvedPluginDirectories(home: URL, workspace: URL?) -> [(url: URL, scope: ConfigScope)] {
        pluginDirectories.compactMap { spec in
            guard let url = resolve(root: spec.root, path: spec.path, home: home, workspace: workspace) else { return nil }
            return (url, spec.scope)
        }
    }

    func installConfigHints(home: URL) -> [String] {
        let userAndSystem = configFiles.compactMap { spec -> String? in
            guard spec.root != .workspace else { return nil }
            return resolve(root: spec.root, path: spec.path, home: home, workspace: nil)?.abbreviatedPath
        }
        return userAndSystem + extraConfigPathHints
    }

    private func resolve(root: PathRoot, path: String, home: URL, workspace: URL?) -> URL? {
        switch root {
        case .home:
            return home.appendingPathComponent(path)
        case .workspace:
            guard let workspace else { return nil }
            return workspace.appendingPathComponent(path)
        case .absolute:
            return URL(fileURLWithPath: path)
        }
    }
}

struct PlatformRegistry {
    let platforms: [PlatformDefinition]

    static let `default` = PlatformRegistry(platforms: [
        PlatformDefinition(
            tool: .claudeCode,
            executableName: "claude",
            versionArgs: [["--version"], ["-v"]],
            configFiles: [
                ConfigPathSpec(root: .home, path: ".claude.json", scope: .user, format: .jsonc),
                ConfigPathSpec(root: .home, path: ".claude/settings.json", scope: .user, format: .jsonc),
                ConfigPathSpec(root: .workspace, path: ".mcp.json", scope: .project, format: .jsonc),
                ConfigPathSpec(root: .workspace, path: ".claude/settings.json", scope: .project, format: .jsonc),
                ConfigPathSpec(root: .workspace, path: ".claude/settings.local.json", scope: .project, format: .jsonc)
            ],
            skillDirectories: [
                DirectorySpec(root: .home, path: ".claude/skills", scope: .user),
                DirectorySpec(root: .workspace, path: ".claude/skills", scope: .project)
            ],
            agentDirectories: [
                DirectorySpec(root: .home, path: ".claude/agents", scope: .user),
                DirectorySpec(root: .workspace, path: ".claude/agents", scope: .project)
            ],
            pluginDirectories: [],
            extraConfigPathHints: ["~/.claude"]
        ),
        PlatformDefinition(
            tool: .codex,
            executableName: "codex",
            versionArgs: [["--version"], ["-V"]],
            configFiles: [
                ConfigPathSpec(root: .home, path: ".codex/config.toml", scope: .user, format: .toml),
                ConfigPathSpec(root: .absolute, path: "/etc/codex/config.toml", scope: .system, format: .toml),
                ConfigPathSpec(root: .workspace, path: ".codex/config.toml", scope: .project, format: .toml)
            ],
            skillDirectories: [],
            agentDirectories: [],
            pluginDirectories: [],
            extraConfigPathHints: ["~/.codex"]
        ),
        PlatformDefinition(
            tool: .openClaw,
            executableName: "openclaw",
            versionArgs: [["--version"], ["-v"]],
            configFiles: [
                ConfigPathSpec(root: .home, path: ".openclaw/openclaw.json", scope: .user, format: .jsonc)
            ],
            skillDirectories: [
                DirectorySpec(root: .home, path: ".openclaw/skills", scope: .user),
                DirectorySpec(root: .home, path: ".agents/skills", scope: .user),
                DirectorySpec(root: .workspace, path: ".agents/skills", scope: .project),
                DirectorySpec(root: .workspace, path: "skills", scope: .project)
            ],
            agentDirectories: [],
            pluginDirectories: [],
            extraConfigPathHints: ["~/.openclaw"]
        ),
        PlatformDefinition(
            tool: .openCode,
            executableName: "opencode",
            versionArgs: [["--version"], ["-v"]],
            configFiles: [
                ConfigPathSpec(root: .home, path: ".config/opencode/opencode.json", scope: .user, format: .jsonc),
                ConfigPathSpec(root: .home, path: ".config/opencode/tui.json", scope: .user, format: .jsonc),
                ConfigPathSpec(root: .workspace, path: "opencode.json", scope: .project, format: .jsonc),
                ConfigPathSpec(root: .workspace, path: "tui.json", scope: .project, format: .jsonc)
            ],
            skillDirectories: [],
            agentDirectories: [
                DirectorySpec(root: .home, path: ".config/opencode/agent", scope: .user),
                DirectorySpec(root: .home, path: ".config/opencode/agents", scope: .user),
                DirectorySpec(root: .workspace, path: ".opencode/agent", scope: .project),
                DirectorySpec(root: .workspace, path: ".opencode/agents", scope: .project)
            ],
            pluginDirectories: [
                DirectorySpec(root: .home, path: ".config/opencode/plugins", scope: .user),
                DirectorySpec(root: .workspace, path: ".opencode/plugins", scope: .project)
            ],
            extraConfigPathHints: ["~/.config/opencode"]
        )
    ])
}

extension PlatformRegistry {
    func platform(for tool: ToolKind) -> PlatformDefinition? {
        platforms.first { $0.tool == tool }
    }
}

extension PlatformDefinition {
    var primaryUserConfig: ConfigPathSpec? {
        configFiles.first { $0.scope == .user }
    }

    func resolve(spec: ConfigPathSpec, home: URL, workspace: URL?) -> URL? {
        switch spec.root {
        case .home:
            return home.appendingPathComponent(spec.path)
        case .workspace:
            guard let workspace else { return nil }
            return workspace.appendingPathComponent(spec.path)
        case .absolute:
            return URL(fileURLWithPath: spec.path)
        }
    }
}
