//
//  ArchivedEventsView.swift
//  Enlace Admin (Preview)
//
//  Created on 4/17/25.
//

import SwiftUI
import CloudKit
import PDFKit
import Foundation

struct ArchivedEventsView: View {
    @Binding var isSpanish: Bool
    @Binding var refreshTrigger: Bool  // Binding to refresh the calendar
    
    // State variables
    @State private var archivedEvents: [CalendarEvent] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    @State private var selectedEvent: CalendarEvent? = nil
    @State private var showDeleteConfirmation: Bool = false
    @State private var showUnarchiveConfirmation: Bool = false
    @State private var searchText: String = ""
    @State private var sortOrder: SortOrder = .newestFirst
    @State private var showFullPDFView: Bool = false
    @State private var currentPDFDocument: PDFKit.PDFDocument? = nil
    @State private var isLoadingPDF: Bool = false
    @State private var pdfLoadError: String? = nil
    
    // Alert system for a more robust approach
    enum AlertType: Identifiable {
        case deleteConfirmation
        case unarchiveConfirmation
        case success(message: String)
        case error(message: String)
        
        var id: Int {
            switch self {
            case .deleteConfirmation: return 0
            case .unarchiveConfirmation: return 1
            case .success: return 2
            case .error: return 3
            }
        }
    }
    
    @State private var activeAlert: AlertType? = nil
    
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
            case .newestFirst: return "Newest First"
            case .oldestFirst: return "Oldest First"
            case .titleAZ: return "Title A-Z"
            case .titleZA: return "Title Z-A"
            }
        }
        
        var spanishDisplayName: String {
            switch self {
            case .newestFirst: return "Más Reciente"
            case .oldestFirst: return "Más Antiguo"
            case .titleAZ: return "Título A-Z"
            case .titleZA: return "Título Z-A"
            }
        }
    }
    
    // Filtered events based on search
    private var filteredEvents: [CalendarEvent] {
        if searchText.isEmpty {
            return archivedEvents
        } else {
            return archivedEvents.filter { event in
                event.title.localizedCaseInsensitiveContains(searchText) ||
                (event.location?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (event.notes?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isSpanish ? "Eventos Archivados" : "Archived Events")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Refresh button
                Button(action: {
                    loadArchivedEvents()
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
                    
                    TextField(isSpanish ? "Buscar por título, ubicación..." : "Search by title, location...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.trailing)
                
                Picker(isSpanish ? "Ordenar" : "Sort", selection: $sortOrder) {
                    ForEach(SortOrder.allCases) { order in
                        Text(isSpanish ? order.spanishDisplayName : order.displayName)
                            .tag(order)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.textBackgroundColor))
            
            if isLoading {
                loadingView(message: isSpanish ? "Cargando eventos archivados..." : "Loading archived events...")
            } else if let error = errorMessage {
                errorView(error: error, retryAction: loadArchivedEvents)
            } else if archivedEvents.isEmpty {
                emptyStateView(
                    icon: "archivebox", 
                    message: isSpanish ? "No hay eventos archivados" : "No archived events"
                )
            } else {
                HStack(spacing: 0) {
                    VStack {
                        List {
                            ForEach(filteredEvents) { event in
                                ArchivedEventRow(
                                    event: event, 
                                    isSpanish: isSpanish,
                                    onUnarchive: { event in
                                        selectedEvent = event
                                        activeAlert = .unarchiveConfirmation
                                    },
                                    onDelete: { event in
                                        selectedEvent = event
                                        activeAlert = .deleteConfirmation
                                    }
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectEvent(event)
                                }
                                .background(selectedEvent?.id == event.id ? Color.blue.opacity(0.1) : Color.clear)
                            }
                        }
                        .listStyle(.inset)
                    }
                    .frame(minWidth: 300)
                    
                    Divider()
                    
                    // Detail panel
                    if let event = selectedEvent {
                        selectedEventDetailView(event: event)
                    } else {
                        emptyDetailView
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            logArchive("ArchivedEventsView appeared", level: .info)
            loadArchivedEvents()
        }
        .alert(item: $activeAlert) { alertType in
            switch alertType {
            case .deleteConfirmation:
                return Alert(
                    title: Text(isSpanish ? "Confirmar eliminación" : "Confirm Deletion"),
                    message: Text(isSpanish ? "¿Estás seguro de que deseas eliminar este evento? Esta acción no se puede deshacer." : "Are you sure you want to delete this event? This action cannot be undone."),
                    primaryButton: .destructive(Text(isSpanish ? "Eliminar" : "Delete")) {
                        if let event = selectedEvent {
                            deleteEvent(event)
                            selectedEvent = nil
                        }
                    },
                    secondaryButton: .cancel(Text(isSpanish ? "Cancelar" : "Cancel"))
                )
            case .unarchiveConfirmation:
                return Alert(
                    title: Text(isSpanish ? "¿Desarchivar este evento?" : "Unarchive this event?"),
                    message: Text(isSpanish ? "El evento se moverá de nuevo a eventos activos." : "This event will be moved back to active events."),
                    primaryButton: .default(Text(isSpanish ? "Desarchivar" : "Unarchive")) {
                        if let event = selectedEvent {
                            unarchiveEvent(event)
                            selectedEvent = nil
                        }
                    },
                    secondaryButton: .cancel(Text(isSpanish ? "Cancelar" : "Cancel"))
                )
            case .success(let message):
                return Alert(
                    title: Text(isSpanish ? "Éxito" : "Success"),
                    message: Text(message),
                    dismissButton: .default(Text(isSpanish ? "Aceptar" : "OK"))
                )
            case .error(let message):
                return Alert(
                    title: Text(isSpanish ? "Error" : "Error"),
                    message: Text(message),
                    dismissButton: .default(Text(isSpanish ? "Aceptar" : "OK"))
                )
            }
        }
        .sheet(isPresented: $showFullPDFView) {
            if let pdf = currentPDFDocument {
                VStack(spacing: 0) {
                    // Header with close button
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            currentPDFDocument = nil
                            showFullPDFView = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                        .padding(10)
                        .keyboardShortcut(.escape, modifiers: [])
                    }
                    .background(Color(NSColor.windowBackgroundColor))
                    
                    // PDF View
                    ArchivedEventPDFView(document: pdf, onCancel: {
                        currentPDFDocument = nil
                        showFullPDFView = false
                    })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(NSColor.textBackgroundColor))
                }
                .frame(width: 1000, height: 800)
            } else {
                VStack {
                    Text(isSpanish ? "Error: No se pudo cargar el PDF" : "Error: Could not load PDF")
                        .foregroundColor(.red)
                        .padding()
                    
                    Button(isSpanish ? "Cerrar" : "Close") {
                        showFullPDFView = false
                    }
                    .buttonStyle(.bordered)
                }
                .frame(width: 400, height: 200)
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func loadingView(message: String) -> some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
                .padding()
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private func errorView(error: String, retryAction: @escaping () -> Void) -> some View {
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
            Button(isSpanish ? "Reintentar" : "Retry") {
                retryAction()
            }
            .buttonStyle(.bordered)
            .padding()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private func emptyStateView(icon: String, message: String) -> some View {
        VStack {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.gray)
                .padding()
            Text(message)
                .font(.headline)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private var emptyDetailView: some View {
        VStack {
            Spacer()
            Image(systemName: "arrow.left.circle")
                .font(.system(size: 40))
                .foregroundColor(.gray)
                .padding()
            Text(isSpanish ? "Selecciona un evento para ver detalles" : "Select an event to view details")
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // Event detail view
    private func selectedEventDetailView(event: CalendarEvent) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                // Title
                Text(event.title)
                    .font(.title)
                    .fontWeight(.bold)
                
                // Action buttons for event management
                HStack {
                    Button(action: {
                        selectedEvent = event
                        activeAlert = .unarchiveConfirmation
                    }) {
                        HStack {
                            Image(systemName: "arrow.uturn.up")
                            Text(isSpanish ? "Desarchivar" : "Unarchive")
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button(action: {
                        selectedEvent = event
                        activeAlert = .deleteConfirmation
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text(isSpanish ? "Eliminar" : "Delete")
                        }
                        .foregroundColor(.red)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 10)
                
                Divider()
                
                // Date and time
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
                
                // PDF attachment
                if event.pdfReference != nil {
                    Divider()
                    
                    Button(action: {
                        loadPDF(for: event)
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
    }
    
    // MARK: - Row Component
    
    struct ArchivedEventRow: View {
        let event: CalendarEvent
        let isSpanish: Bool
        var onUnarchive: ((CalendarEvent) -> Void)? = nil
        var onDelete: ((CalendarEvent) -> Void)? = nil
        
        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.headline)
                    
                    Text(DateFormatter.localizedString(from: event.startDate, dateStyle: .medium, timeStyle: .short))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let location = event.location, !location.isEmpty {
                        Text(location)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Action icons
                HStack(spacing: 16) {
                    // Unarchive
                    Button(action: {
                        onUnarchive?(event)
                    }) {
                        Image(systemName: "arrow.uturn.up")
                            .foregroundColor(.green)
                    }
                    .buttonStyle(.plain)
                    .help(isSpanish ? "Desarchivar" : "Unarchive")
                    
                    // Delete
                    Button(action: {
                        onDelete?(event)
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help(isSpanish ? "Eliminar" : "Delete")
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Methods
    
    private func loadArchivedEvents() {
        isLoading = true
        errorMessage = nil
        
        logArchive("Loading archived events", level: .info)
        
        // Use the isArchived field from the schema for archived events
        let predicate = NSPredicate(format: "isArchived == %@", NSNumber(value: 1))
        let query = CKQuery(recordType: "CalendarEvent", predicate: predicate)
        
        // Sort by startDate, not by archiveDate
        query.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        
        // Try to fetch archived events
        Task {
            do {
                let (results, _) = try await database.records(matching: query)
                var records: [CKRecord] = []
                
                for (_, recordResult) in results {
                    if case .success(let record) = recordResult {
                        records.append(record)
                    }
                }
                
                await MainActor.run {
                    if !records.isEmpty {
                        logArchive("Found \(records.count) archived events in CloudKit", level: .info)
                        self.archivedEvents = records.map { CalendarEvent(record: $0) }
                        sortArchivedEvents()
                    } else {
                        logArchive("No archived events found, creating sample events", level: .info)
                        createSampleArchivedEvents()
                    }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    logArchive("Error fetching archived events: \(error.localizedDescription)", level: .error)
                    createSampleArchivedEvents()
                    self.isLoading = false
                }
            }
        }
    }
    
    private func sortArchivedEvents() {
        switch sortOrder {
        case .newestFirst:
            archivedEvents.sort { $0.startDate > $1.startDate }
        case .oldestFirst:
            archivedEvents.sort { $0.startDate < $1.startDate }
        case .titleAZ:
            archivedEvents.sort { $0.title < $1.title }
        case .titleZA:
            archivedEvents.sort { $0.title > $1.title }
        }
        
        logArchive("Events sorted by \(sortOrder.rawValue)", level: .debug)
    }
    
    private func createSampleArchivedEvents() {
        // Create sample events for testing
        let today = Date()
        let calendar = Calendar.current
        
        // Create sample archived events
        let pastEvent1 = CKRecord(recordType: "CalendarEvent")
        pastEvent1["title"] = "Past Meeting (Archived) (Sample)"
        pastEvent1["startDate"] = calendar.date(byAdding: .day, value: -10, to: today) ?? today
        pastEvent1["endDate"] = calendar.date(byAdding: .hour, value: 1, to: calendar.date(byAdding: .day, value: -10, to: today) ?? today) ?? today
        pastEvent1["location"] = "Conference Room B"
        pastEvent1["notes"] = "This meeting is archived"
        pastEvent1["recordNameMirror"] = UUID().uuidString
        pastEvent1["isArchived"] = 1
        pastEvent1["archiveDate"] = Date().addingTimeInterval(-86400 * 2) // 2 days ago
        
        let pastEvent2 = CKRecord(recordType: "CalendarEvent")
        pastEvent2["title"] = "Old Workshop (Archived) (Sample)"
        pastEvent2["startDate"] = calendar.date(byAdding: .day, value: -20, to: today) ?? today
        pastEvent2["endDate"] = calendar.date(byAdding: .hour, value: 2, to: calendar.date(byAdding: .day, value: -20, to: today) ?? today) ?? today
        pastEvent2["location"] = "Training Center"
        pastEvent2["notes"] = "This workshop is archived"
        pastEvent2["recordNameMirror"] = UUID().uuidString
        pastEvent2["isArchived"] = 1
        pastEvent2["archiveDate"] = Date().addingTimeInterval(-86400 * 5) // 5 days ago
        
        self.archivedEvents = [pastEvent1, pastEvent2].map { CalendarEvent(record: $0) }
        logArchive("Created \(self.archivedEvents.count) sample archived events", level: .debug)
        
        // Sort archived events
        sortArchivedEvents()
    }
    
    private func selectEvent(_ event: CalendarEvent) {
        if selectedEvent?.id == event.id {
            logArchive("Deselected archived event: \(event.title)", level: .debug)
            selectedEvent = nil
        } else {
            logArchive("Selected archived event: \(event.title)", level: .debug)
            selectedEvent = event
        }
    }
    
    private func deleteEvent(_ event: CalendarEvent) {
        // Remove from archived events array
        if let index = archivedEvents.firstIndex(where: { $0.id == event.id }) {
            archivedEvents.remove(at: index)
        }
        
        // Update CloudKit to actually delete the record
        database.delete(withRecordID: event.recordID) { _, error in
            DispatchQueue.main.async {
                if let error = error {
                    logArchiveInfo("Error deleting event: \(error.localizedDescription)", level: .error)
                    self.activeAlert = .error(message: isSpanish ? 
                                            "Error al eliminar evento: \(error.localizedDescription)" : 
                                            "Error deleting event: \(error.localizedDescription)")
                } else {
                    logArchiveInfo("Successfully deleted event: \(event.title)", level: .info)
                    self.activeAlert = .success(message: isSpanish ?
                                              "El evento '\(event.title)' ha sido eliminado con éxito." :
                                              "The event '\(event.title)' has been successfully deleted.")
                }
            }
        }
    }
    
    private func unarchiveEvent(_ event: CalendarEvent) {
        // Remove from local list
        if let index = archivedEvents.firstIndex(where: { $0.id == event.id }) {
            archivedEvents.remove(at: index)
        }
        
        // Update CloudKit
        database.fetch(withRecordID: event.recordID) { record, error in
            guard let record = record, error == nil else {
                logArchiveInfo("Error fetching event to unarchive: \(error?.localizedDescription ?? "Unknown error")", level: .error)
                DispatchQueue.main.async {
                    self.activeAlert = .error(message: isSpanish ? 
                                             "Error al desarchivar evento: \(error?.localizedDescription ?? "Error desconocido")" : 
                                             "Error unarchiving event: \(error?.localizedDescription ?? "Unknown error")")
                }
                return
            }
            
            // Mark as unarchived using isArchived field
            record["isArchived"] = 0
            record["archiveDate"] = nil
            
            // Save the updated record
            self.database.save(record) { _, error in
                DispatchQueue.main.async {
                    if let error = error {
                        logArchiveInfo("Error unarchiving event: \(error.localizedDescription)", level: .error)
                        self.activeAlert = .error(message: isSpanish ? 
                                                "Error al desarchivar evento: \(error.localizedDescription)" : 
                                                "Error unarchiving event: \(error.localizedDescription)")
                    } else {
                        logArchiveInfo("Successfully unarchived event: \(event.title)", level: .info)
                        
                        // Trigger calendar refresh
                        self.refreshTrigger = true
                        print("📅 Triggering calendar refresh after event unarchive")
                        
                        self.activeAlert = .success(message: isSpanish ?
                                                  "El evento '\(event.title)' ha sido desarchivado con éxito." :
                                                  "The event '\(event.title)' has been successfully unarchived.")
                    }
                }
            }
        }
    }
    
    private func loadPDF(for event: CalendarEvent) {
        guard let pdfRef = event.pdfReference else {
            logArchiveOperation(
                operation: "PDF Load",
                itemType: "Event",
                itemTitle: event.title,
                success: false,
                errorMessage: "No PDF reference found"
            )
            return
        }
        
        isLoadingPDF = true
        pdfLoadError = nil
        
        // Fetch the CKRecord containing the PDF asset
        database.fetch(withRecordID: pdfRef.recordID) { record, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.isLoadingPDF = false
                    self.pdfLoadError = error.localizedDescription
                    logArchiveOperation(
                        operation: "PDF Load",
                        itemType: "Event",
                        itemTitle: event.title,
                        success: false,
                        errorMessage: "Error fetching PDF record: \(error.localizedDescription)"
                    )
                }
                return
            }
            
            guard let record = record, let asset = record["pdfFile"] as? CKAsset, let fileURL = asset.fileURL else {
                DispatchQueue.main.async {
                    self.isLoadingPDF = false
                    self.pdfLoadError = "PDF asset not found in record"
                    logArchiveOperation(
                        operation: "PDF Load",
                        itemType: "Event",
                        itemTitle: event.title,
                        success: false,
                        errorMessage: "PDF asset not found in record"
                    )
                }
                return
            }
            
            // Try to load the PDF document from the asset's fileURL
            if let document = PDFDocument(url: fileURL) {
                DispatchQueue.main.async {
                    self.currentPDFDocument = document
                    self.showFullPDFView = true
                    self.isLoadingPDF = false
                    logArchiveOperation(
                        operation: "PDF Load",
                        itemType: "Event",
                        itemTitle: event.title,
                        success: true
                    )
                }
            } else {
                // Try with data as fallback
                do {
                    let data = try Data(contentsOf: fileURL)
                    if let document = PDFDocument(data: data) {
                        DispatchQueue.main.async {
                            self.currentPDFDocument = document
                            self.showFullPDFView = true
                            self.isLoadingPDF = false
                            logArchiveOperation(
                                operation: "PDF Load",
                                itemType: "Event",
                                itemTitle: event.title,
                                success: true
                            )
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.isLoadingPDF = false
                            self.pdfLoadError = "Could not create PDF document from data"
                            logArchiveOperation(
                                operation: "PDF Load",
                                itemType: "Event",
                                itemTitle: event.title,
                                success: false,
                                errorMessage: "Failed to create PDF document from data"
                            )
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.isLoadingPDF = false
                        self.pdfLoadError = error.localizedDescription
                        logArchiveOperation(
                            operation: "PDF Load",
                            itemType: "Event",
                            itemTitle: event.title,
                            success: false,
                            errorMessage: "Error reading data: \(error.localizedDescription)"
                        )
                    }
                }
            }
        }
    }
}

// A wrapper to display PDF documents
struct ArchivedEventPDFView: NSViewRepresentable {
    let document: PDFKit.PDFDocument
    var onCancel: () -> Void
    
    func makeNSView(context: NSViewRepresentableContext<ArchivedEventPDFView>) -> PDFView {
        logArchive("Creating PDF view for archived document", level: .debug)
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
        
        // Ensure we can zoom in and out sufficiently
        pdfView.minScaleFactor = 0.25
        pdfView.maxScaleFactor = 4.0
        
        // Set the document
        pdfView.document = document
        
        // Calculate better scale for the first page
        if document.pageCount > 0, let firstPage = document.page(at: 0) {
            pdfView.go(to: firstPage)
            
            let pageBounds = firstPage.bounds(for: .mediaBox)
            let viewWidth = pdfView.bounds.width
            let viewHeight = pdfView.bounds.height
            
            // Calculate and apply appropriate scale factor if dimensions are valid
            if viewWidth > 0 && viewHeight > 0 && pageBounds.width > 0 && pageBounds.height > 0 {
                let widthScale = viewWidth / pageBounds.width
                let heightScale = viewHeight / pageBounds.height
                let scaleFactor = min(widthScale, heightScale) * 0.9
                
                // Apply scale with a reasonable minimum
                let finalScale = max(0.5, min(scaleFactor, 2.0))
                pdfView.scaleFactor = finalScale
                logArchive("Set PDF scale factor to \(finalScale)", level: .debug)
            }
        }
        
        // Add additional debugging info
        let pageCount = document.pageCount
        logArchive("PDF loaded with \(pageCount) pages", level: .debug)
        
        return pdfView
    }
    
    func updateNSView(_ nsView: PDFView, context: NSViewRepresentableContext<ArchivedEventPDFView>) {
        logArchive("Updating PDF view with document", level: .debug)
        nsView.document = document
        
        // Recalculate scale when document updates
        if document.pageCount > 0, let firstPage = document.page(at: 0) {
            nsView.go(to: firstPage)
            
            let pageBounds = firstPage.bounds(for: .mediaBox)
            let viewWidth = nsView.bounds.width
            let viewHeight = nsView.bounds.height
            
            if viewWidth > 0 && viewHeight > 0 && pageBounds.width > 0 && pageBounds.height > 0 {
                let widthScale = viewWidth / pageBounds.width
                let heightScale = viewHeight / pageBounds.height
                let scaleFactor = min(widthScale, heightScale) * 0.9
                
                let finalScale = max(0.5, min(scaleFactor, 2.0))
                nsView.scaleFactor = finalScale
                logArchive("Updated PDF scale factor to \(finalScale)", level: .debug)
            }
        }
    }
}

struct ArchivedEventsView_Previews: PreviewProvider {
    static var previews: some View {
        ArchivedEventsView(isSpanish: .constant(false), refreshTrigger: .constant(false))
    }
} 