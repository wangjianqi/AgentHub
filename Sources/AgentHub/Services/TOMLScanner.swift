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

// TRAE CLI 1.x/2.x installations can still expose an older YAML settings file.
// Keep this parser intentionally narrow: it only recognizes the documented
// top-level `mcp_servers`/`mcpServers` sequence and never attempts to rewrite YAML.
struct YAMLScanner {
    static func parseMCPServers(text: String, tool: ToolKind, scope: ConfigScope, sourcePath: String) -> [MCPServerItem] {
        let lines = text.components(separatedBy: .newlines)
        guard let containerIndex = lines.firstIndex(where: { line in
            let value = stripComment(line).trimmed
            return value == "mcp_servers:" || value == "mcpServers:"
        }) else { return [] }

        let containerIndent = indentation(of: lines[containerIndex])
        var blocks: [[String]] = []
        var current: [String] = []

        for line in lines.dropFirst(containerIndex + 1) {
            let stripped = stripComment(line)
            let trimmed = stripped.trimmed
            if trimmed.isEmpty { continue }
            let indent = indentation(of: line)
            if indent <= containerIndent { break }

            if trimmed.hasPrefix("- ") && indent == containerIndent + 2 {
                if !current.isEmpty { blocks.append(current) }
                current = [String(trimmed.dropFirst(2))]
            } else if !current.isEmpty {
                current.append(stripped)
            }
        }
        if !current.isEmpty { blocks.append(current) }

        return blocks.compactMap { block in
            parseServerBlock(block, tool: tool, scope: scope, sourcePath: sourcePath)
        }
    }

    private static func parseServerBlock(_ lines: [String], tool: ToolKind, scope: ConfigScope, sourcePath: String) -> MCPServerItem? {
        var name: String?
        var command: String?
        var remoteURL: String?
        var args: [String] = []
        var envKeys: Set<String> = []
        var headerKeys: Set<String> = []
        var disabled = false
        var currentCollection: String?
        var collectionIndent = -1

        for raw in lines {
            let withoutComment = stripComment(raw)
            let trimmed = withoutComment.trimmed
            guard !trimmed.isEmpty else { continue }
            let indent = indentation(of: withoutComment)

            if trimmed.hasPrefix("- "), let collection = currentCollection, indent > collectionIndent {
                let value = unquote(String(trimmed.dropFirst(2)).trimmed)
                if collection == "args", !value.isEmpty { args.append(value) }
                continue
            }

            guard let colon = trimmed.firstIndex(of: ":") else { continue }
            let key = String(trimmed[..<colon]).trimmed
            let rawValue = String(trimmed[trimmed.index(after: colon)...]).trimmed

            if rawValue.isEmpty {
                currentCollection = key
                collectionIndent = indent
                continue
            }

            currentCollection = nil
            let value = unquote(rawValue)
            switch key {
            case "name":
                name = value.nilIfEmpty
            case "command", "cmd":
                command = value.nilIfEmpty
            case "url", "httpUrl", "http_url", "sseUrl", "sse_url":
                remoteURL = value.nilIfEmpty
            case "args":
                args = parseInlineArray(value)
            case "disabled", "disable":
                disabled = parseBool(value) == true
            case "enabled":
                if parseBool(value) == false { disabled = true }
            default:
                if currentCollection == "env" { envKeys.insert(key) }
                if currentCollection == "headers" { headerKeys.insert(key) }
            }

            // Mapping entries under env/headers have values, so infer collection
            // from indentation and the previously opened collection.
            if indent > collectionIndent, collectionIndent >= 0 {
                if currentCollection == "env" { envKeys.insert(key) }
                if currentCollection == "headers" { headerKeys.insert(key) }
            }
        }

        // Second pass for simple nested env/headers mappings. This avoids a full
        // YAML dependency while remaining deterministic for the documented shape.
        var section: String?
        var sectionIndent = -1
        for raw in lines {
            let stripped = stripComment(raw)
            let trimmed = stripped.trimmed
            guard !trimmed.isEmpty else { continue }
            let indent = indentation(of: raw)
            if let colon = trimmed.firstIndex(of: ":") {
                let key = String(trimmed[..<colon]).trimmed
                let value = String(trimmed[trimmed.index(after: colon)...]).trimmed
                if value.isEmpty, key == "env" || key == "headers" {
                    section = key
                    sectionIndent = indent
                    continue
                }
                if let section, indent > sectionIndent, !key.hasPrefix("-") {
                    if section == "env" { envKeys.insert(key) }
                    if section == "headers" { headerKeys.insert(key) }
                    continue
                }
            }
            if section != nil, indent <= sectionIndent {
                section = nil
                sectionIndent = -1
            }
        }

        guard let name = name?.nilIfEmpty else { return nil }
        let allKeys = envKeys.sorted() + headerKeys.sorted().map { "header:\($0)" }
        let rawSnippet = lines.joined(separator: "\n").trimmed
        return MCPServerItem(
            name: name,
            tool: tool,
            scope: scope,
            sourcePath: sourcePath,
            command: command ?? remoteURL,
            args: args,
            envKeys: allKeys,
            rawSnippet: rawSnippet.count > 900 ? String(rawSnippet.prefix(900)) + "…" : rawSnippet,
            isEnabled: !disabled,
            disabledReason: disabled ? L("summary.disabledEnabledField") : nil
        )
    }

    private static func indentation(of line: String) -> Int {
        line.prefix { $0 == " " }.count
    }

    private static func stripComment(_ line: String) -> String {
        var output = ""
        var quote: Character?
        var escaped = false
        for char in line {
            if escaped {
                output.append(char)
                escaped = false
                continue
            }
            if char == "\\" {
                output.append(char)
                escaped = true
                continue
            }
            if char == "\"" || char == "'" {
                if quote == char { quote = nil }
                else if quote == nil { quote = char }
                output.append(char)
                continue
            }
            if char == "#", quote == nil { break }
            output.append(char)
        }
        return output
    }

    private static func unquote(_ value: String) -> String {
        var result = value.trimmed
        if result.count >= 2,
           ((result.hasPrefix("\"") && result.hasSuffix("\"")) || (result.hasPrefix("'") && result.hasSuffix("'"))) {
            result = String(result.dropFirst().dropLast())
        }
        return result
    }

    private static func parseBool(_ value: String) -> Bool? {
        switch unquote(value).lowercased() {
        case "true", "yes", "1": return true
        case "false", "no", "0": return false
        default: return nil
        }
    }

    private static func parseInlineArray(_ value: String) -> [String] {
        let trimmed = value.trimmed
        guard trimmed.hasPrefix("["), trimmed.hasSuffix("]") else {
            return trimmed.nilIfEmpty.map { [$0] } ?? []
        }
        let inner = String(trimmed.dropFirst().dropLast())
        return inner.split(separator: ",").map { unquote(String($0).trimmed) }.filter { !$0.isEmpty }
    }
}
