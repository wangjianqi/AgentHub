import Foundation

struct JSONScanner {
    static func loadObject(from url: URL, allowJSONC: Bool = true) -> Any? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        if let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) {
            return object
        }
        guard allowJSONC, let text = String(data: data, encoding: .utf8) else { return nil }
        let stripped = stripJSONCComments(text)
        guard let strippedData = stripped.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: strippedData, options: [.fragmentsAllowed])
    }

    static func parseMCPServers(object: Any, tool: ToolKind, scope: ConfigScope, sourcePath: String) -> [MCPServerItem] {
        var items: [MCPServerItem] = []
        walk(object: object, path: []) { keyPath, value in
            guard let last = keyPath.last else { return }
            guard ["mcpServers", "mcp_servers", "mcp", "servers"].contains(last) else { return }
            guard let servers = value as? [String: Any] else { return }

            for (name, rawConfig) in servers.sorted(by: { $0.key < $1.key }) {
                guard let config = rawConfig as? [String: Any] else { continue }
                let commandParts = commandAndArgs(from: config)
                let envKeys = environmentKeys(from: config)
                let state = enabledState(from: config)
                let snippet = prettySnippet(rawConfig)
                items.append(MCPServerItem(
                    name: name,
                    tool: tool,
                    scope: scope,
                    sourcePath: sourcePath,
                    command: commandParts.command,
                    args: commandParts.args,
                    envKeys: envKeys,
                    rawSnippet: snippet,
                    isEnabled: state.isEnabled,
                    disabledReason: state.reason
                ))
            }
        }
        return items
    }

    static func parseHooks(object: Any, tool: ToolKind, scope: ConfigScope, sourcePath: String) -> [HookItem] {
        var items: [HookItem] = []
        walk(object: object, path: []) { keyPath, value in
            guard let last = keyPath.last else { return }
            guard last == "hooks" || last == "hook" else { return }
            let hooks = flattenHooks(value: value, prefix: [])
            for hook in hooks {
                items.append(HookItem(
                    name: hook.name,
                    tool: tool,
                    scope: scope,
                    sourcePath: sourcePath,
                    event: hook.event,
                    command: hook.command,
                    rawSnippet: hook.rawSnippet
                ))
            }
        }
        return items
    }

    static func parsePlugins(object: Any, tool: ToolKind, scope: ConfigScope, sourcePath: String) -> [PluginItem] {
        var items: [PluginItem] = []
        walk(object: object, path: []) { keyPath, value in
            guard let last = keyPath.last else { return }
            guard last == "plugin" || last == "plugins" else { return }

            if let plugins = value as? [String] {
                for plugin in plugins {
                    items.append(PluginItem(
                        name: plugin,
                        tool: tool,
                        scope: scope,
                        path: nil,
                        sourcePath: sourcePath,
                        summary: L("summary.configDeclaredPlugin")
                    ))
                }
            } else if let plugins = value as? [Any] {
                for plugin in plugins {
                    if let name = plugin as? String {
                        items.append(PluginItem(name: name, tool: tool, scope: scope, path: nil, sourcePath: sourcePath, summary: L("summary.configDeclaredPlugin")))
                    } else if let dictionary = plugin as? [String: Any] {
                        let name = (dictionary["name"] as? String) ?? (dictionary["package"] as? String) ?? L("summary.unnamedPlugin")
                        items.append(PluginItem(name: name, tool: tool, scope: scope, path: nil, sourcePath: sourcePath, summary: prettySnippet(dictionary, maxLength: 180)))
                    }
                }
            } else if let dictionary = value as? [String: Any] {
                for (name, raw) in dictionary.sorted(by: { $0.key < $1.key }) {
                    items.append(PluginItem(
                        name: name,
                        tool: tool,
                        scope: scope,
                        path: nil,
                        sourcePath: sourcePath,
                        summary: prettySnippet(raw, maxLength: 180)
                    ))
                }
            }
        }
        return items
    }

    private static func flattenHooks(value: Any, prefix: [String]) -> [(name: String, event: String?, command: String?, rawSnippet: String)] {
        var result: [(String, String?, String?, String)] = []

        if let dictionary = value as? [String: Any] {
            if let commandValue = dictionary["command"] ?? dictionary["cmd"] ?? dictionary["script"] {
                let name = prefix.joined(separator: " / ").nilIfEmpty ?? "hook"
                result.append((name, prefix.first, stringify(commandValue), prettySnippet(dictionary)))
            }
            for (key, child) in dictionary.sorted(by: { $0.key < $1.key }) {
                result.append(contentsOf: flattenHooks(value: child, prefix: prefix + [key]))
            }
        } else if let array = value as? [Any] {
            for (index, child) in array.enumerated() {
                result.append(contentsOf: flattenHooks(value: child, prefix: prefix + ["#\(index + 1)"]))
            }
        } else if let command = value as? String {
            let event = prefix.first
            let name = prefix.joined(separator: " /")
            result.append((name, event, command, command))
        } else {
            let name = prefix.joined(separator: " /")
            result.append((name, prefix.first, nil, prettySnippet(value)))
        }

        return result
    }

    private static func walk(object: Any, path: [String], visitor: ([String], Any) -> Void) {
        visitor(path, object)
        if let dictionary = object as? [String: Any] {
            for (key, value) in dictionary {
                walk(object: value, path: path + [key], visitor: visitor)
            }
        } else if let array = object as? [Any] {
            for (index, value) in array.enumerated() {
                walk(object: value, path: path + ["[\(index)]"], visitor: visitor)
            }
        }
    }

    private static func commandAndArgs(from config: [String: Any]) -> (command: String?, args: [String]) {
        if let command = config["command"] as? String {
            return (command, stringArray(from: config["args"]))
        }
        if let commandArray = config["command"] as? [Any] {
            let parts = commandArray.compactMap { $0 as? String }
            return (parts.first, Array(parts.dropFirst()) + stringArray(from: config["args"]))
        }
        if let command = config["cmd"] as? String {
            return (command, stringArray(from: config["args"]))
        }
        if let url = config["url"] as? String {
            return (url, [])
        }
        return (nil, stringArray(from: config["args"]))
    }

    private static func environmentKeys(from config: [String: Any]) -> [String] {
        var keys: Set<String> = []
        if let env = config["env"] as? [String: Any] { keys.formUnion(env.keys) }
        if let env = config["environment"] as? [String: Any] { keys.formUnion(env.keys) }
        if let headers = config["headers"] as? [String: Any] { keys.formUnion(headers.keys.map { "header:\($0)" }) }
        return keys.sorted()
    }

    private static func enabledState(from config: [String: Any]) -> (isEnabled: Bool, reason: String?) {
        if let disabled = boolValue(config["disabled"]), disabled {
            return (false, L("summary.disabledTrue"))
        }
        if let enabled = boolValue(config["enabled"]), !enabled {
            return (false, L("summary.enabledFalse"))
        }
        if let disable = boolValue(config["disable"]), disable {
            return (false, L("summary.disableTrue"))
        }
        return (true, nil)
    }

    private static func boolValue(_ value: Any?) -> Bool? {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.boolValue }
        if let value = value as? String {
            switch value.lowercased().trimmed {
            case "true", "yes", "1": return true
            case "false", "no", "0": return false
            default: return nil
            }
        }
        return nil
    }

    private static func stringArray(from value: Any?) -> [String] {
        if let array = value as? [String] { return array }
        if let array = value as? [Any] { return array.compactMap { stringify($0) } }
        if let string = value as? String { return [string] }
        return []
    }

    private static func stringify(_ value: Any) -> String? {
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }

    private static func stripJSONCComments(_ text: String) -> String {
        var result = ""
        var iterator = Array(text).makeIterator()
        var inString = false
        var escaped = false
        var pending: Character?

        func nextChar() -> Character? {
            if let pendingChar = pending {
                pending = nil
                return pendingChar
            }
            return iterator.next()
        }

        while let char = nextChar() {
            if inString {
                result.append(char)
                if escaped {
                    escaped = false
                } else if char == "\\" {
                    escaped = true
                } else if char == "\"" {
                    inString = false
                }
                continue
            }

            if char == "\"" {
                inString = true
                result.append(char)
                continue
            }

            if char == "/", let next = nextChar() {
                if next == "/" {
                    while let c = nextChar(), c != "\n" { }
                    result.append("\n")
                    continue
                }
                if next == "*" {
                    var previous: Character?
                    while let c = nextChar() {
                        if previous == "*", c == "/" { break }
                        previous = c
                    }
                    continue
                }
                result.append(char)
                pending = next
                continue
            }

            result.append(char)
        }
        return result
    }

    static func prettySnippet(_ value: Any, maxLength: Int = 900) -> String {
        if JSONSerialization.isValidJSONObject(value),
           let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]),
           let text = String(data: data, encoding: .utf8) {
            if text.count > maxLength { return String(text.prefix(maxLength)) + "…" }
            return text
        }
        let text = String(describing: value)
        if text.count > maxLength { return String(text.prefix(maxLength)) + "…" }
        return text
    }
}
