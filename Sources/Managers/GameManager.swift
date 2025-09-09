import Foundation
import Combine

@MainActor
class GameManager: ObservableObject {
    @Published var games: [Game] = []
    @Published var favoriteGames: [Game] = []
    @Published var recentlyPlayed: [Game] = []
    @Published var isLoading = false
    @Published var error: AppError?
    @Published var searchResults: [Game] = []
    @Published var selectedGame: Game?
    
    private let storage = SecureStorage.shared
    private let favoritesFileName = "favorite_games.json"
    private let recentFileName = "recent_games.json"
    
    private var searchTask: Task<Void, Never>?
    
    init() {
        loadFavorites()
        loadRecentlyPlayed()
        Task { await loadPopularDefault() }
    }
    
    // MARK: - Game Search
    
    func searchGames(query: String) {
        searchTask?.cancel()
        
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        searchTask = Task {
            await performSearch(query: query)
        }
    }
    
    private func performSearch(query: String) async {
        isLoading = true
        error = nil
        
        do {
            // Prefer Omni if cookie is available (some endpoints require auth cookie)
            let cookie = (try? storage.load([Account].self, from: "accounts.json")).flatMap { $0.first?.cookie } ?? nil
            let results = try await RobloxAPIService.shared.searchGamesAuto(keyword: query, cookie: cookie)
            if !Task.isCancelled {
                searchResults = results
            }
        } catch {
            if !Task.isCancelled {
                self.error = AppError.networkError(error.localizedDescription)
            }
        }
        
        isLoading = false
    }
    
    // MARK: - Popular Default
    private func loadPopularDefault() async {
        isLoading = true
        error = nil
        do {
            let cookie = (try? storage.load([Account].self, from: "accounts.json")).flatMap { $0.first?.cookie } ?? nil
            var popular: [Game] = []
            if let cookie, !cookie.isEmpty {
                // Prefer personalized recommendation feed when cookie is available
                popular = try await RobloxAPIService.shared.getRecommendedGames(limit: 20, cookie: cookie)
            }
            if popular.isEmpty {
                popular = try await RobloxAPIService.shared.getPopularGames(sortPattern: "trending", cookie: cookie)
            }
            if !Task.isCancelled {
                games = popular
            }
        } catch {
            if !Task.isCancelled {
                self.error = AppError.networkError(error.localizedDescription)
            }
        }
        isLoading = false
    }

    // Force refresh popular/trending for callers
    func refreshTrending() async {
        await loadPopularDefault()
    }

    // MARK: - Top Rated
    func loadTopRated(topN: Int = 10) async {
        isLoading = true
        error = nil
        do {
            let cookie = (try? storage.load([Account].self, from: "accounts.json")).flatMap { $0.first?.cookie } ?? nil
            let top = try await RobloxAPIService.shared.getTopRatedGames(topN: topN, cookie: cookie)
            if !Task.isCancelled {
                games = top
            }
        } catch {
            if !Task.isCancelled {
                self.error = AppError.networkError(error.localizedDescription)
            }
        }
        isLoading = false
    }
    
    // MARK: - Game Management
    
    func selectGame(_ game: Game) {
        selectedGame = game
        // Attempt to fetch a real thumbnail/icon in the background
        Task { [weak self] in
            guard let self = self else { return }
            do {
                // Prefer universe thumbnail; fallback to place icon
                var imageURL = try await RobloxAPIService.shared.fetchGameThumbnail(for: game.universeId)
                if imageURL.isEmpty {
                    imageURL = try await RobloxAPIService.shared.fetchGameIconForPlace(placeId: game.placeId)
                }
                if !imageURL.isEmpty {
                    await MainActor.run {
                        if var current = self.selectedGame, current.id == game.id {
                            current.thumbnailURL = imageURL
                            self.selectedGame = current
                        }
                        // Also update in primary lists for consistency
                        if let idx = self.games.firstIndex(where: { $0.id == game.id }) {
                            self.games[idx].thumbnailURL = imageURL
                        }
                        if let idx = self.searchResults.firstIndex(where: { $0.id == game.id }) {
                            self.searchResults[idx].thumbnailURL = imageURL
                        }
                        if let idx = self.recentlyPlayed.firstIndex(where: { $0.id == game.id }) {
                            self.recentlyPlayed[idx].thumbnailURL = imageURL
                        }
                        if let idx = self.favoriteGames.firstIndex(where: { $0.id == game.id }) {
                            self.favoriteGames[idx].thumbnailURL = imageURL
                        }
                    }
                }
            } catch {
                // Ignore thumbnail errors; keep UI responsive
            }
        }
        addToRecentlyPlayed(game)
    }
    
    func toggleFavorite(_ game: Game) {
        if let index = favoriteGames.firstIndex(where: { $0.id == game.id }) {
            favoriteGames.remove(at: index)
        } else {
            var updatedGame = game
            updatedGame.isFavorite = true
            favoriteGames.append(updatedGame)
        }
        saveFavorites()
    }
    
    func isFavorite(_ game: Game) -> Bool {
        favoriteGames.contains { $0.id == game.id }
    }
    
    private func addToRecentlyPlayed(_ game: Game) {
        var updatedGame = game
        updatedGame.lastPlayed = Date()
        
        recentlyPlayed.removeAll { $0.id == game.id }
        recentlyPlayed.insert(updatedGame, at: 0)
        
        if recentlyPlayed.count > 20 {
            recentlyPlayed = Array(recentlyPlayed.prefix(20))
        }
        
        saveRecentlyPlayed()
    }
    
    // MARK: - Join URL Building
    
    func buildJoinURL(for game: Game, with parameters: [String: String] = [:]) -> String {
        return game.customJoinURL(with: parameters)
    }
    
    func buildPrivateServerURL(for game: Game, accessCode: String) -> String {
        return "roblox://placeId=\(game.placeId)&accessCode=\(accessCode)"
    }
    
    func buildFollowUserURL(userId: String) -> String {
        return "roblox://experiences/start?userId=\(userId)"
    }
    
    // MARK: - Game Categories
    
    func getGamesByGenre(_ genre: GameGenre) -> [Game] {
        return games.filter { $0.genre == genre }
    }
    
    func getTrendingGames() -> [Game] {
        return games.sorted { $0.playerCount > $1.playerCount }.prefix(10).map { $0 }
    }
    
    func getTopRatedGames() -> [Game] {
        return games.filter { $0.rating > 4.0 }.sorted { $0.rating > $1.rating }.prefix(10).map { $0 }
    }
    
    func getVerifiedGames() -> [Game] {
        return games.filter { $0.isVerified }
    }
    
    // MARK: - Filtering and Sorting
    
    func filterGames(by criteria: GameFilterCriteria) -> [Game] {
        var filtered = games
        
        if let genre = criteria.genre {
            filtered = filtered.filter { $0.genre == genre }
        }
        
        if let minRating = criteria.minRating {
            filtered = filtered.filter { $0.rating >= minRating }
        }
        
        if let maxPlayers = criteria.maxPlayers {
            filtered = filtered.filter { $0.maxPlayers <= maxPlayers }
        }
        
        if criteria.verifiedOnly {
            filtered = filtered.filter { $0.isVerified }
        }
        
        if !criteria.tags.isEmpty {
            filtered = filtered.filter { game in
                criteria.tags.allSatisfy { tag in
                    game.tags.contains { $0.localizedCaseInsensitiveContains(tag) }
                }
            }
        }
        
        return sortGames(filtered, by: criteria.sortType)
    }
    
    func sortGames(_ games: [Game], by sortType: GameSortType) -> [Game] {
        switch sortType {
        case .name:
            return games.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .playerCount:
            return games.sorted { $0.playerCount > $1.playerCount }
        case .rating:
            return games.sorted { $0.rating > $1.rating }
        case .createdAt:
            return games.sorted { $0.createdAt > $1.createdAt }
        case .updatedAt:
            return games.sorted { $0.updatedAt > $1.updatedAt }
        case .lastPlayed:
            return games.sorted { ($0.lastPlayed ?? Date.distantPast) > ($1.lastPlayed ?? Date.distantPast) }
        }
    }
    
    // MARK: - Persistence
    
    private func loadFavorites() {
        do {
            if storage.exists(favoritesFileName) {
                favoriteGames = try storage.load([Game].self, from: favoritesFileName)
            }
        } catch {
            self.error = AppError.loadingFailed(error.localizedDescription)
        }
    }
    
    private func saveFavorites() {
        do {
            try storage.save(favoriteGames, to: favoritesFileName)
        } catch {
            self.error = AppError.savingFailed(error.localizedDescription)
        }
    }
    
    private func loadRecentlyPlayed() {
        do {
            if storage.exists(recentFileName) {
                recentlyPlayed = try storage.load([Game].self, from: recentFileName)
            }
        } catch {
            self.error = AppError.loadingFailed(error.localizedDescription)
        }
    }
    
    private func saveRecentlyPlayed() {
        do {
            try storage.save(recentlyPlayed, to: recentFileName)
        } catch {
            self.error = AppError.savingFailed(error.localizedDescription)
        }
    }
}

// MARK: - Supporting Types

struct GameFilterCriteria {
    var genre: GameGenre?
    var minRating: Double?
    var maxPlayers: Int?
    var verifiedOnly: Bool
    var tags: [String]
    var sortType: GameSortType
    
    init() {
        self.genre = nil
        self.minRating = nil
        self.maxPlayers = nil
        self.verifiedOnly = false
        self.tags = []
        self.sortType = .playerCount
    }
}

enum GameSortType: String, CaseIterable {
    case name = "name"
    case playerCount = "playerCount"
    case rating = "rating"
    case createdAt = "createdAt"
    case updatedAt = "updatedAt"
    case lastPlayed = "lastPlayed"
    
    var displayName: String {
        switch self {
        case .name: return "Name"
        case .playerCount: return "Player Count"
        case .rating: return "Rating"
        case .createdAt: return "Date Created"
        case .updatedAt: return "Last Updated"
        case .lastPlayed: return "Last Played"
        }
    }
}

// MARK: - Roblox API Service

class RobloxAPI {
    static let shared = RobloxAPI()
    private let session = URLSession.shared
    
    private init() {}
    
    func searchGames(query: String) async throws -> [Game] {
        // Mock implementation - in real app, this would call Roblox API
        let mockGames = generateMockGames(for: query)
        try await Task.sleep(nanoseconds: 500_000_000) // Simulate network delay
        return mockGames
    }
    
    func getPopularGames() async throws -> [Game] {
        // Mock implementation - in real app, this would call Roblox API
        let mockGames = generatePopularMockGames()
        try await Task.sleep(nanoseconds: 1_000_000_000) // Simulate network delay
        return mockGames
    }
    
    private func generateMockGames(for query: String) -> [Game] {
        let gameNames = [
            "Adopt Me!", "Brookhaven RP", "Tower of Hell", "MeepCity",
            "Bloxburg", "Arsenal", "Jailbreak", "Murder Mystery 2",
            "Piggy", "Flee the Facility", "Natural Disaster Survival",
            "Work at a Pizza Place", "Royale High", "Phantom Forces"
        ]
        
        return gameNames.filter { $0.localizedCaseInsensitiveContains(query) }
            .enumerated()
            .map { index, name in
                createMockGame(id: index + 1000, name: name)
            }
    }
    
    private func generatePopularMockGames() -> [Game] {
        let popularGames = [
            ("Adopt Me!", GameGenre.other, 150000),
            ("Brookhaven RP", GameGenre.town, 120000),
            ("Tower of Hell", GameGenre.adventure, 95000),
            ("MeepCity", GameGenre.town, 85000),
            ("Bloxburg", GameGenre.town, 75000),
            ("Arsenal", GameGenre.fps, 65000),
            ("Jailbreak", GameGenre.action, 55000),
            ("Murder Mystery 2", GameGenre.horror, 45000),
            ("Piggy", GameGenre.horror, 40000),
            ("Flee the Facility", GameGenre.horror, 35000),
            ("Natural Disaster Survival", GameGenre.adventure, 30000),
            ("Work at a Pizza Place", GameGenre.town, 25000),
            ("Royale High", GameGenre.rpg, 20000),
            ("Phantom Forces", GameGenre.fps, 18000)
        ]
        
        return popularGames.enumerated().map { (index, gameData) in
            let (name, genre, playerCount) = gameData
            var game = createMockGame(id: index + 1, name: name)
            game.genre = genre
            game.playerCount = playerCount
            return game
        }
    }
    
    private func createMockGame(id: Int, name: String) -> Game {
        var game = Game(
            id: id,
            name: name,
            description: "A fun and exciting game on Roblox!",
            creatorName: "Developer\(id)",
            creatorId: id * 10,
            placeId: id * 100,
            universeId: id * 1000
        )
        
        game.playerCount = Int.random(in: 1000...100000)
        game.maxPlayers = Int.random(in: 10...50)
        game.rating = Double.random(in: 3.0...5.0)
        game.isVerified = Bool.random()
        game.tags = ["Fun", "Popular", "Multiplayer"].shuffled().prefix(Int.random(in: 1...3)).map { $0 }
        
        return game
    }
}
