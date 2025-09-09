import SwiftUI

struct LaunchSettingsView: View {
    let account: Account
    let onSave: (LaunchSettings) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settingsManager: SettingsManager
    
    @State private var launchSettings: LaunchSettings
    
    init(account: Account, onSave: @escaping (LaunchSettings) -> Void) {
        self.account = account
        self.onSave = onSave
        self._launchSettings = State(initialValue: account.customLaunchSettings)
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
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Launch Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(launchSettings)
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
            
            Text("Launch Settings")
                .font(.system(size: 24, weight: .bold, design: .rounded))
            
            Text("Configure how \(account.displayName) launches games")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var windowSettingsSection: some View {
            LaunchSettingsSection(title: "Window Settings", icon: "rectangle.fill") {
            VStack(spacing: 16) {
                // Window Size
                VStack(alignment: .leading, spacing: 8) {
                    Text("Window Size")
                        .font(.system(size: 16, weight: .semibold))
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Width")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            TextField("Width", value: $launchSettings.windowSize.width, format: .number)
                                .textFieldStyle(ModernTextFieldStyle())
                                .frame(width: 120)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Height")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            TextField("Height", value: $launchSettings.windowSize.height, format: .number)
                                .textFieldStyle(ModernTextFieldStyle())
                                .frame(width: 120)
                        }
                        
                        Spacer()
                        
                        // Preset buttons
                        VStack(spacing: 8) {
                            Button("1920×1080") {
                                launchSettings.windowSize = WindowSize(width: 1920, height: 1080)
                            }
                            .font(.system(size: 12))
                            
                            Button("1280×720") {
                                launchSettings.windowSize = WindowSize(width: 1280, height: 720)
                            }
                            .font(.system(size: 12))
                        }
                    }
                }
                
                // Window Position Preview
                windowPositionPreview
            }
        }
    }
    
    private var positionSettingsSection: some View {
        LaunchSettingsSection(title: "Window Position", icon: "square.grid.3x3.fill") {
            VStack(spacing: 16) {
                // Position picker
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    ForEach(WindowPosition.allCases, id: \.self) { position in
                        PositionButton(
                            position: position,
                            isSelected: launchSettings.startPosition == position
                        ) {
                            launchSettings.startPosition = position
                        }
                    }
                }
                
                Text("Select where the game window should appear when launched")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var launchOptionsSection: some View {
        LaunchSettingsSection(title: "Launch Options", icon: "play.circle.fill") {
            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(settingsManager.currentAccentColor)
                    Text("Auto-join is required and enabled")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("The launcher uses an authentication ticket to join the selected place automatically.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private var customFlagsSection: some View {
        LaunchSettingsSection(title: "Custom Launch Flags", icon: "flag.fill") {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Additional launch parameters (one per line)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: .constant(launchSettings.customFlags.joined(separator: "\n")))
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
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Common Flags:")
                        .font(.system(size: 14, weight: .medium))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("--fullscreen - Launch in fullscreen mode")
                        Text("--windowed - Force windowed mode")
                        Text("--fps=60 - Set target framerate")
                    }
                    .font(.system(size: 12).monospaced())
                    .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var windowPositionPreview: some View {
        VStack(spacing: 12) {
            Text("Preview")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            ZStack {
                // Screen representation
                Rectangle()
                    .fill(Color(NSColor.controlBackgroundColor))
                    .frame(width: 200, height: 120)
                    .overlay(
                        Rectangle()
                            .stroke(Color.secondary, lineWidth: 1)
                    )
                
                // Window representation
                Rectangle()
                    .fill(settingsManager.currentAccentColor.opacity(0.7))
                    .frame(width: 60, height: 36)
                    .position(previewPosition)
                    .animation(settingsManager.getSpringAnimation(for: .normal), value: launchSettings.startPosition)
            }
        }
    }
    
    private var previewPosition: CGPoint {
        let screenSize = CGSize(width: 200, height: 120)
        let windowSize = CGSize(width: 60, height: 36)
        
        switch launchSettings.startPosition {
        case .center:
            return CGPoint(x: screenSize.width / 2, y: screenSize.height / 2)
        case .topLeft:
            return CGPoint(x: windowSize.width / 2 + 10, y: windowSize.height / 2 + 10)
        case .topRight:
            return CGPoint(x: screenSize.width - windowSize.width / 2 - 10, y: windowSize.height / 2 + 10)
        case .bottomLeft:
            return CGPoint(x: windowSize.width / 2 + 10, y: screenSize.height - windowSize.height / 2 - 10)
        case .bottomRight:
            return CGPoint(x: screenSize.width - windowSize.width / 2 - 10, y: screenSize.height - windowSize.height / 2 - 10)
        case .custom:
            return CGPoint(x: screenSize.width / 2, y: screenSize.height / 2)
        }
    }
}

// MARK: - Settings Section

struct LaunchSettingsSection<Content: View>: View {
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

// MARK: - Position Button

struct PositionButton: View {
    let position: WindowPosition
    let isSelected: Bool
    let action: () -> Void
    
    @EnvironmentObject private var settingsManager: SettingsManager
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(isSelected ? .white : settingsManager.currentAccentColor)
                
                Text(position.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(height: 80)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? settingsManager.currentAccentColor : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
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

#Preview {
    LaunchSettingsView(account: Account(username: "test", displayName: "Test", cookie: "test")) { _ in }
        .environmentObject(SettingsManager())
}
