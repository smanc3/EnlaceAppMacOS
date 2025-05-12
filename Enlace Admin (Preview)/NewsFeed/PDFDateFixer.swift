import Foundation
import CloudKit

/// Helper class to fix date issues with PDF documents used as news feed items
class PDFDateFixer {
    
    /// Apply correct date fields to PDF documents used as news feed items
    /// Call this before creating NewsFeedPost objects from PDF records
    static func fixPDFDates(database: CKDatabase, records: [CKRecord]) async {
        print("📅 PDFDateFixer: Starting to fix \(records.count) PDF documents")
        
        var fixedCount = 0
        
        for record in records {
            // Only process PDFDocumentItem records
            guard record.recordType == "PDFDocumentItem" else { continue }
            
            // Check if datePosted or datePublished is missing but dateUploaded exists
            if (record["datePosted"] == nil || record["datePublished"] == nil) && record["dateUploaded"] != nil {
                if let dateUploaded = record["dateUploaded"] as? Date {
                    print("📅 PDFDateFixer: Adding missing date fields to \(record.recordID.recordName)")
                    
                    var wasUpdated = false
                    
                    // Add missing datePosted field
                    if record["datePosted"] == nil {
                        record["datePosted"] = dateUploaded
                        wasUpdated = true
                    }
                    
                    // Add missing datePublished field
                    if record["datePublished"] == nil {
                        record["datePublished"] = dateUploaded
                        wasUpdated = true
                    }
                    
                    // Add isArchived=0 if missing (for queryability)
                    if record["isArchived"] == nil {
                        record["isArchived"] = 0
                        wasUpdated = true
                    }
                    
                    if wasUpdated {
                        do {
                            try await database.save(record)
                            fixedCount += 1
                            print("📅 PDFDateFixer: ✅ Fixed PDF document: \(record.recordID.recordName)")
                        } catch {
                            print("📅 PDFDateFixer: ❌ Error saving PDF document: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
        
        print("📅 PDFDateFixer: Fixed \(fixedCount) of \(records.count) PDF documents")
    }
    
    /// Creates a fixed NewsFeedPost from a PDFDocumentItem record
    /// This ensures correct date display even if the record hasn't been fixed in CloudKit yet
    static func createPostFromPDF(record: CKRecord) -> NewsFeedPost {
        // Create a temporary copy of the record
        let tempRecord = record.copy() as! CKRecord
        
        // Apply date fields locally for this instance only
        if (tempRecord["datePosted"] == nil || tempRecord["datePublished"] == nil) && tempRecord["dateUploaded"] != nil {
            if let dateUploaded = tempRecord["dateUploaded"] as? Date {
                tempRecord["datePosted"] = dateUploaded
                tempRecord["datePublished"] = dateUploaded
                
                print("📅 PDFDateFixer: Set local date fields for display: \(record.recordID.recordName)")
            }
        }
        
        // Create post from the corrected record
        return NewsFeedPost(record: tempRecord)
    }
    
    /// Use this in loadPostsWithFallback after retrieving PDF records
    /// It will both fix the records in CloudKit and provide corrected records for display
    static func processAndFixPDFRecords(database: CKDatabase, records: [CKRecord]) async -> [CKRecord] {
        // First fix the records in CloudKit
        await fixPDFDates(database: database, records: records)
        
        // Return the original records - they now have the dates fixed
        return records
    }
} 