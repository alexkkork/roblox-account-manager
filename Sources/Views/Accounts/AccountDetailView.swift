import SwiftUI

struct AccountDetailView: View {
    let account: Account
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var accountManager: AccountManager
    @EnvironmentObject private var multiLauncher: MultiLauncher
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var gameManager: GameManager
    
    @State private var editedAccount: Account
    @State private var isEditing = false
    @State private var showingDeleteConfirmation = false
    @State private var showingLaunchSettings = false
    
    init(account: Account) {
        self.account = account
        self._editedAccount = State(initialValue: account)
    }
    
    private var activeSessions: [LaunchSession] {
        multiLauncher.getSessionsForAccount(account)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    quickLaunchSection
                    // Header with avatar and basic info
                    headerView
                    
                    // Account details
                    if isEditing {
                        editingView
                    } else {
                        detailsView
                    }
                    
                    // Active sessions
                    if !activeSessions.isEmpty {
                        activeSessionsView
                    }
                    
                    // Launch settings
                    launchSettingsView
                    
                    // Danger zone
                    dangerZoneView
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 30)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .navigationTitle(account.displayName)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    if isEditing {
                        HStack {
                            Button("Cancel") {
                                cancelEditing()
                            }
                            
                            Button("Save") {
                                saveChanges()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else {
                        Button("Edit") {
                            startEditing()
                        }
                    }
                }
            }
        }
        // Default navigation style on macOS
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            settingsManager.settings.beautifulMode ? AnyView(AnimatedAuroraBackground().environmentObject(settingsManager)) : AnyView(Color.clear.anyView)
        )
        .frame(minWidth: 900, minHeight: 700)
        .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                accountManager.deleteAccount(account)
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete '\(account.displayName)'? This action cannot be undone.")
        }
        .sheet(isPresented: $showingLaunchSettings) {
            ZStack {
                Color.clear.ignoresSafeArea()
                LaunchSettingsView(account: editedAccount) { updatedSettings in
                    editedAccount.customLaunchSettings = updatedSettings
                    if !isEditing { accountManager.updateAccount(editedAccount) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Quick Launch Section
    private var quickLaunchSection: some View {
        DetailSection(title: "Quick Launch", icon: "play.fill") {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Button {
                        if let placeId = settingsManager.settings.defaultQuickLaunchPlaceId,
                           let game = (gameManager.games + gameManager.searchResults).first(where: { $0.placeId == placeId }) {
                            multiLauncher.launchGame(account: account, game: game)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                            Text("Quick Launch")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(settingsManager.currentAccentColor))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!account.isActive || settingsManager.settings.defaultQuickLaunchPlaceId == nil)
                    
                    Spacer()
                    
                    Menu {
                        Button("None") { settingsManager.setDefaultQuickLaunch(game: nil) }
                        Divider()
                        ForEach((gameManager.games + gameManager.searchResults).prefix(20)) { game in
                            Button(action: { settingsManager.setDefaultQuickLaunch(game: game) }) {
                                Text(game.name)
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "star")
                            Text(settingsManager.settings.defaultQuickLaunchName ?? "Default game")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(settingsManager.currentAccentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().stroke(settingsManager.currentAccentColor, lineWidth: 1))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Trending grid preview
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(gameManager.games.prefix(10)) { game in
                            HStack(spacing: 8) {
                                AsyncImage(url: URL(string: game.thumbnailURL ?? "")) { img in
                                    img.resizable().aspectRatio(1, contentMode: .fill)
                                } placeholder: {
                                    Rectangle().fill(Color.secondary.opacity(0.2))
                                }
                                .frame(width: 36, height: 36)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(game.name).font(.system(size: 12)).lineLimit(1)
                                    Text(game.creatorName).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                settingsManager.setDefaultQuickLaunch(game: game)
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                }
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 20) {
            // Avatar
            AsyncImage(url: URL(string: account.avatarURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.secondary)
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [settingsManager.currentAccentColor, settingsManager.currentAccentColor.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 4
                    )
            )
            .shadow(color: settingsManager.currentAccentColor.opacity(0.3), radius: 10, x: 0, y: 5)
            
            // Basic info
            VStack(spacing: 8) {
                HStack {
                    Text(account.displayName)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    if !account.isActive {
                        Text("INACTIVE")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                }
                
                Text("@\(account.username)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 16) {
                    Label("Added \(account.createdAt, format: .dateTime.day().month().year())", systemImage: "calendar")
                    Label("Last used \(account.lastUsed, format: .relative(presentation: .named))", systemImage: "clock")
                }
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var detailsView: some View {
        VStack(spacing: 20) {
            
            if !account.tags.isEmpty {
                DetailSection(title: "Tags", icon: "tag.fill") {
                    FlowLayout(spacing: 8) {
                        ForEach(account.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(settingsManager.currentAccentColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(settingsManager.currentAccentColor.opacity(0.1))
                                )
                        }
                    }
                }
            }
            
            
            
            
            DetailSection(title: "Statistics", icon: "chart.bar.fill") {
                HStack(spacing: 24) {
                    StatItem(title: "Total Sessions", value: "\(activeSessions.count)")
                    StatItem(title: "Active Now", value: "\(activeSessions.filter { $0.status == .running }.count)")
                    StatItem(title: "Account Age", value: "\(daysSinceCreation) days")
                }
            }
        }
    }
    
    @ViewBuilder
    private var editingView: some View {
        VStack(spacing: 20) {
            
            DetailSection(title: "Display Name", icon: "person.fill") {
                TextField("Display name", text: $editedAccount.displayName)
                    .textFieldStyle(ModernTextFieldStyle())
            }
            
            
            DetailSection(title: "Tags", icon: "tag.fill") {
                TextField("Comma-separated tags", text: .constant(editedAccount.tags.joined(separator: ", ")))
                    .textFieldStyle(ModernTextFieldStyle())
            }
            
            
            
            
            DetailSection(title: "Status", icon: "power") {
                Toggle("Active Account", isOn: $editedAccount.isActive)
                    .toggleStyle(SwitchToggleStyle(tint: settingsManager.currentAccentColor))
            }
        }
    }
    
    @ViewBuilder
    private var activeSessionsView: some View {
        DetailSection(title: "Active Sessions", icon: "play.circle.fill") {
            VStack(spacing: 12) {
                ForEach(activeSessions) { session in
                    SessionRow(session: session) {
                        multiLauncher.terminateSession(session.id)
                    }
                }
            }
        }
    }
    
    private var launchSettingsView: some View {
        DetailSection(title: "Launch Settings", icon: "gearshape.fill") {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Window Size")
                            .font(.system(size: 14, weight: .semibold))
                        Text("\(account.customLaunchSettings.windowSize.width) × \(account.customLaunchSettings.windowSize.height)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Position")
                            .font(.system(size: 14, weight: .semibold))
                        Text(account.customLaunchSettings.startPosition.displayName)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                Button("Configure Launch Settings") {
                    showingLaunchSettings = true
                }
                .buttonStyle(.bordered)

                
                HStack(spacing: 10) {
                    Button {
                        
                        if let placeId = settingsManager.settings.defaultQuickLaunchPlaceId,
                           let game = (gameManager.games + gameManager.searchResults).first(where: { $0.placeId == placeId }) {
                            multiLauncher.launchGame(account: account, game: game)
                        } else {
                            
                            presentGamePicker()
                        }
                    } label: {
                        Label("Launch", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!account.isActive)
                }
            }
        }
    }

    private func presentGamePicker() {
        
        showingLaunchSettings = true
    }
    
    private var dangerZoneView: some View {
        DetailSection(title: "Danger Zone", icon: "exclamationmark.triangle.fill", titleColor: .red) {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Delete Account")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.red)
                        Text("Permanently delete this account and all associated data")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Delete") {
                        showingDeleteConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.red.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    private var daysSinceCreation: Int {
        Calendar.current.dateComponents([.day], from: account.createdAt, to: Date()).day ?? 0
    }
    
    private func startEditing() {
        editedAccount = account
        isEditing = true
    }
    
    private func cancelEditing() {
        editedAccount = account
        isEditing = false
    }
    
    private func saveChanges() {
        accountManager.updateAccount(editedAccount)
        isEditing = false
    }
}

// MARK: - Detail Section

struct DetailSection<Content: View>: View {
    let title: String
    let icon: String
    let titleColor: Color
    @ViewBuilder let content: Content
    
    init(title: String, icon: String, titleColor: Color = .primary, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.titleColor = titleColor
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(titleColor)
                
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(titleColor)
            }
            
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
    }
}

// MARK: - Stat Item

struct StatItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: LaunchSession
    let onTerminate: () -> Void
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color(session.status.color))
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(session.game.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("\(session.status.displayName) • \(session.startedAt, format: .relative(presentation: .named))")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if session.status == .running {
                Button("Terminate") {
                    onTerminate()
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.red)
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

// MARK: - Flow Layout

struct FlowLayout: Layout {
    let spacing: CGFloat
    
    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        return layout(sizes: sizes, in: proposal.replacingUnspecifiedDimensions()).size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let offsets = layout(sizes: sizes, in: proposal.replacingUnspecifiedDimensions()).offsets
        
        for (offset, subview) in zip(offsets, subviews) {
            subview.place(at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y), proposal: .unspecified)
        }
    }
    
    private func layout(sizes: [CGSize], in size: CGSize) -> (offsets: [CGPoint], size: CGSize) {
        var offsets: [CGPoint] = []
        var currentRow: [CGSize] = []
        var currentRowWidth: CGFloat = 0
        var currentY: CGFloat = 0
        var maxWidth: CGFloat = 0
        
        for size in sizes {
            if currentRowWidth + size.width + (currentRow.isEmpty ? 0 : spacing) <= size.width || currentRow.isEmpty {
                currentRow.append(size)
                currentRowWidth += size.width + (currentRow.count > 1 ? spacing : 0)
            } else {
                // Place current row
                let rowHeight = currentRow.map(\.height).max() ?? 0
                var currentX: CGFloat = 0
                
                for rowSize in currentRow {
                    offsets.append(CGPoint(x: currentX, y: currentY))
                    currentX += rowSize.width + spacing
                }
                
                maxWidth = max(maxWidth, currentRowWidth)
                currentY += rowHeight + spacing
                
                // Start new row
                currentRow = [size]
                currentRowWidth = size.width
            }
        }
        
        // Place final row
        if !currentRow.isEmpty {
            let rowHeight = currentRow.map(\.height).max() ?? 0
            var currentX: CGFloat = 0
            
            for rowSize in currentRow {
                offsets.append(CGPoint(x: currentX, y: currentY))
                currentX += rowSize.width + spacing
            }
            
            maxWidth = max(maxWidth, currentRowWidth)
            currentY += rowHeight
        }
        
        return (offsets, CGSize(width: maxWidth, height: currentY))
    }
}

#Preview {
    AccountDetailView(account: Account(username: "testuser", displayName: "Test User", cookie: "test_cookie"))
        .environmentObject(AccountManager())
        .environmentObject(MultiLauncher())
        .environmentObject(SettingsManager())
}
