import CloudKit
import Foundation

/// A utility class to fix date display issues in NewsFeed
///
/// The issue is that posts are showing the current date instead of their creation date
/// because only datePosted is set but not datePublished.
class NewsFeedDateFixer {
    
    /// Database to use for saving records
    static let database = CKContainer(identifier: "iCloud.PearInc.EICT-iOS-16").publicCloudDatabase
    
    /// Fix creation date for a new post record
    /// Call this instead of setting datePosted directly
    static func fixNewPostDates(newsPost: CKRecord) {
        let creationDate = Date()
        newsPost["datePosted"] = creationDate
        newsPost["datePublished"] = creationDate
        print("📅 NewsFeedDateFixer: Set both date fields on new post")
    }
    
    /// Fix publish date for an existing post record
    /// Call this instead of setting datePosted directly
    static func fixPublishDates(record: CKRecord) {
        let publishDate = Date()
        record["datePosted"] = publishDate
        record["datePublished"] = publishDate
        print("📅 NewsFeedDateFixer: Set both date fields for publish")
    }
    
    /// Fix existing records that don't have datePublished set
    /// Call this after loading posts to update any records with missing fields
    static func fixExistingRecords(posts: [CKRecord]) {
        print("📅 NewsFeedDateFixer: Starting date field fix for \(posts.count) records")
        
        for record in posts {
            if record["datePublished"] == nil && record["datePosted"] != nil {
                if let postedDate = record["datePosted"] as? Date {
                    record["datePublished"] = postedDate
                    print("📅 NewsFeedDateFixer: Fixing \(record.recordID.recordName) - Adding datePublished")
                    
                    database.save(record) { savedRecord, error in
                        if let error = error {
                            print("📅 ❌ NewsFeedDateFixer: Error: \(error.localizedDescription)")
                        } else {
                            print("📅 ✅ NewsFeedDateFixer: Fixed \(record.recordID.recordName)")
                        }
                    }
                }
            }
        }
    }
    
    /// How to use this class:
    ///
    /// 1. In createNewPost, replace:
    ///    ```
    ///    newsPost["datePosted"] = Date()
    ///    ```
    ///    With:
    ///    ```
    ///    NewsFeedDateFixer.fixNewPostDates(newsPost: newsPost)
    ///    ```
    ///
    /// 2. In publishNow, replace:
    ///    ```
    ///    record["datePosted"] = Date()
    ///    ```
    ///    With:
    ///    ```
    ///    NewsFeedDateFixer.fixPublishDates(record: record)
    ///    ```
    ///
    /// 3. In loadPosts, add this line after loading posts:
    ///    ```
    ///    NewsFeedDateFixer.fixExistingRecords(posts: records)
    ///    ```
} 