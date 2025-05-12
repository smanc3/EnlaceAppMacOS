//
//  ArchivedNewsView.swift
//  Enlace Admin (Preview)
//
//  Created on 4/21/25.
//

import SwiftUI
import CloudKit
import PDFKit
import Foundation
import Combine
import AppKit // For sounds

// MARK: - Archived News View
struct ArchivedNewsView: View {
    // MARK: - Properties
    @Binding var isSpanish: Bool
    @Binding var refreshTrigger: Bool
    
    @State private var archivedPosts: [ModelsArchivedNewsPost] = []
    @State private var filteredAndSortedPosts: [ModelsArchivedNewsPost] = [] // Cached filtered and sorted posts
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    @State private var searchText: String = ""
    @State private var selectedPostID: String? = nil
    @State private var sortOption: SortOption = .dateArchived
    @State private var showDeleteConfirmation: Bool = false
    @State private var showUnarchiveConfirmation: Bool = false
    @State private var postToDelete: ModelsArchivedNewsPost? = nil
    @State private var postToUnarchive: ModelsArchivedNewsPost? = nil
    
    // State for detail view PDF loading
    @State private var loadedPdfDocumentForDetail: PDFDocument? = nil
    @State private var isLoadingPDFForDetail: Bool = false
    @State private var pdfLoadErrorForDetail: String? = nil
    
    @EnvironmentObject var languageManager: LanguageManager
    
    private let container = CKContainer(identifier: "iCloud.PearInc.EICT-iOS-16")
    private var database: CKDatabase {
        return container.publicCloudDatabase
    }
    
    @State private var showUnarchiveSuccess: Bool = false
    @State private var unarchiveSuccessMessage: String = ""
    
    @State private var showPDFSheet: Bool = false
    @State private var pdfToShow: PDFDocument? = nil
    
    // Track PDF thumbnails for archived posts
    @State private var pdfThumbnails: [String: NSImage] = [:]
    
    // MARK: - Sort Options
    enum SortOption {
        case dateArchived, datePosted, title
        
        // Simplify these properties to avoid type-checking issues
        func localizedName(isSpanish: Bool) -> String {
            if isSpanish {
                switch self {
                case .dateArchived: return "Fecha de Archivo"
                case .datePosted: return "Fecha de Publicación"
                case .title: return "Título"
                }
            } else {
                switch self {
                case .dateArchived: return "Archive Date"
                case .datePosted: return "Post Date"
                case .title: return "Title"
                }
            }
        }
    }
    
    // MARK: - View Body
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isSpanish ? "Noticias Archivadas" : "Archived News")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Refresh button
                Button(action: {
                    loadArchivedPosts()
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
            
            // Search and filters
            HStack {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField(isSpanish ? "Buscar por título o descripción..." : "Search by title or description...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: searchText) { newValue in
                            updateFilteredPosts()
                        }
                }
                .padding(.trailing)
                
                // Sort picker
                Picker(isSpanish ? "Ordenar" : "Sort", selection: $sortOption) {
                    ForEach([SortOption.dateArchived, .datePosted, .title], id: \.self) { option in
                        Text(option.localizedName(isSpanish: isSpanish)).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
                .onChange(of: sortOption) { newValue in
                    updateFilteredPosts()
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.textBackgroundColor))
            
            // Main content area
            HStack(spacing: 0) {
                // Left panel: list or empty state
                VStack {
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                        VStack {
                            Spacer()
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 50))
                                .foregroundColor(.orange)
                                .padding()
                            Text(error)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .padding()
                            if error.contains("Invalid predicate") {
                                Text(isSpanish ? "Error de CloudKit: La consulta no es válida. Esto podría deberse a un problema con el esquema de la base de datos." : "CloudKit error: The query is invalid. This might be due to an issue with the database schema.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                    .padding(.bottom)
                            }
                            Button(isSpanish ? "Reintentar" : "Retry") {
                                self.loadArchivedPosts()
                            }
                            .buttonStyle(.bordered)
                            .padding()
                            Spacer()
                        }
            } else if archivedPosts.isEmpty {
                emptyStateView
            } else {
                        List(selection: $selectedPostID) {
                            ForEach(filteredAndSortedPosts, id: \ .id.recordName) { post in
                                HStack(alignment: .center, spacing: 12) {
                                    // PDF thumbnail or fallback icon
                                    if let thumbnail = pdfThumbnails[post.id.recordName] {
                                        Image(nsImage: thumbnail)
                                            .resizable()
                                            .frame(width: 32, height: 32)
                                            .cornerRadius(4)
                                    } else {
                                        Image(systemName: post.pdfReference != nil ? "doc.text" : "newspaper")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 32, height: 32)
                                            .foregroundColor(.gray)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(post.title)
                                            .font(.body)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                        Text(dateFormatter.string(from: post.datePosted))
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                    }
                                    Spacer()
                                    // Unarchive button
                                    Button(action: {
                                        postToUnarchive = post
                                        triggerUnarchiveAlert(for: post)
                                    }) {
                                        Image(systemName: "arrow.uturn.up")
                                            .foregroundColor(.green)
                                            .font(.system(size: 16, weight: .medium))
                                    }
                                    .buttonStyle(.plain)
                                    .help(isSpanish ? "Desarchivar" : "Unarchive")
                                    // Delete button
                                    Button(role: .destructive, action: {
                                        postToDelete = post
                                        triggerDeleteAlert(for: post)
                                    }) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 16, weight: .medium))
                                    }
                                    .buttonStyle(.plain)
                                    .help(isSpanish ? "Eliminar" : "Delete")
                                }
                                .tag(post.id.recordName)
                                .contentShape(Rectangle())
                                .background(selectedPostID == post.id.recordName ? Color.blue.opacity(0.1) : Color.clear)
                                .onTapGesture {
                                    selectedPostID = post.id.recordName
                                }
                            }
                        }
                        .listStyle(.inset)
                    }
                    }
                    .frame(minWidth: 300, maxWidth: 300)
                    .background(Color.white)
                    Divider()
                // Right panel: detail or empty detail view
                if let selectedID = selectedPostID, let post = archivedPosts.first(where: { $0.id.recordName == selectedID }) {
                        detailView(post: post)
                    } else {
                        emptyDetailView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            print("ArchivedNewsView appeared")
            self.loadArchivedPosts()
            self.setupNotifications()
        }
        .onDisappear {
            self.removeNotifications()
        }
        .onChange(of: refreshTrigger) { newValue in
            if newValue {
                self.loadArchivedPosts()
                refreshTrigger = false
            }
        }
        .overlay(
            EmptyView() // Replace the custom toast overlay with EmptyView
        )
        .sheet(isPresented: $showPDFSheet) {
            if let pdf = pdfToShow {
                ArchivePDFViewer(document: pdf)
                    .frame(minWidth: 800, minHeight: 600)
            } else {
                Text(isSpanish ? "No se pudo cargar el PDF." : "Could not load PDF.")
                    .padding()
            }
        }
    }
    
    // Update filtered posts when search or sort changes
    private func updateFilteredPosts() {
        var filtered = archivedPosts
        
        // Apply search filtering
        if !searchText.isEmpty {
            filtered = filtered.filter { post in
                post.title.localizedCaseInsensitiveContains(searchText) ||
                post.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply sorting
        switch sortOption {
        case .dateArchived:
            filtered.sort { $0.archivedDate > $1.archivedDate }
        case .datePosted:
            filtered.sort { $0.datePosted > $1.datePosted }
        case .title:
            filtered.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
        
        filteredAndSortedPosts = filtered
    }
    
    // MARK: - Subviews
    
    /// Loading indicator view
    private var loadingView: some View {
        VStack {
            Spacer()
            VStack(spacing: 16) {
                // Centered loading indicator with animation
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
                    .padding()
                    // Add subtle animation to make it more engaging
                    .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 0)
                    // Center in the frame
                    .frame(maxWidth: .infinity, alignment: .center)
                    
                Text(isSpanish ? "Cargando noticias archivadas..." : "Loading archived news...")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    // Center text
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            // Position the loading group slightly above center for better visual balance
            .offset(y: -20)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    /// Empty state view when no posts are available
    private var emptyStateView: some View {
        VStack {
            Spacer(minLength: 80) // Adjusted spacing for consistency
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "archivebox")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text(isSpanish ? "No hay noticias archivadas" : "No archived news")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            Spacer(minLength: 80) // Adjusted spacing for consistency
        }
        .frame(maxWidth: .infinity)
    }
    
    /// Empty detail view when no post is selected
    private var emptyDetailView: some View {
        VStack {
            Spacer()
            Image(systemName: "arrow.left.circle")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text(isSpanish ? "Selecciona una noticia para ver detalles" : "Select a news post to view details")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
    }
    
    /// Detail view for selected post
    private func detailView(post: ModelsArchivedNewsPost) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 20) {
                // Title and date
                VStack(alignment: .leading, spacing: 8) {
                    Text(post.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("\(isSpanish ? "Publicado: " : "Posted: ") \(dateFormatter.string(from: post.datePosted))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(isSpanish ? "Archivado: " : "Archived: ") \(dateFormatter.string(from: post.archivedDate))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // PDF preview if available
                if post.pdfReference != nil {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text(isSpanish ? "Documento PDF" : "PDF Document")
                            .font(.headline)
                        
                        if isLoadingPDFForDetail {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text(isSpanish ? "Cargando PDF..." : "Loading PDF...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        } else if let error = pdfLoadErrorForDetail {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        } else if let pdfDoc = loadedPdfDocumentForDetail {
                            // Show a preview/thumbnail instead of embedding full PDF
                            if let thumbnail = pdfThumbnails[post.id.recordName] {
                                Image(nsImage: thumbnail)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 200)
                                    .cornerRadius(8)
                                    .onTapGesture {
                                        pdfToShow = pdfDoc
                                        showPDFSheet = true
                                    }
                            } else {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                    .frame(height: 100)
                            }
                            
                            Button(action: {
                                pdfToShow = pdfDoc
                                showPDFSheet = true
                            }) {
                                Label(isSpanish ? "Ver PDF" : "View PDF", systemImage: "doc.richtext")
                            }
                            .buttonStyle(.bordered)
                            .padding(.top, 4)
                        } else {
                            ProgressView()
                                .frame(height: 60)
                        }
                    }
                    .onAppear {
                        if loadedPdfDocumentForDetail == nil && !isLoadingPDFForDetail && pdfLoadErrorForDetail == nil {
                            loadPDFForDetailView(post: post)
                        }
                    }
                }
                
                // Link if available
                if let link = post.linkURL {
                    let urlString = link.absoluteString
                    let safeURLString = (urlString.lowercased().hasPrefix("http://") || urlString.lowercased().hasPrefix("https://")) ? urlString : "https://" + urlString
                    let safeURL = URL(string: safeURLString)
                    
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text(isSpanish ? "Enlace" : "Link")
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
                if !post.description.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text(isSpanish ? "Descripción" : "Description")
                            .font(.headline)
                        Text(post.description)
                            .font(.body)
                    }
                }
                
                Spacer()
                
                // Action buttons
                HStack {
                    Spacer()
                    
                    Button(action: {
                        postToUnarchive = post
                        triggerUnarchiveAlert(for: post)
                    }) {
                        Label(isSpanish ? "Desarchivar" : "Unarchive", systemImage: "arrow.uturn.up")
                    }
                    .buttonStyle(.bordered)
                    
                    Button(role: .destructive, action: {
                        postToDelete = post
                        triggerDeleteAlert(for: post)
                    }) {
                        Label(isSpanish ? "Eliminar" : "Delete", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top)
                }
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Methods
    
    /// Set up notification observers
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .postArchived,
            object: nil,
            queue: .main
        ) { _ in
            print("📰 ArchivedNewsView: Received notification of newly archived post, refreshing...")
            self.loadArchivedPosts()
        }
    }

    /// Remove notification observers
    private func removeNotifications() {
        NotificationCenter.default.removeObserver(
            self,
            name: .postArchived,
            object: nil
        )
    }

    /// Load archived posts from CloudKit
    private func loadArchivedPosts() {
        print("Starting to load archived news posts")
        Task {
            do {
                let accountStatus = try await container.accountStatus()
                print("iCloud account status: \(accountStatus.rawValue)")
                guard accountStatus == .available else {
                    throw CKError(.notAuthenticated)
                }
                let predicate = NSPredicate(format: "isArchived == 1")
                let query = CKQuery(recordType: "NewsFeedItem", predicate: predicate)
                query.sortDescriptors = [
                    NSSortDescriptor(key: "scheduledDate", ascending: false),
                    NSSortDescriptor(key: "recordNameMirror", ascending: true) // Secondary sort prevents recordName fallback
                ]
                let (matchResults, _) = try await database.records(matching: query)
                let records = matchResults.compactMap { _, recordResult -> CKRecord? in
                    do {
                        return try recordResult.get()
                    } catch {
                        print("Error getting record: \(error.localizedDescription)")
                        return nil
                    }
                }
                print("Loaded \(records.count) archived news posts")
                // Debug log for each record's ID and isArchived value
                for record in records {
                    let isArchivedValue = record["isArchived"]
                    print("[DEBUG] Archived fetch result: \(record.recordID.recordName), isArchived: \(String(describing: isArchivedValue))")
                }
                    await MainActor.run {
                    self.archivedPosts = records.map { ModelsArchivedNewsPost(record: $0) }
                        self.isLoading = false
                    self.updateFilteredPosts()
                }
                // Fetch PDF thumbnails for posts with pdfReference
                for post in self.archivedPosts {
                    if let pdfRef = post.pdfReference {
                        Task {
                            do {
                                let record = try await database.record(for: pdfRef.recordID)
                                let pdfDoc = PDFDocumentDetails(record: record)
                                if let thumbnail = pdfDoc.thumbnail {
                    await MainActor.run {
                                        self.pdfThumbnails[post.id.recordName] = thumbnail
                                        print("[DEBUG] PDF thumbnail loaded successfully for post:", post.id.recordName)
                    }
                }
            } catch {
                                print("[DEBUG] Failed to fetch PDF record for thumbnail: \(error.localizedDescription)")
                    }
                }
                    }
                }
            } catch {
                print("Error loading archived posts: \(error.localizedDescription)")
                await handleFetchError(error, recordType: "ArchivedNewsPost", function: "loadArchivedPosts")
            }
        }
    }

    /// Handle errors from fetch operations
     private func handleFetchError(_ error: Error, recordType: String, function: String = #function) async {
        await MainActor.run {
            self.isLoading = false
            let recordTypeString = recordType
            
            if let ckError = error as? CKError {
                print("CloudKit error fetching \(recordTypeString): \(error.localizedDescription)")
                print("Error code: \(ckError.errorCode)")
                
                switch ckError.code {
                case .notAuthenticated:
                    self.errorMessage = isSpanish ? "No autenticado en iCloud..." : "Not authenticated with iCloud..."
                case .networkUnavailable, .networkFailure:
                    self.errorMessage = isSpanish ? "Red no disponible..." : "Network unavailable..."
                case .serviceUnavailable, .zoneBusy, .requestRateLimited:
                    self.errorMessage = isSpanish ? "Servicio de iCloud no disponible temporalmente..." : "iCloud service temporarily unavailable..."
                default:
                    self.errorMessage = isSpanish ? "Error al cargar: \(error.localizedDescription)" : "Error loading: \(error.localizedDescription)"
                }
            } else {
                print("Unknown error fetching \(recordTypeString): \(error.localizedDescription)")
                self.errorMessage = isSpanish ? "Error al cargar: \(error.localizedDescription)" : "Error loading: \(error.localizedDescription)"
            }
        }
    }

    /// Delete an archived post
    private func deleteArchivedPost(_ post: ModelsArchivedNewsPost) {
        isLoading = true
        print("📰 [\(Date())] Attempting to delete post: \(post.title)")
        print("🛠️ [DEBUG] Using container identifier: \(container.containerIdentifier ?? "<nil>") for deletion")
        print("🛠️ [DEBUG] Deleting record from PUBLIC database: \(post.id.recordName)")
        
        // Create a deletion operation for more reliable deletion
        let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: [post.id])
        operation.savePolicy = .allKeys
        operation.qualityOfService = .userInitiated
        
        // Set the result block (modern API)
        operation.modifyRecordsResultBlock = { result in
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success:
                    print("📰 ✅ [\(Date())] Successfully deleted archived post")
                    self.archivedPosts.removeAll { $0.id == post.id }
                    self.updateFilteredPosts()
                    if self.selectedPostID == post.id.recordName { self.selectedPostID = nil }
                    print("🛠️ [DEBUG] Removed post from archived list after successful delete: \(post.id.recordName)")
                    NotificationCenter.default.post(name: .newsFeedRefresh, object: nil)
                    
                    // Show success message with NSAlert for consistency
                    let successMessage = self.isSpanish ? "La publicación fue eliminada exitosamente." : "Post deleted successfully."
                    let alert = NSAlert()
                    alert.messageText = self.isSpanish ? "Éxito" : "Success"
                    alert.informativeText = successMessage
                    alert.addButton(withTitle: "OK")
                    
                    print("📰 [DEBUG] Showing delete success alert")
                    DispatchQueue.main.async {
                        let _ = alert.runModal()
                        print("📰 [DEBUG] Delete success alert dismissed")
                    }
                    
                case .failure(let error):
                    let errorDescription = error.localizedDescription
                    print("📰 ❌ [\(Date())] Error deleting archived post: \(errorDescription)")
                    self.errorMessage = self.isSpanish ? "Error al eliminar: \(errorDescription)" : "Error deleting: \(errorDescription)"
                    
                    // Show error alert
                    let alert = NSAlert()
                    alert.messageText = self.isSpanish ? "Error" : "Error"
                    alert.informativeText = self.errorMessage ?? "Unknown error"
                    alert.alertStyle = .critical
                    alert.addButton(withTitle: "OK")
                    
                    DispatchQueue.main.async {
                        let _ = alert.runModal()
                    }
                }
            }
        }
        
        // Add the operation to the database
        database.add(operation)
    }

    /// Unarchive a post (move it back to the news feed)
    private func unarchivePost(_ post: ModelsArchivedNewsPost) {
        isLoading = true
        print("📰 [\(Date())] Attempting to unarchive post: \(post.title) [ID: \(post.id.recordName)]")

        Task {
            do {
                // First check if this is a PDFDocumentItem record
                let isPDF = post.pdfReference != nil 
                print("📰 [\(Date())] isPDF: \(isPDF), pdfReference: \(String(describing: post.pdfReference))")
                
                if isPDF {
                    if let pdfReference = post.pdfReference {
                        print("📰 [\(Date())] Fetching PDF record for unarchive: \(pdfReference.recordID.recordName)")
                        do {
                            let pdfRecord = try await database.record(for: pdfReference.recordID)
                            pdfRecord["isArchived"] = NSNumber(value: 0)
                            if pdfRecord["archivedDate"] != nil {
                                pdfRecord["archivedDate"] = nil
                            }
                            print("📰 [\(Date())] Unarchiving PDF record: \(pdfReference.recordID.recordName)")
                            _ = try await database.save(pdfRecord)
                            print("📰 [\(Date())] Successfully unarchived PDF: \(post.title)")
                        } catch {
                            print("📰 ❌ [\(Date())] Error fetching or saving PDF record during unarchive: \(error.localizedDescription)")
                            // Attempt to delete the orphaned NewsFeedItem record from CloudKit
                            do {
                                let publicDB = container.publicCloudDatabase
                                print("🛠️ [DEBUG] Deleting orphaned NewsFeedItem from PUBLIC database: \(post.id.recordName)")
                                try await publicDB.deleteRecord(withID: post.id)
                                print("🛠️ [DEBUG] Deleted orphaned NewsFeedItem from CloudKit: \(post.id.recordName)")
                            } catch {
                                print("🛠️ [DEBUG] Failed to delete orphaned NewsFeedItem from CloudKit: \(error.localizedDescription)")
                            }
                            await MainActor.run {
                                isLoading = false
                                errorMessage = isSpanish ? "Error al desarchivar PDF: \(error.localizedDescription)" : "Error unarchiving PDF: \(error.localizedDescription)"
                                archivedPosts.removeAll { $0.id == post.id }
                                updateFilteredPosts()
                                if selectedPostID == post.id.recordName { selectedPostID = nil }
                                print("📰 [DEBUG] Removed orphaned post from archived list after unarchive error: \(post.id.recordName)")
                            }
                            return
                        }
                    } else {
                        print("📰 ❌ [\(Date())] Error: Post appears to be a PDF but has no pdfReference")
                    }
                let newsFeedItem = createNewsFeedItem(from: post)
                _ = try await database.save(newsFeedItem)
                    print("📰 ✅ [\(Date())] Successfully created new NewsFeedItem from unarchived post")
                    let publicDB = container.publicCloudDatabase
                    print("🛠️ [DEBUG] Deleting original archived record from PUBLIC database: \(post.id.recordName)")
                    try await publicDB.deleteRecord(withID: post.id)
                } else {
                    // Not a PDF, try to fetch the record for unarchiving
                    print("📰 [\(Date())] Fetching archived post record for unarchive: \(post.id.recordName)")
                    do {
                        let record = try await database.record(for: post.id)
                        record["isArchived"] = NSNumber(value: 0)
                        if record["archivedDate"] != nil {
                            record["archivedDate"] = nil
                        }
                        print("📰 [\(Date())] Unarchiving NewsFeedItem record: \(post.id.recordName)")
                        _ = try await database.save(record)
                        print("📰 ✅ [\(Date())] Successfully unarchived NewsFeedItem: \(post.title)")
                        // Optionally, delete the archived record if needed
                    } catch let ckError as CKError where ckError.code == .unknownItem {
                        print("📰 ❌ [\(Date())] Record not found for unarchive: \(post.id.recordName). Removing from UI.")
                await MainActor.run {
                    isLoading = false
                            errorMessage = isSpanish ? "El registro archivado ya no existe en la nube. Eliminado de la lista." : "Archived record not found in CloudKit. Removed from list."
                    archivedPosts.removeAll { $0.id == post.id }
                            updateFilteredPosts()
                        }
                        return
                    } catch {
                        print("📰 ❌ [\(Date())] Error fetching or saving NewsFeedItem during unarchive: \(error.localizedDescription)")
                        await MainActor.run {
                            isLoading = false
                            errorMessage = isSpanish ? "Error al desarchivar: \(error.localizedDescription)" : "Error unarchiving: \(error.localizedDescription)"
                        }
                        return
                    }
                }
                await MainActor.run {
                    isLoading = false
                    print("📰 ✅ [\(Date())] Successfully unarchived post")
                    archivedPosts.removeAll { $0.id == post.id }
                    if selectedPostID == post.id.recordName { selectedPostID = nil }
                    updateFilteredPosts()
                    print("🛠️ [DEBUG] Removed post from archived list after successful unarchive: \(post.id.recordName)")
                    NotificationCenter.default.post(name: .newsFeedRefresh, object: nil)
                    NotificationCenter.default.post(name: .postUnarchived, object: nil)
                    unarchiveSuccessMessage = isSpanish ? "Post desarchivado con éxito" : "Post successfully unarchived"
                    
                    // Show standardized success alert instead of toast
                    let alert = NSAlert()
                    alert.messageText = isSpanish ? "Operación Exitosa" : "Operation Successful"
                    alert.informativeText = unarchiveSuccessMessage
                    alert.addButton(withTitle: "OK")
                    alert.alertStyle = .informational
                    
                    print("📰 [DEBUG] Showing unarchive success alert")
                    DispatchQueue.main.async {
                        let _ = alert.runModal()
                        print("📰 [DEBUG] Unarchive success alert dismissed")
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    let errorDescription = error.localizedDescription
                    print("📰 ❌ [\(Date())] Error unarchiving post: \(errorDescription)")
                    errorMessage = isSpanish ? "Error al desarchivar: \(errorDescription)" : "Error unarchiving: \(errorDescription)"
                }
            }
        }
    }

    /// Create a new news feed item from an archived post
    private func createNewsFeedItem(from post: ModelsArchivedNewsPost) -> CKRecord {
        let newsFeedItem = CKRecord(recordType: "NewsFeedItem")
        // Copy data from the archived post
        newsFeedItem["title"] = post.title
        newsFeedItem["datePosted"] = post.datePosted // Or should this be Date()?
        newsFeedItem["recordNameMirror"] = "NewsFeed-\(UUID().uuidString)" // Generate a new mirror? Or use original? Needs clarification.
        newsFeedItem["pdfReference"] = post.pdfReference // Copy reference
        // Always set scheduledDate, fallback to datePosted
        newsFeedItem["scheduledDate"] = post.datePosted
        print("🛠️ [DEBUG] createNewsFeedItem: Setting scheduledDate to \(String(describing: newsFeedItem["scheduledDate"]))")
        // Optionally set isArchived and datePublished if needed
        return newsFeedItem
    }

    /// Asynchronously loads a PDFDocument from a post's reference/details for the detail view.
    private func loadPDFForDetailView(post: ModelsArchivedNewsPost) {
         guard let pdfRef = post.pdfReference else {
            print("❌ ArchivedNews PDF: loadPDFForDetailView called without a PDF reference.")
             return
         }

         guard !isLoadingPDFForDetail else {
             print("❌ ArchivedNews PDF: Already loading PDF for detail view, ignoring request.")
            return
        }

         print("🔄 ArchivedNews PDF: Starting async load for detail PDF: \(post.title)")
         print("🔄 ArchivedNews PDF: Reference ID: \(pdfRef.recordID.recordName)")
        
        isLoadingPDFForDetail = true
        pdfLoadErrorForDetail = nil
        loadedPdfDocumentForDetail = nil // Clear previous doc

        Task {
            do {
                // Fetch the PDF record (PDFDocumentItem) using the reference
                print("🔄 ArchivedNews PDF: Fetching record from CloudKit: \(pdfRef.recordID.recordName)")
                 let record = try await database.record(for: pdfRef.recordID)
                print("✅ ArchivedNews PDF: Successfully fetched record from CloudKit")
                print("📄 ArchivedNews PDF: Record keys: \(record.allKeys().joined(separator: ", "))")
                
                 guard let fileURL = (record["pdfFile"] as? CKAsset)?.fileURL else {
                    print("❌ ArchivedNews PDF: PDF asset not found on record or has no file URL")
                    if let _ = record["pdfFile"] as? CKAsset {
                        print("❌ ArchivedNews PDF: Asset exists but fileURL is nil")
                    } else {
                        print("❌ ArchivedNews PDF: No 'pdfFile' asset found on record")
                        print("❌ ArchivedNews PDF: Record keys: \(record.allKeys().joined(separator: ", "))")
                    }
                     throw NSError(domain: "PDFLoadError", code: 2, userInfo: [NSLocalizedDescriptionKey: "PDF asset not found on record or has no file URL."])
                 }
                
                print("🔄 ArchivedNews PDF: Asset fileURL: \(fileURL.path)")
                
                // Check if file exists and get file size
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: fileURL.path) {
                    if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                       let fileSize = attributes[.size] as? Int64 {
                        print("✅ ArchivedNews PDF: File exists at path, size: \(fileSize) bytes")
                        if fileSize == 0 {
                            print("❌ ArchivedNews PDF: File exists but is empty (0 bytes)")
                        }
                    } else {
                        print("⚠️ ArchivedNews PDF: File exists but could not get attributes")
                    }
                } else {
                    print("❌ ArchivedNews PDF: File does not exist at path: \(fileURL.path)")
                    throw NSError(domain: "PDFLoadError", code: 3, userInfo: [NSLocalizedDescriptionKey: "PDF file not found at expected location."])
                }

                 // Load PDFDocument from URL
                print("🔄 ArchivedNews PDF: Creating PDFDocument from URL")
                 let pdfDoc = PDFDocument(url: fileURL)
                
                if pdfDoc == nil {
                    print("❌ ArchivedNews PDF: PDFDocument(url:) returned nil")
                    
                    // Try with data as fallback
                    print("🔄 ArchivedNews PDF: Attempting to load via Data method instead")
                    do {
                        let pdfData = try Data(contentsOf: fileURL)
                        print("✅ ArchivedNews PDF: Successfully read \(pdfData.count) bytes")
                        let dataDoc = PDFDocument(data: pdfData)
                        if dataDoc == nil {
                            print("❌ ArchivedNews PDF: PDFDocument(data:) also returned nil")
                        } else {
                            print("✅ ArchivedNews PDF: Successfully created PDF from data with \(dataDoc!.pageCount) pages")
                        }
                    } catch {
                        print("❌ ArchivedNews PDF: Error reading file data: \(error.localizedDescription)")
                    }
                } else {
                    print("✅ ArchivedNews PDF: Successfully created PDFDocument with \(pdfDoc!.pageCount) pages")
                }

                // Update state on the main thread
                 await MainActor.run {
                     if let loadedDoc = pdfDoc, loadedDoc.pageCount > 0 {
                         print("✅ ArchivedNews PDF: Successfully loaded PDF document for detail view '\(post.title)' with \(loadedDoc.pageCount) pages.")
                         self.loadedPdfDocumentForDetail = loadedDoc
                     } else {
                         let errorMsg = isSpanish ? "Error al cargar el documento PDF o está vacío." : "Error loading PDF document or it is empty."
                         print("❌ ArchivedNews PDF: Failed to load PDF document for detail or document has 0 pages: \(post.title)")
                         self.pdfLoadErrorForDetail = errorMsg
                     }
                     self.isLoadingPDFForDetail = false
                 }
            } catch {
                 let errorDescription = error.localizedDescription
                 print("❌ ArchivedNews PDF: Error loading PDF document for detail view: \(errorDescription)")
                 
                 if let ckError = error as? CKError {
                     print("❌ ArchivedNews PDF: CloudKit error: \(ckError.code.rawValue) - \(ckError.localizedDescription)")
                 }
                 
                 await MainActor.run {
                     self.pdfLoadErrorForDetail = isSpanish ? "Error al cargar PDF: \(errorDescription)" : "Error loading PDF: \(errorDescription)"
                     self.isLoadingPDFForDetail = false
                     self.loadedPdfDocumentForDetail = nil // Ensure it's nil on error
                 }
            }
        }
    }

    // Date formatter
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = isSpanish ? Locale(identifier: "es_ES") : Locale(identifier: "en_US")
        print("🌐 ArchivedNewsView dateFormatter - isSpanish: \(isSpanish), locale: \(formatter.locale.identifier), example date: \(formatter.string(from: Date()))")
        return formatter
    }

    // Add PDF loading for row
    private func loadPDFForRow(post: ModelsArchivedNewsPost) {
        guard let pdfRef = post.pdfReference else { 
            print("❌ ArchivedNews PDF: loadPDFForRow called without a PDF reference.")
            return 
        }
        
        isLoadingPDFForDetail = true
        pdfLoadErrorForDetail = nil
        pdfToShow = nil
        
        print("🔄 ArchivedNews PDF: loadPDFForRow - Starting PDF load for post: \(post.title)")
        print("🔄 ArchivedNews PDF: loadPDFForRow - Reference ID: \(pdfRef.recordID.recordName)")
        
        Task {
            do {
                print("🔄 ArchivedNews PDF: loadPDFForRow - Fetching record from CloudKit")
                let record = try await database.record(for: pdfRef.recordID)
                print("✅ ArchivedNews PDF: loadPDFForRow - Successfully fetched record")
                print("📄 ArchivedNews PDF: loadPDFForRow - Record keys: \(record.allKeys().joined(separator: ", "))")
                
                guard let fileURL = (record["pdfFile"] as? CKAsset)?.fileURL else {
                    print("❌ ArchivedNews PDF: loadPDFForRow - PDF asset not found or has no file URL")
                    throw NSError(domain: "PDFLoadError", code: 2, userInfo: [NSLocalizedDescriptionKey: "PDF asset not found on record or has no file URL."])
                }
                
                print("🔄 ArchivedNews PDF: loadPDFForRow - Asset fileURL: \(fileURL.path)")
                
                // Check if file exists and get file size
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: fileURL.path) {
                    if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                       let fileSize = attributes[.size] as? Int64 {
                        print("✅ ArchivedNews PDF: loadPDFForRow - File exists, size: \(fileSize) bytes")
                        if fileSize == 0 {
                            print("❌ ArchivedNews PDF: loadPDFForRow - File exists but is empty (0 bytes)")
                        }
                    }
                } else {
                    print("❌ ArchivedNews PDF: loadPDFForRow - File does not exist at path")
                    throw NSError(domain: "PDFLoadError", code: 3, userInfo: [NSLocalizedDescriptionKey: "PDF file not found at expected location."])
                }
                
                print("🔄 ArchivedNews PDF: loadPDFForRow - Creating PDFDocument from URL")
                let pdfDoc = PDFDocument(url: fileURL)
                
                if pdfDoc == nil {
                    print("❌ ArchivedNews PDF: loadPDFForRow - PDFDocument(url:) returned nil")
                    // Try with data
                    print("🔄 ArchivedNews PDF: loadPDFForRow - Attempting to load via Data method")
                    let pdfData = try Data(contentsOf: fileURL)
                    print("✅ ArchivedNews PDF: loadPDFForRow - Read \(pdfData.count) bytes")
                    let dataDoc = PDFDocument(data: pdfData)
                    
                    if dataDoc == nil {
                        print("❌ ArchivedNews PDF: loadPDFForRow - PDFDocument(data:) also returned nil")
                    }
                    
                    await MainActor.run {
                        isLoadingPDFForDetail = false
                        if let loadedDoc = dataDoc, loadedDoc.pageCount > 0 {
                            print("✅ ArchivedNews PDF: loadPDFForRow - Successfully created PDF from data with \(loadedDoc.pageCount) pages")
                            pdfToShow = loadedDoc
                            showPDFSheet = true
                        } else {
                            pdfLoadErrorForDetail = isSpanish ? "Error al cargar el documento PDF o está vacío." : "Error loading PDF document or it is empty."
                        }
                    }
                } else {
                    await MainActor.run {
                        isLoadingPDFForDetail = false
                        if pdfDoc!.pageCount > 0 {
                            print("✅ ArchivedNews PDF: loadPDFForRow - Successfully created PDF with \(pdfDoc!.pageCount) pages")
                            pdfToShow = pdfDoc
                            showPDFSheet = true
                        } else {
                            print("❌ ArchivedNews PDF: loadPDFForRow - PDF has 0 pages")
                            pdfLoadErrorForDetail = isSpanish ? "El documento PDF está vacío." : "PDF document is empty."
                        }
                    }
                }
            } catch {
                let errorDescription = error.localizedDescription
                print("❌ ArchivedNews PDF: loadPDFForRow - Error: \(errorDescription)")
                
                if let ckError = error as? CKError {
                    print("❌ ArchivedNews PDF: loadPDFForRow - CloudKit error: \(ckError.code.rawValue) - \(ckError.localizedDescription)")
                }
                
                await MainActor.run {
                    isLoadingPDFForDetail = false
                    pdfLoadErrorForDetail = isSpanish ? "Error al cargar PDF: \(errorDescription)" : "Error loading PDF: \(errorDescription)"
                }
            }
        }
    }

    private func triggerDeleteAlert(for post: ModelsArchivedNewsPost) {
        print("📰 [IMPORTANT] Triggering delete alert for post: \(post.title)")
        
        let alert = NSAlert()
        alert.messageText = isSpanish ? "¿Eliminar post?" : "Delete Post?"
        alert.informativeText = isSpanish ? "Esta acción no se puede deshacer." : "This action cannot be undone."
        alert.addButton(withTitle: isSpanish ? "Eliminar" : "Delete")
        alert.addButton(withTitle: isSpanish ? "Cancelar" : "Cancel")
        alert.alertStyle = .critical
        
        // Run on the main thread to ensure UI updates
        DispatchQueue.main.async {
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                print("🛠️ [IMPORTANT] User confirmed delete")
                if let post = self.postToDelete {
                    self.deleteArchivedPost(post)
                }
            } else {
                print("🛠️ [IMPORTANT] User cancelled delete")
            }
            self.postToDelete = nil
        }
    }

    private func triggerUnarchiveAlert(for post: ModelsArchivedNewsPost) {
        print("📰 [IMPORTANT] Triggering unarchive alert for post: \(post.title)")
        
        let alert = NSAlert()
        alert.messageText = isSpanish ? "¿Desarchivar post?" : "Unarchive Post?"
        alert.informativeText = isSpanish ? "Este post volverá a aparecer en la lista principal de noticias." : "This post will be moved back to the main news feed."
        alert.addButton(withTitle: isSpanish ? "Desarchivar" : "Unarchive")
        alert.addButton(withTitle: isSpanish ? "Cancelar" : "Cancel")
        alert.alertStyle = .informational
        
        // Run on the main thread to ensure UI updates
        DispatchQueue.main.async {
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                print("🛠️ [IMPORTANT] User confirmed unarchive")
                if let post = self.postToUnarchive {
                    self.unarchivePost(post)
                }
            } else {
                print("🛠️ [IMPORTANT] User cancelled unarchive")
            }
            self.postToUnarchive = nil
        }
    }
}

// MARK: - Archived News Post Row
struct ArchivedNewsPostRow: View {
    // MARK: - Properties
    let post: ModelsArchivedNewsPost
    let isSpanish: Bool
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = isSpanish ? Locale(identifier: "es_ES") : Locale(identifier: "en_US")
        return formatter
    }
    
    // MARK: - View Body
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // PDF thumbnail or fallback icon
            if post.pdfReference != nil {
                // Use a colored thumbnail for PDFs (match News Management style)
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(red: 0.93, green: 0.32, blue: 0.24))
                        .frame(width: 32, height: 32)
                    Text("E\nX\nP\nO")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .frame(width: 32, height: 32)
                }
            } else {
                Image(systemName: "doc.text")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .foregroundColor(.gray)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(post.title)
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                // Show PDF file name if available from pdfDocument
                if let pdfDoc = post.pdfDocument, !pdfDoc.title.isEmpty {
                    Text(pdfDoc.title)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                Text(dateFormatter.string(from: post.datePosted))
                    .font(.caption2)
                    .foregroundColor(.green)
                    }
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview
#Preview {
    ArchivedNewsView(isSpanish: .constant(false), refreshTrigger: .constant(false))
}

// Helper function for consistent logging


