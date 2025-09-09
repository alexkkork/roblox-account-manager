import Foundation

struct Game: Codable, Identifiable, Hashable {
    let id: Int
    var name: String
    var description: String
    var thumbnailURL: String?
    var creatorName: String
    var creatorId: Int
    var placeId: Int
    var universeId: Int
    var playerCount: Int
    var maxPlayers: Int
    var rating: Double
    var isVerified: Bool
    var genre: GameGenre
    var tags: [String]
    var isFavorite: Bool
    var lastPlayed: Date?
    var createdAt: Date
    var updatedAt: Date
    
    init(id: Int, name: String, description: String, creatorName: String, creatorId: Int, placeId: Int, universeId: Int) {
        self.id = id
        self.name = name
        self.description = description
        self.creatorName = creatorName
        self.creatorId = creatorId
        self.placeId = placeId
        self.universeId = universeId
        self.playerCount = 0
        self.maxPlayers = 0
        self.rating = 0.0
        self.isVerified = false
        self.genre = .other
        self.tags = []
        self.isFavorite = false
        self.lastPlayed = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    var joinURL: String {
        return "roblox://placeId=\(placeId)"
    }
    
    func customJoinURL(with parameters: [String: String] = [:]) -> String {
        var url = joinURL
        if !parameters.isEmpty {
            let queryItems = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            url += "&\(queryItems)"
        }
        return url
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Game, rhs: Game) -> Bool {
        lhs.id == rhs.id
    }
}

enum GameGenre: String, Codable, CaseIterable {
    case action = "Action"
    case adventure = "Adventure"
    case fighting = "Fighting"
    case fps = "FPS"
    case horror = "Horror"
    case medieval = "Medieval"
    case military = "Military"
    case naval = "Naval"
    case rpg = "RPG"
    case sciFi = "Sci-Fi"
    case sports = "Sports"
    case town = "Town and City"
    case tutorial = "Tutorial"
    case western = "Western"
    case other = "Other"
    
    var displayName: String {
        return self.rawValue
    }
    
    var iconName: String {
        switch self {
        case .action: return "bolt.fill"
        case .adventure: return "map.fill"
        case .fighting: return "figure.boxing"
        case .fps: return "scope"
        case .horror: return "moon.fill"
        case .medieval: return "shield.fill"
        case .military: return "star.fill"
        case .naval: return "sailboat.fill"
        case .rpg: return "person.fill"
        case .sciFi: return "sparkles"
        case .sports: return "sportscourt.fill"
        case .town: return "building.2.fill"
        case .tutorial: return "graduationcap.fill"
        case .western: return "star.circle.fill"
        case .other: return "gamecontroller.fill"
        }
    }
}
