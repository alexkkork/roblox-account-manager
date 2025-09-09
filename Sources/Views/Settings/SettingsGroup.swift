import SwiftUI

struct SettingsGroup<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    @EnvironmentObject private var settingsManager: SettingsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(settingsManager.paletteTextPrimary)
                
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(settingsManager.paletteTextPrimary)
            }
            
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(settingsManager.paletteSurface.opacity(0.6))
        )
    }
}
