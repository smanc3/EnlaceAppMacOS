//
//  Archive.swift
//  Enlace Admin (Preview)
//
//  Created by Steven Mancilla on 3/4/25.
//

import SwiftUI
import CloudKit
import PDFKit
// Make sure to explicitly import the module where CalendarEvent is defined
import Foundation
// Remove all code related to the local CalendarEvent definition (already gone)

// MARK: - PDFViewer
struct ArchivePDFViewer: NSViewRepresentable {
    let document: PDFKit.PDFDocument
    
    init(document: PDFKit.PDFDocument) {
        print("📑 PDF: Initializing ArchivePDFViewer with document")
        print("📑 PDF: Document page count: \(document.pageCount)")
        
        // Validate document
        if document.pageCount == 0 {
            print("⚠️ PDF WARNING: Document has no pages!")
        }
        
        // Add more document diagnostics
        if document.pageCount > 0, let firstPage = document.page(at: 0) {
            let pageBounds = firstPage.bounds(for: .mediaBox)
            print("📑 PDF: First page dimensions: \(pageBounds.width) x \(pageBounds.height)")
            if pageBounds.width < 10 || pageBounds.height < 10 {
                print("⚠️ PDF WARNING: Page dimensions are unusually small!")
            }
        } else {
            print("⚠️ PDF WARNING: Document has no pages or couldn't access first page")
        }
        
        self.document = document
    }
    
    func makeNSView(context: Context) -> PDFView {
        print("📑 PDF: Creating PDFView in ArchivePDFViewer")
        let pdfView = PDFView()
        
        // Add visual debugging to see view boundaries
        pdfView.wantsLayer = true
        pdfView.layer?.borderWidth = 1.0
        pdfView.layer?.borderColor = NSColor.systemBlue.cgColor
        
        // Configure view properties - do this BEFORE setting document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.backgroundColor = NSColor.textBackgroundColor
        
        // Critical: Set these to ensure proper sizing
        pdfView.translatesAutoresizingMaskIntoConstraints = true
        pdfView.autoresizingMask = [.width, .height]
        
        // Enable better interaction
        pdfView.enableDataDetectors = true
        
        // Ensure we can zoom in and out sufficiently
        pdfView.minScaleFactor = 0.25
        pdfView.maxScaleFactor = 4.0
        
        // Set the document immediately first
        pdfView.document = document
        
        // Print initial frame for debugging
        print("📑 PDF: Initial view frame: \(pdfView.frame)")
        
        // Set up a delayed initialization to ensure proper layout
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Double-check document is still set
            if pdfView.document == nil {
                print("📑 PDF: Document not set after delay, setting again")
                pdfView.document = document
            }
            
            // Check if document is valid
            if let pdfDoc = pdfView.document, pdfDoc.pageCount > 0 {
                print("📑 PDF: Document valid with \(pdfDoc.pageCount) pages")
                
                // Force layout refresh
                pdfView.needsLayout = true
                pdfView.layoutSubtreeIfNeeded()
                
                // Navigate to first page
                if let firstPage = pdfDoc.page(at: 0) {
                    pdfView.go(to: firstPage)
                    
                    // Calculate best fit scale
                    pdfView.autoScales = true
                    let fitScale = pdfView.scaleFactorForSizeToFit
                    
                    // Apply scale with slight reduction for better viewing
                    let finalScale = max(0.5, fitScale * 0.95)
                    pdfView.scaleFactor = finalScale
                    print("📑 PDF: Applied scale factor: \(finalScale)")
                    
                    // Print final frame for debugging
                    print("📑 PDF: Final view frame: \(pdfView.frame)")
                }
            } else {
                print("⚠️ PDF WARNING: Document invalid or has no pages")
            }
            
            // Final refresh
            pdfView.needsDisplay = true
        }
        
        return pdfView
    }
    
    func updateNSView(_ pdfView: PDFView, context: Context) {
        print("📑 PDF: Updating PDFView in ArchivePDFViewer")
        
        // Update the document
        pdfView.document = document
        
        // Set up delayed update to ensure proper layout
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Verify document is set
            if pdfView.document == nil {
                print("⚠️ PDF WARNING: Document not set during update, trying again")
                pdfView.document = document
            }
            
            // Check document validity
            if let pdfDoc = pdfView.document, pdfDoc.pageCount > 0 {
                print("📑 PDF: Update successful, document has \(pdfDoc.pageCount) pages")
                
                // Force layout refresh
                pdfView.needsLayout = true
                pdfView.layoutSubtreeIfNeeded()
                
                // Navigate to first page and scale appropriately
                if let firstPage = pdfDoc.page(at: 0) {
                    pdfView.go(to: firstPage)
                    pdfView.autoScales = true
                    pdfView.scaleFactor = max(0.5, pdfView.scaleFactorForSizeToFit * 0.95)
                    
                    // Print frame after update
                    print("📑 PDF: View frame after update: \(pdfView.frame)")
                }
            } else {
                print("⚠️ PDF WARNING: Document invalid or empty after update")
            }
            
            // Final refresh
            pdfView.needsDisplay = true
        }
    }
}

struct PopupView3: View {
    @Binding var showPopupArchive: Bool  // Control popup visibility
    @Binding var isSpanish: Bool      // Control language selection
    var onEventArchived: (() -> Void)? = nil  // Callback for when an event is archived

    @State private var selectedEventID: String = ""
    @State private var events: [CalendarEvent] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var archiveDate: Date = Date()
    @State private var showConfirmation: Bool = false
    @State private var selectedEvent: CalendarEvent? = nil
    @State private var isShowingPDFPreview: Bool = false
    @State private var pdfDocument: PDFKit.PDFDocument? = nil
    @State private var isLoadingPDF: Bool = false
    @State private var pdfError: String? = nil
    @State private var pdfReadyForDisplay: Bool = false  // New state to track PDF readiness
    
    private let container = CKContainer(identifier: "iCloud.PearInc.EICT-iOS-16")
    private var database: CKDatabase {
        return container.publicCloudDatabase
    }

    var body: some View {
            VStack(spacing: 15) {
                // Title
                Text(isSpanish ? "Archivar Evento" : "Archive Event")
                    .font(.title)
                    .fontWeight(.bold)
                
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.2)
                    .padding()
            } else if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        // Event Picker
                        Picker(
                            isSpanish ? "Seleccionar Evento" : "Select Event",
                            selection: $selectedEventID
                        ) {
                            Text(isSpanish ? "Seleccione un evento" : "Select an event")
                                .tag("")
                            
                            ForEach(events) { event in
                                Text(event.title)
                                    .tag(event.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.horizontal)
                        .onChange(of: selectedEventID) { oldValue, newValue in
                            selectedEvent = events.first(where: { $0.id == newValue })
                            // Clear previous PDF
                            pdfDocument = nil
                            pdfError = nil
                        }
                        
                        if let event = selectedEvent {
                            // Event details
                            VStack(alignment: .leading, spacing: 8) {
                                Text(isSpanish ? "Detalles del evento:" : "Event details:")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                
                                HStack {
                                    Text(isSpanish ? "Fecha:" : "Date:")
                                        .fontWeight(.medium)
                                    Text(DateFormatter.localizedString(from: event.startDate, dateStyle: .medium, timeStyle: .short))
                                }
                                
                                HStack {
                                    Text(isSpanish ? "Ubicación:" : "Location:")
                                        .fontWeight(.medium)
                                    Text(event.location ?? "")
                                }
                                
                                // Add PDF view button if the event has a PDF reference
                                if event.pdfReference != nil {
                                    HStack {
                                        Text(isSpanish ? "Documento PDF:" : "PDF Document:")
                                            .fontWeight(.medium)
                                        
                                        Spacer()
                                        
                                        if isLoadingPDF {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                            Text(isSpanish ? "Cargando..." : "Loading...")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        } else if let error = pdfError {
                                            Text(error)
                                                .foregroundColor(.red)
                                                .font(.caption)
                                        } else if pdfDocument != nil {
                                            Button {
                                                print("📑 PDF: View PDF button tapped")
                                                // Use the dedicated function to ensure PDF is ready
                                                loadAndShowPDF()
                                            } label: {
                                                Text(isSpanish ? "Ver PDF" : "View PDF")
                                            }
                                            .buttonStyle(.bordered)
                                        } else {
                                            Button {
                                                print("📑 PDF: Load PDF button tapped for event: \(event.title)")
                                                // Clear states and load the PDF
                                                pdfDocument = nil
                                                pdfError = nil
                                                pdfReadyForDisplay = false
                                                
                                                // Use the loadPDFWithCompletion to provide better error handling
                                                loadPDFWithCompletion {
                                                    print("📑 PDF: Load completed")
                                                    // No need to show preview here - user will click View PDF
                                                }
                                            } label: {
                                                Text(isSpanish ? "Cargar PDF" : "Load PDF")
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                            .padding(.horizontal)
                        }
                        
                        // DatePicker
                        DatePicker(
                            isSpanish ? "Fecha de Archivo" : "Archive Date",
                            selection: $archiveDate
                        )
                        .datePickerStyle(.compact)
                        .padding(.horizontal)
                    }
                }
                
                // Archive and Cancel Buttons
                HStack {
                    Button(isSpanish ? "Cancelar" : "Cancel") {
                        showPopupArchive = false
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button(isSpanish ? "Archivar" : "Archive") {
                        showConfirmation = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedEventID.isEmpty)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 10)
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(isSpanish ? "Notificación" : "Notification"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(isSpanish ? "Confirmar archivo" : "Confirm Archive", isPresented: $showConfirmation) {
            Button(isSpanish ? "Cancelar" : "Cancel", role: .cancel) { }
            Button(isSpanish ? "Archivar" : "Archive", role: .destructive) {
                archiveSelectedEvent()
            }
        } message: {
            Text(isSpanish ? 
                "¿Está seguro de que desea archivar este evento? Esta acción eliminará el evento del calendario activo." : 
                "Are you sure you want to archive this event? This action will remove the event from the active calendar.")
        }
        .onAppear {
            Task {
                await loadEvents()
            }
        }
        .sheet(isPresented: $isShowingPDFPreview) {
            // Double check we have a valid document to prevent nil document issues
            if let pdf = pdfDocument, pdf.pageCount > 0 {
                VStack {
                    HStack {
                        Text(isSpanish ? "Vista Previa del PDF" : "PDF Preview")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(isSpanish ? "Cerrar" : "Close") {
                            print("📑 PDF: Closing PDF preview")
                            isShowingPDFPreview = false
                        }
                        .buttonStyle(.bordered)
                        .keyboardShortcut(.escape, modifiers: [])
                    }
                    .padding()
                    
                    ArchivePDFViewer(document: pdf)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onAppear {
                            print("📑 PDF: ArchivePDFViewer appeared with \(pdf.pageCount) pages")
                        }
                }
                .frame(width: 1000, height: 800)
                .onAppear {
                    print("📑 PDF: PDF preview sheet appeared")
                }
            } else {
                VStack {
                    Text(isSpanish ? "Error: No se pudo cargar el PDF" : "Error: Could not load PDF")
                        .foregroundColor(.red)
                    
                    Button(isSpanish ? "Cerrar" : "Close") {
                        isShowingPDFPreview = false
                    }
                    .buttonStyle(.bordered)
                    .padding()
                }
                .padding()
                .onAppear {
                    print("📑 PDF ERROR: Attempted to show PDF sheet but document is nil or empty")
                    // Auto-close the sheet after a short delay and update error state
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        isShowingPDFPreview = false
                        pdfError = isSpanish ? 
                            "Error: No se pudo cargar el PDF correctamente" : 
                            "Error: Could not load the PDF properly"
                    }
                }
            }
        }
        .onChange(of: pdfDocument) { oldValue, newValue in
            // When PDF document is loaded, mark it as ready for display
            if newValue != nil {
                pdfReadyForDisplay = true
            } else {
                pdfReadyForDisplay = false
            }
        }
    }
    
    // Add PDF loading function with explicit completion handler
    private func loadPDFWithCompletion(_ completion: @escaping () -> Void) {
        guard let event = selectedEvent, let reference = event.pdfReference else {
            print("📑 PDF ERROR: No event or PDF reference available")
            pdfError = isSpanish ? "No hay referencia de PDF disponible" : "No PDF reference available"
            completion()
            return
        }
        
        print("📑 PDF: Starting to load PDF for event: \(event.title)")
        print("📑 PDF: Reference recordID: \(reference.recordID.recordName)")
        
        // Clear previous PDF document to reset state
        pdfDocument = nil
        isLoadingPDF = true
        pdfError = nil
        pdfReadyForDisplay = false
        
        Task {
            print("📑 PDF: Making CloudKit request to fetch PDF record")
            do {
                print("📑 PDF: Fetching record with ID: \(reference.recordID.recordName)")
                let record = try await container.publicCloudDatabase.record(for: reference.recordID)
                print("📑 PDF: Successfully fetched record from CloudKit")
                print("📑 PDF: Record keys: \(record.allKeys().joined(separator: ", "))")
                
                await MainActor.run {
                    print("📑 PDF: Processing record on main thread")
                    
                    if let asset = record["pdfFile"] as? CKAsset, let fileURL = asset.fileURL {
                        print("📑 PDF: Asset has fileURL: \(fileURL.path)")
                        print("📑 PDF: File exists: \(FileManager.default.fileExists(atPath: fileURL.path))")
                        
                        // Try to get file size
                        if let fileAttributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                           let fileSize = fileAttributes[.size] as? Int64 {
                            print("📑 PDF: File size: \(fileSize) bytes")
                            if fileSize <= 0 {
                                print("📑 PDF ERROR: File is empty (0 bytes)")
                                self.isLoadingPDF = false
                                self.pdfError = isSpanish ? 
                                    "El archivo PDF está vacío" : 
                                    "PDF file is empty"
                                completion()
                                return
                            }
                        }
                        
                        // Try direct loading first
                        if let document = PDFKit.PDFDocument(url: fileURL) {
                            print("📑 PDF: Successfully created PDFDocument")
                            print("📑 PDF: Document page count: \(document.pageCount)")
                            
                            if document.pageCount > 0 {
                                // Document loaded successfully with at least one page
                                // Use a longer delay to ensure the UI is ready (0.3 seconds)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    self.pdfDocument = document
                                    self.isLoadingPDF = false
                                    self.pdfReadyForDisplay = true
                                    print("📑 PDF: Successfully loaded PDF document with \(document.pageCount) pages")
                                    completion()
                                }
                            } else {
                                print("📑 PDF ERROR: PDF document has 0 pages")
                                self.isLoadingPDF = false
                                self.pdfError = isSpanish ?
                                    "El documento PDF no tiene páginas" :
                                    "PDF document has no pages"
                                completion()
                            }
                        } else {
                            print("📑 PDF ERROR: Failed to create PDFDocument from URL, trying with data")
                            
                            // Try with data as fallback
                            do {
                                let data = try Data(contentsOf: fileURL)
                                print("📑 PDF: Read \(data.count) bytes from file")
                                
                                if data.count > 0 {
                                    if let document = PDFKit.PDFDocument(data: data) {
                                        print("📑 PDF: Successfully created PDFDocument from data")
                                        print("📑 PDF: Document page count: \(document.pageCount)")
                                        
                                        if document.pageCount > 0 {
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                self.pdfDocument = document
                                                self.isLoadingPDF = false
                                                self.pdfReadyForDisplay = true
                                                print("📑 PDF: Successfully loaded PDF document from data with \(document.pageCount) pages")
                                                completion()
                                            }
                                        } else {
                                            print("📑 PDF ERROR: PDF document from data has 0 pages")
                                            self.isLoadingPDF = false
                                            self.pdfError = isSpanish ?
                                                "El documento PDF no tiene páginas" :
                                                "PDF document has no pages"
                                            completion()
                                        }
                                    } else {
                                        print("📑 PDF ERROR: Failed to create PDFDocument from data")
                                        self.isLoadingPDF = false
                                        self.pdfError = isSpanish ?
                                            "No se pudo crear el documento PDF" :
                                            "Could not create PDF document"
                                        completion()
                                    }
                                } else {
                                    print("📑 PDF ERROR: File data is empty")
                                    self.isLoadingPDF = false
                                    self.pdfError = isSpanish ?
                                        "El archivo PDF está vacío" :
                                        "PDF file is empty"
                                    completion()
                                }
                            } catch {
                                print("📑 PDF ERROR: Error reading file data: \(error)")
                                self.isLoadingPDF = false
                                self.pdfError = isSpanish ?
                                    "Error al leer los datos del archivo: \(error.localizedDescription)" :
                                    "Error reading file data: \(error.localizedDescription)"
                                completion()
                            }
                        }
                    } else {
                        print("📑 PDF ERROR: No pdfFile asset found in record or fileURL is nil")
                        self.isLoadingPDF = false
                        self.pdfError = isSpanish ?
                            "No se encontró el archivo PDF" :
                            "PDF file not found"
                        completion()
                    }
                }
            } catch {
                print("📑 PDF ERROR: Failed to fetch record: \(error.localizedDescription)")
                if let ckError = error as? CKError {
                    print("📑 PDF ERROR: CloudKit error code: \(ckError.errorCode)")
                }
                
                await MainActor.run {
                    self.isLoadingPDF = false
                    self.pdfError = isSpanish ?
                        "Error al cargar el PDF: \(error.localizedDescription)" :
                        "Error loading PDF: \(error.localizedDescription)"
                    completion()
                }
            }
        }
    }
    
    // Simple wrapper for the existing loadPDF method
    private func loadPDF() {
        loadPDFWithCompletion {
            // No additional action needed after initial load
        }
    }
    
    func loadEvents() async {
        isLoading = true
        errorMessage = nil
        
        print("🗄️ Archive: Starting to load events")
        
        let database = CKContainer(identifier: "iCloud.PearInc.EICT-iOS-16").publicCloudDatabase
        
        print("🗄️ Archive: Using direct fetch approach to avoid query issues")
        
        do {
            // Get record zones first - this should work without query issues
            let zones = try await database.allRecordZones()
            print("🗄️ Archive: Successfully retrieved \(zones.count) record zones")
            
            // If there's a default zone, use that
            guard let defaultZone = zones.first(where: { $0.zoneID.zoneName == "_defaultZone" }) ?? zones.first else {
                throw NSError(domain: "ArchiveError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No zones found"])
            }
            
            // Manually create recordIDs for testing - in production you would obtain these another way
            // This is just to test if we can load at least one record without using a query
            print("🗄️ Archive: Attempting direct fetch operation (no query)")
            
            // Create an operation to fetch all records of type "CalendarEvent"
            let configuration = CKOperation.Configuration()
            configuration.timeoutIntervalForRequest = 30
            
            let fetchOperation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [defaultZone.zoneID], configurationsByRecordZoneID: [:])
            fetchOperation.configuration = configuration
            
            var fetchedRecords: [CKRecord] = []
            
            // Set up completion handlers
            fetchOperation.recordWasChangedBlock = { (recordID, result) in
                switch result {
                case .success(let record):
                    if record.recordType == "CalendarEvent" {
                        fetchedRecords.append(record)
                        print("🗄️ Archive: Found record: \(record.recordID.recordName)")
                    }
                case .failure(let error):
                    print("🗄️ Archive: Error with record: \(error.localizedDescription)")
                }
            }
            
            fetchOperation.recordZoneFetchResultBlock = { zoneID, result in
                switch result {
                case .success(let changeToken):
                    print("🗄️ Archive: Successfully fetched zone \(zoneID.zoneName), more changes coming: \(changeToken.moreComing)")
                case .failure(let error):
                    print("🗄️ Archive: Error fetching zone \(zoneID.zoneName): \(error.localizedDescription)")
                }
            }
            
            // Use a continuation to handle the final result
            _ = await withCheckedContinuation { continuation in
                fetchOperation.fetchRecordZoneChangesResultBlock = { result in
                    switch result {
                    case .success:
                        print("🗄️ Archive: Operation completed successfully")
                    case .failure(let error):
                        print("🗄️ Archive: Operation failed: \(error.localizedDescription)")
                    }
                    continuation.resume(returning: ())
                }
                
                // Add operation to database
                database.add(fetchOperation)
            }
            
            // Process the fetched records
            print("🗄️ Archive: Retrieved \(fetchedRecords.count) CalendarEvent records")
            
            if fetchedRecords.isEmpty {
                // Fallback to a direct CloudKit fetch with a small batch size
                print("🗄️ Archive: No records found with zone changes operation, trying fallback method")
                let fallbackRecords = try await fetchCalendarEventsWithFallback(database: database)
                fetchedRecords = fallbackRecords
            }
            
            var recordsWithMissingMirror: [CKRecord] = []
            
            // Process the records
            for record in fetchedRecords {
                if record["recordNameMirror"] == nil {
                    record["recordNameMirror"] = record.recordID.recordName
                    recordsWithMissingMirror.append(record)
                }
            }
            
            // Save the updated records
            for record in recordsWithMissingMirror {
                Task {
                    do {
                        let _ = try await database.save(record)
                        print("Updated record with missing recordNameMirror")
                    } catch {
                        print("Failed to update record with recordNameMirror: \(error.localizedDescription)")
                    }
                }
            }
            
            // Sort the records by startDate
            let sortedRecords = fetchedRecords.sorted {
                let date1 = $0["startDate"] as? Date ?? Date()
                let date2 = $1["startDate"] as? Date ?? Date()
                return date1 < date2
            }
            
            self.events = sortedRecords.map { CalendarEvent(record: $0) }
            print("Mapped \(self.events.count) records to CalendarEvent objects")
        } catch {
            errorMessage = "Failed to load events: \(error.localizedDescription)"
            if let ckError = error as? CKError {
                print("CloudKit error: \(ckError.localizedDescription)")
                print("Error code: \(ckError.errorCode)")
                if let errorInfo = ckError.userInfo["NSDebugDescription"] as? String {
                    print("Debug description: \(errorInfo)")
                }
            } else {
                print("Unknown error: \(error.localizedDescription)")
            }
        }
        
        isLoading = false
    }
    
    // Fallback method for fetching calendar events without a query
    private func fetchCalendarEventsWithFallback(database: CKDatabase) async throws -> [CKRecord] {
        print("🗄️ Archive: Using fallback method to fetch events")
        
        // Create a fetch records operation with an empty array
        var records: [CKRecord] = []
        
        print("🗄️ Archive: Using date-based query strategy")
        
        // Create a very wide date range to capture all events
        let distantPast = Date.distantPast
        let distantFuture = Date.distantFuture
        
        // Create a query that filters on startDate (which should be queryable)
        let datePredicate = NSPredicate(format: "startDate >= %@ AND startDate <= %@", distantPast as NSDate, distantFuture as NSDate)
        let query = CKQuery(recordType: "CalendarEvent", predicate: datePredicate)
        
        // Try to fetch records directly using the records(matching:) API
        do {
            print("🗄️ Archive: Executing date-based query from \(distantPast) to \(distantFuture)")
            let (matchResults, _) = try await database.records(matching: query)
            
            // Process results directly
            for (_, recordResult) in matchResults {
                switch recordResult {
                case .success(let record):
                    records.append(record)
                    print("🗄️ Archive: Successfully found record: \(record.recordID.recordName), title: \(record["title"] ?? "nil")")
                case .failure(let error):
                    print("🗄️ Archive: Error loading record: \(error.localizedDescription)")
                }
            }
            
            print("🗄️ Archive: Successfully loaded \(records.count) records directly")
        } catch {
            print("🗄️ Archive: Query failed with error: \(error.localizedDescription)")
            if let ckError = error as? CKError {
                print("🗄️ Archive: CloudKit error code: \(ckError.errorCode)")
                if let serverDesc = ckError.userInfo["ServerErrorDescription"] as? String {
                    print("🗄️ Archive: Server error description: \(serverDesc)")
                }
            }
            
            // Try one more approach - use a simple boolean true predicate with explicit zone
            print("🗄️ Archive: Trying simple predicate as last resort")
            do {
                let simpleQuery = CKQuery(recordType: "CalendarEvent", predicate: NSPredicate(value: true))
                let (simpleResults, _) = try await database.records(matching: simpleQuery, inZoneWith: nil)
                
                for (_, recordResult) in simpleResults {
                    if case .success(let record) = recordResult {
                        records.append(record)
                        print("🗄️ Archive: Found record with simple query: \(record.recordID.recordName)")
                    }
                }
                print("🗄️ Archive: Simple query found \(records.count) records")
            } catch {
                print("🗄️ Archive: Simple query also failed: \(error.localizedDescription)")
            }
        }
        
        return records
    }
    
    private func archiveSelectedEvent() {
        guard !selectedEventID.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        print("DEBUG: Archive - Starting archiveSelectedEvent with ID: \(selectedEventID)")
        
        // Find the event in the local events array
        guard let event = events.first(where: { event in event.id == selectedEventID }) else {
            isLoading = false
            errorMessage = isSpanish ? "Evento no encontrado" : "Event not found"
            print("ERROR: Archive - Event with ID \(selectedEventID) not found in local events array")
            return
        }
        
        // Create a new ArchivedEvent record
        let archivedRecord = CKRecord(recordType: "ArchivedEvent")
        print("DEBUG: Archive - Created new ArchivedEvent record")
        
        // Instead of querying by recordNameMirror, use the recordID from the event we already found
        print("DEBUG: Archive - Using event from memory with ID: \(event.id)")
        
        // Fetch the original record using recordID
        database.fetch(withRecordID: event.recordID) { originalRecord, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    // Enhanced error handling for fetch errors
                    let errorCode = (error as NSError).code
                    let errorDomain = (error as NSError).domain
                    
                    print("ERROR: Archive - Failed to fetch original record: \(error.localizedDescription)")
                    print("ERROR: Archive - Error details - Code: \(errorCode), Domain: \(errorDomain)")
                    
                    self.errorMessage = self.isSpanish ?
                        "Error al recuperar el evento: \(error.localizedDescription)" :
                        "Error retrieving event: \(error.localizedDescription)"
                }
                return
            }
            
            guard let originalRecord = originalRecord else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = self.isSpanish ? "Evento no encontrado" : "Event not found"
                    print("ERROR: Archive - No matching original record found in CloudKit")
                }
                return
            }
            
            print("DEBUG: Archive - Successfully found original record: \(originalRecord.recordID.recordName)")
            
            // Copy data from original event to archived event
            archivedRecord["title"] = originalRecord["title"]
            archivedRecord["startDate"] = originalRecord["startDate"]
            archivedRecord["endDate"] = originalRecord["endDate"]
            archivedRecord["location"] = originalRecord["location"]
            archivedRecord["notes"] = originalRecord["notes"]
            archivedRecord["pdfReference"] = originalRecord["pdfReference"]
            archivedRecord["archivedDate"] = self.archiveDate
            
            // IMPORTANT: Set recordNameMirror for queryability
            archivedRecord["recordNameMirror"] = archivedRecord.recordID.recordName
            print("DEBUG: Archive - Set recordNameMirror on new archive record: \(archivedRecord.recordID.recordName)")
            
            // Save the archived event to CloudKit
            print("DEBUG: Archive - Saving ArchivedEvent record")
            self.database.save(archivedRecord) { savedRecord, saveError in
                if let saveError = saveError {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        
                        // Enhanced error handling for schema or permission issues
                        let errorCode = (saveError as NSError).code
                        let errorDomain = (saveError as NSError).domain
                        let userInfo = (saveError as NSError).userInfo
                        
                        print("ERROR: Archive - Save error: \(saveError.localizedDescription)")
                        print("ERROR: Archive - Error details - Code: \(errorCode), Domain: \(errorDomain)")
                        
                        // Fix optional string interpolation with explicit handling
                        let userInfoDescription = String(describing: userInfo)
                        print("ERROR: Archive - Error userInfo: \(userInfoDescription)")
                        
                        if errorCode == CKError.unknownItem.rawValue {
                            self.errorMessage = self.isSpanish ?
                                "Error: El tipo 'ArchivedEvent' no está marcado como indexable en CloudKit. Verifique el Dashboard de CloudKit." :
                                "Error: 'ArchivedEvent' type is not marked as indexable in CloudKit. Please check CloudKit Dashboard."
                        } else if errorCode == CKError.notAuthenticated.rawValue || errorCode == CKError.permissionFailure.rawValue {
                            self.errorMessage = self.isSpanish ?
                                "Error de permisos: No tiene permisos para guardar en CloudKit." :
                                "Permission error: You don't have permissions to save to CloudKit."
                        } else {
                            self.errorMessage = self.isSpanish ?
                                "Error al archivar el evento: \(saveError.localizedDescription)" :
                                "Error archiving event: \(saveError.localizedDescription)"
                        }
                    }
                    return
                }
                
                print("DEBUG: Archive - Successfully saved ArchivedEvent record")
                // Delete the original event
                print("DEBUG: Archive - Now deleting original event")
                self.database.delete(withRecordID: originalRecord.recordID) { _, deleteError in
                    DispatchQueue.main.async {
                        self.isLoading = false
                        
                        if let deleteError = deleteError {
                            // Enhanced error handling for delete errors
                            let errorCode = (deleteError as NSError).code
                            print("ERROR: Archive - Delete error: \(deleteError.localizedDescription), code: \(errorCode)")
                            
                            if errorCode == CKError.permissionFailure.rawValue {
                                self.alertMessage = self.isSpanish ?
                                    "Evento archivado pero no se pudo eliminar el original por falta de permisos." :
                                    "Event archived but could not delete original due to permission issues."
                            } else {
                                self.alertMessage = self.isSpanish ?
                                    "Evento archivado pero no se pudo eliminar el original: \(deleteError.localizedDescription)" :
                                    "Event archived but could not delete original: \(deleteError.localizedDescription)"
                            }
                        } else {
                            print("DEBUG: Archive - Successfully deleted original event")
                            self.alertMessage = self.isSpanish ?
                                "Evento archivado exitosamente" :
                                "Event successfully archived"
                            
                            // Call the callback
                            self.onEventArchived?()
                        }
                        
                        self.showAlert = true
                        self.showPopupArchive = false
                    }
                }
            }
        }
    }
    
    // Add a function to load PDF and ensure it's ready before showing preview
    private func loadAndShowPDF() {
        print("📑 PDF: loadAndShowPDF called")
        
        // Check if we already have a valid PDF loaded
        if let doc = pdfDocument, doc.pageCount > 0 {
            print("📑 PDF: Valid document already loaded with \(doc.pageCount) pages")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                pdfReadyForDisplay = true
                isShowingPDFPreview = true
            }
            return
        }
        
        // Start fresh loading
        print("📑 PDF: Need to load PDF before showing")
        pdfDocument = nil
        pdfError = nil
        isLoadingPDF = true
        pdfReadyForDisplay = false
        
        // Load PDF with completion handler
        loadPDFWithCompletion {
            // Only show preview if we successfully loaded a valid PDF
            if let doc = pdfDocument, doc.pageCount > 0 {
                print("📑 PDF: Successfully loaded PDF with \(doc.pageCount) pages")
                // Small delay to ensure UI state is updated
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    pdfReadyForDisplay = true
                    isShowingPDFPreview = true
                }
            } else {
                print("📑 PDF ERROR: Failed to load valid PDF")
                DispatchQueue.main.async {
                    pdfError = isSpanish ? 
                        "Error: No se pudo cargar el PDF correctamente" : 
                        "Error: Could not load the PDF properly"
                }
            }
        }
    }
}

struct Archive: View {
    @State private var showPopupArchive = false
    @State private var isSpanish = false
    @State private var refreshCalendar = false
    
    var body: some View {
        VStack {
            Button(action: {
                showPopupArchive = true
            }) {
                Text(isSpanish ? "Archivar Evento" : "Archive Event")
                    .fontWeight(.bold)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
            
            if showPopupArchive {
                PopupView3(
                    showPopupArchive: $showPopupArchive,
                    isSpanish: $isSpanish,
                    onEventArchived: {
                        refreshCalendar = true
                    }
                )
            }
        }
    }
}

#Preview {
    Archive()
}

