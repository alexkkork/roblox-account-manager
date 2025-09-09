import SwiftUI

struct BehaviorSettingsView: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    
    var body: some View {
        VStack(spacing: 24) {
            // Notifications
            SettingsGroup(title: "Notifications", icon: "bell.fill") {
                VStack(spacing: 16) {
                    Toggle("Enable notifications", isOn: .init(
                        get: { settingsManager.settings.enableNotifications },
                        set: { _ in settingsManager.toggleNotifications() }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: settingsManager.currentAccentColor))
                    
                    Text("Receive notifications about launches, completions, and errors")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            // Startup Behavior
            SettingsGroup(title: "Startup", icon: "power") {
                VStack(spacing: 16) {
                    Toggle("Launch on startup", isOn: .init(
                        get: { settingsManager.settings.autoLaunchOnStartup },
                        set: { _ in settingsManager.toggleAutoLaunch() }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: settingsManager.currentAccentColor))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Automatically start the app when you log in to your Mac")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        if settingsManager.settings.autoLaunchOnStartup {
                            Text("The app will start minimized and run in the background")
                                .font(.system(size: 12))
                                .foregroundColor(.blue)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            // Launch Behavior (simplified)
            SettingsGroup(title: "Launch Behavior", icon: "play.rectangle.fill") {
                VStack(spacing: 20) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Maximum simultaneous launches")
                                .font(.system(size: 16, weight: .semibold))
                            Text("How many accounts can launch at the same time")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        HStack {
                            Button("-") {
                                let newValue = max(1, settingsManager.settings.maxSimultaneousLaunches - 1)
                                settingsManager.updateMaxSimultaneousLaunches(newValue)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            Text("\(settingsManager.settings.maxSimultaneousLaunches)")
                                .font(.system(size: 16, weight: .medium))
                                .frame(width: 30)
                            Button("+") {
                                let newValue = min(10, settingsManager.settings.maxSimultaneousLaunches + 1)
                                settingsManager.updateMaxSimultaneousLaunches(newValue)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
            
            // Window Management
            SettingsGroup(title: "Window Management", icon: "macwindow") {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Window Behavior")
                                .font(.system(size: 16, weight: .semibold))
                            Text("How windows should behave")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Picker("Window Behavior", selection: .init(
                            get: { settingsManager.settings.windowBehavior },
                            set: { settingsManager.updateWindowBehavior($0) }
                        )) {
                            ForEach(WindowBehavior.allCases, id: \.self) { behavior in
                                Text(behavior.displayName).tag(behavior)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 180)
                    }
                    
                    // Behavior description
                    switch settingsManager.settings.windowBehavior {
                    case .normal:
                        Text("Windows behave normally")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    case .alwaysOnTop:
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("Windows will stay on top of other applications")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    case .minimizeToTray:
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("Windows will minimize to the system tray when closed")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            
            // Performance
            SettingsGroup(title: "Performance", icon: "speedometer") {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Memory Management")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Automatically clean up completed sessions")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Clean Now") {
                            // This would trigger cleanup
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Text("Sessions older than 1 hour will be automatically cleaned up to free memory")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

#Preview {
    BehaviorSettingsView()
        .environmentObject(SettingsManager())
        .padding()
}
