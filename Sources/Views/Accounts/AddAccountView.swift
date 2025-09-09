import SwiftUI

struct AddAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var accountManager: AccountManager
    @EnvironmentObject private var settingsManager: SettingsManager
    
    @State private var username = ""
    @State private var displayName = ""
    @State private var cookie = ""
    // removed notes state
    
    @State private var tags = ""
    @State private var avatarURL = ""
    @State private var isActive = true
    
    @State private var isValidating = false
    @State private var validationErrors: [String] = []
    @State private var showingCookieInstructions = false
    @State private var fieldErrors: [String: String] = [:]
    @State private var showingSuccessAnimation = false
    @State private var currentStep = 0
    @State private var isFetchingUserInfo = false
    
    var body: some View {
        ZStack {
            // Background
            backgroundView
            
            if showingSuccessAnimation {
                successAnimationView
            } else {
                mainContentView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minWidth: 760, minHeight: 800)
        .sheet(isPresented: $showingCookieInstructions) {
            CookieInstructionsView()
        }
        .onAppear {
            validateFields()
        }
    }
    
    private var backgroundView: some View {
        ZStack {
            // Base background
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()
            
            // Gradient overlay
            LinearGradient(
                colors: [
                    settingsManager.currentAccentColor.opacity(0.08),
                    Color.clear,
                    settingsManager.currentAccentColor.opacity(0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Floating orbs
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(settingsManager.currentAccentColor.opacity(0.06))
                    .frame(width: CGFloat.random(in: 100...200))
                    .position(
                        x: CGFloat.random(in: 0...700),
                        y: CGFloat.random(in: 0...800)
                    )
                    .animation(
                        .easeInOut(duration: Double.random(in: 4...8))
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 1.0),
                        value: currentStep
                    )
            }
        }
    }
    
    private var mainContentView: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Enhanced Header
                    enhancedHeaderView
                    
                    // Progress Steps
                    progressStepsView
                    
                    // Form with real-time validation
                    enhancedFormView
                    
                    // Action buttons
                    actionButtonsView
                }
                .padding(.horizontal, 50)
                .padding(.vertical, 40)
            }
            .navigationTitle("Add New Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var successAnimationView: some View {
        VStack(spacing: 24) {
            // Success icon with animation
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.green, .green.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(showingSuccessAnimation ? 1.0 : 0.5)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6), value: showingSuccessAnimation)
                // removed notes UI
                Image(systemName: "checkmark")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(showingSuccessAnimation ? 1.0 : 0.5)
                    .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2), value: showingSuccessAnimation)
            }
            .shadow(color: .green.opacity(0.3), radius: 20, x: 0, y: 10)
            
            VStack(spacing: 12) {
                Text("Account Added Successfully!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .opacity(showingSuccessAnimation ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.5).delay(0.4), value: showingSuccessAnimation)
                
                Text("Your account has been securely saved and is ready to use")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .opacity(showingSuccessAnimation ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.5).delay(0.6), value: showingSuccessAnimation)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                dismiss()
            }
        }
    }
    
    private var enhancedHeaderView: some View {
        VStack(spacing: 20) {
            // Animated icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                settingsManager.currentAccentColor,
                                settingsManager.currentAccentColor.opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .scaleEffect(1.0 + sin(Date().timeIntervalSince1970 * 2) * 0.05)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: currentStep)
                
                Image(systemName: "person.badge.plus.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
            }
            .shadow(color: settingsManager.currentAccentColor.opacity(0.3), radius: 15, x: 0, y: 8)
            
            VStack(spacing: 12) {
                Text("Add New Account")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Securely add another Roblox account to your collection")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
    }
    
    private var progressStepsView: some View {
        HStack(spacing: 16) {
            ForEach(0..<4, id: \.self) { step in
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(stepColor(for: step))
                            .frame(width: 40, height: 40)
                        
                        if step < currentStep {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text("\(step + 1)")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(step == currentStep ? .white : .secondary)
                        }
                    }
                    
                    Text(stepTitle(for: step))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(step <= currentStep ? settingsManager.currentAccentColor : .secondary)
                        .multilineTextAlignment(.center)
                }
                
                if step < 3 {
                    Rectangle()
                        .fill(step < currentStep ? settingsManager.currentAccentColor : Color.secondary.opacity(0.3))
                        .frame(height: 2)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var enhancedFormView: some View {
        VStack(spacing: 24) {
            // Username with real-time validation
            EnhancedFormField(
                title: "Username",
                isRequired: true,
                errorMessage: fieldErrors["username"],
                validation: {
                    validateUsername()
                },
                content: {
                    HStack {
                        TextField(username.isEmpty ? "Enter your Roblox username" : "Username (auto-filled)", text: $username)
                            .textFieldStyle(ValidatedTextFieldStyle(hasError: fieldErrors["username"] != nil))
                            .onSubmit { validateUsername() }
                            .disabled(!username.isEmpty && isFetchingUserInfo)
                        
                        if isFetchingUserInfo {
                            ProgressView()
                                .scaleEffect(0.8)
                                .padding(.trailing, 8)
                        } else if !username.isEmpty {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .padding(.trailing, 8)
                        }
                    }
                }
            )
            
            // Display Name
            EnhancedFormField(
                title: "Display Name",
                subtitle: "How this account will appear in the app",
                content: {
                    HStack {
                        TextField(displayName.isEmpty ? "Enter display name (optional)" : "Display Name (auto-filled)", text: $displayName)
                            .textFieldStyle(ValidatedTextFieldStyle(hasError: false))
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
                }
            )
            
            // Cookie with validation and help
            EnhancedFormField(
                title: "Roblox Cookie",
                isRequired: true,
                errorMessage: fieldErrors["cookie"],
                action: {
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
                },
                validation: {
                    validateCookie()
                },
                content: {
                    VStack(spacing: 8) {
                        SecureField("Paste your Roblox cookie here", text: $cookie)
                            .textFieldStyle(ValidatedTextFieldStyle(hasError: fieldErrors["cookie"] != nil))
                            .font(.system(size: 12).monospaced())
                            .onSubmit { 
                                validateCookie()
                                if !cookie.isEmpty && cookie.count > 50 {
                                    fetchUserInfoFromCookie(cookie)
                                }
                            }
                            .onChange(of: cookie) { newValue in
                                // Debounced fetch: basic guard to avoid spam
                                if !newValue.isEmpty && newValue.count > 100 && newValue.contains("_|WARNING:-DO-NOT-SHARE-THIS") {
                                    fetchUserInfoFromCookie(newValue)
                                }
                            }
                        
                        if !cookie.isEmpty {
                            HStack {
                                Image(systemName: cookie.contains("_|WARNING:-DO-NOT-SHARE-THIS") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .foregroundColor(cookie.contains("_|WARNING:-DO-NOT-SHARE-THIS") ? .green : .orange)
                                
                                Text(cookie.contains("_|WARNING:-DO-NOT-SHARE-THIS") ? "Valid cookie format detected" : "Please ensure this is a valid Roblox cookie")
                                    .font(.system(size: 12))
                                    .foregroundColor(cookie.contains("_|WARNING:-DO-NOT-SHARE-THIS") ? .green : .orange)
                            }
                            .transition(.opacity.combined(with: .scale))
                        }
                    }
                }
            )
            
            // Optional fields section
            VStack(spacing: 20) {
                SectionHeader(title: "Optional Information", subtitle: "Additional details to organize your account")
                
                // Avatar URL
                EnhancedFormField(
                    title: "Avatar URL",
                    subtitle: "Direct link to your avatar image",
                    content: {
                        TextField("https://example.com/avatar.png", text: $avatarURL)
                            .textFieldStyle(ValidatedTextFieldStyle(hasError: false))
                    }
                )
                
                // Tags
                EnhancedFormField(
                    title: "Tags",
                    subtitle: "Organize with tags (comma-separated)",
                    content: {
                        TextField("main, alt, testing, work", text: $tags)
                            .textFieldStyle(ValidatedTextFieldStyle(hasError: false))
                    }
                )
                
                
            }
            
            // Account settings
            VStack(spacing: 16) {
                SectionHeader(title: "Account Settings", subtitle: "Configure how this account behaves")
                
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "power")
                                .font(.system(size: 16))
                                .foregroundColor(isActive ? .green : .secondary)
                            
                            Text("Active Account")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        
                        Text("Active accounts appear in launch options and can be used immediately")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $isActive)
                        .toggleStyle(SwitchToggleStyle(tint: settingsManager.currentAccentColor))
                        .scaleEffect(1.2)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                )
            }
        }
    }
    
    private var actionButtonsView: some View {
        VStack(spacing: 16) {
            // Main action button
            Button(action: addAccount) {
                HStack {
                    if isValidating {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    
                    Text(isValidating ? "Adding Account..." : "Add Account")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(canAddAccount && !isValidating ? settingsManager.currentAccentColor : Color.secondary)
                )
                .scaleEffect(canAddAccount && !isValidating ? 1.0 : 0.98)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: canAddAccount)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!canAddAccount || isValidating)
            
            // Secondary actions
            HStack(spacing: 16) {
                Button("Import Account") {
                    // Future feature: Import account from file
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(settingsManager.currentAccentColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(settingsManager.currentAccentColor, lineWidth: 1)
                )
                .buttonStyle(PlainButtonStyle())
                
                Button("Validate Cookie") {
                    validateCookie()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(settingsManager.currentAccentColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(settingsManager.currentAccentColor, lineWidth: 1)
                )
                .buttonStyle(PlainButtonStyle())
                .disabled(cookie.isEmpty)
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var errorsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("Please fix the following issues:")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.red)
            }
            
            ForEach(validationErrors, id: \.self) { error in
                HStack(alignment: .top) {
                    Text("•")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.red.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var canAddAccount: Bool {
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !cookie.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Validation Methods
    
    private func validateFields() {
        validateUsername()
        validateCookie()
        updateCurrentStep()
    }
    
    private func validateUsername() {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedUsername.isEmpty {
            fieldErrors["username"] = "Username is required"
        } else if trimmedUsername.count < 3 {
            fieldErrors["username"] = "Username must be at least 3 characters"
        } else if trimmedUsername.count > 20 {
            fieldErrors["username"] = "Username must be 20 characters or less"
        } else if !trimmedUsername.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
            fieldErrors["username"] = "Username can only contain letters, numbers, and underscores"
        } else {
            fieldErrors.removeValue(forKey: "username")
            
            // Auto-fill display name if empty
            if displayName.isEmpty {
                displayName = trimmedUsername
            }
        }
    }
    
    private func validateCookie() {
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
    
    private func updateCurrentStep() {
        if fieldErrors["username"] == nil && !username.isEmpty {
            if fieldErrors["cookie"] == nil && !cookie.isEmpty {
                currentStep = 3
            } else {
                currentStep = 2
            }
        } else if !username.isEmpty {
            currentStep = 1
        } else {
            currentStep = 0
        }
    }
    
    private func stepColor(for step: Int) -> Color {
        if step < currentStep {
            return .green
        } else if step == currentStep {
            return settingsManager.currentAccentColor
        } else {
            return Color.secondary.opacity(0.3)
        }
    }
    
    private func stepTitle(for step: Int) -> String {
        switch step {
        case 0: return "Basic Info"
        case 1: return "Username"
        case 2: return "Cookie"
        case 3: return "Complete"
        default: return ""
        }
    }
    
    private func addAccount() {
        isValidating = true
        validateFields()
        
        // Check if there are any field errors
        if !fieldErrors.isEmpty {
            isValidating = false
            return
        }
        
        let parsedTags = tags.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        let account = Account(
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            displayName: displayName.isEmpty ? username : displayName,
            cookie: cookie.trimmingCharacters(in: .whitespacesAndNewlines),
            avatarURL: avatarURL.isEmpty ? nil : avatarURL
        )
        
        var newAccount = account
        newAccount.tags = parsedTags
        newAccount.isActive = isActive
        
        let validation = accountManager.validateAccount(newAccount)
        
        if validation.isValid {
            accountManager.addAccount(newAccount)
            
            // Show success animation
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showingSuccessAnimation = true
            }
        } else {
            validationErrors = validation.errors
        }
        
        isValidating = false
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
                    validateFields()
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

// MARK: - Form Field

struct FormField<Content: View>: View {
    let title: String
    let subtitle: String?
    let isRequired: Bool
    let action: (() -> Void)?
    @ViewBuilder let content: Content
    
    init(
        title: String,
        subtitle: String? = nil,
        isRequired: Bool = false,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.isRequired = isRequired
        self.action = action
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if isRequired {
                        Text("*")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.red)
                    }
                }
                
                Spacer()
                
                if let action = action {
                    Button(action: action) {
                        // Action button content is provided by the caller
                    }
                }
            }
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            content
        }
    }
}

// MARK: - Enhanced Components

struct EnhancedFormField<Content: View>: View {
    let title: String
    let subtitle: String?
    let isRequired: Bool
    let errorMessage: String?
    let action: (() -> Void)?
    let validation: (() -> Void)?
    @ViewBuilder let content: Content
    
    @EnvironmentObject private var settingsManager: SettingsManager
    
    init(
        title: String,
        subtitle: String? = nil,
        isRequired: Bool = false,
        errorMessage: String? = nil,
        action: (() -> Void)? = nil,
        validation: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.isRequired = isRequired
        self.errorMessage = errorMessage
        self.action = action
        self.validation = validation
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if isRequired {
                        Text("*")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.red)
                    }
                    
                    if errorMessage == nil && isRequired {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.green)
                            .opacity(validation != nil ? 1.0 : 0.0)
                            .animation(.easeInOut(duration: 0.2), value: errorMessage)
                    }
                }
                
                Spacer()
                
                if let action = action {
                    Button(action: action) {
                        // Action content provided by caller
                    }
                }
            }
            
            // Subtitle
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            // Content
            content
            
            // Error message
            if let errorMessage = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                    
                    Text(errorMessage)
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
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    errorMessage != nil ? Color.red.opacity(0.5) : settingsManager.currentAccentColor.opacity(0.2),
                    lineWidth: errorMessage != nil ? 2 : 1
                )
        )
        .scaleEffect(errorMessage != nil ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: errorMessage)
    }
}

struct ValidatedTextFieldStyle: TextFieldStyle {
    let hasError: Bool
    @EnvironmentObject private var settingsManager: SettingsManager
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        hasError ? Color.red : settingsManager.currentAccentColor.opacity(0.4),
                        lineWidth: hasError ? 2 : 1
                    )
            )
            .font(.system(size: 16))
            .shadow(color: hasError ? Color.red.opacity(0.2) : Color.clear, radius: 4, x: 0, y: 2)
            .scaleEffect(hasError ? 1.01 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: hasError)
    }
}

struct SectionHeader: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }
}

// MARK: - View Extensions

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

#Preview {
    AddAccountView()
        .environmentObject(AccountManager())
        .environmentObject(SettingsManager())
}
