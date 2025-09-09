import SwiftUI
import Combine

struct GamePickerView: View {
    @Binding var selectedGame: Game?
    var initialCategory: GamePickerCategory = .search
    var onConfirm: ((Game?) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var gameManager: GameManager
    @EnvironmentObject private var settingsManager: SettingsManager
    
    @State private var searchText = ""
    @State private var selectedCategory: GamePickerCategory = .search
    @State private var lastSearchValue = ""
    private let allowedCategories: [GamePickerCategory] = [.popular, .search, .favorites, .recent]
    
    private var displayedGames: [Game] {
        let games: [Game]
        switch selectedCategory {
        case .popular:
            games = gameManager.games
        case .favorites:
            games = gameManager.favoriteGames
        case .recent:
            games = gameManager.recentlyPlayed
        case .search:
            games = gameManager.searchResults
        }
        
        if searchText.isEmpty {
            return games
        } else {
            return games.filter { game in
                game.name.localizedCaseInsensitiveContains(searchText) ||
                game.creatorName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBarView
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                
                // Categories
                categoriesView
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                
                // Games grid
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Choose Game")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Select") {
                        onConfirm?(selectedGame)
                        dismiss()
                    }
                    .disabled(selectedGame == nil)
                }
            }
        }
        // Default navigation style on macOS (StackNavigationViewStyle is iOS-only)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Ensure trending/popular list is available and set initial category
            if gameManager.games.isEmpty {
                Task { await gameManager.refreshTrending() }
            }
            selectedCategory = initialCategory
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
    
    private var searchBarView: some View {
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
    }
    
    private var categoriesView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(allowedCategories, id: \.self) { category in
                    CategoryChip(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                        
                        switch category {
                        case .search:
                            if !searchText.isEmpty {
                                gameManager.searchGames(query: searchText)
                            }
                        default:
                            break
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: selectedCategory.emptyIcon)
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            VStack(spacing: 8) {
                Text(selectedCategory.emptyTitle)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(selectedCategory.emptyMessage)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if selectedCategory == .search && !searchText.isEmpty {
                Button("Search") {
                    gameManager.searchGames(query: searchText)
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
                GridItem(.adaptive(minimum: 200, maximum: 240), spacing: 16)
            ], spacing: 16) {
                ForEach(displayedGames) { game in
                    GamePickerCard(
                        game: game,
                        isSelected: selectedGame?.id == game.id
                    ) {
                        selectedGame = game
                        gameManager.selectGame(game)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Game Picker Category

enum GamePickerCategory: String, CaseIterable {
    case popular = "popular"
    case favorites = "favorites"
    case recent = "recent"
    case search = "search"
    
    var displayName: String {
        switch self {
        case .popular: return "Popular"
        case .favorites: return "Favorites"
        case .recent: return "Recent"
        case .search: return "Search"
        }
    }
    
    var iconName: String {
        switch self {
        case .popular: return "flame.fill"
        case .favorites: return "heart.fill"
        case .recent: return "clock.fill"
        case .search: return "magnifyingglass"
        }
    }
    
    var emptyIcon: String {
        switch self {
        case .popular: return "gamecontroller"
        case .favorites: return "heart"
        case .recent: return "clock"
        case .search: return "magnifyingglass"
        }
    }
    
    var emptyTitle: String {
        switch self {
        case .popular: return "No Popular Games"
        case .favorites: return "No Favorite Games"
        case .recent: return "No Recent Games"
        case .search: return "No Search Results"
        }
    }
    
    var emptyMessage: String {
        switch self {
        case .popular: return "Load popular games to see them here"
        case .favorites: return "Favorite games will appear here"
        case .recent: return "Recently played games will appear here"
        case .search: return "Try different search terms"
        }
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let category: GamePickerCategory
    let isSelected: Bool
    let action: () -> Void
    
    @EnvironmentObject private var settingsManager: SettingsManager
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.iconName)
                    .font(.system(size: 12, weight: .medium))
                
                Text(category.displayName)
                    .font(.system(size: 14, weight: .medium))
            }
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

// MARK: - Game Picker Card

struct GamePickerCard: View {
    let game: Game
    let isSelected: Bool
    let onSelect: () -> Void
    
    @EnvironmentObject private var settingsManager: SettingsManager
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
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
                                .font(.system(size: 24))
                                .foregroundColor(.secondary.opacity(0.5))
                        )
                        .aspectRatio(16/9, contentMode: .fit)
                }
                .clipped()
                .overlay(alignment: .bottomTrailing) {
                    // Player count
                    if game.playerCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 8))
                            Text("\(game.playerCount.formatted())")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                        )
                        .padding(8)
                    }
                }
                
                // Game info
                VStack(alignment: .leading, spacing: 6) {
                    Text(game.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text("by \(game.creatorName)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    HStack {
                        if game.rating > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.yellow)
                                Text(String(format: "%.1f", game.rating))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(settingsManager.currentAccentColor)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isSelected ? settingsManager.currentAccentColor : (isHovered ? Color.secondary.opacity(0.3) : Color.clear),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .shadow(color: .black.opacity(isHovered ? 0.1 : 0.05), radius: isHovered ? 6 : 3, x: 0, y: 2)
        .animation(settingsManager.getSpringAnimation(for: .quick), value: isHovered)
        .animation(settingsManager.getSpringAnimation(for: .quick), value: isSelected)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    GamePickerView(selectedGame: .constant(nil))
        .environmentObject(GameManager())
        .environmentObject(SettingsManager())
}
