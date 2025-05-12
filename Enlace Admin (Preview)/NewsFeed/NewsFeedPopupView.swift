//
//  NewsFeedPopupView.swift
//  Enlace Admin (Preview)
//
//  Created by Admin on 4/8/25.
//

import SwiftUI
import UniformTypeIdentifiers
import PDFKit
import CloudKit
import AppKit

// MARK: - PDFKitView

/// A SwiftUI view that wraps `PDFView` from PDFKit to display PDF documents in a macOS app.
struct PDFKitView: NSViewRepresentable {
    /// The `PDFDocument` to be displayed.
    let pdfDocument: PDFKit.PDFDocument
    
    /// Initializes the view with a `PDFDocument`.
    /// - Parameter pdfDoc: The `PDFDocument` instance to show.
    init(showing pdfDoc: PDFKit.PDFDocument) {
        print("📄 PDFKitView: Initializing with document, page count: \(pdfDoc.pageCount)")
        self.pdfDocument = pdfDoc
    }
    
    /// Creates and configures the `PDFView` instance.
    /// - Parameter context: The context in which the view is created.
    /// - Returns: A configured `PDFView` instance.
    func makeNSView(context: Context) -> PDFView {
        print("📄 PDFKitView: Creating PDFView")
        let pdfView = PDFView()
        
        // Enable layer-backed view for better performance
        pdfView.wantsLayer = true
        
        // Configure PDFView properties
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        pdfView.autoScales = true // Let PDFKit handle scaling
        pdfView.backgroundColor = .clear // No background
        pdfView.displayBox = .cropBox // Best for viewing
        
        // Apply document and configure page
        pdfView.document = pdfDocument
        
        // Set initial scale and position
        if let firstPage = pdfDocument.page(at: 0) {
            pdfView.go(to: firstPage)
        }
        
        return pdfView;
    }
    
    /// Updates the `PDFView` when the SwiftUI view's state changes.
    /// - Parameters:
    ///   - pdfView: The `PDFView` instance to update.
    ///   - context: The context containing information about the update.
    func updateNSView(_ pdfView: PDFView, context: Context) {
        pdfView.document = pdfDocument
        if let firstPage = pdfDocument.page(at: 0) {
            pdfView.go(to: firstPage)
        }
    }
    
    // Define types explicitly to avoid ambiguity
    typealias NSViewType = PDFView
    typealias Context = NSViewRepresentableContext<PDFKitView>
}

// MARK: - NewsFeedPopupView

/// The primary view for creating and editing news items
struct NewsFeedPopupView: View {
    // MARK: - Properties
    
    // Optional binding to control dismissal from parent view
    var onDismiss: (() -> Void)?
    
    // Add a static property to track when the last notification was sent
    private static var lastNotificationTime: Date = Date(timeIntervalSince1970: 0)
    private static let minimumNotificationInterval: TimeInterval = 2.0 // 2 seconds between identical notifications
    
    // MARK: - State Properties
    
    @State private var title: String = ""
    @State private var showPDFSelector: Bool = false
    @State private var selectedPDFURL: URL?
    @State private var selectedFileLabel: String = ""
    @State private var selectedPDFRecord: CKRecord?
    @State private var isSpanish = false
    @State private var isPublishing: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var validationMessage: String = ""
    @State private var uploadProgress: Double = 0.0
    @State private var showValidationMessage: Bool = false
    @State private var linkURL: String = ""
    @State private var description: String = ""
    @State private var pdfDocument: PDFDocument? = nil
    @State private var scheduledDate: Date? = nil
    @State private var pdfThumbnail: NSImage? = nil
    @State private var fileImporterIsPresented: Bool = false
    @State private var showPostConfirmation: Bool = false
    @State private var showPostSuccess: Bool = false
    
    // MARK: - CloudKit Properties
    private var cloudKitContainer: CKContainer { CKContainer(identifier: "iCloud.PearInc.EICT-iOS-16") }
    private var publicDatabase: CKDatabase { cloudKitContainer.publicCloudDatabase }
    
    // MARK: - Debug Logging
    
    private func logDebug(_ message: String) {
        print("📰 NewsFeedPopupView: \(message)")
    }
    
    private func logImportant(_ message: String) {
        print("‼️ [IMPORTANT] NewsFeedPopupView: \(message)")
    }
    
    private func logAction(_ action: String, _ details: String) {
        print("🔶 [ACTION] NewsFeedPopupView - \(action): \(details)")
    }
    
    // Standardized error message display
    private func showErrorMessage(_ message: String) {
        logAction("ERROR", "Showing error message: \(message)")
        
        // Update state to show alert
        self.alertTitle = isSpanish ? "Error" : "Error"
        self.alertMessage = message
        self.showAlert = true
    }
    
    // Add a more robust confirmation system
    private func showConfirmationDialog(title: String, message: String, confirmAction: @escaping () -> Void) {
        logAction("CONFIRM", "Creating confirmation dialog: \(title)")
        self.alertTitle = title
        self.alertMessage = message
        
        // Create and present the alert directly to ensure it shows
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: isSpanish ? "Publicar" : "Post")
        alert.addButton(withTitle: isSpanish ? "Cancelar" : "Cancel")
        
        // Run on the main thread to ensure UI updates
        DispatchQueue.main.async {
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                self.logAction("CONFIRM", "User confirmed action")
                confirmAction()
            } else {
                self.logAction("CONFIRM", "User cancelled action")
            }
        }
    }
    
    // Add a success message display function
    private func showSuccessMessage(_ message: String, onDismiss: (() -> Void)? = nil) {
        logAction("SUCCESS", "Showing success message: \(message)")
        
        // Create and present the success alert directly
        let alert = NSAlert()
        alert.messageText = isSpanish ? "Éxito" : "Success" 
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        
        // Run on the main thread to ensure UI updates
        DispatchQueue.main.async {
            let _ = alert.runModal()
            self.logAction("SUCCESS", "Success alert dismissed")
            if let dismiss = onDismiss {
                dismiss()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        let hasTitle = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasPDF = selectedPDFURL != nil || selectedPDFRecord != nil
        let valid = hasTitle && hasPDF
        logDebug("isFormValid check: hasTitle=\(hasTitle), hasPDF=\(hasPDF), valid=\(valid)")
        return valid
    }
    
    private var titlePlaceholder: String {
        return isSpanish ? "Título del artículo de noticias" : "News Article Title"
    }
    
    private var validationFeedback: String {
        var feedback = ""
        
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            feedback += isSpanish ? "• Se requiere un título" : "• Title is required"
        }
        
        if selectedPDFURL == nil {
            if !feedback.isEmpty {
                feedback += "\n"
            }
            feedback += isSpanish ? "• Se requiere un PDF" : "• PDF is required"
        }
        
        return feedback
    }
    
    // MARK: - View Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Top bar: Cancel, Title, Publish
            HStack {
                Button(isSpanish ? "Cancelar" : "Cancel") {
                    onDismiss?()
                }
                .buttonStyle(.bordered)
                Spacer()
                Text(isSpanish ? "Publicar en el Feed de Noticias" : "Post to News Feed")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: {
                    // Validate form before showing confirmation
                    if isFormValid {
                        logDebug("Post button tapped, showing confirmation dialog")
                        // Show confirmation with direct method instead of the boolean flag approach
                        showConfirmationDialog(
                            title: isSpanish ? "¿Publicar noticia?" : "Post News Item?",
                            message: isSpanish ? 
                                "¿Estás seguro de que deseas publicar esta noticia?" : 
                                "Are you sure you want to post this news item?",
                            confirmAction: {
                                self.logDebug("Post confirmation accepted")
                                self.publishNewsItem()
                            }
                        )
                    } else {
                        logDebug("Post button tapped but form is invalid")
                        showValidationMessage = true
                    }
                }) {
                    Text(isSpanish ? "Publicar" : "Post")
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isFormValid || isPublishing)
                .opacity(isFormValid ? 1.0 : 0.6)
            }
            .padding(.bottom, 8)
            // Main content scrollable
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
            // Language segmented control
            HStack(spacing: 12) {
                Text(isSpanish ? "Idioma:" : "Language:")
                    .fontWeight(.semibold)
                Picker("", selection: $isSpanish) {
                    Text("English").tag(false)
                    Text("Español").tag(true)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 180)
            }
            .padding(.bottom, 4)
            // Title
            Text(isSpanish ? "Título" : "Title")
                .fontWeight(.semibold)
                    TextField("", text: $title)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(maxWidth: .infinity)
            // Description
            Text(isSpanish ? "Descripción (opcional)" : "Description (optional)")
                .fontWeight(.semibold)
            TextEditor(text: $description)
                        .frame(minHeight: 80, maxHeight: .infinity)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .padding(.bottom, 4)
            // Link URL
            Text(isSpanish ? "URL del enlace (opcional):" : "Link URL (optional):")
                .fontWeight(.semibold)
            TextField(isSpanish ? "Sitio web URL" : "Website URL", text: $linkURL)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(maxWidth: .infinity)
            // PDF Document
            Text(isSpanish ? "Documento PDF (opcional)" : "PDF Document (optional)")
                .fontWeight(.semibold)
                
            // Integrated PDF Selector - This replaces the separate popup
            VStack(spacing: 16) {
                // Upload PDF
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text(isSpanish ? "Subir PDF" : "Upload PDF")
                }
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
                .contentShape(Rectangle())
                .onTapGesture {
                    print("🛠️ [DEBUG] Upload PDF area tapped in NewsFeedPopupView")
                    self.fileImporterIsPresented = true
                }

                // Divider
                HStack {
                    Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 1)
                    Text(isSpanish ? "o" : "or")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 1)
                }

                // Select Existing PDF
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                    Text(isSpanish ? "Seleccionar PDF Existente" : "Select Existing PDF")
                }
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
                .contentShape(Rectangle())
                .onTapGesture {
                    print("🛠️ [DEBUG] Select Existing PDF area tapped in NewsFeedPopupView")
                    showPDFSelector = true
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)

            // Live PDF Preview
            if let pdfDoc = pdfDocument {
                Divider().padding(.vertical, 8)
                Text(isSpanish ? "Vista previa del PDF" : "PDF Preview")
                    .font(.headline)
                    .padding(.bottom, 4)
                PDFKitView(showing: pdfDoc)
                    .frame(height: 300)
                    .cornerRadius(8)
                    .shadow(radius: 2)
            }

            // Scheduled Date Picker
            VStack(alignment: .leading, spacing: 4) {
                Text(isSpanish ? "Fecha y hora de publicación programada (opcional)" : "Scheduled Post Date/Time (optional)")
                    .fontWeight(.semibold)
                DatePicker(
                    isSpanish ? "Programar para más tarde" : "Schedule for later",
                    selection: Binding(
                        get: { scheduledDate ?? Date() },
                        set: { newValue in scheduledDate = newValue }
                    ),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
                .datePickerStyle(FieldDatePickerStyle())
                .frame(maxWidth: 250)
                .environment(\.locale, Locale(identifier: isSpanish ? "es" : "en"))
                Button(isSpanish ? "Limpiar fecha" : "Clear Date") {
                    scheduledDate = nil
                }
                .font(.caption)
                .foregroundColor(.red)
                .buttonStyle(.plain)
                .opacity(scheduledDate == nil ? 0.5 : 1.0)
                .disabled(scheduledDate == nil)
            }
            .padding(.vertical, 4)
            // Validation Message
            if showValidationMessage && !validationFeedback.isEmpty {
                Text(validationFeedback)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(minWidth: 500, maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showPDFSelector) {
            PDFSelectorView(
                selectedPDFRecord: $selectedPDFRecord,
                selectedPDFURL: $selectedPDFURL,
                selectedFileLabel: $selectedFileLabel,
                isSpanish: $isSpanish
            )
            .frame(width: 800, height: 600)
            .onChange(of: selectedPDFRecord) { newValue in
                if newValue != nil {
                    // Auto-dismiss when a PDF is selected
                    showPDFSelector = false
                }
            }
            .onChange(of: selectedPDFURL) { newValue in
                if newValue != nil {
                    // Auto-dismiss when a PDF is imported
                    showPDFSelector = false
                }
            }
        }
        .fileImporter(
            isPresented: $fileImporterIsPresented,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            handleFileImportResult(result)
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .onChange(of: selectedPDFURL) { newURL in
            if let url = newURL {
                logDebug("📄 Loading PDFDocument for URL: \(url)")
                
                // First check if file exists
                if !FileManager.default.fileExists(atPath: url.path) {
                    logDebug("⚠️ WARNING: PDF file does not exist at path: \(url.path)")
                    // Show error alert
                    showErrorMessage(isSpanish ? 
                        "No se pudo encontrar el archivo PDF." : 
                        "Could not find the PDF file.")
                    return
                }
                
                // First try immediate loading
                if let document = PDFDocument(url: url) {
                    logDebug("✅ PDF loaded immediately with \(document.pageCount) pages")
                    setupPDFDocument(document)
                    return
                }
                
                // If immediate loading fails, try background loading
                logDebug("📄 Immediate PDF loading failed, trying background loading...")
                DispatchQueue.global(qos: .userInitiated).async {
                    guard let document = PDFDocument(url: url) else {
                        DispatchQueue.main.async {
                            self.logDebug("❌ Failed to load PDF document at URL: \(url)")
                            showErrorMessage(self.isSpanish ? 
                                "No se pudo cargar el documento PDF." : 
                                "Could not load the PDF document.")
                            self.pdfDocument = nil
                            self.pdfThumbnail = nil
                        }
                        return
                    }
                    
                    DispatchQueue.main.async {
                        self.setupPDFDocument(document)
                    }
                }
            } else {
                self.pdfDocument = nil
                self.pdfThumbnail = nil
                self.logDebug("❌ PDF URL was nil, cleared PDF document")
            }
        }
    }
    
    // MARK: - Methods
    
    private func publishNewsItem() {
        logImportant("PUBLISHING NEWS ITEM")
        logAction("PUBLISH", "Title: \(title), Has PDF: \(selectedPDFURL != nil || selectedPDFRecord != nil)")
        logDebug("Full details - Description length: \(description.count), Link: \(linkURL), isSpanish: \(isSpanish), selectedPDFURL: \(String(describing: selectedPDFURL)), selectedPDFRecord: \(String(describing: selectedPDFRecord))")
        
        isPublishing = true
        var didComplete = false
        
        // Create timeout for publishing
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            if self.isPublishing && !didComplete {
                self.isPublishing = false
                self.showErrorMessage(self.isSpanish ? "La publicación está tardando demasiado. Intente de nuevo." : "Publishing is taking too long. Please try again.")
                self.logImportant("TIMEOUT: Publishing took too long")
            }
        }
        
        // Create a new news post record using NewsFeedItem schema
        let newsPost = CKRecord(recordType: "NewsFeedItem")
        newsPost["title"] = title
        newsPost["content"] = description
        newsPost["datePosted"] = Date()
        newsPost["datePublished"] = Date()
        newsPost["isArchived"] = 0
        newsPost["recordNameMirror"] = newsPost.recordID.recordName
        if !linkURL.isEmpty {
            newsPost["linkURL"] = formatURL(linkURL)
        }
        
        // Always set scheduledDate, fallback to datePosted if not provided
        let effectiveScheduledDate = scheduledDate ?? newsPost["datePosted"] as? Date ?? Date()
        newsPost["scheduledDate"] = effectiveScheduledDate
        logDebug("Setting scheduledDate: \(String(describing: effectiveScheduledDate))")
        
        // Log the record details
        logAction("RECORD", "Created NewsItem record with ID: \(newsPost.recordID.recordName)")
        logDebug("Record fields: \(newsPost.getAllKeys().map { "\($0): \(String(describing: newsPost[$0]))" }.joined(separator: ", "))")
        
        if let pdfRecord = selectedPDFRecord {
            logAction("PDF", "Using existing CloudKit PDF record: \(pdfRecord.recordID.recordName)")
            let pdfReference = CKRecord.Reference(record: pdfRecord, action: .none)
            newsPost["pdfReference"] = pdfReference
            logAction("SAVE", "Saving NewsFeedItem with existing PDF reference")
            
            self.saveNewsPost(newsPost) { success in 
                didComplete = true
                // Only show success alert if save was successful
                if success {
                    self.logAction("SUCCESS", "News item saved with existing PDF")
                    DispatchQueue.main.async {
                        self.showPostSuccess = true
                    }
                } else {
                    self.logAction("FAILURE", "Failed to save news item with existing PDF")
                }
            }
        } else if let pdfURL = selectedPDFURL {
            logAction("PDF", "Uploading new PDF from URL: \(pdfURL)")
            
            // Verify the file exists and is accessible
            if !FileManager.default.fileExists(atPath: pdfURL.path) {
                logImportant("ERROR: PDF file does not exist at \(pdfURL.path)")
                DispatchQueue.main.async {
                    self.isPublishing = false
                    showErrorMessage(self.isSpanish ? 
                        "No se pudo encontrar el archivo PDF en la ubicación temporal." : 
                        "Could not find the PDF file at the temporary location.")
                    didComplete = true
                }
                return
            }
            
            // Create PDF record
            let pdfRecord = CKRecord(recordType: "PDFDocumentItem")
            pdfRecord["title"] = selectedFileLabel
            pdfRecord["dateUploaded"] = Date()
            pdfRecord["recordNameMirror"] = pdfRecord.recordID.recordName
            
            // Create CKAsset from PDF URL
            logAction("ASSET", "Creating CKAsset from file: \(pdfURL.path)")
            let pdfAsset = CKAsset(fileURL: pdfURL)
            pdfRecord["pdfFile"] = pdfAsset
            
            logAction("SAVE", "Saving PDFDocumentItem record: \(pdfRecord.recordID.recordName)")
            
            // Save PDF record to CloudKit
            publicDatabase.save(pdfRecord) { (record, error) in
                if let error = error {
                    self.logImportant("ERROR saving PDF: \(error.localizedDescription)")
                    if let ckError = error as? CKError {
                        self.logDebug("CKError code: \(ckError.code.rawValue)")
                    }
                    
                    DispatchQueue.main.async {
                        self.isPublishing = false
                        showErrorMessage(self.isSpanish ?
                            "Error al guardar el PDF: \(error.localizedDescription)" :
                            "Error saving PDF: \(error.localizedDescription)")
                        didComplete = true
                    }
                    return
                }
                
                if let savedRecord = record {
                    let pdfReference = CKRecord.Reference(record: savedRecord, action: .none)
                    newsPost["pdfReference"] = pdfReference
                    self.logAction("PDF SAVED", "PDF saved successfully with ID: \(savedRecord.recordID.recordName)")
                    
                    // Now save the news post with PDF reference
                    self.logAction("SAVE", "Now saving NewsFeedItem with PDF reference")
                    
                    self.saveNewsPost(newsPost) { success in 
                        didComplete = true
                        // Only show success alert if save was successful
                        if success {
                            self.logAction("SUCCESS", "News item with new PDF saved successfully")
                            DispatchQueue.main.async {
                                self.showPostSuccess = true
                            }
                        } else {
                            self.logAction("FAILURE", "Failed to save news item with new PDF")
                        }
                    }
                } else {
                    self.logImportant("ERROR: PDF save returned nil record")
                    DispatchQueue.main.async {
                        self.isPublishing = false
                        showErrorMessage(self.isSpanish ? "No se pudo guardar el PDF." : "Could not save PDF.")
                        didComplete = true
                    }
                }
            }
        } else {
            self.logImportant("ERROR: No PDF selected for publishing")
            DispatchQueue.main.async {
                self.isPublishing = false
                showErrorMessage(self.isSpanish ?
                    "Por favor seleccione un PDF" :
                    "Please select a PDF")
                didComplete = true
            }
            return
        }
    }
    
    private func saveNewsPost(_ newsPost: CKRecord, completion: @escaping (Bool) -> Void) {
        logAction("SAVE", "Saving NewsFeedItem record: \(newsPost.recordID.recordName)")
        
        publicDatabase.save(newsPost) { (record, error) in
            DispatchQueue.main.async {
                self.isPublishing = false
                
                if let error = error {
                    self.logImportant("ERROR saving news item: \(error.localizedDescription)")
                    if let ckError = error as? CKError {
                        self.logDebug("CKError code: \(ckError.code.rawValue)")
                    }
                    
                    showErrorMessage(self.isSpanish ?
                        "Error al publicar la noticia: \(error.localizedDescription)" :
                        "Error publishing news: \(error.localizedDescription)")
                    completion(false)
                } else if let record = record {
                    self.logAction("SAVED", "NewsFeedItem saved successfully: \(record.recordID.recordName)")
                    
                    // Success - reset the form
                    self.resetForm()
                    
                    // Notify other parts of the app
                    self.logAction("NOTIFY", "Posting notification for news feed refresh")
                    
                    // Simple debounce mechanism for notifications
                    let now = Date()
                    if now.timeIntervalSince(NewsFeedPopupView.lastNotificationTime) > NewsFeedPopupView.minimumNotificationInterval {
                        NewsFeedPopupView.lastNotificationTime = now
                        NotificationCenter.default.post(name: NSNotification.Name("NewsFeedRefreshNotification"), object: nil)
                        self.logAction("NOTIFY", "Posted refresh notification (debounced)")
                    } else {
                        self.logAction("NOTIFY", "Skipped duplicate notification - too soon after previous")
                    }
                    
                    // Show success message and then dismiss
                    self.showSuccessMessage(
                        self.isSpanish ? "La noticia fue publicada exitosamente." : "News item posted successfully.",
                        onDismiss: {
                            self.logDebug("Success alert dismissed, calling onDismiss")
                            self.onDismiss?()
                        }
                    )
                    
                    // Tell the caller the save was successful
                    completion(true)
                } else {
                    self.logImportant("ERROR: News item save returned nil record")
                    showErrorMessage(self.isSpanish ? "No se pudo guardar la noticia." : "Could not save news post.")
                    completion(false)
                }
            }
        }
    }
    
    // Helper function to reset the form fields
    private func resetForm() {
        self.title = ""
        self.description = ""
        self.linkURL = ""
        self.selectedPDFURL = nil
        self.selectedPDFRecord = nil
        self.selectedFileLabel = ""
        self.pdfDocument = nil
        self.pdfThumbnail = nil
        self.scheduledDate = nil
    }
    
    private func handleFileImportResult(_ result: Result<[URL], Error>) {
        logDebug("Handling file import result")
        
        // Use userInteractive QoS to match the UI thread and avoid priority inversion
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                // Get the selected file URL
                guard let selectedFile = try result.get().first else {
                    self.logDebug("No file was selected")
                    return
                }
                // Start file access
                if !selectedFile.startAccessingSecurityScopedResource() {
                    DispatchQueue.main.async {
                        self.logDebug("Failed to access security scoped resource")
                        self.alertTitle = self.isSpanish ?
                            "Error" :
                            "Error"
                        self.alertMessage = self.isSpanish ?
                            "No se pudo acceder al archivo seleccionado." :
                            "Could not access the selected file."
                        self.showAlert = true
                    }
                    return
                }
                // Copy the file to a temporary location that we can access later
                let fileName = selectedFile.lastPathComponent
                let tempDir = FileManager.default.temporaryDirectory
                let copiedFile = tempDir.appendingPathComponent(fileName)
                self.logDebug("Original file: \(selectedFile.path)")
                self.logDebug("Copying to: \(copiedFile.path)")
                // Remove existing file if needed
                try? FileManager.default.removeItem(at: copiedFile)
                // Copy the file
                try FileManager.default.copyItem(at: selectedFile, to: copiedFile)
                // Stop accessing the original file
                selectedFile.stopAccessingSecurityScopedResource()
                DispatchQueue.main.async {
                    // Update our state variables
                    self.selectedPDFURL = copiedFile
                    self.selectedPDFRecord = nil
                    self.selectedFileLabel = fileName
                    self.logDebug("Successfully imported PDF: \(fileName)")
                }
            } catch {
                DispatchQueue.main.async {
                    self.logDebug("Error handling file import: \(error.localizedDescription)")
                    self.alertTitle = self.isSpanish ?
                        "Error al importar el archivo: \(error.localizedDescription)" :
                        "Error importing file: \(error.localizedDescription)"
                    self.showAlert = true
                }
            }
        }
    }
    
    // Helper method to set up PDF document and thumbnail
    private func setupPDFDocument(_ document: PDFDocument) {
        self.logDebug("✅ PDF document loaded with \(document.pageCount) pages")
        
        // Generate thumbnail if possible
        var thumb: NSImage? = nil
        if let page = document.page(at: 0) {
            let pageBounds = page.bounds(for: .mediaBox)
            self.logDebug("📐 PDF first page dimensions: \(pageBounds.width) x \(pageBounds.height) points")
            thumb = page.thumbnail(of: NSSize(width: 40, height: 52), for: .mediaBox)
        }
        
        // Set the document and thumbnail on the main thread
        self.pdfDocument = document
        self.pdfThumbnail = thumb
        
        // Force layout update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.logDebug("🔄 Forcing layout update after PDF loaded")
        }
    }
    
    // Add this helper method to format URLs properly
    private func formatURL(_ urlString: String) -> String {
        // Don't attempt to format empty strings
        guard !urlString.isEmpty else {
            return urlString
        }
        
        // Check if URL already contains a scheme
        if urlString.contains("://") || urlString.lowercased().hasPrefix("http://") || urlString.lowercased().hasPrefix("https://") {
            return urlString
        }
        
        // Default to https:// if no scheme present
        return "https://" + urlString
    }
}
