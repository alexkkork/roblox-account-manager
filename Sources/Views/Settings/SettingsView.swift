import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settingsManager: SettingsManager
    
    @State private var selectedSection: SettingsSection = .appearance
    @State private var showingResetConfirmation = false
    @State private var showingImportExport = false
    
    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                // Sidebar
                settingsSidebar
                    .frame(width: 250)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                
                // Content
                settingsContent
                    .frame(maxWidth: .infinity)
                    .background(Color(NSColor.windowBackgroundColor))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Import Settings") {
                            importSettings()
                        }
                        
                        Button("Export Settings") {
                            exportSettings()
                        }
                        
                        Divider()
                        
                        Button("Reset All Settings", role: .destructive) {
                            showingResetConfirmation = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert("Reset Settings", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                settingsManager.resetToDefaults()
            }
        } message: {
            Text("Are you sure you want to reset all settings to their default values? This action cannot be undone.")
        }
    }
    
    private var settingsSidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(settingsManager.currentAccentColor)
                    
                    Text("Settings")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                Text("Customize your experience")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            // Section list
            VStack(spacing: 4) {
                ForEach(SettingsSection.allCases, id: \.self) { section in
                    SettingsSidebarButton(
                        section: section,
                        isSelected: selectedSection == section
                    ) {
                        selectedSection = section
                    }
                }
            }
            .padding(.horizontal, 16)
            
            Spacer()
            
            // Footer
            VStack(alignment: .leading, spacing: 8) {
                Divider()
                    .padding(.horizontal, 16)
                
                Text("Version 1.0.0")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
        }
    }
    
    @ViewBuilder
    private var settingsContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Section header
                sectionHeader
                
                // Section content
                switch selectedSection {
                case .appearance:
                    AppearanceSettingsView()
                case .behavior:
                    BehaviorSettingsView()
                case .audio:
                    AudioSettingsView()
                case .security:
                    SecuritySettingsView()
                case .advanced:
                    AdvancedSettingsView()
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 30)
        }
    }
    
    private var sectionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: selectedSection.iconName)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(settingsManager.currentAccentColor)
                    
                    Text(selectedSection.displayName)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                Text(selectedSection.description)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Reset Section") {
                settingsManager.resetSection(selectedSection)
            }
            .buttonStyle(.bordered)
            .foregroundColor(.orange)
        }
    }
    
    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try settingsManager.importSettings(from: url)
            } catch {
                // Handle error
                print("Import failed: \(error)")
            }
        }
    }
    
    private func exportSettings() {
        do {
            let exportURL = try settingsManager.exportSettings()
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.json]
            panel.nameFieldStringValue = "settings_export.json"
            
            if panel.runModal() == .OK, let saveURL = panel.url {
                try FileManager.default.moveItem(at: exportURL, to: saveURL)
            }
        } catch {
            // Handle error
            print("Export failed: \(error)")
        }
    }
}

// MARK: - Settings Sidebar Button

struct SettingsSidebarButton: View {
    let section: SettingsSection
    let isSelected: Bool
    let action: () -> Void
    
    @EnvironmentObject private var settingsManager: SettingsManager
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: section.iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? settingsManager.currentAccentColor : .secondary)
                    .frame(width: 20)
                
                Text(section.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? settingsManager.currentAccentColor : .primary)
                
                Spacer()
                
                if isSelected {
                    Circle()
                        .fill(settingsManager.currentAccentColor)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? settingsManager.currentAccentColor.opacity(0.1) : Color.clear)
        )
        .animation(settingsManager.getSpringAnimation(for: .quick), value: isSelected)
    }
}

// MARK: - Settings Section Extension

extension SettingsSection {
    var description: String {
        switch self {
        case .appearance: return "Customize the look and feel of the application"
        case .behavior: return "Configure how the application behaves"
        case .audio: return "Manage audio and feedback settings"
        case .security: return "Security and privacy preferences"
        case .advanced: return "Advanced configuration options"
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(SettingsManager())
}
