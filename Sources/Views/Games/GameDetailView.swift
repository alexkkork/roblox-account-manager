import SwiftUI

struct GameDetailView: View {
    let game: Game
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var gameManager: GameManager
    @EnvironmentObject private var accountManager: AccountManager
    @EnvironmentObject private var multiLauncher: MultiLauncher
    @EnvironmentObject private var settingsManager: SettingsManager
    
    @State private var selectedAccount: Account?
    @State private var showingAccountPicker = false
    @State private var showingJoinURLBuilder = false
    
    private var isFavorite: Bool {
        gameManager.isFavorite(game)
    }
    
    private var activeSessions: [LaunchSession] {
        multiLauncher.getSessionsForGame(game)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with thumbnail and basic info
                    headerView
                    
                    // Game description
                    descriptionView
                    
                    // Statistics
                    statisticsView
                    
                    // Tags and genre
                    tagsAndGenreView
                    
                    // Active sessions
                    if !activeSessions.isEmpty {
                        activeSessionsView
                    }
                    
                    // Launch options
                    launchOptionsView
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 30)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .navigationTitle(game.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 12) {
                        // Favorite button
                        Button(action: { gameManager.toggleFavorite(game) }) {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .foregroundColor(isFavorite ? .red : .secondary)
                        }
                        
                        // Share/URL builder
                        Button("URL Builder") {
                            showingJoinURLBuilder = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        // Default navigation style on macOS
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            settingsManager.settings.beautifulMode ? AnyView(AnimatedAuroraBackground().environmentObject(settingsManager)) : AnyView(Color.clear.anyView)
        )
        .sheet(isPresented: $showingAccountPicker) {
            ZStack {
                Color.clear.ignoresSafeArea()
                AccountPickerView(selectedAccount: $selectedAccount) { account in
                    if let account = account { multiLauncher.launchGame(account: account, game: game) }
                }
                .environmentObject(accountManager)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showingJoinURLBuilder) {
            ZStack {
                Color.clear.ignoresSafeArea()
                JoinURLBuilderView(game: game)
                    .environmentObject(accountManager)
                    .environmentObject(multiLauncher)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 20) {
            // Thumbnail
            AsyncImage(url: URL(string: game.thumbnailURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .overlay(
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary.opacity(0.5))
                    )
                    .aspectRatio(16/9, contentMode: .fit)
            }
            .frame(height: 300)
            .clipped()
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            
            // Game info
            VStack(spacing: 12) {
                HStack {
                    Text(game.name)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if game.isVerified {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 20))
                                .foregroundColor(settingsManager.currentAccentColor)
                            Text("Verified")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(settingsManager.currentAccentColor)
                        }
                    }
                }
                
                HStack {
                    Text("by \(game.creatorName)")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if game.rating > 0 {
                        HStack(spacing: 6) {
                            ForEach(0..<5) { index in
                                Image(systemName: index < Int(game.rating) ? "star.fill" : "star")
                                    .font(.system(size: 14))
                                    .foregroundColor(.yellow)
                            }
                            Text(String(format: "%.1f", game.rating))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                HStack(spacing: 20) {
                    if game.playerCount > 0 {
                        Label("\(game.playerCount.formatted()) playing", systemImage: "person.fill")
                    }
                    
                    if game.maxPlayers > 0 {
                        Label("Max \(game.maxPlayers)", systemImage: "person.2.fill")
                    }
                    
                    Label("Added \(game.createdAt, format: .dateTime.day().month().year())", systemImage: "calendar")
                }
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            }
        }
    }
    
    private var descriptionView: some View {
        GameDetailSection(title: "Description", icon: "text.alignleft") {
            Text(game.description.isEmpty ? "No description available." : game.description)
                .font(.system(size: 16))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var statisticsView: some View {
        GameDetailSection(title: "Statistics", icon: "chart.bar.fill") {
            HStack(spacing: 40) {
                StatisticItem(
                    title: "Players Online",
                    value: game.playerCount.formatted(),
                    icon: "person.fill",
                    color: .green
                )
                
                StatisticItem(
                    title: "Max Players",
                    value: "\(game.maxPlayers)",
                    icon: "person.2.fill",
                    color: .blue
                )
                
                StatisticItem(
                    title: "Rating",
                    value: String(format: "%.1f", game.rating),
                    icon: "star.fill",
                    color: .yellow
                )
                
                StatisticItem(
                    title: "Times Played",
                    value: game.lastPlayed != nil ? "Recently" : "Never",
                    icon: "clock.fill",
                    color: .orange
                )
            }
        }
    }
    
    private var tagsAndGenreView: some View {
        GameDetailSection(title: "Genre & Tags", icon: "tag.fill") {
            VStack(alignment: .leading, spacing: 16) {
                // Genre
                HStack {
                    Text("Genre:")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 6) {
                        Image(systemName: game.genre.iconName)
                            .font(.system(size: 14))
                            .foregroundColor(settingsManager.currentAccentColor)
                        
                        Text(game.genre.displayName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(settingsManager.currentAccentColor)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(settingsManager.currentAccentColor.opacity(0.1))
                    )
                }
                
                // Tags
                if !game.tags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags:")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        FlowLayout(spacing: 8) {
                            ForEach(game.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(Color(NSColor.controlBackgroundColor))
                                    )
                            }
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var activeSessionsView: some View {
        GameDetailSection(title: "Active Sessions", icon: "play.circle.fill") {
            VStack(spacing: 12) {
                ForEach(activeSessions) { session in
                    HStack {
                        AsyncImage(url: URL(string: session.account.avatarURL ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.account.displayName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                            
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color(session.status.color))
                                    .frame(width: 8, height: 8)
                                
                                Text("\(session.status.displayName) • \(session.startedAt, format: .relative(presentation: .named))")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if session.status == .running {
                            Button("Terminate") {
                                multiLauncher.terminateSession(session.id)
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )
                }
            }
        }
    }
    
    private var launchOptionsView: some View {
        GameDetailSection(title: "Launch Options", icon: "play.rectangle.fill") {
            VStack(spacing: 16) {
                // Quick launch with selected account
                if let selectedAccount = accountManager.selectedAccount {
                    Menu {
                        Button("Clean Roblox") { multiLauncher.launchGame(account: selectedAccount, game: game, flavor: .clean) }
                        Button("Opiumware Roblox") { multiLauncher.launchGame(account: selectedAccount, game: game, flavor: .opiumware) }
                        Button("MacSploit Roblox") { multiLauncher.launchGame(account: selectedAccount, game: game, flavor: .macsploit) }
                        Button("Hydrogen Roblox") { multiLauncher.launchGame(account: selectedAccount, game: game, flavor: .hydrogen) }
                    } label: {
                        HStack {
                            AsyncImage(url: URL(string: selectedAccount.avatarURL ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                            }
                            .frame(width: 24, height: 24)
                            .clipShape(Circle())
                            
                            Text("Launch with \(selectedAccount.displayName)")
                                .font(.system(size: 16, weight: .semibold))
                            
                            Spacer()
                            
                            Image(systemName: "play.fill")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(settingsManager.currentAccentColor)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Launch with different account
                Button("Choose Account to Launch") {
                    showingAccountPicker = true
                }
                .buttonStyle(.bordered)
                
                // URL builder
                Button("Build Custom Join URL") {
                    showingJoinURLBuilder = true
                }
                .buttonStyle(.bordered)
                
                // Launch multiple accounts
                if accountManager.accounts.count > 1 {
                    Button("Launch Multiple Accounts") {
                        let activeAccounts = accountManager.accounts.filter { $0.isActive }
                        multiLauncher.launchMultipleAccounts(accounts: activeAccounts, game: game)
                    }
                    .buttonStyle(.bordered)
                    .disabled(accountManager.accounts.filter { $0.isActive }.count < 2)
                }
            }
        }
    }
}

// MARK: - Game Detail Section

struct GameDetailSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
    }
}

// MARK: - Statistic Item

struct StatisticItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Account Picker View

struct AccountPickerView: View {
    @Binding var selectedAccount: Account?
    let onLaunch: (Account?) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var accountManager: AccountManager
    @EnvironmentObject private var settingsManager: SettingsManager
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Choose Account")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .padding(.top, 20)
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(accountManager.accounts.filter { $0.isActive }) { account in
                            AccountRow(
                                account: account,
                                isSelected: selectedAccount?.id == account.id
                            ) {
                                selectedAccount = account
                                onLaunch(account)
                                dismiss()
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("Select Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Account Row

struct AccountRow: View {
    let account: Account
    let isSelected: Bool
    let onSelect: () -> Void
    
    @EnvironmentObject private var settingsManager: SettingsManager
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                AsyncImage(url: URL(string: account.avatarURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("@\(account.username)")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? settingsManager.currentAccentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? settingsManager.currentAccentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    GameDetailView(game: Game(id: 1, name: "Test Game", description: "A test game", creatorName: "Test Creator", creatorId: 1, placeId: 1, universeId: 1))
        .environmentObject(GameManager())
        .environmentObject(AccountManager())
        .environmentObject(MultiLauncher())
        .environmentObject(SettingsManager())
}
