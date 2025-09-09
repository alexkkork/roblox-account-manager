import Foundation
import Combine
import AppKit

extension Notification.Name {
    static let accountsChanged = Notification.Name("accountsChanged")
}

@MainActor
class AccountManager: ObservableObject {
    @Published var accounts: [Account] = []
    @Published var isLoading = false
    @Published var error: AppError?
    @Published var selectedAccount: Account?
    
    private let storage = SecureStorage.shared
    private let fileName = "accounts.json"
    @Published var authenticatedUserId: Int?
    
    init() {
        loadAccounts()
    }
    
    // MARK: - Account Management
    
    func addAccount(_ account: Account) {
        // Prevent duplicates by username or cookie
        if accounts.contains(where: { $0.username.lowercased() == account.username.lowercased() }) {
            self.error = .validationFailed(["An account with this username already exists."])
            return
        }
        if !account.cookie.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           accounts.contains(where: { !$0.cookie.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.cookie == account.cookie }) {
            self.error = .validationFailed(["An account with this cookie already exists."])
            return
        }
        accounts.append(account)
        saveAccounts()
    }
    
    func updateAccount(_ account: Account) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account
            saveAccounts()
        }
    }
    
    func deleteAccount(_ account: Account) {
        accounts.removeAll { $0.id == account.id }
        if selectedAccount?.id == account.id {
            selectedAccount = nil
        }
        saveAccounts()
    }
    
    func selectAccount(_ account: Account) {
        selectedAccount = account
        updateLastUsed(for: account)
    }
    
    func toggleAccountActive(_ account: Account) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index].isActive.toggle()
            saveAccounts()
        }
    }
    
    private func updateLastUsed(for account: Account) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index].lastUsed = Date()
            saveAccounts()
        }
    }
    
    // MARK: - Search and Filter
    
    func searchAccounts(query: String) -> [Account] {
        guard !query.isEmpty else { return accounts }
        
        return accounts.filter { account in
            account.username.localizedCaseInsensitiveContains(query) ||
            account.displayName.localizedCaseInsensitiveContains(query) ||
            account.tags.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }
    
    func filterAccounts(by tags: [String], activeOnly: Bool = false) -> [Account] {
        var filtered = accounts
        
        if activeOnly {
            filtered = filtered.filter { $0.isActive }
        }
        
        if !tags.isEmpty {
            filtered = filtered.filter { account in
                tags.allSatisfy { tag in
                    account.tags.contains { $0.localizedCaseInsensitiveContains(tag) }
                }
            }
        }
        
        return filtered
    }
    
    func sortAccounts(by sortType: AccountSortType) -> [Account] {
        switch sortType {
        case .username:
            return accounts.sorted { $0.username.localizedCaseInsensitiveCompare($1.username) == .orderedAscending }
        case .displayName:
            return accounts.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        case .lastUsed:
            return accounts.sorted { $0.lastUsed > $1.lastUsed }
        case .createdAt:
            return accounts.sorted { $0.createdAt > $1.createdAt }
        case .active:
            return accounts.sorted { $0.isActive && !$1.isActive }
        }
    }
    
    // MARK: - Validation
    
    func validateAccount(_ account: Account, allowEmptyCookie: Bool = false) -> ValidationResult {
        var errors: [String] = []
        
        if account.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Username cannot be empty")
        }
        
        if account.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Display name cannot be empty")
        }
        
        if account.cookie.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if !allowEmptyCookie {
                errors.append("Cookie cannot be empty")
            }
        } else if !isValidRobloxCookie(account.cookie) {
            errors.append("Invalid Roblox cookie format")
        }
        
        if accounts.contains(where: { $0.username.lowercased() == account.username.lowercased() && $0.id != account.id }) {
            errors.append("Account with this username already exists")
        }
        if !account.cookie.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           accounts.contains(where: { $0.cookie == account.cookie && $0.id != account.id && !$0.cookie.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            errors.append("Account with this cookie already exists")
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    private func isValidRobloxCookie(_ cookie: String) -> Bool {
        // Basic validation for Roblox cookie format
        return cookie.contains("_|WARNING:-DO-NOT-SHARE-THIS.--Sharing-this-will-allow-someone-to-log-in-as-you-and-to-steal-your-ROBUX-and-items.|_")
    }
    
    // MARK: - Bulk Operations
    
    func exportAccounts() throws -> URL {
        let exportData = ExportData(
            accounts: accounts,
            exportedAt: Date(),
            version: "1.0"
        )
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("accounts_export_\(Date().timeIntervalSince1970)")
            .appendingPathExtension("json")
        
        try storage.save(exportData, to: tempURL.lastPathComponent, encrypted: false)
        return tempURL
    }
    
    func importAccounts(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let exportData = try JSONDecoder().decode(ExportData.self, from: data)
        
        for importedAccount in exportData.accounts {
            if !accounts.contains(where: { $0.username.lowercased() == importedAccount.username.lowercased() }) {
                accounts.append(importedAccount)
            }
        }
        
        saveAccounts()
    }
    
    // MARK: - Persistence
    
    private func loadAccounts() {
        isLoading = true
        error = nil
        
        if storage.exists(fileName) {
            do {
                // Prefer plaintext JSON (no encryption)
                accounts = try storage.load([Account].self, from: fileName, encrypted: false)
            } catch {
                // Fallback: load legacy encrypted file and migrate to plaintext
                do {
                    accounts = try storage.load([Account].self, from: fileName, encrypted: true)
                    try storage.save(accounts, to: fileName, encrypted: false)
                } catch {
                    self.error = AppError.loadingFailed(error.localizedDescription)
                }
            }
        }
        
        isLoading = false

        // Backfill missing avatar URLs for existing accounts
        refreshMissingAvatars()
    }
    
    private func saveAccounts() {
        do {
            // Save accounts as plain JSON (no encryption)
            try storage.save(accounts, to: fileName, encrypted: false)
        } catch {
            self.error = AppError.savingFailed(error.localizedDescription)
        }
        // Notify others of count change
        NotificationCenter.default.post(name: .accountsChanged, object: nil, userInfo: ["count": accounts.filter{ $0.isActive }.count])
    }

    // MARK: - Avatar Backfill
    private func refreshMissingAvatars() {
        for index in accounts.indices {
            if (accounts[index].avatarURL ?? "").isEmpty {
                let cookie = accounts[index].cookie
                Task {
                    do {
                        let user = try await RobloxAPIService.shared.fetchUserInfo(from: cookie)
                        await MainActor.run {
                            // Update avatar (and also update username/displayName if we don't have anything meaningful)
                            accounts[index].avatarURL = user.avatarURL
                            if accounts[index].username.isEmpty { accounts[index].username = user.username }
                            if accounts[index].displayName.isEmpty { accounts[index].displayName = user.displayName }
                            saveAccounts()
                        }
                    } catch {
                        // Ignore failures to keep UI responsive
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Types

enum AccountSortType: String, CaseIterable {
    case username = "username"
    case displayName = "displayName"
    case lastUsed = "lastUsed"
    case createdAt = "createdAt"
    case active = "active"
    
    var displayName: String {
        switch self {
        case .username: return "Username"
        case .displayName: return "Display Name"
        case .lastUsed: return "Last Used"
        case .createdAt: return "Date Created"
        case .active: return "Active Status"
        }
    }
}

struct ValidationResult {
    let isValid: Bool
    let errors: [String]
}

struct ExportData: Codable {
    let accounts: [Account]
    let exportedAt: Date
    let version: String
}

enum AppError: LocalizedError {
    case loadingFailed(String)
    case savingFailed(String)
    case validationFailed([String])
    case networkError(String)
    case launchError(String)
    
    var errorDescription: String? {
        switch self {
        case .loadingFailed(let message):
            return "Loading failed: \(message)"
        case .savingFailed(let message):
            return "Saving failed: \(message)"
        case .validationFailed(let errors):
            return "Validation failed: \(errors.joined(separator: ", "))"
        case .networkError(let message):
            return "Network error: \(message)"
        case .launchError(let message):
            return "Launch error: \(message)"
        }
    }
}
