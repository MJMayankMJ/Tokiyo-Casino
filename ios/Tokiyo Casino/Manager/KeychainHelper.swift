//
//  KeychainHelper.swift
//  Spin Royale
//
//  Created by Mayank Jangid on 3/24/25.
//

import Foundation
import Security

class KeychainHelper {
    
    static let shared = KeychainHelper()
    private init() {}
    
    //  "yyyy-MM-dd" format so we only compare the day.
    private let dayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)  // So it’s consistent
        return df
    }()
    
    // MARK: - Store an array of day-strings
    func storeClaimedDays(_ days: [String], for key: String) {
        guard let data = try? JSONEncoder().encode(days) else {
            #if DEBUG
            print("Error: Could not encode days array to JSON.")
            #endif
            return
        }
        
        let query: [String: Any] = [
            kSecClass as String       : kSecClassGenericPassword,
            kSecAttrAccount as String : key,
            kSecValueData as String   : data
        ]
        
        // Delete any existing item with the same key
        SecItemDelete(query as CFDictionary)
        
        // Add the new item
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            #if DEBUG
            print("Error saving array to keychain: \(status)")
            #endif
        }
    }

    // MARK: - Retrieve an array of day-strings
    func retrieveClaimedDays(for key: String) -> [String] {
        let query: [String: Any] = [
            kSecClass as String       : kSecClassGenericPassword,
            kSecAttrAccount as String : key,
            kSecReturnData as String  : true,
            kSecMatchLimit as String  : kSecMatchLimitOne
        ]
        
        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess, let data = item as? Data else {
            // If nothing stored yet, return empty array
            return []
        }
        
        if let dayArray = try? JSONDecoder().decode([String].self, from: data) {
            return dayArray
        } else {
            #if DEBUG
            print("Error: Could not decode JSON from keychain data.")
            #endif
            return []
        }
    }

    // MARK: - Store raw data
    func storeData(_ data: Data, for key: String) {
        let query: [String: Any] = [
            kSecClass as String       : kSecClassGenericPassword,
            kSecAttrAccount as String : key,
            kSecValueData as String   : data
        ]

        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            #if DEBUG
            print("Error saving data to keychain: \(status)")
            #endif
        }
    }

    // MARK: - Retrieve raw data
    func retrieveData(for key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String       : kSecClassGenericPassword,
            kSecAttrAccount as String : key,
            kSecReturnData as String  : true,
            kSecMatchLimit as String  : kSecMatchLimitOne
        ]

        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess else {
            return nil
        }

        return item as? Data
    }
    
    // MARK: - Add a single date to the existing array
    func addClaimedDay(_ date: Date, for key: String) {
        let dayString = dayFormatter.string(from: date)
        
        // Retrieve existing days
        var existingDays = retrieveClaimedDays(for: key)
        
        // Only add if it's not already in the array
        if !existingDays.contains(dayString) {
            existingDays.append(dayString)
            storeClaimedDays(existingDays, for: key)
        }
    }
    
    // for future: check if a specific day is in the keychain array ----- if situation arises
    func isDayClaimed(_ date: Date, for key: String) -> Bool {
        let dayString = dayFormatter.string(from: date)
        let existingDays = retrieveClaimedDays(for: key)
        return existingDays.contains(dayString)
    }
    
    // MARK: - (Optional) Reset Keychain --- this is for testing purposes cz i dont know how to make the app work while changing time
    func resetKeychain() {
        let secItemClasses: [CFString] = [
            kSecClassGenericPassword,
            kSecClassInternetPassword,
            kSecClassCertificate,
            kSecClassKey,
            kSecClassIdentity
        ]
        
        for itemClass in secItemClasses {
            let query: [CFString: Any] = [kSecClass: itemClass]
            let status = SecItemDelete(query as CFDictionary)
            #if DEBUG
            if status == errSecSuccess || status == errSecItemNotFound {
                print("Successfully deleted items for class \(itemClass)")
            } else {
                print("Error deleting items for class \(itemClass): \(status)")
            }
            #endif
        }
    }
}
