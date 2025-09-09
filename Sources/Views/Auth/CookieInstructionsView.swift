import SwiftUI

struct CookieInstructionsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settingsManager: SettingsManager
    
    @State private var currentStep = 0
    private let totalSteps = 6
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    headerView
                    
                    // Step indicator
                    stepIndicator
                    
                    // Instructions
                    instructionSteps
                    
                    // Warning
                    warningView
                    
                    // Close button
                    Button("Got it!") {
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 20)
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("How to Get Your Roblox Cookie")
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
    
    private var headerView: some View {
        VStack(spacing: 16) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(settingsManager.currentAccentColor)
            
            Text("Cookie Extraction Guide")
                .font(.system(size: 24, weight: .bold, design: .rounded))
            
            Text("Follow these steps to safely extract your Roblox authentication cookie")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? settingsManager.currentAccentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 10)
    }
    
    private var instructionSteps: some View {
        VStack(spacing: 24) {
            InstructionStep(
                number: 1,
                title: "Open Roblox Website",
                description: "Go to roblox.com in your web browser and make sure you're logged in to your account.",
                icon: "safari.fill"
            )
            
            InstructionStep(
                number: 2,
                title: "Open Developer Tools",
                description: "Right-click anywhere on the page and select 'Inspect Element' or press F12 (Cmd+Option+I on Mac).",
                icon: "wrench.and.screwdriver.fill"
            )
            
            InstructionStep(
                number: 3,
                title: "Navigate to Application/Storage",
                description: "In the developer tools, click on the 'Application' tab (Chrome) or 'Storage' tab (Firefox).",
                icon: "folder.fill"
            )
            
            InstructionStep(
                number: 4,
                title: "Find Cookies",
                description: "In the left sidebar, expand 'Cookies' and click on 'https://www.roblox.com'.",
                icon: "list.bullet"
            )
            
            InstructionStep(
                number: 5,
                title: "Locate .ROBLOSECURITY",
                description: "Look for a cookie named '.ROBLOSECURITY' in the list. This is your authentication cookie.",
                icon: "key.fill"
            )
            
            InstructionStep(
                number: 6,
                title: "Copy the Value",
                description: "Double-click on the 'Value' column for .ROBLOSECURITY and copy the entire string. It should start with '_|WARNING:-DO-NOT-SHARE-THIS'.",
                icon: "doc.on.clipboard.fill"
            )
        }
    }
    
    private var warningView: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.orange)
                
                Text("Important Security Warning")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.orange)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                SecurityWarningItem(
                    text: "Never share your cookie with anyone else"
                )
                
                SecurityWarningItem(
                    text: "This cookie gives full access to your Roblox account"
                )
                
                SecurityWarningItem(
                    text: "Your cookie is encrypted and stored securely on your device"
                )
                
                SecurityWarningItem(
                    text: "We never transmit your cookie to external servers"
                )
                
                SecurityWarningItem(
                    text: "If you suspect your cookie is compromised, log out of Roblox immediately"
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Instruction Step

struct InstructionStep: View {
    let number: Int
    let title: String
    let description: String
    let icon: String
    
    @EnvironmentObject private var settingsManager: SettingsManager
    
    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            // Step number
            ZStack {
                Circle()
                    .fill(settingsManager.currentAccentColor)
                    .frame(width: 40, height: 40)
                
                Text("\(number)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(settingsManager.currentAccentColor)
                    
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
    }
}

// MARK: - Security Warning Item

struct SecurityWarningItem: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(.orange)
                .padding(.top, 2)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    CookieInstructionsView()
        .environmentObject(SettingsManager())
}
