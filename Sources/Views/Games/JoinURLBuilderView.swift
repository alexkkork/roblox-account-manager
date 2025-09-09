import SwiftUI

struct JoinURLBuilderView: View {
    let game: Game
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var accountManager: AccountManager
    @EnvironmentObject private var multiLauncher: MultiLauncher
    @EnvironmentObject private var settingsManager: SettingsManager
    
    @State private var selectedAccount: Account?
    @State private var customParameters: [URLParameter] = []
    @State private var privateServerCode = ""
    @State private var followUserId = ""
    @State private var selectedURLType: URLType = .standard
    @State private var generatedURL = ""
    @State private var showingCopiedAlert = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerView
                    
                    // URL Type Selection
                    urlTypeSelectionView
                    
                    // Parameters based on type
                    parametersView
                    
                    // Custom parameters
                    customParametersView
                    
                    // Generated URL
                    generatedURLView
                    
                    // Actions
                    actionsView
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, 40)
                .padding(.vertical, 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Join URL Builder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        // macOS uses DefaultNavigationViewStyle; StackNavigationViewStyle is iOS-only
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            selectedAccount = accountManager.selectedAccount
            updateURL()
        }
        .alert("URL Copied!", isPresented: $showingCopiedAlert) {
            Button("OK") {}
        } message: {
            Text("The join URL has been copied to your clipboard.")
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 16) {
            Image(systemName: "link.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(settingsManager.currentAccentColor)
            
            Text("Join URL Builder")
                .font(.system(size: 24, weight: .bold, design: .rounded))
            
            Text("Create custom join URLs for \(game.name)")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var urlTypeSelectionView: some View {
        URLBuilderSection(title: "URL Type", icon: "link") {
            VStack(spacing: 12) {
                ForEach(URLType.allCases, id: \.self) { type in
                    URLTypeButton(
                        type: type,
                        isSelected: selectedURLType == type
                    ) {
                        selectedURLType = type
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var parametersView: some View {
        switch selectedURLType {
        case .standard:
            EmptyView()
        case .privateServer:
            privateServerView
        case .followUser:
            followUserView
        }
    }
    
    private var privateServerView: some View {
        URLBuilderSection(title: "Private Server", icon: "lock.fill") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Access Code")
                    .font(.system(size: 16, weight: .semibold))
                
                TextField("Enter private server access code", text: $privateServerCode)
                    .textFieldStyle(ModernTextFieldStyle())
                
                Text("Enter the access code for the private server you want to join.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var followUserView: some View {
        URLBuilderSection(title: "Follow User", icon: "person.fill.badge.plus") {
            VStack(alignment: .leading, spacing: 8) {
                Text("User ID")
                    .font(.system(size: 16, weight: .semibold))
                
                TextField("Enter user ID to follow", text: $followUserId)
                    .textFieldStyle(ModernTextFieldStyle())
                
                Text("Enter the Roblox user ID of the player you want to follow into the game.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var customParametersView: some View {
        URLBuilderSection(title: "Custom Parameters", icon: "slider.horizontal.3") {
            VStack(spacing: 16) {
                ForEach(customParameters.indices, id: \.self) { index in
                    HStack {
                        TextField("Parameter name", text: $customParameters[index].key)
                            .textFieldStyle(ModernTextFieldStyle())
                        
                        TextField("Value", text: $customParameters[index].value)
                            .textFieldStyle(ModernTextFieldStyle())
                        
                        Button(action: { removeParameter(at: index) }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Button("Add Parameter") {
                    addParameter()
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private var generatedURLView: some View {
        URLBuilderSection(title: "Generated URL", icon: "doc.text") {
            VStack(alignment: .leading, spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(generatedURL)
                        .font(.system(size: 12).monospaced())
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(NSColor.controlBackgroundColor))
                        )
                        .textSelection(.enabled)
                }
                
                HStack(spacing: 8) {
                    Button("Generate") { updateURL() }
                        .buttonStyle(.borderedProminent)
                    Button("Copy URL") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(generatedURL, forType: .string)
                        showingCopiedAlert = true
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Test URL") {
                        if let url = URL(string: generatedURL) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(generatedURL.isEmpty)
                }
            }
        }
    }
    
    private var actionsView: some View {
        URLBuilderSection(title: "Launch Actions", icon: "play.rectangle.fill") {
            VStack(spacing: 12) {
                if let account = selectedAccount {
                    Button(action: { launchWithURL(account: account) }) {
                        HStack {
                            AsyncImage(url: URL(string: account.avatarURL ?? "")) { image in
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
                            
                            Text("Launch with \(account.displayName)")
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
                    .disabled(generatedURL.isEmpty)
                }
                
                // Account picker
                Menu {
                    ForEach(accountManager.accounts.filter { $0.isActive }) { account in
                        Button(account.displayName) {
                            selectedAccount = account
                        }
                    }
                } label: {
                    Text("Select Different Account")
                }
                .buttonStyle(.bordered)
                
                // Launch multiple accounts
                if accountManager.accounts.filter({ $0.isActive }).count > 1 {
                    Button("Launch All Active Accounts") {
                        launchWithAllAccounts()
                    }
                    .buttonStyle(.bordered)
                    .disabled(generatedURL.isEmpty)
                }
            }
        }
    }
    
    private func updateURL() {
        Task { @MainActor in
            guard let account = selectedAccount else { generatedURL = ""; return }
            do {
                generatedURL = try await multiLauncher.buildJoinURL(account: account, game: game)
            } catch {
                generatedURL = ""
            }
        }
    }
    
    private func addParameter() {
        customParameters.append(URLParameter(key: "", value: ""))
    }
    
    private func removeParameter(at index: Int) {
        customParameters.remove(at: index)
    }
    
    private func launchWithURL(account: Account) {
        // In a real implementation, this would launch with the custom URL
        // For now, we'll use the regular launch method
        multiLauncher.launchGame(account: account, game: game)
        dismiss()
    }
    
    private func launchWithAllAccounts() {
        let activeAccounts = accountManager.accounts.filter { $0.isActive }
        multiLauncher.launchMultipleAccounts(accounts: activeAccounts, game: game)
        dismiss()
    }
}

// MARK: - Supporting Types

enum URLType: String, CaseIterable {
    case standard = "standard"
    case privateServer = "privateServer"
    case followUser = "followUser"
    
    var displayName: String {
        switch self {
        case .standard: return "Standard Join"
        case .privateServer: return "Private Server"
        case .followUser: return "Follow User"
        }
    }
    
    var description: String {
        switch self {
        case .standard: return "Join the game normally"
        case .privateServer: return "Join a private server with access code"
        case .followUser: return "Follow a specific user into the game"
        }
    }
    
    var iconName: String {
        switch self {
        case .standard: return "gamecontroller.fill"
        case .privateServer: return "lock.fill"
        case .followUser: return "person.fill.badge.plus"
        }
    }
}

struct URLParameter {
    var key: String
    var value: String
}

// MARK: - URL Builder Section

struct URLBuilderSection<Content: View>: View {
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

// MARK: - URL Type Button

struct URLTypeButton: View {
    let type: URLType
    let isSelected: Bool
    let action: () -> Void
    
    @EnvironmentObject private var settingsManager: SettingsManager
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: type.iconName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isSelected ? settingsManager.currentAccentColor : .secondary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(type.description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(settingsManager.currentAccentColor)
                }
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
    JoinURLBuilderView(game: Game(id: 1, name: "Test Game", description: "Test", creatorName: "Creator", creatorId: 1, placeId: 1, universeId: 1))
        .environmentObject(AccountManager())
        .environmentObject(MultiLauncher())
        .environmentObject(SettingsManager())
}
