import Foundation

struct Account: Codable, Identifiable, Hashable {
    let id = UUID()
    var username: String
    var displayName: String
    var cookie: String
    var avatarURL: String?
    var isActive: Bool
    var lastUsed: Date
    var createdAt: Date
    var tags: [String]
    var customLaunchSettings: LaunchSettings
    
    init(username: String, displayName: String, cookie: String, avatarURL: String? = nil) {
        self.username = username
        self.displayName = displayName
        self.cookie = cookie
        self.avatarURL = avatarURL
        self.isActive = true
        self.lastUsed = Date()
        self.createdAt = Date()
        self.tags = []
        self.customLaunchSettings = LaunchSettings()
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Account, rhs: Account) -> Bool {
        lhs.id == rhs.id
    }
}

struct LaunchSettings: Codable {
    var windowSize: WindowSize
    var startPosition: WindowPosition
    var autoJoin: Bool
    var customFlags: [String]
    
    init() {
        self.windowSize = WindowSize(width: 1920, height: 1080)
        self.startPosition = WindowPosition.center
        self.autoJoin = true
        self.customFlags = []
    }
}

struct WindowSize: Codable {
    var width: Int
    var height: Int
}

enum WindowPosition: String, Codable, CaseIterable {
    case center = "center"
    case topLeft = "topLeft"
    case topRight = "topRight"
    case bottomLeft = "bottomLeft"
    case bottomRight = "bottomRight"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .center: return "Center"
        case .topLeft: return "Top Left"
        case .topRight: return "Top Right"
        case .bottomLeft: return "Bottom Left"
        case .bottomRight: return "Bottom Right"
        case .custom: return "Custom"
        }
    }
}
