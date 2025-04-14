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
    let pdfDocument: PDFDocument
    
    /// Initializes the view with a `PDFDocument`.
    /// - Parameter pdfDoc: The `PDFDocument` instance to show.
    init(showing pdfDoc: PDFDocument) {
        self.pdfDocument = pdfDoc
    }
    
    /// Creates and configures the `PDFView` instance.
    /// - Parameter context: The context in which the view is created.
    /// - Returns: A configured `PDFView` instance.
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = pdfDocument
        pdfView.autoScales = true // Enable automatic scaling
        return pdfView
    }
    
    /// Updates the `PDFView` when the SwiftUI view's state changes.
    /// - Parameters:
    ///   - pdfView: The `PDFView` instance to update.
    ///   - context: The context containing information about the update.
    func updateNSView(_ pdfView: PDFView, context: Context) {
        // Update the document if it changes (though in this simple case, it might not be necessary if the view is recreated)
        pdfView.document = pdfDocument
    }
}

// MARK: - NewsFeedPopupView

/// A view representing a pop-up window for creating and uploading a new news feed post with a title and a PDF attachment.
struct NewsFeedPopupView: View {
    /// Binding to control the visibility of the pop-up.
    @Binding var showPopup: Bool
    /// Binding to determine the display language (Spanish or English).
    @Binding var isSpanish: Bool
    
    /// State variable for the document title input field.
    @State private var documentTitle: String = ""
    /// State variable storing the URL of the selected PDF file.
    @State private var selectedPDFURL: URL? = nil
    /// State variable for displaying the name of the selected file.
    @State private var selectedFileLabel: String = ""
    /// State variable to indicate if an upload is currently in progress.
    @State private var isUploading: Bool = false
    /// State variable holding the loaded `PDFDocument` for preview generation.
    @State private var pdfPreview: PDFDocument? = nil
    /// State variable holding the generated thumbnail image of the selected PDF's first page.
    @State private var pdfThumbnail: NSImage? = nil
    
    /// State variable to control the presentation of alerts.
    @State private var showAlert = false
    /// State variable for the title of the alert.
    @State private var alertTitle = ""
    /// State variable for the message body of the alert.
    @State private var alertMessage = ""
    /// State variable to indicate if the last operation (upload) was successful, used for alert dismissal logic.
    @State private var isSuccess = false
    
    /// The CloudKit container instance.
    private let container = CKContainer(identifier: "iCloud.PearInc.EICT-iOS-16")
    /// Computed property to access the public CloudKit database.
    private var database: CKDatabase {
        return container.publicCloudDatabase
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    // Only dismiss if not uploading
                    if !isUploading {
                        showPopup = false
                    }
                }
            
            VStack(spacing: 15) {
                // Header
                HStack {
                    Text(isSpanish ? "Publicar en Noticias" : "Post to News Feed")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: {
                        if !isUploading {
                            showPopup = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                    .disabled(isUploading)
                }
                .padding(.horizontal)
                
                // Form content in a compact bordered container
                ScrollView {
                    VStack(spacing: 12) {
                        // Title TextField
                        TextField(
                            isSpanish ? "Título del Documento" : "Document Title",
                            text: $documentTitle
                        )
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                        
                        // PDF Selection Area
                        HStack {
                            VStack(alignment: .leading) {
                                Text(selectedFileLabel.isEmpty ?
                                     (isSpanish ? "Seleccionar PDF" : "Select PDF File") :
                                        selectedFileLabel)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(selectedPDFURL == nil ? Color(NSColor.controlBackgroundColor) : Color.clear)
                                .cornerRadius(6)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                
                                // Display Thumbnail if available
                                if let thumbnail = pdfThumbnail {
                                    Image(nsImage: thumbnail)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(height: 100)
                                        .cornerRadius(4)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                                        )
                                        .padding(.top, 5)
                                }
                            }
                            
                            Spacer()
                            
                            // Show Remove button only if PDF is selected
                            if selectedPDFURL != nil {
                                Button(action: resetPDFSelection) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                                .padding(.trailing)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Select PDF Button
                        Button(action: selectPDF) {
                            Text(isSpanish ? "Seleccionar PDF" : "Select PDF")
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isUploading)
                        .padding(.horizontal)
                        
                        // Validation Message
                        if documentTitle.isEmpty || selectedPDFURL == nil {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.orange)
                                
                                Text(isSpanish ? "Requiere título y archivo PDF" : "Title and PDF file required")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                // Upload Buttons
                HStack {
                    Button(isSpanish ? "Cancelar" : "Cancel") {
                        resetForm()
                        showPopup = false
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                    .buttonStyle(.bordered)
                    .disabled(isUploading)
                    
                    Spacer()
                    
                    Button(action: uploadPDF) {
                        if isUploading {
                            ProgressView()
                                .scaleEffect(0.7)
                                .padding(.horizontal, 5)
                        } else {
                            Text(isSpanish ? "Publicar" : "Publish")
                                .fontWeight(.medium)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(documentTitle.isEmpty || selectedPDFURL == nil || isUploading)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            // Apply standard padding, width, vertical sizing, background, radius, shadow to the main VStack
            .frame(maxWidth: 400, maxHeight: 500)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(12)
            .shadow(radius: 10)
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text(isSpanish ? "Cerrar" : "Close")) {
                        if isSuccess {
                            // Reset form state when closing after success
                            resetForm()
                            showPopup = false
                        }
                    }
                )
            }
        }
        .onDisappear {
            // Reset state when view disappears (e.g., if closed unexpectedly)
            resetForm()
        }
    }
    
    // MARK: - Methods
    
    /// Resets all form state variables to their default values.
    /// Call this when cancelling, successfully uploading, or when the view disappears.
    private func resetForm() {
        documentTitle = ""
        selectedPDFURL = nil
        selectedFileLabel = ""
        pdfPreview = nil
        pdfThumbnail = nil // Clear thumbnail
        isUploading = false
        isSuccess = false
    }
    
    /// Opens an `NSOpenPanel` to allow the user to select a PDF file.
    /// Updates the state with the selected file's URL, name, and generates a thumbnail.
    /// Shows an alert if the selected file cannot be loaded as a `PDFDocument`.
    private func selectPDF() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.pdf]
        
        // Clear previous selection first to avoid lingering state
        self.resetPDFSelection()
        
        if panel.runModal() == .OK, let url = panel.url {
            self.selectedPDFURL = url
            if let pdfDoc = PDFDocument(url: url) {
                self.pdfPreview = pdfDoc // Keep the document temporarily for page access
                self.selectedFileLabel = url.lastPathComponent
                
                // Generate thumbnail for the first page
                if let page = pdfDoc.page(at: 0) {
                    // Define desired thumbnail size (adjust as needed for UI)
                    let thumbnailSize = NSSize(width: 100, height: 150)
                    self.pdfThumbnail = page.thumbnail(of: thumbnailSize, for: .mediaBox)
                }
                
            } else {
                // Handle error if PDFDocument fails to initialize
                self.showAlert = true
                self.alertTitle = isSpanish ? "Error" : "Error"
                self.alertMessage = isSpanish ? "No se pudo cargar el PDF" : "Could not load PDF"
                self.resetPDFSelection() // Ensure reset on load failure
            }
        }
    }
    
    /// Resets only the state variables related to the selected PDF.
    /// Used internally by `selectPDF` before selecting a new file and when removing the current selection.
    private func resetPDFSelection() {
        self.selectedPDFURL = nil
        self.selectedFileLabel = ""
        self.pdfPreview = nil
        self.pdfThumbnail = nil
    }
    
    /// Uploads the selected PDF file and its title to CloudKit.
    /// Creates a `PDFDocumentItem` record and saves it to the public database.
    /// Shows an alert indicating success or failure.
    private func uploadPDF() {
        // Ensure required fields are filled
        guard let pdfURL = selectedPDFURL, !documentTitle.isEmpty else {
            alertTitle = isSpanish ? "Error" : "Error"
            alertMessage = isSpanish ? "Por favor proporcione un título y seleccione un archivo PDF." : "Please provide a title and select a PDF file."
            showAlert = true
            return
        }
        
        isUploading = true // Show progress indicator
        
        // Create the CloudKit record
        let record = CKRecord(recordType: "PDFDocumentItem")
        record["title"] = documentTitle
        record["dateUploaded"] = Date() // Set current date/time
        record["pdfFile"] = CKAsset(fileURL: pdfURL) // Create CKAsset from file URL
        
        // Save the record to the public database
        database.save(record) { savedRecord, error in
            // Ensure UI updates happen on the main thread
            DispatchQueue.main.async {
                isUploading = false // Hide progress indicator
                
                if let error = error {
                    // Handle upload error
                    isSuccess = false
                    alertTitle = isSpanish ? "Error" : "Error"
                    alertMessage = isSpanish ? 
                        "Error al publicar el documento: \(error.localizedDescription)" :
                        "Error publishing document: \(error.localizedDescription)"
                } else {
                    // Handle upload success
                    isSuccess = true
                    alertTitle = isSpanish ? "Éxito" : "Success"
                    alertMessage = isSpanish ? 
                        "El documento ha sido publicado exitosamente." :
                        "The document has been successfully published."
                    // Note: resetForm() is called when the success alert is dismissed
                }
                
                showAlert = true // Show the result alert
            }
        }
    }
} 