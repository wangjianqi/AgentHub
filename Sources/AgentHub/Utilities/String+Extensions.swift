import Foundation

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nilIfEmpty: String? {
        let value = trimmed
        return value.isEmpty ? nil : value
    }

    func containsIgnoringCase(_ other: String) -> Bool {
        range(of: other, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    func firstNonEmptyLine(maxLength: Int = 140) -> String? {
        let line = components(separatedBy: .newlines)
            .map { $0.trimmed }
            .first { !$0.isEmpty && !$0.hasPrefix("---") }
        guard let line else { return nil }
        if line.count <= maxLength { return line }
        return String(line.prefix(maxLength)) + "…"
    }
}

extension URL {
    var abbreviatedPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let pathValue = path
        if pathValue == home { return "~" }
        if pathValue.hasPrefix(home + "/") {
            return "~" + String(pathValue.dropFirst(home.count))
        }
        return pathValue
    }
}
