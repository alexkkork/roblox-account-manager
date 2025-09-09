import SwiftUI

struct AccountsView: View {
    @EnvironmentObject private var accountManager: AccountManager
    @EnvironmentObject private var multiLauncher: MultiLauncher
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var gameManager: GameManager
    
    @State private var searchText = ""
    @State private var selectedSortType: AccountSortType = .lastUsed
    @State private var showingAddAccount = false
    @State private var showingAccountDetail = false
    @State private var selectedAccount: Account?
    @State private var showingDeleteConfirmation = false
    @State private var accountToDelete: Account?
    @State private var selectedTags: [String] = []
    @State private var showActiveOnly = false
    // Quick launch picker
    @State private var pickingAccountForQuickLaunch: Account?
    @State private var quickLaunchChosenGame: Game? = nil
    @State private var pendingFlavorAccount: Account? = nil
    @State private var pendingFlavorGame: Game? = nil
    @State private var showingFlavorSheet = false
    
    private var filteredAccounts: [Account] {
        let accounts = accountManager.searchAccounts(query: searchText)
        let filtered = accountManager.filterAccounts(by: selectedTags, activeOnly: showActiveOnly)
        let intersection = Set(accounts).intersection(Set(filtered))
        return accountManager.sortAccounts(by: selectedSortType).filter { intersection.contains($0) }
    }
    
    private var allTags: [String] {
        Array(Set(accountManager.accounts.flatMap { $0.tags })).sorted()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Search and filters
            searchAndFiltersView
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            
            // Accounts list
            if filteredAccounts.isEmpty {
                emptyStateView
            } else {
                accountsListView
            }
        }
        .background(Color.clear)
        .navigationTitle("Accounts")
        .sheet(isPresented: $showingAddAccount) {
            ZStack {
                Color.clear.ignoresSafeArea()
                AddAccountView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .environmentObject(accountManager)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(item: $selectedAccount) { account in
            ZStack {
                Color.clear.ignoresSafeArea()
                AccountDetailView(account: account)
                    .environmentObject(accountManager)
                    .environmentObject(multiLauncher)
                    .environmentObject(gameManager)
                    .environmentObject(settingsManager)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showingFlavorSheet) {
            if let acc = pendingFlavorAccount, let game = pendingFlavorGame {
                ZStack {
                    Color.clear.ignoresSafeArea()
                    FlavorPickerView { flavor in
                        showingFlavorSheet = false
                        multiLauncher.launchGame(account: acc, game: game, flavor: flavor)
                        pendingFlavorAccount = nil
                        pendingFlavorGame = nil
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(item: $pickingAccountForQuickLaunch) { acc in
            ZStack {
                Color.clear.ignoresSafeArea()
                GamePickerView(selectedGame: $quickLaunchChosenGame, initialCategory: .popular) { game in
                    if let game = game {
                        multiLauncher.launchGame(account: acc, game: game)
                    }
                    pickingAccountForQuickLaunch = nil
                }
                .environmentObject(gameManager)
                .environmentObject(settingsManager)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .alert("Delete Account", isPresented: $showingDeleteConfirmation, presenting: accountToDelete) { account in
            Button("Cancel", role: .cancel) {
                accountToDelete = nil
            }
            Button("Delete", role: .destructive) {
                accountManager.deleteAccount(account)
                accountToDelete = nil
            }
        } message: { account in
            Text("Are you sure you want to delete '\(account.displayName)'? This action cannot be undone.")
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("Accounts")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("\(accountManager.accounts.count) accounts • \(accountManager.accounts.filter(\.isActive).count) active")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Quick actions
            HStack(spacing: 12) {
                // Group launch (2 accounts, triple-burst)
                Button(action: {
                    let activeAccounts = accountManager.accounts.filter { $0.isActive }
                    let firstTwo = Array(activeAccounts.prefix(2))
                    if let game = gameManager.selectedGame ?? gameManager.games.first, firstTwo.count >= 2 {
                        multiLauncher.launchGroupTripleBurst(accounts: firstTwo, game: game, bursts: 3, staggerBetweenAccountsMs: 60, delayBetweenBurstsMs: 160)
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.rectangle.on.rectangle")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Launch 2")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(settingsManager.currentAccentColor)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .help("Launch two active accounts nearly simultaneously")
                // Import/Export menu
                Menu {
                    Button("Import Accounts") {
                        importAccounts()
                    }
                    Button("Export Accounts") {
                        exportAccounts()
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up.on.square")
                        .font(.system(size: 16, weight: .medium))
                }
                .menuStyle(BorderlessButtonMenuStyle())
                
                // Add account button
                Button(action: { showingAddAccount = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Add Account")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(settingsManager.currentAccentColor)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial)
    }
    
    private var searchAndFiltersView: some View {
        VStack(spacing: 16) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search accounts...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            
            // Filters
            HStack {
                // Sort picker
                Menu {
                    ForEach(AccountSortType.allCases, id: \.self) { sortType in
                        Button(sortType.displayName) {
                            selectedSortType = sortType
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.up.arrow.down")
                        Text("Sort: \(selectedSortType.displayName)")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                }
                .menuStyle(BorderlessButtonMenuStyle())
                
                Spacer()
                
                // Active only toggle
                Toggle("Active Only", isOn: $showActiveOnly)
                    .font(.system(size: 14, weight: .medium))
                    .toggleStyle(SwitchToggleStyle(tint: settingsManager.currentAccentColor))
            }
            
            // Tag filters
            if !allTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(allTags, id: \.self) { tag in
                            TagFilterButton(
                                tag: tag,
                                isSelected: selectedTags.contains(tag)
                            ) {
                                toggleTagSelection(tag)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))
            
            VStack(spacing: 8) {
                Text(searchText.isEmpty ? "No Accounts Yet" : "No Matching Accounts")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(searchText.isEmpty ? "Add your first account to get started" : "Try adjusting your search or filters")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            if searchText.isEmpty {
                Button("Add First Account") {
                    showingAddAccount = true
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var accountsListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredAccounts) { account in
                    AccountCard(
                        account: account,
                        isSelected: accountManager.selectedAccount?.id == account.id
                    ) {
                        accountManager.selectAccount(account)
                        selectedAccount = account
                    } onToggleActive: {
                        accountManager.toggleAccountActive(account)
                    } onDelete: {
                        accountToDelete = account
                        showingDeleteConfirmation = true
                    } onLaunch: { game in
                        // Resolve quick-launch target
                        var target: Game? = game
                        if target == nil, let placeId = settingsManager.settings.defaultQuickLaunchPlaceId {
                            target = (gameManager.games + gameManager.searchResults).first { $0.placeId == placeId }
                        }
                        if target == nil {
                            target = gameManager.selectedGame ?? gameManager.games.first
                        }
                        if let resolved = target {
                            // Ask flavor first
                            selectedAccount = account
                            showFlavorMenuFor(account: account, game: resolved)
                        } else {
                            // Ask user to pick a game
                            pickingAccountForQuickLaunch = account
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
    
    private func toggleTagSelection(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.removeAll { $0 == tag }
        } else {
            selectedTags.append(tag)
        }
    }
    
    private func importAccounts() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try accountManager.importAccounts(from: url)
            } catch {
                // Handle error
                print("Import failed: \(error)")
            }
        }
    }
    
    private func exportAccounts() {
        do {
            let exportURL = try accountManager.exportAccounts()
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.json]
            panel.nameFieldStringValue = "accounts_export.json"
            
            if panel.runModal() == .OK, let saveURL = panel.url {
                try FileManager.default.moveItem(at: exportURL, to: saveURL)
            }
        } catch {
            // Handle error
            print("Export failed: \(error)")
        }
    }
}
private extension AccountsView {
    func showFlavorMenuFor(account: Account, game: Game) {
        pendingFlavorAccount = account
        pendingFlavorGame = game
        showingFlavorSheet = true
    }
}

struct FlavorPickerView: View {
    let onPick: (RobloxFlavor) -> Void
    var body: some View {
        VStack(spacing: 16) {
            Text("Choose Launch Flavor")
                .font(.system(size: 18, weight: .semibold))
            HStack(spacing: 12) {
                ForEach([RobloxFlavor.clean, .opiumware, .macsploit, .hydrogen], id: \.self) { flavor in
                    Button(action: { onPick(flavor) }) {
                        Text(label(for: flavor))
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().stroke(Color.accentColor, lineWidth: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(20)
    }
    private func label(for f: RobloxFlavor) -> String {
        switch f {
        case .clean: return "Clean Roblox"
        case .opiumware: return "Opiumware Roblox"
        case .macsploit: return "MacSploit Roblox"
        case .hydrogen: return "Hydrogen Roblox"
        }
    }
}

// MARK: - Account Card

struct AccountCard: View {
    let account: Account
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggleActive: () -> Void
    let onDelete: () -> Void
    let onLaunch: (Game?) -> Void
    
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var multiLauncher: MultiLauncher
    @State private var isHovered = false
    
    private var activeSessions: [LaunchSession] {
        multiLauncher.getSessionsForAccount(account)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Avatar
                AsyncImage(url: URL(string: account.avatarURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(account.isActive ? settingsManager.currentAccentColor : Color.secondary, lineWidth: 2)
                )
                
                // Account info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(account.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        if !account.isActive {
                            Text("INACTIVE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text("@\(account.username)")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("Last used: \(account.lastUsed, format: .relative(presentation: .named))")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        if !activeSessions.isEmpty {
                            Text("• \(activeSessions.count) active session\(activeSessions.count == 1 ? "" : "s")")
                                .font(.system(size: 12))
                                .foregroundColor(settingsManager.currentAccentColor)
                        }
                    }
                }
                
                Spacer()
                
                // Tags
                if !account.tags.isEmpty {
                    HStack {
                        ForEach(account.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(settingsManager.currentAccentColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(settingsManager.currentAccentColor.opacity(0.1))
                                )
                        }
                        
                        if account.tags.count > 3 {
                            Text("+\(account.tags.count - 3)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Actions
                HStack(spacing: 8) {
                    // Toggle active button
                    Button(action: onToggleActive) {
                        Image(systemName: account.isActive ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(account.isActive ? .orange : .green)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(account.isActive ? "Deactivate Account" : "Activate Account")
                    
                    // Quick Launch button
                    Button(action: {
                        onLaunch(nil)
                    }) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(settingsManager.currentAccentColor)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!account.isActive)
                    .help("Quick Launch (uses default game)")
                    
                    // Launch… dialog
                    Button(action: {
                        onSelect()
                    }) {
                        Text("Launch…")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(settingsManager.currentAccentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().stroke(settingsManager.currentAccentColor, lineWidth: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!account.isActive)
                    .help("Choose a game and launch")

                    // More actions menu
                    Menu {
                        Button("View Details") { onSelect() }
                        Divider()
                        Button("Delete Account", role: .destructive) { onDelete() }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .menuStyle(BorderlessButtonMenuStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            // Active sessions indicator
            if !activeSessions.isEmpty {
                HStack {
                    ForEach(activeSessions.prefix(3)) { session in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(session.status.color))
                                .frame(width: 8, height: 8)
                            
                            Text(session.game.name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color(NSColor.controlBackgroundColor))
                        )
                    }
                    
                    if activeSessions.count > 3 {
                        Text("+\(activeSessions.count - 3) more")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .opacity(isSelected ? 1.0 : 0.9)
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.02), settingsManager.currentAccentColor.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isSelected ? settingsManager.currentAccentColor : (isHovered ? Color.secondary.opacity(0.3) : Color.clear),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .shadow(color: settingsManager.currentAccentColor.opacity(isSelected ? 0.25 : (isHovered ? 0.18 : 0.1)), radius: isSelected ? 10 : (isHovered ? 8 : 4), x: 0, y: 3)
        .animation(settingsManager.getSpringAnimation(for: .quick), value: isHovered)
        .animation(settingsManager.getSpringAnimation(for: .quick), value: isSelected)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onSelect()
        }
    }
}

// MARK: - Tag Filter Button

struct TagFilterButton: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void
    
    @EnvironmentObject private var settingsManager: SettingsManager
    
    var body: some View {
        Button(action: action) {
            Text(tag)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isSelected ? .white : settingsManager.currentAccentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? settingsManager.currentAccentColor : settingsManager.currentAccentColor.opacity(0.1))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    AccountsView()
        .environmentObject(AccountManager())
        .environmentObject(MultiLauncher())
        .environmentObject(SettingsManager())
        .frame(width: 1000, height: 700)
}
