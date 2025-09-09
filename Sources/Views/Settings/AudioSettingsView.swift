import SwiftUI

struct AudioSettingsView: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    
    var body: some View {
        VStack(spacing: 24) {
            // Sound Effects
            SettingsGroup(title: "Sound Effects", icon: "speaker.wave.3.fill") {
                VStack(spacing: 16) {
                    Toggle("Enable sound effects", isOn: .init(
                        get: { settingsManager.settings.enableSoundEffects },
                        set: { _ in settingsManager.toggleSoundEffects() }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: settingsManager.currentAccentColor))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Play sounds for launches, completions, and notifications")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        if settingsManager.settings.enableSoundEffects {
                            Button("Test Sound") {
                                // Play test sound
                                NSSound.beep()
                            }
                            .font(.system(size: 12))
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            // Simplified: removed haptic, events, and system integration
        }
    }
}

// MARK: - Audio Event Row

struct AudioEventRow: View {
    let title: String
    let description: String
    let isEnabled: Bool
    let soundName: String
    
    @EnvironmentObject private var settingsManager: SettingsManager
    @State private var enabled: Bool
    
    init(title: String, description: String, isEnabled: Bool, soundName: String) {
        self.title = title
        self.description = description
        self.isEnabled = isEnabled
        self.soundName = soundName
        self._enabled = State(initialValue: isEnabled)
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                if enabled && settingsManager.settings.enableSoundEffects {
                    Button("Test") {
                        // Play test sound
                        NSSound.beep()
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
                
                Toggle("", isOn: $enabled)
                    .toggleStyle(SwitchToggleStyle(tint: settingsManager.currentAccentColor))
                    .disabled(!settingsManager.settings.enableSoundEffects)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .opacity(settingsManager.settings.enableSoundEffects ? 1.0 : 0.6)
    }
}

#Preview {
    AudioSettingsView()
        .environmentObject(SettingsManager())
        .padding()
}
