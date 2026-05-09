import SwiftUI

@main
struct AgentHubApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var languageManager = LanguageManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .id(languageManager.language.id)
                .environmentObject(appState)
                .environmentObject(languageManager)
                .environment(\.locale, languageManager.language.locale)
                .frame(minWidth: 1120, minHeight: 720)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(after: .appInfo) {
                Button(L("menu.refreshScan")) {
                    appState.refresh()
                }
                .keyboardShortcut("r", modifiers: [.command])
            }

            CommandMenu(L("menu.language")) {
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        languageManager.setLanguage(language)
                        appState.refresh()
                    } label: {
                        HStack {
                            Text(language.menuTitle)
                            if language == languageManager.language {
                                Text("✓")
                            }
                        }
                    }
                }
            }
        }
    }
}
