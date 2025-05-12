import Foundation
import CloudKit
import SwiftUI

/// Implementation guide for fixing the news feed date display issue
///
/// This issue occurs because posts are showing today's date instead of when they were posted.
/// The root cause is that only `datePosted` is being set while `datePublished` is missing.

class NewsDateFixer {
    // Reference to the database
    static let database = CKContainer(identifier: "iCloud.PearInc.EICT-iOS-16").publicCloudDatabase
    
    /// Run this function from a button press to fix all posts in the database
    static func fixAllPosts() async -> String {
        print("📅 ===== STARTING DATE FIX FOR ALL POSTS =====")
        var fixedCount = 0
        var errorCount = 0
        
        do {
            // Get all NewsFeedItem records
            let query = CKQuery(recordType: "NewsFeedItem", predicate: NSPredicate(value: true))
            let (results, _) = try await database.records(matching: query, inZoneWith: nil)
            
            print("📅 Found \(results.count) posts to check")
            
            for (_, result) in results {
                do {
                    let record = try result.get()
                    if let datePosted = record["datePosted"] as? Date, record["datePublished"] == nil {
                        // Missing datePublished field - set it to match datePosted
                        record["datePublished"] = datePosted
                        
                        print("📅 Fixing record: \(record.recordID.recordName)")
                        
                        // Save the updated record
                        try await database.save(record)
                        fixedCount += 1
                        print("📅 ✅ Fixed record \(record.recordID.recordName)")
                    }
                } catch {
                    errorCount += 1
                    print("📅 ❌ Error fixing record: \(error.localizedDescription)")
                }
            }
            
            print("📅 ===== COMPLETED DATE FIX =====")
            print("📅 Fixed \(fixedCount) records")
            print("📅 Encountered \(errorCount) errors")
            
            return "Fixed \(fixedCount) posts, with \(errorCount) errors"
        } catch {
            print("📅 ❌ Error retrieving records: \(error.localizedDescription)")
            return "Error: \(error.localizedDescription)"
        }
    }
    
    /// Call this in NewsFeedManagementView.loadPosts after loading records
    static func fixExistingRecords(records: [CKRecord]) async {
        print("📅 Checking \(records.count) records for date issues")
        
        var fixedCount = 0
        for record in records {
            if let datePosted = record["datePosted"] as? Date, record["datePublished"] == nil {
                record["datePublished"] = datePosted
                print("📅 Adding datePublished to record \(record.recordID.recordName)")
                
                do {
                    // Save the record with the new field
                    try await database.save(record)
                    fixedCount += 1
                    print("📅 ✅ Fixed record \(record.recordID.recordName)")
                } catch {
                    print("📅 ❌ Error saving record: \(error.localizedDescription)")
                }
            }
        }
        
        if fixedCount > 0 {
            print("📅 Fixed date fields on \(fixedCount) records")
        } else {
            print("📅 No records needed date fixing")
        }
    }
}

/// SwiftUI view to provide a fix button for administrators
struct NewsDateFixView: View {
    @State private var result: String = ""
    @State private var isFixing: Bool = false
    
    var body: some View {
        VStack {
            Text("News Feed Date Fix Tool")
                .font(.headline)
            
            Text("This tool fixes news items showing today's date instead of the actual post date")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding()
            
            if isFixing {
                ProgressView()
                    .padding()
            } else {
                Button("Fix All Posts") {
                    isFixing = true
                    Task {
                        let fixResult = await NewsDateFixer.fixAllPosts()
                        await MainActor.run {
                            result = fixResult
                            isFixing = false
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isFixing)
            }
            
            if !result.isEmpty {
                Text(result)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

/// IMPLEMENTATION GUIDE:
///
/// 1. In NewsFeedManagementView.swift:
///    a. Find line 513: `newsPost["datePosted"] = Date()`
///       Replace with: `NewsFeedDateFixer.fixNewPostDates(newsPost: newsPost)`
///
/// 2. In NewsFeedManagementView.swift:
///    a. Find publishNow function around line 1618: `record["datePosted"] = Date()`
///       Replace with: `NewsFeedDateFixer.fixPublishDates(record: record)`
///
/// 3. In NewsFeedManagementView.swift:
///    a. In the loadPosts function after loading records (around line 685):
///       Add: `await NewsDateFixer.fixExistingRecords(records: records)`
///
/// 4. In NewsFeedPopupView.swift:
///    a. Find line 435: `newsPost["datePosted"] = Date()`
///       Replace with: `DateFixHelper.setPostDates(record: newsPost)`
///
/// 5. Add a "Fix Dates" button to admin tools that calls `NewsDateFixer.fixAllPosts()` 