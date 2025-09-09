import SwiftUI

struct StatisticsView: View {
    @EnvironmentObject private var multiLauncher: MultiLauncher
    @EnvironmentObject private var accountManager: AccountManager
    @EnvironmentObject private var gameManager: GameManager
    @EnvironmentObject private var settingsManager: SettingsManager
    
    @State private var selectedTimeRange: TimeRange = .today
    @State private var showingDetailedStats = false
    
    private var launchStats: LaunchStatistics {
        multiLauncher.getLaunchStatistics()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Time range selector
            timeRangeSelector
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            
            // Statistics content
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Overview cards
                    overviewCardsView
                    
                    // Charts section
                    chartsSection
                    
                    // Account statistics
                    accountStatsSection
                    
                    // Game statistics
                    gameStatsSection
                    
                    // Session history
                    sessionHistorySection
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .background(Color.clear)
        .navigationTitle("Statistics")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Detailed View") {
                    showingDetailedStats = true
                }
                .buttonStyle(.bordered)
            }
        }
        .sheet(isPresented: $showingDetailedStats) {
            ZStack {
                Color.clear.ignoresSafeArea()
                DetailedStatisticsView()
                    .environmentObject(multiLauncher)
                    .environmentObject(accountManager)
                    .environmentObject(gameManager)
                    .environmentObject(settingsManager)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("Statistics")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Track your usage and performance metrics")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Quick stats
            HStack(spacing: 20) {
                QuickStatItem(
                    title: "Active Sessions",
                    value: "\(launchStats.currentActiveSessions)",
                    color: .green
                )
                
                QuickStatItem(
                    title: "Success Rate",
                    value: "\(Int(launchStats.successRate * 100))%",
                    color: launchStats.successRate > 0.8 ? .green : .orange
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
    }
    
    private var timeRangeSelector: some View {
        HStack {
            Text("Time Range:")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            Spacer()
            
            HStack(spacing: 8) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Button(range.displayName) {
                        selectedTimeRange = range
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(selectedTimeRange == range ? .white : settingsManager.currentAccentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(selectedTimeRange == range ? settingsManager.currentAccentColor : settingsManager.currentAccentColor.opacity(0.1))
                    )
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    private var overviewCardsView: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(
                title: "Total Launches",
                value: "\(launchStats.totalLaunches)",
                subtitle: selectedTimeRange.displayName,
                icon: "play.rectangle.fill",
                color: settingsManager.currentAccentColor
            )
            
            StatCard(
                title: "Successful",
                value: "\(launchStats.successfulLaunches)",
                subtitle: "\(Int(launchStats.successRate * 100))% success rate",
                icon: "checkmark.circle.fill",
                color: .green
            )
            
            StatCard(
                title: "Failed",
                value: "\(launchStats.failedLaunches)",
                subtitle: "Launch failures",
                icon: "xmark.circle.fill",
                color: .red
            )
            
            StatCard(
                title: "Avg. Play Time",
                value: formatDuration(launchStats.averagePlayTime),
                subtitle: "Per session",
                icon: "clock.fill",
                color: .blue
            )
        }
    }
    
    private var chartsSection: some View {
        StatisticsSection(title: "Usage Trends", icon: "chart.line.uptrend.xyaxis") {
            VStack(spacing: 20) {
                // Launch activity chart
                LaunchActivityChart(timeRange: selectedTimeRange)
                
                // Success rate chart
                SuccessRateChart(timeRange: selectedTimeRange)
            }
        }
    }
    
    private var accountStatsSection: some View {
        StatisticsSection(title: "Account Statistics", icon: "person.3.fill") {
            VStack(spacing: 16) {
                // Most active accounts
                VStack(alignment: .leading, spacing: 12) {
                    Text("Most Active Accounts")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    ForEach(getMostActiveAccounts().prefix(5), id: \.account.id) { accountStat in
                        AccountStatRow(accountStat: accountStat)
                    }
                }
                
                Divider()
                
                // Account distribution
                AccountDistributionView(accounts: accountManager.accounts)
            }
        }
    }
    
    private var gameStatsSection: some View {
        StatisticsSection(title: "Game Statistics", icon: "gamecontroller.fill") {
            VStack(spacing: 16) {
                // Most played games
                VStack(alignment: .leading, spacing: 12) {
                    Text("Most Played Games")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    ForEach(getMostPlayedGames().prefix(5), id: \.game.id) { gameStat in
                        GameStatRow(gameStat: gameStat)
                    }
                }
                
                Divider()
                
                // Game genre distribution
                GameGenreDistributionView(games: gameManager.recentlyPlayed)
            }
        }
    }
    
    private var sessionHistorySection: some View {
        StatisticsSection(title: "Recent Sessions", icon: "clock.arrow.circlepath") {
            VStack(spacing: 12) {
                ForEach(getRecentSessions().prefix(10)) { session in
                    SessionHistoryRow(session: session)
                }
                
                if getRecentSessions().count > 10 {
                    Button("View All Sessions") {
                        showingDetailedStats = true
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(settingsManager.currentAccentColor)
                    .padding(.top, 8)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getMostActiveAccounts() -> [AccountStatistic] {
        return accountManager.accounts.map { account in
            let sessions = multiLauncher.activeLaunches.filter { $0.account.id == account.id }
            return AccountStatistic(
                account: account,
                sessionCount: sessions.count,
                totalPlayTime: sessions.compactMap { $0.duration }.reduce(0, +),
                averagePlayTime: sessions.compactMap { $0.duration }.reduce(0, +) / max(1, Double(sessions.count))
            )
        }.sorted { $0.sessionCount > $1.sessionCount }
    }
    
    private func getMostPlayedGames() -> [GameStatistic] {
        let gameStats = Dictionary(grouping: multiLauncher.activeLaunches) { $0.game.id }
            .mapValues { sessions in
                GameStatistic(
                    game: sessions.first!.game,
                    sessionCount: sessions.count,
                    totalPlayTime: sessions.compactMap { $0.duration }.reduce(0, +),
                    uniquePlayers: Set(sessions.map { $0.account.id }).count
                )
            }
        
        return Array(gameStats.values).sorted { $0.sessionCount > $1.sessionCount }
    }
    
    private func getRecentSessions() -> [LaunchSession] {
        return multiLauncher.activeLaunches
            .sorted { $0.startedAt > $1.startedAt }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Supporting Types

enum TimeRange: String, CaseIterable {
    case today = "today"
    case week = "week"
    case month = "month"
    case year = "year"
    case all = "all"
    
    var displayName: String {
        switch self {
        case .today: return "Today"
        case .week: return "This Week"
        case .month: return "This Month"
        case .year: return "This Year"
        case .all: return "All Time"
        }
    }
}

struct AccountStatistic {
    let account: Account
    let sessionCount: Int
    let totalPlayTime: TimeInterval
    let averagePlayTime: TimeInterval
}

struct GameStatistic {
    let game: Game
    let sessionCount: Int
    let totalPlayTime: TimeInterval
    let uniquePlayers: Int
}

// MARK: - Quick Stat Item

struct QuickStatItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(color)
                
                Spacer()
                
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Statistics Section

struct StatisticsSection<Content: View>: View {
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

// MARK: - Account Stat Row

struct AccountStatRow: View {
    let accountStat: AccountStatistic
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: accountStat.account.avatarURL ?? "")) { image in
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
                Text(accountStat.account.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("\(accountStat.sessionCount) sessions • \(formatDuration(accountStat.totalPlayTime)) total")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(formatDuration(accountStat.averagePlayTime)) avg")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let hours = minutes / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes % 60)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Game Stat Row

struct GameStatRow: View {
    let gameStat: GameStatistic
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: gameStat.game.thumbnailURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .overlay(
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary.opacity(0.5))
                        )
            }
            .frame(width: 48, height: 27)
            .clipped()
            .cornerRadius(6)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(gameStat.game.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text("\(gameStat.sessionCount) sessions • \(gameStat.uniquePlayers) players")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(formatDuration(gameStat.totalPlayTime))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let hours = minutes / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes % 60)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Session History Row

struct SessionHistoryRow: View {
    let session: LaunchSession
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(session.status.color))
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(session.account.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text("→")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Text(session.game.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                
                Text("\(session.status.displayName) • \(session.startedAt, format: .relative(presentation: .named))")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let duration = session.duration {
                Text(formatDuration(duration))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let hours = minutes / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes % 60)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Placeholder Chart Views

struct LaunchActivityChart: View {
    let timeRange: TimeRange
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Launch Activity")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            Rectangle()
                .fill(Color.secondary.opacity(0.1))
                .frame(height: 200)
                .overlay(
                    Text("Chart visualization would go here")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                )
                .cornerRadius(8)
        }
    }
}

struct SuccessRateChart: View {
    let timeRange: TimeRange
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Success Rate")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            Rectangle()
                .fill(Color.secondary.opacity(0.1))
                .frame(height: 150)
                .overlay(
                    Text("Success rate chart would go here")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                )
                .cornerRadius(8)
        }
    }
}

struct AccountDistributionView: View {
    let accounts: [Account]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account Distribution")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            HStack {
                Text("Active: \(accounts.filter { $0.isActive }.count)")
                    .font(.system(size: 14))
                    .foregroundColor(.green)
                
                Text("•")
                    .foregroundColor(.secondary)
                
                Text("Inactive: \(accounts.filter { !$0.isActive }.count)")
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                
                Spacer()
                
                Text("Total: \(accounts.count)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
    }
}

struct GameGenreDistributionView: View {
    let games: [Game]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Genre Distribution")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            let genreCounts = Dictionary(grouping: games, by: { $0.genre })
                .mapValues { $0.count }
                .sorted { $0.value > $1.value }
            
            ForEach(genreCounts.prefix(3), id: \.key) { genre, count in
                HStack {
                    Image(systemName: genre.iconName)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Text(genre.displayName)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(count)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

#Preview {
    StatisticsView()
        .environmentObject(MultiLauncher())
        .environmentObject(AccountManager())
        .environmentObject(GameManager())
        .environmentObject(SettingsManager())
        .frame(width: 1200, height: 800)
}
