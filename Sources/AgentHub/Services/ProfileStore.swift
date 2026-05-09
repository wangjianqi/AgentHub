import Foundation

final class ProfileStore {
    private let fileManager = FileManager.default

    func load() -> [MCPProfile] {
        guard let url = try? profilesURL(), fileManager.fileExists(atPath: url.path) else { return [] }
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([MCPProfile].self, from: data)) ?? []
    }

    func save(_ profiles: [MCPProfile]) {
        guard let url = try? profilesURL() else { return }
        try? fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(profiles) {
            try? data.write(to: url, options: .atomic)
        }
    }

    func profilesPath() -> String {
        (try? profilesURL().abbreviatedPath) ?? "~/Library/Application Support/AgentHub/profiles.json"
    }

    private func profilesURL() throws -> URL {
        let appSupport = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return appSupport.appendingPathComponent("AgentHub/profiles.json")
    }
}
