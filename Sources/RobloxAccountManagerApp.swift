import SwiftUI
import AppKit

@main
struct RobloxAccountManagerApp: App {
    @StateObject private var accountManager = AccountManager()
    @StateObject private var gameManager = GameManager()
    @StateObject private var settingsManager = SettingsManager()
    @StateObject private var multiLauncher = MultiLauncher()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(accountManager)
                .environmentObject(gameManager)
                .environmentObject(settingsManager)
                .environmentObject(multiLauncher)
                .frame(minWidth: 1200, minHeight: 800)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
                .onOpenURL { url in
                    multiLauncher.handleInboundURL(url)
                }
                .onReceive(NotificationCenter.default.publisher(for: .init("applyExecutorsToClones"))) { note in
                    if let count = note.userInfo?["count"] as? Int {
                        settingsManager.applyAssignedExecutorsToClones(totalInstances: count)
                    }
                }
                .onAppear {
                    settingsManager.startApplicationsMonitor()
                }
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .pasteboard) {
                // Keep standard pasteboard commands (Cmd+C, Cmd+V, etc.)
            }
        }
    }
}
