import SwiftUI

struct LauncherView: View {
    @EnvironmentObject private var multiLauncher: MultiLauncher
    @EnvironmentObject private var accountManager: AccountManager
    @EnvironmentObject private var gameManager: GameManager
    @EnvironmentObject private var settingsManager: SettingsManager
    
    @State private var selectedAccounts: Set<Account> = []
    @State private var selectedGame: Game?
    @State private var showingGamePicker = false
    @State private var showingBulkLaunchSettings = false
    @State private var bulkLaunchSettings = LaunchSettings()
    @State private var selectedFlavor: RobloxFlavor = .clean
    
    private var canLaunch: Bool {
        !selectedAccounts.isEmpty && selectedGame != nil && multiLauncher.canLaunchMore()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            HStack(spacing: 24) {
                accountSelectionPanel
                    .frame(width: 300)
                
                centerPanel
                    .frame(maxWidth: .infinity)
                
                activeSessionsPanel
                    .frame(width: 280)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color.clear)
        .navigationTitle("Multi-Launcher")
        .sheet(isPresented: $showingGamePicker) {
            ZStack {
                Color.clear.ignoresSafeArea()
                GamePickerView(selectedGame: $selectedGame)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .environmentObject(gameManager)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showingBulkLaunchSettings) {
            ZStack {
                Color.clear.ignoresSafeArea()
                BulkLaunchSettingsView(settings: $bulkLaunchSettings)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .environmentObject(settingsManager)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            if let selected = accountManager.selectedAccount {
                selectedAccounts.insert(selected)
            }
            selectedGame = gameManager.selectedGame
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("Multi-Launcher")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("\(multiLauncher.activeLaunches.count) active sessions • \(multiLauncher.launchQueue.count) queued")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button("Terminate All") {
                    multiLauncher.terminateAllSessions()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
                .disabled(multiLauncher.activeLaunches.isEmpty)
                
                Button("Launch Settings") {
                    showingBulkLaunchSettings = true
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
    }
    
    private var accountSelectionPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Select Accounts")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(selectedAccounts.count) selected")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 12) {
                Button("Select All") {
                    selectedAccounts = Set(accountManager.accounts.filter { $0.isActive })
                }
                .font(.system(size: 12))
                .buttonStyle(.bordered)
                
                Button("Select None") {
                    selectedAccounts.removeAll()
                }
                .font(.system(size: 12))
                .buttonStyle(.bordered)
            }
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(accountManager.accounts.filter { $0.isActive }) { account in
                        LauncherAccountRow(
                            account: account,
                            isSelected: selectedAccounts.contains(account),
                            activeSessions: multiLauncher.getSessionsForAccount(account).filter { $0.status == .running }.count
                        ) {
                            toggleAccountSelection(account)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
    }
    
    private var centerPanel: some View {
        VStack(spacing: 24) {
            gameSelectionView
            
            launchControlsView
            
            if !multiLauncher.launchQueue.isEmpty {
                launchQueueView
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
    }
    
    private var gameSelectionView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Selected Game")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Choose Game") {
                    showingGamePicker = true
                }
                .buttonStyle(.bordered)
            }
            
            if let game = selectedGame {
                HStack(spacing: 16) {
                    AsyncImage(url: URL(string: game.thumbnailURL ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .overlay(
                                Image(systemName: "gamecontroller.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.secondary.opacity(0.5))
                            )
                            .aspectRatio(16/9, contentMode: .fit)
                    }
                    .frame(width: 120, height: 68)
                    .clipped()
                    .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(game.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        
                        Text("by \(game.creatorName)")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 12) {
                            if game.playerCount > 0 {
                                Label("\(game.playerCount.formatted())", systemImage: "person.fill")
                            }
                            
                            if game.rating > 0 {
                                Label(String(format: "%.1f", game.rating), systemImage: "star.fill")
                            }
                        }
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "gamecontroller")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text("No game selected")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Button("Choose a Game") {
                        showingGamePicker = true
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .frame(maxWidth: .infinity, minHeight: 120)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [5]))
                        )
                )
            }
        }
    }
    
    private var launchControlsView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Text("Launch As:")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Picker("Flavor", selection: $selectedFlavor) {
                    ForEach(RobloxFlavor.allCases, id: \.self) { f in
                        Text(f.displayName).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 420)
                Spacer()
            }

            Button(action: performLaunch) {
                HStack {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("Launch \(selectedAccounts.count) Account\(selectedAccounts.count == 1 ? "" : "s")")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(canLaunch ? settingsManager.currentAccentColor : Color.secondary)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!canLaunch)
            
            HStack(spacing: 12) {
                Button("Sequential Launch") {
                    performSequentialLaunch()
                }
                .font(.system(size: 14))
                .buttonStyle(.bordered)
                .disabled(!canLaunch)
                
                Button("Staggered Launch") {
                    performStaggeredLaunch()
                }
                .font(.system(size: 14))
                .buttonStyle(.bordered)
                .disabled(!canLaunch)
            }
            
            VStack(spacing: 8) {
                if !canLaunch {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.orange)
                        
                        Text(launchBlockedReason)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                
                Text("Max concurrent launches: \(settingsManager.settings.maxSimultaneousLaunches)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var launchQueueView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Launch Queue (\(multiLauncher.launchQueue.count))")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(multiLauncher.launchQueue.indices, id: \.self) { index in
                        let request = multiLauncher.launchQueue[index]
                        
                        VStack(spacing: 6) {
                            AsyncImage(url: URL(string: request.account.avatarURL ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 24, height: 24)
                            .clipShape(Circle())
                            
                            Text(request.account.displayName)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            Text("Position \(index + 1)")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(NSColor.controlBackgroundColor))
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(settingsManager.currentAccentColor.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(settingsManager.currentAccentColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var activeSessionsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Active Sessions")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(multiLauncher.getActiveSessions().count)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            if multiLauncher.activeLaunches.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "play.slash")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text("No active sessions")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(multiLauncher.activeLaunches) { session in
                            LaunchSessionRow(session: session) {
                                multiLauncher.terminateSession(session.id)
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
    }
    
    private var launchBlockedReason: String {
        if selectedAccounts.isEmpty {
            return "Select at least one account"
        } else if selectedGame == nil {
            return "Select a game to launch"
        } else if !multiLauncher.canLaunchMore() {
            return "Maximum concurrent launches reached"
        }
        return ""
    }
    
    private func toggleAccountSelection(_ account: Account) {
        if selectedAccounts.contains(account) {
            selectedAccounts.remove(account)
        } else {
            selectedAccounts.insert(account)
        }
    }
    
    private func performLaunch() {
        guard let game = selectedGame else { return }
        settingsManager.prepareMultiInstanceClones(desiredCount: max(1, selectedAccounts.count), flavor: selectedFlavor)
        openExecutorAppIfNeeded(flavor: selectedFlavor)
        
        for account in selectedAccounts {
            multiLauncher.launchGame(account: account, game: game, customSettings: bulkLaunchSettings, flavor: selectedFlavor)
        }
    }
    
    private func performSequentialLaunch() {
        guard let game = selectedGame else { return }
        
        let accounts = Array(selectedAccounts)
        for (index, account) in accounts.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 2.0) {
                multiLauncher.launchGame(account: account, game: game, customSettings: bulkLaunchSettings)
            }
        }
    }
    
    private func performStaggeredLaunch() {
        guard let game = selectedGame else { return }
        
        let accounts = Array(selectedAccounts)
        for (index, account) in accounts.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.5) {
                multiLauncher.launchGame(account: account, game: game, customSettings: bulkLaunchSettings)
            }
        }
    }

    private func openExecutorAppIfNeeded(flavor: RobloxFlavor) {
        let appPath: String?
        switch flavor {
        case .clean:
            appPath = nil
        case .opiumware:
            appPath = "/Applications/Opiumware.app"
        case .macsploit:
            appPath = "/Applications/MacSploit.app"
        case .hydrogen:
            appPath = nil
        }
        if let appPath, FileManager.default.fileExists(atPath: appPath) {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            p.arguments = ["-n", appPath]
            try? p.run()
        }
    }
}

// MARK: - Launcher Account Row

struct LauncherAccountRow: View {
    let account: Account
    let isSelected: Bool
    let activeSessions: Int
    let onToggle: () -> Void
    
    @EnvironmentObject private var settingsManager: SettingsManager
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? settingsManager.currentAccentColor : .secondary)
                
                AsyncImage(url: URL(string: account.avatarURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .frame(width: 28, height: 28)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text("@\(account.username)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        if activeSessions > 0 {
                            Text("• \(activeSessions) active")
                                .font(.system(size: 12))
                                .foregroundColor(settingsManager.currentAccentColor)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? settingsManager.currentAccentColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? settingsManager.currentAccentColor : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Launch Session Row

struct LaunchSessionRow: View {
    let session: LaunchSession
    let onTerminate: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(Color(session.status.color))
                    .frame(width: 8, height: 8)
                
                Text(session.account.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                if session.status == .running {
                    Button(action: onTerminate) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(session.game.name)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text("\(session.status.displayName) • \(session.startedAt, format: .relative(presentation: .named))")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                if let pid = session.processId, pid > 0 {
                    Text("PID: \(pid)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

#Preview {
    LauncherView()
        .environmentObject(MultiLauncher())
        .environmentObject(AccountManager())
        .environmentObject(GameManager())
        .environmentObject(SettingsManager())
        .frame(width: 1200, height: 800)
}
