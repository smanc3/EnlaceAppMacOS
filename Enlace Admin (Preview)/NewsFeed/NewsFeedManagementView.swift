//
//  NewsFeedManagementView.swift
//  Enlace Admin (Preview)
//
//  Created on 5/10/25.
//

import SwiftUI
import CloudKit
import PDFKit
import Combine
import AppKit

// MARK: - Notification Manager
class NotificationManager {
    static let shared = NotificationManager()
    private var lastNotificationTime: [String: Date] = [:]
    private let minimumInterval: TimeInterval = 2.0 // 2 seconds between identical notifications
    
    private init() {}
    
    func postNotification(name: Notification.Name, object: Any? = nil, userInfo: [AnyHashable: Any]? = nil) {
        let notificationKey = name.rawValue
        let now = Date()
        
        // Check if we've sent this notification recently
        if let lastTime = lastNotificationTime[notificationKey], 
           now.timeIntervalSince(lastTime) < minimumInterval {
            print("🔔 NotificationManager: Skipping duplicate notification '\(name.rawValue)' (last sent \(now.timeIntervalSince(lastTime))s ago)")
            return
        }
        
        // Send the notification and update the timestamp
        print("🔔 NotificationManager: Posting notification '\(name.rawValue)'")
        NotificationCenter.default.post(name: name, object: object, userInfo: userInfo)
        lastNotificationTime[notificationKey] = now
    }
    
    // Helper for the common news feed refresh notification
    func postNewsFeedRefresh() {
        postNotification(name: Notification.Name("NewsFeedRefreshNotification"))
    }
}

// MARK: - News Feed Post Model
class NewsFeedPost: ObservableObject, Identifiable, Hashable {
    let id: CKRecord.ID
    @Published var title: String  // Make title mutable and published
    let datePosted: Date
    let scheduledDate: Date?
    let pdfReference: CKRecord.Reference?
    let record: CKRecord
    let recordNameMirror: String
    @Published var linkURL: URL?  // Make linkURL mutable and published
    let notes: String?
    let location: String?
    @Published var content: String?  // Make content mutable and published
    @Published var pdfDocument: PDFDocumentDetails?
    
    // Add Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id.recordName)
    }
    
    static func == (lhs: NewsFeedPost, rhs: NewsFeedPost) -> Bool {
        return lhs.id.recordName == rhs.id.recordName
    }
    
    init(record: CKRecord) {
        print("🛠️ NewsFeedPost CKRecord fields for recordID \(record.recordID.recordName):")
        for key in record.getAllKeys() {
            print("🛠️   Field: \(key) = \(String(describing: record[key]))")
        }
        self.id = record.recordID
        self.record = record
        self.title = record["title"] as? String ?? "Untitled"
        self.datePosted = record["datePosted"] as? Date ?? Date()
        self.scheduledDate = record["scheduledDate"] as? Date
        self.pdfReference = record["pdfReference"] as? CKRecord.Reference
        self.recordNameMirror = record["recordNameMirror"] as? String ?? record.recordID.recordName
        self.linkURL = (record["linkURL"] as? String).flatMap { URL(string: $0) }
        self.notes = record["notes"] as? String
        self.location = record["location"] as? String
        self.content = record["content"] as? String
        self.pdfDocument = nil // Will be populated later if reference exists
    }
    
    var isScheduled: Bool {
        guard let scheduled = scheduledDate else { return false }
        return scheduled > Date()
    }
    
    // Add method to update the record
    func updateRecord() {
        record["title"] = title
        if let linkURL = linkURL {
            record["linkURL"] = linkURL.absoluteString
        } else {
            record["linkURL"] = nil
        }
        if let content = content {
            record["content"] = content
        } else {
            record["content"] = nil
        }
    }
}

// MARK: - Archived News Post Model
struct ArchivedNewsPost: Identifiable {
    let id: CKRecord.ID
    let title: String
    let datePosted: Date
    let archivedDate: Date // This will now be set to the datePosted as a fallback
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
        
        // Use datePosted as a fallback for archivedDate since the field doesn't exist
        if let archivedDate = record["archivedDate"] as? Date {
            self.archivedDate = archivedDate
        } else {
            // Use datePosted as fallback when archivedDate doesn't exist
            self.archivedDate = self.datePosted
            print("📰 ArchivedNewsPost: Using datePosted as fallback for missing archivedDate field")
        }
        
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
struct PDFDocumentDetails: Identifiable, Hashable { // Conform to Identifiable and Hashable
    let id: CKRecord.ID
    let title: String
    let dateUploaded: Date
    let fileURL: URL?
    let record: CKRecord
    var thumbnail: NSImage?
    
    // Add Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id.recordName)
    }
    
    static func == (lhs: PDFDocumentDetails, rhs: PDFDocumentDetails) -> Bool {
        return lhs.id.recordName == rhs.id.recordName
    }
    
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
    
    // State
    @State private var posts: [NewsFeedPost] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showError = false
    @State private var showAddSheet = false
    @State private var showPDFPicker = false
    @State private var showLinkInput = false
    @State private var showPDFPreview = false
    @State private var showPDFLoadError = false
    @State private var pdfLoadError: String? = nil
    @State private var pdfLoadErrorForDetail: String? = nil
    @State private var refreshTrigger = false  // Add this for refresh functionality
    @State private var sortOption: SortOption = .dateNewest  // Add this for sorting functionality
    @State private var lastRefreshTime: Date = Date(timeIntervalSince1970: 0) // Track last refresh time for debouncing
    @State private var errorTitle: String = "" // Add this property to store error title
    
    @EnvironmentObject var languageManager: LanguageManager
    
    // SIMPLIFIED ALERT SYSTEM - use only one approach with Boolean flags
    @State private var showDeleteAlert = false
    @State private var showArchiveAlert = false
    @State private var postToAction: NewsFeedPost? = nil
    @State private var showArchiveSuccess: Bool = false
    @State private var archiveSuccessMessage: String = ""
    
    // Remove the complex alert enums and other redundant alert state
    
    private let container = CKContainer(identifier: "iCloud.PearInc.EICT-iOS-16")
    private var database: CKDatabase {
        print("🛠️ [DEBUG] Using CloudKit container: \(container.containerIdentifier ?? "unknown")")
        print("🛠️ [DEBUG] Using database: \(container.publicCloudDatabase)")
        return container.publicCloudDatabase
    }
    
    // This container is used for *loading* posts, which might be from a shared/older source
    private let sourceDataContainer = CKContainer(identifier: "iCloud.PearInc.EICT-iOS-16")
    private var sourceDatabase: CKDatabase {
        return sourceDataContainer.publicCloudDatabase
    }
    
    // This container is for *saving/archiving* data specific to this Admin (Preview) app
    private let targetAdminContainerIdentifier = "iCloud.PearInc.EICT-iOS-16"
    private var targetAdminContainer: CKContainer {
        return CKContainer(identifier: targetAdminContainerIdentifier)
    }
    private var targetAdminPrivateDB: CKDatabase {
        return targetAdminContainer.publicCloudDatabase
    }
    
    // Filtered posts based on search
    private var filteredPosts: [NewsFeedPost] {
        // Filter by search text and isArchived
        let nonArchived = posts.filter { post in
            if let isArchived = post.record["isArchived"] as? Int {
                return isArchived != 1
            }
            // Default: treat as not archived if field missing
            return true
        }
        print("🛠️ [DEBUG] Filtered non-archived posts: \(nonArchived.count) of \(posts.count)")
        let filtered: [NewsFeedPost]
        if searchText.isEmpty {
            filtered = sortPosts(nonArchived)
        } else {
            filtered = sortPosts(nonArchived.filter { $0.title.localizedCaseInsensitiveContains(searchText) })
            }
        print("🛠️ [DEBUG] Filtered posts after search: \(filtered.count)")
        return filtered
    }
    
    // Additional state
    @State private var showingPDFViewer = false
    @State private var currentPDFDocument: PDFKit.PDFDocument? = nil
    @State private var pdfDetailsToShow: PDFDocumentDetails? = nil // New state for .sheet(item:)
    
    // Archived posts storage
    @State private var archivedPosts: [ArchivedNewsPost] = []
    
    // 1. Change selectedPostID to String?
    @State private var selectedPostID: String? = nil
    
    // 2. Update selectedPost computed property
    private var selectedPost: NewsFeedPost? {
        posts.first(where: { $0.id.recordName == selectedPostID })
    }
    
    enum SortOption: String, CaseIterable, Identifiable {
        case dateNewest = "Date Newest"
        case title = "Title"
        
        var id: String { self.rawValue }
        
        var localizedName: String {
            switch self {
            case .dateNewest: return NSLocalizedString("Date Newest", comment: "")
            case .title: return NSLocalizedString("Title", comment: "")
            }
        }
    }
    
    @State private var searchText: String = ""
    @State private var isEditing = false
    @State private var editTitle = ""
    @State private var editLinkURL = ""  // New state for link URL
    @State private var selectedPDFRecord: CKRecord? = nil
    @State private var selectedPDFURL: URL? = nil
    @State private var selectedFileLabel = ""
    
    var body: some View {
        VStack(spacing: 0) {
            header
            HStack(spacing: 0) {
                listPanel
                Divider()
                detailPanel
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            print("🖼️ News Management View appeared")
            loadPosts()
            
            // Debug info 
            print("🛠️ [DEBUG] Using simplified alert system")
        }
        // Only keep the error alert
        .alert(isPresented: $showError) {
            Alert(
                title: Text(errorTitle),
                message: Text(errorMessage ?? ""),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(item: $pdfDetailsToShow) { (details: PDFDocumentDetails) in
            // Present a lightweight wrapper that asynchronously loads the PDF on a background queue
            PDFViewerSheet(details: details, dismissAction: {
                pdfDetailsToShow = nil
            })
        }
        .onAppear {
            // Add notification observer for when items are unarchived
            NotificationCenter.default.addObserver(
                forName: Notification.Name("NewsFeedRefreshNotification"),
                object: nil,
                queue: .main
            ) { _ in
                print("📰 NewsFeed: Received notification of unarchived post, refreshing...")
                
                // Debounce refresh operations - only refresh if it's been at least 1 second since the last refresh
                let now = Date()
                if now.timeIntervalSince(self.lastRefreshTime) > 1.0 {
                    self.lastRefreshTime = now
                    self.loadPosts()
                    self.loadArchivedPosts()
                    print("📰 NewsFeed: Refresh executed. Debounce active until \(self.lastRefreshTime.addingTimeInterval(1.0))")
                } else {
                    print("📰 NewsFeed: Refresh skipped due to debounce. Last refresh at \(self.lastRefreshTime)")
                }
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
    
    private var header: some View {
        VStack(spacing: 0) {
            // Title and refresh button row
            HStack {
                Text(isSpanish ? "News Management" : "News Management")
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
                Button(action: {
                        loadPosts()
                }) {
                    Label(isSpanish ? "Actualizar" : "Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
            }
            .padding(.horizontal)
            .padding(.top)
            .padding(.bottom, 4)
            .background(Color(NSColor.controlBackgroundColor))

            // Search and sort row
            HStack {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField(isSpanish ? "Buscar por título..." : "Search by title...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.trailing)
                
                // Sort picker
                Picker(isSpanish ? "Ordenar" : "Sort", selection: $sortOption) {
                    ForEach(SortOption.allCases, id: \.self) { option in
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
        }
    }

    private var contentPanels: some View {
        HStack(spacing: 0) {
            listPanel
            Divider()
            detailPanel
        }
        .frame(minWidth: 800, maxWidth: 1200, minHeight: 500, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var listPanel: some View {
        VStack(spacing: 0) {
            // List of posts
            ZStack {
                List(selection: $selectedPostID) {
            if isLoading {
                loadingView(message: isSpanish ? "Cargando noticias..." : "Loading news...")
            } else if let error = errorMessage {
                errorView(error: error, retryAction: loadPosts)
            } else if posts.isEmpty {
                        EmptyNewsListView(isSpanish: isSpanish)
            } else {
                        ForEach(filteredPosts, id: \ .id) { post in
                                NewsPostRow(
                                    post: post,
                                    isSpanish: isSpanish,
                                    onEdit: { editPost(post) },
                                    onArchive: { 
                                        print("📰 Archive button tapped for post: \(post.title)")
                                        triggerArchiveAlert(for: post)
                                    },
                                    onDelete: { 
                                        print("📰 Delete button tapped for post: \(post.title) with ID: \(post.id.recordName)")
                                        triggerDeleteAlert(for: post)
                                    }
                                )
                            .tag(post.id.recordName)
                                .contentShape(Rectangle())
                            .background(selectedPostID == post.id.recordName ? Color.blue.opacity(0.1) : Color.clear)
                                .onTapGesture {
                                selectedPostID = post.id.recordName
                                isEditing = false
                            }
                        }
                            }
                        }
                        .listStyle(.inset)
            }
        }
        .frame(minWidth: 300, maxWidth: 300)
        .background(Color(NSColor.textBackgroundColor))
    }

    private var detailPanel: some View {
        Group {
            if let post = selectedPost {
                if isEditing {
        VStack {
                        EditPostForm(
                            post: post,
                            onSave: {
                                print("🛠️ [DEBUG] Edit saved for post: \(post.title) – initiating CloudKit save")
                                saveEditedPost(post)
                            },
                            onCancel: {
                                print("🛠️ [DEBUG] Edit cancelled for post: \(post.title)")
                                isEditing = false
                            }
                        )
            Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(NSColor.controlBackgroundColor))
                } else {
                    selectedPostDetailView(post: post)
                }
            } else {
        VStack {
            Spacer()
            Image(systemName: "arrow.left.circle")
                        .font(.system(size: 48))
                .foregroundColor(.gray)
                    Text(isSpanish ? "Selecciona una noticia para ver detalles" : "Select a post to view details")
                .font(.headline)
                .foregroundColor(.secondary)
                        .padding()
            Spacer()
        }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .layoutPriority(1)
    }

    // Add EditPostForm struct
    private struct EditPostForm: View {
        @ObservedObject var post: NewsFeedPost
        @State private var editedTitle: String
        @State private var editedLinkURL: String
        @State private var editedContent: String
        let onSave: () -> Void
        let onCancel: () -> Void
        
        init(post: NewsFeedPost, onSave: @escaping () -> Void, onCancel: @escaping () -> Void) {
            self.post = post
            self._editedTitle = State(initialValue: post.title)
            self._editedLinkURL = State(initialValue: post.linkURL?.absoluteString ?? "")
            self._editedContent = State(initialValue: post.content ?? "")
            self.onSave = onSave
            self.onCancel = onCancel
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text("Edit News Post")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.bottom, 8)
                
                Text("Title")
                    .fontWeight(.semibold)
                TextField("Enter title", text: $editedTitle)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: 400)
                
                Text("Link URL")
                    .fontWeight(.semibold)
                TextField("Enter link (optional)", text: $editedLinkURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: 400)
                
                Text("Description")
                    .fontWeight(.semibold)
                TextEditor(text: $editedContent)
                    .frame(height: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .frame(maxWidth: 600)
                
                        HStack {
                    Spacer()
                    Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)
                    Button("Save") {
                        // Update local changes
                        post.title = editedTitle
                        post.linkURL = URL(string: editedLinkURL)
                        post.content = editedContent.isEmpty ? nil : editedContent
                        post.updateRecord()
                        // Persist to CloudKit via parent view helper
                        onSave()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top, 8)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
    }

    // Add the selectedPostDetailView method
    private func selectedPostDetailView(post: NewsFeedPost) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 20) {
                // Title and date
                VStack(alignment: .leading, spacing: 8) {
                    Text(post.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Posted: " + DateFormatter.localizedString(from: post.datePosted, dateStyle: .short, timeStyle: .short))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // PDF preview if available
                if let pdfDoc = post.pdfDocument {
                Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PDF Document")
                            .font(.headline)
                        if let thumbnail = pdfDoc.thumbnail {
                                Image(nsImage: thumbnail)
                                    .resizable()
                                .scaledToFit()
                                .frame(height: 200)
                                .cornerRadius(8)
                                .onTapGesture {
                                    pdfDetailsToShow = pdfDoc
                                }
                        }
                        Button(action: { pdfDetailsToShow = pdfDoc }) {
                            Label("View PDF", systemImage: "doc.richtext")
                            }
                            .buttonStyle(.bordered)
                    }
                }
                
                // Link if available
                if let link = post.linkURL {
                    let urlString = link.absoluteString
                    let safeURLString = (urlString.lowercased().hasPrefix("http://") || urlString.lowercased().hasPrefix("https://")) ? urlString : "https://" + urlString
                    let safeURL = URL(string: safeURLString)
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Link")
                            .font(.headline)
                        if let safeURL = safeURL {
                            Link(urlString, destination: safeURL)
                                .foregroundColor(.blue)
            } else {
                            Text(urlString)
                                .foregroundColor(.red)
                        }
                    }
                }

                // Description if available
                if let content = post.content, !content.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                        .font(.headline)
                        Text(content)
                            .font(.body)
                    }
                }
                
                // Notes if available
                if let notes = post.notes, !notes.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                        .font(.headline)
                        Text(notes)
                            .font(.body)
                                    .foregroundColor(.secondary)
                    }
                }
                
                // Location if available
                if let location = post.location, !location.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location")
                        .font(.headline)
                        Text(location)
                            .font(.body)
                                .foregroundColor(.secondary)
                        }
                }

                Spacer()
            }
            .padding()
        }
    }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            header
            Divider()
            contentPanels
        }
        .frame(minWidth: 800, maxWidth: 1200, minHeight: 500, maxHeight: .infinity)
        .cornerRadius(16)
        .shadow(radius: 8)
        .onAppear {
            print("📰 NewsFeedManagementView appeared")
            setupNotifications()
            loadPosts()
        }
        .onDisappear {
            print("📰 NewsFeedManagementView disappeared")
            removeNotifications()
        }
        .onChange(of: refreshTrigger) { newValue in
            loadPosts()
        }
    }
    
    // MARK: - Methods
    
    private func loadPosts() {
        debugLog("Called")
        isLoading = true
        errorMessage = nil
        // Only fetch non-archived posts and only those scheduled for now or earlier
        let now = Date()
        let predicate = NSPredicate(format: "isArchived != 1 AND scheduledDate <= %@", now as NSDate)
        debugLog("Query predicate: \(predicate)")
        let query = CKQuery(recordType: "NewsFeedItem", predicate: predicate)
        
        // CRITICAL FIX: Use two explicit sort descriptors - primary on scheduledDate and secondary on recordNameMirror
        // This prevents CloudKit from ever trying to sort by recordName (which is not queryable)
        query.sortDescriptors = [
            NSSortDescriptor(key: "scheduledDate", ascending: false),
            NSSortDescriptor(key: "recordNameMirror", ascending: true) // Secondary sort on a field we know is queryable
        ]
        
        debugLog("About to fetch NewsFeedItem records")
        debugLog("Query recordType: \(query.recordType)")
        debugLog("Query predicate: \(predicate)")
        debugLog("Query sortDescriptors: \(query.sortDescriptors ?? [])")
        debugLog("Query sort keys: \(query.sortDescriptors?.map { $0.key ?? "<nil>" } ?? [])")
        
        // Log schema fields
        let schemaRecord = CKRecord(recordType: "NewsFeedItem")
        let allKeys = schemaRecord.getAllKeys()
        debugLog("NewsFeedItem schema fields: \(allKeys)")
        
        // ENHANCED APPROACH: Use CKQueryOperation for more control
        let operation = CKQueryOperation(query: query)
        operation.desiredKeys = ["title", "content", "datePosted", "datePublished", "scheduledDate", "pdfReference", "recordNameMirror", "linkURL", "notes", "location", "isArchived"]
        
        var fetchedRecords: [CKRecord] = []
        
        operation.recordMatchedBlock = { (recordID, result) in
                            switch result {
            case .success(let record):
                self.debugLog("[MAIN FETCH] Got record: \(record.recordID.recordName)")
                fetchedRecords.append(record)
                            case .failure(let error):
                self.debugLog("[MAIN FETCH] Failed to get record: \(error)")
            }
        }
        
        operation.queryResultBlock = { result in
            DispatchQueue.main.async {
                    self.isLoading = false
            
            switch result {
            case .success:
                    self.debugLog("[MAIN FETCH] Success: \(fetchedRecords.count) records fetched")
                    
                    // Process the records
                    let posts = fetchedRecords.compactMap { NewsFeedPost(record: $0) }
                    
                    self.posts = posts
                    
                    if !posts.isEmpty {
                        self.debugLog("[MAIN FETCH] All records fetched")
                        // Debug log for each record's ID and isArchived value
                        for post in posts {
                            let isArchivedValue = post.record["isArchived"]
                            self.debugLog("[DEBUG] Fetched post: \(post.id.recordName), isArchived: \(String(describing: isArchivedValue))")
                }
            } else {
                        self.debugLog("[MAIN FETCH] No posts found")
                    }
                    
                    // Fetch PDF thumbnails for posts with pdfReference
                    for (index, post) in self.posts.enumerated() {
            if let pdfRef = post.pdfReference {
                            database.fetch(withRecordID: pdfRef.recordID) { record, error in
                                if let record = record {
                                    let pdfDoc = PDFDocumentDetails(record: record)
                                    DispatchQueue.main.async {
                                        // Update the post's pdfDocument property
                                        self.posts[index].pdfDocument = pdfDoc
                                        self.debugLog("[THUMBNAIL] Loaded thumbnail for post: \(post.title)")
                                    }
                                } else if let error = error {
                                    self.debugLog("[THUMBNAIL] Error fetching PDFDocumentItem: \(error.localizedDescription)")
                                }
                            }
                        }
                    }
                    
                case .failure(let error):
                    self.errorMessage = "Error loading posts: \(error.localizedDescription)"
                    self.debugLog("loadPosts error: \(error)")
                    
                    if let ckError = error as? CKError {
                        self.debugLog("CKError code: \(ckError.code.rawValue)")
                        self.debugLog("CKError userInfo: \(ckError.userInfo)")
                    }
                    
                    self.debugLog("Call stack: \(Thread.callStackSymbols.joined(separator: "\n"))")
                }
            }
        }
        
        // Run the operation
        database.add(operation)
        
        // Pre-check can use the same improved approach
        let checkQuery = CKQuery(recordType: "NewsFeedItem", predicate: NSPredicate(value: true))
        checkQuery.sortDescriptors = [
            NSSortDescriptor(key: "scheduledDate", ascending: false),
            NSSortDescriptor(key: "recordNameMirror", ascending: true)
        ]
        
        let checkOperation = CKQueryOperation(query: checkQuery)
        checkOperation.desiredKeys = ["scheduledDate"] // Only need this field for pre-check
        
        var recordsWithoutScheduledDate: [String] = []
        
        checkOperation.recordMatchedBlock = { (recordID, result) in
                            switch result {
            case .success(let record):
                if record["scheduledDate"] == nil {
                    recordsWithoutScheduledDate.append(record.recordID.recordName)
                }
            case .failure:
                // Skip failed records for pre-check
                break
            }
        }
        
        checkOperation.queryResultBlock = { result in
            switch result {
            case .success:
                if !recordsWithoutScheduledDate.isEmpty {
                    self.debugLog("[CRITICAL] PRE-CHECK FOUND \(recordsWithoutScheduledDate.count) NewsFeedItem RECORDS MISSING 'scheduledDate': \(recordsWithoutScheduledDate)")
                    self.debugLog("[CRITICAL] This is THE MOST LIKELY CAUSE of the 'Field recordName is not marked queryable' error.")
                    self.debugLog("[CRITICAL] A data migration is needed to set 'scheduledDate' for these records.")
                } else {
                    self.debugLog("[PRE-CHECK] PASSED: All checked records have 'scheduledDate' set.")
                }
                
            case .failure(let error):
                self.debugLog("[PRE-CHECK] FAILED: Could not fetch records to check for missing 'scheduledDate': \(error.localizedDescription)")
            }
        }
        
        database.add(checkOperation)
    }
    
    private func loadArchivedPosts() {
        debugLog("Loading archived posts")
        
        // Only fetch archived posts
        let predicate = NSPredicate(format: "isArchived == 1")
        debugLog("Archived query predicate: \(predicate)")
        let query = CKQuery(recordType: "NewsFeedItem", predicate: predicate)
        
        // Use the same sort descriptors for consistency
        query.sortDescriptors = [
            NSSortDescriptor(key: "scheduledDate", ascending: false),
            NSSortDescriptor(key: "recordNameMirror", ascending: true)
        ]
        
        debugLog("About to fetch archived NewsFeedItem records")
        
        // Use operation for better control
        let operation = CKQueryOperation(query: query)
        operation.desiredKeys = ["title", "datePosted", "archivedDate", "scheduledDate", "pdfReference", "recordNameMirror", "linkURL"]
        
        var fetchedRecords: [CKRecord] = []
        
        operation.recordMatchedBlock = { (recordID, result) in
            switch result {
            case .success(let record):
                self.debugLog("[ARCHIVE FETCH] Got archived record: \(record.recordID.recordName)")
                fetchedRecords.append(record)
            case .failure(let error):
                self.debugLog("[ARCHIVE FETCH] Failed to get archived record: \(error)")
            }
        }
        
        operation.queryResultBlock = { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.debugLog("[ARCHIVE FETCH] Success: \(fetchedRecords.count) archived records fetched")
                    
                    // Process the records
                    let archivedPosts = fetchedRecords.compactMap { ArchivedNewsPost(record: $0) }
                    self.archivedPosts = archivedPosts
                    
                    if !archivedPosts.isEmpty {
                        self.debugLog("[ARCHIVE FETCH] All archived records fetched")
                        // Debug log for each archived record
                        for post in archivedPosts {
                            self.debugLog("[DEBUG] Fetched archived post: \(post.id.recordName)")
                        }
                        
                        // Fetch PDF thumbnails for archived posts with pdfReference
                        for (index, post) in self.archivedPosts.enumerated() {
                            if let pdfRef = post.pdfReference {
                                self.database.fetch(withRecordID: pdfRef.recordID) { record, error in
                                    if let record = record {
                                        let pdfDoc = PDFDocumentDetails(record: record)
                DispatchQueue.main.async {
                                            // Update the post's pdfDocument property
                                            self.archivedPosts[index].pdfDocument = pdfDoc
                                            self.debugLog("[THUMBNAIL] Loaded thumbnail for archived post: \(post.title)")
                                        }
                                    } else if let error = error {
                                        self.debugLog("[THUMBNAIL] Error fetching PDFDocumentItem for archived post: \(error.localizedDescription)")
                                    }
                                }
                            }
                        }
                    } else {
                        self.debugLog("[ARCHIVE FETCH] No archived posts found")
                    }
                    
                case .failure(let error):
                    self.debugLog("[ARCHIVE FETCH] Error loading archived posts: \(error.localizedDescription)")
                    
                    if let ckError = error as? CKError {
                        self.debugLog("[ARCHIVE FETCH] CKError code: \(ckError.code.rawValue)")
                        self.debugLog("[ARCHIVE FETCH] CKError userInfo: \(ckError.userInfo)")
                    }
                }
            }
        }
        
        // Run the operation
        database.add(operation)
    }
    
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
            if let pdfURL = selectedPDFURL {
                // User selected a new PDF file, upload it first
                let pdfRecord = CKRecord(recordType: "PDFDocumentItem")
                pdfRecord["title"] = selectedFileLabel
                pdfRecord["dateUploaded"] = Date()
                pdfRecord["recordNameMirror"] = pdfRecord.recordID.recordName
                pdfRecord["isArchived"] = 0
                let pdfAsset = CKAsset(fileURL: pdfURL)
                pdfRecord["pdfFile"] = pdfAsset
                database.save(pdfRecord) { (savedRecord, error) in
                    if let error = error {
            DispatchQueue.main.async {
                            self.isLoading = false
                            self.errorMessage = "Error saving PDF: \(error.localizedDescription)"
            }
                        print("📰 ❌ [\(Date())] Error saving PDF: \(error.localizedDescription)")
            return
        }
                    guard let savedRecord = savedRecord else {
            DispatchQueue.main.async {
                            self.isLoading = false
                            self.errorMessage = "Failed to save PDF document"
                        }
                        print("📰 ❌ [\(Date())] Failed to save PDF document: nil record returned")
                        return
                    }
                    print("📰 [\(Date())] Successfully saved PDF record: \(savedRecord.recordID.recordName)")
                    let updatedPost = EditNewsPostInfo(
                        title: editTitle,
                        scheduledDate: nil,
                        pdfRecord: savedRecord,
                        pdfURL: nil,
                        linkURL: editLinkURL.isEmpty ? nil : editLinkURL
                    )
                    updatePost(originalPost: post, updatedPost: updatedPost)
                }
            } else {
                // No new PDF file, use selectedPDFRecord
                    let updatedPost = EditNewsPostInfo(
                    title: editTitle,
                    scheduledDate: nil,
                    pdfRecord: selectedPDFRecord,
                    pdfURL: nil,
                    linkURL: editLinkURL.isEmpty ? nil : editLinkURL
                )
                updatePost(originalPost: post, updatedPost: updatedPost)
            }
        } else {
            // Create new post
            createNewPost(
                title: editTitle,
                scheduledDate: nil, // Always set to nil now that we removed scheduling
                        pdfRecord: selectedPDFRecord,
                        pdfURL: selectedPDFURL,
                        linkURL: editLinkURL.isEmpty ? nil : editLinkURL
                    )
        }
        // Reset edit mode
        isEditing = false
    }
    
    // PATCH: One-time fix for missing scheduledDate
    private func patchMissingScheduledDates() {
        debugLog("Called")
        isLoading = true
        errorMessage = nil
        debugLog("Starting patchMissingScheduledDates")
        let database = CKContainer(identifier: "iCloud.PearInc.EICT-iOS-16").publicCloudDatabase
        let query = CKQuery(recordType: "NewsFeedItem", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "datePosted", ascending: false)]
        debugLog("About to fetch all NewsFeedItem records for patch")
        database.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
            switch result {
            case .success(let (matchResults, _)):
                debugLog("[PATCH] Fetched \(matchResults.count) records")
                var patched = 0
                var errors = 0
                let group = DispatchGroup()
                for (_, recordResult) in matchResults {
                    if let record = try? recordResult.get(), record["scheduledDate"] == nil {
                        let fallback = record["datePosted"] as? Date ?? record["datePublished"] as? Date ?? Date()
                        record["scheduledDate"] = fallback
                        debugLog("[PATCH] Patching record \(record.recordID.recordName) with scheduledDate \(fallback)")
                        group.enter()
                        database.save(record) { _, error in
                            if let error = error {
                                debugLog("[PATCH] Error saving record \(record.recordID.recordName): \(error.localizedDescription)")
                                errors += 1
            } else {
                                patched += 1
                            }
                            group.leave()
                        }
                    }
                }
                group.notify(queue: .main) {
                    debugLog("[PATCH] Completed patch. Patched: \(patched), Errors: \(errors)")
                    self.isLoading = false
                    self.errorMessage = errors > 0 ? "Patch completed with errors" : nil
                    self.loadPosts()
                }
            case .failure(let error):
                debugLog("[PATCH] Error fetching records: \(error.localizedDescription)")
                self.isLoading = false
                self.errorMessage = "Patch failed: \(error.localizedDescription)"
            }
        }
    }
    
    // Debug logger for function tracing
    private func debugLog(_ message: String, function: String = #function) {
        print("🛠️ [DEBUG] [\(function)] \(message)")
    }
    
    private func editPost(_ post: NewsFeedPost) {
        print("🛠️ editPost called for post: \(post.title)")
        self.selectedPostID = post.id.recordName
        self.editTitle = post.title
        self.editLinkURL = post.linkURL?.absoluteString ?? ""
        self.isEditing = true
    }
    
    private func deletePost(_ post: NewsFeedPost) {
        print("🛠️ [IMPORTANT] deletePost called for post: \(post.title) [ID: \(post.id.recordName)]")
        print("🛠️ [DEBUG] Post record details:")
        print("🛠️ [DEBUG] - Record type: \(post.record.recordType)")
        
        // Safely get fields and provide fallbacks if empty
        let fields = post.record.getAllKeys()
        print("🛠️ [DEBUG] - Fields: \(fields.isEmpty ? "<empty>" : fields.joined(separator: ", "))")
        print("🛠️ [DEBUG] - ID: \(post.id.recordName)")
        print("🛠️ [DEBUG] - Zone: \(post.id.zoneID.zoneName)")
        
        isLoading = true
        errorMessage = nil
        
        // Add additional debug for the delete operation
        print("🛠️ [DEBUG] About to delete record with ID: \(post.id.recordName)")
        print("🛠️ [DEBUG] Database URL: \(database)")
        print("🛠️ [DEBUG] Container ID: \(container.containerIdentifier ?? "unknown")")
        
        // Use the CKModifyRecordsOperation for more control over the delete operation
        let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: [post.id])
        operation.savePolicy = .allKeys
        operation.qualityOfService = .userInitiated
        
        // Set the result block (modern API)
        operation.modifyRecordsResultBlock = { result in
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success:
                    print("🛠️ [SUCCESS] Successfully deleted post with ID: \(post.id.recordName)")
                    print("🛠️ [IMPORTANT] Successfully deleted post: \(post.title) [ID: \(post.id.recordName)]")
                    self.posts.removeAll { $0.id == post.id }
                    
                    // Send notification to refresh other views
                    print("🛠️ [IMPORTANT] Posting NewsFeedRefreshNotification for deleted post")
                    NotificationManager.shared.postNewsFeedRefresh()
                    
                    // Show success message
                    let successMessage = self.isSpanish ? "La publicación fue eliminada exitosamente." : "Post deleted successfully."
                    self.showSuccessMessage(successMessage)
                    
                    // Reset state after deleting
                    if self.selectedPostID == post.id.recordName {
                        self.selectedPostID = nil
                        self.isEditing = false
                    }
                    print("🛠️ [DEBUG] Post deleted and UI state reset. Posts count: \(self.posts.count)")
                
                case .failure(let error):
                    // Error case
                    print("🛠️ [ERROR] Delete operation failed with error: \(error.localizedDescription)")
                    self.showErrorMessage("Error deleting post: \(error.localizedDescription)")
                    print("🛠️ [IMPORTANT] Error deleting post: \(error.localizedDescription)")
                    
                    if let ckError = error as? CKError {
                        print("🛠️ [DEBUG] CKError code: \(ckError.code.rawValue)")
                        print("🛠️ [DEBUG] CKError details: \(ckError.localizedDescription)")
                        print("🛠️ [DEBUG] CKError userInfo: \(ckError.userInfo)")
                        // Additional error diagnostics
                        if ckError.code == .serverRecordChanged {
                            print("🛠️ [DEBUG] Server record changed error - client record: \(String(describing: ckError.userInfo[CKRecordChangedErrorClientRecordKey]))")
                            print("🛠️ [DEBUG] Server record changed error - server record: \(String(describing: ckError.userInfo[CKRecordChangedErrorServerRecordKey]))")
                        } else if ckError.code == .zoneNotFound {
                            print("🛠️ [DEBUG] Zone not found error - zone ID: \(String(describing: ckError.userInfo["CKRecordZoneID"]))")
                        } else if ckError.code == .unknownItem {
                            print("🛠️ [DEBUG] Unknown item error - record ID: \(String(describing: ckError.userInfo["CKRecord"]))")
                        }
                    }
                }
            }
        }
        
        // Add the operation to the database
        database.add(operation)
    }
    
    // Add a method to show consistent success feedback
    private func showSuccessMessage(_ message: String) {
        print("🛠️ [SUCCESS] Showing success message: \(message)")
        
        // Create and present a success alert directly
        let alert = NSAlert()
        alert.messageText = isSpanish ? "Operación Exitosa" : "Operation Successful"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .informational
        
        // Run on the main thread to ensure UI updates
        DispatchQueue.main.async {
            let _ = alert.runModal()
            print("🛠️ [SUCCESS] Success alert dismissed")
        }
    }

    private func archivePost(post: NewsFeedPost) {
        print("🛠️ [IMPORTANT] archivePost called for post: \(post.title) [ID: \(post.id.recordName)]")
        isLoading = true
        errorMessage = nil
        
        // Set the isArchived flag
        post.record["isArchived"] = 1
        
        // Add additional debug for the archive operation
        print("🛠️ [DEBUG] About to update record with ID: \(post.id.recordName)")
        print("🛠️ [DEBUG] Setting isArchived=1 on record")
        print("🛠️ [DEBUG] Database URL: \(database)")
        
        database.save(post.record) { savedRecord, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    self.showErrorMessage("Error archiving post: \(error.localizedDescription)")
                    print("🛠️ [IMPORTANT] Error archiving post: \(error.localizedDescription)")
                    if let ckError = error as? CKError {
                        print("🛠️ [DEBUG] CKError code: \(ckError.code.rawValue)")
                        print("🛠️ [DEBUG] CKError details: \(ckError.localizedDescription)")
                    }
                } else {
                    print("🛠️ [IMPORTANT] Successfully archived post: \(post.title) [ID: \(post.id.recordName)]")
                    self.posts.removeAll { $0.id == post.id }
                    
                    // Send notification to refresh other views
                    print("🛠️ [IMPORTANT] Posting NewsFeedRefreshNotification for archived post")
                    NotificationManager.shared.postNewsFeedRefresh()
                    
                    // Show success message
                    let successMessage = self.isSpanish ? "La publicación fue archivada exitosamente." : "Post archived successfully."
                    self.showSuccessMessage(successMessage)
                    
                    // Reset state after archiving
                    if self.selectedPostID == post.id.recordName {
                        self.selectedPostID = nil
                        self.isEditing = false
                    }
                    print("🛠️ [DEBUG] Post archived and UI state reset. Posts count: \(self.posts.count)")
                }
            }
        }
    }
    
    // Update the trigger methods to use a direct confirmation approach
    private func triggerArchiveAlert(for post: NewsFeedPost) {
        print("📰 [IMPORTANT] Triggering archive alert for post: \(post.title)")
        
        // Create and present a confirmation alert directly
        let alert = NSAlert()
        alert.messageText = isSpanish ? "Archivar Publicación" : "Archive Post"
        alert.informativeText = isSpanish ? 
            "La publicación se moverá al archivo y ya no estará disponible en la pestaña de gestión de noticias." : 
            "The post will be moved to the archive and will no longer be available in the manage news feed tab."
        alert.addButton(withTitle: isSpanish ? "Archivar" : "Archive")
        alert.addButton(withTitle: isSpanish ? "Cancelar" : "Cancel")
        alert.alertStyle = .warning
        
        // Run on the main thread to ensure UI updates
        DispatchQueue.main.async {
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                print("🛠️ [IMPORTANT] User confirmed archive")
                self.archivePost(post: post)
            } else {
                print("🛠️ [IMPORTANT] User cancelled archive")
            }
        }
    }
    
    private func triggerDeleteAlert(for post: NewsFeedPost) {
        print("🛠️ [IMPORTANT] Triggering delete alert for post: \(post.title)")
        
        // Create and present a confirmation alert directly
        let alert = NSAlert()
        alert.messageText = isSpanish ? "Eliminar Publicación" : "Delete Post"
        alert.informativeText = isSpanish ? 
            "Esta acción no se puede deshacer." : 
            "This action cannot be undone."
        alert.addButton(withTitle: isSpanish ? "Eliminar" : "Delete")
        alert.addButton(withTitle: isSpanish ? "Cancelar" : "Cancel")
        alert.alertStyle = .warning
        
        // Run on the main thread to ensure UI updates
                DispatchQueue.main.async {
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                print("🛠️ [IMPORTANT] User confirmed delete")
                self.deletePost(post)
            } else {
                print("🛠️ [IMPORTANT] User cancelled delete")
            }
        }
    }

    private func showErrorMessage(_ message: String, title: String = "") {
        print("🛠️ [ERROR] Showing error: \(title) - \(message)")
        self.errorMessage = message
        self.errorTitle = title.isEmpty ? (isSpanish ? "Error" : "Error") : title
        self.showError = true
    }

    // MARK: - Direct CloudKit operations
    
    /// Alternative delete method that uses a different approach to delete records
    private func directDeleteRecord(recordID: CKRecord.ID, title: String) {
        print("🔴 [DIRECT DELETE] Attempting to delete record: \(recordID.recordName)")
        isLoading = true
        
        // Create a deletion operation
        let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: [recordID])
        operation.savePolicy = .allKeys
        operation.qualityOfService = .userInitiated
        
        // Set the result block (modern API)
        operation.modifyRecordsResultBlock = { result in
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success:
                    print("🔴 [DIRECT DELETE] Success! Deleted record: \(recordID.recordName)")
                    
                    // Update the UI
                    self.posts.removeAll { $0.id.recordName == recordID.recordName }
                    
                    // Send notification to refresh other views
                    NotificationManager.shared.postNewsFeedRefresh()
                    
                    // Show success message
                    let successMessage = self.isSpanish ? "La publicación fue eliminada exitosamente." : "Post deleted successfully."
                    self.showSuccessMessage(successMessage)
                    
                    // Reset selection if needed
                    if self.selectedPostID == recordID.recordName {
                        self.selectedPostID = nil
                        self.isEditing = false
                    }
                case .failure(let error):
                    print("🔴 [DIRECT DELETE] Error: \(error.localizedDescription)")
                    self.showErrorMessage("Error deleting post: \(error.localizedDescription)")
                }
            }
        }
        
        // Add the operation to the database
        database.add(operation)
    }

    /// Persist changes made to a NewsFeedPost back to CloudKit and refresh list
    private func saveEditedPost(_ post: NewsFeedPost) {
        print("🛠️ [IMPORTANT] saveEditedPost called for post: \(post.title) [ID: \(post.id.recordName)]")
        isLoading = true
        errorMessage = nil

        database.save(post.record) { savedRecord, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    print("🛠️ [ERROR] Failed to save edited post: \(error.localizedDescription)")
                    self.showErrorMessage(self.isSpanish ? "Error al guardar cambios: \(error.localizedDescription)" : "Failed to save changes: \(error.localizedDescription)")
                } else {
                    print("🛠️ [SUCCESS] Successfully saved edited post: \(post.title)")
                    // Replace post in array with updated version
                    if let index = self.posts.firstIndex(where: { $0.id == post.id }) {
                        self.posts[index] = post
                    }
                    // Trigger refresh notifications so other views stay in sync
                    NotificationManager.shared.postNewsFeedRefresh()
                    // Exit edit mode and update filtered list
                    self.isEditing = false
                    self.loadPosts()
                    self.showSuccessMessage(self.isSpanish ? "Cambios guardados exitosamente." : "Changes saved successfully.")
                }
            }
        }
    }
}

// MARK: - PDF Viewer Implementation
struct PDFViewerController: NSViewControllerRepresentable {
    let document: PDFKit.PDFDocument
    var onDismiss: () -> Void
    
    func makeNSViewController(context: Context) -> NSViewController {
        let controller = PDFViewController(document: document, onDismiss: onDismiss)
        return controller
    }
    
    func updateNSViewController(_ nsViewController: NSViewController, context: Context) {
        if let pdfController = nsViewController as? PDFViewController {
            pdfController.document = document
        }
    }
    
    class PDFViewController: NSViewController {
        var document: PDFKit.PDFDocument
        var onDismiss: () -> Void
        var pdfView: PDFView!
        
        init(document: PDFKit.PDFDocument, onDismiss: @escaping () -> Void) {
            self.document = document
            self.onDismiss = onDismiss
            super.init(nibName: nil, bundle: nil)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func loadView() {
            let containerView = NSView()
            
            // Create toolbar
            let toolbar = NSView()
            toolbar.wantsLayer = true
            toolbar.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
            containerView.addSubview(toolbar)
            
            // Create PDF view
            pdfView = PDFView()
            pdfView.autoresizingMask = [.width, .height]
            containerView.addSubview(pdfView)
            
            // Add close button
            let closeButton = NSButton(title: "Close", target: self, action: #selector(closeButtonTapped))
            closeButton.bezelStyle = .rounded
            toolbar.addSubview(closeButton)
            
            self.view = containerView
        }
        
        override func viewDidLoad() {
            super.viewDidLoad()
            pdfView.document = document
            pdfView.autoScales = true
        }
        
        @objc private func closeButtonTapped() {
            onDismiss()
        }
    }
}

// MARK: - Preview
struct NewsFeedManagementView_Previews: PreviewProvider {
    static var previews: some View {
        NewsFeedManagementView(isSpanish: .constant(false))
    }
}

private struct EmptyNewsListView: View {
    let isSpanish: Bool
    var body: some View {
        VStack {
            Spacer(minLength: 80) // Adjusted from just Spacer() to add minimal spacing at top
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "newspaper")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text(isSpanish ? "No hay noticias para mostrar" : "No news to display")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            Spacer(minLength: 80) // Adjusted from just Spacer() to add minimal spacing at bottom
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - PDF Viewer Sheet (asynchronous loader to prevent priority inversion)
fileprivate struct PDFViewerSheet: View {
    let details: PDFDocumentDetails
    let dismissAction: () -> Void
    
    @State private var pdfDocument: PDFKit.PDFDocument? = nil
    @State private var isLoading: Bool = true
    
    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                    Text("Loading PDF…")
                        .font(.headline)
                }
                .frame(minWidth: 400, minHeight: 300)
            } else if let pdf = pdfDocument {
                VStack(spacing: 0) {
                    // Header with title and close button
                    HStack {
                        Text(details.title)
                            .font(.headline)
                            .fontWeight(.bold)
                            .padding(.leading)
                        Spacer()
                        Button("Close") {
                            dismissAction()
                        }
                        .padding(.trailing)
                    }
                    .padding(.vertical, 8)
                    .background(Color(NSColor.windowBackgroundColor))
                    
                    // PDF Viewer Controller
                    PDFViewerController(document: pdf, onDismiss: dismissAction)
                        .frame(minWidth: 800, minHeight: 600)
                }
                .frame(minWidth: 800, minHeight: 600)
            } else {
                VStack(spacing: 16) {
                    Text("Error loading PDF")
                        .foregroundColor(.red)
                    Button("Close") { dismissAction() }
                        .buttonStyle(.bordered)
                }
                .frame(width: 400, height: 200)
            }
        }
        .onAppear(perform: loadPDF)
    }
    
    private func loadPDF() {
        // Load the PDF on a background queue
        DispatchQueue.global(qos: .userInitiated).async {
            let doc = details.getPDFDocument()
            DispatchQueue.main.async {
                self.pdfDocument = doc
                self.isLoading = false
            }
        }
    }
} 