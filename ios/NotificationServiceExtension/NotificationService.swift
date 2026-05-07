import UserNotifications
import Foundation

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        if let bestAttemptContent = bestAttemptContent {
            let userInfo = bestAttemptContent.userInfo
            
            // 1. Check if encrypted
            if let senderId = userInfo["sender_id"] as? String ?? userInfo["actor_id"] as? String,
               let headerBase64 = userInfo["header"] as? String,
               let contentBase64 = userInfo["content"] as? String ?? userInfo["body"] as? String {
                
                decryptAndShow(senderId: senderId, 
                               headerBase64: headerBase64, 
                               contentBase64: contentBase64, 
                               userInfo: userInfo)
            } else {
                contentHandler(bestAttemptContent)
            }
        }
    }
    
    private func decryptAndShow(senderId: String, headerBase64: String, contentBase64: String, userInfo: [AnyHashable: Any]) {
        guard let bestAttemptContent = bestAttemptContent, let contentHandler = contentHandler else { return }
        
        // 1. Load Encryption Key from Shared Keychain (via App Group)
        // Note: You must configure App Groups in Xcode for this to work.
        let groupName = "group.com.oasis.app" // Replace with actual group
        
        // Use a simple Keychain wrapper or Security framework
        // Assuming the key was saved by Flutter with the same App Group
        guard let encryptionKey = loadKeyFromKeychain(key: "pq_aura_state_encryption_key", group: groupName) else {
            contentHandler(bestAttemptContent)
            return
        }
        
        // 2. Construct Shared Path
        let fileManager = FileManager.default
        guard let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupName) else {
            contentHandler(bestAttemptContent)
            return
        }
        
        let sessionURL = groupURL.appendingPathComponent("pqa_sessions/session_\(senderId).pqa")
        
        if !fileManager.fileExists(atPath: sessionURL.path) {
            contentHandler(bestAttemptContent)
            return
        }
        
        // 3. Native Decryption
        var statePtr: OpaquePointer? = nil
        defer {
            if let ptr = statePtr {
                PqAuraNative.freeState(statePtr: ptr)
            }
        }
        
        statePtr = PqAuraNative.loadAtomic(path: sessionURL.path, key: encryptionKey)
        
        guard let ptr = statePtr,
              let header = Data(base64Encoded: headerBase64),
              let ciphertext = Data(base64Encoded: contentBase64) else {
            contentHandler(bestAttemptContent)
            return
        }
        
        let ad = (userInfo["ad"] as? String ?? "").data(using: .utf8) ?? Data()
        
        if let plaintextData = PqAuraNative.decrypt(statePtr: ptr, header: header, payload: ciphertext, ad: ad) {
            // 4. Update State Atomic
            _ = PqAuraNative.saveAtomic(statePtr: ptr, path: sessionURL.path, key: encryptionKey)
            
            bestAttemptContent.body = String(data: plaintextData, encoding: .utf8) ?? "🔒 New Message"
            contentHandler(bestAttemptContent)
        } else {
            contentHandler(bestAttemptContent)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
    
    private func loadKeyFromKeychain(key: String, group: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrAccessGroup as String: group,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess {
            return result as? Data
        } else {
            print("Keychain error: \(status)")
            return nil
        }
    }
}
