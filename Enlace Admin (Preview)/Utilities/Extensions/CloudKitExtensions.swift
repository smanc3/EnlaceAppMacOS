import Foundation
import CloudKit

// MARK: - CKRecord Extensions
extension CKRecord {
    /// Safely get all keys from a CKRecord
    func getAllKeys() -> [String] {
        // Use a direct approach that doesn't call allKeys()
        // Get keys via KVC mechanism to avoid circular references
        let keypaths = value(forKey: "allKeys") as? [String] ?? []
        return keypaths
    }
    
    /// Get a string representation of all record fields for debugging
    func debugDescription() -> String {
        let keys = getAllKeys()
        var result = "CKRecord(\(recordType), id: \(recordID.recordName))\n"
        
        for key in keys {
            if let value = self[key] {
                result += "  - \(key): \(String(describing: value))\n"
            } else {
                result += "  - \(key): nil\n"
            }
        }
        
        return result
    }
    
    /// Log record contents to console
    func logRecordContents(label: String = "") {
        print("📊 CKRecord: \(label)")
        print(debugDescription())
    }
    
    // MARK: - Advanced Debugging Extensions
    
    /// Log detailed information about a CKRecord including container and zone details
    func logDebugInfo() {
        let containerID = self.recordID.zoneID.ownerName
        let recordType = self.recordType
        let recordName = self.recordID.recordName
        let recordZone = self.recordID.zoneID.zoneName
        
        print("📊 CKRecord Debug Info:")
        print("📊 - Container: \(containerID)")
        print("📊 - Record Type: \(recordType)")
        print("📊 - Record Name: \(recordName)")
        print("📊 - Zone: \(recordZone)")
        
        if let mirrorName = self["recordNameMirror"] as? String {
            if mirrorName != recordName {
                print("⚠️ Warning: recordNameMirror (\(mirrorName)) does not match record ID (\(recordName))")
            }
        }
    }
    
    /// Compare two CKRecords and log differences
    static func logRecordDifferences(record1: CKRecord, record2: CKRecord) {
        print("📊 CKRecord Comparison:")
        
        if record1.recordID.zoneID.ownerName != record2.recordID.zoneID.ownerName {
            print("⚠️ Container mismatch detected!")
            print("📊 - Record 1 Container: \(record1.recordID.zoneID.ownerName)")
            print("📊 - Record 2 Container: \(record2.recordID.zoneID.ownerName)")
        }
        
        let keys1 = Set(record1.getAllKeys())
        let keys2 = Set(record2.getAllKeys())
        
        let uniqueToRecord1 = keys1.subtracting(keys2)
        let uniqueToRecord2 = keys2.subtracting(keys1)
        let commonKeys = keys1.intersection(keys2)
        
        if !uniqueToRecord1.isEmpty {
            print("📊 Keys only in Record 1: \(uniqueToRecord1.joined(separator: ", "))")
        }
        
        if !uniqueToRecord2.isEmpty {
            print("📊 Keys only in Record 2: \(uniqueToRecord2.joined(separator: ", "))")
        }
        
        for key in commonKeys {
            let value1 = record1[key]
            let value2 = record2[key]
            
            if !areEqual(value1, value2) {
                print("📊 Value differs for key '\(key)':")
                print("📊 - Record 1: \(String(describing: value1))")
                print("📊 - Record 2: \(String(describing: value2))")
            }
        }
    }
    
    private static func areEqual(_ value1: Any?, _ value2: Any?) -> Bool {
        // Basic equality check for common CloudKit types
        if let v1 = value1 as? String, let v2 = value2 as? String {
            return v1 == v2
        } else if let v1 = value1 as? NSNumber, let v2 = value2 as? NSNumber {
            return v1 == v2
        } else if let v1 = value1, let v2 = value2 {
            return String(describing: v1) == String(describing: v2)
        } else {
            return value1 == nil && value2 == nil
        }
    }
}

// MARK: - CloudKit Predicate Helpers
extension NSPredicate {
    /// Create a CloudKit-compatible predicate for isArchived field
    static func archivedStatus(isArchived: Bool) -> NSPredicate {
        return NSPredicate(format: "isArchived == %@", NSNumber(value: isArchived ? 1 : 0))
    }
}

// MARK: - CKContainer Extensions
extension CKContainer {
    /// Log information about the current CloudKit container
    static func logCurrentContainerInfo() {
        let container = CKContainer.default()
        let containerID = container.containerIdentifier ?? "Unknown container ID"
        
        print("📊 Current CloudKit Container: \(containerID)")
        
        container.accountStatus { status, error in
            let statusDesc: String
            switch status {
            case .available: statusDesc = "Available"
            case .couldNotDetermine: statusDesc = "Could not determine"
            case .noAccount: statusDesc = "No account"
            case .restricted: statusDesc = "Restricted"
            case .temporarilyUnavailable: statusDesc = "Temporarily unavailable"
            @unknown default: statusDesc = "Unknown status (\(status.rawValue))"
            }
            
            print("📊 iCloud Account Status: \(statusDesc)")
            
            if let error = error {
                print("⚠️ Account status error: \(error.localizedDescription)")
            }
        }
    }
} 