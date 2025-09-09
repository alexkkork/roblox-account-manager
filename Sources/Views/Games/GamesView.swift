import SwiftUI
import Combine

struct GamesView: View {
    @EnvironmentObject private var gameManager: GameManager
    @EnvironmentObject private var accountManager: AccountManager
    @EnvironmentObject private var multiLauncher: MultiLauncher
    @EnvironmentObject private var settingsManager: SettingsManager
    
    @State private var searchText = ""
    @State private var selectedCategory: GameCategory = .search
    @State private var filterCriteria = GameFilterCriteria()
    @State private var showingFilters = false
    @State private var selectedGame: Game?
    @State private var showingGameDetail = false
    @State private var showingJoinURLBuilder = false
    @State private var lastSearchValue = ""
    
    private var displayedGames: [Game] {
        switch selectedCategory {
        case .popular:
            return gameManager.games
        case .favorites:
            return gameManager.favoriteGames
        case .recent:
            return gameManager.recentlyPlayed
        case .search:
            return gameManager.searchResults
        case .genre(let genre):
            return gameManager.getGamesByGenre(genre)
        case .trending:
            return gameManager.getTrendingGames()
        case .topRated:
            return []
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Search and categories
            searchAndCategoriesView
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            
            // Games content
            if gameManager.isLoading && displayedGames.isEmpty {
                loadingView
            } else if displayedGames.isEmpty {
                emptyStateView
            } else {
                gamesGridView
                    .overlay(alignment: .topTrailing) {
                        if gameManager.isLoading {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Updating…")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .padding(8)
                            .background(
                                Capsule()
                                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.9))
                            )
                            .padding(12)
                        }
                    }
            }
        }
        .background(Color.clear)
        .navigationTitle("Games")
        .sheet(item: $selectedGame) { game in
            ZStack {
                Color.clear.ignoresSafeArea()
                GameDetailView(game: game)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .environmentObject(gameManager)
                    .environmentObject(accountManager)
                    .environmentObject(multiLauncher)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showingJoinURLBuilder) {
            if let game = selectedGame {
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
        .sheet(isPresented: $showingFilters) {
            ZStack {
                Color.clear.ignoresSafeArea()
                GameFiltersView(criteria: $filterCriteria)
                    .environmentObject(settingsManager)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            // Start in search mode; no auto-load
        }
        .onReceive(Just(searchText).delay(for: .milliseconds(600), scheduler: RunLoop.main)) { newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed != lastSearchValue else { return }
            lastSearchValue = trimmed
            if selectedCategory == .search && trimmed.count >= 2 {
                gameManager.searchGames(query: trimmed)
            } else if trimmed.isEmpty {
                gameManager.searchResults = []
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("Games")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("\(displayedGames.count) games • \(gameManager.favoriteGames.count) favorites")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Quick actions
            HStack(spacing: 12) {
                // Filters button
                Button(action: { showingFilters = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 16, weight: .medium))
                        Text("Filters")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Refresh button
                Button(action: {
                    switch selectedCategory {
                    case .search:
                        if !searchText.isEmpty { gameManager.searchGames(query: searchText) }
                    case .trending, .popular:
                        Task { await gameManager.refreshTrending() }
                    default:
                        break
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(gameManager.isLoading ? settingsManager.currentAccentColor : .secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(gameManager.isLoading)
                
                // Join URL Builder
                Button(action: { showingJoinURLBuilder = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "link")
                            .font(.system(size: 14, weight: .semibold))
                        Text("URL Builder")
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
                .disabled(selectedGame == nil)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial)
    }
    
    private var searchAndCategoriesView: some View {
        VStack(spacing: 16) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search games...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onSubmit {
                        if !searchText.isEmpty {
                            selectedCategory = .search
                            gameManager.searchGames(query: searchText)
                        }
                    }
                
                if !searchText.isEmpty {
                    Button(action: { 
                        searchText = ""
                        selectedCategory = .search
                        gameManager.searchResults = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                if gameManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            
            // Categories
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach([GameCategory.search, .favorites, .recent, .trending], id: \.self) { category in
                        CategoryButton(
                            category: category,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                            
                            switch category {
                            case .search:
                                if !searchText.isEmpty {
                                    gameManager.searchGames(query: searchText)
                                }
                            case .trending, .popular:
                                Task { await gameManager.refreshTrending() }
                            default:
                                break
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: selectedCategory.emptyStateIcon)
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))
            
            VStack(spacing: 8) {
                Text(selectedCategory.emptyStateTitle)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(selectedCategory.emptyStateMessage)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if selectedCategory == .search {
                Button("Search Games") {
                    if !searchText.isEmpty {
                        gameManager.searchGames(query: searchText)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading games…")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var gamesGridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 300, maximum: 360), spacing: 20)
            ], spacing: 20) {
                ForEach(displayedGames) { game in
                    GameCard(
                        game: game,
                        isSelected: selectedGame?.id == game.id,
                        isFavorite: gameManager.isFavorite(game)
                    ) {
                        selectedGame = game
                        gameManager.selectGame(game)
                    } onToggleFavorite: {
                        gameManager.toggleFavorite(game)
                    } onLaunch: { flavor in
                        if let account = accountManager.selectedAccount {
                            multiLauncher.launchGame(account: account, game: game, flavor: flavor)
                        }
                    } onShowDetail: {
                        selectedGame = game
                        showingGameDetail = true
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}

extension View {
	var anyView: AnyView { AnyView(self) }
}

// MARK: - Game Category

enum GameCategory: Hashable, CaseIterable {
    case popular
    case favorites
    case recent
    case search
    case trending
    case topRated
    case genre(GameGenre)
    
    static var allCases: [GameCategory] {
        return [.popular, .favorites, .recent, .search, .trending, .topRated] +
               GameGenre.allCases.map { .genre($0) }
    }
    
    var displayName: String {
        switch self {
        case .popular: return "Popular"
        case .favorites: return "Favorites"
        case .recent: return "Recent"
        case .search: return "Search"
        case .trending: return "Trending"
        case .topRated: return "Top Rated"
        case .genre(let genre): return genre.displayName
        }
    }
    
    var iconName: String {
        switch self {
        case .popular: return "flame.fill"
        case .favorites: return "heart.fill"
        case .recent: return "clock.fill"
        case .search: return "magnifyingglass"
        case .trending: return "chart.line.uptrend.xyaxis"
        case .topRated: return "star.fill"
        case .genre(let genre): return genre.iconName
        }
    }
    
    var emptyStateIcon: String {
        switch self {
        case .popular: return "gamecontroller"
        case .favorites: return "heart"
        case .recent: return "clock"
        case .search: return "magnifyingglass"
        case .trending: return "chart.line.uptrend.xyaxis"
        case .topRated: return "star"
        case .genre: return "gamecontroller"
        }
    }
    
    var emptyStateTitle: String {
        switch self {
        case .popular: return "No Trending Games"
        case .favorites: return "No Favorite Games"
        case .recent: return "No Recent Games"
        case .search: return "No Search Results"
        case .trending: return "No Trending Games"
        case .topRated: return "No Top Rated Games"
        case .genre(let genre): return "No \(genre.displayName) Games"
        }
    }
    
    var emptyStateMessage: String {
        switch self {
        case .popular: return "Try refreshing to load trending games"
        case .favorites: return "Mark games as favorites to see them here"
        case .recent: return "Games you've played recently will appear here"
        case .search: return "Try different search terms"
        case .trending: return "No trending games available right now"
        case .topRated: return "No top rated games available"
        case .genre: return "No games found in this genre"
        }
    }
}

// MARK: - Category Button

struct CategoryButton: View {
    let category: GameCategory
    let isSelected: Bool
    let action: () -> Void
    
    @EnvironmentObject private var settingsManager: SettingsManager
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: category.iconName)
                    .font(.system(size: 14, weight: .medium))
                
                Text(category.displayName)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : settingsManager.currentAccentColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? settingsManager.currentAccentColor : settingsManager.currentAccentColor.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(settingsManager.getSpringAnimation(for: .quick), value: isSelected)
    }
}

// MARK: - Game Card

struct GameCard: View {
    let game: Game
    let isSelected: Bool
    let isFavorite: Bool
    let onSelect: () -> Void
    let onToggleFavorite: () -> Void
    let onLaunch: (RobloxFlavor) -> Void
    let onShowDetail: () -> Void
    
    @EnvironmentObject private var settingsManager: SettingsManager
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 0) {
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
                            .font(.system(size: 32))
                            .foregroundColor(.secondary.opacity(0.5))
                    )
                    .aspectRatio(16/9, contentMode: .fit)
            }
            .clipped()
            .overlay(alignment: .topTrailing) {
                // Favorite button
                Button(action: onToggleFavorite) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isFavorite ? .red : .white)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(12)
                .opacity(isHovered || isFavorite ? 1.0 : 0.0)
                .animation(settingsManager.getSpringAnimation(for: .quick), value: isHovered)
                .animation(settingsManager.getSpringAnimation(for: .quick), value: isFavorite)
            }
            .overlay(alignment: .bottomTrailing) {
                // Player count
                if game.playerCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 10))
                        Text("\(game.playerCount.formatted())")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
                    .padding(12)
                }
            }
            
            // Game info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(game.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        
                        Text("by \(game.creatorName)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    if game.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 16))
                            .foregroundColor(settingsManager.currentAccentColor)
                    }
                }
                
                // Rating and genre
                HStack {
                    if game.rating > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", game.rating))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Text(game.genre.displayName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(settingsManager.currentAccentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(settingsManager.currentAccentColor.opacity(0.1))
                        )
                }
                
                // Action buttons (always occupy layout to avoid hover glitch)
                HStack(spacing: 8) {
                    Menu {
                        Button("Clean Roblox") { onLaunch(.clean) }
                        Button("Opiumware Roblox") { onLaunch(.opiumware) }
                        Button("MacSploit Roblox") { onLaunch(.macsploit) }
                        Button("Hydrogen Roblox") { onLaunch(.hydrogen) }
                    } label: {
                        Label("Launch", systemImage: "play.fill")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .menuStyle(BorderlessButtonMenuStyle())
                    
                    Button("Details") {
                        onShowDetail()
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(settingsManager.currentAccentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .stroke(settingsManager.currentAccentColor, lineWidth: 1)
                    )
                    
                    Spacer()
                }
                .opacity(isHovered || isSelected ? 1.0 : 0.0)
                .allowsHitTesting(isHovered || isSelected)
                .animation(settingsManager.getSpringAnimation(for: .quick), value: isHovered)
            }
            .padding(16)
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 12)
                    .stroke(settingsManager.currentAccentColor.opacity(0.08), lineWidth: 1)
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.02), settingsManager.currentAccentColor.opacity(0.05)],
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
        .scaleEffect(isHovered ? 1.02 : 1.0)
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

#Preview {
    GamesView()
        .environmentObject(GameManager())
        .environmentObject(AccountManager())
        .environmentObject(MultiLauncher())
        .environmentObject(SettingsManager())
        .frame(width: 1200, height: 800)
}
