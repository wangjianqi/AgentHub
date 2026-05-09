import Foundation

struct TOMLScanner {
    static func parseMCPServers(text: String, tool: ToolKind, scope: ConfigScope, sourcePath: String) -> [MCPServerItem] {
        var sections: [String: [String: String]] = [:]
        var currentSection: String?

        for rawLine in text.components(separatedBy: .newlines) {
            let line = stripComment(rawLine).trimmed
            guard !line.isEmpty else { continue }

            if line.hasPrefix("["), line.hasSuffix("]") {
                currentSection = String(line.dropFirst().dropLast()).trimmed
                sections[currentSection!, default: [:]] = [:]
                continue
            }

            guard let currentSection, let equalRange = line.range(of: "=") else { continue }
            let key = String(line[..<equalRange.lowerBound]).trimmed
            let value = String(line[equalRange.upperBound...]).trimmed
            sections[currentSection, default: [:]][key] = value
        }

        let serverNames = Set(sections.keys.compactMap { section -> String? in
            if section.hasPrefix("mcp_servers.") {
                let suffix = String(section.dropFirst("mcp_servers.".count))
                return suffix.components(separatedBy: ".").first
            }
            if section.hasPrefix("mcpServers.") {
                let suffix = String(section.dropFirst("mcpServers.".count))
                return suffix.components(separatedBy: ".").first
            }
            return nil
        })

        return serverNames.sorted().map { name in
            let baseSection = sections["mcp_servers.\(name)"] ?? sections["mcpServers.\(name)"] ?? [:]
            let envSection = sections["mcp_servers.\(name).env"] ?? sections["mcpServers.\(name).env"] ?? [:]
            let command = parseString(baseSection["command"])
            let args = parseArray(baseSection["args"])
            let envKeys = Array(envSection.keys).sorted()
            let raw = rawSectionSnippet(text: text, serverName: name)
            let disabled = parseBool(baseSection["disabled"]) == true || parseBool(baseSection["disable"]) == true || parseBool(baseSection["enabled"]) == false
            let reason: String? = disabled ? L("summary.disabledEnabledField") : nil
            return MCPServerItem(
                name: name,
                tool: tool,
                scope: scope,
                sourcePath: sourcePath,
                command: command,
                args: args,
                envKeys: envKeys,
                rawSnippet: raw,
                isEnabled: !disabled,
                disabledReason: reason
            )
        }
    }

    static func parsePotentialHooks(text: String, tool: ToolKind, scope: ConfigScope, sourcePath: String) -> [HookItem] {
        var items: [HookItem] = []
        var currentSection: String?
        var sectionLines: [String] = []

        func flush() {
            guard let section = currentSection else { return }
            let lower = section.lowercased()
            guard lower.contains("hook") || lower.contains("hooks") else { return }
            let commandLine = sectionLines.first { line in
                let normalized = stripComment(line).trimmed
                return normalized.hasPrefix("command") || normalized.hasPrefix("cmd") || normalized.hasPrefix("script")
            }
            let command = commandLine.flatMap { line -> String? in
                guard let range = line.range(of: "=") else { return nil }
                return parseString(String(line[range.upperBound...]))
            }
            items.append(HookItem(
                name: section,
                tool: tool,
                scope: scope,
                sourcePath: sourcePath,
                event: section.components(separatedBy: ".").last,
                command: command,
                rawSnippet: sectionLines.joined(separator: "\n")
            ))
        }

        for line in text.components(separatedBy: .newlines) {
            let trimmed = stripComment(line).trimmed
            if trimmed.hasPrefix("["), trimmed.hasSuffix("]") {
                flush()
                currentSection = String(trimmed.dropFirst().dropLast())
                sectionLines = []
            } else if currentSection != nil {
                sectionLines.append(line)
            }
        }
        flush()
        return items
    }

    private static func stripComment(_ line: String) -> String {
        var inQuote = false
        var previous: Character?
        var output = ""
        for char in line {
            if char == "\"", previous != "\\" {
                inQuote.toggle()
            }
            if char == "#", !inQuote {
                break
            }
            output.append(char)
            previous = char
        }
        return output
    }

    private static func parseString(_ value: String?) -> String? {
        guard var value = value?.trimmed, !value.isEmpty else { return nil }
        if value.hasPrefix("\""), value.hasSuffix("\"") {
            value = String(value.dropFirst().dropLast())
        }
        if value.hasPrefix("'"), value.hasSuffix("'") {
            value = String(value.dropFirst().dropLast())
        }
        return value.nilIfEmpty
    }

    private static func parseBool(_ value: String?) -> Bool? {
        guard let normalized = parseString(value)?.lowercased().trimmed else { return nil }
        switch normalized {
        case "true", "yes", "1": return true
        case "false", "no", "0": return false
        default: return nil
        }
    }

    private static func parseArray(_ value: String?) -> [String] {
        guard let value = value?.trimmed, value.hasPrefix("["), value.hasSuffix("]") else { return [] }
        let inner = String(value.dropFirst().dropLast())
        var result: [String] = []
        var current = ""
        var inQuote = false
        var quoteChar: Character?
        var previous: Character?

        for char in inner {
            if (char == "\"" || char == "'") && previous != "\\" {
                if inQuote, quoteChar == char {
                    inQuote = false
                    quoteChar = nil
                } else if !inQuote {
                    inQuote = true
                    quoteChar = char
                } else {
                    current.append(char)
                }
            } else if char == ",", !inQuote {
                if let value = current.trimmed.nilIfEmpty {
                    result.append(value)
                }
                current = ""
            } else {
                current.append(char)
            }
            previous = char
        }
        if let value = current.trimmed.nilIfEmpty {
            result.append(value)
        }
        return result.map { parseString($0) ?? $0 }
    }

    private static func rawSectionSnippet(text: String, serverName: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        var capture = false
        var collected: [String] = []

        for line in lines {
            let trimmed = stripComment(line).trimmed
            if trimmed.hasPrefix("["), trimmed.hasSuffix("]") {
                let section = String(trimmed.dropFirst().dropLast())
                if section == "mcp_servers.\(serverName)" || section == "mcpServers.\(serverName)" || section == "mcp_servers.\(serverName).env" || section == "mcpServers.\(serverName).env" {
                    capture = true
                    collected.append(line)
                } else if capture {
                    break
                }
            } else if capture {
                collected.append(line)
            }
        }
        let snippet = collected.joined(separator: "\n").trimmed
        if snippet.count > 900 { return String(snippet.prefix(900)) + "…" }
        return snippet
    }
}
