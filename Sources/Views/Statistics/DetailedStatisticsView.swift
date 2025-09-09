import SwiftUI

struct DetailedStatisticsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var multiLauncher: MultiLauncher
    @EnvironmentObject private var accountManager: AccountManager
    @EnvironmentObject private var gameManager: GameManager
    @EnvironmentObject private var settingsManager: SettingsManager
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Detailed Statistics")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    
                    Text("Comprehensive analytics and insights would be displayed here")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    // Placeholder for detailed charts and analytics
                    Rectangle()
                        .fill(Color.secondary.opacity(0.1))
                        .frame(height: 400)
                        .overlay(
                            Text("Advanced charts and analytics")
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                        )
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Detailed Statistics")
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

#Preview {
    DetailedStatisticsView()
        .environmentObject(MultiLauncher())
        .environmentObject(AccountManager())
        .environmentObject(GameManager())
        .environmentObject(SettingsManager())
}
