import SwiftUI
import CloudKit

struct FixNewsDateView: View {
    @State private var isFixing = false
    @State private var result = ""
    @State private var fixedCount = 0
    @State private var totalPosts = 0
    @State private var errorCount = 0
    @State private var fixPDFs = true // New toggle to fix PDF records
    @State private var refreshID = UUID()
    @State private var logMessages: [String] = []
    
    var body: some View {
        VStack(spacing: 20) {
            Text("News Feed Date Fix Tool")
                .font(.largeTitle)
                .bold()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("This tool fixes the date display issue in news feed posts.")
                    .font(.title3)
                Text("Problem: News posts are showing today's date instead of when they were posted.")
                Text("Cause: Missing date fields in both NewsFeedItem and PDFDocumentItem records.")
                Text("Solution: This tool adds the missing date fields to all records.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            HStack {
                VStack(alignment: .leading) {
                    Label("Total posts: \(totalPosts)", systemImage: "doc.text")
                    Label("Posts fixed: \(fixedCount)", systemImage: "checkmark.circle")
                    Label("Errors: \(errorCount)", systemImage: "exclamationmark.triangle")
                }
                
                Spacer()
                
                Button {
                    refreshStats()
                } label: {
                    Label("Refresh Stats", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
            Toggle("Also fix PDF documents used as news feed items", isOn: $fixPDFs)
                .padding(.vertical, 4)
            
            if isFixing {
                ProgressView("Fixing dates...")
                    .padding()
            } else {
                Button {
                    fixAllPosts()
                } label: {
                    Label("Fix All Posts", systemImage: "wrench.and.screwdriver")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isFixing)
            }
            
            if !result.isEmpty {
                Text(result)
                    .foregroundColor(result.contains("Error") ? .red : .green)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            }
            
            Text("Log Messages")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(logMessages, id: \.self) { message in
                        Text(message)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 2)
                    }
                }
            }
            .frame(height: 200)
            .padding()
            .background(Color.black.opacity(0.05))
            .cornerRadius(8)
            
            Text("How to permanently fix the issue:")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("1. In NewsFeedManagementView.swift:")
                Text("   • Find: newsPost[\"datePosted\"] = Date()")
                Text("   • Change to: NewsFeedDateFixer.fixNewPostDates(newsPost: newsPost)")
                
                Text("2. In publishNow function:")
                Text("   • Find: record[\"datePosted\"] = Date()")
                Text("   • Change to: NewsFeedDateFixer.fixPublishDates(record: record)")
                
                Text("3. In NewsFeedPopupView.swift:")
                Text("   • Find: newsPost[\"datePosted\"] = Date()")
                Text("   • Change to: DateFixHelper.setPostDates(record: newsPost)")
                
                Text("4. In NewsFeedManagementView.swift:")
                Text("   • Find where PDFs are converted to news items in loadPostsWithFallback")
                Text("   • Add code to copy dateUploaded to both datePosted and datePublished")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
        .frame(minWidth: 700, minHeight: 700)
        .onAppear {
            refreshStats()
        }
    }
    
    private func addLog(_ message: String) {
        logMessages.append("\(dateFormatter.string(from: Date())) - \(message)")
    }
    
    private func refreshStats() {
        Task {
            await getPostStats()
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }
    
    private func getPostStats() async {
        addLog("Fetching post statistics...")
        
        do {
            let database = CKContainer(identifier: "iCloud.PearInc.EICT-iOS-16").publicCloudDatabase
            
            // Count all posts (NewsFeedItem records)
            let postsQuery = CKQuery(recordType: "NewsFeedItem", predicate: NSPredicate(value: true))
            postsQuery.sortDescriptors = [
                NSSortDescriptor(key: "scheduledDate", ascending: false),
                NSSortDescriptor(key: "recordNameMirror", ascending: true) // Secondary sort prevents recordName fallback
            ]
            let (postsResults, _) = try await database.records(matching: postsQuery, inZoneWith: nil)
            
            // Process NewsFeedItem records
            let newsItemCount = postsResults.count
            var newsItemMissingCount = 0
            
            // Process NewsFeedItem records
            for (_, result) in postsResults {
                do {
                    let record = try result.get()
                    if record["datePosted"] != nil && record["datePublished"] == nil {
                        newsItemMissingCount += 1
                    }
                } catch {
                    // Skip failed records
                }
            }
            
            // Count PDFs used as news items
            let pdfsQuery = CKQuery(recordType: "PDFDocumentItem", predicate: NSPredicate(value: true))
            let (pdfResults, _) = try await database.records(matching: pdfsQuery, inZoneWith: nil)
            
            let pdfCount = pdfResults.count
            var pdfMissingCount = 0
            
            // Process PDF records
            for (_, result) in pdfResults {
                do {
                    let record = try result.get()
                    if (record["datePosted"] == nil || record["datePublished"] == nil) && record["dateUploaded"] != nil {
                        pdfMissingCount += 1
                    }
                } catch {
                    // Skip failed records
                }
            }
            
            totalPosts = newsItemCount + pdfCount
            let totalMissing = newsItemMissingCount + pdfMissingCount
            fixedCount = totalPosts - totalMissing
            
            addLog("Found \(newsItemCount) news items (\(newsItemMissingCount) need fixing)")
            addLog("Found \(pdfCount) PDF documents (\(pdfMissingCount) need fixing)")
            addLog("Total: \(totalPosts) items, \(fixedCount) already fixed, \(totalMissing) need fixing")
            
        } catch {
            errorCount += 1
            addLog("Error fetching stats: \(error.localizedDescription)")
        }
    }
    
    private func fixAllPosts() {
        guard !isFixing else { return }
        
        isFixing = true
        result = "Starting fix process..."
        addLog("Starting fix process for all posts...")
        
        Task {
            do {
                let database = CKContainer(identifier: "iCloud.PearInc.EICT-iOS-16").publicCloudDatabase
                var fixed = 0
                var errors = 0
                
                // 1. Fix NewsFeedItem records first
                addLog("Fixing NewsFeedItem records...")
                let query = CKQuery(recordType: "NewsFeedItem", predicate: NSPredicate(value: true))
                query.sortDescriptors = [
                    NSSortDescriptor(key: "scheduledDate", ascending: false),
                    NSSortDescriptor(key: "recordNameMirror", ascending: true) // Secondary sort prevents recordName fallback
                ]
                let (results, _) = try await database.records(matching: query, inZoneWith: nil)
                
                addLog("Found \(results.count) NewsFeedItem records to process")
                
                for (_, result) in results {
                    do {
                        let record = try result.get()
                        if let datePosted = record["datePosted"] as? Date, record["datePublished"] == nil {
                            // Missing datePublished field - set it
                            record["datePublished"] = datePosted
                            addLog("Fixing NewsFeedItem: \(record.recordID.recordName)")
                            
                            // Save the updated record
                            try await database.save(record)
                            fixed += 1
                            addLog("✅ Fixed NewsFeedItem \(record.recordID.recordName)")
                        }
                    } catch {
                        errors += 1
                        addLog("❌ Error fixing NewsFeedItem: \(error.localizedDescription)")
                    }
                }
                
                // 2. Fix PDFDocumentItem records if enabled
                if fixPDFs {
                    addLog("Fixing PDFDocumentItem records...")
                    let pdfQuery = CKQuery(recordType: "PDFDocumentItem", predicate: NSPredicate(value: true))
                    let (pdfResults, _) = try await database.records(matching: pdfQuery, inZoneWith: nil)
                    
                    addLog("Found \(pdfResults.count) PDFDocumentItem records to process")
                    
                    for (_, result) in pdfResults {
                        do {
                            let record = try result.get()
                            if let dateUploaded = record["dateUploaded"] as? Date {
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
                                    addLog("Fixing PDFDocumentItem: \(record.recordID.recordName)")
                                    try await database.save(record)
                                    fixed += 1
                                    addLog("✅ Fixed PDFDocumentItem \(record.recordID.recordName)")
                                }
                            }
                        } catch {
                            errors += 1
                            addLog("❌ Error fixing PDFDocumentItem: \(error.localizedDescription)")
                        }
                    }
                }
                
                await MainActor.run {
                    isFixing = false
                    result = "Fixed \(fixed) records with \(errors) errors"
                    addLog("Completed with \(fixed) fixes and \(errors) errors")
                    
                    // Refresh stats
                    refreshStats()
                }
                
            } catch {
                await MainActor.run {
                    isFixing = false
                    result = "Error: \(error.localizedDescription)"
                    errorCount += 1
                    addLog("❌ Error during fix process: \(error.localizedDescription)")
                }
            }
        }
    }
}

#Preview {
    FixNewsDateView()
} 