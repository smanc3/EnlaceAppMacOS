//
//  EventManagementView.swift
//  Enlace Admin (Preview)
//
//  Created on 4/20/25.
//

import SwiftUI
import CloudKit
import PDFKit
import AppKit
import Darwin // For mach memory APIs
import Foundation

// MARK: - CalendarPDFKitView Implementation
/// A SwiftUI view that wraps `PDFView` from PDFKit to display PDF documents in a macOS app.
struct CalendarPDFKitView: NSViewRepresentable {
    /// The `PDFDocument` to be displayed.
    let pdfDocument: PDFKit.PDFDocument
    
    /// Initializes the view with a `PDFDocument`.
    /// - Parameter pdfDoc: The `PDFDocument` instance to show.
    init(showing pdfDoc: PDFKit.PDFDocument) {
        print("📄 CalendarPDFKitView: Initializing with document, page count: \(pdfDoc.pageCount)")
        self.pdfDocument = pdfDoc
    }
    
    /// Creates and configures the `PDFView` instance.
    /// - Parameter context: The context in which the view is created.
    /// - Returns: A configured `PDFView` instance.
    func makeNSView(context: Context) -> PDFView {
        print("📄 CalendarPDFKitView: Creating PDFView")
        let pdfView = PDFView()
        
        // Enable layer-backed view for better performance
        pdfView.wantsLayer = true
        
        // Configure PDFView properties
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        pdfView.autoScales = true // Let PDFKit handle scaling
        pdfView.backgroundColor = .white // Clean white background
        pdfView.displayBox = .cropBox // Best for viewing
        
        // Enable PDF controls with professional appearance
        pdfView.displaysPageBreaks = true
        pdfView.displaysAsBook = false
        pdfView.enableDataDetectors = true
        
        // Add a subtle border
        if let layer = pdfView.layer {
            layer.borderWidth = 1.0
            layer.borderColor = NSColor.lightGray.withAlphaComponent(0.3).cgColor
            layer.cornerRadius = 4.0
            layer.shadowOpacity = 0.2
            layer.shadowRadius = 3.0
            layer.shadowOffset = CGSize(width: 0, height: 1)
        }
        
        // Apply document and configure page
        pdfView.document = pdfDocument
        
        // Set initial scale and position
        if let firstPage = pdfDocument.page(at: 0) {
            pdfView.go(to: firstPage)
            // Use a higher zoom factor (1.5x the size-to-fit) for better readability
            pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit * 1.5
        }
        
        return pdfView
    }
    
    /// Updates the `PDFView` when the SwiftUI view's state changes.
    /// - Parameters:
    ///   - pdfView: The `PDFView` instance to update.
    ///   - context: The context containing information about the update.
    func updateNSView(_ pdfView: PDFView, context: Context) {
        pdfView.document = pdfDocument
        if let firstPage = pdfDocument.page(at: 0) {
            pdfView.go(to: firstPage)
            // Maintain consistent zoom factor on update
            pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit * 1.5
        }
    }
    
    // Define types explicitly to avoid ambiguity
    typealias NSViewType = PDFView
    typealias Context = NSViewRepresentableContext<CalendarPDFKitView>
}

// MARK: - FreezeDetection Stub (re-added to satisfy references)
/// A simplified placeholder for the original FreezeDetection system so the project can compile.
/// Replace with the full implementation as needed.

struct EventManagementView: View {
    @Binding var isSpanish: Bool
    @Binding var refreshTrigger: Bool
    @StateObject private var languageManager = LanguageManager()
    
    // State variables
    @State private var events: [CalendarEvent] = []
    @State private var archivedEvents: [CalendarEvent] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    @State private var selectedEvent: CalendarEvent? = nil
    @State private var searchText: String = ""
    @State private var sortOrder: SortOrder = .newestFirst
    @State private var showFullPDFView: Bool = false
    @State private var currentPDFDocument: PDFKit.PDFDocument? = nil
    
    // CRITICAL: New approach to bypass event selection
    @State private var selectedEventId: String? = nil
    @State private var selectedEventTitle: String? = nil
    
    // Freeze detection properties
    @State private var activeDetectionArea: FreezeDetection.Area? = nil
    @State private var activeDetectionContext: [String: Any]? = nil
    @State private var freezeDetectionTimer: Timer? = nil
    @State private var freezeDetectionStartTime: Date? = nil
    @State private var pdfError: Error? = nil

    // Event action tracking enum
    enum EventAction {
        case select, deselect, load, cloudKitFetch, viewPDF, pdfLoad
        case memoryCheck, memoryPressure, debugInfo, warning, critical, freeze
    }
    
    // Alert system
    enum AlertType: Identifiable {
        case deleteConfirmation
        case archiveConfirmation
        case unarchiveConfirmation
        case createSuccess(title: String)
        case updateSuccess(title: String)
        case archiveSuccess(title: String)
        case unarchiveSuccess(title: String)
        case error(message: String)
        
        var id: Int {
            switch self {
            case .deleteConfirmation: return 0
            case .archiveConfirmation: return 1
            case .unarchiveConfirmation: return 2
            case .createSuccess: return 3
            case .updateSuccess: return 4
            case .error: return 5
            case .archiveSuccess: return 6
            case .unarchiveSuccess: return 7
            }
        }
    }
    
    @State private var activeAlert: AlertType? = nil
    
    // Editing state
    @State private var isEditing: Bool = false
    @State private var editTitle: String = ""
    @State private var editLocation: String = ""
    @State private var editStartDate: Date = Date()
    @State private var editEndDate: Date = Date().addingTimeInterval(3600)
    @State private var editNotes: String = ""
    @State private var editLinkURL: String = ""
    @State private var selectedPDFRecord: CKRecord?
    @State private var selectedPDFURL: URL?
    @State private var selectedFileLabel: String = ""
    @State private var showPDFPicker: Bool = false
    
    // State for PDF management
    @State private var pdfThumbnailCache: [String: NSImage] = [:] // Cache for PDF thumbnails
    @State private var pdfDocument: PDFDocument? = nil
    
    // CloudKit
    private let container = CKContainer(identifier: "iCloud.PearInc.EICT-iOS-16")
    private var database: CKDatabase {
        return container.publicCloudDatabase
    }
    
    enum SortOrder: String, CaseIterable, Identifiable {
        case newestFirst, oldestFirst, titleAZ, titleZA
        
        var id: String { self.rawValue }
        
        var displayName: String {
            switch self {
            case .newestFirst: return "Latest Events First"
            case .oldestFirst: return "Earliest Events First"
            case .titleAZ: return "Title A-Z"
            case .titleZA: return "Title Z-A"
            }
        }
        
        var spanishDisplayName: String {
            switch self {
            case .newestFirst: return "Eventos Próximos Primero"
            case .oldestFirst: return "Eventos Antiguos Primero"
            case .titleAZ: return "Título A-Z"
            case .titleZA: return "Título Z-A"
            }
        }
    }
    
    // Filtered events based on search and filter settings
    private var filteredEvents: [CalendarEvent] {
        guard !searchText.isEmpty else { return events }
        return events.filter { 
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            ($0.location ?? "").localizedCaseInsensitiveContains(searchText) ||
            ($0.notes ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // Add a static property to store the timer
    private static var memoryMonitorTimer: Timer?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Search and filters section
            searchAndFilterView
            
            // Main content area - delegate to helper properties
            contentView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            loadEvents()
            loadArchivedEvents()
            setupFreezeDetection()
            
            // Add observer for PDF view requests from EventRowActions
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ViewPDFRequested"),
                object: nil,
                queue: .main
            ) { notification in
                if let userInfo = notification.userInfo,
                   let reference = userInfo["reference"] as? CKRecord.Reference,
                   let eventId = userInfo["eventId"] as? String {
                    self.viewPDF(for: reference, eventId: eventId)
                }
            }
        }
        .onDisappear {
            // Cleanup observers to prevent memory leaks
            NotificationCenter.default.removeObserver(self)
            
            // Important: Invalidate the timer to prevent memory leaks
            // And prevent background processing
            Self.memoryMonitorTimer?.invalidate()
            Self.memoryMonitorTimer = nil
            print("📊 CLEANUP: Memory monitor timer invalidated and nullified")
            
            // Clear any references
            selectedEvent = nil
            selectedEventId = nil
            selectedEventTitle = nil
            currentPDFDocument = nil
            
            // Clear caches on disappear
            pdfThumbnailCache.removeAll()
            
            // Force a cleanup cycle
            autoreleasepool {
                // Additional cleanup in autorelease pool
                if #available(macOS 13.0, *) {
                    URLCache.shared.removeAllCachedResponses()
                }
                
                // Force immediate memory release on macOS
                // Use simpler approach that doesn't require unsafe pointers
                #if os(macOS)
                // Request memory warning
                let sharedApplication = NSApplication.shared
                NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: sharedApplication)
                NotificationCenter.default.post(name: NSApplication.willBecomeActiveNotification, object: sharedApplication)
                #endif
            }
            
            print("ℹ️ [EventManagementView.swift:\(#line)] body - EventManagementView disappeared - cleaned up observers")
        }
        .alert(item: $activeAlert) { alertType in
            createAlertView(for: alertType)
        }
        .sheet(isPresented: $showPDFPicker) {
            PDFSelectorView(
                selectedPDFRecord: $selectedPDFRecord,
                selectedPDFURL: $selectedPDFURL,
                selectedFileLabel: $selectedFileLabel,
                isSpanish: $isSpanish
            )
            .frame(width: 600, height: 500)
            .onChange(of: selectedPDFRecord) { newValue in
                if newValue != nil {
                    // Auto-dismiss when a PDF is selected
                    showPDFPicker = false
                }
            }
            .onChange(of: selectedPDFURL) { url in
                print("🟢 [DEBUG] .onChange selectedPDFURL triggered: \(String(describing: url))")
                guard let url = url else {
                    self.pdfDocument = nil
                    return
                }
                
                print("📄 [DEBUG] Loading PDFDocument from selected URL: \(url.path)")
                
                // First check if file exists
                if !FileManager.default.fileExists(atPath: url.path) {
                    print("⚠️ [DEBUG] WARNING: PDF file does not exist at path: \(url.path)")
                    return
                }
                
                // First try immediate loading
                if let document = PDFDocument(url: url) {
                    print("✅ [DEBUG] PDF loaded immediately with \(document.pageCount) pages")
                    setupPDFDocument(document)
                    return
                }
                
                // If immediate loading fails, try background loading
                print("📄 [DEBUG] Immediate PDF loading failed, trying background loading...")
                DispatchQueue.global(qos: .userInitiated).async {
                    guard let document = PDFDocument(url: url) else {
                        DispatchQueue.main.async {
                            print("❌ [DEBUG] Failed to load PDF document at URL: \(url)")
                            self.pdfDocument = nil
                        }
                        return
                    }
                    
                    DispatchQueue.main.async {
                        self.setupPDFDocument(document)
                    }
                }
            }
        }
        .sheet(isPresented: $showFullPDFView) {
            pdfViewSheet
        }
        // Load PDF when an existing CloudKit record is selected
        .onChange(of: selectedPDFRecord) { newRecord in
            print("🟢 [DEBUG] .onChange selectedPDFRecord triggered: \(String(describing: newRecord))")
            guard let record = newRecord else {
                self.pdfDocument = nil
                return
            }
            
            print("📄 [DEBUG] Loading PDFDocument from selected record: \(record.recordID.recordName)")
            
            if let asset = record["pdfFile"] as? CKAsset, let url = asset.fileURL {
                // Check if file exists
                if !FileManager.default.fileExists(atPath: url.path) {
                    print("⚠️ [DEBUG] WARNING: PDF asset file does not exist at path: \(url.path)")
                    return
                }
                
                // Try immediate loading
                if let document = PDFDocument(url: url) {
                    print("✅ [DEBUG] PDF loaded from record immediately with \(document.pageCount) pages")
                    setupPDFDocument(document)
                    return
                }
                
                // If immediate loading fails, try background loading
                print("📄 [DEBUG] Immediate PDF loading failed, trying background loading...")
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        // Try data-based loading
                        let data = try Data(contentsOf: url)
                        guard let document = PDFDocument(data: data) else {
                            DispatchQueue.main.async {
                                print("❌ [DEBUG] Failed to load PDF document from data")
                                self.pdfDocument = nil
                            }
                            return
                        }
                        
                        DispatchQueue.main.async {
                            self.setupPDFDocument(document)
                        }
                    } catch {
                        DispatchQueue.main.async {
                            print("❌ [DEBUG] Error reading asset data: \(error.localizedDescription)")
                            self.pdfDocument = nil
                        }
                    }
                }
            } else {
                print("⚠️ [DEBUG] No pdfFile asset found in record")
                self.pdfDocument = nil
            }
        }
    }
    
    // Header view extracted
    private var headerView: some View {
        HStack {
            Text(isSpanish ? "Administrar Eventos" : "Manage Events")
                .font(.title)
                .fontWeight(.bold)
            
            Spacer()
            
            // Refresh button
            Button(action: {
                print("🔄 [EventManagement] Refresh button pressed")
                DebugLogger.trackCalendarRefresh(action: "Refresh Button Pressed", context: "EventManagement", refreshTrigger: refreshTrigger)
                loadEvents()
                loadArchivedEvents()
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
    }
    
    // Extract some of the body content into separate methods to reduce complexity
    private var contentView: some View {
        if isLoading {
            return AnyView(loadingView(message: isSpanish ? "Cargando eventos..." : "Loading events..."))
        } else if errorMessage != nil {
            return AnyView(errorView(error: errorMessage!, retryAction: loadEvents))
        } else if events.isEmpty {
            return AnyView(emptyStateView(
                icon: "calendar", 
                message: isSpanish ? "No hay eventos para mostrar" : "No events to display"
            ))
        } else {
            return AnyView(eventsContentView)
        }
    }
    
    private var eventsContentView: some View {
        // SIMPLIFIED APPROACH - only use selectedEventId/Title, not selectedEvent
        HStack(spacing: 0) {
            // Left panel: list of events - SIMPLIFIED
            VStack {
                List {
                    ForEach(filteredEvents, id: \.id) { event in
                        EventRow(event: event, isSpanish: isSpanish, editEvent: editEvent, archiveEvent: promptArchiveEvent, deleteEvent: deleteEvent, isSelected: selectedEvent?.id == event.id, selectEvent: handleEventSelection)
                    }
                }
                .listStyle(.inset)
                .background(Color.white)
                // Removed Create New Event button
            }
            .frame(minWidth: 300, maxWidth: 300)
            .background(Color.white)
            
            Divider()
            
            // Right panel
            rightPanelView
        }
    }
    
    private func editEvent(_ event: CalendarEvent) {
        print("🔄 DEBUG: Starting editEvent for event ID: \(event.id)")
        selectedEventId = event.id
        selectedEventTitle = event.title
        selectedEvent = CalendarEvent(
            id: event.id,
            title: event.title,
            startDate: event.startDate,
            endDate: event.endDate,
            recordID: event.recordID
        )
        isEditing = true
        editTitle = event.title
        editLocation = event.location ?? ""
        editStartDate = event.startDate
        editEndDate = event.endDate
        editNotes = event.notes ?? ""
        editLinkURL = event.linkURL?.absoluteString ?? ""
        if event.pdfReference != nil {
            selectedPDFRecord = nil
            selectedFileLabel = isSpanish ? "PDF Disponible" : "PDF Available"
            // Don't actually load the PDF yet to avoid performance issues
        } else {
            selectedPDFRecord = nil
            selectedPDFURL = nil
            selectedFileLabel = ""
        }
        print("🔄 DEBUG: Completed editEvent setup")
    }
    
    private func createNewEvent() {
        selectedEvent = nil
        selectedEventId = nil
        selectedEventTitle = nil
        isEditing = true
        clearEditState()
        print("🆕 DEBUG: Created new event form")
    }
    
    private func clearEditState() {
        editTitle = ""
        editLocation = ""
        editStartDate = Date()
        editEndDate = Date().addingTimeInterval(3600)
        editNotes = ""
        editLinkURL = ""
        selectedPDFRecord = nil
        selectedPDFURL = nil
        selectedFileLabel = ""
    }
    
    // Consolidated asynchronous PDF loading
    private func loadPDFRecordAsync(_ reference: CKRecord.Reference) async {
        print("📄 DEBUG: Starting async PDF loading for reference ID: \(reference.recordID.recordName)")
        logEventAction(
            action: .pdfLoad, 
            details: [
                "state": "started",
                "referenceID": reference.recordID.recordName
            ]
        )
        
        // Set default state immediately to prevent UI freeze
        await MainActor.run {
            selectedPDFRecord = nil
            selectedFileLabel = isSpanish ? "Cargando PDF..." : "Loading PDF..."
        }
        
        do {
            // Fetch the record asynchronously using CKFetchRecordsOperation with high QoS
            let startTime = Date()
            let record: CKRecord = try await withCheckedThrowingContinuation { continuation in
                let op = CKFetchRecordsOperation(recordIDs: [reference.recordID])
                op.qualityOfService = .userInteractive // elevate QoS to match UI expectations
                op.perRecordResultBlock = { recordID, result in
                    switch result {
                    case .success(let fetchedRecord):
                        continuation.resume(returning: fetchedRecord)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                // In case CloudKit returns overall failure without per-record callback
                op.fetchRecordsResultBlock = { result in
                    if case .failure(let error) = result {
                        continuation.resume(throwing: error)
                    }
                }
                database.add(op)
            }
            let loadTime = Date().timeIntervalSince(startTime)
            
            // Log all record keys for debugging
            print("�� PDF KEYS: \(record.allKeys().joined(separator: ", "))")
            
            // Check both possible PDF asset fields
            let pdfAsset = (record["pdfFile"] as? CKAsset) ?? (record["pdfAsset"] as? CKAsset)
            if let pdfAsset = pdfAsset {
                print("✅ PDF ASSET FOUND: \(pdfAsset)")
                if let fileURL = pdfAsset.fileURL {
                    print("📄 PDF FILE URL: \(fileURL.path)")
                    
                    // Check if file exists and get size
                    if FileManager.default.fileExists(atPath: fileURL.path) {
                        let fileSize = try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64 ?? 0
                        print("📄 PDF FILE SIZE: \(fileSize ?? 0) bytes")
                    } else {
                        print("❌ PDF FILE DOES NOT EXIST at path: \(fileURL.path)")
                    }
                } else {
                    print("❌ PDF ASSET HAS NO FILE URL")
                }
            } else {
                print("❌ NO PDF ASSET FOUND in fields 'pdfFile' or 'pdfAsset'")
            }
            
            // Log detailed performance information
            logEventAction(
                action: .pdfLoad,
                details: [
                    "state": "completed",
                    "referenceID": reference.recordID.recordName,
                    "loadTime": loadTime,
                    "recordSize": record.description.count
                ],
                executionTime: loadTime
            )
            
            // Update UI on main thread
            await MainActor.run {
                print("📄 DEBUG: Successfully loaded PDF record")
                self.selectedPDFRecord = record
                self.selectedFileLabel = record["title"] as? String ?? "Selected PDF"
            }
        } catch {
            print("📄 DEBUG: Error fetching PDF record: \(error.localizedDescription)")
            logEventAction(
                action: .pdfLoad,
                details: [
                    "state": "error",
                    "referenceID": reference.recordID.recordName,
                    "error": error.localizedDescription
                ]
            )
            
            await MainActor.run {
                self.selectedFileLabel = self.isSpanish ? "Error: \(error.localizedDescription)" : "Error: \(error.localizedDescription)"
            }
        }
    }
    
    private func saveChanges() {
        if selectedEvent != nil {
            // Update existing event
            updateEvent()
        } else {
            // Create new event
            createEvent()
        }
        // Reset edit mode
        isEditing = false
    }
    
    private func updateEvent() {
        guard let selectedEvent = selectedEvent else {
            errorMessage = "No event selected for update"
            activeAlert = .error(message: "No event selected")
            return
        }
        
        let recordID = selectedEvent.recordID
        
        // Create a custom operation with proper QoS instead of using direct fetch
        let fetchOperation = CKFetchRecordsOperation(recordIDs: [recordID])
        fetchOperation.qualityOfService = .userInteractive // Match UI thread priority
        
        fetchOperation.perRecordResultBlock = { (recordID, result) in
            switch result {
            case .success(let record):
                // Update record fields on the main thread to prevent threading issues
            DispatchQueue.main.async {
                    // Update record fields
            record["title"] = self.editTitle
                    record["location"] = self.editLocation.isEmpty ? nil : self.editLocation
            record["startDate"] = self.editStartDate
            record["endDate"] = self.editEndDate
                    record["notes"] = self.editNotes.isEmpty ? nil : self.editNotes
                    record["linkURL"] = self.editLinkURL.isEmpty ? nil : self.editLinkURL
                    
            if let pdfRecord = self.selectedPDFRecord {
                record["pdfReference"] = CKRecord.Reference(record: pdfRecord, action: .deleteSelf)
                    }
                    
                    // Save the updated record
                    let saveOperation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
                    saveOperation.qualityOfService = .userInteractive
                    saveOperation.modifyRecordsResultBlock = { result in
                DispatchQueue.main.async {
                            switch result {
                            case .success:
                                let updatedEvent = CalendarEvent(record: record)
                                if let index = self.events.firstIndex(where: { $0.id == updatedEvent.id }) {
                                    self.events[index] = updatedEvent
                                }
                                
                                self.resetEditFields()
                                self.isEditing = false
                                self.selectedEvent = nil
                                self.selectedEventId = nil
                                self.selectedEventTitle = nil
                        self.activeAlert = .updateSuccess(title: self.editTitle)
                                
                                // Trigger refresh and log
                                DebugLogger.trackRefreshTrigger(source: "EventManagement-updateEvent", oldValue: self.refreshTrigger, newValue: !self.refreshTrigger)
                                self.refreshTrigger.toggle()
                                
                            case .failure(let error):
                                self.errorMessage = "Failed to update event: \(error.localizedDescription)"
                                self.activeAlert = .error(message: "Update failed: \(error.localizedDescription)")
                            }
                        }
                    }
                    
                    self.database.add(saveOperation)
                }
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to fetch event for update: \(error.localizedDescription)"
                    self.activeAlert = .error(message: "Update failed: \(error.localizedDescription)")
                }
            }
        }
        
        // Add the fetch operation to the database
        database.add(fetchOperation)
    }

    private func createEvent() {
        let record = CKRecord(recordType: "CalendarEvent")
        record["title"] = editTitle
        record["location"] = editLocation.isEmpty ? nil : editLocation
        record["startDate"] = editStartDate
        record["endDate"] = editEndDate
        record["notes"] = editNotes.isEmpty ? nil : editNotes
        record["linkURL"] = editLinkURL.isEmpty ? nil : editLinkURL
                    record["isArchived"] = 0
        
        if let pdfRecord = selectedPDFRecord {
            record["pdfReference"] = CKRecord.Reference(record: pdfRecord, action: .deleteSelf)
        }
        
        let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        operation.qualityOfService = .userInteractive // Set high QoS to prevent thread priority inversion
        operation.modifyRecordsResultBlock = { result in
                        DispatchQueue.main.async {
                switch result {
                case .success:
                    let newEvent = CalendarEvent(record: record)
                    self.events.append(newEvent)
                    self.events.sort { $0.startDate > $1.startDate }
                    
                    self.resetEditFields()
                    self.isEditing = false
                    self.activeAlert = .createSuccess(title: self.editTitle)
                    
                    // Trigger refresh and log
                    DebugLogger.trackRefreshTrigger(source: "EventManagement-createEvent", oldValue: self.refreshTrigger, newValue: !self.refreshTrigger)
                    self.refreshTrigger.toggle()
                    
                case .failure(let error):
                    self.errorMessage = "Failed to create event: \(error.localizedDescription)"
                    self.activeAlert = .error(message: "Create failed: \(error.localizedDescription)")
                }
            }
        }
        
        database.add(operation)
    }
    
    // Add the resetEditFields method
    private func resetEditFields() {
        if let event = selectedEvent {
            // If an event is selected, populate fields with its values
            editTitle = event.title
            editLocation = event.location ?? ""
            editStartDate = event.startDate
            editEndDate = event.endDate
            editNotes = event.notes ?? ""
            editLinkURL = event.linkURL?.absoluteString ?? ""
            
            // Handle PDF reference
            if event.pdfReference != nil {
                selectedPDFRecord = nil
                selectedFileLabel = isSpanish ? "PDF Disponible" : "PDF Available"
                
                // Don't actually load the PDF yet to avoid performance issues
                print("🔄 PDF: Reference exists but not loading yet")
            } else {
                selectedPDFRecord = nil
                selectedPDFURL = nil
                selectedFileLabel = ""
            }
        } else {
            // If no event is selected, reset to defaults
            clearEditState()
        }
        
        print("🔄 DEBUG: Reset edit fields completed")
    }
    
    // MARK: - Logging and Performance Tracking

    // Track event operations with context
    private func trackEventOperation<T>(
        action: EventAction,
        id: String,
        title: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        operation: () -> T
    ) -> T {
        // Log before operation
        print("📝 EVENT ACTION: Starting \(action) for event ID: \(id), Title: \(title)")
        
        // Get memory before operation
        let memoryBefore = getMemoryUsageMB()
        let startTime = Date()
        
        // Execute the operation
        let result = operation()
        
        // Calculate metrics
        let duration = Date().timeIntervalSince(startTime)
        let memoryAfter = getMemoryUsageMB()
        let memoryDelta = Int64(memoryAfter) - Int64(memoryBefore)
        
        // Log after operation with metrics
        print("📝 EVENT ACTION: Completed \(action) in \(String(format: "%.4f", duration))s, Memory delta: \(memoryDelta)MB")
        
        // Log to central event action system
        logEventAction(
            action: action,
            id: id,
            title: title,
            details: [
                "duration": duration,
                "memoryBefore": memoryBefore,
                "memoryAfter": memoryAfter,
                "memoryDelta": memoryDelta,
                "file": URL(fileURLWithPath: file).lastPathComponent,
                "function": function,
                "line": line
            ],
            executionTime: duration
        )
        
        return result
    }
    
    // Log event actions to the console with detailed info
    private func logEventAction(
        action: EventAction,
        id: String? = nil,
        title: String? = nil,
        details: [String: Any] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        executionTime: TimeInterval? = nil
    ) {
        // Create timestamp
        let timestamp = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        let timestampString = formatter.string(from: timestamp)
        
        // Build log message
        var logMessage = "[\(timestampString)][\(action)]"
        
        if let id = id {
            logMessage += "[ID: \(id)]"
        }
        
        if let title = title {
            logMessage += "[Title: \(title)]"
        }
        
        if let executionTime = executionTime {
            logMessage += "[Time: \(String(format: "%.4f", executionTime))s]"
        }
        
        // Add file info
        let fileComponent = URL(fileURLWithPath: file).lastPathComponent
        logMessage += " \(fileComponent):\(line)"
        
        // Add details
        if !details.isEmpty {
            let detailsString = details.map { key, value in "\(key): \(value)" }.joined(separator: ", ")
            logMessage += " - \(detailsString)"
        }
        
        // Print log message
        print("📊 \(logMessage)")
    }
    
    // Log info messages
    private func logInfo(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        print("ℹ️ [\(URL(fileURLWithPath: file).lastPathComponent):\(line)] \(function) - \(message)")
    }
    
    // Log warning messages
    private func logWarning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        print("⚠️ [\(URL(fileURLWithPath: file).lastPathComponent):\(line)] \(function) - \(message)")
    }
    
    // Log link saved - helps track link-related actions for debugging
    private func logLinkSaved(url: String, modelType: String, modelId: String, file: String = #file, function: String = #function, line: Int = #line) {
        print("🔗 LINK SAVED: \(url) in \(modelType) ID: \(modelId) at [\(URL(fileURLWithPath: file).lastPathComponent):\(line)]")
    }
    
    // Event load tracking
    private func beginEventLoad() {
        print("📚 EVENT LOAD: Starting event loading process")
        logInfo("Beginning event load", file: #file, function: #function, line: #line)
    }
    
    private func endEventLoad(count: Int, success: Bool, error: Error? = nil) {
        if success {
            print("📚 EVENT LOAD: Successfully loaded \(count) events")
        } else if let error = error {
            print("📚 EVENT LOAD: Failed to load events - \(error.localizedDescription)")
        }
        
        logInfo("Event load completed: count=\(count), success=\(success)", file: #file, function: #function, line: #line)
    }
    
    // MARK: - Helper Methods for Network and Diagnostics
    
    // Helper to get file size in bytes
    private func getFileSize(_ url: URL) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let size = attributes[.size] as? Int64 {
                return size
            }
        } catch {
            print("Error getting file size: \(error.localizedDescription)")
        }
        return 0
    }
    
    // Helper method to get formatted file size string
    private func getFileSizeString(_ url: URL) -> String {
        let bytes = getFileSize(url)
        
        if bytes < 1024 {
            return "\(bytes) bytes"
        } else if bytes < 1024 * 1024 {
            let kb = Double(bytes) / 1024.0
            return "\(String(format: "%.2f", kb)) KB"
        } else {
            let mb = Double(bytes) / (1024.0 * 1024.0)
            return "\(String(format: "%.2f", mb)) MB"
        }
    }
    
    // Helper to classify CloudKit errors for better diagnostics
    private func classifyCloudKitError(_ error: Error) -> String {
        let nsError = error as NSError
        
        if nsError.domain == CKErrorDomain {
            let ckError = CKError(_nsError: nsError)
            
            switch ckError.code {
            case .networkFailure, .networkUnavailable, .serviceUnavailable:
                return "NetworkIssue"
            case .notAuthenticated, .permissionFailure:
                return "AuthenticationIssue"
            case .limitExceeded, .requestRateLimited:
                return "RateLimitIssue"
            case .assetFileNotFound, .incompatibleVersion, .badContainer, .invalidArguments:
                return "DataIssue"
            case .serverResponseLost, .serverRejectedRequest, .internalError:
                return "ServerIssue"
            default:
                return "OtherCloudKitIssue"
            }
        } else if nsError.domain == NSURLErrorDomain {
            return "NetworkConnectivityIssue"
        }
        
        return "UnknownIssue"
    }
    
    // Helper to detect network quality
    private func detectNetworkQuality() -> String {
        // This is a simplified version - in a real app, you'd use NWPathMonitor
        // or other network diagnosis tools to get actual network quality
        
        // For demo purposes, we're returning a fixed value to avoid network requests
        return "Unknown (Not measured)"
    }
    
    // MARK: - Optimized Data Processing Methods
    
    // New optimized method to map records to events in chunks
    private func mapRecordsToEventsOptimized(_ records: [CKRecord]) {
        // Start a new freeze detection for the mapping operation - shorter timeout
        FreezeDetection.startDetection(
            area: .dataProcessing,
            timeoutSeconds: 2.0,
            context: [
                "operation": "mapRecordsToEvents",
                "recordCount": records.count,
                "optimizedMapping": true
            ]
        )
        
        // Use Task to move the heavy processing to a background thread
        Task {
            // Define chunk size - smaller chunks process faster
            let chunkSize = max(1, min(5, records.count))
            print("📊 OPTIMIZED MAPPING: Processing \(records.count) records in chunks of \(chunkSize)")
            
            // Process records in chunks to avoid UI blocking
            var mappedEvents: [CalendarEvent] = []
            
            // Create chunks of records
            let chunks = stride(from: 0, to: records.count, by: chunkSize).map {
                Array(records[$0..<min($0 + chunkSize, records.count)])
            }
            
            // Process each chunk with a slight delay to allow UI updates
            for (index, chunk) in chunks.enumerated() {
                // Map the chunk of records to events
                let chunkStart = Date()
                let chunkEvents = chunk.map { CalendarEvent(record: $0) }
                mappedEvents.append(contentsOf: chunkEvents)
                
                print("📊 MAPPING CHUNK: Processed chunk \(index+1)/\(chunks.count) with \(chunk.count) records in \(Date().timeIntervalSince(chunkStart) * 1000)ms")
                
                // If more chunks remain, add a tiny delay to allow UI to remain responsive
                if index < chunks.count - 1 {
                    try? await Task.sleep(nanoseconds: 1_000_000) // 1ms delay
                }
            }
            
            // Update UI on main thread
            await MainActor.run {
                // Set events and finish loading
                self.events = mappedEvents
                self.sortEvents()
                
                // End loading state
                self.isLoading = false
                
                logEventAction(
                    action: .load,
                    details: [
                        "operation": "mapping_optimized_complete",
                        "count": mappedEvents.count,
                        "chunkedProcessing": true,
                        "chunkSize": chunkSize,
                        "chunks": chunks.count
                    ]
                )
                
                print("📚 EVENT LOAD: Successfully loaded \(mappedEvents.count) events")
                endEventLoad(count: self.events.count, success: true)
                
                // Stop the freeze detection
                FreezeDetection.stopDetection(additionalContext: [
                    "eventCount": self.events.count,
                    "success": true,
                    "optimizedComplete": true
                ])
            }
        }
    }

    // MARK: - MISSING VIEWS AND FUNCTIONS RESTORED
    
    // Search and filter view
    private var searchAndFilterView: some View {
        HStack {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
            TextField(isSpanish ? "Buscar eventos..." : "Search events...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                .onChange(of: searchText) { newValue in
                    print("🔍 DEBUG: Search text changed to: \(newValue)")
                }
            }
            .padding(.trailing)
            
            // Sort picker
            Picker(isSpanish ? "Ordenar por" : "Sort by", selection: $sortOrder) {
                ForEach(SortOrder.allCases) { order in
                    Text(isSpanish ? order.spanishDisplayName : order.displayName).tag(order)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 150)
            .onChange(of: sortOrder) { newValue in
                print("🔃 DEBUG: Sort order changed to: \(newValue)"); sortEvents()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.textBackgroundColor))
    }

    // Load events from CloudKit
    private func loadEvents() {
        isLoading = true
        errorMessage = nil
        
        // For debugging, track the start time
        let startTime = Date()
        DebugLogger.trackCalendarRefresh(action: "loadEvents Started", context: "EventManagement", refreshTrigger: refreshTrigger)

        let predicate = NSPredicate(format: "isArchived != 1")
        let query = CKQuery(recordType: "CalendarEvent", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        
        let operation = CKQueryOperation(query: query)
        operation.resultsLimit = 100
        operation.qualityOfService = .userInteractive // Set high QoS to prevent thread priority inversion
        
        var fetchedEvents: [CalendarEvent] = []
        
        operation.recordMatchedBlock = { (recordID, result) in
                switch result {
            case .success(let record):
                let event = CalendarEvent(record: record)
                fetchedEvents.append(event)
            case .failure(let error):
                DispatchQueue.main.async {
                    print("Error fetching record \(recordID): \(error.localizedDescription)")
                    }
            }
        }
        
        operation.queryResultBlock = { result in
            DispatchQueue.main.async {
                switch result {
                case .success(_):
                    self.events = fetchedEvents
                    self.isLoading = false
                    DebugLogger.trackEventLoad(module: "EventManagement", eventCount: self.events.count, startTime: startTime)
                    DebugLogger.trackCalendarRefresh(action: "loadEvents Completed Successfully", context: "EventManagement", refreshTrigger: self.refreshTrigger)
                case .failure(let error):
                    self.errorMessage = "Failed to load events: \(error.localizedDescription)"
                    self.isLoading = false
                    DebugLogger.trackEventLoad(module: "EventManagement", eventCount: nil, startTime: startTime, error: error)
                    DebugLogger.trackCalendarRefresh(action: "loadEvents Failed", context: "EventManagement", refreshTrigger: self.refreshTrigger)
                }
            }
        }
        
        database.add(operation)
    }

    // Load archived events from CloudKit
    private func loadArchivedEvents() {
        // For debugging, track the start time
        let startTime = Date()
        DebugLogger.trackCalendarRefresh(action: "loadArchivedEvents Started", context: "EventManagement", refreshTrigger: refreshTrigger)
        
        let predicate = NSPredicate(format: "isArchived == 1")
        let query = CKQuery(recordType: "CalendarEvent", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        
        let operation = CKQueryOperation(query: query)
        operation.resultsLimit = 100
        operation.qualityOfService = .userInteractive // Set high QoS to prevent thread priority inversion
        
        var fetchedArchivedEvents: [CalendarEvent] = []
        
        operation.recordMatchedBlock = { (recordID, result) in
                switch result {
            case .success(let record):
                let event = CalendarEvent(record: record)
                fetchedArchivedEvents.append(event)
            case .failure(let error):
                DispatchQueue.main.async {
                    print("Error fetching archived record \(recordID): \(error.localizedDescription)")
                }
            }
        }
        
        operation.queryResultBlock = { result in
            DispatchQueue.main.async {
                switch result {
                case .success(_):
                    self.archivedEvents = fetchedArchivedEvents
                    DebugLogger.trackEventLoad(module: "EventManagement-Archived", eventCount: self.archivedEvents.count, startTime: startTime)
                    DebugLogger.trackCalendarRefresh(action: "loadArchivedEvents Completed Successfully", context: "EventManagement", refreshTrigger: self.refreshTrigger)
                case .failure(let error):
                    print("Failed to load archived events: \(error.localizedDescription)")
                    DebugLogger.trackEventLoad(module: "EventManagement-Archived", eventCount: nil, startTime: startTime, error: error)
                    DebugLogger.trackCalendarRefresh(action: "loadArchivedEvents Failed", context: "EventManagement", refreshTrigger: self.refreshTrigger)
                }
            }
        }
        
        database.add(operation)
    }

    // Create alert view for .alert modifier
    private func createAlertView(for alertType: AlertType) -> Alert {
        print("⚠️ DEBUG: Creating alert for type: \(alertType)")
        switch alertType {
        case .deleteConfirmation:
            let title = selectedEventTitle ?? ""
            return Alert(
                title: Text(isSpanish ? "Eliminar Evento" : "Delete Event"),
                message: Text(isSpanish ? "Esta acción no se puede deshacer. ¿Deseas eliminar \"\(title)\"?" : "This action cannot be undone. Do you want to delete \"\(title)\"?"),
                primaryButton: .destructive(Text(isSpanish ? "Eliminar" : "Delete")) { confirmDeleteEvent() },
                secondaryButton: .cancel()
            )
        case .archiveConfirmation:
            let title = selectedEventTitle ?? ""
            return Alert(
                title: Text(isSpanish ? "Archivar Evento" : "Archive Event"),
                message: Text(isSpanish ? "El evento se moverá al archivo. Podrás restaurarlo más tarde. ¿Deseas archivar \"\(title)\"?" : "The event will be moved to the archive. You can restore it later. Do you want to archive \"\(title)\"?"),
                primaryButton: .default(Text(isSpanish ? "Archivar" : "Archive")) { confirmArchiveEvent() },
                secondaryButton: .cancel()
            )
        case .unarchiveConfirmation:
            let title = selectedEventTitle ?? ""
            return Alert(
                title: Text(isSpanish ? "Restaurar Evento" : "Restore Event"),
                message: Text(isSpanish ? "El evento volverá a la lista principal. ¿Deseas restaurar \"\(title)\"?" : "The event will return to the main list. Do you want to restore \"\(title)\"?"),
                primaryButton: .default(Text(isSpanish ? "Restaurar" : "Restore")) { confirmUnarchiveEvent() },
                secondaryButton: .cancel()
            )
        case .createSuccess(let title):
            return Alert(
                title: Text(isSpanish ? "Operación Exitosa" : "Operation Successful"),
                message: Text(isSpanish ? "El evento \"\(title)\" se creó correctamente." : "Event \"\(title)\" was created successfully."),
                dismissButton: .default(Text("OK"))
            )
        case .updateSuccess(let title):
            return Alert(
                title: Text(isSpanish ? "Operación Exitosa" : "Operation Successful"),
                message: Text(isSpanish ? "El evento \"\(title)\" se actualizó correctamente." : "Event \"\(title)\" was updated successfully."),
                dismissButton: .default(Text("OK"))
            )
        case .archiveSuccess(let title):
            return Alert(
                title: Text(isSpanish ? "Operación Exitosa" : "Operation Successful"),
                message: Text(isSpanish ? "El evento \"\(title)\" se archivó correctamente." : "Event \"\(title)\" was archived successfully."),
                dismissButton: .default(Text("OK"))
            )
        case .unarchiveSuccess(let title):
            return Alert(
                title: Text(isSpanish ? "Operación Exitosa" : "Operation Successful"),
                message: Text(isSpanish ? "El evento \"\(title)\" se restauró correctamente." : "Event \"\(title)\" was unarchived successfully."),
                dismissButton: .default(Text("OK"))
            )
        case .error(let message):
            return Alert(
                title: Text(isSpanish ? "Error" : "Error"),
                         message: Text(message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // PDF view sheet
    private var pdfViewSheet: some View {
        ZStack {
            // Background
            Color(NSColor.windowBackgroundColor)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Header with title and close button
                HStack {
                    if let _ = currentPDFDocument, let title = selectedEventTitle {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.blue)
                            Text(title)
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                    } else {
                        Text(isSpanish ? "Visualizador de PDF" : "PDF Viewer")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        showFullPDFView = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                // Add a subtle divider
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.gray.opacity(0.2))
                
                // Main content area with PDF
            if let pdf = currentPDFDocument {
                    VStack(spacing: 12) {
                        // PDF info bar
                        HStack {
                            Text("\(pdf.pageCount) \(isSpanish ? "páginas" : "pages")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            // PDF controls
                            Button(action: {
                                // Print functionality could be added here
                                print("Print PDF requested")
                            }) {
                                Label(isSpanish ? "Imprimir" : "Print", systemImage: "printer")
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.horizontal)
                        
                        // Actual PDF view
                        CalendarPDFKitView(showing: pdf)
                            .background(Color.white)
                            .cornerRadius(8)
                            .shadow(radius: 2)
                            .padding(.horizontal)
                        
                        // PDF navigation footer
                        HStack {
                            Button(action: {
                                // Action for previous page
                            }) {
                                Image(systemName: "arrow.left")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .buttonStyle(.bordered)
                            
                            Spacer()
                            
                            // Page indicator
                            if pdf.pageCount > 0 {
                                Text("\(isSpanish ? "Página" : "Page") 1 \(isSpanish ? "de" : "of") \(pdf.pageCount)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                // Action for next page
                            }) {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                    .onAppear {
                        print("🟢 [DEBUG] Rendering PDF preview block, pdfDocument: \(pdf)")
                    }
            } else if let error = pdfError {
                    VStack {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                            .padding()
                        Text(isSpanish ? "Error al cargar PDF: " : "Error loading PDF: ")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text(error.localizedDescription)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                        Spacer()
                    }
            } else {
                    VStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding()
                        Text(isSpanish ? "Cargando PDF..." : "Loading PDF...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
        }
        .frame(width: 800, height: 900)
        .onAppear { print("📄 DEBUG: PDF sheet appeared") }
    }

    // Loading view
    private func loadingView(message: String) -> some View {
        // Return a view with the divider present
        HStack(spacing: 0) {
            // Loading panel with white background
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
                        
            Text(message)
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
            .frame(minWidth: 300, maxWidth: 300)
            .background(Color.white)
            
            // Keep divider visible
            Divider()
            
            // Empty detail panel
            VStack {
                Spacer()
                Image(systemName: "arrow.left.circle")
                    .font(.system(size: 48))
                    .foregroundColor(.gray)
                Text(isSpanish ? "Selecciona un evento para ver detalles" : "Select an event to view details")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding()
                Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.textBackgroundColor))
        }
    }

    private func errorView(error: String, retryAction: @escaping () -> Void) -> some View {
        HStack(spacing: 0) {
            // Error panel
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
            Button(action: retryAction) {
                Text(isSpanish ? "Reintentar" : "Retry")
            }
                .buttonStyle(.bordered)
                .padding()
                Spacer()
            }
            .frame(minWidth: 300, maxWidth: 300)
            .background(Color.white)
            
            // Keep divider visible
            Divider()
            
            // Empty detail panel
            VStack {
                Spacer()
                Image(systemName: "arrow.left.circle")
                    .font(.system(size: 48))
                    .foregroundColor(.gray)
                Text(isSpanish ? "Selecciona un evento para ver detalles" : "Select an event to view details")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding()
                Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.textBackgroundColor))
        }
    }

    private func emptyStateView(icon: String, message: String) -> some View {
        // Return a view with the divider present
        HStack(spacing: 0) {
            // Empty list panel
            VStack {
                Spacer(minLength: 80) // Adjusted spacing for consistency
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
            Image(systemName: icon)
                            .font(.system(size: 60))
                .foregroundColor(.gray)
            Text(message)
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                Spacer(minLength: 80) // Adjusted spacing for consistency
            }
            .frame(minWidth: 300, maxWidth: 300)
            .background(Color.white)
            
            // Keep divider visible
            Divider()
            
            // Empty detail panel
            VStack {
                Spacer()
                Image(systemName: "arrow.left.circle")
                    .font(.system(size: 48))
                    .foregroundColor(.gray)
                Text(isSpanish ? "Selecciona un evento para ver detalles" : "Select an event to view details")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding()
                Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.textBackgroundColor))
        }
        .onAppear { print("🈳 DEBUG: Empty state view shown: \(message)") }
    }

    // Right panel view (event detail or edit panel)
    private var rightPanelView: some View {
        VStack {
            if isEditing {
                Text((selectedEvent == nil) ? (isSpanish ? "Crear Nuevo Evento de Calendario" : "Create New Calendar Event") : (isSpanish ? "Editar Evento" : "Edit Event"))
                    .font(.headline)
                // INSERT EDIT FORM
                VStack(alignment: .leading, spacing: 12) {
                    TextField(isSpanish ? "Título" : "Title", text: $editTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    TextField(isSpanish ? "Ubicación" : "Location", text: $editLocation)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    DatePicker(isSpanish ? "Fecha de inicio" : "Start Date", selection: $editStartDate, displayedComponents: [.date, .hourAndMinute])
                    DatePicker(isSpanish ? "Fecha de fin" : "End Date", selection: $editEndDate, displayedComponents: [.date, .hourAndMinute])
                    TextEditor(text: $editNotes)
                        .frame(height: 80)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                    TextField(isSpanish ? "Enlace (URL)" : "Link (URL)", text: $editLinkURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.vertical, 8)
                
                // Save / Cancel buttons
                HStack {
                    Button(isSpanish ? "Cancelar" : "Cancel") {
                        print("🛑 [EventManagement] Cancel button pressed")
                        isEditing = false
                        clearEditState()
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                    Button(isSpanish ? "Guardar" : "Save") {
                        print("💾 [EventManagement] Save button pressed")
                        saveChanges()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(editTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.bottom, 8)
                // END OF INSERTED EDIT FORM
            } else if let event = selectedEvent {
                // Use a ScrollView and styled VStack to match ArchivedEventsView
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        // Title
                Text(event.title)
                            .font(.title)
                    .fontWeight(.bold)
                        // Action buttons (edit, archive, delete)
                        HStack {
                            Button(action: {
                                print("✏️ [DEBUG] Edit button tapped for event ID: \(event.id)")
                                editEvent(event)
                            }) {
                                HStack {
                                    Image(systemName: "pencil")
                                    Text(isSpanish ? "Editar" : "Edit")
                                }
                            }
                            .buttonStyle(.plain)
                            Button(action: {
                                print("📦 [DEBUG] Archive button tapped for event ID: \(event.id)")
                                promptArchiveEvent(event)
                            }) {
                                HStack {
                                    Image(systemName: "archivebox")
                                    Text(isSpanish ? "Archivar" : "Archive")
                                }
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            Button(action: {
                                print("🗑️ [DEBUG] Delete button tapped for event ID: \(event.id)")
                                deleteEvent(event)
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text(isSpanish ? "Eliminar" : "Delete")
                                }
                                .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 10)
                        Divider()
                        // Date
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                            Text(isSpanish ? "Fecha: " : "Date: ")
                                .fontWeight(.medium)
                            Text(DateFormatter.localizedString(from: event.startDate, dateStyle: .full, timeStyle: .none))
                        }
                        .padding(.bottom, 5)
                        // Time
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.blue)
                            Text(isSpanish ? "Hora: " : "Time: ")
                                .fontWeight(.medium)
                            Text("\(DateFormatter.localizedString(from: event.startDate, dateStyle: .none, timeStyle: .short)) - \(DateFormatter.localizedString(from: event.endDate, dateStyle: .none, timeStyle: .short))")
                        }
                        .padding(.bottom, 5)
                        // Location
                if let location = event.location, !location.isEmpty {
                            HStack {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundColor(.red)
                                Text(isSpanish ? "Ubicación: " : "Location: ")
                                    .fontWeight(.medium)
                    Text(location)
                            }
                            .padding(.bottom, 5)
                }
                        // Notes
                if let notes = event.notes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Image(systemName: "note.text")
                                        .foregroundColor(.orange)
                                    Text(isSpanish ? "Notas:" : "Notes:")
                                        .fontWeight(.medium)
                                }
                    Text(notes)
                                    .padding(.leading, 28)
                }
                            .padding(.bottom, 5)
                        }
                        
                        // Link URL 
                        if let linkURL = event.linkURL {
                            Divider()
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Image(systemName: "link")
                                        .foregroundColor(.blue)
                                    Text(isSpanish ? "Enlace:" : "Link:")
                                        .fontWeight(.medium)
                                }
                                Link(destination: linkURL) {
                                    HStack {
                                        Text(linkURL.absoluteString)
                                            .foregroundColor(.blue)
                                            .underline()
                                        Image(systemName: "arrow.up.right.square")
                                            .foregroundColor(.blue)
                                    }
                                    .padding(8)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.leading, 28)
                            }
                            .padding(.bottom, 5)
                        }
                        
                        // PDF attachment
                if let pdfRef = event.pdfReference {
                            Divider()
                            Button(action: {
                                print("📄 [DEBUG] View PDF button tapped for event ID: \(event.id)")
                                self.viewPDF(for: pdfRef, eventId: event.id)
                            }) {
                                HStack {
                                    Image(systemName: "doc.text")
                                    Text(isSpanish ? "Ver PDF Adjunto" : "View Attached PDF")
                    }
                            }
                            .buttonStyle(.bordered)
                            .padding(.top, 5)
                        }
                        Spacer()
                    }
                    .padding()
                }
                .background(Color.white)
            } else {
                Spacer()
                Image(systemName: "arrow.left.circle")
                    .font(.system(size: 48))
                    .foregroundColor(.gray)
                Text(isSpanish ? "Selecciona un evento para ver detalles" : "Select an event to view details")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding()
            Spacer()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
        .onAppear { print("➡️ DEBUG: Right panel view appeared") }
    }

    // Sort events based on sortOrder
    private func sortEvents() {
        print("🔃 DEBUG: Sorting events by order: \(sortOrder)")
        switch sortOrder {
        case .newestFirst:
            events.sort { $0.startDate > $1.startDate }
        case .oldestFirst:
            events.sort { $0.startDate < $1.startDate }
        case .titleAZ:
            events.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .titleZA:
            events.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }
        }
    }

    private func handleEventSelection(_ event: CalendarEvent) {
        print("👉 DEBUG: Handling event selection for event ID: \(event.id), Title: \(event.title)")
        selectedEvent = event
        selectedEventId = event.id
        selectedEventTitle = event.title
        isEditing = false // Ensure we are in detail view mode, not edit mode
        
        // If there's a PDF, start loading its details but not the full PDF yet
        if let pdfRef = event.pdfReference {
            Task {
                await loadPDFRecordAsync(pdfRef)
            }
        } else {
            // Clear any previous PDF details if this event has no PDF
            selectedPDFRecord = nil
            selectedPDFURL = nil
            selectedFileLabel = ""
        }
    }

    // Helper function to log CloudKit errors consistently
    private func logCloudKitError(_ error: CKError, operation: String, resourceId: String) {
        let errorCode = error.code
        DebugLogger.log("CloudKit error in \(operation): \(errorCode.rawValue) - \(errorCode)", category: .cloudKit, level: .error)
        
        // Log underlying error if available
        if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? Error {
            DebugLogger.log("Underlying error: \(underlyingError.localizedDescription)", category: .cloudKit, level: .error)
        }
        
        var errorDetails = "Unknown error"
        switch errorCode {
        case .serverRecordChanged:
            errorDetails = "Server record changed - The record was modified by another process"
        case .networkFailure, .networkUnavailable:
            errorDetails = "Network connectivity issue - Check internet connection"
        case .serviceUnavailable:
            errorDetails = "CloudKit service unavailable - Servers may be down"
        case .notAuthenticated:
            errorDetails = "Not authenticated - Check iCloud sign in"
        case .permissionFailure:
            errorDetails = "Permission failure - Check app entitlements"
        case .unknownItem:
            errorDetails = "Unknown item - The record or zone does not exist"
        case .invalidArguments:
            errorDetails = "Invalid arguments in request"
        case .constraintViolation:
            errorDetails = "Constraint violation - Schema validation failed"
        case .operationCancelled:
            errorDetails = "Operation cancelled"
        case .changeTokenExpired:
            errorDetails = "Change token expired - Fetch new token"
        case .batchRequestFailed:
            errorDetails = "Batch request failed"
        case .zoneBusy:
            errorDetails = "Zone busy - Try again later"
        default:
            errorDetails = "Other CloudKit error: \(errorCode.rawValue)"
        }
        
        DebugLogger.log("\(operation) failed for resource \(resourceId): \(errorDetails)", category: .cloudKit, level: .error)
    }

    private func promptArchiveEvent(_ event: CalendarEvent) {
        // Store the event to be archived and show confirmation alert
        print("📦 [DEBUG] Archive confirmation requested for event ID: \(event.id)")
        selectedEvent = event
        selectedEventId = event.id
        selectedEventTitle = event.title
        activeAlert = .archiveConfirmation
    }

    private func deleteEvent(_ event: CalendarEvent) {
        let recordID = event.recordID
        
        let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: [recordID])
        operation.qualityOfService = .userInteractive // Set high QoS to prevent thread priority inversion
        operation.modifyRecordsResultBlock = { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self.events.removeAll { $0.id == event.id }
                    self.selectedEvent = nil
                    self.selectedEventId = nil
                    self.selectedEventTitle = nil
                    
                    // Trigger refresh and log
                    DebugLogger.trackRefreshTrigger(source: "EventManagement-deleteEvent", oldValue: self.refreshTrigger, newValue: !self.refreshTrigger)
                    self.refreshTrigger.toggle()
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to delete event: \(error.localizedDescription)"
                    self.activeAlert = .error(message: "Delete failed: \(error.localizedDescription)")
                }
            }
        }
        
        database.add(operation)
    }

    private func unarchiveEvent(_ event: CalendarEvent) {
        let recordID = event.recordID
        
        // Create a fetch operation with high QoS
        let fetchOperation = CKFetchRecordsOperation(recordIDs: [recordID])
        fetchOperation.qualityOfService = .userInteractive // Set high QoS
        
        fetchOperation.perRecordResultBlock = { (recordID, result) in
            switch result {
            case .success(let record):
                // Update record on the main thread
                DispatchQueue.main.async {
                    record["isArchived"] = 0
                    
                    // Create save operation with high QoS
                    let saveOperation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
                    saveOperation.qualityOfService = .userInteractive // Set high QoS
                    
                    saveOperation.modifyRecordsResultBlock = { result in
                        switch result {
                        case .success:
                            DispatchQueue.main.async {
                                self.archivedEvents.removeAll { $0.id == event.id }
                                
                                // Create updated event with isArchived = false
                                var updatedEvent = event
                                updatedEvent.isArchived = false
                                self.events.append(updatedEvent)
                                
                                // Sort events
                                self.events.sort { $0.startDate > $1.startDate }
                                
                                self.activeAlert = .unarchiveSuccess(title: event.title)
                                
                                // Trigger refresh and log
                                DebugLogger.trackRefreshTrigger(source: "EventManagement-unarchiveEvent", oldValue: self.refreshTrigger, newValue: !self.refreshTrigger)
                                self.refreshTrigger.toggle()
                            }
                        case .failure(let error):
                            DispatchQueue.main.async {
                                self.errorMessage = "Failed to unarchive event: \(error.localizedDescription)"
                                self.activeAlert = .error(message: "Unarchive failed: \(error.localizedDescription)")
                            }
                        }
                    }
                    
                    self.database.add(saveOperation)
                }
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to fetch event for unarchiving: \(error.localizedDescription)"
                    self.activeAlert = .error(message: "Unarchive failed: \(error.localizedDescription)")
                }
            }
        }
        
        // Add the fetch operation to the database
        database.add(fetchOperation)
    }

    private func confirmDeleteEvent() {
        if let event = selectedEvent { 
            deleteEvent(event) 
        }
    }

    private func confirmArchiveEvent() {
        if let event = selectedEvent {
            archiveEvent(event)
        }
    }

    private func confirmUnarchiveEvent() {
        if let event = selectedEvent { 
            unarchiveEvent(event) 
        }
    }

    // MARK: - PDF Debugging Utilities
    
    // Simple logging helper for PDF operations (re-added after refactor)
    private func logPDFOperation(operation: String, details: [String: Any] = [:]) {
        var logMessage = "📄 [PDF] \(operation)"
        if !details.isEmpty {
            let detailsString = details.map { "\($0): \($1)" }.joined(separator: ", ")
            logMessage += " - \(detailsString)"
        }
        print(logMessage)
    }

    // MARK: - Freeze Detection (simplified stub)
    private func setupFreezeDetection() {
        // Placeholder implementation to satisfy compiler; extend with real detection if needed
        freezeDetectionStartTime = Date()
    }

    // Lightweight memory usage helper (stub) to replace removed implementation
    private func getMemoryUsageMB() -> UInt64 {
        // Return 0 for now; integrate real measurement if needed
        return 0
    }

    // MARK: - PDF Viewing
    /// Fetches the PDF from CloudKit for the given reference and presents it in a sheet.
    private func viewPDF(for reference: CKRecord.Reference, eventId: String) {
        // Reset state
        currentPDFDocument = nil
        pdfError = nil
        showFullPDFView = true

        // Optional: start freeze detection timing
        startFreezeDetection(area: .pdfLoading, timeoutSeconds: 10.0, context: ["eventId": eventId])

        let recordID = reference.recordID
        database.fetch(withRecordID: recordID) { record, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.pdfError = error
                    stopFreezeDetection(additionalContext: ["success": false, "error": error.localizedDescription])
                    return
                }
                guard let record = record,
                      let asset = (record["pdfFile"] as? CKAsset) ?? (record["pdfAsset"] as? CKAsset),
                      let url = asset.fileURL,
                      let document = PDFDocument(url: url) else {
                    // Log detailed diagnostics about what's in the record
                    if let record = record {
                        print("📝 PDF DIAGNOSTICS - Record found but PDF loading failed")
                        print("📝 Record keys: \(record.allKeys().joined(separator: ", "))")
                        print("📝 Has pdfFile: \(record["pdfFile"] != nil)")
                        print("📝 Has pdfAsset: \(record["pdfAsset"] != nil)")
                        if let asset = record["pdfAsset"] as? CKAsset {
                            print("📝 pdfAsset fileURL exists: \(asset.fileURL != nil)")
                        }
                        if let asset = record["pdfFile"] as? CKAsset {
                            print("📝 pdfFile fileURL exists: \(asset.fileURL != nil)")
                        }
                    }
                    
                    self.pdfError = NSError(domain: "PDF", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid PDF data"])
                    stopFreezeDetection(additionalContext: ["success": false, "error": "Invalid PDF data"])
                    return
                }
                self.currentPDFDocument = document
                stopFreezeDetection(additionalContext: ["success": true])
            }
        }
    }

    // Helper method to set up PDF document and thumbnail - copied from NewsFeedPopupView for consistency
    private func setupPDFDocument(_ document: PDFDocument) {
        print("✅ [DEBUG] PDF document loaded with \(document.pageCount) pages")
        
        // Generate thumbnail if possible (for future use)
        if let page = document.page(at: 0) {
            let pageBounds = page.bounds(for: .mediaBox)
            print("📐 [DEBUG] PDF first page dimensions: \(pageBounds.width) x \(pageBounds.height) points")
        }
        
        // Set the document for preview
        self.pdfDocument = document
        
        // Force layout update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("🔄 [DEBUG] Forcing layout update after PDF loaded")
        }
    }

    private func archiveEvent(_ event: CalendarEvent) {
        let recordID = event.recordID
        
        // Create a fetch operation with high QoS
        let fetchOperation = CKFetchRecordsOperation(recordIDs: [recordID])
        fetchOperation.qualityOfService = .userInteractive // Set high QoS
        
        fetchOperation.perRecordResultBlock = { (recordID, result) in
            switch result {
            case .success(let record):
                // Update record on the main thread
                DispatchQueue.main.async {
                    record["isArchived"] = 1
                    
                    // Create save operation with high QoS
                    let saveOperation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
                    saveOperation.qualityOfService = .userInteractive // Set high QoS
                    
                    saveOperation.modifyRecordsResultBlock = { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .success:
                                self.events.removeAll { $0.id == event.id }
                                
                                // Create updated event with isArchived = true
                                var archivedEvent = event
                                archivedEvent.isArchived = true
                                self.archivedEvents.append(archivedEvent)
                                
                                // Sort archived events
                                self.archivedEvents.sort { $0.startDate > $1.startDate }
                                
                                self.selectedEvent = nil
                                self.selectedEventId = nil
                                self.selectedEventTitle = nil
                                self.activeAlert = .archiveSuccess(title: event.title)
                                
                                // Trigger refresh and log
                                DebugLogger.trackRefreshTrigger(source: "EventManagement-archiveEvent", oldValue: self.refreshTrigger, newValue: !self.refreshTrigger)
                                self.refreshTrigger.toggle()
                                
                            case .failure(let error):
                                self.errorMessage = "Failed to archive event: \(error.localizedDescription)"
                                self.activeAlert = .error(message: "Archive failed: \(error.localizedDescription)")
                            }
                        }
                    }
                    
                    self.database.add(saveOperation)
                }
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to fetch event for archiving: \(error.localizedDescription)"
                    self.activeAlert = .error(message: "Archive failed: \(error.localizedDescription)")
                }
            }
        }
        
        // Add the fetch operation to the database
        database.add(fetchOperation)
    }
}

// MARK: - Previews

struct EventManagementView_Previews: PreviewProvider {
    static var previews: some View {
        EventManagementView(isSpanish: .constant(false), refreshTrigger: .constant(false))
    }
}

// Create a convenience initializer for CalendarEvent for our minimal version
extension CalendarEvent {
    // Convenience initializer for creating a minimal version
    init(id: String, title: String, startDate: Date, endDate: Date, recordID: CKRecord.ID) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.recordID = recordID
        self.location = nil
        self.notes = nil
        self.pdfReference = nil
        self.isArchived = false
        self.archiveDate = nil
        self.linkURL = nil
        
        // Initialize recurrence fields with default values
        self.isRecurrenceSeries = false
        self.isRecurring = false
        self.recurrenceCount = nil
        self.recurrenceEndType = nil
        self.recurrenceParent = nil
        self.recurrenceType = nil
        self.recurrenceWeekdays = nil
    }
}

// Add this helper for time formatting:
private func formatEventTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    formatter.dateStyle = .none
    return formatter.string(from: date)
}

// Add EventRowActions as a subview with hover state and polished buttons
struct EventRowActions: View {
    let event: CalendarEvent
    let isHovered: Bool
    let editEvent: (CalendarEvent) -> Void
    let archiveEvent: (CalendarEvent) -> Void
    let deleteEvent: (CalendarEvent) -> Void
    let isSpanish: Bool
    var body: some View {
        HStack(spacing: 8) {
            Button(action: { editEvent(event) }) {
                Image(systemName: "pencil")
                    .font(.system(size: 16, weight: .medium))
                    .help(isSpanish ? "Editar" : "Edit")
            }
            .buttonStyle(.plain)
            Button(action: { archiveEvent(event) }) {
                Image(systemName: "archivebox")
                    .font(.system(size: 16, weight: .medium))
                    .help(isSpanish ? "Archivar" : "Archive")
            }
            .buttonStyle(.plain)
            Button(action: { deleteEvent(event) }) {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.red)
                    .help(isSpanish ? "Eliminar" : "Delete")
            }
            .buttonStyle(.plain)
        }
        // Make buttons always visible
    }
}

// Replace eventRow(_:) function with EventRow struct
struct EventRow: View {
    let event: CalendarEvent
    let isSpanish: Bool
    let editEvent: (CalendarEvent) -> Void
    let archiveEvent: (CalendarEvent) -> Void
    let deleteEvent: (CalendarEvent) -> Void
    let isSelected: Bool
    let selectEvent: (CalendarEvent) -> Void
    @State private var isHovered = false
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(event.title)
                    .fontWeight(.bold)
                Text(DateFormatter.localizedString(from: event.startDate, dateStyle: .short, timeStyle: .short))
                    .font(.caption)
                    .foregroundColor(.green)
                if let location = event.location, !location.isEmpty {
                    Text(location)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            EventRowActions(event: event, isHovered: isHovered, editEvent: editEvent, archiveEvent: archiveEvent, deleteEvent: deleteEvent, isSpanish: isSpanish)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(isHovered ? Color.gray.opacity(0.08) : (isSelected ? Color.blue.opacity(0.1) : Color.clear))
        .cornerRadius(6)
        .onHover { hovering in isHovered = hovering }
        .contentShape(Rectangle())
        .onTapGesture {
            selectEvent(event)
        }
    }
}

// Make viewPDF accessible to EventRowActions
extension EventRowActions {
    func viewPDF(for reference: CKRecord.Reference, eventId: String) {
        // This acts as a bridge to the main EventManagementView's viewPDF function
        // We need to use a notification to trigger it because we can't directly access it
        
        NotificationCenter.default.post(
            name: NSNotification.Name("ViewPDFRequested"),
            object: nil,
            userInfo: [
                "reference": reference,
                "eventId": eventId
            ]
        )
    }
}
