import SwiftUI
import Foundation
import Combine
// Ensure GroupManager is visible to this file
// (File is under Sources/Managers/GroupManager.swift)

struct ContentView: View {
    @EnvironmentObject private var accountManager: AccountManager
    @EnvironmentObject private var gameManager: GameManager
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var multiLauncher: MultiLauncher
    
    @State private var selectedTab: MainTab = .accounts
    @State private var showingSettings = false
    @State private var showingFirstTimeSetup = false
    @State private var showingSupportPrompt = false
    
    var body: some View {
        Group {
            if showingFirstTimeSetup {
                // Full screen first-time setup
                ZStack {
                    backgroundView
                    FirstTimeSetupView(isPresented: $showingFirstTimeSetup)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.9)),
                    removal: .opacity.combined(with: .scale(scale: 1.1))
                ))
            } else {
                // Main app with sidebar
                ZStack {
                    backgroundView
                        .zIndex(0)
                    mainContentView
                        .zIndex(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minWidth: 960, minHeight: 640)
            }
        }
        .preferredColorScheme(settingsManager.currentColorScheme)
        .accentColor(settingsManager.currentAccentColor)
        .animation(settingsManager.getSpringAnimation(for: .normal), value: showingFirstTimeSetup)
        .onAppear {
            multiLauncher.ensureDefaultURLHandler()
            checkFirstTimeSetup()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFirstTimeSetup)) { _ in
            showingFirstTimeSetup = true
        }
        .onChange(of: settingsManager.error?.localizedDescription) { newValue in
            if newValue != nil { showingSupportPrompt = true }
        }
        .sheet(isPresented: $showingSettings) {
            ZStack {
                Color.clear.ignoresSafeArea()
                SettingsView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .environmentObject(settingsManager)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(minWidth: 900, minHeight: 700)
        }
        .sheet(isPresented: $showingSupportPrompt) {
            SupportErrorPromptView(
                message: settingsManager.error?.localizedDescription ?? "",
                openSupport: {
                    showingSupportPrompt = false
                    selectedTab = .support
                }
            )
        }
    }
    
    private var backgroundView: some View {
        ZStack {
            
            settingsManager.selectedGradient.ignoresSafeArea()
            
            if settingsManager.settings.beautifulMode {
                AnimatedAuroraBackground()
                    .environmentObject(settingsManager)
                    .opacity(0.6)
                    .allowsHitTesting(false)
            }
            if settingsManager.settings.enablePatternOverlay || settingsManager.settings.backgroundStyle == .pattern {
                PatternOverlay()
                    .opacity(0.04)
                    .ignoresSafeArea()
            }
        }
    }
    
    private var mainContentView: some View {
        GeometryReader { geo in
        let sidebarWidth = min(max(180.0, geo.size.width * 0.22), 260.0)
        HStack(spacing: 0) {
            // Sidebar
            SidebarView(selectedTab: $selectedTab, showingSettings: $showingSettings)
                .frame(width: sidebarWidth)
                .frame(maxHeight: .infinity)
                .overlay(
                    Rectangle()
                        .frame(width: 1)
                        .foregroundColor(Color(NSColor.separatorColor)),
                    alignment: .trailing
                )
                .zIndex(2)
            
            // Main content area
            Group {
                switch selectedTab {
                case .accounts:
                    AccountsView()
                        .environmentObject(accountManager)
                        .environmentObject(gameManager)
                        .environmentObject(multiLauncher)
                case .games:
                    GamesView()
                        .environmentObject(gameManager)
                        .environmentObject(accountManager)
                        .environmentObject(multiLauncher)
                case .launcher:
                    LauncherView()
                        .environmentObject(multiLauncher)
                        .environmentObject(accountManager)
                        .environmentObject(gameManager)
                case .executors:
                    ExecutorsView()
                        .environmentObject(settingsManager)
                        .environmentObject(accountManager)
                        .environmentObject(gameManager)
                        .environmentObject(multiLauncher)
                case .statistics:
                    StatisticsView()
                        .environmentObject(multiLauncher)
                        .environmentObject(accountManager)
                        .environmentObject(gameManager)
                case .friends:
                    FriendsView()
                        .environmentObject(accountManager)
                        .environmentObject(gameManager)
                        .environmentObject(settingsManager)
                case .support:
                    SupportView()
                        .environmentObject(accountManager)
                        .environmentObject(gameManager)
                        .environmentObject(settingsManager)
                        .environmentObject(multiLauncher)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Quick action buttons
                Menu {
                    Button("Clean Roblox") {
                        if let account = accountManager.selectedAccount, let game = gameManager.selectedGame {
                            multiLauncher.launchGame(account: account, game: game, flavor: .clean)
                        }
                    }
                    Button("Opiumware Roblox") {
                        if let account = accountManager.selectedAccount, let game = gameManager.selectedGame {
                            multiLauncher.launchGame(account: account, game: game, flavor: .opiumware)
                        }
                    }
                    Button("MacSploit Roblox") {
                        if let account = accountManager.selectedAccount, let game = gameManager.selectedGame {
                            multiLauncher.launchGame(account: account, game: game, flavor: .macsploit)
                        }
                    }
                    Button("Hydrogen Roblox") {
                        if let account = accountManager.selectedAccount, let game = gameManager.selectedGame {
                            multiLauncher.launchGame(account: account, game: game, flavor: .hydrogen)
                        }
                    }
                } label: {
                    Label("Launch", systemImage: "play.fill")
                }
                .disabled(accountManager.selectedAccount == nil || gameManager.selectedGame == nil)
                
                Button(action: { showingSettings = true }) {
                    Label("Settings", systemImage: "gearshape.fill")
                }
            }
        }
    }
    
    private func checkFirstTimeSetup() {
        showingFirstTimeSetup = accountManager.accounts.isEmpty
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let openFirstTimeSetup = Notification.Name("openFirstTimeSetup")
}

// MARK: - Main Tabs

enum MainTab: String, CaseIterable {
    case accounts = "accounts"
    case games = "games"
    case launcher = "launcher"
    case executors = "executors"
    case statistics = "statistics"
    case friends = "friends"
    case support = "support"
    
    var displayName: String {
        switch self {
        case .accounts: return "Accounts"
        case .games: return "Games"
        case .launcher: return "Launcher"
        case .executors: return "Executors"
        case .statistics: return "Statistics"
        case .friends: return "Friends"
        case .support: return "Support"
        }
    }
    
    var iconName: String {
        switch self {
        case .accounts: return "person.3.fill"
        case .games: return "gamecontroller.fill"
        case .launcher: return "play.rectangle.fill"
        case .executors: return "shippingbox.fill"
        case .statistics: return "chart.bar.fill"
        case .friends: return "person.2.fill"
        case .support: return "lifepreserver"
        }
    }
}

// MARK: - Sidebar View

struct SidebarView: View {
    @Binding var selectedTab: MainTab
    @Binding var showingSettings: Bool
    @EnvironmentObject private var settingsManager: SettingsManager
    
    var body: some View {
        VStack(spacing: 0) {
            // App Header
            headerView
                .padding(.top, 20)
                .padding(.bottom, 30)
            
            // Navigation
            VStack(spacing: 8) {
                ForEach(MainTab.allCases, id: \.self) { tab in
                    SidebarTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab
                    ) {
                        withAnimation(settingsManager.getSpringAnimation(for: .quick)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            
            Spacer()
            
            // Bottom actions
            VStack(spacing: 12) {
                Divider()
                    .padding(.horizontal, 16)
                
                Button(action: { openDiscordInvite() }) {
                    HStack(spacing: 10) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 16, weight: .medium))
                        Text("Join Discord")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 0.345, green: 0.396, blue: 0.949))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 16)

                Button(action: { showingSettings = true }) {
                    HStack {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16, weight: .medium))
                        Text("Settings")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.clear)
                )
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 20)
        }
        .background(Color.clear)
        .contentShape(Rectangle())
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            // App Icon
            ZStack {
                // Outer ring
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                settingsManager.currentAccentColor,
                                settingsManager.currentAccentColor.opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 68, height: 68)
                
                // Inner circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                settingsManager.currentAccentColor.opacity(0.9),
                                settingsManager.currentAccentColor
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                
                // Icon
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            }
            .shadow(color: settingsManager.currentAccentColor.opacity(0.4), radius: 12, x: 0, y: 6)
            
            // App Title
            Text("Roblox Account Manager")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }
}

private func openDiscordInvite() {
    let inviteCode = "BHDgYcv4Ek"
    if let deep = URL(string: "discord://-/invite/\(inviteCode)"),
       NSWorkspace.shared.urlForApplication(toOpen: deep) != nil {
        NSWorkspace.shared.open(deep)
        return
    }
    if let web = URL(string: "https://discord.gg/\(inviteCode)") {
        NSWorkspace.shared.open(web)
    }
}

// MARK: - Support Views

struct SupportErrorPromptView: View {
    let message: String
    let openSupport: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                Text("We noticed an error.").font(.system(size: 18, weight: .semibold))
            }
            Text(message).font(.system(size: 13)).foregroundColor(.secondary).multilineTextAlignment(.center)
                .lineLimit(4)
            HStack(spacing: 12) {
                Button("Open Support") { openSupport() }
                    .buttonStyle(.borderedProminent)
                DismissSheetButton()
            }
            .padding(.top, 6)
        }
        .padding(24)
        .frame(minWidth: 400)
    }
}

private struct DismissSheetButton: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Button("Dismiss") { dismiss() }.buttonStyle(.bordered)
    }
}

struct SupportView: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    @State private var descriptionText: String = ""
    @State private var includeLogs: Bool = true
    @State private var contact: String = ""
    @State private var isPrivate: Bool = false
    @State private var isSubmitting = false
    @State private var submitResult: String = ""

    private let publicWebhook = "https://discord.com/api/webhooks/1414838689183563816/ewabo8TUmAM38HVLXmX7vA9NWWZd_fsd4SFXFZOLypQvSTb7CfxTBK-FTxtOAHkSLEnj"
    private let privateWebhook = "https://discord.com/api/webhooks/1414839166906142741/E-SueKCpvZH43Iiv5K9f5S8WTMKgG8kfvyLK4HydPR51YX_Cx-1bZLFVlcEokaG8I0gb"

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                form
                actions
                if !submitResult.isEmpty { resultBanner }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 30)
        }
        .onAppear { prefill() }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: "lifepreserver").font(.system(size: 24, weight: .medium))
                Text("Support").font(.system(size: 28, weight: .bold))
            }
            Spacer()
            Picker("Visibility", selection: $isPrivate) {
                Text("Public").tag(false)
                Text("Private").tag(true)
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(width: 220)
        }
    }

    private var form: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("What happened?").font(.system(size: 16, weight: .semibold))
                TextEditor(text: $descriptionText)
                    .frame(minHeight: 140)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.controlBackgroundColor)))
            }
            Toggle("Include recent error message", isOn: $includeLogs).toggleStyle(SwitchToggleStyle())
            HStack {
                Text("Contact (optional)").font(.system(size: 14))
                Spacer()
                TextField("Discord tag or email", text: $contact)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 260)
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button(action: submit) {
                HStack(spacing: 8) {
                    if isSubmitting { ProgressView().scaleEffect(0.8) }
                    Text(isSubmitting ? "Submitting…" : "Submit Request")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSubmitting || descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button("Open Support Channel") { openDiscordInvite() }
                .buttonStyle(.bordered)
            Spacer()
        }
    }

    private var resultBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: submitResult.hasPrefix("OK") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(submitResult.hasPrefix("OK") ? .green : .orange)
            Text(submitResult).font(.system(size: 13))
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
    }

    private func prefill() {
        if descriptionText.isEmpty {
            let err = settingsManager.error
            if let err { descriptionText = "Error: \(err.localizedDescription)\n\nSteps to reproduce: " }
        }
    }

    private func submit() {
        isSubmitting = true
        submitResult = ""
        let contentText = buildContent()
        guard let payload = try? JSONSerialization.data(withJSONObject: ["content": contentText], options: []) else {
            submitResult = "Failed to encode payload"
            isSubmitting = false
            return
        }
        let urlString = isPrivate ? privateWebhook : publicWebhook
        guard let url = URL(string: urlString) else {
            submitResult = "Invalid webhook URL"
            isSubmitting = false
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = payload
        let task = URLSession.shared.dataTask(with: req) { data, resp, err in
            DispatchQueue.main.async {
                isSubmitting = false
                if let err { submitResult = "Failed: \(err.localizedDescription)"; return }
                if let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                    submitResult = "OK: Sent to \(isPrivate ? "private" : "public") support"
                    descriptionText = ""
                } else {
                    let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
                    submitResult = "Failed: HTTP \(code)"
                }
            }
        }
        task.resume()
    }

    private func buildContent() -> String {
        var lines: [String] = []
        lines.append("New support request from Roblox Account Manager")
        if includeLogs, let err = settingsManager.error?.localizedDescription {
            lines.append("Error: \(err)")
        }
        let msg = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !msg.isEmpty { lines.append("Message: \(msg)") }
        if !contact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { lines.append("Contact: \(contact)") }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Executors View (embedded to avoid Xcode project file edits)

struct ExecutorsView: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var accountManager: AccountManager
    @EnvironmentObject private var gameManager: GameManager
    @EnvironmentObject private var multiLauncher: MultiLauncher
    @State private var newExecutorName = ""
    @State private var newExecutorURLString = ""
    @State private var showingChooseInstallDir = false
    @State private var isBusy = false
    @State private var logText = ""
    @State private var showFinalize = false
    @State private var prepareCountText = "2"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                installDirectory
                addExecutor
                listExecutors
                instanceAssignments
                popularExecutors
                cleanTools
                finalizeInstall
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 30)
            .onAppear {
                if accountManager.selectedAccount == nil {
                    accountManager.selectedAccount = accountManager.accounts.first
                }
                if gameManager.selectedGame == nil {
                    if let first = (gameManager.games + gameManager.searchResults).first {
                        gameManager.selectGame(first)
                    } else {
                        Task { await gameManager.refreshTrending() }
                    }
                }
            }
        }
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 24, weight: .medium))
                    Text("Executors")
                        .font(.system(size: 28, weight: .bold))
                }
                Text("Install, manage, and assign executors to robloxN instances")
                    .foregroundColor(.secondary)
            }
            Spacer()
            HStack(spacing: 10) {
                Button("Install/Update All") { installAllExecutors() }
                    .disabled(isBusy || settingsManager.settings.executors.isEmpty)
                Button("Move Clones Here") { settingsManager.moveClonesToDesiredDir() }
                    .disabled(isBusy)
                Button("Apply Assignments Now") { applyAssignmentsNow() }
                    .disabled(isBusy)
            }
        }
    }
    
    private var installDirectory: some View {
        SettingsGroup(title: "Install Directory", icon: "folder") {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Location")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Where executors will be installed and indexed")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                TextField("/path/to/executors", text: .init(
                    get: { settingsManager.settings.executorsInstallDirectory },
                    set: { settingsManager.settings.executorsInstallDirectory = $0 }
                ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(minWidth: 420)
                Button("Choose…") { showingChooseInstallDir = true }
            }
        }
        .fileImporter(isPresented: $showingChooseInstallDir, allowedContentTypes: [.folder]) { result in
            if case let .success(url) = result { settingsManager.settings.executorsInstallDirectory = url.path }
        }
    }
    
    private var addExecutor: some View {
        SettingsGroup(title: "Add Executor", icon: "plus.circle.fill") {
            HStack(spacing: 8) {
                TextField("Name", text: $newExecutorName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Install link or script path", text: $newExecutorURLString)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Add") { addExecutorAction() }
                    .disabled(newExecutorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newExecutorURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
    
    private var listExecutors: some View {
        SettingsGroup(title: "Installed Executors", icon: "list.bullet") {
            VStack(spacing: 10) {
                ForEach(settingsManager.settings.executors) { exec in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exec.name)
                                .font(.system(size: 14, weight: .semibold))
                            if !exec.installURLString.isEmpty {
                                Text(exec.installURLString)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            if let path = exec.installedPath, !path.isEmpty {
                                Text(path)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Button("Install/Update") { installExecutor(exec) }
                            .buttonStyle(.bordered)
                        Button("Remove", role: .destructive) { settingsManager.removeExecutor(exec) }
                            .buttonStyle(.bordered)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )
                }
                if !logText.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Logs")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        ScrollView {
                            Text(logText)
                                .font(.system(size: 11).monospaced())
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: 120)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }
    
    private var instanceAssignments: some View {
        SettingsGroup(title: "Instance Assignments", icon: "square.stack.3d.down.forward.fill") {
            HStack(spacing: 12) {
                ForEach(Array(1..<(max(settingsManager.settings.maxSimultaneousLaunches, 2) + 1)), id: \.self) { idx in
                    VStack {
                        Text("roblox\\(idx)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Picker("", selection: .init(
                            get: { settingsManager.settings.executorAssignmentsByInstance[idx] },
                            set: { settingsManager.settings.executorAssignmentsByInstance[idx] = $0 }
                        )) {
                            Text("Normal").tag(Optional<UUID>.none)
                            ForEach(settingsManager.settings.executors) { exec in
                                Text(exec.name).tag(Optional(exec.id))
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 180)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )
                }
            }
        }
    }

    private var popularExecutors: some View {
        SettingsGroup(title: "Popular Executors", icon: "sparkles") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Install a known executor with one click.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                HStack(spacing: 12) {
                    Button("Install Opiumware") { installOpiumware() }
                        .buttonStyle(.borderedProminent)
                    Button("Install MacSploit") { installMacSploit() }
                        .buttonStyle(.bordered)
                    Button("Install Hydrogen-M") { installHydrogen() }
                        .buttonStyle(.bordered)
                }
            }
        }
    }

    private var cleanTools: some View {
        SettingsGroup(title: "No Hacks (Clean Roblox)", icon: "checkmark.seal") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Manage clean clones independent of executors.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                HStack(spacing: 12) {
                    Button("Reinstall Clean Clones") {
                        let n = max(1, min(10, Int(prepareCountText) ?? 2))
                        settingsManager.reinstallCleanClones(desiredCount: n)
                        appendLog("[Clean] Reinstalled clean Roblox clones (\(n)) into \(settingsManager.settings.robloxClonesDirectory.isEmpty ? settingsManager.defaultClonesDirectory() : settingsManager.settings.robloxClonesDirectory)")
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Reinstall Clean (Download) & Prepare…") {
                        // Ask for count via the existing field
                        let n = max(1, min(10, Int(prepareCountText) ?? 2))
                        settingsManager.installCleanRobloxAndPrepare(desiredCount: n)
                        appendLog("[Clean] Downloaded clean Roblox and prepared \(n) clean clone(s) in good directory")
                    }
                    .buttonStyle(.bordered)
                    Button("Install Clean Roblox to /Applications") {
                        settingsManager.installCleanRoblox()
                        appendLog("[Clean] Installed clean Roblox into /Applications/Roblox.app")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    // MARK: - Test Launch
    private var testLaunch: some View {
        SettingsGroup(title: "Test Launch", icon: "play.fill") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Quickly test a launch using your current clones and executor assignments.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                HStack(spacing: 12) {
                    Picker("Account", selection: .init(
                        get: { accountManager.selectedAccount?.id ?? accountManager.accounts.first?.id },
                        set: { id in
                            if let id, let acc = accountManager.accounts.first(where: { $0.id == id }) {
                                accountManager.selectedAccount = acc
                            }
                        }
                    )) {
                        ForEach(accountManager.accounts) { acc in
                            Text(acc.displayName).tag(Optional(acc.id))
                        }
                    }
                    .frame(width: 220)
                    
                    Picker("Game", selection: .init(
                        get: { gameManager.selectedGame?.id ?? (gameManager.games + gameManager.searchResults).first?.id },
                        set: { gid in
                            if let gid, let g = (gameManager.games + gameManager.searchResults).first(where: { $0.id == gid }) {
                                gameManager.selectGame(g)
                            }
                        }
                    )) {
                        ForEach(gameManager.games.isEmpty ? gameManager.searchResults : gameManager.games) { g in
                            Text(g.name).tag(Optional(g.id))
                        }
                    }
                    .frame(width: 280)
                    
                    Button("Launch Test") {
                        let acc = accountManager.selectedAccount ?? accountManager.accounts.first
                        var gsel = gameManager.selectedGame ?? (gameManager.games + gameManager.searchResults).first
                        if gsel == nil {
                            Task { await gameManager.refreshTrending() }
                            gsel = (gameManager.games + gameManager.searchResults).first
                        }
                        if let acc, let g = gsel {
                            multiLauncher.launchGame(account: acc, game: g)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
    
    private func addExecutorAction() {
        let name = newExecutorName.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = newExecutorURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !url.isEmpty else { return }
        settingsManager.addExecutor(name: name, installURLString: url)
        newExecutorName = ""
        newExecutorURLString = ""
    }

    // MARK: - Actions (run commands from tab)
    private func installExecutor(_ exec: Executor) {
        runCommandFor(input: exec.installURLString, action: "install")
    }
    
    private func installAllExecutors() {
        for exec in settingsManager.settings.executors {
            installExecutor(exec)
        }
    }
    
    private func applyAssignmentsNow() {
        let count = countClones()
        settingsManager.applyAssignedExecutorsToClones(totalInstances: max(1, count))
        appendLog("[Tab] Applied assignments to \(max(1, count)) instance(s)")
    }
    
    private func countClones() -> Int {
        let fm = FileManager.default
        var dir = settingsManager.settings.robloxClonesDirectory
        if dir.isEmpty { dir = settingsManager.defaultClonesDirectory() }
        guard let items = try? fm.contentsOfDirectory(atPath: dir) else { return 0 }
        return items.filter { $0.hasPrefix("Roblox-") && $0.hasSuffix(".app") }.count
    }
    
    private func runCommandFor(input: String, action: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return }
        // Open Terminal.app and run the command there exactly as user would, from $HOME.
        var dest = settingsManager.settings.executorsInstallDirectory
        if dest.isEmpty { dest = settingsManager.defaultExecutorsDirectory() }
        try? FileManager.default.createDirectory(atPath: dest, withIntermediateDirectories: true)
        let clones = settingsManager.settings.robloxClonesDirectory.isEmpty ? settingsManager.defaultClonesDirectory() : settingsManager.settings.robloxClonesDirectory
        let export = "cd $HOME; export ACTION=\(action); export EXECUTOR_INSTALL_DIR=\(dest.quoted()); export ROBLOX_CLONES_DIR=\(clones.quoted());"
        let fullCmd = export + " " + trimmed
        let shell = "sudo /bin/zsh -lc \(fullCmd.quoted())"
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        let osa = "tell application \"Terminal\" to do script \"\(shell.escapedForOSA())\""
        p.arguments = ["-e", osa]
        let out = Pipe(); let err = Pipe()
        p.standardOutput = out; p.standardError = err
        isBusy = true
        appendLog("[Run] Terminal: \(trimmed)")
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try p.run()
                p.waitUntilExit()
                let outStr = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let errStr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                DispatchQueue.main.async {
                    self.appendLog(outStr)
                    if !errStr.isEmpty { self.appendLog(errStr) }
                    self.isBusy = false
                    // Ask user to confirm installation before preparing clones
                    self.showFinalize = true
                }
            } catch {
                DispatchQueue.main.async {
                    self.appendLog("[Error] \(error.localizedDescription)")
                    self.isBusy = false
                }
            }
        }
    }
    
    // MARK: - Finalize and prepare multi-instance clones
    private var finalizeInstall: some View {
        SettingsGroup(title: "Finalize Multi-Instance", icon: "square.stack.3d.up.fill") {
            VStack(alignment: .leading, spacing: 10) {
                Text("After installing in Terminal, confirm to prepare Roblox clones that bypass single-instance detection.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                if showFinalize {
                    HStack(spacing: 10) {
                        Text("Number of instances")
                        TextField("2", text: $prepareCountText)
                            .frame(width: 60)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Spacer()
                        Button("Yes, Prepare Clones") {
                            let n = max(1, min(10, Int(prepareCountText) ?? 2))
                            settingsManager.prepareMultiInstanceClones(desiredCount: n)
                            appendLog("[Finalize] Prepared \(n) clone(s) in \(settingsManager.settings.robloxClonesDirectory.isEmpty ? settingsManager.defaultClonesDirectory() : settingsManager.settings.robloxClonesDirectory)")
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Not Yet") { showFinalize = false }
                            .buttonStyle(.bordered)
                    }
                } else {
                    Text("Run an installer first, then we’ll ask to finalize.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Popular installers
    private func installOpiumware() {
        let cmd = "curl -s \"https://raw.githubusercontent.com/norbyv1/OpiumwareInstall/main/installer\" | bash"
        runCommandFor(input: cmd, action: "install")
    }
    private func installMacSploit() {
        let cmd = "cd ~/ && curl -s \"https://git.raptor.fun/main/install.sh\" | bash </dev/tty"
        runCommandFor(input: cmd, action: "install")
    }
    private func installHydrogen() {
        let hydrogenInstallerURL = "https://0ai4bbbahf.ufs.sh/f/4fzhZqSSYIjmt8OGDr546yzQVkLwJsKXF8Y7eoi1cUprDjC2"
        let hydrogenMURL = "https://0ai4bbbahf.ufs.sh/f/4fzhZqSSYIjm6G06fL5Y9NPtXuqoZsSJebkQBGvjIy12HdFO"
        let robloxArm = "https://setup.rbxcdn.com/mac/arm64/version-1f7443723bfe4e74-RobloxPlayer.zip"
        let robloxX86 = "https://setup.rbxcdn.com/mac/version-1f7443723bfe4e74-RobloxPlayer.zip"
        let cmd = "INSTALLER=\"$TMPDIR/hydrogen_installer\"; curl -fsSL \"\(hydrogenInstallerURL)\" -o \"$INSTALLER\" && chmod +x \"$INSTALLER\" && \"$INSTALLER\" --hydrogen-url \"\(hydrogenMURL)\" --roblox-url-arm \"\(robloxArm)\" --roblox-url-x86 \"\(robloxX86)\" && rm -f \"$INSTALLER\""
        runCommandFor(input: cmd, action: "install")
    }
    
    private func appendLog(_ s: String) {
        if s.isEmpty { return }
        logText.append(contentsOf: (logText.isEmpty ? "" : "\n") + s)
    }
}

private extension String {
    func quoted() -> String { return "\"" + self.replacingOccurrences(of: "\"", with: "\\\"") + "\"" }
    func escapedForOSA() -> String {
        var s = self
        s = s.replacingOccurrences(of: "\\", with: "\\\\")
        s = s.replacingOccurrences(of: "\"", with: "\\\"")
        s = s.replacingOccurrences(of: "\n", with: "\\n")
        return s
    }
}
// MARK: - Sidebar Tab Button

struct SidebarTabButton: View {
    let tab: MainTab
    let isSelected: Bool
    let action: () -> Void
    
    @EnvironmentObject private var settingsManager: SettingsManager
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: tab.iconName)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 20, height: 20)
                
                Text(tab.displayName)
                    .font(.system(size: 14, weight: .medium))
                
                Spacer()
                
                if isSelected {
                    Circle()
                        .fill(settingsManager.currentAccentColor)
                        .frame(width: 6, height: 6)
                }
            }
            .contentShape(Rectangle())
            .foregroundColor(isSelected ? settingsManager.currentAccentColor : .secondary)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            ZStack {
                if isSelected && settingsManager.settings.beautifulMode {
                    LinearGradient(colors: [settingsManager.currentAccentColor.opacity(0.35), settingsManager.currentAccentColor.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: settingsManager.currentAccentColor.opacity(0.35), radius: 12, x: 0, y: 6)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            isSelected
                            ? settingsManager.currentAccentColor.opacity(0.12)
                            : (isHovered ? Color.secondary.opacity(0.08) : Color.clear)
                        )
                        .allowsHitTesting(false)
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isSelected ? settingsManager.currentAccentColor.opacity(0.3) : (isHovered ? Color.secondary.opacity(0.2) : Color.clear),
                    lineWidth: 1
                )
        )
        .scaleEffect(isSelected ? 1.03 : 1.0)
        .animation(settingsManager.getSpringAnimation(for: .quick), value: isSelected)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Pattern Overlay

struct PatternOverlay: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 40
            let dotSize: CGFloat = 2
            
            for x in stride(from: 0, to: size.width, by: spacing) {
                for y in stride(from: 0, to: size.height, by: spacing) {
                    let point = CGPoint(x: x, y: y)
                    context.fill(
                        Path(ellipseIn: CGRect(
                            origin: CGPoint(x: point.x - dotSize/2, y: point.y - dotSize/2),
                            size: CGSize(width: dotSize, height: dotSize)
                        )),
                        with: .color(.primary)
                    )
                }
            }
        }
    }
}

// MARK: - Beautiful Mode Animated Background
struct AnimatedAuroraBackground: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    @State private var t: CGFloat = 0
    @State private var noiseOffset: CGFloat = 0
    private let timer = Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()
    
    var body: some View {
        TimelineView(.animation) { _ in
            Canvas { context, size in
                // Base gradient wash
                let grad = Gradient(colors: [
                    settingsManager.currentAccentColor.opacity(0.25),
                    settingsManager.paletteBackground.opacity(0.8),
                    settingsManager.currentAccentColor.opacity(0.18)
                ])
                let rect = CGRect(origin: .zero, size: size)
                context.fill(
                    Path(rect),
                    with: .linearGradient(
                        grad,
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: size.width, y: size.height)
                    )
                )

                // Moving blobs
                let blobCount = 5
                for i in 0..<blobCount {
                    let phase = t + CGFloat(i) * 0.8
                    let cx = size.width * (0.5 + 0.38 * CGFloat(cos(Double(phase + CGFloat(i)))))
                    let cy = size.height * (0.5 + 0.34 * CGFloat(sin(Double(phase * 0.8 + CGFloat(i) * 1.7))))
                    let radius = min(size.width, size.height) * (0.22 + 0.05 * CGFloat(sin(Double(phase * 1.3 + CGFloat(i)))))
                    let blobRect = CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2)
                    let color = settingsManager.currentAccentColor.opacity(0.18 + 0.08 * CGFloat(sin(Double(phase))))
                    context.fill(Path(ellipseIn: blobRect), with: .radialGradient(Gradient(colors: [color, .clear]), center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: radius))
                }

                // Subtle bokeh dots
                let dotCount = 60
                for i in 0..<dotCount {
                    let angle = CGFloat(i) * .pi * 2 / CGFloat(dotCount)
                    let r = (min(size.width, size.height) * 0.45) * (0.6 + 0.4 * CGFloat(sin(Double(t * 0.6 + angle * 2))))
                    let x = size.width * 0.5 + r * CGFloat(cos(Double(angle + t * 0.15)))
                    let y = size.height * 0.5 + r * CGFloat(sin(Double(angle + t * 0.15)))
                    let s = CGFloat(1.0 + 1.5 * abs(sin(Double(angle * 3 + t))))
                    let dotRect = CGRect(x: x - s, y: y - s, width: s * 2, height: s * 2)
                    context.fill(Path(ellipseIn: dotRect), with: .color(settingsManager.currentAccentColor.opacity(0.08)))
                }
            }
        }
        .ignoresSafeArea()
        .onReceive(timer) { _ in
            // Drive time
            withAnimation(.linear(duration: 1/60)) { t += 0.008; noiseOffset += 0.003 }
        }
    }
}

// MARK: - Friends (embedded)

struct FriendPresence: Identifiable {
    let id: Int
    let name: String
    let displayName: String
    var avatarURL: String
    var userPresenceType: Int
    var lastLocation: String
    var placeId: Int?
    var universeId: Int?
    var gameId: String?
    var lastOnline: String?
}

struct FriendsView: View {
    @EnvironmentObject private var accountManager: AccountManager
    @EnvironmentObject private var settingsManager: SettingsManager
    @State private var friends: [FriendPresence] = []
    @State private var searchText: String = ""
    @State private var isLoading: Bool = false
    @State private var errorText: String = ""
    @State private var timerCancellable: AnyCancellable?
    @State private var selectedAccountId: UUID? = nil
    @State private var filter: FriendsFilter = .all
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.2.fill").font(.system(size: 22))
                        Text("Friends").font(.system(size: 28, weight: .bold))
                    }
                    Text("See who is online and what they’re playing").foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            
            HStack(spacing: 12) {
                // Account picker (required)
                Picker("Account", selection: $selectedAccountId) {
                    Text("Select account").tag(Optional<UUID>.none)
                    ForEach(accountManager.accounts) { acc in
                        Text(acc.displayName.isEmpty ? acc.username : acc.displayName).tag(Optional(acc.id))
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 220)

                // Filter segmented control
                Picker("", selection: $filter) {
                    ForEach(FriendsFilter.allCases, id: \.self) { f in Text(f.displayName).tag(f) }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 320)

                Spacer()

                TextField("Search friends…", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(minWidth: 220)

                Button(action: { Task { await refresh() } }) { Label("Refresh", systemImage: "arrow.clockwise") }
                    .buttonStyle(.bordered)
                    .disabled(selectedAccountId == nil)
            }
            .padding(.horizontal, 12)
            
            if !errorText.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                    Text(errorText).foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
            }
            
            if selectedAccountId == nil {
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.questionmark").font(.system(size: 32)).foregroundColor(.secondary)
                    Text("Select an account to view friends").foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isLoading {
                VStack(spacing: 12) { ProgressView(); Text("Loading friends…").foregroundColor(.secondary) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(filteredFriends) { f in FriendRow(friend: f) }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
        }
        .padding(.vertical, 20)
        .onAppear { Task { await refresh() }; startAutoRefresh(interval: 1.0) }
        .onDisappear { timerCancellable?.cancel() }
    }
    
    private var filteredFriends: [FriendPresence] {
        // Apply presence filter and search
        let filteredByPresence: [FriendPresence] = friends.filter { f in
            switch filter {
            case .all: return true
            case .online: return f.userPresenceType == 1
            case .ingame: return f.userPresenceType == 2
            case .offline: return f.userPresenceType == 0 || (f.userPresenceType != 1 && f.userPresenceType != 2)
            }
        }
        let q = searchText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return filteredByPresence }
        return filteredByPresence.filter { $0.name.localizedCaseInsensitiveContains(q) || $0.displayName.localizedCaseInsensitiveContains(q) }
    }
    
    private func startAutoRefresh(interval: Double = 30.0) {
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { _ in Task { await refreshPresenceOnly() } }
    }
    
    private func currentCookie() -> String? {
        guard let sel = selectedAccountId, let acc = accountManager.accounts.first(where: { $0.id == sel }) else { return nil }
        let c = acc.cookie.trimmingCharacters(in: .whitespacesAndNewlines)
        return c.isEmpty ? nil : c
    }
    
    private func refreshPresenceOnly() async {
        guard let cookie = currentCookie(), !friends.isEmpty else { return }
        let ids = friends.map { $0.id }
        do {
            let pres = try await RobloxAPIService.shared.fetchPresence(userIds: ids, cookie: cookie)
            var map: [Int: RobloxAPIService.PresenceItem] = [:]
            for p in pres { map[p.userId] = p }
            for i in friends.indices {
                if let p = map[friends[i].id] {
                    friends[i].userPresenceType = p.userPresenceType
                    friends[i].lastLocation = p.lastLocation ?? ""
                    friends[i].placeId = p.placeId
                    friends[i].universeId = p.universeId
                    friends[i].gameId = p.gameId
                    friends[i].lastOnline = p.lastOnline
                }
            }
        } catch { errorText = "Presence refresh failed: \(error.localizedDescription)" }
    }
    
    private func refresh() async {
        isLoading = true; errorText = ""; defer { isLoading = false }
        guard let cookie = currentCookie() else { errorText = "No account selected or cookie missing"; return }
        do {
            let me = try await RobloxAPIService.shared.fetchUserInfo(from: cookie)
            accountManager.authenticatedUserId = me.id
            let basic = try await RobloxAPIService.shared.fetchFriends(of: me.id, cookie: cookie)
            let ids = basic.map { $0.id }
            let presence = try await RobloxAPIService.shared.fetchPresence(userIds: ids, cookie: cookie)
            var presById: [Int: RobloxAPIService.PresenceItem] = [:]
            for p in presence { presById[p.userId] = p }
            let avatars = try await RobloxAPIService.shared.fetchAvatarHeadshots(userIds: ids)
            var rows: [FriendPresence] = []
            rows.reserveCapacity(basic.count)
            for f in basic {
                let p = presById[f.id]
                let avatar = avatars[f.id] ?? ""
                rows.append(FriendPresence(
                    id: f.id,
                    name: f.name,
                    displayName: f.displayName,
                    avatarURL: avatar,
                    userPresenceType: p?.userPresenceType ?? 0,
                    lastLocation: p?.lastLocation ?? "",
                    placeId: p?.placeId,
                    universeId: p?.universeId,
                    gameId: p?.gameId,
                    lastOnline: p?.lastOnline
                ))
            }
            friends = rows.sorted { a, b in
                func rank(_ t: Int) -> Int { t == 2 ? 0 : (t == 1 ? 1 : 2) }
                let ra = rank(a.userPresenceType), rb = rank(b.userPresenceType)
                if ra != rb { return ra < rb }
                return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
            }
        } catch { errorText = error.localizedDescription }
    }
}

private struct FriendRow: View {
    let friend: FriendPresence
    @EnvironmentObject private var settingsManager: SettingsManager
    
    var presenceText: String {
        switch friend.userPresenceType {
        case 2: return friend.lastLocation.isEmpty ? "In-Game" : friend.lastLocation
        case 1: return friend.lastLocation.isEmpty ? "Online" : friend.lastLocation
        case 3: return "In Studio"
        default: return friend.lastOnline.map { "Last online: \($0)" } ?? "Offline"
        }
    }
    var presenceColor: Color {
        switch friend.userPresenceType {
        case 2: return .green
        case 1: return .blue
        case 3: return .orange
        default: return .secondary
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: friend.avatarURL)) { $0.resizable().scaledToFill() } placeholder: {
                RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.2))
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(friend.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(settingsManager.paletteTextPrimary)
                    if friend.displayName != friend.name {
                        Text("@\(friend.name)")
                            .font(.system(size: 12))
                            .foregroundColor(settingsManager.paletteTextSecondary)
                    }
                    PresenceBadge(type: friend.userPresenceType)
                }
                Text(presenceText)
                    .font(.system(size: 12))
                    .foregroundColor(presenceColor)
                    .lineLimit(1)
            }
            Spacer()
            if friend.userPresenceType == 2, let _ = friend.placeId {
                Button("Join") { }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(settingsManager.paletteSurface.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct PresenceBadge: View {
    let type: Int
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color.opacity(0.8))
                .clipShape(Capsule())
        }
    }
    private var label: String { type == 2 ? "In-Game" : (type == 1 ? "Online" : (type == 3 ? "Studio" : "Offline")) }
    private var color: Color { type == 2 ? .green : (type == 1 ? .blue : (type == 3 ? .orange : .gray)) }
}

private enum FriendsFilter: CaseIterable { case all, online, ingame, offline
    var displayName: String { switch self { case .all: return "All"; case .online: return "Online"; case .ingame: return "In-Game"; case .offline: return "Offline" } }
}

#Preview {
    ContentView()
        .environmentObject(AccountManager())
        .environmentObject(GameManager())
        .environmentObject(SettingsManager())
        .frame(width: 1200, height: 800)
}
