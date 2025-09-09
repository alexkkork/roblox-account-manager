import Foundation

@MainActor
class GroupManager: ObservableObject {
    @Published var groups: [AccountGroup] = []
    @Published var isLoading = false
    @Published var error: AppError?
    
    private let storage = SecureStorage.shared
    private let fileName = "account_groups.json"
    
    init() {
        load()
    }
    
    @discardableResult
    func create(name: String, accountIds: [UUID] = []) -> AccountGroup {
        var group = AccountGroup(name: name, accountIds: accountIds)
        group.updatedAt = Date()
        groups.append(group)
        save()
        return group
    }
    
    func update(_ group: AccountGroup) {
        if let idx = groups.firstIndex(where: { $0.id == group.id }) {
            var g = group
            g.updatedAt = Date()
            groups[idx] = g
            save()
        }
    }
    
    func delete(_ group: AccountGroup) {
        groups.removeAll { $0.id == group.id }
        save()
    }
    
    func addAccount(_ accountId: UUID, to groupId: UUID) {
        guard let idx = groups.firstIndex(where: { $0.id == groupId }) else { return }
        if !groups[idx].accountIds.contains(accountId) {
            objectWillChange.send()
            groups[idx].accountIds.append(accountId)
            groups[idx].updatedAt = Date()
            // Reassign to trigger @Published change propagation
            groups[idx] = groups[idx]
            groups = groups
            save()
        }
    }
    
    func removeAccount(_ accountId: UUID, from groupId: UUID) {
        guard let idx = groups.firstIndex(where: { $0.id == groupId }) else { return }
        objectWillChange.send()
        groups[idx].accountIds.removeAll { $0 == accountId }
        groups[idx].updatedAt = Date()
        groups[idx] = groups[idx]
        groups = groups
        save()
    }
    
    private func load() {
        isLoading = true
        error = nil
        do {
            if storage.exists(fileName) {
                groups = try storage.load([AccountGroup].self, from: fileName)
            }
        } catch {
            self.error = AppError.loadingFailed(error.localizedDescription)
        }
        isLoading = false
    }
    
    private func save() {
        do {
            try storage.save(groups, to: fileName)
        } catch {
            self.error = AppError.savingFailed(error.localizedDescription)
        }
    }
}


