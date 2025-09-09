import Foundation
import CryptoKit

class SecureStorage: ObservableObject {
    static let shared = SecureStorage()
    
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private var appSupportDirectory: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    }
    
    private var appDataDirectory: URL {
        let url = appSupportDirectory.appendingPathComponent("RobloxAccountManager", isDirectory: true)
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    
    private var encryptionKey: SymmetricKey {
        let keyData = getOrCreateEncryptionKey()
        return SymmetricKey(data: keyData)
    }
    
    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - Encryption Key Management
    
    private func getOrCreateEncryptionKey() -> Data {
        let keyFileURL = appDataDirectory.appendingPathComponent("encryption.key")
        // Try file-based key first (no Keychain, no prompts)
        if let existing = try? Data(contentsOf: keyFileURL), existing.count == 32 {
            return existing
        }
        // If a legacy Keychain key exists, migrate it to file then delete
        let legacyKeychain = Keychain()
        let legacyIdentifier = "com.robloxmanager.encryptionkey"
        if let legacy = legacyKeychain.getData(legacyIdentifier), legacy.count == 32 {
            try? legacy.write(to: keyFileURL, options: [.atomic])
            legacyKeychain.deleteData(forKey: legacyIdentifier)
            return legacy
        }
        // Create a new random key and persist to file
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        try? keyData.write(to: keyFileURL, options: [.atomic])
        return keyData
    }
    
    // MARK: - Generic Storage Methods
    
    func save<T: Codable>(_ object: T, to fileName: String, encrypted: Bool = true) throws {
        let data = try encoder.encode(object)
        let fileURL = appDataDirectory.appendingPathComponent(fileName)
        
        if encrypted {
            let encryptedData = try encrypt(data)
            try encryptedData.write(to: fileURL)
        } else {
            try data.write(to: fileURL)
        }
    }
    
    func load<T: Codable>(_ type: T.Type, from fileName: String, encrypted: Bool = true) throws -> T {
        let fileURL = appDataDirectory.appendingPathComponent(fileName)
        let data = try Data(contentsOf: fileURL)
        
        let decodableData: Data
        if encrypted {
            decodableData = try decrypt(data)
        } else {
            decodableData = data
        }
        
        return try decoder.decode(type, from: decodableData)
    }
    
    func exists(_ fileName: String) -> Bool {
        let fileURL = appDataDirectory.appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    func delete(_ fileName: String) throws {
        let fileURL = appDataDirectory.appendingPathComponent(fileName)
        try fileManager.removeItem(at: fileURL)
    }
    
    // MARK: - Encryption/Decryption
    
    private func encrypt(_ data: Data) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: encryptionKey)
        return sealedBox.combined!
    }
    
    private func decrypt(_ encryptedData: Data) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        return try AES.GCM.open(sealedBox, using: encryptionKey)
    }
    
    // MARK: - Backup and Restore
    
    func createBackup() throws -> URL {
        let backupURL = appDataDirectory.appendingPathComponent("backup_\(Date().timeIntervalSince1970).zip")
        // Implementation for creating zip backup would go here
        return backupURL
    }
    
    func restoreFromBackup(at url: URL) throws {
        // Implementation for restoring from backup would go here
    }
}

// MARK: - Keychain Helper

private class Keychain {
    func setData(_ data: Data, forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func getData(_ key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        return status == errSecSuccess ? result as? Data : nil
    }
    
    func deleteData(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}
