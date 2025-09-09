import SwiftUI

struct BulkLaunchSettingsView: View {
    @Binding var settings: LaunchSettings
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settingsManager: SettingsManager
    
    @State private var tempSettings: LaunchSettings
    
    init(settings: Binding<LaunchSettings>) {
        self._settings = settings
        self._tempSettings = State(initialValue: settings.wrappedValue)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerView
                    
                    // Window Settings
                    windowSettingsSection
                    
                    // Position Settings
                    positionSettingsSection
                    
                    // Launch Options
                    launchOptionsSection
                    
                    // Custom Flags
                    customFlagsSection
                    
                    // Presets
                    presetsSection
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Bulk Launch Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        settings = tempSettings
                        dismiss()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var headerView: some View {
        VStack(spacing: 16) {
            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 50))
                .foregroundColor(settingsManager.currentAccentColor)
            
            Text("Bulk Launch Settings")
                .font(.system(size: 24, weight: .bold, design: .rounded))
            
            Text("Configure settings that will apply to all launched accounts")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var windowSettingsSection: some View {
            BulkLaunchSettingsSection(title: "Window Settings", icon: "rectangle.fill") {
            VStack(spacing: 16) {
                // Window Size
                VStack(alignment: .leading, spacing: 12) {
                    Text("Window Size")
                        .font(.system(size: 16, weight: .semibold))
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Width")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            TextField("Width", value: $tempSettings.windowSize.width, format: .number)
                                .textFieldStyle(ModernTextFieldStyle())
                                .frame(width: 120)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Height")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            TextField("Height", value: $tempSettings.windowSize.height, format: .number)
                                .textFieldStyle(ModernTextFieldStyle())
                                .frame(width: 120)
                        }
                        
                        Spacer()
                    }
                }
                
                // Quick size presets
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Presets")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        ForEach(WindowSizePreset.allCases, id: \.self) { preset in
                            Button(preset.displayName) {
                                tempSettings.windowSize = preset.size
                            }
                            .font(.system(size: 12))
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
    }
    
    private var positionSettingsSection: some View {
        BulkLaunchSettingsSection(title: "Window Position", icon: "square.grid.3x3.fill") {
            VStack(spacing: 16) {
                Text("Choose how windows should be positioned")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    ForEach(WindowPosition.allCases, id: \.self) { position in
                        BulkPositionButton(
                            position: position,
                            isSelected: tempSettings.startPosition == position
                        ) {
                            tempSettings.startPosition = position
                        }
                    }
                }
                
                if tempSettings.startPosition == .custom {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Custom Position")
                            .font(.system(size: 14, weight: .medium))
                        
                        Text("Windows will be positioned automatically with smart spacing")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(settingsManager.currentAccentColor.opacity(0.1))
                    )
                }
            }
        }
    }
    
    private var launchOptionsSection: some View {
        BulkLaunchSettingsSection(title: "Launch Options", icon: "play.circle.fill") {
            VStack(spacing: 16) {
                Toggle("Auto-join game", isOn: $tempSettings.autoJoin)
                    .toggleStyle(SwitchToggleStyle(tint: settingsManager.currentAccentColor))
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("When enabled, accounts will automatically join the selected game after launching Roblox.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Text("This may not work for all games or if the game is full.")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private var customFlagsSection: some View {
        BulkLaunchSettingsSection(title: "Custom Launch Flags", icon: "flag.fill") {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Additional launch parameters (one per line)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: .constant(tempSettings.customFlags.joined(separator: "\n")))
                        .font(.system(size: 12).monospaced())
                        .frame(height: 100)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(NSColor.controlBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(settingsManager.currentAccentColor.opacity(0.3), lineWidth: 1)
                        )
                }
                
                // Common flags
                VStack(alignment: .leading, spacing: 8) {
                    Text("Common Flags:")
                        .font(.system(size: 14, weight: .medium))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        CommonFlagRow(flag: "--fullscreen", description: "Launch in fullscreen mode")
                        CommonFlagRow(flag: "--windowed", description: "Force windowed mode")
                        CommonFlagRow(flag: "--fps=60", description: "Set target framerate")
                        CommonFlagRow(flag: "--no-sound", description: "Disable audio")
                    }
                }
            }
        }
    }
    
    private var presetsSection: some View {
        BulkLaunchSettingsSection(title: "Presets", icon: "bookmark.fill") {
            VStack(spacing: 16) {
                Text("Quick configuration presets")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ForEach(LaunchPreset.allCases, id: \.self) { preset in
                        PresetButton(preset: preset) {
                            applyPreset(preset)
                        }
                    }
                }
            }
        }
    }
    
    private func applyPreset(_ preset: LaunchPreset) {
        switch preset {
        case .performance:
            tempSettings.windowSize = WindowSize(width: 1280, height: 720)
            tempSettings.startPosition = .center
            tempSettings.autoJoin = true
            tempSettings.customFlags = ["--fps=60", "--no-sound"]
            
        case .quality:
            tempSettings.windowSize = WindowSize(width: 1920, height: 1080)
            tempSettings.startPosition = .center
            tempSettings.autoJoin = true
            tempSettings.customFlags = ["--fullscreen"]
            
        case .multiWindow:
            tempSettings.windowSize = WindowSize(width: 960, height: 540)
            tempSettings.startPosition = .custom
            tempSettings.autoJoin = true
            tempSettings.customFlags = ["--windowed"]
            
        case .minimal:
            tempSettings.windowSize = WindowSize(width: 800, height: 600)
            tempSettings.startPosition = .center
            tempSettings.autoJoin = false
            tempSettings.customFlags = ["--no-sound", "--windowed"]
        }
    }
}

// MARK: - Supporting Types

enum WindowSizePreset: CaseIterable {
    case hd720
    case hd1080
    case hd1440
    case uhd4k
    
    var displayName: String {
        switch self {
        case .hd720: return "720p"
        case .hd1080: return "1080p"
        case .hd1440: return "1440p"
        case .uhd4k: return "4K"
        }
    }
    
    var size: WindowSize {
        switch self {
        case .hd720: return WindowSize(width: 1280, height: 720)
        case .hd1080: return WindowSize(width: 1920, height: 1080)
        case .hd1440: return WindowSize(width: 2560, height: 1440)
        case .uhd4k: return WindowSize(width: 3840, height: 2160)
        }
    }
}

enum LaunchPreset: CaseIterable {
    case performance
    case quality
    case multiWindow
    case minimal
    
    var displayName: String {
        switch self {
        case .performance: return "Performance"
        case .quality: return "High Quality"
        case .multiWindow: return "Multi-Window"
        case .minimal: return "Minimal"
        }
    }
    
    var description: String {
        switch self {
        case .performance: return "Optimized for performance with lower resolution and disabled audio"
        case .quality: return "Best visual quality with fullscreen mode"
        case .multiWindow: return "Smaller windows optimized for multiple accounts"
        case .minimal: return "Basic settings with minimal resource usage"
        }
    }
    
    var iconName: String {
        switch self {
        case .performance: return "speedometer"
        case .quality: return "sparkles"
        case .multiWindow: return "rectangle.3.group"
        case .minimal: return "minus.circle"
        }
    }
}

// MARK: - Bulk Settings Section

struct BulkLaunchSettingsSection<Content: View>: View {
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

// MARK: - Bulk Position Button

struct BulkPositionButton: View {
    let position: WindowPosition
    let isSelected: Bool
    let action: () -> Void
    
    @EnvironmentObject private var settingsManager: SettingsManager
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isSelected ? .white : settingsManager.currentAccentColor)
                
                Text(position.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(height: 70)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? settingsManager.currentAccentColor : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? settingsManager.currentAccentColor : settingsManager.currentAccentColor.opacity(0.3),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(settingsManager.getSpringAnimation(for: .quick), value: isSelected)
    }
    
    private var iconName: String {
        switch position {
        case .center: return "rectangle.center.inset.filled"
        case .topLeft: return "rectangle.topthird.inset.filled"
        case .topRight: return "arrow.up.right.square.fill"
        case .bottomLeft: return "rectangle.bottomthird.inset.filled"
        case .bottomRight: return "arrow.down.right.square.fill"
        case .custom: return "rectangle.dashed"
        }
    }
}

// MARK: - Common Flag Row

struct CommonFlagRow: View {
    let flag: String
    let description: String
    
    var body: some View {
        HStack {
            Text(flag)
                .font(.system(size: 12).monospaced())
                .foregroundColor(.primary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
            
            Text("- \(description)")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preset Button

struct PresetButton: View {
    let preset: LaunchPreset
    let action: () -> Void
    
    @EnvironmentObject private var settingsManager: SettingsManager
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: preset.iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(settingsManager.currentAccentColor)
                    
                    Text(preset.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                Text(preset.description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(settingsManager.currentAccentColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    BulkLaunchSettingsView(settings: .constant(LaunchSettings()))
        .environmentObject(SettingsManager())
}
