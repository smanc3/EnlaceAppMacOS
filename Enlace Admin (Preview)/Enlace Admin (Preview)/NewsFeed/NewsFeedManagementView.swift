//
//  NewsFeedManagementView.swift
//  Enlace Admin (Preview)
//
//  Created on 5/10/25.
//

import SwiftUI
import CloudKit
import PDFKit

// MARK: - News Feed Post Model
struct NewsFeedPost: Identifiable {
    let id: CKRecord.ID
    let title: String
    let datePosted: Date
    let scheduledDate: Date?
    let pdfReference: CKRecord.Reference?
    let record: CKRecord
    let recordNameMirror: String
    let linkURL: URL?  // New property for clickable links
    
    // Add PDF document details
    var pdfDocument: PDFDocumentDetails?
    
    init(record: CKRecord) {
        self.id = record.recordID
        self.record = record
        self.title = record["title"] as? String ?? "Untitled"
        
        // Check for both datePosted and datePublished fields
        if let datePosted = record["datePosted"] as? Date {
            self.datePosted = datePosted
        } else if let datePublished = record["datePublished"] as? Date {
            self.datePosted = datePublished
        } else {
            self.datePosted = Date()
        }
        
        self.scheduledDate = record["scheduledDate"] as? Date
        self.pdfReference = record["pdfReference"] as? CKRecord.Reference
        self.recordNameMirror = record["recordNameMirror"] as? String ?? record.recordID.recordName
        
        // Initialize link URL if present
        if let linkString = record["linkURL"] as? String, !linkString.isEmpty {
            self.linkURL = URL(string: linkString)
        } else {
            self.linkURL = nil
        }
        
        self.pdfDocument = nil // Will be populated later if reference exists
    }
    
    var isScheduled: Bool {
        guard let scheduled = scheduledDate else { return false }
        return scheduled > Date()
    }
}

// MARK: - Archived News Post Model
struct ArchivedNewsPost: Identifiable {
    let id: CKRecord.ID
    let title: String
    let datePosted: Date
    let archivedDate: Date
    let pdfReference: CKRecord.Reference?
    let record: CKRecord
    let recordNameMirror: String
    let linkURL: URL?  // New property for clickable links
    
    // Add PDF document details
    var pdfDocument: PDFDocumentDetails?
    
    init(record: CKRecord) {
        self.id = record.recordID
        self.record = record
        self.title = record["title"] as? String ?? "Untitled"
        self.datePosted = record["datePosted"] as? Date ?? Date()
        self.archivedDate = record["archivedDate"] as? Date ?? Date()
        self.pdfReference = record["pdfReference"] as? CKRecord.Reference
        self.recordNameMirror = record["recordNameMirror"] as? String ?? record.recordID.recordName
        
        // Initialize link URL if present
        if let linkString = record["linkURL"] as? String, !linkString.isEmpty {
            self.linkURL = URL(string: linkString)
        } else {
            self.linkURL = nil
        }
        
        self.pdfDocument = nil // Will be populated later if reference exists
    }
}

// MARK: - PDF Document Details model
struct PDFDocumentDetails: Identifiable { // Conform to Identifiable
    let id: CKRecord.ID
    let title: String
    let dateUploaded: Date
    let fileURL: URL?
    let record: CKRecord
    var thumbnail: NSImage?
    
    init(record: CKRecord) {
        self.id = record.recordID
        self.record = record
        self.title = record["title"] as? String ?? "Untitled Document"
        self.dateUploaded = record["dateUploaded"] as? Date ?? Date()
        
        // Extract file URL from CKAsset
        if let asset = record["pdfFile"] as? CKAsset, let fileURL = asset.fileURL {
            self.fileURL = fileURL
            // Generate thumbnail
            self.thumbnail = Self.generateThumbnail(from: fileURL)
        } else {
            self.fileURL = nil
            self.thumbnail = nil
        }
    }
    
    // Function to safely get PDFDocument from the asset
    func getPDFDocument() -> PDFKit.PDFDocument? {
        guard let fileURL = self.fileURL else {
            print("📄 PDF Loading: No file URL available")
            return nil
        }
        
        print("📄 PDF Loading: Attempting to load PDF from URL: \(fileURL)")
        
        // Try to load directly from URL first
        if let pdfDoc = PDFKit.PDFDocument(url: fileURL) {
            print("📄 PDF Loading: Successfully loaded PDF directly from URL")
            print("📄 PDF Loading: Page count: \(pdfDoc.pageCount)")
            return pdfDoc
        }
        
        print("📄 PDF Loading: Failed to load PDF directly from URL, trying with data")
        
        // Try loading via data as a fallback
        do {
            let data = try Data(contentsOf: fileURL)
            print("📄 PDF Loading: Read \(data.count) bytes from file")
            
            if let pdfDoc = PDFKit.PDFDocument(data: data) {
                print("📄 PDF Loading: Successfully created PDFDocument from data")
                print("📄 PDF Loading: Page count: \(pdfDoc.pageCount)")
                return pdfDoc
            } else {
                print("📄 PDF Loading: Failed to create PDFDocument from data")
                return nil
            }
        } catch {
            print("📄 PDF Loading: Error reading file data: \(error)")
            return nil
        }
    }
    
    // Helper function to generate thumbnail from PDF
    static func generateThumbnail(from fileURL: URL) -> NSImage? {
        // Validate PDF document
        guard let pdfDocument = PDFKit.PDFDocument(url: fileURL),
              let pdfPage = pdfDocument.page(at: 0) else {
            print("Failed to load PDF document or first page")
            return nil
        }
        
        // Define thumbnail size
        let thumbnailSize = NSSize(width: 200, height: 200)
        
        // Create new image with white background
        let image = NSImage(size: thumbnailSize)
        image.lockFocus()
        
        // Save current graphics context
        let currentContext = NSGraphicsContext.current
        
        // Set up drawing environment
        NSColor.white.set()
        NSRect(origin: .zero, size: thumbnailSize).fill()
        
        // Get PDF page bounds
        let pdfRect = pdfPage.bounds(for: .mediaBox)
        
        // Calculate scale to fit PDF in thumbnail
        let scale = min(
            thumbnailSize.width / pdfRect.width,
            thumbnailSize.height / pdfRect.height
        )
        
        // Create and apply transform
        let transform = NSAffineTransform()
        
        // Center the PDF in the thumbnail
        let xOffset = (thumbnailSize.width - (pdfRect.width * scale)) / 2
        let yOffset = (thumbnailSize.height - (pdfRect.height * scale)) / 2
        
        // Apply transforms in correct order
        transform.translateX(by: xOffset, yBy: yOffset)
        transform.scale(by: scale)
        transform.concat()
        
        // Draw PDF page
        if let context = NSGraphicsContext.current {
            pdfPage.draw(with: .mediaBox, to: context.cgContext)
        }
        
        // Restore graphics context and unlock focus
        image.unlockFocus()
        NSGraphicsContext.current = currentContext
        
        return image
    }
}

// MARK: - News Feed Management View
struct NewsFeedManagementView: View {
    @Binding var isSpanish: Bool
    
    // State variables
    @State private var posts: [NewsFeedPost] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    @State private var selectedPost: NewsFeedPost? = nil
    @State private var showDeleteConfirmation: Bool = false
    @State private var searchText: String = ""
    @State private var showScheduledOnly: Bool = false
    @State private var sortOrder = SortOption.datePosted
    @State private var showArchiveConfirmation = false
    @State private var showFullPDFView: Bool = false
    @State private var currentPDFDocument: PDFKit.PDFDocument? = nil
    @State private var pdfDetailsToShow: PDFDocumentDetails? = nil // New state for .sheet(item:)
    
    // Additional state
    @State private var showingDeleteAlert = false
    @State private var showingArchiveAlert = false
    @State private var showingPDFViewer = false
    @State private var sortOption: SortOption = .datePosted
    @State private var showingSortOptions = false
    @State private var refreshTrigger = false
    
    enum SortOption: String, CaseIterable, Identifiable {
        case datePosted = "Date Posted"
        case title = "Title"
        case scheduledDate = "Scheduled Date"
        
        var id: String { self.rawValue }
        
        var localizedName: String {
            switch self {
            case .datePosted: return NSLocalizedString("Date Posted", comment: "")
            case .title: return NSLocalizedString("Title", comment: "")
            case .scheduledDate: return NSLocalizedString("Scheduled Date", comment: "")
            }
        }
    }
    
    // Archived posts storage
    @State private var archivedPosts: [ArchivedNewsPost] = []
    
    // Editing state
    @State private var isEditing: Bool = false
    @State private var editTitle: String = ""
    @State private var isScheduled: Bool = false
    @State private var scheduledDate: Date = Date().addingTimeInterval(3600)
    @State private var editLinkURL: String = ""  // New state variable for link URL
    @State private var selectedPDFRecord: CKRecord?
    @State private var selectedPDFURL: URL?
    @State private var selectedFileLabel: String = ""
    @State private var showPDFPicker: Bool = false
    
    // CloudKit
    private let container = CKContainer(identifier: "iCloud.PearInc.EICT-iOS-16")
    private var database: CKDatabase {
        return container.publicCloudDatabase
    }
    
    // Filtered posts based on search and filter settings
    private var filteredPosts: [NewsFeedPost] {
        // Start with all posts
        var result = posts
        
        // Apply search filter if needed
        result = filterBySearch(result)
        
        // Apply scheduled filter if needed
        result = filterByScheduled(result)
        
        // Apply sorting
        return sortPosts(result)
    }
    
    private func filterBySearch(_ posts: [NewsFeedPost]) -> [NewsFeedPost] {
        guard !searchText.isEmpty else { return posts }
        return posts.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    private func filterByScheduled(_ posts: [NewsFeedPost]) -> [NewsFeedPost] {
        guard showingSortOptions else { return posts }
        return posts.filter { $0.isScheduled }
    }
    
    private func sortPosts(_ posts: [NewsFeedPost]) -> [NewsFeedPost] {
        switch sortOption {
        case .datePosted:
            return posts.sorted(by: { $0.datePosted > $1.datePosted })
        case .title:
            return posts.sorted(by: { $0.title < $1.title })
        case .scheduledDate:
            return posts.sorted(by: { $0.scheduledDate ?? Date() > $1.scheduledDate ?? Date() })
        }
    }
    
    @EnvironmentObject var languageManager: LanguageManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isSpanish ? "Gestión de Noticias" : "News Management")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Refresh button
                Button(action: {
                    loadPosts()
                }) {
                    Label(isSpanish ? "Actualizar" : "Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            // Tab selector removed
            
            // Only show active posts view
            activePostsView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            loadPosts()
        }
        .onChange(of: refreshTrigger) { oldValue, newValue in
            loadPosts()
        }
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text(isSpanish ? "Confirmar eliminación" : "Confirm Deletion"),
                message: Text(isSpanish ? "¿Estás seguro de que deseas eliminar esta publicación? Esta acción no se puede deshacer." : "Are you sure you want to delete this post? This action cannot be undone."),
                primaryButton: .destructive(Text(isSpanish ? "Eliminar" : "Delete")) {
                    if let post = selectedPost {
                        deletePost(post)
                        selectedPost = nil
                        isEditing = false
                    }
                },
                secondaryButton: .cancel(Text(isSpanish ? "Cancelar" : "Cancel"))
            )
        }
        .alert(isPresented: $showingArchiveAlert) {
            Alert(
                title: Text(isSpanish ? "Archivar esta publicación?" : "Archive this post?"),
                message: Text(isSpanish ? "La publicación se moverá al archivo y ya no estará disponible en la lista principal." : "The post will be moved to the archive and will no longer be available in the main list."),
                primaryButton: .destructive(Text(isSpanish ? "Archivar" : "Archive")) {
                    if let post = selectedPost {
                        archivePost(post: post)
                        selectedPost = nil
                        isEditing = false
                    }
                },
                secondaryButton: .cancel(Text(isSpanish ? "Cancelar" : "Cancel"))
            )
        }
        .sheet(item: $pdfDetailsToShow) { details in
            // Attempt to load the document directly from the details passed to the sheet
            if let pdf = details.getPDFDocument() {
                VStack(spacing: 0) {
                    // Header with close button
                    HStack {
                        Text("PDF Viewer")
                            .font(.headline)
                            .fontWeight(.bold)
                            .padding(.leading)
                        
                        Spacer()
                        
                        Button(action: {
                            print("📄 PDF Viewer: Close button pressed")
                            pdfDetailsToShow = nil // Dismiss by setting item to nil
                        }) {
                            Text("Close")
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 20)
                        .keyboardShortcut(.escape, modifiers: [])
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    .background(Color(NSColor.windowBackgroundColor))
                    
                    // Controller-based PDF viewer
                    PDFViewerController(document: pdf, onDismiss: {
                        print("📄 PDF Viewer: PDFViewerController requested dismiss")
                        pdfDetailsToShow = nil // Dismiss by setting item to nil
                    })
                    .frame(minWidth: 1000, idealWidth: 1200, maxWidth: .infinity, 
                           minHeight: 800, idealHeight: 900, maxHeight: .infinity)
                }
                .frame(minWidth: 1000, minHeight: 800) // Increase minimum size of the sheet
                .onAppear {
                    print("📄 PDF Viewer: Sheet view appeared for document '\(details.title)' page count: \(pdf.pageCount)")
                    if pdf.pageCount > 0, let firstPage = pdf.page(at: 0) {
                        let bounds = firstPage.bounds(for: .mediaBox)
                        print("📄 PDF Viewer: First page dimensions: \(bounds.width) x \(bounds.height)")
                    } else {
                        print("⚠️ PDF Viewer: Document has no pages!")
                    }
                }
            } else {
                // Error case if getPDFDocument fails within the sheet
                VStack {
                    Text("Error: Could not load PDF document for '\(details.title)'")
                        .foregroundColor(.red)
                        .padding()
                    
                    Button("Close") {
                        pdfDetailsToShow = nil
                    }
                    .buttonStyle(.bordered)
                }
                .frame(width: 400, height: 200)
            }
        }
        .onAppear {
            // Add notification observer for when items are unarchived
            NotificationCenter.default.addObserver(
                forName: Notification.Name("NewsFeedRefreshNotification"),
                object: nil,
                queue: .main
            ) { _ in
                print("📰 NewsFeed: Received notification of unarchived post, refreshing...")
                loadPosts()
                loadArchivedPosts()
            }
        }
        .onDisappear {
            // Remove the observer when the view disappears
            NotificationCenter.default.removeObserver(
                self,
                name: Notification.Name("NewsFeedRefreshNotification"),
                object: nil
            )
        }
    }
    
    // MARK: - Methods
    
    private func loadPDFRecord(_ reference: CKRecord.Reference) {
        // Fetch the PDF record from CloudKit
        database.fetch(withRecordID: reference.recordID) { record, error in
            if let record = record, error == nil {
                DispatchQueue.main.async {
                    self.selectedPDFRecord = record
                    self.selectedFileLabel = record["title"] as? String ?? "Selected PDF"
                }
            }
        }
    }
    
    private func saveChanges() {
        if let post = selectedPost {
            // Update existing post
            let updatedPost = EditNewsPostInfo(
                title: editTitle,
                scheduledDate: isScheduled ? scheduledDate : nil,
                pdfRecord: selectedPDFRecord,
                pdfURL: selectedPDFURL,
                linkURL: editLinkURL.isEmpty ? nil : editLinkURL
            )
            updatePost(originalPost: post, updatedPost: updatedPost)
        } else {
            // Create new post
            createNewPost(
                title: editTitle,
                scheduledDate: isScheduled ? scheduledDate : nil,
                pdfRecord: selectedPDFRecord,
                pdfURL: selectedPDFURL,
                linkURL: editLinkURL.isEmpty ? nil : editLinkURL
            )
        }
        
        // Reset edit mode
        isEditing = false
    }
    
    private func createNewPost(title: String, scheduledDate: Date?, pdfRecord: CKRecord?, pdfURL: URL?, linkURL: String?) {
        let newRecord = CKRecord(recordType: "NewsFeedItem")
        newRecord["title"] = title
        
        if let scheduledDate = scheduledDate {
            newRecord["scheduledDate"] = scheduledDate
        } else {
            newRecord["datePosted"] = Date()
        }
        
        // Set recordNameMirror for queryability
        newRecord["recordNameMirror"] = newRecord.recordID.recordName
        
        // Add link URL if provided
        if let linkURL = linkURL, !linkURL.isEmpty {
            newRecord["linkURL"] = linkURL
        }
        
        // Add PDF reference if available
        if let pdfRecord = pdfRecord {
            newRecord["pdfReference"] = CKRecord.Reference(record: pdfRecord, action: .deleteSelf)
        }
        
        // Save the new record
        database.save(newRecord) { _, error in
            if let error = error {
                print("Error creating new post: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.errorMessage = "Error creating post: \(error.localizedDescription)"
                }
            } else {
                DispatchQueue.main.async {
                    // Reload posts to show the new one
                    self.loadPosts()
                }
            }
        }
    }
    
    private func loadPosts() {
        print("\n📰 ===== NEWS FEED DEBUG LOG ===== 📰")
        print("📰 [\(Date())] Starting to load posts")
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // ---> MODIFIED: Force use of PDF-based fallback method only
                print("📰 [\(Date())] Forcing PDF-based fallback approach to load news feed")
                
                let fetchedRecords = try await fetchNewsFeedWithFallback(database: database)
                print("📰 ✅ [\(Date())] PDF-based method found \(fetchedRecords.count) records")
                // <--- END MODIFIED
                
                // Process records and update recordNameMirror if needed
                var recordsWithMissingMirror: [CKRecord] = []
                for record in fetchedRecords {
                    if record["recordNameMirror"] == nil {
                        record["recordNameMirror"] = record.recordID.recordName
                        recordsWithMissingMirror.append(record)
                        print("📰 ⚠️ [\(Date())] Record missing recordNameMirror: \(record.recordID.recordName)")
                    }
                }
                
                // Save updated records
                for record in recordsWithMissingMirror {
                    Task {
                        do {
                            let _ = try await database.save(record)
                            print("📰 ✅ [\(Date())] Updated record with missing recordNameMirror: \(record.recordID.recordName)")
                        } catch {
                            print("📰 ❌ [\(Date())] Failed to update recordNameMirror for \(record.recordID.recordName): \(error.localizedDescription)")
                        }
                    }
                }
                
                // Create posts and fetch PDFs
                var posts = fetchedRecords.map { NewsFeedPost(record: $0) }
                print("📰 ✅ [\(Date())] Created \(posts.count) NewsFeedPost objects")
                
                // Fetch PDFs for posts that have references
                for i in 0..<posts.count {
                    if let pdfRef = posts[i].pdfReference {
                        do {
                            print("📰 [\(Date())] Fetching PDF for post: \(posts[i].title)")
                            let pdfRecord = try await database.record(for: pdfRef.recordID)
                            let pdfDetails = PDFDocumentDetails(record: pdfRecord)
                            posts[i].pdfDocument = pdfDetails
                            print("📰 ✅ [\(Date())] Successfully loaded PDF for post: \(posts[i].title)")
                        } catch {
                            print("📰 ❌ [\(Date())] Error fetching PDF for post \(posts[i].title): \(error.localizedDescription)")
                        }
                    }
                }
                
                // Update UI
                await MainActor.run {
                    self.posts = posts
                    self.isLoading = false
                    print("📰 ✅ [\(Date())] UI updated with \(posts.count) posts")
                    print("📰 ===== NEWS FEED LOAD COMPLETE ===== 📰\n")
                }
                
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Error loading news: \(error.localizedDescription)"
                    print("📰 ❌ [\(Date())] Error loading posts: \(error.localizedDescription)")
                    print("📰 ===== NEWS FEED LOAD FAILED ===== 📰\n")
                }
            }
        }
    }
    
    // Fallback method for fetching news feed items
    private func fetchNewsFeedWithFallback(database: CKDatabase) async throws -> [CKRecord] {
        print("📰 [\(Date())] Starting fallback method to fetch posts")
        
        // Create a configuration for the operation
        let configuration = CKOperation.Configuration()
        configuration.timeoutIntervalForRequest = 30
        
        // Try to recover from PDFs directly
        print("📰 [\(Date())] Attempting to recover news feed items from PDF records")
        
        let pdfQuery = CKQuery(recordType: "PDFDocumentItem", predicate: NSPredicate(value: true))
        
        do {
            let (pdfMatchResults, _) = try await database.records(matching: pdfQuery)
            
            let pdfRecords = pdfMatchResults.compactMap { _, recordResult -> CKRecord? in
                try? recordResult.get()
            }
            
            if !pdfRecords.isEmpty {
                print("📰 ✅ [\(Date())] Found \(pdfRecords.count) PDF records! Creating news feed items from them.")
                
                // Create synthetic news feed records from the PDFs
                var syntheticNewsRecords: [CKRecord] = []
                
                // First pass - find and fix incorrectly archived PDFs
                for pdf in pdfRecords {
                    if let isArchived = pdf["isArchived"] as? Bool, isArchived {
                        // Check if this is the Annual Report Review or another problematic PDF
                        let recordID = pdf.recordID.recordName
                        let title = pdf["title"] as? String ?? "Unknown"
                        
                        print("📰 🔍 [\(Date())] Found PDF marked as archived: \(recordID), title: \(title)")
                        
                        // Force fix for Annual Report Review or any PDF with no archived posts referencing it
                        if title.contains("Annual Report Review") || recordID == "61579A12-F376-47D2-85A1-9622D5CCBBA2" {
                            print("📰 🛠️ [\(Date())] EMERGENCY FIX: Forcefully clearing isArchived flag for \(title)")
                            pdf["isArchived"] = nil
                            
                            // Save synchronously to ensure it takes effect immediately
                            do {
                                let savedRecord = try await database.save(pdf)
                                print("📰 ✅ [\(Date())] Successfully cleared isArchived flag for \(title)")
                                
                                // Create a synthetic record for this now-unarchived PDF
                                let syntheticRecord = createSyntheticRecord(from: savedRecord)
                                syntheticNewsRecords.append(syntheticRecord)
                                print("📰 ✅ [\(Date())] Added unarchived PDF to news feed: \(title)")
                                
                                // Skip the regular archive check for this PDF since we've already handled it
                                continue
                            } catch {
                                print("📰 ❌ [\(Date())] Failed to clear isArchived flag: \(error.localizedDescription)")
                            }
                        }
                    }
                }
                
                // Second pass - normal processing for non-archived PDFs
                for pdf in pdfRecords {
                    // Skip PDFs that are archived (check both Bool and Int types for backward compatibility)
                    let isArchivedBool = (pdf["isArchived"] as? Bool) == true
                    let isArchivedInt = (pdf["isArchived"] as? Int) == 1
                    
                    if isArchivedBool || isArchivedInt {
                        print("📰 ℹ️ [\(Date())] Skipping archived PDF: \(pdf.recordID.recordName), title: \(pdf["title"] as? String ?? "Unknown")")
                        
                        // Check if this PDF is actually in the archived posts collection
                        // This helps fix cases where PDFs were deleted from archives but flag wasn't cleared
                        Task {
                            // Create a predicate to find ArchivedNewsPost records that reference this specific PDF
                            let pdfReferenceToFind = CKRecord.Reference(recordID: pdf.recordID, action: .none)
                            let referencePredicate = NSPredicate(format: "pdfReference == %@", pdfReferenceToFind)
                            
                            let archivedPostsQuery = CKQuery(recordType: "ArchivedNewsPost", predicate: referencePredicate)
                            print("📰 🔄 [\(Date())] Querying ArchivedNewsPost for pdfReference: \(pdf.recordID.recordName)")
                            
                            do {
                                let (archivedResults, _) = try await database.records(matching: archivedPostsQuery)
                                
                                // Check if any archived post references this PDF
                                var foundInArchives = false
                                for (_, archiveResult) in archivedResults {
                                    if case .success(let archiveRecord) = archiveResult {
                                        print("📰 🔄 [\(Date())] Found matching ArchivedNewsPost: \(archiveRecord.recordID.recordName)")
                                        foundInArchives = true
                                        break // Found one, no need to check further
                                    }
                                }
                                
                                // If not found in archives, the flag should be cleared
                                if !foundInArchives {
                                    print("📰 🔄 [\(Date())] PDF \(pdf.recordID.recordName) marked as archived but not found in ArchivedNewsPost references - clearing flag")
                                    pdf["isArchived"] = nil // Clear the flag
                                    
                                    // Save the PDF with the cleared flag
                                    let updatedPDF = try await database.save(pdf)
                                    print("📰 ✅ [\(Date())] Successfully cleared isArchived flag for \(updatedPDF["title"] as? String ?? "Unknown PDF")")
                                    
                                    // Create a synthetic record for this PDF since it's not actually archived
                                    let syntheticRecord = createSyntheticRecord(from: updatedPDF)
                                    
                                    // Use DispatchQueue.main to safely access the shared array
                                    DispatchQueue.main.async {
                                        // Add to the synthetic records array (ensure this array is accessible or handle appropriately)
                                        // syntheticNewsRecords.append(syntheticRecord) // Re-enable if syntheticNewsRecords is accessible
                                        print("📰 ✅ [\(Date())] Created synthetic news feed item from recovered PDF: \(syntheticRecord["title"] ?? "Unknown")")
                                        
                                        // Notify that we need to refresh the view
                                        NotificationCenter.default.post(name: NSNotification.Name("NewsFeedRefreshNotification"), object: nil)
                                    }
                                } else {
                                    print("📰 🔄 [\(Date())] PDF \(pdf.recordID.recordName) confirmed to be referenced by an ArchivedNewsPost.")
                                }
                            } catch {
                                // More specific logging for this context
                                print("📰 ❌ [\(Date())] Error querying ArchivedNewsPost for PDF reference \(pdf.recordID.recordName): \(error.localizedDescription)")
                                if let ckError = error as? CKError {
                                    print("📰 ❌ CKError Code: \(ckError.code.rawValue) - \(ckError)")
                                    // Log if the specific field is the issue
                                    if ckError.code == .invalidArguments && ckError.localizedDescription.contains("pdfReference") {
                                        print("📰 ❌ Issue might be with querying the 'pdfReference' field. Ensure it's marked QUERYABLE in the ArchivedNewsPost schema.")
                                    }
                                }
                            }
                        }
                        continue
                    }
                    
                    print("📰 ✅ [\(Date())] PDF found:")
                    print("📰    - ID: \(pdf.recordID.recordName)")
                    print("📰    - Title: \(pdf["title"] as? String ?? "No title")")
                    
                    // Log all fields in the PDF
                    print("📰    - All fields: \(pdf.allKeys().joined(separator: ", "))")
                    
                    // Create a synthetic news feed record from this PDF
                    let syntheticRecord = createSyntheticRecord(from: pdf)
                    syntheticNewsRecords.append(syntheticRecord)
                }
                
                print("📰 ✅ [\(Date())] Created \(syntheticNewsRecords.count) synthetic news feed items")
                return syntheticNewsRecords
            } else {
                print("📰 ❌ [\(Date())] No PDF records found")
                return []
            }
        } catch {
            print("📰 ❌ [\(Date())] Error retrieving PDF records: \(error.localizedDescription)")
            
            // Fall back to the previous approaches
            return await withCheckedContinuation { continuation in
                self.fetchRecordsWithLegacyAPI { records in
                    continuation.resume(returning: records)
                }
            }
        }
    }
    
    // Last resort method using the older API
    private func fetchRecordsWithLegacyAPI(completion: @escaping ([CKRecord]) -> Void) {
        print("📰 [\(Date())] Attempting final legacy approach to fetch records")
        
        let query = CKQuery(recordType: "NewsFeedItem", predicate: NSPredicate(value: true))
        
        // Don't use any sort descriptors, filter, or query on system fields
        database.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 100) { result in
            switch result {
            case .success(let matchResults):
                let records = matchResults.matchResults.compactMap { _, recordResult in
                    try? recordResult.get()
                }
                
                if !records.isEmpty {
                    print("📰 ✅ [\(Date())] Legacy API found \(records.count) records!")
                    
                    for record in records {
                        print("📰 ✅ [\(Date())] Legacy API found record:")
                        print("📰    - ID: \(record.recordID.recordName)")
                        print("📰    - Title: \(record["title"] as? String ?? "No title")")
                        print("📰    - All fields: \(record.allKeys().joined(separator: ", "))")
                    }
                    
                    completion(records)
                } else {
                    print("📰 ⚠️ [\(Date())] Legacy API found no records. Checking if PDFs exist...")
                    
                    // Try querying the PDF documents to see if they exist
                    let pdfQuery = CKQuery(recordType: "PDFDocumentItem", predicate: NSPredicate(value: true))
                    self.database.fetch(withQuery: pdfQuery, inZoneWith: nil, desiredKeys: nil, resultsLimit: 100) { pdfResult in
                        switch pdfResult {
                        case .success(let pdfMatchResults):
                            let pdfRecords = pdfMatchResults.matchResults.compactMap { _, recordResult in
                                try? recordResult.get()
                            }
                            
                            if !pdfRecords.isEmpty {
                                print("📰 ✅ [\(Date())] Found \(pdfRecords.count) PDF records! They exist but News Feed items don't.")
                                
                                // Check if any PDF has a related news feed record
                                for pdf in pdfRecords {
                                    print("📰 ✅ [\(Date())] PDF found:")
                                    print("📰    - ID: \(pdf.recordID.recordName)")
                                    print("📰    - Title: \(pdf["title"] as? String ?? "No title")")
                                    print("📰    - All fields: \(pdf.allKeys().joined(separator: ", "))")
                                }
                                
                                // Try to check for similar record types
                                self.tryAlternativeRecordTypes { alternativeRecords in
                                    if !alternativeRecords.isEmpty {
                                        completion(alternativeRecords)
                                    } else {
                                        completion([])
                                    }
                                }
                            } else {
                                print("📰 ❌ [\(Date())] No PDF records found either")
                                completion([])
                            }
                        case .failure(let error):
                            print("📰 ❌ [\(Date())] Error fetching PDF records: \(error.localizedDescription)")
                            completion([])
                        }
                    }
                }
            case .failure(let error):
                print("📰 ❌ [\(Date())] Legacy API query failed: \(error.localizedDescription)")
                
                // Try to check all available record types as a diagnostic step
                self.database.fetchAllRecordZones { (zones, zonesError) in
                    if let zones = zones {
                        print("📰 ℹ️ [\(Date())] Available zones: \(zones.map { $0.zoneID.zoneName }.joined(separator: ", "))")
                        
                        // Try querying for all record types instead of user identities
                        let recordTypesQuery = CKQuery(recordType: "PDFDocumentItem", predicate: NSPredicate(value: true))
                        self.database.fetch(withQuery: recordTypesQuery, inZoneWith: nil, desiredKeys: nil, resultsLimit: 100) { typeResult in
                            switch typeResult {
                            case .success(let matchResults):
                                let records = matchResults.matchResults.compactMap { _, recordResult in
                                    try? recordResult.get()
                                }
                                
                                if !records.isEmpty {
                                    print("📰 ✅ [\(Date())] Found \(records.count) PDF records!")
                                    print("📰 ✅ [\(Date())] This confirms the database connection works!")
                                    
                                    // Try to list all record types
                                    print("📰 ℹ️ [\(Date())] Attempting to identify other record types...")
                                    
                                    // Try a direct check for record type name variations
                                    self.tryAlternativeRecordTypes { alternativeRecords in
                                        if !alternativeRecords.isEmpty {
                                            completion(alternativeRecords)
                                        } else {
                                            completion([])
                                        }
                                    }
                                } else {
                                    print("📰 ❌ [\(Date())] No records found at all")
                                    completion([])
                                }
                            case .failure(let error):
                                print("📰 ❌ [\(Date())] Error finding records: \(error.localizedDescription)")
                                completion([])
                            }
                        }
                    } else {
                        print("📰 ❌ [\(Date())] Failed to fetch zones: \(zonesError?.localizedDescription ?? "Unknown error")")
                        completion([])
                    }
                }
            }
        }
    }
    
    // Try various alternative record type names
    private func tryAlternativeRecordTypes(completion: @escaping ([CKRecord]) -> Void) {
        let possibleTypes = [
            "NewsItem", "NewsFeedPost", "NewsPost", "News", "FeedItem", 
            "NewsFeed", "Article", "Post"
        ]
        
        print("📰 [\(Date())] Trying alternative record type names...")
        
        var foundRecords = [CKRecord]()
        let group = DispatchGroup()
        
        for typeName in possibleTypes {
            group.enter()
            let query = CKQuery(recordType: typeName, predicate: NSPredicate(value: true))
            
            database.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 100) { result in
                defer { group.leave() }
                
                switch result {
                case .success(let matchResults):
                    let records = matchResults.matchResults.compactMap { _, recordResult in 
                        try? recordResult.get()
                    }
                    
                    if !records.isEmpty {
                        print("📰 ✅ [\(Date())] Found \(records.count) records with type '\(typeName)'!")
                        foundRecords.append(contentsOf: records)
                        
                        for record in records {
                            print("📰 ✅ [\(Date())] Found record of type '\(typeName)':")
                            print("📰    - ID: \(record.recordID.recordName)")
                            print("📰    - Fields: \(record.allKeys().joined(separator: ", "))")
                        }
                    }
                case .failure(let error):
                    print("📰 [\(Date())] Type '\(typeName)' query failed: \(error.localizedDescription)")
                }
            }
        }
        
        group.notify(queue: .main) {
            print("📰 [\(Date())] Completed alternative record type search, found \(foundRecords.count) records")
            completion(foundRecords)
        }
    }
    
    private func updatePost(originalPost: NewsFeedPost, updatedPost: EditNewsPostInfo) {
        let recordID = originalPost.id
        
        database.fetch(withRecordID: recordID) { record, error in
            guard let record = record, error == nil else {
                print("Error fetching record: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            // Update the record with new values
            record["title"] = updatedPost.title
            
            if let scheduledDate = updatedPost.scheduledDate {
                record["scheduledDate"] = scheduledDate
                record["datePosted"] = nil  // Clear posted date if scheduled
            } else {
                record["scheduledDate"] = nil  // Clear scheduled date
                if record["datePosted"] == nil {
                    record["datePosted"] = Date()  // Set posted date if not already set
                }
            }
            
            // Update link URL
            if let linkURL = updatedPost.linkURL, !linkURL.isEmpty {
                record["linkURL"] = linkURL
            } else {
                record["linkURL"] = nil  // Remove link if empty
            }
            
            // Ensure recordNameMirror is set
            if record["recordNameMirror"] == nil {
                record["recordNameMirror"] = record.recordID.recordName
            }
            
            if let pdfRecord = updatedPost.pdfRecord {
                record["pdfReference"] = CKRecord.Reference(record: pdfRecord, action: .deleteSelf)
            } else if updatedPost.pdfURL != nil {
                // Upload new PDF and create reference
                // (This would require additional logic to handle PDF uploads)
                // For now, we'll leave the existing reference
            }
            
            // Save the updated record
            self.database.save(record) { _, error in
                if let error = error {
                    print("Error saving record: \(error.localizedDescription)")
                } else {
                    DispatchQueue.main.async {
                        self.loadPosts()
                    }
                }
            }
        }
    }
    
    private func deletePost(_ post: NewsFeedPost) {
        database.delete(withRecordID: post.id) { _, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error deleting record: \(error.localizedDescription)")
                } else {
                    // Remove the post from our local state
                    if let index = self.posts.firstIndex(where: { $0.id == post.id }) {
                        self.posts.remove(at: index)
                    }
                }
            }
        }
    }
    
    private func publishNow(_ post: NewsFeedPost) {
        guard post.isScheduled else { return }
        
        // Fetch the record directly using its ID instead of querying
        database.fetch(withRecordID: post.id) { record, error in
            if let error = error {
                print("Error fetching record: \(error.localizedDescription)")
                return
            }
            
            guard let record = record else {
                print("No record found for post")
                return
            }
            
            // Remove scheduled date to publish immediately
            record["scheduledDate"] = nil
            record["datePosted"] = Date() // Update to current date
            
            // Ensure recordNameMirror is set
            if record["recordNameMirror"] == nil {
                record["recordNameMirror"] = record.recordID.recordName
            }
            
            self.database.save(record) { _, error in
                if let error = error {
                    print("Error publishing now: \(error.localizedDescription)")
                } else {
                    DispatchQueue.main.async {
                        self.loadPosts()
                    }
                }
            }
        }
    }
    
    private func archivePost(post: NewsFeedPost) {
        isLoading = true
        
        print("📰 NewsFeed: Starting to archive post: \(post.id.recordName)")
        
        // Create a new archived record
        let archivedRecord = CKRecord(recordType: "ArchivedNewsPost")
        
        // Transfer data directly from the post object without fetching the original
        archivedRecord["title"] = post.title
        archivedRecord["datePosted"] = post.datePosted
        archivedRecord["recordNameMirror"] = post.recordNameMirror
        archivedRecord["archivedDate"] = Date() // Add archive date
        
        // Add PDF reference if available
        if let pdfRef = post.pdfReference {
            archivedRecord["pdfReference"] = pdfRef
            
            // Mark the PDF as archived so it won't be shown in the news feed again
            database.fetch(withRecordID: pdfRef.recordID) { pdfRecord, error in
                if let pdfRecord = pdfRecord, error == nil {
                    // Use Int (1) instead of Bool (true) for consistency with other parts of the app
                    pdfRecord["isArchived"] = 1 
                    self.database.save(pdfRecord) { _, error in
                        if let error = error {
                            print("📰 NewsFeed: Warning - Failed to mark PDF as archived: \(error.localizedDescription)")
                        } else {
                            print("📰 NewsFeed: Successfully marked PDF as archived")
                            
                            // Manually trigger a refresh of the news feed to update the UI
                            DispatchQueue.main.async {
                                self.loadPosts()
                            }
                        }
                    }
                }
            }
        }
            
        // Save the archived record
        database.save(archivedRecord) { newRecord, error in
            if let error = error {
                print("📰 NewsFeed: Error saving archived post: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Error saving to archive: \(error.localizedDescription)"
                }
                return
            }
            
            print("📰 NewsFeed: Successfully saved archived post")
            
            // Remove the post from our local array regardless of whether it exists in CloudKit
            DispatchQueue.main.async {
                self.isLoading = false
                
                // Remove the post from our local array
                self.posts.removeAll { $0.id == post.id }
                
                // Notify the parent view that we've archived a post
                NotificationCenter.default.post(name: Notification.Name("ArchivedNewsPostNotification"), object: nil)
                
                print("📰 NewsFeed: Successfully archived post")
            }
        }
    }
    
    // Add retry mechanism for PDF loading
    private func loadPDFWithRetry(fileURL: URL, maxRetries: Int = 3, retryDelay: TimeInterval = 0.5, startTime: Date) {
        var retryCount = 0
        let currentIsSpanish = languageManager.isSpanish // Capture current language state

        func attemptLoad() {
            // Check if file exists and get file attributes
            do {
                let fileManager = FileManager.default
                let fileAttributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                
                // Check file size
                if let fileSize = fileAttributes[.size] as? Int64 {
                    print("📄 PDF Load: File size: \(fileSize) bytes (\(String(format: "%.1f", Double(fileSize) / 1024.0 / 1024.0))MB)")
                    if fileSize < 100 {
                        print("⚠️ PDF Load WARNING: File size is suspiciously small (\(fileSize) bytes)")
                        DispatchQueue.main.async {
                            // Use captured language state
                            self.errorMessage = currentIsSpanish ? "Error: El archivo PDF parece estar dañado" : "Error: PDF file appears to be corrupted"
                        }
                        return
                    }
                }
                
                // Try to load the PDF directly from URL first
                print("📄 PDF Load: Attempting to create PDFDocument from URL...")
                let urlLoadStartTime = Date()
                
                if let pdfDocument = PDFKit.PDFDocument(url: fileURL) {
                    let urlLoadDuration = Date().timeIntervalSince(urlLoadStartTime)
                    print("✅ PDF Load SUCCESS: Created PDFDocument from URL in \(String(format: "%.3f", urlLoadDuration))s")
                    print("📄 PDF Details: Page count: \(pdfDocument.pageCount)")
                    
                    if pdfDocument.pageCount == 0 {
                        print("❌ PDF Load ERROR: PDF document has 0 pages")
                        print("📄 PDF Load: Loading process failed after \(String(format: "%.3f", Date().timeIntervalSince(startTime)))s")
                        DispatchQueue.main.async {
                            // Use captured language state
                            self.errorMessage = currentIsSpanish ? "Error: El documento PDF no tiene páginas" : "Error: PDF document has no pages"
                        }
                        return
                    }
                    
                    // Set the document and show the viewer on the main thread
                    DispatchQueue.main.async {
                        print("📄 PDF Load: Setting currentPDFDocument on main thread")
                        self.currentPDFDocument = pdfDocument
                        self.showingPDFViewer = true
                        print("📄 PDF Load: showingPDFViewer set to true")
                        print("✅ PDF LOADING PROCESS COMPLETE ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                        print("📄 Total loading time: \(String(format: "%.3f", Date().timeIntervalSince(startTime)))s")
                    }
                    return
                }
                
                // If we get here, the PDF couldn't be loaded
                if retryCount < maxRetries {
                    retryCount += 1
                    print("⚠️ PDF Load: Attempt \(retryCount) failed, retrying in \(retryDelay)s...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) {
                        attemptLoad()
                    }
                } else {
                    print("❌ PDF Load: All retry attempts failed")
                    DispatchQueue.main.async {
                        // Use captured language state
                        self.errorMessage = currentIsSpanish ? "Error: No se pudo cargar el PDF después de múltiples intentos" : "Error: Failed to load PDF after multiple attempts"
                    }
                }
            } catch {
                print("⚠️ PDF Load: Error accessing file: \(error.localizedDescription)")
                if retryCount < maxRetries {
                    retryCount += 1
                    print("⚠️ PDF Load: Attempt \(retryCount) failed, retrying in \(retryDelay)s...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) {
                        attemptLoad()
                    }
                } else {
                    print("❌ PDF Load: All retry attempts failed")
                    DispatchQueue.main.async {
                        // Use captured language state
                        self.errorMessage = languageManager.isSpanish ? "Error: No se pudo acceder al archivo PDF" : "Error: Could not access PDF file"
                    }
                }
            }
        }
        
        // Start the first attempt
        attemptLoad()
    }
    
    // Update loadPDF function to use the retry mechanism
    private func loadPDF() {
        print("📄 PDF LOADING PROCESS START ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        let startTime = Date()
        
        // Check if we have a selected record
        guard let selectedRecord = selectedPDFRecord else {
            print("❌ PDF Load: No PDF record selected")
            DispatchQueue.main.async {
                self.errorMessage = languageManager.isSpanish ? "Error: No se ha seleccionado ningún documento PDF" : "Error: No PDF document selected"
            }
            return
        }
        
        print("📄 PDF Load: Attempting to load PDF: \(selectedRecord["title"] as? String ?? "Untitled")")
        
        // Get system memory info for debugging
        let memoryInfo = ProcessInfo.processInfo
        print("📄 System Memory: Total: \(String(format: "%.1f", Double(memoryInfo.physicalMemory) / 1024.0 / 1024.0 / 1024.0))GB")
        
        // Check if the record has a pdfFile field
        guard let asset = selectedRecord["pdfFile"] as? CKAsset else {
            print("❌ PDF Load: No pdfFile asset found in record")
            DispatchQueue.main.async {
                // Use captured language state
                self.errorMessage = languageManager.isSpanish ? "Error: El documento seleccionado no contiene un archivo PDF" : "Error: Selected document does not contain a PDF file"
            }
            return
        }
        
        // Check if we have a valid file URL
        guard let fileURL = asset.fileURL else {
            print("❌ PDF Load: No file URL available in CKAsset")
            DispatchQueue.main.async {
                self.errorMessage = languageManager.isSpanish ? "Error: No se pudo acceder al archivo PDF" : "Error: Could not access PDF file"
            }
            return
        }
        
        print("📄 PDF Load: File URL: \(fileURL.path)")
        print("📄 PDF Load: File URL scheme: \(fileURL.scheme ?? "none")")
        print("📄 PDF Load: File URL isFileURL: \(fileURL.isFileURL)")
        
        // Use the retry mechanism to load the PDF
        loadPDFWithRetry(fileURL: fileURL, startTime: startTime)
    }
    
    // Helper method to create a synthetic record from a PDF record
    private func createSyntheticRecord(from pdf: CKRecord) -> CKRecord {
        let syntheticRecord = CKRecord(recordType: "NewsFeedItem")
        
        // Copy over the title
        if let title = pdf["title"] as? String {
            syntheticRecord["title"] = title
        } else {
            syntheticRecord["title"] = "PDF Document"
        }
        
        // Set dates
        if let dateUploaded = pdf["dateUploaded"] as? Date {
            syntheticRecord["datePosted"] = dateUploaded
            syntheticRecord["datePublished"] = dateUploaded
        } else {
            syntheticRecord["datePosted"] = Date()
            syntheticRecord["datePublished"] = Date()
        }
        
        // Link to the PDF
        syntheticRecord["pdfReference"] = CKRecord.Reference(recordID: pdf.recordID, action: .none)
        
        // Set record mirror
        syntheticRecord["recordNameMirror"] = syntheticRecord.recordID.recordName
        
        print("📰 ✅ [\(Date())] Created synthetic news feed item from PDF: \(syntheticRecord["title"] ?? "Unknown")")
        return syntheticRecord
    }
    
    // MARK: - Archive Management Methods
    
    private func loadArchivedPosts() {
        print("\n📰 ===== ARCHIVED NEWS FEED DEBUG LOG ===== 📰")
        print("📰 [\(Date())] Starting to load archived posts")
        isLoading = true
        errorMessage = nil
        
        let query = CKQuery(recordType: "ArchivedNewsPost", predicate: NSPredicate(value: true))
        
        Task {
            do {
                let (result, _) = try await database.records(matching: query)
                
                let records = result.compactMap { _, recordResult -> CKRecord? in
                    try? recordResult.get()
                }
                
                print("📰 ✅ [\(Date())] Retrieved \(records.count) archived posts from CloudKit")
                
                var archivedPosts = records.map { ArchivedNewsPost(record: $0) }
                
                // Fetch PDFs for posts that have references
                for i in 0..<archivedPosts.count {
                    if let pdfRef = archivedPosts[i].pdfReference {
                        do {
                            print("📰 [\(Date())] Fetching PDF for archived post: \(archivedPosts[i].title)")
                            let pdfRecord = try await database.record(for: pdfRef.recordID)
                            let pdfDetails = PDFDocumentDetails(record: pdfRecord)
                            archivedPosts[i].pdfDocument = pdfDetails
                            print("📰 ✅ [\(Date())] Successfully loaded PDF for archived post: \(archivedPosts[i].title)")
                        } catch {
                            print("📰 ❌ [\(Date())] Error fetching PDF for archived post \(archivedPosts[i].title): \(error.localizedDescription)")
                        }
                    }
                }
                
                // Sort by archived date, newest first
                archivedPosts.sort { $0.archivedDate > $1.archivedDate }
                
                await MainActor.run {
                    self.archivedPosts = archivedPosts
                    self.isLoading = false
                    print("📰 ✅ [\(Date())] UI updated with \(archivedPosts.count) archived posts")
                    print("📰 ===== ARCHIVED NEWS FEED LOAD COMPLETE ===== 📰\n")
                }
                
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Error loading archives: \(error.localizedDescription)"
                    print("📰 ❌ [\(Date())] Error loading archived posts: \(error.localizedDescription)")
                    print("📰 ===== ARCHIVED NEWS FEED LOAD FAILED ===== 📰\n")
                }
            }
        }
    }
    
    private func unarchivePost(_ post: ArchivedNewsPost) {
        print("📰 [\(Date())] Starting to unarchive post: \(post.id.recordName)")
        
        // Create a new news feed record
        let newsFeedRecord = CKRecord(recordType: "NewsFeedItem")
        
        // Transfer data from archived post
        newsFeedRecord["title"] = post.title
        newsFeedRecord["datePosted"] = Date() // Set current date as publishing date
        
        // Set recordNameMirror for queryability
        newsFeedRecord["recordNameMirror"] = newsFeedRecord.recordID.recordName
        
        // Add PDF reference if available
        if let pdfRef = post.pdfReference {
            newsFeedRecord["pdfReference"] = pdfRef
            
            // Update the PDF record to remove archived flag
            database.fetch(withRecordID: pdfRef.recordID) { pdfRecord, error in
                if let pdfRecord = pdfRecord, error == nil {
                    // Remove both possible formats of the isArchived flag for compatibility
                    pdfRecord["isArchived"] = nil 
                    self.database.save(pdfRecord) { _, error in
                        if let error = error {
                            print("📰 [\(Date())] Warning: Failed to clear isArchived flag: \(error.localizedDescription)")
                        } else {
                            print("📰 [\(Date())] Successfully cleared isArchived flag on PDF")
                            
                            // Manually trigger a refresh of the news feed
                            DispatchQueue.main.async {
                                self.loadPosts()
                            }
                        }
                    }
                }
            }
        }
        
        // Save the new news feed record
        database.save(newsFeedRecord) { _, error in
            if let error = error {
                print("📰 [\(Date())] Error creating unarchived post: \(error.localizedDescription)")
                return
            }
            
            print("📰 [\(Date())] Successfully created unarchived post")
            
            // Now delete the archived record
            self.database.delete(withRecordID: post.id) { _, error in
                if let error = error {
                    print("📰 [\(Date())] Error deleting archived post: \(error.localizedDescription)")
                } else {
                    print("📰 [\(Date())] Successfully deleted archived post")
                    
                    DispatchQueue.main.async {
                        // Remove from local array
                        self.archivedPosts.removeAll { $0.id == post.id }
                        
                        // Notify that news feed should be refreshed
                        NotificationCenter.default.post(name: Notification.Name("NewsFeedRefreshNotification"), object: nil)
                    }
                }
            }
        }
    }
    
    private func deleteArchivedPost(_ post: ArchivedNewsPost) {
        print("📰 [\(Date())] Starting to delete archived post: \(post.id.recordName)")
        
        database.delete(withRecordID: post.id) { _, error in
            if let error = error {
                print("📰 [\(Date())] Error deleting archived post: \(error.localizedDescription)")
            } else {
                print("📰 [\(Date())] Successfully deleted archived post")
                
                DispatchQueue.main.async {
                    // Remove from local array
                    self.archivedPosts.removeAll { $0.id == post.id }
                }
            }
        }
    }
    
    // Helper function to filter archived posts
    var filteredArchivedPosts: [ArchivedNewsPost] {
        guard !searchText.isEmpty else { return archivedPosts }
        return archivedPosts.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    // Active posts view
    var activePostsView: some View {
        VStack {
            // Search and filters
            HStack {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField(isSpanish ? "Buscar por título..." : "Search by title...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.trailing)
                
                // Filters
                Toggle(isSpanish ? "Solo Programados" : "Scheduled Only", isOn: $showingSortOptions)
                    .toggleStyle(.checkbox)
                    .padding(.trailing)
                
                Picker(isSpanish ? "Ordenar" : "Sort", selection: $sortOption) {
                    ForEach(SortOption.allCases) { option in
                        Text(option.localizedName)
                            .tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.textBackgroundColor))
            
            if isLoading {
                loadingView(message: isSpanish ? "Cargando noticias..." : "Loading news...")
            } else if let error = errorMessage {
                errorView(error: error, retryAction: loadPosts)
            } else if posts.isEmpty {
                emptyStateView(
                    icon: "newspaper", 
                    message: isSpanish ? "No hay noticias para mostrar" : "No news to display"
                )
            } else {
                // Content is the same as before
                // We'll just reuse the existing body code for this case
                HStack(spacing: 0) {
                    VStack {
                        List {
                            ForEach(filteredPosts) { post in
                                NewsPostRow(post: post, isSpanish: isSpanish)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectPost(post)
                                    }
                                    .background(selectedPost?.id == post.id ? Color.blue.opacity(0.1) : Color.clear)
                                    .contextMenu {
                                        Button(action: { editPost(post) }) {
                                            Label(isSpanish ? "Editar" : "Edit", systemImage: "pencil")
                                        }
                                        
                                        if let scheduledDate = post.scheduledDate, scheduledDate > Date() {
                                            Button(action: { publishNow(post) }) {
                                                Label(isSpanish ? "Publicar Ahora" : "Publish Now", systemImage: "arrow.up.circle")
                                            }
                                        }
                                        
                                        Button(action: {
                                            selectedPost = post
                                            showingArchiveAlert = true
                                        }) {
                                            Label(isSpanish ? "Archivar" : "Archive", systemImage: "archivebox")
                                        }
                                        
                                        Button(action: {
                                            selectedPost = post
                                            showingDeleteAlert = true
                                        }) {
                                            Label(isSpanish ? "Eliminar" : "Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .listStyle(.inset)
                        
                        // Create New Post button
                        Button(action: createNewPost) {
                            Label(isSpanish ? "Crear Nueva Publicación" : "Create New Post", systemImage: "plus.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .padding()
                    }
                    .frame(minWidth: 300)
                    
                    Divider()
                    
                    // Detail panel remains the same as in body
                    if let post = selectedPost, !isEditing {
                        selectedPostDetailView(post: post)
                    } else if isEditing {
                        editPostView
                    } else {
                        emptyDetailView
                    }
                }
            }
        }
    }
    
    // Helper views
    private func loadingView(message: String) -> some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
                .padding()
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private func errorView(error: String, retryAction: @escaping () -> Void) -> some View {
        VStack {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.red)
                .padding()
            Text(error)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding()
            Button("Reintentar") {
                retryAction()
            }
            .buttonStyle(.bordered)
            .padding()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private func emptyStateView(icon: String, message: String) -> some View {
        VStack {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.gray)
                .padding()
            Text(message)
                .font(.headline)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private var emptyDetailView: some View {
        VStack {
            Spacer()
            Image(systemName: "arrow.left.circle")
                .font(.system(size: 40))
                .foregroundColor(.gray)
                .padding()
            Text(isSpanish ? "Selecciona una publicación para ver detalles" : "Select a post to view details")
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // Helper functions for post management
    private func selectPost(_ post: NewsFeedPost) {
        if selectedPost?.id == post.id {
            // Deselect if tapping the same post again
            selectedPost = nil
            isEditing = false
        } else {
            selectedPost = post
            isEditing = false
            // Initialize edit state when selecting a post
            editTitle = post.title
            isScheduled = post.isScheduled
            scheduledDate = post.scheduledDate ?? Date().addingTimeInterval(3600)
            // Load PDF record if needed
            if let pdfRef = post.pdfReference {
                loadPDFRecord(pdfRef)
            } else {
                selectedPDFRecord = nil
                selectedPDFURL = nil
                selectedFileLabel = ""
            }
        }
    }
    
    private func editPost(_ post: NewsFeedPost) {
        selectedPost = post
        isEditing = true
        // Initialize edit state
        editTitle = post.title
        isScheduled = post.isScheduled
        scheduledDate = post.scheduledDate ?? Date().addingTimeInterval(3600)
        editLinkURL = post.linkURL?.absoluteString ?? ""  // Initialize link URL from post
        
        // Load PDF record if needed
        if let pdfRef = post.pdfReference {
            loadPDFRecord(pdfRef)
        } else {
            selectedPDFRecord = nil
            selectedPDFURL = nil
            selectedFileLabel = ""
        }
    }
    
    private func createNewPost() {
        // Reset edit state for a new post
        selectedPost = nil
        isEditing = true
        editTitle = ""
        isScheduled = false
        scheduledDate = Date().addingTimeInterval(3600)
        editLinkURL = ""  // Reset link URL for new post
        selectedPDFRecord = nil
        selectedPDFURL = nil
        selectedFileLabel = ""
    }
    
    // Selected post detail view
    private func selectedPostDetailView(post: NewsFeedPost) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                // Title
                Text(post.title)
                    .font(.title)
                    .fontWeight(.bold)

                // Action buttons for post management
                HStack {
                    Button(action: { editPost(post) }) {
                        HStack {
                            Image(systemName: "pencil")
                            Text(isSpanish ? "Editar" : "Edit")
                        }
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button(action: {
                        selectedPost = post
                        showingArchiveAlert = true
                    }) {
                        HStack {
                            Image(systemName: "archivebox")
                            Text(isSpanish ? "Archivar" : "Archive")
                        }
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    if let scheduledDate = post.scheduledDate, scheduledDate > Date() {
                        Button(action: { publishNow(post) }) {
                            HStack {
                                Image(systemName: "arrow.up.circle")
                                Text(isSpanish ? "Publicar Ahora" : "Publish Now")
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.vertical, 10)

                Divider()

                // Status and dates
                Group {
                    if post.isScheduled {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundColor(.orange)

                            Text(isSpanish ? "Programado para:" : "Scheduled for:")
                                .fontWeight(.medium)

                            Text(DateFormatter.localizedString(from: post.scheduledDate!, dateStyle: .full, timeStyle: .short))
                        }
                        .padding(.bottom, 5)
                    } else {
                        HStack {
                            Image(systemName: "calendar.badge.checkmark")
                                .foregroundColor(.green)

                            Text(isSpanish ? "Publicado el:" : "Published on:")
                                .fontWeight(.medium)

                            Text(DateFormatter.localizedString(from: post.datePosted, dateStyle: .full, timeStyle: .short))
                        }
                        .padding(.bottom, 5)
                    }
                }

                // Link URL if available
                if let linkURL = post.linkURL {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Image(systemName: "link")
                                .foregroundColor(.blue)

                            Text(isSpanish ? "Enlace:" : "Link:")
                                .fontWeight(.medium)
                        }

                        Link(destination: linkURL) {
                            Text(linkURL.absoluteString)
                                .foregroundColor(.blue)
                                .underline()
                                .padding(.leading, 28)
                        }
                    }
                    .padding(.vertical, 10)
                }

                // PDF attachment details
                if let pdfDetails = post.pdfDocument { // Use pdfDetails consistently
                    Divider()

                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.blue)

                            Text(isSpanish ? "PDF Adjunto:" : "Attached PDF:")
                                .fontWeight(.medium)
                        }

                        // PDF details if available
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pdfDetails.title) // Use pdfDetails
                                .font(.subheadline)
                                .padding(.leading, 28)

                            if let thumbnail = pdfDetails.thumbnail { // Use pdfDetails
                                Image(nsImage: thumbnail)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 150)
                                    .cornerRadius(4)
                                    .padding(.leading, 28)
                                    .padding(.vertical, 5)
                            }

                            // ---> MODIFIED BUTTON ACTION AND DISABLED STATE
                            Button(isSpanish ? "Ver PDF completo" : "View full PDF") {
                                print("📄 UI Action: 'View full PDF' button tapped for \(pdfDetails.title)")
                                // Add logging here to check fileURL state *at tap time*
                                print("📄 UI Action: Checking pdfDetails at tap time. Title: '\(pdfDetails.title)'. fileURL is \(pdfDetails.fileURL == nil ? "nil" : "present")")
                                
                                // Set the item to trigger the sheet presentation
                                self.pdfDetailsToShow = pdfDetails
                                print("📄 UI Action: Set pdfDetailsToShow for '\(pdfDetails.title)'")
                            }
                            .buttonStyle(.bordered)
                            .padding(.leading, 28)
                            // Disable the button if the fileURL isn't available yet
                            .disabled(pdfDetails.fileURL == nil)
                            // <--- END MODIFIED

                            // Show message if fileURL is nil (still loading/processing)
                            if pdfDetails.fileURL == nil {
                                Text(isSpanish ? "Procesando PDF..." : "Processing PDF...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 28)
                                    .padding(.top, 5)
                            }
                        }
                    }
                    .padding(.vertical, 5)
                } else if post.pdfReference != nil {
                    // This section indicates the PDF *reference* exists, but the details haven't been loaded yet.
                    Divider()

                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.blue)

                            Text(isSpanish ? "PDF Adjunto:" : "Attached PDF:")
                                .fontWeight(.medium)
                        }

                        HStack {
                             ProgressView() // Show a spinner while loading
                                .scaleEffect(0.7)
                                .padding(.leading, 28)
                             Text(isSpanish ? "Cargando detalles del PDF..." : "Loading PDF details...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                    }
                    .padding(.vertical, 5)
                }

                Spacer()
            }
            .padding()
        }
        // Add logging on view appear
        .onAppear {
            print("📄 DetailView: Appeared for post '\(post.title)'")
            if let details = post.pdfDocument {
                print("📄 DetailView: pdfDocument exists. Title: '\(details.title)'. fileURL is \(details.fileURL == nil ? "nil" : "present")")
            } else {
                print("📄 DetailView: pdfDocument is nil.")
            }
        }
    }
    
    // Edit post view
    var editPostView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                // Title
                Text(selectedPost == nil ? 
                    (isSpanish ? "Nueva Publicación" : "New Post") : 
                    (isSpanish ? "Editar Publicación" : "Edit Post"))
                    .font(.title)
                    .fontWeight(.bold)
                
                Divider()
                
                // Title field
                Group {
                    Text(isSpanish ? "Título:" : "Title:")
                        .font(.headline)
                    
                    TextField(isSpanish ? "Título de la publicación" : "Post title", text: $editTitle)
                        .textFieldStyle(.roundedBorder)
                        .padding(.bottom, 10)
                }
                
                // Scheduling section
                Group {
                    Text(isSpanish ? "Programación:" : "Scheduling:")
                        .font(.headline)
                    
                    Toggle(isSpanish ? "Programar para una fecha futura" : "Schedule for a future date", isOn: $isScheduled)
                        .padding(.bottom, 5)
                    
                    if isScheduled {
                        DatePicker(
                            isSpanish ? "Fecha de publicación:" : "Publication date:",
                            selection: $scheduledDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.compact)
                        .padding(.bottom, 10)
                    }
                }
                
                // PDF section
                Group {
                    Text(isSpanish ? "PDF Adjunto:" : "Attached PDF:")
                        .font(.headline)
                    
                    PDFSelectorView(
                        selectedPDFRecord: $selectedPDFRecord,
                        selectedPDFURL: $selectedPDFURL,
                        selectedFileLabel: $selectedFileLabel,
                        isSpanish: $isSpanish
                    )
                    .frame(height: 300)
                }
                
                // Link URL field
                Group {
                    Text(isSpanish ? "Enlace URL:" : "Link URL:")
                        .font(.headline)
                    
                    TextField(isSpanish ? "URL del sitio web (opcional)" : "Website URL (optional)", text: $editLinkURL)
                        .textFieldStyle(.roundedBorder)
                        .padding(.bottom, 10)
                }
                
                Spacer()
                
                // Action buttons
                HStack {
                    Button(isSpanish ? "Cancelar" : "Cancel") {
                        print("📱 UI: Cancel button pressed in NewsFeedManagementView")
                        print("📱 UI: Current edit state before cancel: isEditing = \(isEditing)")
                        isEditing = false
                        print("📱 UI: Edit mode exited successfully")
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button(isSpanish ? "Guardar Cambios" : "Save Changes") {
                        saveChanges()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(editTitle.isEmpty)
                }
            }
            .padding()
        }
    }
    
    // Add loadAndShowPDF function
    private func loadAndShowPDF(fileName: String, fileURL: URL?) {
        print("\n📄 PDF LOADING PROCESS START ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📄 PDF Load: Attempting to load PDF: \(fileName)")
        let startTime = Date()
        
        // Reset state
        self.currentPDFDocument = nil
        self.showingPDFViewer = false
        self.errorMessage = nil
        
        // Log system memory status
        let processInfo = ProcessInfo.processInfo
        let physicalMemory = processInfo.physicalMemory
        let memoryUsage = Double(physicalMemory) / 1024.0 / 1024.0 / 1024.0 // Convert to GB
        print("📄 System Memory: Total: \(String(format: "%.1f", memoryUsage))GB")
        
        guard let fileURL = fileURL else {
            print("❌ PDF Load ERROR: File URL is nil for \(fileName)")
            print("📄 PDF Load: Loading process failed after \(String(format: "%.3f", Date().timeIntervalSince(startTime)))s")
            
            // Check if PDF is still loading
            if isLoading {
                DispatchQueue.main.async {
                    self.errorMessage = languageManager.isSpanish ? 
                        "El PDF aún se está cargando. Por favor espere..." : 
                        "PDF is still loading. Please wait..."
                }
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = languageManager.isSpanish ? 
                        "No se pudo cargar el PDF. Intente seleccionar otro documento o actualizar la página." : 
                        "Could not load PDF. Try selecting another document or refresh the page."
                }
            }
            return
        }
        
        print("📄 PDF Load: File URL: \(fileURL.path)")
        print("📄 PDF Load: File URL scheme: \(fileURL.scheme ?? "none")")
        print("📄 PDF Load: File URL isFileURL: \(fileURL.isFileURL)")
        
        // Use the retry mechanism to load the PDF
        loadPDFWithRetry(fileURL: fileURL, startTime: startTime)
    }
}

// MARK: - News Post Row
struct NewsPostRow: View {
    let post: NewsFeedPost
    let isSpanish: Bool
    
    var body: some View {
        HStack(spacing: 15) {
            // PDF thumbnail or icon
            if let pdfDocument = post.pdfDocument, let thumbnail = pdfDocument.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                    .cornerRadius(4)
            } else {
                Image(systemName: post.pdfReference != nil ? "doc.text.fill" : "doc.text")
                    .font(.system(size: 24))
                    .foregroundColor(post.pdfReference != nil ? .blue : .gray)
                    .frame(width: 40)
            }
            
            // Title and date info
            VStack(alignment: .leading, spacing: 4) {
                Text(post.title)
                    .font(.headline)
                    .lineLimit(1)
                
                if let pdfDoc = post.pdfDocument {
                    Text(pdfDoc.title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack {
                    if post.isScheduled {
                        Label(
                            post.scheduledDate != nil ? 
                                formatDate(post.scheduledDate!) : "",
                            systemImage: "calendar.badge.clock"
                        )
                        .font(.caption)
                        .foregroundColor(.orange)
                    } else {
                        Label(
                            formatDate(post.datePosted),
                            systemImage: "calendar.badge.checkmark"
                        )
                        .font(.caption)
                        .foregroundColor(.green)
                    }
                    
                    // Link indicator
                    if post.linkURL != nil {
                        Label("", systemImage: "link")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
            
            // Status indicator
            if post.isScheduled {
                Text(isSpanish ? "Programado" : "Scheduled")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange)
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Archived Post Row
struct ArchivedPostRow: View {
    let post: ArchivedNewsPost
    let isSpanish: Bool
    
    var body: some View {
        HStack(spacing: 15) {
            // PDF thumbnail or icon
            if let pdfDocument = post.pdfDocument, let thumbnail = pdfDocument.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                    .cornerRadius(4)
            } else {
                Image(systemName: post.pdfReference != nil ? "doc.text.fill" : "doc.text")
                    .font(.system(size: 24))
                    .foregroundColor(post.pdfReference != nil ? .blue : .gray)
                    .frame(width: 40)
            }
            
            // Title and date info
            VStack(alignment: .leading, spacing: 4) {
                Text(post.title)
                    .font(.headline)
                    .lineLimit(1)
                
                if let pdfDoc = post.pdfDocument {
                    Text(pdfDoc.title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack {
                    // Original post date
                    Label(
                        formatDate(post.datePosted),
                        systemImage: "calendar"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    // Archive date
                    Label(
                        formatDate(post.archivedDate),
                        systemImage: "archivebox"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    // Link indicator
                    if post.linkURL != nil {
                        Label("", systemImage: "link")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
            
            // Archived indicator
            Text(isSpanish ? "Archivado" : "Archived")
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray)
                .cornerRadius(8)
        }
        .padding(.vertical, 8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Edit News Post View
struct EditNewsPostInfo {
    let title: String
    let scheduledDate: Date?
    let pdfRecord: CKRecord?
    let pdfURL: URL?
    let linkURL: String?  // Added link URL
}

struct EditNewsPostView: View {
    @Binding var isSpanish: Bool
    let post: NewsFeedPost
    let onSave: (EditNewsPostInfo) -> Void
    let onCancel: () -> Void
    
    @State private var title: String
    @State private var isScheduled: Bool
    @State private var scheduledDate: Date
    @State private var editLinkURL: String = ""  // New state variable for link URL
    @State private var selectedPDFRecord: CKRecord?
    @State private var selectedPDFURL: URL?
    @State private var selectedFileLabel: String = ""
    @State private var showPDFPicker: Bool = false
    
    init(isSpanish: Binding<Bool>, post: NewsFeedPost, onSave: @escaping (EditNewsPostInfo) -> Void, onCancel: @escaping () -> Void) {
        self._isSpanish = isSpanish
        self.post = post
        self.onSave = onSave
        self.onCancel = onCancel
        
        // Initialize state from post
        self._title = State(initialValue: post.title)
        self._isScheduled = State(initialValue: post.isScheduled)
        self._scheduledDate = State(initialValue: post.scheduledDate ?? Date().addingTimeInterval(3600))
        
        // If there's a PDF reference, we'd need to fetch it to set the selectedPDFRecord
        // This would normally be done in onAppear
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text(isSpanish ? "Editar Publicación" : "Edit Post")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .resizable()
                        .frame(width: 20, height: 20)
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Form content
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    // Title section
                    Group {
                        Text(isSpanish ? "Título:" : "Title:")
                            .font(.headline)
                        
                        TextField(isSpanish ? "Título de la publicación" : "Post title", text: $title)
                            .textFieldStyle(.roundedBorder)
                            .padding(.bottom, 10)
                    }
                    
                    // Scheduling section
                    Group {
                        Text(isSpanish ? "Programación:" : "Scheduling:")
                            .font(.headline)
                        
                        Toggle(isSpanish ? "Programar para una fecha futura" : "Schedule for future date", isOn: $isScheduled)
                            .padding(.bottom, 5)
                        
                        if isScheduled {
                            DatePicker(
                                isSpanish ? "Fecha de publicación:" : "Publication date:",
                                selection: $scheduledDate,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.compact)
                            .padding(.bottom, 10)
                        }
                    }
                    
                    // PDF section
                    Group {
                        Text(isSpanish ? "PDF Adjunto:" : "Attached PDF:")
                            .font(.headline)
                        
                        PDFSelectorView(
                            selectedPDFRecord: $selectedPDFRecord,
                            selectedPDFURL: $selectedPDFURL,
                            selectedFileLabel: $selectedFileLabel,
                            isSpanish: $isSpanish
                        )
                        .frame(height: 300)
                    }
                    
                    // Link URL field
                    Group {
                        Text(isSpanish ? "Enlace URL:" : "Link URL:")
                            .font(.headline)
                        
                        TextField(isSpanish ? "URL del sitio web (opcional)" : "Website URL (optional)", text: $editLinkURL)
                            .textFieldStyle(.roundedBorder)
                            .padding(.bottom, 10)
                    }
                }
                .padding()
            }
            
            // Action buttons
            HStack {
                Button(isSpanish ? "Cancelar" : "Cancel") {
                    print("📱 UI: Cancel button pressed in EditNewsPostView")
                    print("📱 UI: Calling onCancel() closure")
                    onCancel()
                    print("📱 UI: Cancel action completed")
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button(isSpanish ? "Guardar Cambios" : "Save Changes") {
                    let updatedPost = EditNewsPostInfo(
                        title: title,
                        scheduledDate: isScheduled ? scheduledDate : nil,
                        pdfRecord: selectedPDFRecord,
                        pdfURL: selectedPDFURL,
                        linkURL: editLinkURL.isEmpty ? nil : editLinkURL
                    )
                    onSave(updatedPost)
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            // Fetch the PDF record if there's a reference
            if let pdfRef = post.pdfReference {
                // This would fetch the record and set selectedPDFRecord
                loadPDFRecord(pdfRef)
            }
        }
    }
    
    private func loadPDFRecord(_ reference: CKRecord.Reference) {
        // Fetch the PDF record from CloudKit
        // This is a placeholder for the actual implementation
        let container = CKContainer(identifier: "iCloud.PearInc.EICT-iOS-16")
        let database = container.publicCloudDatabase
        
        database.fetch(withRecordID: reference.recordID) { record, error in
            if let record = record, error == nil {
                DispatchQueue.main.async {
                    self.selectedPDFRecord = record
                }
            }
        }
    }
}

// Add this new PDFKit view implementation with better controls
struct PDFKitRepresentedView: NSViewRepresentable {
    let document: PDFKit.PDFDocument
    var onCancel: () -> Void
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        print("📄 PDFKitRepresentedView: Creating new PDFView instance")
        
        // Configure PDFView before setting document
        pdfView.wantsLayer = true
        
        // Better visual debugging
        pdfView.layer?.borderWidth = 1.0
        pdfView.layer?.borderColor = NSColor.systemBlue.cgColor
        pdfView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        // Set explicit frame size - critical for initial rendering
        let initialFrame = NSRect(x: 0, y: 0, width: 800, height: 600)
        pdfView.frame = initialFrame
        print("📄 PDFKitRepresentedView: Set initial frame to \(initialFrame)")
        
        // Configure PDFView properties with better defaults
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage  // Changed to single page for better rendering
        pdfView.displayDirection = .vertical
        pdfView.displayBox = .cropBox
        pdfView.displaysPageBreaks = true
        pdfView.pageShadowsEnabled = true
        pdfView.maxScaleFactor = 5.0        // Increased max zoom
        pdfView.minScaleFactor = 0.1        // Allow more zoom out
        pdfView.backgroundColor = NSColor.textBackgroundColor
        pdfView.autoresizingMask = [.width, .height]
        pdfView.acceptsDraggedFiles = false // Disable dragging to avoid issues
        
        // Set document properties for debugging
        print("📄 PDFKitRepresentedView: PDF document details:")
        print("  - Page count: \(document.pageCount)")
        print("  - Document permissions allow printing: \(document.allowsPrinting)")
        print("  - Document permissions allow copying: \(document.allowsCopying)")
        
        // Check if document has proper metadata
        let documentAttributes = document.documentAttributes ?? [:]
        print("  - Document has \(documentAttributes.count) metadata attributes")
        if let title = documentAttributes[PDFDocumentAttribute.titleAttribute] as? String {
            print("  - Title: \(title)")
        }
        
        // Safely set document after configuration
        pdfView.document = document
        
        // Force layout
        pdfView.needsLayout = true
        pdfView.layoutSubtreeIfNeeded()
        
        // Go to first page and adjust scaling
        if document.pageCount > 0, let firstPage = document.page(at: 0) {
            pdfView.go(to: firstPage)
            
            // Get the page size and adjust scale factor intelligently
            let pageBounds = firstPage.bounds(for: .mediaBox)
            print("📄 PDFKitRepresentedView: First page size: \(pageBounds.width) x \(pageBounds.height)")
            
            // Calculate scale factors based on view vs page size
            let widthScaleFactor = pdfView.bounds.width / pageBounds.width
            let heightScaleFactor = pdfView.bounds.height / pageBounds.height
            let idealScaleFactor = min(widthScaleFactor, heightScaleFactor) * 0.95 // 95% to add margin
            
            print("📄 PDFKitRepresentedView: Ideal scale factor: \(idealScaleFactor)")
            print("📄 PDFKitRepresentedView: System scale factor: \(pdfView.scaleFactorForSizeToFit)")
            
            // Apply the better of the two scale factors
            if idealScaleFactor > 0 {
                pdfView.scaleFactor = min(idealScaleFactor, 2.0) // Cap at 2x
                print("📄 PDFKitRepresentedView: Applied custom scale factor: \(pdfView.scaleFactor)")
            } else {
                pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
                print("📄 PDFKitRepresentedView: Fallback to system scale factor: \(pdfView.scaleFactor)")
            }
            
            // Check if page has content
            if let pageString = firstPage.string, !pageString.isEmpty {
                print("📄 PDFKitRepresentedView: Page has text content (\(pageString.count) chars)")
            } else {
                print("📄 PDFKitRepresentedView: Page has no text content, might be scanned or image-based")
            }
        } else {
            print("⚠️ PDFKitRepresentedView: Document has no pages to display")
        }
        
        // Add a small delay to ensure everything is properly initialized and rendered
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Force refresh with proper scale
            pdfView.autoScales = true  // Reapply in case it didn't stick
            pdfView.needsDisplay = true
            
            // Verify final rendering state
            print("📄 PDFKitRepresentedView: Delayed refresh - final view bounds: \(pdfView.bounds)")
            print("📄 PDFKitRepresentedView: Delayed refresh - final scale factor: \(pdfView.scaleFactor)")
        }
        
        return pdfView
    }
    
    func updateNSView(_ pdfView: PDFView, context: Context) {
        print("📄 PDFKitRepresentedView: Updating PDFView")
        
        // Check document state before updating
        if pdfView.document === document {
            print("📄 PDFKitRepresentedView: Document reference unchanged, skipping document reset")
            return
        }
        
        // Check document validity
        guard document.pageCount > 0 else {
            print("⚠️ PDFKitRepresentedView: Update called with empty document")
            return
        }
        
        // Update document and reset view state
        pdfView.document = document
        
        // Document debug info
        print("📄 PDFKitRepresentedView: Updated to document with \(document.pageCount) pages")
        
        // Force layout update
        pdfView.needsLayout = true
        pdfView.layoutSubtreeIfNeeded()
        pdfView.needsDisplay = true
        
        // Ensure proper scaling
        if let page = pdfView.document?.page(at: 0) {
            pdfView.go(to: page)
            
            // Calculate optimal scale factor
            let pageBounds = page.bounds(for: .mediaBox)
            let widthScaleFactor = pdfView.bounds.width / pageBounds.width
            let heightScaleFactor = pdfView.bounds.height / pageBounds.height
            let idealScaleFactor = min(widthScaleFactor, heightScaleFactor) * 0.95
            
            if idealScaleFactor > 0 {
                pdfView.scaleFactor = min(idealScaleFactor, 2.0)
                print("📄 PDFKitRepresentedView: Update - custom scale factor: \(pdfView.scaleFactor)")
            } else {
                pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
                print("📄 PDFKitRepresentedView: Update - system scale factor: \(pdfView.scaleFactor)")
            }
            
            // Re-verify state after update
            print("📄 PDFKitRepresentedView: Update - view bounds: \(pdfView.bounds)")
            print("📄 PDFKitRepresentedView: Update - page bounds: \(pageBounds)")
        } else {
            print("⚠️ PDFKitRepresentedView: Update - document has no pages")
        }
    }
}

// MARK: - PDF Viewer Implementation
struct PDFViewerController: NSViewControllerRepresentable {
    let document: PDFKit.PDFDocument
    var onDismiss: () -> Void
    
    func makeNSViewController(context: Context) -> NSViewController {
        print("\n📄 PDFViewerController: Creating new controller instance")
        print("📄 PDFViewerController: Document details:")
        print("  - Page count: \(document.pageCount)")
        print("  - Document permissions: printing=\(document.allowsPrinting), copying=\(document.allowsCopying)")
        
        if document.pageCount > 0, let firstPage = document.page(at: 0) {
            let pageBounds = firstPage.bounds(for: .mediaBox)
            print("  - First page dimensions: \(pageBounds.width) x \(pageBounds.height)")
            print("  - First page rotation: \(firstPage.rotation)")
        }
        
        let controller = PDFViewController(document: document, onDismiss: onDismiss)
        return controller
    }
    
    func updateNSViewController(_ nsViewController: NSViewController, context: Context) {
        print("\n📄 PDFViewerController: Updating controller")
        print("📄 PDFViewerController: New document details:")
        print("  - Page count: \(document.pageCount)")
        
        if let pdfController = nsViewController as? PDFViewController {
            pdfController.document = document
            pdfController.updatePDFDocument()
        }
    }
    
    class PDFViewController: NSViewController {
        var document: PDFKit.PDFDocument
        var onDismiss: () -> Void
        var pdfView: PDFView!
        private var toolbar: NSView!
        private var loadingCounter = 0
        private var viewSetupComplete = false
        
        init(document: PDFKit.PDFDocument, onDismiss: @escaping () -> Void) {
            print("📄 PDFViewController: Initializing with document")
            self.document = document
            self.onDismiss = onDismiss
            super.init(nibName: nil, bundle: nil)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func loadView() {
            print("\n📄 PDFViewController: Loading view")
            print("📄 PDFViewController: Current view state:")
            print("  - View loaded: \(viewSetupComplete)")
            print("  - Document page count: \(document.pageCount)")
            
            // Create main container view with explicit size
            let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 900, height: 700))
            containerView.wantsLayer = true
            containerView.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
            print("📄 PDFViewController: Container view created with frame: \(containerView.frame)")
            
            // Create toolbar with fixed height
            toolbar = NSView(frame: NSRect(x: 0, y: containerView.bounds.height - 50, 
                                          width: containerView.bounds.width, height: 50))
            toolbar.wantsLayer = true
            toolbar.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
            toolbar.autoresizingMask = [.width, .minYMargin]
            containerView.addSubview(toolbar)
            print("📄 PDFViewController: Toolbar created with frame: \(toolbar.frame)")
            
            // Create PDF view with proper frame
            pdfView = PDFView(frame: NSRect(x: 0, y: 0, 
                                           width: containerView.bounds.width,
                                           height: containerView.bounds.height - 50))
            pdfView.autoresizingMask = [.width, .height]
            containerView.addSubview(pdfView)
            print("📄 PDFViewController: PDFView created with frame: \(pdfView.frame)")
            
            // Configure PDF view
            configurePDFView()
            
            // Add toolbar buttons
            addToolbarButtons()
            
            // Set as the view
            self.view = containerView
            viewSetupComplete = true
            
            print("📄 PDFViewController: View hierarchy setup complete")
            print("📄 PDFViewController: Final view frame: \(view.frame)")
        }
        
        private func configurePDFView() {
            print("\n📄 PDFViewController: Configuring PDFView")
            
            // Configure PDF view properties
            pdfView.wantsLayer = true
            pdfView.layer?.borderWidth = 1.0
            pdfView.layer?.borderColor = NSColor.systemBlue.cgColor
            
            // Set display properties
            pdfView.autoScales = true
            pdfView.displayMode = .singlePage
            pdfView.displayDirection = .vertical
            pdfView.backgroundColor = NSColor.textBackgroundColor
            pdfView.displaysPageBreaks = true
            pdfView.pageShadowsEnabled = true
            
            // Improved zoom settings
            pdfView.maxScaleFactor = 5.0
            pdfView.minScaleFactor = 0.1
            
            // Better interaction
            pdfView.acceptsDraggedFiles = false
            
            print("📄 PDFViewController: PDFView configured with:")
            print("  - Display mode: \(pdfView.displayMode.rawValue)")
            print("  - Auto scales: \(pdfView.autoScales)")
            print("  - Scale factor range: \(pdfView.minScaleFactor) to \(pdfView.maxScaleFactor)")
        }
        
        override func viewDidLoad() {
            super.viewDidLoad()
            print("\n📄 PDFViewController: View did load")
            print("📄 PDFViewController: View frame: \(view.frame)")
            print("📄 PDFViewController: PDFView frame: \(pdfView.frame)")
            
            // Configure the view and set up document
            configurePDFView()
            setupDocument()
        }
        
        override func viewDidAppear() {
            super.viewDidAppear()
            print("\n📄 PDFViewController: View did appear")
            print("📄 PDFViewController: View frame: \(view.frame)")
            print("📄 PDFViewController: PDFView frame: \(pdfView.frame)")
            
            // Now that the view is laid out, set up the document
            setupDocument()
        }
        
        private func setupDocument() {
            print("\n📄 PDFViewController: Setting up document")
            print("📄 PDFViewController: Current state:")
            print("  - View frame: \(view.frame)")
            print("  - PDFView frame: \(pdfView.frame)")
            print("  - Document page count: \(document.pageCount)")
            
            // Safety check
            if document.pageCount == 0 {
                print("⚠️ PDFViewController: Warning - Document has 0 pages")
                return
            }
            
            // Set document
            pdfView.document = document
            print("📄 PDFViewController: Document set on PDFView")
            
            // Navigate to first page and set scale
            if let page = document.page(at: 0) {
                pdfView.go(to: page)
                print("📄 PDFViewController: Navigated to first page")
                
                // Calculate optimal scale factor
                let pageBounds = page.bounds(for: .mediaBox)
                let viewBounds = pdfView.bounds
                
                print("📄 PDFViewController: Dimensions:")
                print("  - View size: \(viewBounds.width) x \(viewBounds.height)")
                print("  - Page size: \(pageBounds.width) x \(pageBounds.height)")
                
                let widthScaleFactor = viewBounds.width / pageBounds.width
                let heightScaleFactor = viewBounds.height / pageBounds.height
                let idealScaleFactor = min(widthScaleFactor, heightScaleFactor) * 0.95
                
                print("📄 PDFViewController: Scale calculations:")
                print("  - Width scale: \(widthScaleFactor)")
                print("  - Height scale: \(heightScaleFactor)")
                print("  - Ideal scale: \(idealScaleFactor)")
                
                if idealScaleFactor > 0 {
                    pdfView.scaleFactor = min(idealScaleFactor, 2.0)
                    print("📄 PDFViewController: Applied custom scale factor: \(pdfView.scaleFactor)")
                } else {
                    pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
                    print("📄 PDFViewController: Applied default scale factor: \(pdfView.scaleFactor)")
                }
                
                // Force layout
                pdfView.needsLayout = true
                pdfView.layoutSubtreeIfNeeded()
                pdfView.needsDisplay = true
                print("📄 PDFViewController: Forced layout update")
            }
        }
        
        private func refreshDocument() {
            loadingCounter += 1
            print("\n📄 PDFViewController: Refresh \(loadingCounter)")
            print("📄 PDFViewController: Current state:")
            print("  - View frame: \(view.frame)")
            print("  - PDFView frame: \(pdfView.frame)")
            print("  - Scale factor: \(pdfView.scaleFactor)")
            
            // Force layout
            pdfView.needsLayout = true
            pdfView.layoutSubtreeIfNeeded()
            pdfView.needsDisplay = true
            
            // Recheck scaling
            if let firstPage = document.page(at: 0) {
                let pageBounds = firstPage.bounds(for: .mediaBox)
                let viewBounds = pdfView.bounds
                print("📄 PDFViewController: Refresh dimensions:")
                print("  - View size: \(viewBounds.width) x \(viewBounds.height)")
                print("  - Page size: \(pageBounds.width) x \(pageBounds.height)")
                print("  - Current scale: \(pdfView.scaleFactor)")
            }
        }
        
        func updatePDFDocument() {
            print("\n📄 PDFViewController: Updating PDF document")
            print("📄 PDFViewController: Current state:")
            print("  - View frame: \(view.frame)")
            print("  - PDFView frame: \(pdfView.frame)")
            print("  - Document page count: \(document.pageCount)")
            
            // Safety check
            if document.pageCount == 0 {
                print("⚠️ PDFViewController: Warning - Document has 0 pages")
                return
            }
            
            // Set document
            pdfView.document = document
            print("📄 PDFViewController: Document updated on PDFView")
            
            // Navigate to first page
            if let page = document.page(at: 0) {
                pdfView.go(to: page)
                print("📄 PDFViewController: Navigated to first page")
                
                // Calculate optimal scale factor
                let pageBounds = page.bounds(for: .mediaBox)
                let viewBounds = pdfView.bounds
                
                print("📄 PDFViewController: Update dimensions:")
                print("  - View size: \(viewBounds.width) x \(viewBounds.height)")
                print("  - Page size: \(pageBounds.width) x \(pageBounds.height)")
                
                let widthScaleFactor = viewBounds.width / pageBounds.width
                let heightScaleFactor = viewBounds.height / pageBounds.height
                let idealScaleFactor = min(widthScaleFactor, heightScaleFactor) * 0.95
                
                print("📄 PDFViewController: Update scale calculations:")
                print("  - Width scale: \(widthScaleFactor)")
                print("  - Height scale: \(heightScaleFactor)")
                print("  - Ideal scale: \(idealScaleFactor)")
                
                if idealScaleFactor > 0 {
                    pdfView.scaleFactor = min(idealScaleFactor, 2.0)
                    print("📄 PDFViewController: Applied custom scale factor: \(pdfView.scaleFactor)")
                } else {
                    pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
                    print("📄 PDFViewController: Applied default scale factor: \(pdfView.scaleFactor)")
                }
                
                // Force layout
                pdfView.needsLayout = true
                pdfView.layoutSubtreeIfNeeded()
                pdfView.needsDisplay = true
                print("📄 PDFViewController: Forced layout update")
            }
        }
        
        private func addToolbarButtons() {
            // Close button
            let closeButton = NSButton(title: "Close", target: self, action: #selector(closeButtonTapped))
            closeButton.bezelStyle = .rounded
            closeButton.frame = NSRect(x: toolbar.bounds.width - 80, y: 10, width: 70, height: 30) // Adjusted y position
            closeButton.autoresizingMask = [.minXMargin] // Removed .centerYMargin
            toolbar.addSubview(closeButton)
            
            // ---> MODIFY ZOOM BUTTONS <---
            // Zoom In button (Use Image)
            let zoomInButton = NSButton(image: NSImage(systemSymbolName: "plus.magnifyingglass", accessibilityDescription: "Zoom In")!, target: self, action: #selector(zoomIn))
            zoomInButton.bezelStyle = .regularSquare // Changed bezel style
            zoomInButton.isBordered = false // Make it look like a symbol button
            zoomInButton.frame = NSRect(x: 10, y: 10, width: 30, height: 30) // Adjusted frame
            zoomInButton.autoresizingMask = [.maxXMargin] // Removed .centerYMargin
            toolbar.addSubview(zoomInButton)
            
            // Zoom Out button (Use Image)
            let zoomOutButton = NSButton(image: NSImage(systemSymbolName: "minus.magnifyingglass", accessibilityDescription: "Zoom Out")!, target: self, action: #selector(zoomOut))
            zoomOutButton.bezelStyle = .regularSquare // Changed bezel style
            zoomOutButton.isBordered = false // Make it look like a symbol button
            zoomOutButton.frame = NSRect(x: 50, y: 10, width: 30, height: 30) // Position next to zoom in
            zoomOutButton.autoresizingMask = [.maxXMargin] // Removed .centerYMargin
            toolbar.addSubview(zoomOutButton)
            
            // Remove the Fit button
            /*
            let fitToViewButton = NSButton(title: "Fit", target: self, action: #selector(fitToView))
            fitToViewButton.bezelStyle = .rounded
            fitToViewButton.frame = NSRect(x: 170, y: 10, width: 50, height: 30) // Adjusted y position
            fitToViewButton.autoresizingMask = [.maxXMargin, .centerYMargin]
            toolbar.addSubview(fitToViewButton)
            */
            // ---> END MODIFICATION <---
        }
        
        @objc private func closeButtonTapped() {
            print("📄 PDFViewController: Close button tapped")
            onDismiss()
        }
        
        @objc private func zoomIn() {
            guard pdfView != nil else { return } // Changed from pdfView?
            pdfView.scaleFactor = min(pdfView.scaleFactor * 1.25, pdfView.maxScaleFactor)
            print("📄 PDFViewController: Zoomed in to \(pdfView.scaleFactor)")
        }
        
        @objc private func zoomOut() {
            guard pdfView != nil else { return } // Changed from pdfView?
            // Ensure minScaleFactor is set before zooming out
             if pdfView.minScaleFactor == 0 { // Check if not explicitly set
                 pdfView.minScaleFactor = pdfView.scaleFactorForSizeToFit * 0.5 // Allow zoom out to 50% of fit
             }
            pdfView.scaleFactor = max(pdfView.scaleFactor / 1.25, pdfView.minScaleFactor)
            print("📄 PDFViewController: Zoomed out to \(pdfView.scaleFactor)")
        }
        
        // Remove the fitToView action as the button is removed
        /*
        @objc private func fitToView() {
            pdfView?.scaleFactor = pdfView.scaleFactorForSizeToFit
            print("📄 PDFViewController: Fit to view with scale \(pdfView.scaleFactor)")
        }
        */
    }
}

// MARK: - Preview
struct NewsFeedManagementView_Previews: PreviewProvider {
    static var previews: some View {
        NewsFeedManagementView(isSpanish: .constant(false))
    }
} 