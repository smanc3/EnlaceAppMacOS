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
        
        // Add visual debugging to see view boundaries
        pdfView.wantsLayer = true
        pdfView.layer?.borderWidth = 2.0
        pdfView.layer?.borderColor = NSColor.red.cgColor
        
        print("📄 PDFViewer: Initial view frame: \(pdfView.frame)")
        
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
            print("📄 PDFViewer: View frame before setting document: \(pdfView.frame)")
            
            // Check for parent view
            if let superview = pdfView.superview {
                print("📄 PDFViewer: Has superview with frame: \(superview.frame)")
            } else {
                print("⚠️ PDFViewer WARNING: No superview available yet")
            }
            
            // Set the document
            pdfView.document = document
            
            // Log success or failure
            if pdfView.document == nil {
                print("❌ PDFViewer ERROR: Document not set properly in PDFView after delay")
            } else {
                print("✅ PDFViewer: Document set successfully, page count: \(pdfView.document?.pageCount ?? 0)")
                
                // Force layout and go to first page
                pdfView.needsLayout = true
                pdfView.layoutSubtreeIfNeeded()
                pdfView.needsDisplay = true
                
                if let firstPage = pdfView.document?.page(at: 0) {
                    let pageBounds = firstPage.bounds(for: .mediaBox)
                    pdfView.go(to: firstPage)
                    
                    // Get view dimensions after layout
                    let viewWidth = pdfView.bounds.width
                    let viewHeight = pdfView.bounds.height
                    
                    print("📄 PDFViewer: View dimensions after layout: \(viewWidth) x \(viewHeight)")
                    
                    // Check for problematic dimensions
                    if viewWidth < 50 || viewHeight < 50 {
                        print("⚠️ PDFViewer WARNING: View dimensions are too small!")
                        
                        // Try to fix with parent dimensions
                        if let superview = pdfView.superview {
                            let adjustedFrame = NSRect(
                                x: pdfView.frame.origin.x,
                                y: pdfView.frame.origin.y,
                                width: max(superview.frame.width * 0.9, 600),
                                height: max(superview.frame.height * 0.9, 500)
                            )
                            pdfView.frame = adjustedFrame
                            print("📄 PDFViewer: Explicitly set frame to: \(adjustedFrame)")
                        } else {
                            // Set default size
                            pdfView.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
                            print("📄 PDFViewer: Set default frame size: 800x600")
                        }
                    }
                    
                    // Apply appropriate scale factor
                    if viewWidth > 0 && viewHeight > 0 && pageBounds.width > 0 && pageBounds.height > 0 {
                        let widthScale = viewWidth / pageBounds.width
                        let heightScale = viewHeight / pageBounds.height
                        let scaleFactor = min(widthScale, heightScale) * 0.9
                        
                        print("📄 PDFViewer: Calculated scale factor: \(scaleFactor)")
                        let finalScale = max(0.5, scaleFactor)
                        pdfView.scaleFactor = finalScale
                        print("📄 PDFViewer: Applied scale factor: \(finalScale)")
                    } else {
                        // Apply default scale
                        pdfView.scaleFactor = 1.0
                        print("📄 PDFViewer: Applied default scale factor: 1.0")
                    }
                }
            }
            
            // Log final state
            print("📄 PDFViewer: Final view frame: \(pdfView.frame)")
            print("📄 PDFViewer: Final view bounds: \(pdfView.bounds)")
        }
        
        return pdfView
    }
    
    func updateNSView(_ pdfView: PDFView, context: Context) {
        print("📄 PDFViewer: Updating PDFView, current frame: \(pdfView.frame)")
        
        // Use a longer delay to ensure PDFView is ready for document update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Set the document
            pdfView.document = document
            
            // Log success or failure
            if pdfView.document == nil {
                print("❌ PDFViewer ERROR: Document not updated properly in PDFView after delay")
            } else {
                print("✅ PDFViewer: Document updated successfully, page count: \(pdfView.document?.pageCount ?? 0)")
                
                // Force layout refresh
                pdfView.needsLayout = true
                pdfView.layoutSubtreeIfNeeded()
                pdfView.needsDisplay = true
                
                // Check frame after update
                print("📄 PDFViewer: View frame after update: \(pdfView.frame)")
                print("📄 PDFViewer: View bounds after update: \(pdfView.bounds)")
                
                // Fix small dimensions if needed
                if pdfView.frame.width < 50 || pdfView.frame.height < 50 {
                    print("⚠️ PDFViewer WARNING: View dimensions too small after update")
                    
                    if let superview = pdfView.superview {
                        print("📄 PDFViewer: Superview dimensions: \(superview.frame.width) x \(superview.frame.height)")
                        
                        // Set reasonable dimensions based on parent
                        let adjustedFrame = NSRect(
                            x: pdfView.frame.origin.x,
                            y: pdfView.frame.origin.y,
                            width: max(superview.frame.width * 0.9, 600),
                            height: max(superview.frame.height * 0.9, 500)
                        )
                        pdfView.frame = adjustedFrame
                        print("📄 PDFViewer: Adjusted frame to: \(adjustedFrame)")
                    }
                }
                
                // Ensure content is visible at good size
                if let firstPage = document.page(at: 0) {
                    pdfView.go(to: firstPage)
                    pdfView.scaleFactor = max(0.5, pdfView.scaleFactorForSizeToFit)
                    print("📄 PDFViewer: Reset to first page with scale: \(pdfView.scaleFactor)")
                }
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
    
    // MARK: - Debug Logging
    
    private func logDebug(_ message: String) {
        print("📄 PDFSelectorView: \(message)")
    }
    
    // MARK: - View Lifecycle
    
    var body: some View {
        VStack(spacing: 0) {
            // HEADER
            HStack {
                Text(isSpanish ? "Seleccione un PDF" : "Select a PDF Document")
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
                        if let selectedRecord = selectedPDFRecord {
                            selectedPDFPreview(for: selectedRecord)
                        } else if let url = selectedPDFURL {
                            importedPDFPreview(for: url)
                        } else {
                            noSelectionView()
                        }
                    }
                    .frame(width: 210)
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
        }
        .fileImporter(
            isPresented: $isImportingPDF,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            handleFileImportResult(result)
        }
        .alert(isPresented: $showErrorAlert) {
            Alert(
                title: Text(isSpanish ? "Error" : "Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            fetchPDFs()
        }
    }
    
    // MARK: - Component Views
    
    private func selectedPDFPreview(for record: CKRecord) -> some View {
        VStack {
            Text(isSpanish ? "PDF Seleccionado" : "Selected PDF")
                .font(.headline)
                .padding(.top, 10)
            
            generateThumbnail(for: record)
                .padding(10)
            
            Text(record["title"] as? String ?? "Unknown")
                .font(.callout)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 10)
            
            if let date = record["dateUploaded"] as? Date {
                Text(date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.bottom, 10)
    }
    
    private func importedPDFPreview(for url: URL) -> some View {
        VStack {
            Text(isSpanish ? "Nuevo PDF" : "New PDF")
                .font(.headline)
                .padding(.top, 10)
            
            Image(systemName: "doc.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 100)
                .foregroundColor(.blue)
                .padding(10)
            
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
            
            Image(systemName: "doc.badge.plus")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 100)
                .foregroundColor(.secondary)
                .padding(10)
            
            Text(isSpanish ? 
                "Seleccione un PDF existente o importe uno nuevo" : 
                "Select an existing PDF or import a new one")
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
            logDebug("Selected PDF at index \(index): \(pdf["title"] as? String ?? "Unknown")")
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
                        Text(date, style: .date)
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
    
    private func generateThumbnail(for record: CKRecord) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white)
                .shadow(radius: 2)
                .frame(width: 80, height: 100)
            
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
        
        let query = CKQuery(recordType: "PDFDocumentItem", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "dateUploaded", ascending: false)]
        
        let operation = CKQueryOperation(query: query)
        operation.resultsLimit = 50
        
        var fetchedRecords: [CKRecord] = []
        
        operation.recordMatchedBlock = { (recordID, result) in
            switch result {
            case .success(let record):
                fetchedRecords.append(record)
            case .failure(let error):
                logDebug("Error fetching record \(recordID.recordName): \(error.localizedDescription)")
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
        selectedPDFRecord = pdf
        selectedPDFURL = nil
        
        // Update the file label with the title
        selectedFileLabel = pdf["title"] as? String ?? "Unknown PDF"
        
        logDebug("Selected existing PDF: \(selectedFileLabel)")
    }
    
    private func handleFileImportResult(_ result: Result<[URL], Error>) {
        logDebug("Handling file import result")
        
        do {
            // Get the selected file URL
            guard let selectedFile = try result.get().first else {
                logDebug("No file was selected")
                return
            }
            
            // Start file access
            if !selectedFile.startAccessingSecurityScopedResource() {
                logDebug("Failed to access security scoped resource")
                errorMessage = isSpanish ? 
                    "No se pudo acceder al archivo seleccionado." : 
                    "Could not access the selected file."
                showErrorAlert = true
                return
            }
            
            // Copy the file to a temporary location that we can access later
            let fileName = selectedFile.lastPathComponent
            let tempDir = FileManager.default.temporaryDirectory
            let copiedFile = tempDir.appendingPathComponent(fileName)
            
            logDebug("Original file: \(selectedFile.path)")
            logDebug("Copying to: \(copiedFile.path)")
            
            // Remove existing file if needed
            try? FileManager.default.removeItem(at: copiedFile)
            
            // Copy the file
            try FileManager.default.copyItem(at: selectedFile, to: copiedFile)
            
            // Stop accessing the original file
            selectedFile.stopAccessingSecurityScopedResource()
            
            // Update our state variables
            selectedPDFURL = copiedFile
            selectedPDFRecord = nil
            selectedDocIndex = nil
            selectedFileLabel = fileName
            
            logDebug("Successfully imported PDF: \(fileName)")
            
        } catch {
            logDebug("Error handling file import: \(error.localizedDescription)")
            errorMessage = isSpanish ? 
                "Error al importar el archivo: \(error.localizedDescription)" : 
                "Error importing file: \(error.localizedDescription)"
            showErrorAlert = true
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