import SwiftUI

struct SecuritySettingsView: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    
    @State private var showingDataLocationPicker = false
    @State private var showingBackupLocationPicker = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Simplified: removed encryption, storage, backup, privacy groups
        }
        // removed fileImporter
    }
    
    private func createBackup() {
        // Implementation for creating a backup
        print("Creating backup...")
    }
    
    private func restoreFromBackup() {
        // Implementation for restoring from backup
        print("Restoring from backup...")
    }
}

// MARK: - Storage Info Row

struct StorageInfoRow: View {
    let title: String
    let description: String
    let size: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(size)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color(NSColor.controlBackgroundColor))
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
    }
}

#Preview {
    SecuritySettingsView()
        .environmentObject(SettingsManager())
        .padding()
}
