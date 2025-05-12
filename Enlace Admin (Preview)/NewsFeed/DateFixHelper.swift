import Foundation
import CloudKit

/// Helper class to ensure consistent date handling for news feed posts
class DateFixHelper {
    
    /// Sets both datePosted and datePublished fields on a record
    /// - Parameters:
    ///   - record: The CKRecord to update
    ///   - date: The date to use (defaults to current date if nil)
    static func setPostDates(record: CKRecord, date: Date? = nil) {
        let timestamp = date ?? Date()
        record["datePosted"] = timestamp
        record["datePublished"] = timestamp
        print("📰 Date Fix: Set both date fields on record \(record.recordID.recordName) to \(timestamp)")
    }
    
    /// Fixes date fields on any record type, ensuring data consistency
    /// - Parameters:
    ///   - record: The record to fix
    ///   - saveRecord: Whether to save the record to CloudKit
    /// - Returns: True if changes were made
    static func fixDateFields(record: CKRecord, saveRecord: Bool = false) -> Bool {
        var modified = false
        
        // Check if we have any date field to work with
        if let datePosted = record["datePosted"] as? Date {
            // We have datePosted but missing datePublished
            if record["datePublished"] == nil {
                record["datePublished"] = datePosted
                print("📅 Date Fix: Added datePublished to match datePosted: \(datePosted)")
                modified = true
            }
        } else if let datePublished = record["datePublished"] as? Date {
            // We have datePublished but missing datePosted
            record["datePosted"] = datePublished
            print("📅 Date Fix: Added datePosted to match datePublished: \(datePublished)")
            modified = true
        } else if let dateUploaded = record["dateUploaded"] as? Date {
            // We have dateUploaded but missing the other fields
            record["datePosted"] = dateUploaded
            record["datePublished"] = dateUploaded
            print("📅 Date Fix: Added both date fields from dateUploaded: \(dateUploaded)")
            modified = true
        } else if let creationDate = record.creationDate {
            // Last resort - use creation date
            record["datePosted"] = creationDate
            record["datePublished"] = creationDate
            print("📅 Date Fix: Added both date fields from creationDate: \(creationDate)")
            modified = true
        }
        
        // Save if requested and if changes were made
        if saveRecord && modified {
            let database = CKContainer(identifier: "iCloud.PearInc.EICT-iOS-16").publicCloudDatabase
            database.save(record) { savedRecord, error in
                if let error = error {
                    print("📅 Date Fix Error: Failed to save record: \(error.localizedDescription)")
                } else {
                    print("📅 Date Fix Success: Saved record \(record.recordID.recordName)")
                }
            }
        }
        
        return modified
    }
} 