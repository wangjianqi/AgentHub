import Foundation

struct MCPHealthChecker {
    static func check(server: MCPServerItem) -> MCPCheckResult {
        guard let command = server.command?.trimmed, !command.isEmpty else {
            return MCPCheckResult(server: server, status: .failed, title: L("health.missingCommand.title"), detail: L("health.missingCommand.detail"))
        }

        if command.hasPrefix("http://") || command.hasPrefix("https://") {
            return MCPCheckResult(server: server, status: .warning, title: L("health.remoteMCP.title"), detail: L("health.remoteMCP.detail", command))
        }

        let resolved: String?
        if command.hasPrefix("/") {
            resolved = FileManager.default.fileExists(atPath: command) ? command : nil
        } else {
            resolved = CommandRunner.which(command)
        }

        guard let resolved else {
            return MCPCheckResult(server: server, status: .failed, title: L("health.commandUnavailable.title"), detail: L("health.commandUnavailable.detail", command))
        }

        let riskyArgs = server.args.joined(separator: " ").lowercased()
        if riskyArgs.contains("curl") || riskyArgs.contains("bash") || riskyArgs.contains("sudo") || riskyArgs.contains("rm -rf") {
            return MCPCheckResult(server: server, status: .warning, title: L("health.riskyArgs.title"), detail: L("health.riskyArgs.detail", resolved))
        }

        if ["npx", "uvx", "bunx", "pnpm", "npm", "node", "python", "python3", "uv"].contains(command) {
            return MCPCheckResult(server: server, status: .warning, title: L("health.runnerAvailable.title"), detail: L("health.runnerAvailable.detail", command, resolved))
        }

        return MCPCheckResult(server: server, status: .ok, title: L("health.commandExists.title"), detail: L("health.commandExists.detail", resolved))
    }
}
