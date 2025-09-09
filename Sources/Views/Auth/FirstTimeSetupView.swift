import SwiftUI
import Combine

struct FirstTimeSetupView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject private var accountManager: AccountManager
    @EnvironmentObject private var settingsManager: SettingsManager
    
    @State private var currentStep = 0
    @State private var username = ""
    @State private var displayName = ""
    @State private var cookie = ""
    @State private var isValidating = false
    @State private var validationError: String?
    @State private var showingCookieInstructions = false
    @State private var fieldErrors: [String: String] = [:]
    @State private var showingSuccessAnimation = false
    @State private var hasAttemptedContinue = false
    @State private var animationTrigger = false
    @State private var isFetchingUserInfo = false
    @State private var avatarURL = ""
    @State private var lastCookieValue = ""
    
    private let totalSteps = 3
    @State private var skipCookieStep = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .frame(maxWidth: .infinity)
            
            // Progress indicator
            progressView
                .padding(.top, 40)
                .frame(maxWidth: .infinity)
            
            // Step content
            stepContentView
                .padding(.top, 50)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            // Navigation buttons
            navigationButtons
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 80)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var backgroundView: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    settingsManager.currentAccentColor.opacity(0.1),
                    Color.clear,
                    settingsManager.currentAccentColor.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
                // Continuously animated floating orbs
                if settingsManager.settings.enableAnimations {
                    ForEach(0..<5, id: \.self) { index in
                        MovingOrb(
                            color: settingsManager.currentAccentColor.opacity(0.04),
                            size: CGFloat.random(in: 120...250),
                            delay: Double(index) * 0.4
                        )
                    }
                }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 20) {
            // Welcome icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                settingsManager.currentAccentColor,
                                settingsManager.currentAccentColor.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 45, weight: .medium))
                    .foregroundColor(.white)
            }
            .shadow(color: settingsManager.currentAccentColor.opacity(0.3), radius: 20, x: 0, y: 10)
            .scaleEffect(1.0 + sin(Date().timeIntervalSince1970) * 0.05)
            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: currentStep)
            
            // Welcome text
            VStack(spacing: 12) {
                Text("Welcome to Roblox Account Manager")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Text("Let's get you started by setting up your first account")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.9)
            }
        }
    }
    
    private var progressView: some View {
        VStack(spacing: 16) {
            // Progress bar
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { step in
                    Rectangle()
                        .fill(step <= currentStep ? settingsManager.currentAccentColor : Color.secondary.opacity(0.3))
                        .frame(height: 4)
                        .animation(settingsManager.getSpringAnimation(for: .normal), value: currentStep)
                }
            }
            .frame(maxWidth: 300)
            
            // Step indicator
            Text("Step \(currentStep + 1) of \(totalSteps)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private var stepContentView: some View {
        switch currentStep {
        case 0:
            welcomeStepView
        case 1:
            accountInfoStepView
        case 2:
            if skipCookieStep {
                skippedCookieView
            } else {
                cookieStepView
            }
        default:
            EmptyView()
        }
    }
    
    private var welcomeStepView: some View {
        VStack(spacing: 20) {
            Text("Getting Started")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            Toggle("Skip cookie step (I'll paste it later)", isOn: $skipCookieStep)
                .toggleStyle(SwitchToggleStyle(tint: settingsManager.currentAccentColor))
                .padding(.top, 8)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                FeatureRow(
                    icon: "person.3.fill",
                    title: "Multi-Account Management",
                    description: "Manage multiple Roblox accounts securely"
                ) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        currentStep = 1
                    }
                }
                
                FeatureRow(
                    icon: "gamecontroller.fill",
                    title: "Game Browser",
                    description: "Discover and launch games with ease"
                ) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        currentStep = 1
                    }
                }
                
                FeatureRow(
                    icon: "play.rectangle.fill",
                    title: "Multi-Launcher",
                    description: "Launch multiple accounts simultaneously"
                ) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        currentStep = 1
                    }
                }
                
                FeatureRow(
                    icon: "lock.shield.fill",
                    title: "Secure Storage",
                    description: "Your data is encrypted and protected"
                ) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        currentStep = 1
                    }
                }
            }
            .frame(maxWidth: .infinity)
            
            Text("Click any feature to continue")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
                .opacity(0.8)
        }
    }
    
    private var accountInfoStepView: some View {
        VStack(spacing: 30) {
            Text("Account Information")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            
            VStack(spacing: 24) {
                // Auto-filled username display
                if !username.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Username")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.green)
                        }
                        
                        HStack {
                            Text(username)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(NSColor.textBackgroundColor).opacity(0.5))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.green.opacity(0.4), lineWidth: 1.5)
                                )
                            
                            Spacer()
                            
                            Text("Auto-filled")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.green)
                        }
                    }
                }
                
                // Username manual entry when skipping cookie
                if skipCookieStep && username.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Username")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        TextField("Enter your Roblox username", text: $username)
                            .textFieldStyle(EnhancedSetupTextFieldStyle(hasError: hasAttemptedContinue && (fieldErrors["username"] != nil)))
                            .onSubmit { validateSetupUsername() }
                        
                        if hasAttemptedContinue, let error = fieldErrors["username"] {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.red)
                            }
                        }
                        
                        Text("Required when skipping cookie. You can add the cookie later in Accounts → Edit Account.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Display Name field
                VStack(alignment: .leading, spacing: 12) {
                    Text("Display Name")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    HStack {
                        TextField(displayName.isEmpty ? "Enter a display name (optional)" : "Display Name (auto-filled)", text: $displayName)
                            .textFieldStyle(EnhancedSetupTextFieldStyle(hasError: false))
                            .disabled(!displayName.isEmpty && isFetchingUserInfo)
                            .placeholder(when: displayName.isEmpty && !isFetchingUserInfo) {
                                Text("Will use username if empty")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary.opacity(0.7))
                            }
                        
                        if !displayName.isEmpty && displayName != username {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .padding(.trailing, 8)
                        }
                    }
                    
                    Text("The display name is how this account will appear in the app. If left empty, your username will be used.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(settingsManager.currentAccentColor.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(settingsManager.currentAccentColor.opacity(0.2), lineWidth: 1)
                        )
                }
                
                if username.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.accentColor)
                        
                        Text("Continue to the next step to paste your Roblox cookie")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Text("Your username will be automatically filled once you provide your cookie")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 20)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private var cookieStepView: some View {
        VStack(spacing: 30) {
            Text("Security Cookie")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            
            VStack(spacing: 24) {
                // Cookie field with enhanced validation
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Roblox Cookie")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("*")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.red)
                        
                        Spacer()
                        
                        Button(action: { showingCookieInstructions = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "questionmark.circle.fill")
                                    .font(.system(size: 14))
                                Text("How to get cookie?")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(settingsManager.currentAccentColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(settingsManager.currentAccentColor.opacity(0.1))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if hasAttemptedContinue, fieldErrors["cookie"] == nil, !cookie.isEmpty {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.green)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    
                    VStack(spacing: 8) {
                        SecureField("Paste your Roblox cookie here", text: $cookie)
                            .textFieldStyle(EnhancedSetupTextFieldStyle(hasError: hasAttemptedContinue && fieldErrors["cookie"] != nil))
                            .font(.system(size: 12).monospaced())
                            .onSubmit {
                                if !cookie.isEmpty && cookie.count > 50 && cookie != lastCookieValue {
                                    lastCookieValue = cookie
                                    fetchUserInfoFromCookie(cookie)
                                }
                            }
                            .onReceive(Just(cookie).delay(for: .milliseconds(800), scheduler: RunLoop.main)) { newValue in
                                if newValue != lastCookieValue && !newValue.isEmpty && newValue.count > 100 && newValue.contains("_|WARNING:-DO-NOT-SHARE-THIS") {
                                    lastCookieValue = newValue
                                    fetchUserInfoFromCookie(newValue)
                                }
                            }
                        
                        // Real-time cookie validation feedback
                        if !cookie.isEmpty {
                            HStack(spacing: 8) {
                                if isFetchingUserInfo {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .foregroundColor(.blue)
                                    Text("Fetching user info...")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.blue)
                                } else {
                                    Image(systemName: cookie.contains("_|WARNING:-DO-NOT-SHARE-THIS") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                        .foregroundColor(cookie.contains("_|WARNING:-DO-NOT-SHARE-THIS") ? .green : .orange)
                                    
                                    Text(cookie.contains("_|WARNING:-DO-NOT-SHARE-THIS") ? "Valid cookie format detected" : "Please ensure this is a valid Roblox cookie")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(cookie.contains("_|WARNING:-DO-NOT-SHARE-THIS") ? .green : .orange)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill((cookie.contains("_|WARNING:-DO-NOT-SHARE-THIS") ? Color.green : Color.orange).opacity(0.1))
                            )
                            .transition(.opacity.combined(with: .scale))
                        }
                    }
                    
                    // Error message
                    if hasAttemptedContinue, let error = fieldErrors["cookie"] {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                            
                            Text(error)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .scale(scale: 0.8))
                        ))
                    }
                }
                
                // Security information
                VStack(alignment: .leading, spacing: 16) {
                    Text("Security Information")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        SecurityInfoRow(
                            icon: "lock.shield.fill",
                            text: "Your cookie is encrypted and stored securely",
                            color: .green
                        )
                        
                        SecurityInfoRow(
                            icon: "eye.slash.fill",
                            text: "We never share your information with third parties",
                            color: .blue
                        )
                        
                        SecurityInfoRow(
                            icon: "key.fill",
                            text: "Encryption key is stored locally in app data",
                            color: .purple
                        )
                        
                        SecurityInfoRow(
                            icon: "network.slash",
                            text: "No data is transmitted to external servers",
                            color: .orange
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                )
            }
            .frame(maxWidth: 600)
        }
        .sheet(isPresented: $showingCookieInstructions) {
            ZStack {
                Color.clear.ignoresSafeArea()
                CookieInstructionsView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var skippedCookieView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44))
                .foregroundColor(.green)
            Text("You chose to skip the cookie step")
                .font(.system(size: 20, weight: .bold))
            Text("You can paste your cookie later from Accounts → Edit Account.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
    }
    
    private var navigationButtons: some View {
        HStack(spacing: 16) {
            if currentStep > 0 {
                Button("Back") {
                    withAnimation(settingsManager.getSpringAnimation(for: .normal)) {
                        currentStep -= 1
                        validationError = nil
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            
            Spacer()
            
            Button(currentStep == totalSteps - 1 ? "Complete Setup" : "Continue") {
                handleContinue()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isValidating || !canContinue)
        }
    }
    
    private var canContinue: Bool {
        // Always allow user to press Continue - validation happens when they try
        return !isValidating
    }
    
    private func handleContinue() {
        hasAttemptedContinue = true
        
        // Validate current step
        switch currentStep {
        case 1:
            // If skipping cookie, require username here
            if skipCookieStep {
                if username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    fieldErrors["username"] = "Username is required when skipping cookie"
                    return
                } else {
                    fieldErrors.removeValue(forKey: "username")
                }
            }
        case 2:
            if !skipCookieStep {
                validateSetupCookie()
                if fieldErrors["cookie"] != nil { return }
                if username.isEmpty && !isFetchingUserInfo {
                    fieldErrors["cookie"] = "Please paste a valid cookie to auto-fill your username"
                    return
                } else if isFetchingUserInfo {
                    fieldErrors["cookie"] = "Please wait while we fetch your user info..."
                    return
                }
            } else {
                // When skipping cookie, require a username so we can create the account
                if username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // If no username yet, prompt user to enter one on the Account Info step
                    fieldErrors["cookie"] = "Please enter a username (since cookie was skipped)"
                    return
                }
                if displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    displayName = username
                }
            }
        default:
            break
        }
        
        if currentStep == totalSteps - 1 {
            completeSetup()
        } else {
            withAnimation(settingsManager.getSpringAnimation(for: .normal)) {
                currentStep += 1
                validationError = nil
                hasAttemptedContinue = false // Reset for next step
            }
            
            // Auto-fill display name if empty
            if currentStep == 2 && displayName.isEmpty {
                displayName = username
            }
        }
    }
    
    private func completeSetup() {
        isValidating = true
        validationError = nil
        
        let account = Account(
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            displayName: displayName.isEmpty ? username : displayName,
            cookie: skipCookieStep ? "" : cookie.trimmingCharacters(in: .whitespacesAndNewlines),
            avatarURL: avatarURL.isEmpty ? nil : avatarURL
        )
        
        let validation = accountManager.validateAccount(account, allowEmptyCookie: skipCookieStep)
        
        if validation.isValid {
            accountManager.addAccount(account)
            
            withAnimation(settingsManager.getSpringAnimation(for: .normal)) {
                isPresented = false
            }
        } else {
            validationError = validation.errors.first
        }
        
        isValidating = false
    }
    
    // MARK: - Enhanced Validation Methods
    
    private func validateSetupUsername() {
        // Username is now auto-filled from cookie, so no manual validation needed
        if !username.isEmpty {
            fieldErrors.removeValue(forKey: "username")
            
            // Auto-fill display name if empty
            if displayName.isEmpty {
                displayName = username
            }
        }
    }
    
    private func validateSetupCookie() {
        let trimmedCookie = cookie.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedCookie.isEmpty {
            fieldErrors["cookie"] = "Cookie is required"
        } else if !trimmedCookie.contains("_|WARNING:-DO-NOT-SHARE-THIS") {
            fieldErrors["cookie"] = "Invalid cookie format - please ensure you copied the complete .ROBLOSECURITY cookie"
        } else if trimmedCookie.count < 100 {
            fieldErrors["cookie"] = "Cookie appears to be incomplete"
        } else {
            fieldErrors.removeValue(forKey: "cookie")
        }
    }
    
    private func fetchUserInfoFromCookie(_ cookieValue: String) {
        guard !isFetchingUserInfo else { return }
        
        isFetchingUserInfo = true
        fieldErrors.removeValue(forKey: "cookie")
        
        Task {
            do {
                let userInfo = try await RobloxAPIService.shared.fetchUserInfo(from: cookieValue)
                
                await MainActor.run {
                    username = userInfo.username
                    displayName = userInfo.displayName
                    avatarURL = userInfo.avatarURL ?? ""
                    isFetchingUserInfo = false
                    fieldErrors.removeValue(forKey: "cookie")
                }
            } catch {
                await MainActor.run {
                    isFetchingUserInfo = false
                    if let robloxError = error as? RobloxAPIError {
                        fieldErrors["cookie"] = robloxError.localizedDescription
                    } else {
                        fieldErrors["cookie"] = "Failed to fetch user info"
                    }
                }
            }
        }
    }
}

// MARK: - Enhanced Setup Components

struct EnhancedSetupTextFieldStyle: TextFieldStyle {
    let hasError: Bool
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        hasError ? Color.red : Color.accentColor.opacity(0.4),
                        lineWidth: hasError ? 2 : 1.5
                    )
            )
            .font(.system(size: 16, weight: .medium))
            .shadow(color: hasError ? Color.red.opacity(0.2) : Color.accentColor.opacity(0.1), radius: 6, x: 0, y: 3)
            .scaleEffect(hasError ? 1.01 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: hasError)
    }
}

struct SecurityInfoRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
                .frame(width: 24, height: 24)
            
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let action: () -> Void
    
    @EnvironmentObject private var settingsManager: SettingsManager
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 20) {
            // Icon container with better visibility
            ZStack {
                Circle()
                    .fill(settingsManager.currentAccentColor.opacity(isPressed ? 0.25 : 0.15))
                    .frame(width: 44, height: 44)
                
                Circle()
                    .fill(settingsManager.currentAccentColor.opacity(isPressed ? 0.2 : 0.1))
                    .frame(width: 38, height: 38)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(settingsManager.currentAccentColor)
                    .shadow(color: settingsManager.currentAccentColor.opacity(0.3), radius: 2, x: 0, y: 1)
                    .scaleEffect(isPressed ? 0.95 : 1.0)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            // Subtle arrow indicator
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary.opacity(0.6))
                .scaleEffect(isPressed ? 1.1 : 1.0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor).opacity(isPressed ? 0.8 : 0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(settingsManager.currentAccentColor.opacity(isPressed ? 0.3 : 0.1), lineWidth: isPressed ? 2 : 1)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .shadow(color: isPressed ? settingsManager.currentAccentColor.opacity(0.3) : .black.opacity(0.05), radius: isPressed ? 8 : 8, x: 0, y: isPressed ? 6 : 4)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture {
            withAnimation(.spring(response: 0.15, dampingFraction: 0.6)) {
                isPressed = true
            }
            
            // Quick feedback animation and action
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isPressed = false
                }
                action()
            }
        }
    }
}

// MARK: - Modern Text Field Style

struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
            )
            .font(.system(size: 16))
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    @EnvironmentObject private var settingsManager: SettingsManager
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(settingsManager.currentAccentColor)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.secondary)
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Moving Orb Component

struct MovingOrb: View {
    let color: Color
    let size: CGFloat
    let delay: Double
    
    @State private var position = CGPoint(x: CGFloat.random(in: 100...700), y: CGFloat.random(in: 100...500))
    @State private var targetPosition = CGPoint(x: CGFloat.random(in: 100...700), y: CGFloat.random(in: 100...500))
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .position(position)
            .onAppear {
                startContinuousMovement()
            }
    }
    
    private func startContinuousMovement() {
        // Start the continuous movement animation
        Timer.scheduledTimer(withTimeInterval: 3.0 + delay, repeats: true) { _ in
            withAnimation(
                .easeInOut(duration: Double.random(in: 3...6))
            ) {
                position = CGPoint(
                    x: CGFloat.random(in: 50...750),
                    y: CGFloat.random(in: 50...550)
                )
            }
        }
        
        // Also start immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(
                .easeInOut(duration: Double.random(in: 3...6))
            ) {
                position = CGPoint(
                    x: CGFloat.random(in: 50...750),
                    y: CGFloat.random(in: 50...550)
                )
            }
        }
    }
}

#Preview {
    FirstTimeSetupView(isPresented: .constant(true))
        .environmentObject(AccountManager())
        .environmentObject(SettingsManager())
        .frame(width: 1000, height: 700)
}
