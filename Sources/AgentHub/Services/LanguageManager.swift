import Foundation

final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published private(set) var language: AppLanguage

    static let defaultsKey = "AgentHub.AppLanguage"

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.defaultsKey)
        self.language = AppLanguage(rawValue: saved ?? "") ?? .english
    }

    func setLanguage(_ language: AppLanguage) {
        self.language = language
        UserDefaults.standard.set(language.rawValue, forKey: Self.defaultsKey)
    }

    func localized(_ key: String, _ arguments: CVarArg...) -> String {
        localized(key, arguments)
    }

    func localized(_ key: String, _ arguments: [CVarArg]) -> String {
        LocalizedText.resolve(key, languageCode: language.rawValue, arguments: arguments)
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }

    var locale: Locale { Locale(identifier: rawValue) }

    var menuTitle: String {
        switch self {
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        }
    }
}

struct StringCatalogStore {
    static let shared = StringCatalogStore()

    private let catalog: [String: CatalogEntry]

    private init() {
        // Debug: Print bundle path and available resources
        print("Bundle path: \(Bundle.main.bundlePath)")
        print("Resource URL: \(Bundle.main.url(forResource: "Localizable", withExtension: "xcstrings")?.absoluteString ?? "NOT FOUND")")
        
        guard let url = Bundle.main.url(forResource: "Localizable", withExtension: "xcstrings") else {
            print("ERROR: Could not find Localizable.xcstrings in bundle")
            self.catalog = [:]
            return
        }
        
        guard let data = try? Data(contentsOf: url) else {
            print("ERROR: Could not read data from Localizable.xcstrings")
            self.catalog = [:]
            return
        }
        
        guard let decoded = try? JSONDecoder().decode(StringCatalog.self, from: data) else {
            print("ERROR: Could not decode Localizable.xcstrings")
            self.catalog = [:]
            return
        }
        
        print("SUCCESS: Loaded \(decoded.strings.count) localization keys")
        self.catalog = decoded.strings
    }

    func localizedString(forKey key: String, languageCode: String) -> String {
        if let value = catalog[key]?.localizations[languageCode]?.stringUnit.value {
            return value
        }
        if let value = catalog[key]?.localizations["en"]?.stringUnit.value {
            return value
        }
        return key
    }
}

private struct StringCatalog: Decodable {
    let strings: [String: CatalogEntry]
}

private struct CatalogEntry: Decodable {
    let localizations: [String: CatalogLocalization]
}

private struct CatalogLocalization: Decodable {
    let stringUnit: CatalogStringUnit
}

private struct CatalogStringUnit: Decodable {
    let value: String
}

func L(_ key: String, _ arguments: CVarArg...) -> String {
    let languageCode = UserDefaults.standard.string(forKey: LanguageManager.defaultsKey) ?? AppLanguage.english.rawValue
    return LocalizedText.resolve(key, languageCode: languageCode, arguments: arguments)
}

struct LocalizedText {
    static func resolve(_ key: String, languageCode: String, arguments: [CVarArg]) -> String {
        let format = StringCatalogStore.shared.localizedString(forKey: key, languageCode: languageCode)
        guard !arguments.isEmpty else { return format }
        return String(format: format, locale: Locale(identifier: languageCode), arguments: arguments)
    }
}

extension ConfigScope {
    var localizedTitle: String {
        switch self {
        case .user: return L("scope.user")
        case .project: return L("scope.project")
        case .system: return L("scope.system")
        case .discovered: return L("scope.discovered")
        }
    }
}

extension InstallationStatus {
    var localizedTitle: String {
        switch self {
        case .installed: return L("install.installed")
        case .missing: return L("install.missing")
        case .unknown: return L("install.unknown")
        }
    }
}

extension RiskSeverity {
    var localizedTitle: String {
        switch self {
        case .high: return L("risk.severity.high")
        case .medium: return L("risk.severity.medium")
        case .low: return L("risk.severity.low")
        case .info: return L("risk.severity.info")
        }
    }
}

extension MCPCheckStatus {
    var localizedTitle: String {
        switch self {
        case .ok: return L("mcp.check.ok")
        case .warning: return L("mcp.check.warning")
        case .failed: return L("mcp.check.failed")
        case .skipped: return L("mcp.check.skipped")
        }
    }
}
