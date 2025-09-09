import Foundation
import SwiftUI

struct AppSettings: Codable {
    var theme: AppTheme
    var accentColor: AccentColorOption
    var enableAnimations: Bool
    var animationPreset: AnimationPreset
    // Beautiful Mode: enables enhanced visuals and richer animations
    var beautifulMode: Bool
    var enableNotifications: Bool
    var autoLaunchOnStartup: Bool
    var defaultLaunchSettings: LaunchSettings
    var maxSimultaneousLaunches: Int
    var enableSoundEffects: Bool
    var enableHapticFeedback: Bool
    var dataStoragePath: String
    var encryptionEnabled: Bool
    var autoBackup: Bool
    var backupInterval: BackupInterval
    var language: AppLanguage
    var windowBehavior: WindowBehavior
    var backgroundStyle: BackgroundStyle
    var enablePatternOverlay: Bool
    var uiPalette: ThemePalette
    // Custom gradient
    var useCustomGradient: Bool
    var customGradientStartHex: String
    var customGradientEndHex: String
    var customGradientAngleDegrees: Double
    
    var defaultQuickLaunchPlaceId: Int?
    var defaultQuickLaunchUniverseId: Int?
    var defaultQuickLaunchName: String?
    var defaultQuickLaunchIconURL: String?
    
    var executorsInstallDirectory: String
    var executors: [Executor]
    
    var executorAssignmentsByInstance: [Int: UUID]
    
    var robloxClonesDirectory: String
    
    init() {
        self.theme = .system
        self.accentColor = .blue
        self.enableAnimations = true
        self.animationPreset = .balanced
        self.beautifulMode = false
        self.enableNotifications = true
        self.autoLaunchOnStartup = false
        self.defaultLaunchSettings = LaunchSettings()
        self.maxSimultaneousLaunches = 5
        self.enableSoundEffects = true
        self.enableHapticFeedback = true
        self.dataStoragePath = ""
        self.encryptionEnabled = true
        self.autoBackup = true
        self.backupInterval = .daily
        self.language = .english
        self.windowBehavior = .normal
        self.backgroundStyle = .classic
        self.enablePatternOverlay = false
        self.uiPalette = .system
        self.useCustomGradient = false
        self.customGradientStartHex = "#1E90FF" // DodgerBlue
        self.customGradientEndHex = "#4B0082"   // Indigo
        self.customGradientAngleDegrees = 45
        self.defaultQuickLaunchPlaceId = nil
        self.defaultQuickLaunchUniverseId = nil
        self.defaultQuickLaunchName = nil
        self.defaultQuickLaunchIconURL = nil
        self.executorsInstallDirectory = ""
        self.executors = []
        self.executorAssignmentsByInstance = [:]
        self.robloxClonesDirectory = ""
    }
}

// MARK: - Executors

struct Executor: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    
    var installURLString: String
    
    var installedPath: String?
    
    var dylibRelativePaths: [String]
    init(id: UUID = UUID(), name: String, installURLString: String, installedPath: String? = nil, dylibRelativePaths: [String] = []) {
        self.id = id
        self.name = name
        self.installURLString = installURLString
        self.installedPath = installedPath
        self.dylibRelativePaths = dylibRelativePaths
    }
}

enum AppTheme: String, Codable, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

// MARK: - Background Style

enum BackgroundStyle: String, Codable, CaseIterable {
    case plain = "plain"
    case classic = "classic" // subtle gradient
    case vibrant = "vibrant" // stronger gradient
    case material = "material"
    case pattern = "pattern"
    
    var displayName: String {
        switch self {
        case .plain: return "Plain"
        case .classic: return "Classic"
        case .vibrant: return "Vibrant"
        case .material: return "Material"
        case .pattern: return "Pattern"
        }
    }
}

// MARK: - Animation Preset

enum AnimationPreset: String, Codable, CaseIterable {
    case soft = "soft"
    case balanced = "balanced"
    case snappy = "snappy"
    
    var displayName: String {
        switch self {
        case .soft: return "Soft"
        case .balanced: return "Balanced"
        case .snappy: return "Snappy"
        }
    }
}

enum AccentColorOption: String, Codable, CaseIterable {
    case blue = "blue"
    case purple = "purple"
    case pink = "pink"
    case red = "red"
    case orange = "orange"
    case yellow = "yellow"
    case green = "green"
    case mint = "mint"
    case teal = "teal"
    case cyan = "cyan"
    
    var displayName: String {
        return rawValue.capitalized
    }
    
    var color: Color {
        switch self {
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .mint: return .mint
        case .teal: return .teal
        case .cyan: return .cyan
        }
    }
}

// MARK: - Theme Palette (global UI colors)

enum ThemePalette: String, Codable, CaseIterable {
    case system
    case graphite
    case midnight
    case ocean
    case forest
    case sunset
    case candy
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .graphite: return "Graphite"
        case .midnight: return "Midnight"
        case .ocean: return "Ocean"
        case .forest: return "Forest"
        case .sunset: return "Sunset"
        case .candy: return "Candy"
        }
    }
}

enum BackupInterval: String, Codable, CaseIterable {
    case never = "never"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    
    var displayName: String {
        switch self {
        case .never: return "Never"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }
}

enum AppLanguage: String, Codable, CaseIterable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case japanese = "ja"
    case korean = "ko"
    case chinese = "zh"
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .chinese: return "中文"
        }
    }
}

enum WindowBehavior: String, Codable, CaseIterable {
    case normal = "normal"
    case alwaysOnTop = "alwaysOnTop"
    case minimizeToTray = "minimizeToTray"
    
    var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .alwaysOnTop: return "Always on Top"
        case .minimizeToTray: return "Minimize to Tray"
        }
    }
}

// MARK: - Roblox Flavors (Clean vs Executor-specific clones)

enum RobloxFlavor: String, Codable, CaseIterable {
    case clean = "clean"
    case opiumware = "opiumware"
    case macsploit = "macsploit"
    case hydrogen = "hydrogen"
    
    var displayName: String {
        switch self {
        case .clean: return "Clean Roblox"
        case .opiumware: return "Opiumware Roblox"
        case .macsploit: return "MacSploit Roblox"
        case .hydrogen: return "Hydrogen Roblox"
        }
    }
}
