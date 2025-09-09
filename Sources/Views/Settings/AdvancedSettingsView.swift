import SwiftUI

struct AdvancedSettingsView: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    
    @State private var showingLogViewer = false
    @State private var showingDeveloperOptions = false
    @State private var newExecutorName = ""
    @State private var newExecutorURLString = ""
    @State private var showingChooseInstallDir = false
    @State private var installDirectoryPath: String = ""
    
    var body: some View {
        VStack(spacing: 24) {
            // Simplified: removed Language & Region
            
            // Performance Settings
            SettingsGroup(title: "Performance", icon: "speedometer") {
                VStack(spacing: 20) {
                    // First-time setup
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("First-Time Setup")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Re-run the initial setup guide")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Open Setup…") {
                            NotificationCenter.default.post(name: .openFirstTimeSetup, object: nil)
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    // Memory management
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Memory Management")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Automatically clean up old session data")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Clean Now") {
                            cleanupMemory()
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    // Cache settings
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Cache Settings")
                            .font(.system(size: 16, weight: .semibold))
                        
                        VStack(spacing: 12) {
                            HStack {
                                Text("Game thumbnails cache")
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text("~25 MB")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                
                                Button("Clear") {
                                    clearThumbnailCache()
                                }
                                .font(.system(size: 12))
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            
                            HStack {
                                Text("Application logs")
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text("~5 MB")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                
                                Button("View") {
                                    showingLogViewer = true
                                }
                                .font(.system(size: 12))
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }
            }
            
            // Simplified: removed Debug & Diagnostics
            
            
            // Simplified: removed Experimental Features
            
            // Simplified: removed Developer Options
        }
        .sheet(isPresented: $showingLogViewer) {
            ZStack {
                Color.clear.ignoresSafeArea()
                LogViewerView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .fileImporter(isPresented: $showingChooseInstallDir, allowedContentTypes: [.folder]) { result in
            if case let .success(url) = result {
                settingsManager.settings.executorsInstallDirectory = url.path
            }
        }
    }
    
    private func cleanupMemory() {
        // Implementation for memory cleanup
        print("Cleaning up memory...")
    }
    
    private func clearThumbnailCache() {
        // Implementation for clearing thumbnail cache
        print("Clearing thumbnail cache...")
    }
    
    private func generateSystemReport() {
        // Implementation for generating system report
        print("Generating system report...")
    }
    
    private func exportLogs() {
        // Implementation for exporting logs
        print("Exporting logs...")
    }
    
    // MARK: - Executors Actions
    private func addExecutor() {
        let name = newExecutorName.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = newExecutorURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !url.isEmpty else { return }
        settingsManager.addExecutor(name: name, installURLString: url)
        newExecutorName = ""
        newExecutorURLString = ""
    }
    
    private func removeExecutor(_ exec: Executor) {
        settingsManager.removeExecutor(exec)
    }
    
    private func installExecutor(_ exec: Executor) {
        settingsManager.installOrUpdateExecutor(exec)
    }
}

// MARK: - Experimental Feature Row

struct ExperimentalFeatureRow: View {
    let title: String
    let description: String
    let isEnabled: Bool
    
    @EnvironmentObject private var settingsManager: SettingsManager
    @State private var enabled: Bool
    
    init(title: String, description: String, isEnabled: Bool) {
        self.title = title
        self.description = description
        self.isEnabled = isEnabled
        self._enabled = State(initialValue: isEnabled)
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text("BETA")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .clipShape(Capsule())
                }
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $enabled)
                .toggleStyle(SwitchToggleStyle(tint: settingsManager.currentAccentColor))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

// MARK: - Developer Option Row

struct DeveloperOptionRow: View {
    let title: String
    let description: String
    let isEnabled: Bool
    
    @EnvironmentObject private var settingsManager: SettingsManager
    @State private var enabled: Bool
    
    init(title: String, description: String, isEnabled: Bool) {
        self.title = title
        self.description = description
        self.isEnabled = isEnabled
        self._enabled = State(initialValue: isEnabled)
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text("DEV")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $enabled)
                .toggleStyle(SwitchToggleStyle(tint: .red))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.red.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Log Viewer (Placeholder)

struct LogViewerView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Application Logs")
                        .font(.system(size: 20, weight: .bold))
                        .padding(.bottom, 16)
                    
                    Text("Log entries would be displayed here in a real implementation")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    // Mock log entries
                    VStack(alignment: .leading, spacing: 8) {
                        LogEntry(timestamp: "2024-01-15 10:30:25", level: "INFO", message: "Application started successfully")
                        LogEntry(timestamp: "2024-01-15 10:30:26", level: "DEBUG", message: "Loading user settings...")
                        LogEntry(timestamp: "2024-01-15 10:30:27", level: "INFO", message: "Settings loaded successfully")
                        LogEntry(timestamp: "2024-01-15 10:31:15", level: "WARNING", message: "Network request timeout, retrying...")
                        LogEntry(timestamp: "2024-01-15 10:31:18", level: "ERROR", message: "Failed to connect to game server")
                    }
                }
                .padding(20)
            }
            .navigationTitle("Logs")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LogEntry: View {
    let timestamp: String
    let level: String
    let message: String
    
    var levelColor: Color {
        switch level {
        case "ERROR": return .red
        case "WARNING": return .orange
        case "INFO": return .blue
        case "DEBUG": return .secondary
        default: return .primary
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(timestamp)
                .font(.system(size: 12).monospaced())
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .leading)
            
            Text(level)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(levelColor)
                .frame(width: 70, alignment: .leading)
            
            Text(message)
                .font(.system(size: 12).monospaced())
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.3))
        )
    }
}

#Preview {
    AdvancedSettingsView()
        .environmentObject(SettingsManager())
        .padding()
}
