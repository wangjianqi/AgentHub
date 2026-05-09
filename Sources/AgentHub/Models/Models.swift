import Foundation

enum ToolKind: String, CaseIterable, Identifiable, Codable {
    case claudeCode = "Claude Code"
    case codex = "Codex"
    case openClaw = "OpenClaw"
    case openCode = "OpenCode"
    case unknown = "Unknown"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .claudeCode: return "sparkles"
        case .codex: return "terminal"
        case .openClaw: return "pawprint"
        case .openCode: return "curlybraces.square"
        case .unknown: return "questionmark.circle"
        }
    }
}

enum ConfigScope: String, Codable, CaseIterable, Identifiable {
    case user = "user"
    case project = "project"
    case system = "system"
    case discovered = "discovered"

    var id: String { rawValue }
}

enum InstallationStatus: String, Codable {
    case installed = "installed"
    case missing = "missing"
    case unknown = "unknown"
}

struct ToolInstallation: Identifiable, Codable, Hashable {
    var id: ToolKind { tool }
    let tool: ToolKind
    let executableName: String
    let status: InstallationStatus
    let executablePath: String?
    let version: String?
    let configPaths: [String]
}

struct ConfigFileItem: Identifiable, Codable, Hashable {
    let id: UUID
    let tool: ToolKind
    let scope: ConfigScope
    let path: String
    let exists: Bool
    let bytes: Int?
    let summary: String

    init(tool: ToolKind, scope: ConfigScope, path: String, exists: Bool, bytes: Int?, summary: String) {
        self.id = UUID()
        self.tool = tool
        self.scope = scope
        self.path = path
        self.exists = exists
        self.bytes = bytes
        self.summary = summary
    }
}

struct MCPServerItem: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let tool: ToolKind
    let scope: ConfigScope
    let sourcePath: String
    let command: String?
    let args: [String]
    let envKeys: [String]
    let rawSnippet: String
    let isEnabled: Bool
    let disabledReason: String?

    init(
        name: String,
        tool: ToolKind,
        scope: ConfigScope,
        sourcePath: String,
        command: String?,
        args: [String],
        envKeys: [String],
        rawSnippet: String,
        isEnabled: Bool = true,
        disabledReason: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.tool = tool
        self.scope = scope
        self.sourcePath = sourcePath
        self.command = command
        self.args = args
        self.envKeys = envKeys
        self.rawSnippet = rawSnippet
        self.isEnabled = isEnabled
        self.disabledReason = disabledReason
    }

    var commandLine: String {
        ([command].compactMap { $0 } + args).joined(separator: " ")
    }

    var stableKey: String {
        "\(tool.rawValue)|\(scope.rawValue)|\(sourcePath)|\(name)"
    }
}

struct SkillItem: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let tool: ToolKind
    let scope: ConfigScope
    let path: String
    let summary: String

    init(name: String, tool: ToolKind, scope: ConfigScope, path: String, summary: String) {
        self.id = UUID()
        self.name = name
        self.tool = tool
        self.scope = scope
        self.path = path
        self.summary = summary
    }
}

struct AgentItem: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let tool: ToolKind
    let scope: ConfigScope
    let path: String
    let summary: String

    init(name: String, tool: ToolKind, scope: ConfigScope, path: String, summary: String) {
        self.id = UUID()
        self.name = name
        self.tool = tool
        self.scope = scope
        self.path = path
        self.summary = summary
    }
}

struct HookItem: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let tool: ToolKind
    let scope: ConfigScope
    let sourcePath: String
    let event: String?
    let command: String?
    let rawSnippet: String

    init(name: String, tool: ToolKind, scope: ConfigScope, sourcePath: String, event: String?, command: String?, rawSnippet: String) {
        self.id = UUID()
        self.name = name
        self.tool = tool
        self.scope = scope
        self.sourcePath = sourcePath
        self.event = event
        self.command = command
        self.rawSnippet = rawSnippet
    }
}

struct PluginItem: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let tool: ToolKind
    let scope: ConfigScope
    let path: String?
    let sourcePath: String?
    let summary: String

    init(name: String, tool: ToolKind, scope: ConfigScope, path: String?, sourcePath: String?, summary: String) {
        self.id = UUID()
        self.name = name
        self.tool = tool
        self.scope = scope
        self.path = path
        self.sourcePath = sourcePath
        self.summary = summary
    }
}

enum RiskSeverity: String, Codable, CaseIterable, Identifiable {
    case high = "high"
    case medium = "medium"
    case low = "low"
    case info = "info"

    var id: String { rawValue }

    var weight: Int {
        switch self {
        case .high: return 4
        case .medium: return 3
        case .low: return 2
        case .info: return 1
        }
    }
}

struct RiskIssue: Identifiable, Codable, Hashable {
    let id: UUID
    let severity: RiskSeverity
    let title: String
    let message: String
    let tool: ToolKind
    let sourcePath: String?
    let relatedName: String?

    init(severity: RiskSeverity, title: String, message: String, tool: ToolKind, sourcePath: String?, relatedName: String?) {
        self.id = UUID()
        self.severity = severity
        self.title = title
        self.message = message
        self.tool = tool
        self.sourcePath = sourcePath
        self.relatedName = relatedName
    }
}

struct AuditSnapshot: Codable {
    let scannedAt: Date
    let workspacePath: String?
    let installations: [ToolInstallation]
    let configFiles: [ConfigFileItem]
    let mcpServers: [MCPServerItem]
    let skills: [SkillItem]
    let agents: [AgentItem]
    let hooks: [HookItem]
    let plugins: [PluginItem]
    let risks: [RiskIssue]

    static let empty = AuditSnapshot(
        scannedAt: Date(),
        workspacePath: nil,
        installations: [],
        configFiles: [],
        mcpServers: [],
        skills: [],
        agents: [],
        hooks: [],
        plugins: [],
        risks: []
    )
}

struct ConfigEditResult: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let message: String
    let originalPath: String
    let backupPath: String?
    let changed: Bool
}

enum MCPCheckStatus: String, Codable, CaseIterable, Identifiable {
    case ok = "ok"
    case warning = "warning"
    case failed = "failed"
    case skipped = "skipped"

    var id: String { rawValue }
}

struct MCPCheckResult: Identifiable, Codable, Hashable {
    let id: UUID
    let serverStableKey: String
    let serverName: String
    let tool: ToolKind
    let status: MCPCheckStatus
    let title: String
    let detail: String
    let checkedAt: Date

    init(server: MCPServerItem, status: MCPCheckStatus, title: String, detail: String) {
        self.id = UUID()
        self.serverStableKey = server.stableKey
        self.serverName = server.name
        self.tool = server.tool
        self.status = status
        self.title = title
        self.detail = detail
        self.checkedAt = Date()
    }
}

struct BackupItem: Identifiable, Hashable {
    let id = UUID()
    let originalPath: String
    let backupPath: String
    let createdAt: Date
    let bytes: Int64
}

struct DiffLine: Identifiable, Hashable {
    enum Kind: String {
        case same
        case added
        case removed
    }

    let id = UUID()
    let kind: Kind
    let text: String
}

struct MCPProfileServer: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let tool: ToolKind
    let scope: ConfigScope
    let sourcePath: String
    let commandLine: String
    let stableKey: String

    init(server: MCPServerItem) {
        self.id = UUID()
        self.name = server.name
        self.tool = server.tool
        self.scope = server.scope
        self.sourcePath = server.sourcePath
        self.commandLine = server.commandLine
        self.stableKey = server.stableKey
    }
}

struct MCPProfile: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var notes: String
    var createdAt: Date
    var updatedAt: Date
    var servers: [MCPProfileServer]

    init(name: String, notes: String = "", servers: [MCPProfileServer] = []) {
        self.id = UUID()
        self.name = name
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
        self.servers = servers
    }
}
