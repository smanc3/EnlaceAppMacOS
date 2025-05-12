//
//  ArchivedNewsView.swift
//  Enlace Admin (Preview)
//
//  Created on 5/21/25.
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
    @State private var selectedPostID: CKRecord.ID? = nil
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
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            // Search and filters
            HStack {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField(isSpanish ? "Buscar por título..." : "Search by title...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: searchText) { _, _ in
                            updateFilteredPosts()
                        }
                }
                .padding(.trailing)
                
                Picker(isSpanish ? "Ordenar" : "Sort", selection: $sortOption) {
                    ForEach([SortOption.dateArchived, .datePosted, .title], id: \.self) { option in
                        Text(option.localizedName(isSpanish: isSpanish)).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
                .onChange(of: sortOption) { _, _ in
                    updateFilteredPosts()
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.textBackgroundColor))
            
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(message: error)
            } else if archivedPosts.isEmpty {
                emptyStateView
            } else {
                HStack(spacing: 0) {
                    VStack {
                        List(selection: $selectedPostID) {
                            ForEach(filteredAndSortedPosts) { post in
                                ArchivedNewsPostRow(
                                    post: post,
                                    isSpanish: isSpanish
                                )
                                .tag(post.id)
                                .contentShape(Rectangle())
                                .background(selectedPostID == post.id ? Color.blue.opacity(0.1) : Color.clear)
                            }
                        }
                        .listStyle(.inset)
                    }
                    .frame(minWidth: 300)
                    
                    Divider()
                    
                    // Detail panel
                    if let selectedID = selectedPostID, let post = archivedPosts.first(where: { $0.id == selectedID }) {
                        detailView(post: post)
                    } else {
                        emptyDetailView
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            print("ArchivedNewsView appeared")
            self.loadArchivedPosts()
            self.setupNotifications()
        }
        .onDisappear {
            self.removeNotifications()
        }
        .onChange(of: refreshTrigger) { oldValue, newValue in
            if newValue {
                self.loadArchivedPosts()
                refreshTrigger = false
            }
        }
        .alert(isSpanish ? "¿Eliminar este post?" : "Delete this post?", isPresented: $showDeleteConfirmation) {
            Button(isSpanish ? "Eliminar" : "Delete", role: .destructive) { 
                if let post = postToDelete { 
                    self.deleteArchivedPost(post)
                    selectedPostID = nil 
                }
            }
            Button(isSpanish ? "Cancelar" : "Cancel", role: .cancel) {}
        } message: { 
            Text(isSpanish ? "Esta acción no se puede deshacer." : "This action cannot be undone.")
        }
        .alert(isSpanish ? "¿Desarchivar este post?" : "Unarchive this post?", isPresented: $showUnarchiveConfirmation) {
            Button(isSpanish ? "Desarchivar" : "Unarchive", role: .none) { 
                if let post = postToUnarchive { 
                    self.unarchivePost(post)
                    selectedPostID = nil 
                } 
            }
            Button(isSpanish ? "Cancelar" : "Cancel", role: .cancel) {}
        } message: { 
            Text(isSpanish ? "Este post volverá a aparecer en la lista principal de noticias." : "This post will be moved back to the main news feed.")
        }
    }
    
    // Update filtered posts when search or sort changes
    private func updateFilteredPosts() {
        // First apply search filtering
        var filtered: [ModelsArchivedNewsPost] = []
        
        if searchText.isEmpty {
            filtered = archivedPosts
        } else {
            for post in archivedPosts {
                if post.title.localizedCaseInsensitiveContains(searchText) {
                    filtered.append(post)
                }
            }
        }
        
        // Then apply sorting
        switch sortOption {
        case .dateArchived:
            filtered.sort { $0.archivedDate > $1.archivedDate }
        case .datePosted:
            filtered.sort { $0.datePosted > $1.datePosted }
        case .title:
            filtered.sort { $0.title < $1.title }
        }
        
        // Update the stored property
        filteredAndSortedPosts = filtered
    }
    
    // MARK: - Subviews
    
    /// Loading indicator view
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text(isSpanish ? "Cargando noticias archivadas..." : "Loading archived news...")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding()
            Spacer()
        }
    }
    
    /// Error message view
    private func errorView(message: String) -> some View {
        VStack {
             Spacer()
             Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundColor(.orange)
             Text(message).padding()
             Button("Retry") { 
                 self.loadArchivedPosts() 
             }.buttonStyle(.bordered)
             Spacer()
        }
    }
    
    /// Empty state view when no posts are available
    private var emptyStateView: some View {
        VStack {
            Spacer()
            Image(systemName: "archivebox").font(.largeTitle).foregroundColor(.gray)
            Text(isSpanish ? "No hay noticias archivadas" : "No archived news").font(.headline)
            Spacer()
        }
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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header section
                VStack(alignment: .leading, spacing: 12) {
                    Text(post.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Divider()
                    
                    // Dates
                    Group {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                            Text(isSpanish ? "Fecha de publicación:" : "Post date:")
                                .fontWeight(.medium)
                            Text(dateFormatter.string(from: post.datePosted))
                        }
                        
                        HStack {
                            Image(systemName: "archivebox")
                                .foregroundColor(.orange)
                            Text(isSpanish ? "Fecha de archivo:" : "Archive date:")
                                .fontWeight(.medium)
                            Text(dateFormatter.string(from: post.archivedDate))
                        }
                    }
                    
                    Divider()
                    
                    // Content section - just use a placeholder
                    Text(isSpanish ? "Contenido:" : "Content:")
                        .font(.headline)
                        .padding(.top, 8)
                    
                    Text(isSpanish ? "Contenido no disponible en la vista previa" : "Content not available in preview")
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(8)
                }
                .padding()
                
                Spacer()
                
                // Action buttons
                HStack {
                    Spacer()
                    
                    Button(action: {
                        postToUnarchive = post
                        showUnarchiveConfirmation = true
                    }) {
                        Label(isSpanish ? "Desarchivar" : "Unarchive", systemImage: "arrow.up.bin")
                    }
                    .buttonStyle(.bordered)
                    
                    Button(role: .destructive, action: {
                        postToDelete = post
                        showDeleteConfirmation = true
                    }) {
                        Label(isSpanish ? "Eliminar" : "Delete", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Methods
    
    /// Set up notification observers
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("ArchivedNewsPostNotification"),
            object: nil,
            queue: .main
        ) { _ in
            print("Received notification of newly archived post, refreshing...")
            self.loadArchivedPosts()
        }
    }

    /// Remove notification observers
    private func removeNotifications() {
        NotificationCenter.default.removeObserver(
            self,
            name: Notification.Name("ArchivedNewsPostNotification"),
            object: nil
        )
    }

    /// Load archived posts from CloudKit
    private func loadArchivedPosts() {
        isLoading = true
        errorMessage = nil
        
        print("Starting to load archived news posts")
        
        Task {
            do {
                let accountStatus = try await container.accountStatus()
                print("iCloud account status: \(accountStatus.rawValue)")
                
                switch accountStatus {
                case .available:
                    print("iCloud account available, fetching posts")
                    let posts = try await fetchArchivedPosts()
                    await MainActor.run {
                        self.archivedPosts = posts
                        self.isLoading = false
                        print("Loaded \(posts.count) archived news posts")
                        self.updateFilteredPosts()
                    }
                case .noAccount:
                    await MainActor.run {
                        self.isLoading = false
                        print("No iCloud account found")
                        self.errorMessage = isSpanish ?
                            "No se ha iniciado sesión en iCloud. Por favor, inicie sesión en Preferencias del Sistema." :
                            "No iCloud account found. Please sign in through System Preferences."
                    }
                case .restricted:
                    await MainActor.run {
                        self.isLoading = false
                        print("iCloud account is restricted")
                        self.errorMessage = isSpanish ?
                            "El acceso a iCloud está restringido. Verifique los controles parentales." :
                            "iCloud access is restricted. Check parental controls."
                    }
                case .couldNotDetermine:
                    await MainActor.run {
                        self.isLoading = false
                        print("Could not determine iCloud account status")
                        self.errorMessage = isSpanish ?
                            "No se pudo determinar el estado de la cuenta de iCloud. Verifique su conexión." :
                            "Could not determine iCloud account status. Check your connection."
                    }
                case .temporarilyUnavailable:
                    await MainActor.run {
                        self.isLoading = false
                        print("iCloud account is temporarily unavailable")
                        self.errorMessage = isSpanish ?
                            "La cuenta de iCloud está temporalmente no disponible. Intente más tarde." :
                            "iCloud account is temporarily unavailable. Try again later."
                    }
                @unknown default:
                    await MainActor.run {
                        self.isLoading = false
                        print("Unknown iCloud account status")
                        self.errorMessage = isSpanish ?
                            "Estado desconocido de la cuenta de iCloud. Intente reiniciar la aplicación." :
                            "Unknown iCloud account status. Try restarting the app."
                    }
                }
            } catch {
                await handleFetchError(error, recordType: "ArchivedNewsPost", function: "loadArchivedPosts")
            }
        }
    }

    /// Fetch archived posts from CloudKit with primary and fallback methods
    private func fetchArchivedPosts() async throws -> [ModelsArchivedNewsPost] {
        print("Using fallback methods to fetch archived posts")
        return try await fetchPostsWithFallbackMethod()
    }

    /// Fallback method: Search for archived posts through various methods
    private func fetchPostsWithFallbackMethod() async throws -> [ModelsArchivedNewsPost] {
        print("Attempting fallback method to retrieve archived posts")
        
        // Try finding archived PDFs first (seems most reliable based on history)
        let postsFromPDFs = try await fetchArchivedPostsFromPDFs()
        if !postsFromPDFs.isEmpty {
            return postsFromPDFs
        }
        
        // Then try alternative types
        print("No posts found via PDFs, trying alternate types")
        return try await fetchPostsWithAlternativeTypes()
    }

    /// Fetch archived posts by looking for PDFs marked as archived
    private func fetchArchivedPostsFromPDFs() async throws -> [ModelsArchivedNewsPost] {
        print("Searching for archived posts")
        
        // Search for *PDFs* (PDFDocumentItem) that are marked as archived
        // NOTE: The schema shows PDFDocumentItem has no 'isArchived' field.
        // History suggests we were checking this, perhaps it was on the NewsFeedItem?
        // Let's assume for now we just look for ArchivedNewsPost records directly,
        // as the PDF-based approach seems problematic with the current schema.
        // Reverting to a simpler fetch of ArchivedNewsPost.
        
        print("Revising strategy: Directly fetching ArchivedNewsPost records.")
        
        // Instead of a generic predicate, use one that forces CloudKit to use the archivedDate index
        // let query = CKQuery(recordType: "ArchivedNewsPost", predicate: NSPredicate(value: true))
        
        // Create a predicate that will always be true but explicitly references archivedDate
        // "archivedDate <= %@" with a date far in the future will match all records
        let farFutureDate = Date().addingTimeInterval(10*365*24*60*60) // ~10 years in the future
        let predicate = NSPredicate(format: "archivedDate <= %@", farFutureDate as NSDate)
        
        let query = CKQuery(recordType: "ArchivedNewsPost", predicate: predicate)
        query.sortDescriptors = nil // Keep sort descriptors nil
        
        // Log details before executing the query
        print("Executing query: recordType=\(query.recordType), predicate=\(query.predicate), sortDescriptors=\(query.sortDescriptors ?? [])")
        
        let (results, _) = try await database.records(matching: query)
        var fetchedPosts: [ModelsArchivedNewsPost] = []
        
        for (_, recordResult) in results {
            if case .success(let record) = recordResult {
                print("Found ArchivedNewsPost: \(record.recordID.recordName)")
                fetchedPosts.append(ModelsArchivedNewsPost(record: record))
            }
        }
        print("Found \(fetchedPosts.count) ArchivedNewsPost records")
        
        // Sort the fetched results in memory instead
        if !fetchedPosts.isEmpty {
            fetchedPosts.sort { $0.archivedDate > $1.archivedDate } // Sort by archivedDate descending
            print("Sorted \(fetchedPosts.count) posts by archivedDate (descending)")
        }
        
        return fetchedPosts
    }

    /// Try fetching posts using alternative record types
    private func fetchPostsWithAlternativeTypes() async throws -> [ModelsArchivedNewsPost] {
        // This might be redundant if fetchArchivedPostsFromPDFs directly fetches ArchivedNewsPost
        print("Fallback: Trying alternate record types (ArchivedPost, ArchivedNewsFeedItem)")

        let alternateTypes = ["ArchivedPost", "ArchivedNewsFeedItem"] // Removed ArchivedNewsPost as it's tried first now

        for type in alternateTypes {
            do {
                let typeQuery = CKQuery(recordType: type, predicate: NSPredicate(value: true))
                // No sort descriptors
                print("Querying \(type) without sort descriptors")
                
                // Log details before executing the query
                print("Executing query: recordType=\(typeQuery.recordType), predicate=\(typeQuery.predicate), sortDescriptors=\(typeQuery.sortDescriptors ?? [])")

                let (altResults, _) = try await database.records(matching: typeQuery)

                var altRecords: [CKRecord] = []
                for (_, recordResult) in altResults {
                    if case .success(let record) = recordResult {
                        altRecords.append(record)
                        print("Found record of type \(type): \(record.recordID.recordName)")
                    }
                }

                if !altRecords.isEmpty {
                    print("Found \(altRecords.count) records of type \(type)")
                    // Convert these records to ModelsArchivedNewsPost if possible (might require adjustments)
                    print("Warning: Conversion from \(type) to ModelsArchivedNewsPost might be lossy.")
                    return altRecords.map { ModelsArchivedNewsPost(record: $0) } // Simplified conversion
                }
            } catch {
                print("Error fetching \(type): \(error.localizedDescription)")
                // Consider if we should re-throw or log specific error types here
            }
        }
        
        print("No archived posts found after all fallback attempts")
        return []
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
        print("Attempting to delete post: \(post.title)")

        Task {
            do {
                // Use post.id directly as the API expects a String, not a CKRecord.ID
                try await database.deleteRecord(withID: post.id)
                await MainActor.run {
                    isLoading = false
                    print("Successfully deleted archived post")
                    archivedPosts.removeAll { $0.id == post.id }
                    if selectedPostID == post.id { selectedPostID = nil } // Clear selection if deleted
                    updateFilteredPosts() // Update filtered posts
                    NotificationCenter.default.post(name: Notification.Name("NewsFeedRefreshNotification"), object: nil)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    let errorDescription = error.localizedDescription
                    print("Error deleting archived post: \(errorDescription)")
                    errorMessage = isSpanish ? "Error al eliminar: \(errorDescription)" : "Error deleting: \(errorDescription)"
                }
            }
        }
    }

    /// Unarchive a post (move it back to the news feed)
    private func unarchivePost(_ post: ModelsArchivedNewsPost) {
        isLoading = true
        print("Attempting to unarchive post: \(post.title)")

        Task {
            do {
                // Step 1: Create and save a new news feed item
                let newsFeedItem = createNewsFeedItem(from: post)
                _ = try await database.save(newsFeedItem)
                print("Successfully created new NewsFeedItem from unarchived post")

                // Step 2: Delete the archived post record
                // Use post.id directly as the API expects a String
                try await database.deleteRecord(withID: post.id)

                await MainActor.run {
                    isLoading = false
                    print("Successfully unarchived post")
                    archivedPosts.removeAll { $0.id == post.id }
                     if selectedPostID == post.id { selectedPostID = nil } // Clear selection if unarchived
                     updateFilteredPosts() // Update filtered posts
                    NotificationCenter.default.post(name: Notification.Name("NewsFeedRefreshNotification"), object: nil)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    let errorDescription = error.localizedDescription
                    print("Error unarchiving post: \(errorDescription)")
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
        // newsFeedItem["isArchived"] = 0 // Explicitly set to not archived? Schema has isArchived on NewsFeedItem
        // newsFeedItem["datePublished"] = Date() // Set publish date?
        
        return newsFeedItem
    }

    /// Asynchronously loads a PDFDocument from a post's reference/details for the detail view.
    private func loadPDFForDetailView(post: ModelsArchivedNewsPost) {
         guard let pdfRef = post.pdfReference else {
            print("loadPDFForDetailView called without a PDF reference.")
             return
         }

         guard !isLoadingPDFForDetail else {
             print("Already loading PDF for detail view, ignoring request.")
            return
        }

         print("Starting async load for detail PDF: \(post.title)")
        isLoadingPDFForDetail = true
        pdfLoadErrorForDetail = nil
        loadedPdfDocumentForDetail = nil // Clear previous doc

        Task {
            do {
                // Fetch the PDF record (PDFDocumentItem) using the reference
                 let record = try await database.record(for: pdfRef.recordID)
                 guard let asset = record["pdfFile"] as? CKAsset, let fileURL = asset.fileURL else {
                     throw NSError(domain: "PDFLoadError", code: 2, userInfo: [NSLocalizedDescriptionKey: "PDF asset not found on record or has no file URL."])
                 }

                 // Load PDFDocument from URL
                 let pdfDoc = PDFDocument(url: fileURL)

                // Update state on the main thread
                 await MainActor.run {
                     if let loadedDoc = pdfDoc, loadedDoc.pageCount > 0 {
                         print("Successfully loaded PDF document for detail view '\(post.title)' with \(loadedDoc.pageCount) pages.")
                         self.loadedPdfDocumentForDetail = loadedDoc
                     } else {
                         let errorMsg = isSpanish ? "Error al cargar el documento PDF o está vacío." : "Error loading PDF document or it is empty."
                          print("Failed to load PDF document for detail or document has 0 pages: \(post.title)")
                         self.pdfLoadErrorForDetail = errorMsg
                     }
                     self.isLoadingPDFForDetail = false
                 }
            } catch {
                 let errorDescription = error.localizedDescription
                  print("Error loading PDF document for detail view: \(errorDescription)")
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
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}

// MARK: - Archived News Post Row
struct ArchivedNewsPostRow: View {
    // MARK: - Properties
    let post: ModelsArchivedNewsPost
    let isSpanish: Bool
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    // MARK: - View Body
    var body: some View {
        HStack(spacing: 15) {
            // PDF indicator or icon
            if post.pdfReference != nil {
                Image(systemName: "doc.text.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "newspaper.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
                    .frame(width: 24, height: 24)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(post.title)
                    .fontWeight(.medium)
                
                HStack {
                    // Post date
                    Label {
                        Text(dateFormatter.string(from: post.datePosted))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } icon: {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Archive date
                    Label {
                        Text(dateFormatter.string(from: post.archivedDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } icon: {
                        Image(systemName: "archivebox")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
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


