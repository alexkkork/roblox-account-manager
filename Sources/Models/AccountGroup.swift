import Foundation

struct AccountGroup: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var accountIds: [UUID]
    var createdAt: Date
    var updatedAt: Date
    
    init(name: String, accountIds: [UUID] = []) {
        self.id = UUID()
        self.name = name
        self.accountIds = accountIds
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

