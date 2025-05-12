//
//  PDFSelectorView.swift
//  Enlace Admin (Preview)
//
//  Created by Admin on 4/8/25.
//

import SwiftUI
import CloudKit
import UniformTypeIdentifiers
import PDFKit

// Create a new PDF viewer with a different name to avoid conflicts
struct PDFViewer: NSViewRepresentable {
    let document: PDFKit.PDFDocument
    
    init(document: PDFKit.PDFDocument) {
        print("📄 PDFViewer: Initializing with document, page count: \(document.pageCount)")
        
        // Log document details
        if document.pageCount > 0, let firstPage = document.page(at: 0) {
            let pageBounds = firstPage.bounds(for: .mediaBox)
            print("📄 PDFViewer: First page dimensions: \(pageBounds.width) x \(pageBounds.height)")
            if pageBounds.width < 10 || pageBounds.height < 10 {
                print("⚠️ PDFViewer WARNING: Page dimensions are unusually small!")
            }
        } else {
            print("⚠️ PDFViewer WARNING: Document has no pages or couldn't access first page")
        }
        
        self.document = document
    }
    
    func makeNSView(context: Context) -> PDFView {
        print("📄 PDFViewer: Creating PDFView")
        let pdfView = PDFView()
        
        // Configure PDFView properties
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = NSColor.textBackgroundColor
        pdfView.autoresizingMask = [.width, .height]
        pdfView.minScaleFactor = 0.1
        pdfView.maxScaleFactor = 4.0
        
        // Use a longer delay to ensure PDFView is fully initialized before setting document
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            print("📄 PDFViewer: Setting document after delay")
            pdfView.document = document
            pdfView.autoScales = true // Always fit to view
                pdfView.layoutSubtreeIfNeeded()
            if let firstPage = document.page(at: 0) {
                    pdfView.go(to: firstPage)
            }
        }
        
        return pdfView
    }
    
    func updateNSView(_ pdfView: PDFView, context: Context) {
        print("📄 PDFViewer: Updating PDFView, current frame: \(pdfView.frame)")
        
        // Use a longer delay to ensure PDFView is ready for document update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            pdfView.document = document
            pdfView.autoScales = true // Always fit to view
                pdfView.layoutSubtreeIfNeeded()
                if let firstPage = document.page(at: 0) {
                    pdfView.go(to: firstPage)
            }
        }
    }
}

/// A view that allows the user to select from existing PDFs stored in CloudKit or import a new PDF file.
struct PDFSelectorView: View {
    // MARK: - Environment & Bindings
    
    @State private var selectedDocIndex: Int? = nil
    @State private var isImportingPDF: Bool = false
    @State private var showRefreshIndicator: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    @State private var availablePDFs: [CKRecord] = []
    @State private var isLoading: Bool = true
    @State private var previewPDFDocument: PDFDocument? = nil
    @State private var isLoadingPreview: Bool = false
    
    // Bindings for handling the selected PDF
    @Binding var selectedPDFRecord: CKRecord?
    @Binding var selectedPDFURL: URL?
    @Binding var selectedFileLabel: String
    @Binding var isSpanish: Bool
    
    // CloudKit container
    private let container = CKContainer(identifier: "iCloud.PearInc.EICT-iOS-16")
    private var database: CKDatabase {
        return container.publicCloudDatabase
    }
    
    var onConfirm: (() -> Void)? = nil
    
    // MARK: - Debug Logging
    
    private func logDebug(_ message: String) {
        print("📄 PDFSelectorView: \(message)")
    }
    
    // MARK: - View Lifecycle
    
    var body: some View {
        VStack(spacing: 0) {
            // HEADER
            HStack {
                Text(isSpanish ? "Adjuntar un PDF" : "Attach a PDF Document")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    logDebug("Refreshing PDF list")
                    refreshPDFs()
                } label: {
                    Label(isSpanish ? "Actualizar" : "Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            
            if isLoading {
                // LOADING INDICATOR
                VStack {
                    ProgressView()
                        .scaleEffect(1.0)
                    Text(isSpanish ? "Cargando documentos..." : "Loading documents...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                // CONTENT VIEW
                HStack(spacing: 0) {
                    // LEFT PANE - Selected PDF preview
                    VStack {
                        if isLoadingPreview {
                            ProgressView()
                                .frame(width: 100, height: 140)
                        } else if let doc = previewPDFDocument {
                            VStack {
                                Text(isSpanish ? "Vista previa del PDF" : "PDF Preview")
                                    .font(.headline)
                                    .padding(.top, 10)
                                
                                // Enhanced PDF preview with larger size
                                PDFViewer(document: doc)
                                    .frame(minWidth: 200, minHeight: 280)
                                    .background(Color.white)
                                    .cornerRadius(8)
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                                    .padding(10)
                                
                                let title = selectedPDFRecord?["title"] as? String ?? selectedFileLabel
                                Text(title)
                                    .font(.callout)
                                    .fontWeight(.medium)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 8)
                            }
                        } else if let selectedRecord = selectedPDFRecord {
                            selectedPDFPreview(for: selectedRecord)
                        } else if let url = selectedPDFURL {
                            importedPDFPreview(for: url)
                        } else {
                            noSelectionView()
                        }
                    }
                    .frame(minWidth: 250)
                    .background(Color.gray.opacity(0.05))
                    
                    // RIGHT PANE - PDF selection options
                    VStack(spacing: 10) {
                        // Import button at the top
                        Button {
                            logDebug("Opening file importer")
                            isImportingPDF = true
                        } label: {
                            Label(isSpanish ? "Subir PDF" : "Upload PDF", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .padding(.horizontal)
                        .padding(.top, 5)
                        
                        // Available PDFs Title
                        HStack {
                            Text(isSpanish ? "PDFs disponibles" : "Available PDFs")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            if showRefreshIndicator {
                                ProgressView()
                                    .scaleEffect(0.5)
                            }
                        }
                        .padding(.horizontal)
                        
                        Divider()
                            .padding(.horizontal)
                        
                        // PDF List
                        if availablePDFs.isEmpty {
                            VStack {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.secondary)
                                    .padding(.bottom, 8)
                                
                                Text(isSpanish ? "No hay PDFs disponibles" : "No PDFs available")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding()
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 2) {
                                    ForEach(0..<availablePDFs.count, id: \.self) { index in
                                        let pdf = availablePDFs[index]
                                        pdfListItem(pdf: pdf, index: index)
                                    }
                                }
                                .padding(.horizontal, 5)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(maxHeight: .infinity)
            }
            Spacer()
        }
        .fileImporter(
            isPresented: $isImportingPDF,
            allowedContentTypes: [UTType.pdf],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let selectedFile = try result.get().first else {
                    logDebug("PDF import cancelled or no file selected")
                    return
                }
                
                logDebug("PDF file selected from importer: \(selectedFile.lastPathComponent)")
                
                // Start accessing the file
                guard selectedFile.startAccessingSecurityScopedResource() else {
                    logDebug("⚠️ Security access denied for file: \(selectedFile.path)")
                    throw NSError(domain: "PDFSelectorViewError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Security access denied"])
                }
                
                // Create a copy of the file to avoid security access issues
                let tempDir = FileManager.default.temporaryDirectory
                let destURL = tempDir.appendingPathComponent(UUID().uuidString + ".pdf")
                
                logDebug("Creating temporary copy at: \(destURL.path)")
                
                try FileManager.default.copyItem(at: selectedFile, to: destURL)
                
                // Stop accessing the security-scoped resource
                selectedFile.stopAccessingSecurityScopedResource()
                
                // Check if the file is a valid PDF
                if let pdfDoc = PDFDocument(url: destURL) {
                    logDebug("✅ Valid PDF imported: pages: \(pdfDoc.pageCount)")
                    
                    // Set the selected file properties
                    selectedPDFURL = destURL
                    print("🟢 [DEBUG] PDFSelectorView: selectedPDFURL binding set to \(destURL.path)")
                    selectedPDFRecord = nil
                    print("🟢 [DEBUG] PDFSelectorView: selectedPDFRecord cleared (was import)")
                    selectedFileLabel = selectedFile.lastPathComponent
                    
                    // Use this newly created file for the actual record
                } else {
                    logDebug("❌ Invalid PDF file: Could not create PDFDocument")
                    throw NSError(domain: "PDFSelectorViewError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid PDF file"])
                }
            } catch {
                logDebug("❌ Error importing PDF: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
        .alert(isPresented: $showErrorAlert) {
            Alert(
                title: Text(isSpanish ? "Error" : "Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .frame(width: 800, height: 600) // Larger size to accommodate PDF preview
        .onAppear {
            fetchPDFs()
        }
        .onChange(of: selectedPDFRecord) { newRecord in
            if let record = newRecord, let asset = record["pdfFile"] as? CKAsset, let url = asset.fileURL {
                // logDebug("[PDFSelectorView] Loading preview PDFDocument for CKRecord asset: \(url) on thread: \(Thread.isMainThread ? \"main\" : \"background\"), QoS: \(qos_class_self())")
                isLoadingPreview = true
                DispatchQueue.global(qos: .userInitiated).async {
                    // print("[PDF LOAD] Starting load for \(url) on thread: \(Thread.isMainThread ? \"main\" : \"background\"), QoS: \(qos_class_self())")
                    let doc = PDFDocument(url: url)
                    // print("[PDF LOAD] Finished load for \(url) on thread: \(Thread.isMainThread ? \"main\" : \"background\"), QoS: \(qos_class_self())")
                    DispatchQueue.main.async {
                    self.previewPDFDocument = doc
                    self.isLoadingPreview = false
                        // logDebug("[PDFSelectorView] Preview PDFDocument loaded: \(doc != nil) on thread: \(Thread.isMainThread ? \"main\" : \"background\"), QoS: \(qos_class_self())")
                    }
                }
            } else {
                self.previewPDFDocument = nil
            }
        }
        .onChange(of: selectedPDFURL) { newURL in
            if let url = newURL {
                // logDebug("[PDFSelectorView] Loading preview PDFDocument for URL: \(url) on thread: \(Thread.isMainThread ? \"main\" : \"background\"), QoS: \(qos_class_self())")
                isLoadingPreview = true
                DispatchQueue.global(qos: .userInitiated).async {
                    // print("[PDF LOAD] Starting load for \(url) on thread: \(Thread.isMainThread ? \"main\" : \"background\"), QoS: \(qos_class_self())")
                    let doc = PDFDocument(url: url)
                    // print("[PDF LOAD] Finished load for \(url) on thread: \(Thread.isMainThread ? \"main\" : \"background\"), QoS: \(qos_class_self())")
                    DispatchQueue.main.async {
                    self.previewPDFDocument = doc
                    self.isLoadingPreview = false
                        // logDebug("[PDFSelectorView] Preview PDFDocument loaded: \(doc != nil) on thread: \(Thread.isMainThread ? \"main\" : \"background\"), QoS: \(qos_class_self())")
                    }
                }
            } else {
                self.previewPDFDocument = nil
            }
        }
    }
    
    // MARK: - Component Views
    
    private func selectedPDFPreview(for record: CKRecord) -> some View {
        VStack {
            if let title = record["title"] as? String {
                Text(title)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
            }
            
            if let asset = record["pdfFile"] as? CKAsset, let fileURL = asset.fileURL {
                if let pdfDoc = PDFDocument(url: fileURL) {
                    // Use PDFViewer for a better preview
                    PDFViewer(document: pdfDoc)
                        .frame(minWidth: 200, minHeight: 280)
                        .background(Color.white)
                        .cornerRadius(8)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .padding(10)
                } else {
                    // Fallback icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                            .frame(width: 100, height: 140)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.18), lineWidth: 1)
                            )
                        Image(systemName: "doc.text.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .foregroundColor(.blue)
                    }
                    .padding(10)
                    
                    Text(isSpanish ? "No se pudo cargar el PDF" : "Could not load PDF")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Group {
                    // Log debug message but don't render it
                    let _ = {
                        print("⚠️ Warning: PDF asset or fileURL is nil for record preview")
                        return EmptyView()
                    }()
                }
                
                // Show fallback placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                        .frame(width: 100, height: 140)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.18), lineWidth: 1)
                        )
                    Image(systemName: "exclamationmark.triangle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .foregroundColor(.orange)
                }
                .padding(10)
                
                Text(isSpanish ? "PDF no disponible" : "PDF Not Available")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func importedPDFPreview(for url: URL) -> some View {
        VStack {
            Text(isSpanish ? "Nuevo PDF" : "New PDF")
                .font(.headline)
                .padding(.top, 10)
                
            if let pdfDoc = PDFDocument(url: url) {
                // Show actual PDF preview
                PDFViewer(document: pdfDoc)
                    .frame(minWidth: 200, minHeight: 280)
                    .background(Color.white)
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .padding(10)
            } else {
                // Fallback if PDF can't be loaded
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                        .frame(width: 100, height: 140)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.18), lineWidth: 1)
                        )
                    Image(systemName: "doc.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .foregroundColor(.blue)
                }
                .padding(10)
            }
                
            Text(url.lastPathComponent)
                .font(.callout)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 10)
            Text(isSpanish ? "PDF importado" : "Imported PDF")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.bottom, 10)
    }
    
    private func noSelectionView() -> some View {
        VStack {
            Text(isSpanish ? "Ningún PDF seleccionado" : "No PDF Selected")
                .font(.headline)
                .padding(.top, 10)
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                    .frame(width: 100, height: 140)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.18), lineWidth: 1)
                    )
            Image(systemName: "doc.badge.plus")
                .resizable()
                .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                .foregroundColor(.secondary)
            }
                .padding(10)
            Text(isSpanish ? "Adjunte un PDF existente o importe uno nuevo" : "Attach an existing PDF or import a new one")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
            Spacer()
        }
        .padding(.bottom, 10)
    }
    
    private func pdfListItem(pdf: CKRecord, index: Int) -> some View {
        Button {
            selectExistingPDF(pdf, at: index)
        } label: {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(pdf["title"] as? String ?? "Unknown")
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    if let date = pdf["dateUploaded"] as? Date {
                        Text(formatDate(date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if selectedDocIndex == index {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selectedDocIndex == index ? 
                        Color.blue.opacity(0.1) : 
                        Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
    
    // Helper function to format dates consistently based on language setting
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = isSpanish ? Locale(identifier: "es_ES") : Locale(identifier: "en_US")
        return formatter.string(from: date)
    }
    
    private func generateThumbnail(for record: CKRecord) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                .frame(width: 100, height: 140)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.18), lineWidth: 1)
                )
            Image(systemName: "doc.richtext")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .foregroundColor(.blue)
                .background(Color.white)
        }
    }
    
    // MARK: - Helper Methods
    
    private func fetchPDFs() {
        logDebug("Fetching PDFs from CloudKit")
        isLoading = true
        
        // Create a more specific predicate that ensures we only get non-archived PDFs
        let predicate = NSPredicate(format: "isArchived != %d", 1)
        let query = CKQuery(recordType: "PDFDocumentItem", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "dateUploaded", ascending: false)]
        
        logDebug("Query Details:")
        logDebug("- Record Type: PDFDocumentItem")
        logDebug("- Predicate: \(predicate)")
        logDebug("- Sort Descriptor: dateUploaded (descending)")
        
        let operation = CKQueryOperation(query: query)
        operation.resultsLimit = 50
        
        var fetchedRecords: [CKRecord] = []
        
        operation.recordMatchedBlock = { (recordID, result) in
            switch result {
            case .success(let record):
                logDebug("Successfully fetched record: \(recordID.recordName)")
                logDebug("- Title: " + (record["title"] as? String ?? "No title"))
                logDebug("- Date Uploaded: " + String(describing: record["dateUploaded"] as? Date ?? Date()))
                logDebug("- Is Archived: " + String(describing: record["isArchived"] as? Int64 ?? 0))
                fetchedRecords.append(record)
            case .failure(let error):
                logDebug("Error fetching record \(recordID.recordName): \(error.localizedDescription)")
                if let ckError = error as? CKError {
                    logDebug("CloudKit Error Code: \(ckError.code.rawValue)")
                    logDebug("Error Description: \(ckError.localizedDescription)")
                    if let serverRecord = ckError.serverRecord {
                        logDebug("Server Record: \(serverRecord)")
                    }
                }
            }
        }
        
        operation.queryResultBlock = { result in
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success:
                    self.availablePDFs = fetchedRecords
                    logDebug("Fetched \(fetchedRecords.count) PDFs")
                case .failure(let error):
                    logDebug("Error fetching PDFs: \(error.localizedDescription)")
                    self.errorMessage = self.isSpanish ? 
                        "Error al cargar los PDFs: \(error.localizedDescription)" : 
                        "Error loading PDFs: \(error.localizedDescription)"
                    self.showErrorAlert = true
                    self.availablePDFs = []
                }
            }
        }
        
        database.add(operation)
    }
    
    private func refreshPDFs() {
        showRefreshIndicator = true
        fetchPDFs()
        
        // Auto-hide refresh indicator after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showRefreshIndicator = false
        }
    }
    
    private func selectExistingPDF(_ pdf: CKRecord, at index: Int) {
        selectedDocIndex = index
        print("🟢 [DEBUG] PDFSelectorView: setting selectedPDFRecord binding to \(pdf.recordID.recordName)")
        selectedPDFRecord = pdf
        selectedPDFURL = nil
        
        print("🟢 [DEBUG] PDFSelectorView: selectedPDFURL cleared, selectedFileLabel will be \(pdf["title"] as? String ?? "Unknown")")
        
        // Update the file label with the title
        selectedFileLabel = pdf["title"] as? String ?? "Unknown PDF"
        
        // Log detailed information about the selected PDF
        logDebug("Selected existing PDF at index \(index)")
        logDebug("PDF Record ID: \(pdf.recordID.recordName)")
        logDebug("PDF Title: \(selectedFileLabel)")
        if let creationDate = pdf.creationDate {
            logDebug("PDF Creation Date: \(creationDate)")
        }
        if let asset = pdf["pdfFile"] as? CKAsset, let fileURL = asset.fileURL {
            logDebug("PDF File URL: \(fileURL)")
            isLoadingPreview = true
            DispatchQueue.global(qos: .userInitiated).async {
                let doc = PDFDocument(url: fileURL)
                DispatchQueue.main.async {
                    self.previewPDFDocument = doc
                    self.isLoadingPreview = false
                    self.logDebug("Loaded preview for selected PDF: \(self.selectedFileLabel)")
                    self.logDebug("PDF document loaded: \(doc != nil), page count: \(doc?.pageCount ?? 0)")
                }
            }
        } else {
            logDebug("⚠️ Warning: PDF asset or fileURL is nil")
        }
    }
}

/// View representing a single PDF item in the grid
struct SelectorPDFItemView: View {
    let record: CKRecord
    @Binding var selectedPDFRecord: CKRecord?
    @Binding var selectedPDFURL: URL?
    @Binding var selectedFileLabel: String
    @Binding var selectedDocument: PDFDocument?
    @Binding var thumbnailImage: NSImage?
    @Binding var isSpanish: Bool
    
    var body: some View {
        VStack {
            // Thumbnail or placeholder
            ZStack {
                Rectangle()
                    .fill(Color(NSColor.controlBackgroundColor))
                    .aspectRatio(0.75, contentMode: .fit)
                    .cornerRadius(6)
                
                if let thumbnailImage = thumbnailImage {
                    Image(nsImage: thumbnailImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .cornerRadius(6)
                } else {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                }
                
                // Selection indicator
                if selectedPDFRecord?.recordID == record.recordID {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.blue, lineWidth: 3)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                        .background(Circle().fill(Color.white).frame(width: 22, height: 22))
                        .position(x: 30, y: 30)
                }
            }
            .onHover { hovering in
                // Implementation of onHover
            }
            
            // Title
            Text(record["title"] as? String ?? "Untitled")
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundColor(selectedPDFRecord?.recordID == record.recordID ? .blue : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Date
            if let date = record["dateUploaded"] as? Date {
                Text(dateFormatter.string(from: date))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(6)
        .background(selectedPDFRecord?.recordID == record.recordID ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .onAppear {
            // Implementation of onAppear
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        formatter.locale = isSpanish ? Locale(identifier: "es_ES") : Locale(identifier: "en_US")
        return formatter
    }
}

#Preview {
    PDFSelectorView(
        selectedPDFRecord: .constant(nil),
        selectedPDFURL: .constant(nil),
        selectedFileLabel: .constant(""),
        isSpanish: .constant(false)
    )
} 