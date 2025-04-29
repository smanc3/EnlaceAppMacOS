//
//  NewsFeedPopupView.swift
//  Enlace Admin (Preview)
//
//  Created by Admin on 4/8/25.
//

import SwiftUI
import CloudKit
import UniformTypeIdentifiers
import PDFKit

// MARK: - PDFKitView

/// A SwiftUI view that wraps `PDFView` from PDFKit to display PDF documents in a macOS app.
struct PDFKitView: NSViewRepresentable {
    /// The `PDFDocument` to be displayed.
    let pdfDocument: PDFKit.PDFDocument
    
    /// Initializes the view with a `PDFDocument`.
    /// - Parameter pdfDoc: The `PDFDocument` instance to show.
    init(showing pdfDoc: PDFKit.PDFDocument) {
        print("📄 PDFKitView: Initializing with document, page count: \(pdfDoc.pageCount)")
        
        // Add more document diagnostics
        if pdfDoc.pageCount > 0, let firstPage = pdfDoc.page(at: 0) {
            let pageBounds = firstPage.bounds(for: .mediaBox)
            print("📄 PDFKitView: First page dimensions: \(pageBounds.width) x \(pageBounds.height)")
            if pageBounds.width < 10 || pageBounds.height < 10 {
                print("⚠️ PDFKitView WARNING: Page dimensions are unusually small!")
            }
        }
        
        self.pdfDocument = pdfDoc
    }
    
    /// Creates and configures the `PDFView` instance.
    /// - Parameter context: The context in which the view is created.
    /// - Returns: A configured `PDFView` instance.
    func makeNSView(context: Context) -> PDFView {
        print("📄 PDFKitView: Creating PDFView")
        let pdfView = PDFView()
        
        // Add visual debugging to help diagnose layout issues
        pdfView.wantsLayer = true
        pdfView.layer?.borderWidth = 2.0
        pdfView.layer?.borderColor = NSColor.red.cgColor
        
        print("📄 PDFKitView: Initial view frame: \(pdfView.frame)")
        
        // Configure other PDFView properties BEFORE setting document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = NSColor.textBackgroundColor
        pdfView.autoresizingMask = [.width, .height]
        pdfView.minScaleFactor = 0.1
        pdfView.maxScaleFactor = 4.0
        
        // Use a longer delay to ensure PDFView is properly initialized before setting document
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            print("📄 PDFKitView: Setting document on view after delay")
            print("📄 PDFKitView: View frame before setting document: \(pdfView.frame)")
            
            // Check if we have a parent view
            if let superview = pdfView.superview {
                print("📄 PDFKitView: View has superview with frame: \(superview.frame)")
            } else {
                print("⚠️ PDFKitView WARNING: No superview yet")
            }
            
            // Set the document
        pdfView.document = pdfDocument
            
            // Add detailed logging
            if pdfView.document == nil {
                print("❌ PDFKitView ERROR: Document not set properly in makeNSView after delay")
            } else {
                print("✅ PDFKitView: Document set successfully after delay, page count: \(pdfView.document?.pageCount ?? 0)")
                
                if let firstPage = pdfView.document?.page(at: 0) {
                    let pageBounds = firstPage.bounds(for: .mediaBox)
                    print("📄 PDFKitView: First page bounds: \(pageBounds)")
                    
                    // Force layout updates
                    pdfView.needsLayout = true
                    pdfView.layoutSubtreeIfNeeded()
                    pdfView.needsDisplay = true
                    pdfView.go(to: firstPage)
                    
                    // Check view dimensions after layout
                    let viewWidth = pdfView.bounds.width
                    let viewHeight = pdfView.bounds.height
                    
                    print("📄 PDFKitView: View dimensions after layout: \(viewWidth) x \(viewHeight)")
                    
                    // Check for problematic dimensions
                    if viewWidth < 50 || viewHeight < 50 {
                        print("⚠️ PDFKitView WARNING: View dimensions are too small!")
                        
                        // Try to fix by setting explicit frame if parent view exists
                        if let superview = pdfView.superview {
                            let adjustedFrame = NSRect(
                                x: pdfView.frame.origin.x,
                                y: pdfView.frame.origin.y,
                                width: max(superview.frame.width * 0.9, 500),
                                height: max(superview.frame.height * 0.9, 700)
                            )
                            pdfView.frame = adjustedFrame
                            print("📄 PDFKitView: Explicitly set frame to: \(adjustedFrame)")
                        } else {
                            // Set a reasonable default size
                            pdfView.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
                            print("📄 PDFKitView: Set default size to 800x600")
                        }
                    }
                    
                    // Calculate and apply appropriate scale factor
                    if viewWidth > 0 && viewHeight > 0 && pageBounds.width > 0 && pageBounds.height > 0 {
                        let widthScale = viewWidth / pageBounds.width
                        let heightScale = viewHeight / pageBounds.height
                        let scaleFactor = min(widthScale, heightScale) * 0.9
                        
                        print("📄 PDFKitView: Calculated scale factor: \(scaleFactor)")
                        
                        // Apply scale with a reasonable minimum
                        let finalScale = max(0.5, scaleFactor)
                        pdfView.scaleFactor = finalScale
                        print("📄 PDFKitView: Applied scale factor: \(finalScale)")
                    } else {
                        // Apply a default scale if dimensions are invalid
                        pdfView.scaleFactor = 1.0
                        print("📄 PDFKitView: Applied default scale of 1.0")
                    }
                }
            }
            
            // Log final view state
            print("📄 PDFKitView: Final view frame: \(pdfView.frame)")
            print("📄 PDFKitView: Final view bounds: \(pdfView.bounds)")
        }
        
        return pdfView
    }
    
    /// Updates the `PDFView` when the SwiftUI view's state changes.
    /// - Parameters:
    ///   - pdfView: The `PDFView` instance to update.
    ///   - context: The context containing information about the update.
    func updateNSView(_ pdfView: PDFView, context: Context) {
        print("📄 PDFKitView: Updating PDFView, current frame: \(pdfView.frame)")
        
        // Use a longer delay to ensure PDFView is ready before updating document
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Update the document
        pdfView.document = pdfDocument
            
            // Check if document was updated properly
            if pdfView.document == nil {
                print("❌ PDFKitView ERROR: Document not updated properly in updateNSView after delay")
            } else {
                print("✅ PDFKitView: Document updated successfully after delay, page count: \(pdfView.document?.pageCount ?? 0)")
                
                // Force layout updates
                pdfView.needsLayout = true
                pdfView.layoutSubtreeIfNeeded()
                pdfView.needsDisplay = true
                
                // Check view dimensions
                print("📄 PDFKitView: View dimensions after update: \(pdfView.bounds.width) x \(pdfView.bounds.height)")
                
                // Try to fix small dimensions
                if pdfView.bounds.width < 50 || pdfView.bounds.height < 50 {
                    print("⚠️ PDFKitView WARNING: View has small dimensions after update")
                    
                    if let superview = pdfView.superview {
                        let adjustedFrame = NSRect(
                            x: pdfView.frame.origin.x,
                            y: pdfView.frame.origin.y,
                            width: max(superview.frame.width * 0.9, 500),
                            height: max(superview.frame.height * 0.9, 700)
                        )
                        pdfView.frame = adjustedFrame
                        print("📄 PDFKitView: Adjusted frame to: \(adjustedFrame)")
                    }
                }
                
                // Reset view to show entire first page with good scaling
                if let firstPage = pdfDocument.page(at: 0) {
                    pdfView.go(to: firstPage)
                    pdfView.scaleFactor = max(0.5, pdfView.scaleFactorForSizeToFit)
                    print("📄 PDFKitView: Reset to first page with scale factor: \(pdfView.scaleFactor)")
                }
            }
        }
    }
}

// MARK: - NewsFeedPopupView

/// The primary view for creating and editing news items
struct NewsFeedPopupView: View {
    // MARK: - Environment Properties
    
    @EnvironmentObject private var authManager: AuthenticationManager
    
    // Optional binding to control dismissal from parent view
    var onDismiss: (() -> Void)?
    
    // MARK: - State Properties
    
    @State private var title: String = ""
    @State private var showPDFSelector: Bool = false
    @State private var selectedPDFRecord: CKRecord? = nil
    @State private var selectedPDFURL: URL? = nil
    @State private var selectedFileLabel: String = ""
    @State private var isSpanish = false
    @State private var isPublishing: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var validationMessage: String = ""
    @State private var uploadProgress: Double = 0.0
    @State private var showValidationMessage: Bool = false
    @State private var linkURL: String = ""  // New state for storing link URL
    
    // CloudKit container
    private let container = CKContainer(identifier: "iCloud.PearInc.EICT-iOS-16")
    private var database: CKDatabase {
        return container.publicCloudDatabase
    }
    
    // MARK: - Debug Logging
    
    private func logDebug(_ message: String) {
        print("📰 NewsFeedPopupView: \(message)")
    }
    
    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && 
               (selectedPDFRecord != nil || selectedPDFURL != nil)
    }
    
    private var titlePlaceholder: String {
        return isSpanish ? "Título del artículo de noticias" : "News Article Title"
    }
    
    private var validationFeedback: String {
        var feedback = ""
        
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            feedback += isSpanish ? "• Se requiere un título\n" : "• Title is required\n"
        }
        
        if selectedPDFRecord == nil && selectedPDFURL == nil {
            feedback += isSpanish ? "• Se requiere un PDF" : "• PDF is required"
        }
        
        return feedback
    }
    
    // MARK: - View Body
    
    var body: some View {
        VStack(spacing: 0) {
            // TOP NAV BAR
            HStack {
                Button {
                    logDebug("Cancel button tapped")
                    onDismiss?()
                } label: {
                    Text(isSpanish ? "Cancelar" : "Cancel")
                }
                
                Spacer()
                
                Text(isSpanish ? "Publicar Noticia" : "Publish News")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    logDebug("Attempting to publish news item")
                    publishNewsItem()
                } label: {
                    Text(isSpanish ? "PUBLICAR" : "PUBLISH")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isFormValid || isPublishing)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // LANGUAGE SELECTOR
                    HStack {
                        Text(isSpanish ? "Idioma:" : "Language:")
                            .fontWeight(.medium)
                        
                        Picker("", selection: $isSpanish) {
                            Text("English").tag(false)
                            Text("Español").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                        
                        Spacer()
                    }
                    .padding(.top, 10)
                    
                    // TITLE INPUT
                    VStack(alignment: .leading, spacing: 8) {
                        Text(isSpanish ? "Título" : "Title")
                            .font(.headline)
                        
                        TextField(titlePlaceholder, text: $title)
                            .textFieldStyle(.roundedBorder)
                            .font(.body)
                            .onChange(of: title) { oldValue, newValue in
                                if showValidationMessage {
                                    showValidationMessage = false
                                }
                            }
                    }
                    
                    // LINK URL INPUT SECTION
                    VStack(alignment: .leading, spacing: 8) {
                        Text(isSpanish ? "Enlace URL (opcional):" : "Link URL (optional):")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            TextField(isSpanish ? "URL del sitio web" : "Website URL", text: $linkURL)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                                .onChange(of: linkURL) { oldValue, newValue in
                                    if !newValue.isEmpty && !newValue.lowercased().hasPrefix("http") {
                                        linkURL = "https://" + newValue
                                        
                                        // Log URL format correction
                                        logDebug("Added https:// prefix to URL input: \(linkURL)")
                                    }
                                }
                            
                            if !linkURL.isEmpty {
                                HStack {
                                    // Show URL validation status
                                    if URL(string: linkURL) != nil {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                        Text(isSpanish ? "URL válida" : "Valid URL")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    } else {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                        Text(isSpanish ? "URL inválida" : "Invalid URL format")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                    
                                    Spacer()
                                    
                                    // Preview link button
                                    if URL(string: linkURL) != nil {
                                        Button(action: {
                                            if let url = URL(string: linkURL) {
                                                NSWorkspace.shared.open(url)
                                                logDebug("Opened URL for preview: \(url)")
                                            }
                                        }) {
                                            HStack {
                                                Image(systemName: "eye")
                                                Text(isSpanish ? "Previsualizar" : "Preview")
                                            }
                                        }
                                        .buttonStyle(.borderless)
                                        .foregroundColor(.blue)
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                    
                    // PDF SELECTOR SECTION
                    VStack(alignment: .leading, spacing: 8) {
                        Text(isSpanish ? "Documento PDF" : "PDF Document")
                            .font(.headline)
                        
                        if selectedPDFRecord != nil || selectedPDFURL != nil {
                            // SELECTED PDF DISPLAY
                            HStack {
                                Image(systemName: "doc.fill")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                                
                                Text(selectedFileLabel)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                
                                Spacer()
                                
                                Button {
                                    logDebug("Changing PDF selection")
                                    showPDFSelector = true
                                    if showValidationMessage {
                                        showValidationMessage = false
                                    }
                                } label: {
                                    Text(isSpanish ? "Cambiar" : "Change")
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.05))
                            )
                        } else {
                            // SELECT PDF BUTTON
                            Button {
                                logDebug("Opening PDF selector")
                                showPDFSelector = true
                                if showValidationMessage {
                                    showValidationMessage = false
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "doc.badge.plus")
                                    Text(isSpanish ? "Seleccionar PDF" : "Select PDF")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }
                    }
                    
                    // VALIDATION MESSAGE
                    if showValidationMessage {
                        Text(validationMessage)
                            .font(.callout)
                            .foregroundColor(.red)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.05))
                            )
                    }
                    
                    // PROGRESS INDICATOR
                    if isPublishing {
                        VStack(spacing: 8) {
                            ProgressView(value: uploadProgress, total: 1.0)
                                .progressViewStyle(.linear)
                            
                            Text(uploadProgress < 1.0 ? 
                                 (isSpanish ? "Subiendo PDF..." : "Uploading PDF...") : 
                                 (isSpanish ? "Publicando noticia..." : "Publishing news item..."))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.05))
                        )
                    }
                    
                    Spacer()
                }
                .padding()
            }
        }
        .sheet(isPresented: $showPDFSelector) {
            PDFSelectorView(
                selectedPDFRecord: $selectedPDFRecord,
                selectedPDFURL: $selectedPDFURL, 
                selectedFileLabel: $selectedFileLabel,
                isSpanish: $isSpanish
            )
            .frame(minWidth: 650, minHeight: 500)
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK")) {
                    if alertTitle.contains("Success") || alertTitle.contains("Éxito") {
                        onDismiss?()
                    }
                }
            )
        }
    }
    
    // MARK: - Methods
    
    private func publishNewsItem() {
        guard isFormValid else {
            validationMessage = validationFeedback
            showValidationMessage = true
            return
        }
        
        // Reset validation message when publishing
        showValidationMessage = false
        isPublishing = true
        uploadProgress = 0.0
        
        logDebug("Starting news item publication process")
        
        // If we have a selected PDF URL (new upload), we need to upload it first
        if let pdfURL = selectedPDFURL {
            uploadPDF(from: pdfURL) { recordID, error in
                if let error = error {
                    DispatchQueue.main.async {
                        logDebug("Error uploading PDF: \(error.localizedDescription)")
                        self.alertTitle = self.isSpanish ? "Error" : "Error"
                        self.alertMessage = self.isSpanish ? 
                            "Error al subir el PDF: \(error.localizedDescription)" : 
                            "Error uploading PDF: \(error.localizedDescription)"
                        self.showAlert = true
                        self.isPublishing = false
                    }
                    return
                }
                
                guard let recordID = recordID else {
                    DispatchQueue.main.async {
                        logDebug("Error: No record ID returned after PDF upload")
                        self.alertTitle = self.isSpanish ? "Error" : "Error"
                        self.alertMessage = self.isSpanish ? 
                            "Error al subir el PDF: No se recibió ID del registro" : 
                            "Error uploading PDF: No record ID was received"
                        self.showAlert = true
                        self.isPublishing = false
                    }
                    return
                }
                
                // Fetch the full record to use for the news item
                self.database.fetch(withRecordID: recordID) { record, error in
                    if let error = error {
                        DispatchQueue.main.async {
                            logDebug("Error fetching uploaded PDF record: \(error.localizedDescription)")
                            self.alertTitle = self.isSpanish ? "Error" : "Error"
                            self.alertMessage = self.isSpanish ? 
                                "Error al recuperar el PDF subido: \(error.localizedDescription)" : 
                                "Error retrieving uploaded PDF: \(error.localizedDescription)"
                            self.showAlert = true
                            self.isPublishing = false
                        }
                        return
                    }
                    
                    guard let pdfRecord = record else {
                        DispatchQueue.main.async {
                            logDebug("Error: No PDF record found after upload")
                            self.alertTitle = self.isSpanish ? "Error" : "Error"
                            self.alertMessage = self.isSpanish ? 
                                "Error al recuperar el PDF subido: No se encontró el registro" : 
                                "Error retrieving uploaded PDF: Record not found"
                            self.showAlert = true
                            self.isPublishing = false
                        }
                        return
                    }
                    
                    self.createNewsItem(with: pdfRecord)
                }
            }
        } else if let pdfRecord = selectedPDFRecord {
            // We have an existing PDF, use it directly
            createNewsItem(with: pdfRecord)
        }
    }
    
    private func uploadPDF(from url: URL, completion: @escaping (CKRecord.ID?, Error?) -> Void) {
        logDebug("Uploading PDF from: \(url.lastPathComponent)")
        
        // Create asset from the file
        let asset = CKAsset(fileURL: url)
        
        // Create a new record
        let record = CKRecord(recordType: "PDFDocumentItem")
        record["title"] = selectedFileLabel as CKRecordValue
        record["pdfFile"] = asset
        record["dateUploaded"] = Date() as CKRecordValue
        record["isSpanish"] = isSpanish as CKRecordValue
        record["uploadedBy"] = authManager.userRecord?.recordID as? CKRecordValue
        
        // Upload to CloudKit
        let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        operation.perRecordProgressBlock = { _, progress in
            DispatchQueue.main.async {
                self.uploadProgress = progress
                logDebug("Upload progress: \(Int(progress * 100))%")
            }
        }
        
        operation.modifyRecordsResultBlock = { result in
            switch result {
            case .success:
                logDebug("PDF upload successful")
                completion(record.recordID, nil)
            case .failure(let error):
                logDebug("PDF upload failed: \(error.localizedDescription)")
                completion(nil, error)
            }
        }
        
        database.add(operation)
    }
    
    private func createNewsItem(with pdfRecord: CKRecord) {
        logDebug("Creating news item with PDF record: \(pdfRecord.recordID.recordName)")
        
        let newsRecord = CKRecord(recordType: "NewsItem")
        newsRecord["title"] = title as CKRecordValue
        newsRecord["isSpanish"] = isSpanish as CKRecordValue
        newsRecord["datePublished"] = Date() as CKRecordValue
        newsRecord["pdfReference"] = CKRecord.Reference(recordID: pdfRecord.recordID, action: .deleteSelf)
        
        // Save link URL if provided and valid
        if !linkURL.isEmpty, let _ = URL(string: linkURL) {
            newsRecord["linkURL"] = linkURL as CKRecordValue
            logDebug("Added link URL to news item: \(linkURL)")
        }
        
        if let userRecord = authManager.userRecord {
            newsRecord["publishedBy"] = CKRecord.Reference(recordID: userRecord.recordID, action: .none)
        }
        
        // Save to CloudKit
        database.save(newsRecord) { (record, error) in
            DispatchQueue.main.async {
                self.isPublishing = false
                
                if let error = error {
                    logDebug("Error saving news item: \(error.localizedDescription)")
                    self.alertTitle = self.isSpanish ? "Error" : "Error"
                    self.alertMessage = self.isSpanish ? 
                        "Error al publicar la noticia: \(error.localizedDescription)" : 
                        "Error publishing news item: \(error.localizedDescription)"
                } else {
                    logDebug("Successfully published news item with ID: \(record?.recordID.recordName ?? "unknown")")
                    self.alertTitle = self.isSpanish ? "Éxito" : "Success"
                    self.alertMessage = self.isSpanish ? 
                        "Noticia publicada exitosamente." : 
                        "News item successfully published."
                }
                
                self.showAlert = true
            }
        }
    }
} 
