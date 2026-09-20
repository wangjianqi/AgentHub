import Foundation

enum ConfigFormat {
    case json
    case jsonc
    case toml
    case yaml
}

enum PathRoot {
    case home
    case workspace
    case absolute
    case environment(variable: String, fallbackHomePath: String)

    var isWorkspace: Bool {
        if case .workspace = self { return true }
        return false
    }
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
    var allowFlatMarkdownSkills: Bool = false
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
    var executableAliases: [String] = []
    var applicationNames: [String] = []
    var installationEvidenceDirectories: [DirectorySpec] = []
    var cliDetectionEnabled: Bool = true

    var executableNames: [String] {
        guard cliDetectionEnabled else { return [] }
        return [executableName] + executableAliases
    }

    func resolvedConfigFiles(home: URL, workspace: URL?) -> [(url: URL, scope: ConfigScope, format: ConfigFormat)] {
        configFiles.compactMap { spec in
            guard let url = resolve(root: spec.root, path: spec.path, home: home, workspace: workspace) else { return nil }
            return (url, spec.scope, spec.format)
        }
    }

    func resolvedSkillDirectories(home: URL, workspace: URL?) -> [(url: URL, scope: ConfigScope, allowFlatMarkdownSkills: Bool)] {
        skillDirectories.compactMap { spec in
            guard let url = resolve(root: spec.root, path: spec.path, home: home, workspace: workspace) else { return nil }
            return (url, spec.scope, spec.allowFlatMarkdownSkills)
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
            guard !spec.root.isWorkspace else { return nil }
            return resolve(root: spec.root, path: spec.path, home: home, workspace: nil)?.abbreviatedPath
        }
        return Array(Set(userAndSystem + extraConfigPathHints)).sorted()
    }

    var primaryUserConfig: ConfigPathSpec? {
        configFiles.first { $0.scope == .user }
    }

    func resolve(spec: ConfigPathSpec, home: URL, workspace: URL?) -> URL? {
        resolve(root: spec.root, path: spec.path, home: home, workspace: workspace)
    }

    func resolve(root: PathRoot, path: String, home: URL, workspace: URL?) -> URL? {
        let baseURL: URL
        switch root {
        case .home:
            baseURL = home
        case .workspace:
            guard let workspace else { return nil }
            baseURL = workspace
        case .absolute:
            return URL(fileURLWithPath: path)
        case .environment(let variable, let fallbackHomePath):
            if let raw = ProcessInfo.processInfo.environment[variable]?.trimmed, !raw.isEmpty {
                let expanded = NSString(string: raw).expandingTildeInPath
                if expanded.hasPrefix("/") {
                    baseURL = URL(fileURLWithPath: expanded, isDirectory: true)
                } else {
                    let anchor = workspace ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
                    baseURL = anchor.appendingPathComponent(expanded, isDirectory: true)
                }
            } else {
                baseURL = home.appendingPathComponent(fallbackHomePath, isDirectory: true)
            }
        }
        guard !path.isEmpty else { return baseURL }
        return baseURL.appendingPathComponent(path)
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
            extraConfigPathHints: ["~/.claude"],
            applicationNames: ["Claude.app"]
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
            skillDirectories: [
                DirectorySpec(root: .home, path: ".agents/skills", scope: .user),
                DirectorySpec(root: .workspace, path: ".agents/skills", scope: .project),
                DirectorySpec(root: .absolute, path: "/etc/codex/skills", scope: .system)
            ],
            agentDirectories: [],
            pluginDirectories: [],
            extraConfigPathHints: ["~/.codex", "~/.agents/skills"],
            applicationNames: ["Codex.app"]
        ),

        // MARK: - China / APAC coding agents

        PlatformDefinition(
            tool: .codeBuddy,
            executableName: "codebuddy",
            versionArgs: [["--version"], ["-v"]],
            configFiles: [
                ConfigPathSpec(root: .environment(variable: "CODEBUDDY_CONFIG_DIR", fallbackHomePath: ".codebuddy"), path: ".mcp.json", scope: .user, format: .jsonc),
                ConfigPathSpec(root: .environment(variable: "CODEBUDDY_CONFIG_DIR", fallbackHomePath: ".codebuddy"), path: "mcp.json", scope: .user, format: .jsonc),
                ConfigPathSpec(root: .home, path: ".codebuddy.json", scope: .user, format: .jsonc),
                ConfigPathSpec(root: .environment(variable: "CODEBUDDY_CONFIG_DIR", fallbackHomePath: ".codebuddy"), path: "settings.json", scope: .user, format: .jsonc),
                ConfigPathSpec(root: .environment(variable: "CODEBUDDY_CONFIG_DIR", fallbackHomePath: ".codebuddy"), path: "settings.local.json", scope: .user, format: .jsonc),
                ConfigPathSpec(root: .workspace, path: ".mcp.json", scope: .project, format: .jsonc),
                ConfigPathSpec(root: .workspace, path: "mcp.json", scope: .project, format: .jsonc),
                ConfigPathSpec(root: .workspace, path: ".codebuddy/settings.json", scope: .project, format: .jsonc),
                ConfigPathSpec(root: .workspace, path: ".codebuddy/settings.local.json", scope: .project, format: .jsonc)
            ],
            skillDirectories: [
                DirectorySpec(root: .environment(variable: "CODEBUDDY_CONFIG_DIR", fallbackHomePath: ".codebuddy"), path: "skills", scope: .user),
                DirectorySpec(root: .workspace, path: ".codebuddy/skills", scope: .project)
            ],
            agentDirectories: [
                DirectorySpec(root: .environment(variable: "CODEBUDDY_CONFIG_DIR", fallbackHomePath: ".codebuddy"), path: "agents", scope: .user),
                DirectorySpec(root: .workspace, path: ".codebuddy/agents", scope: .project)
            ],
            pluginDirectories: [],
            extraConfigPathHints: ["~/.codebuddy", ".codebuddy"],
            executableAliases: ["cbc"],
            applicationNames: ["CodeBuddy.app", "CodeBuddy IDE.app"]
        ),
        PlatformDefinition(
            tool: .qoder,
            executableName: "qoder",
            versionArgs: [["--version"], ["-v"]],
            configFiles: [
                ConfigPathSpec(root: .environment(variable: "QODER_CONFIG_DIR", fallbackHomePath: ".qoder"), path: "settings.json", scope: .user, format: .jsonc),
                ConfigPathSpec(root: .workspace, path: ".qoder/settings.json", scope: .project, format: .jsonc),
                ConfigPathSpec(root: .workspace, path: ".qoder/settings.local.json", scope: .project, format: .jsonc),
                ConfigPathSpec(root: .workspace, path: ".mcp.json", scope: .project, format: .jsonc)
            ],
            skillDirectories: [
                DirectorySpec(root: .environment(variable: "QODER_CONFIG_DIR", fallbackHomePath: ".qoder"), path: "skills", scope: .user),
                DirectorySpec(root: .workspace, path: ".qoder/skills", scope: .project)
            ],
            agentDirectories: [
                DirectorySpec(root: .environment(variable: "QODER_CONFIG_DIR", fallbackHomePath: ".qoder"), path: "agents", scope: .user),
                DirectorySpec(root: .workspace, path: ".qoder/agents", scope: .project)
            ],
            pluginDirectories: [],
            extraConfigPathHints: ["~/.qoder", ".qoder"],
            applicationNames: ["Qoder.app"]
        ),
        PlatformDefinition(
            tool: .qoderCN,
            executableName: "qodercn",
            versionArgs: [["--version"], ["-v"]],
            configFiles: [
                ConfigPathSpec(root: .environment(variable: "QODERCN_CONFIG_DIR", fallbackHomePath: ".qoder-cn"), path: "settings.json", scope: .user, format: .jsonc),
                ConfigPathSpec(root: .workspace, path: ".qoder/settings.json", scope: .project, format: .jsonc),
                ConfigPathSpec(root: .workspace, path: ".qoder/settings.local.json", scope: .project, format: .jsonc),
                ConfigPathSpec(root: .workspace, path: ".mcp.json", scope: .project, format: .jsonc)
            ],
            skillDirectories: [
                DirectorySpec(root: .environment(variable: "QODERCN_CONFIG_DIR", fallbackHomePath: ".qoder-cn"), path: "skills", scope: .user),
                DirectorySpec(root: .home, path: ".lingma/skills", scope: .user),
                DirectorySpec(root: .workspace, path: ".qoder/skills", scope: .project),
                DirectorySpec(root: .workspace, path: ".lingma/skills", scope: .project)
            ],
            agentDirectories: [
                DirectorySpec(root: .environment(variable: "QODERCN_CONFIG_DIR", fallbackHomePath: ".qoder-cn"), path: "agents", scope: .user),
                DirectorySpec(root: .workspace, path: ".qoder/agents", scope: .project)
            ],
            pluginDirectories: [],
            extraConfigPathHints: ["~/.qoder-cn", "~/.lingma", ".qoder", ".lingma"],
            executableAliases: ["qoderclicn"],
            applicationNames: ["Qoder CN.app", "通义灵码.app", "Lingma.app"]
        ),
        PlatformDefinition(
            tool: .trae,
            executableName: "traecli",
            versionArgs: [["--version"], ["-v"]],
            configFiles: [
                ConfigPathSpec(root: .home, path: ".trae/traecli.toml", scope: .user, format: .toml),
                ConfigPathSpec(root: .home, path: "Library/Application Support/trae_cli/trae_cli.yaml", scope: .user, format: .yaml),
                ConfigPathSpec(root: .home, path: ".trae-cn/hooks.json", scope: .user, format: .jsonc),
                ConfigPathSpec(root: .workspace, path: ".trae/mcp.json", scope: .project, format: .jsonc),
                ConfigPathSpec(root: .workspace, path: ".trae/hooks.json", scope: .project, format: .jsonc)
            ],
            skillDirectories: [
                DirectorySpec(root: .home, path: ".traecli/skills", scope: .user),
                DirectorySpec(root: .home, path: ".trae-cn/skills", scope: .user),
                DirectorySpec(root: .workspace, path: ".traecli/skills", scope: .project),
                DirectorySpec(root: .workspace, path: ".trae/skills", scope: .project)
            ],
            agentDirectories: [
                DirectorySpec(root: .workspace, path: ".traecli/agents", scope: .project)
            ],
            pluginDirectories: [],
            extraConfigPathHints: ["~/.trae", "~/.traecli", "~/.trae-cn", "~/Library/Application Support/trae_cli", ".trae"],
            applicationNames: ["TRAE.app", "TraeCode.app", "TRAE CN.app", "TraeCode CN.app", "TRAE SOLO.app", "TRAE Work.app", "TraeWork.app", "TRAE SOLO CN.app", "TRAE Work CN.app", "TraeWork CN.app"]
        ),
        PlatformDefinition(
            tool: .qwenCode,
            executableName: "qwen",
            versionArgs: [["--version"], ["-v"]],
            configFiles: [
                ConfigPathSpec(root: .environment(variable: "QWEN_HOME", fallbackHomePath: ".qwen"), path: "settings.json", scope: .user, format: .jsonc),
                ConfigPathSpec(root: .workspace, path: ".qwen/settings.json", scope: .project, format: .jsonc),
                ConfigPathSpec(root: .absolute, path: "/Library/Application Support/QwenCode/system-defaults.json", scope: .system, format: .jsonc),
                ConfigPathSpec(root: .absolute, path: "/Library/Application Support/QwenCode/settings.json", scope: .system, format: .jsonc)
            ],
            skillDirectories: [
                DirectorySpec(root: .environment(variable: "QWEN_HOME", fallbackHomePath: ".qwen"), path: "skills", scope: .user),
                DirectorySpec(root: .workspace, path: ".qwen/skills", scope: .project)
            ],
            agentDirectories: [],
            pluginDirectories: [],
            extraConfigPathHints: ["~/.qwen", ".qwen"]
        ),
        PlatformDefinition(
            tool: .kimiCode,
            executableName: "kimi",
            versionArgs: [["--version"], ["-V"]],
            configFiles: [
                ConfigPathSpec(root: .environment(variable: "KIMI_CODE_HOME", fallbackHomePath: ".kimi-code"), path: "mcp.json", scope: .user, format: .jsonc),
                ConfigPathSpec(root: .environment(variable: "KIMI_CODE_HOME", fallbackHomePath: ".kimi-code"), path: "config.toml", scope: .user, format: .toml),
                ConfigPathSpec(root: .environment(variable: "KIMI_CODE_HOME", fallbackHomePath: ".kimi-code"), path: "plugins/installed.json", scope: .user, format: .jsonc),
                ConfigPathSpec(root: .workspace, path: ".kimi-code/mcp.json", scope: .project, format: .jsonc)
            ],
            skillDirectories: [
                DirectorySpec(root: .environment(variable: "KIMI_CODE_HOME", fallbackHomePath: ".kimi-code"), path: "skills", scope: .user, allowFlatMarkdownSkills: true),
                DirectorySpec(root: .home, path: ".agents/skills", scope: .user, allowFlatMarkdownSkills: true),
                DirectorySpec(root: .workspace, path: ".kimi-code/skills", scope: .project, allowFlatMarkdownSkills: true),
                DirectorySpec(root: .workspace, path: ".agents/skills", scope: .project, allowFlatMarkdownSkills: true)
            ],
            agentDirectories: [
                DirectorySpec(root: .environment(variable: "KIMI_CODE_HOME", fallbackHomePath: ".kimi-code"), path: "agents", scope: .user),
                DirectorySpec(root: .home, path: ".agents/agents", scope: .user),
                DirectorySpec(root: .workspace, path: ".kimi-code/agents", scope: .project),
                DirectorySpec(root: .workspace, path: ".agents/agents", scope: .project)
            ],
            pluginDirectories: [],
            extraConfigPathHints: ["~/.kimi-code", "~/.agents/skills", "~/.agents/agents", ".kimi-code"]
        ),
        PlatformDefinition(
            tool: .baiduComate,
            executableName: "comate",
            versionArgs: [["--version"], ["-v"]],
            configFiles: [
                ConfigPathSpec(root: .workspace, path: ".comate/mcp.json", scope: .project, format: .jsonc)
            ],
            skillDirectories: [
                DirectorySpec(root: .home, path: ".comate/skills", scope: .user),
                DirectorySpec(root: .workspace, path: ".comate/skills", scope: .project),
                DirectorySpec(root: .workspace, path: ".agents/skills", scope: .project)
            ],
            agentDirectories: [],
            pluginDirectories: [],
            extraConfigPathHints: ["~/.comate/skills", ".comate", ".comate/mcp.json", ".comate/rules", ".agents/skills"],
            applicationNames: ["Comate.app", "Comate AI IDE.app", "文心快码.app"],
            installationEvidenceDirectories: [
                DirectorySpec(root: .home, path: ".comate/skills", scope: .user)
            ],
            // Baidu's latest public 4.0 notes still describe Comate CLI as under development.
            // Detect the standalone macOS app and Skills/config artifacts without guessing a CLI binary.
            cliDetectionEnabled: false
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

    var migrationTargets: [ToolKind] {
        platforms.map(\.tool)
    }
}
