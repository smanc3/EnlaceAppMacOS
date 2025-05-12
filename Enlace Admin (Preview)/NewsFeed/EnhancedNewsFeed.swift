import SwiftUI
import CloudKit

/// Enhanced extensions for NewsFeedPost to better handle PDFs as news feed items
extension NewsFeedPost {
    
    /// Factory method to create a NewsFeedPost from any record type with proper date handling
    static func createFromAnyRecord(_ record: CKRecord) -> NewsFeedPost {
        // Handle PDFDocumentItem records specifically 
        if record.recordType == "PDFDocumentItem" {
            // Create a temporary record with proper date fields
            let tempRecord = record.copy() as! CKRecord
            
            // If datePosted and datePublished are missing but dateUploaded exists,
            // copy the dateUploaded value to both fields
            if (tempRecord["datePosted"] == nil || tempRecord["datePublished"] == nil) && 
               tempRecord["dateUploaded"] != nil {
                if let dateUploaded = tempRecord["dateUploaded"] as? Date {
                    tempRecord["datePosted"] = dateUploaded
                    tempRecord["datePublished"] = dateUploaded
                    print("📅 Enhanced: Set temporary date fields for \(record.recordID.recordName)")
                }
            }
            
            return NewsFeedPost(record: tempRecord)
        } else {
            // Normal NewsFeedItem records handled by standard initializer
            return NewsFeedPost(record: record)
        }
    }
    
    /// Apply to a list of records to create properly dated posts
    static func createFromRecords(_ records: [CKRecord]) -> [NewsFeedPost] {
        print("📅 Enhanced: Creating \(records.count) posts with proper date handling")
        
        return records.map { record in
            // Ensure date fields are populated
            ensureDateFieldsExist(record)
            
            // Check archive status for debugging
            if let isArchived = record["isArchived"] as? Int {
                print("📅 Enhanced: Record \(record.recordID.recordName) isArchived=\(isArchived)")
            } else {
                print("📅 Enhanced: Record \(record.recordID.recordName) has no isArchived field")
            }
            
            // Create the post
            return NewsFeedPost(record: record)
        }
    }
    
    private static func ensureDateFieldsExist(_ record: CKRecord) {
        print("📅 Enhanced: Set temporary date fields for \(record.recordID.recordName)")
        
        // If PDFDocumentItem has no datePosted, use dateUploaded
        if record.recordType == "PDFDocumentItem" {
            // If datePosted is missing but dateUploaded exists, use that
            if record["datePosted"] == nil, let dateUploaded = record["dateUploaded"] as? Date {
                record["datePosted"] = dateUploaded
                print("📅 Enhanced: Added datePosted using dateUploaded")
            }
        }
    }
}

/// Instructions for implementing the enhanced post creation:
///
/// 1. In loadPostsWithFallback, change:
///    ```
///    var newsFeedPosts = fallbackRecords.map { NewsFeedPost(record: $0) }
///    ```
///    to:
///    ```
///    var newsFeedPosts = NewsFeedPost.createFromRecords(fallbackRecords)
///    ```
///
/// 2. The same change should be made in other places that convert PDFs to posts
///
/// This approach ensures correct dates are displayed even without permanently 
/// modifying the CloudKit records. It's a fallback if the Fix All Posts tool
/// hasn't been run yet. 