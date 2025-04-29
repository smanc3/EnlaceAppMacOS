//
//  EventManagementView.swift
//  Enlace Admin (Preview)
//
//  Created on 5/20/25.
//

import SwiftUI
import CloudKit
import PDFKit
import Foundation

struct EventManagementView: View {
    @Binding var isSpanish: Bool
    @Binding var refreshTrigger: Bool
    
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
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isSpanish ? "Gestión de Eventos" : "Event Management")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Refresh button
                Button(action: {
                    loadEvents()
                    // Still load archived events for background operations
                    loadArchivedEvents()
                }) {
                    Label(isSpanish ? "Actualizar" : "Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            // Active Events View
            VStack {
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
                    .onChange(of: sortOrder) { oldValue, newValue in
                        sortEvents()
                        sortArchivedEvents()
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(NSColor.textBackgroundColor))
                
                if isLoading {
                    loadingView(message: isSpanish ? "Cargando eventos..." : "Loading events...")
                } else if errorMessage != nil {
                    errorView(error: errorMessage!, retryAction: loadEvents)
                } else if events.isEmpty {
                    emptyStateView(
                        icon: "calendar", 
                        message: isSpanish ? "No hay eventos para mostrar" : "No events to display"
                    )
                } else {
                    HStack(spacing: 0) {
                        VStack {
                            List {
                                ForEach(filteredEvents) { event in
                                    EventRow(
                                        event: event, 
                                        isSpanish: isSpanish,
                                        onEdit: { editEvent($0) },
                                        onArchive: { event in
                                            selectedEvent = event
                                            activeAlert = .archiveConfirmation
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
                            
                            // Create New Event button
                            Button(action: createNewEvent) {
                                Label(isSpanish ? "Crear Nuevo Evento" : "Create New Event", systemImage: "plus.circle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .padding()
                        }
                        .frame(minWidth: 300)
                        
                        Divider()
                        
                        // Detail panel
                        if let event = selectedEvent, !isEditing {
                            selectedEventDetailView(event: event)
                        } else if isEditing {
                            editEventView
                        } else {
                            emptyDetailView
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            loadEvents()
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
                            isEditing = false
                        }
                    },
                    secondaryButton: .cancel(Text(isSpanish ? "Cancelar" : "Cancel"))
                )
                
            case .archiveConfirmation:
                return Alert(
                    title: Text(isSpanish ? "¿Archivar este evento?" : "Archive this event?"),
                    message: Text(isSpanish ? "El evento se moverá al archivo y ya no estará disponible en la vista principal." : "This event will be moved to the archive and will no longer be available in the main view."),
                    primaryButton: .destructive(Text(isSpanish ? "Archivar" : "Archive")) {
                        if let event = selectedEvent {
                            archiveEvent(event)
                            selectedEvent = nil
                            isEditing = false
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
                            isEditing = false
                        }
                    },
                    secondaryButton: .cancel(Text(isSpanish ? "Cancelar" : "Cancel"))
                )
                
            case .createSuccess(let title):
                return Alert(
                    title: Text(isSpanish ? "Evento Creado" : "Event Created"),
                    message: Text(isSpanish ? "El evento '\(title)' ha sido creado con éxito." : "The event '\(title)' has been successfully created."),
                    dismissButton: .default(Text(isSpanish ? "Aceptar" : "OK"))
                )
                
            case .updateSuccess(let title):
                return Alert(
                    title: Text(isSpanish ? "Evento Actualizado" : "Event Updated"),
                    message: Text(isSpanish ? "El evento '\(title)' ha sido actualizado con éxito." : "The event '\(title)' has been successfully updated."),
                    dismissButton: .default(Text(isSpanish ? "Aceptar" : "OK"))
                )
                
            case .archiveSuccess(let title):
                return Alert(
                    title: Text(isSpanish ? "Evento Archivado" : "Event Archived"),
                    message: Text(isSpanish ? "El evento '\(title)' ha sido archivado con éxito." : "The event '\(title)' has been successfully archived."),
                    dismissButton: .default(Text(isSpanish ? "Aceptar" : "OK"))
                )
                
            case .unarchiveSuccess(let title):
                return Alert(
                    title: Text(isSpanish ? "Evento Desarchivado" : "Event Unarchived"),
                    message: Text(isSpanish ? "El evento '\(title)' ha sido desarchivado con éxito." : "The event '\(title)' has been successfully unarchived."),
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
        .sheet(isPresented: $showPDFPicker) {
            PDFSelectorView(
                selectedPDFRecord: $selectedPDFRecord,
                selectedPDFURL: $selectedPDFURL,
                selectedFileLabel: $selectedFileLabel,
                isSpanish: $isSpanish
            )
            .frame(width: 600, height: 500)
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
                    PDFKitRepresentedView(document: pdf, onCancel: {
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
                    Button(action: { editEvent(event) }) {
                        HStack {
                            Image(systemName: "pencil")
                            Text(isSpanish ? "Editar" : "Edit")
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button(action: {
                        selectedEvent = event
                        activeAlert = .archiveConfirmation
                    }) {
                        HStack {
                            Image(systemName: "archivebox")
                            Text(isSpanish ? "Archivar" : "Archive")
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
                
                // Website link if available
                if let linkURL = event.linkURL {
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
                                    .padding(.leading, 28)
                                
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onHover { hovering in
                            if hovering {
                                NSCursor.pointingHand.set()
                            } else {
                                NSCursor.arrow.set()
                            }
                        }
                        .onTapGesture {
                            // This will be called in addition to the Link's action
                            logLinkClicked(url: linkURL, context: "Event detail view for event: \(event.title)", file: #file, function: #function, line: #line)
                        }
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
    
    // Edit event view
    var editEventView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                // Title
                Text(selectedEvent == nil ? 
                    (isSpanish ? "Nuevo Evento" : "New Event") : 
                    (isSpanish ? "Editar Evento" : "Edit Event"))
                    .font(.title)
                    .fontWeight(.bold)
                
                Divider()
                
                // Title field
                Group {
                    Text(isSpanish ? "Título:" : "Title:")
                        .font(.headline)
                    
                    TextField(isSpanish ? "Título del evento" : "Event title", text: $editTitle)
                        .textFieldStyle(.roundedBorder)
                        .padding(.bottom, 10)
                }
                
                // Location field
                Group {
                    Text(isSpanish ? "Ubicación:" : "Location:")
                        .font(.headline)
                    
                    TextField(isSpanish ? "Ubicación del evento" : "Event location", text: $editLocation)
                        .textFieldStyle(.roundedBorder)
                        .padding(.bottom, 10)
                }
                
                // Date and time fields
                Group {
                    Text(isSpanish ? "Fecha y hora:" : "Date and time:")
                        .font(.headline)
                    
                    DatePicker(
                        isSpanish ? "Inicio:" : "Start:",
                        selection: $editStartDate
                    )
                    .datePickerStyle(.compact)
                    .padding(.bottom, 5)
                    
                    DatePicker(
                        isSpanish ? "Fin:" : "End:",
                        selection: $editEndDate
                    )
                    .datePickerStyle(.compact)
                    .padding(.bottom, 10)
                }
                
                // Notes field
                Group {
                    Text(isSpanish ? "Notas:" : "Notes:")
                        .font(.headline)
                    
                    TextEditor(text: $editNotes)
                        .frame(height: 100)
                        .border(Color.gray.opacity(0.3), width: 1)
                        .padding(.bottom, 10)
                }
                
                // Link URL field
                Group {
                    Text(isSpanish ? "Enlace URL:" : "Link URL:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        TextField(isSpanish ? "URL del sitio web (opcional)" : "Website URL (optional)", text: $editLinkURL)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: editLinkURL) { oldValue, newValue in
                                if !newValue.isEmpty && !newValue.lowercased().hasPrefix("http") {
                                    editLinkURL = "https://" + newValue
                                    
                                    // Log URL format correction
                                    logInfo("Added https:// prefix to URL input: \(editLinkURL)", file: #file, function: #function, line: #line)
                                }
                                
                                // Validate URL when input changes
                                if !newValue.isEmpty {
                                    let isValid = URL(string: editLinkURL) != nil
                                    logLinkValidation(url: editLinkURL, isValid: isValid, file: #file, function: #function, line: #line)
                                }
                            }
                        
                        if !editLinkURL.isEmpty {
                            HStack {
                                // Show URL validation status
                                if URL(string: editLinkURL) != nil {
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
                                if URL(string: editLinkURL) != nil {
                                    Button(action: {
                                        if let url = URL(string: editLinkURL) {
                                            NSWorkspace.shared.open(url)
                                            logLinkOpenedExternally(url: url, success: true, file: #file, function: #function, line: #line)
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
                    .padding(.bottom, 10)
                }
                
                // PDF section
                Group {
                    Text(isSpanish ? "PDF Adjunto:" : "Attached PDF:")
                        .font(.headline)
                    
                    Button(action: {
                        showPDFPicker = true
                    }) {
                        HStack {
                            Image(systemName: "doc.badge.plus")
                            Text(selectedFileLabel.isEmpty ? 
                                (isSpanish ? "Seleccionar PDF" : "Select PDF") : 
                                selectedFileLabel)
                        }
                    }
                    .buttonStyle(.bordered)
                    .padding(.bottom, 10)
                }
                
                Spacer()
                
                // Action buttons
                HStack {
                    Button(isSpanish ? "Cancelar" : "Cancel") {
                        isEditing = false
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button(isSpanish ? "Guardar Cambios" : "Save Changes") {
                        saveChanges()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(editTitle.isEmpty)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Event Row Components
    
    struct EventRow: View {
        let event: CalendarEvent
        let isSpanish: Bool
        var onEdit: ((CalendarEvent) -> Void)? = nil
        var onArchive: ((CalendarEvent) -> Void)? = nil
        var onDelete: ((CalendarEvent) -> Void)? = nil
        
        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.headline)
                    
                    Text(DateFormatter.localizedString(from: event.startDate, dateStyle: .medium, timeStyle: .short))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        if let location = event.location, !location.isEmpty {
                            HStack(spacing: 2) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)
                                Text(location)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Add link icon when URL is present
                        if event.linkURL != nil {
                            HStack(spacing: 2) {
                                Image(systemName: "link.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                Text(isSpanish ? "Enlace" : "Link")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Action icons
                HStack(spacing: 16) {
                    // Edit
                    Button(action: {
                        onEdit?(event)
                    }) {
                        Image(systemName: "pencil")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .help(isSpanish ? "Editar" : "Edit")
                    
                    // Archive
                    Button(action: {
                        onArchive?(event)
                    }) {
                        Image(systemName: "archivebox")
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                    .help(isSpanish ? "Archivar" : "Archive")
                    
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
    
    private func loadEvents() {
        isLoading = true
        errorMessage = nil
        
        print("📚 EventManagement: Starting to load events")
        
        // Use the isArchived field from the schema for active events (not archived)
        let predicate = NSPredicate(format: "isArchived != %@", NSNumber(value: 1))
        let query = CKQuery(recordType: "CalendarEvent", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]
        
        // Try to fetch events
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
                        print("📚 EventManagement: Found \(records.count) events in CloudKit")
                        self.events = records.map { CalendarEvent(record: $0) }
                        self.sortEvents()
                    } else {
                        print("📚 EventManagement: No events found in CloudKit, creating sample events")
                        createSampleEvents()
                    }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    print("📚 EventManagement: Error fetching events: \(error.localizedDescription)")
                    print("📚 EventManagement: Creating sample events instead")
                    createSampleEvents()
                    self.isLoading = false
                }
            }
        }
    }
    
    private func loadArchivedEvents() {
        print("📚 EventManagement: Loading archived events")
        
        // Use the isArchived field from the schema for archived events
        let predicate = NSPredicate(format: "isArchived == %@", NSNumber(value: 1))
        let query = CKQuery(recordType: "CalendarEvent", predicate: predicate)
        
        // Sort by startDate, not by archiveDate
        // This ensures events are sorted by when they occur, not when they were archived
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
                        print("📚 EventManagement: Found \(records.count) archived events in CloudKit")
                        self.archivedEvents = records.map { CalendarEvent(record: $0) }
                        self.sortArchivedEvents()
                    } else {
                        print("📚 EventManagement: No archived events found in CloudKit, creating sample archived events")
                        createSampleArchivedEvents()
                    }
                }
            } catch {
                await MainActor.run {
                    print("📚 EventManagement: Error fetching archived events: \(error.localizedDescription)")
                    print("📚 EventManagement: Creating sample archived events instead")
                    createSampleArchivedEvents()
                }
            }
        }
    }
    
    // Add a new method to sort archived events
    private func sortArchivedEvents() {
        switch sortOrder {
        case .newestFirst:
            // Sort by event date (startDate) - upcoming events first
            archivedEvents.sort { $0.startDate > $1.startDate }
        case .oldestFirst:
            // Sort by event date (startDate) - past events first
            archivedEvents.sort { $0.startDate < $1.startDate }
        case .titleAZ:
            archivedEvents.sort { $0.title < $1.title }
        case .titleZA:
            archivedEvents.sort { $0.title > $1.title }
        }
        
        print("📚 Archived events sorted by \(sortOrder.rawValue): Using startDate for chronological ordering")
    }
    
    // Creates sample events for testing
    private func createSampleEvents() {
        // Add the Test event that was created earlier
        let testRecord = CKRecord(recordType: "CalendarEvent")
        testRecord["title"] = "Test (From Create Event)"
        testRecord["startDate"] = Date()
        testRecord["endDate"] = Date().addingTimeInterval(3600)
        testRecord["location"] = "Conference Room"
        testRecord["notes"] = "This is the test event you created earlier"
        testRecord["recordNameMirror"] = UUID().uuidString
        testRecord["isArchived"] = 0
        
        // Create additional sample events
        let today = Date()
        let calendar = Calendar.current
        
        let sampleEvent1 = CKRecord(recordType: "CalendarEvent")
        sampleEvent1["title"] = "Team Meeting (Sample)"
        sampleEvent1["startDate"] = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        sampleEvent1["endDate"] = calendar.date(byAdding: .hour, value: 1, to: calendar.date(byAdding: .day, value: 1, to: today) ?? today) ?? today
        sampleEvent1["location"] = "Conference Room A"
        sampleEvent1["notes"] = "Discuss quarterly goals"
        sampleEvent1["recordNameMirror"] = UUID().uuidString
        sampleEvent1["isArchived"] = 0
                
        let sampleEvent2 = CKRecord(recordType: "CalendarEvent")
        sampleEvent2["title"] = "Parent Conference (Sample)"
        sampleEvent2["startDate"] = calendar.date(byAdding: .day, value: 2, to: today) ?? today
        sampleEvent2["endDate"] = calendar.date(byAdding: .hour, value: 2, to: calendar.date(byAdding: .day, value: 2, to: today) ?? today) ?? today
        sampleEvent2["location"] = "Main Office"
        sampleEvent2["notes"] = "End of year review"
        sampleEvent2["recordNameMirror"] = UUID().uuidString
        sampleEvent2["isArchived"] = 0
        
        let sampleEvent3 = CKRecord(recordType: "CalendarEvent")
        sampleEvent3["title"] = "Staff Development (Sample)"
        sampleEvent3["startDate"] = calendar.date(byAdding: .day, value: 3, to: today) ?? today
        sampleEvent3["endDate"] = calendar.date(byAdding: .hour, value: 4, to: calendar.date(byAdding: .day, value: 3, to: today) ?? today) ?? today
        sampleEvent3["location"] = "Auditorium"
        sampleEvent3["notes"] = "New curriculum training"
        sampleEvent3["recordNameMirror"] = UUID().uuidString
        sampleEvent3["isArchived"] = 0
        
        // Map to events
        let testEvent = CalendarEvent(record: testRecord)
        let sampleEvents = [sampleEvent1, sampleEvent2, sampleEvent3].map { CalendarEvent(record: $0) }
        
        // Add all events, with the test event first
        self.events = [testEvent] + sampleEvents
        
        print("📚 EventManagement: Created \(self.events.count) sample events")
        self.sortEvents()
    }
    
    // Update createSampleArchivedEvents to use the new sort method
    private func createSampleArchivedEvents() {
        // Add some archived events for demonstration
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
        print("📚 EventManagement: Created \(self.archivedEvents.count) sample archived events")
        
        // Sort archived events using the new method
        sortArchivedEvents()
    }
    
    // Helper to create a sample event record
    private func createSampleEvent(title: String, startDate: Date, endDate: Date, location: String, notes: String) -> CKRecord {
        let record = CKRecord(recordType: "CalendarEvent")
        record["title"] = title + " (Sample)"
        record["startDate"] = startDate
        record["endDate"] = endDate
        record["location"] = location
        record["notes"] = notes + "\n\nThis is a sample event created for display purposes only."
        record["recordNameMirror"] = UUID().uuidString
        record["isArchived"] = 1  // These are for archived events
        record["archiveDate"] = Date().addingTimeInterval(-Double.random(in: 86400...604800)) // Random date in the past 1-7 days
        return record
    }
    
    private func sortEvents() {
        switch sortOrder {
        case .newestFirst:
            // Sort by event date (startDate) - upcoming events first
            events.sort { $0.startDate > $1.startDate }
        case .oldestFirst:
            // Sort by event date (startDate) - past events first
            events.sort { $0.startDate < $1.startDate }
        case .titleAZ:
            events.sort { $0.title < $1.title }
        case .titleZA:
            events.sort { $0.title > $1.title }
        }
        
        print("📚 Events sorted by \(sortOrder.rawValue): Using startDate for chronological ordering")
    }
    
    // Selection and Edit functions
    private func selectEvent(_ event: CalendarEvent) {
        if selectedEvent?.id == event.id {
            selectedEvent = nil
            isEditing = false
        } else {
            selectedEvent = event
            isEditing = false
            
            // Initialize edit state
            editTitle = event.title
            editLocation = event.location ?? ""
            editStartDate = event.startDate
            editEndDate = event.endDate
            editNotes = event.notes ?? ""
            editLinkURL = event.linkURL?.absoluteString ?? ""
            
            // Handle PDF reference
            if let pdfRef = event.pdfReference {
                loadPDFRecord(pdfRef)
            } else {
                selectedPDFRecord = nil
                selectedPDFURL = nil
                selectedFileLabel = ""
            }
        }
    }
    
    private func editEvent(_ event: CalendarEvent) {
        selectedEvent = event
        isEditing = true
        
        // Initialize edit state
        editTitle = event.title
        editLocation = event.location ?? ""
        editStartDate = event.startDate
        editEndDate = event.endDate
        editNotes = event.notes ?? ""
        editLinkURL = event.linkURL?.absoluteString ?? ""
        
        // Handle PDF reference
        if let pdfRef = event.pdfReference {
            loadPDFRecord(pdfRef)
        } else {
            selectedPDFRecord = nil
            selectedPDFURL = nil
            selectedFileLabel = ""
        }
    }
    
    private func createNewEvent() {
        selectedEvent = nil
        isEditing = true
        
        // Reset form fields
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
    
    private func saveChanges() {
        if let event = selectedEvent {
            // Update existing event
            updateEvent(event)
        } else {
            // Create new event
            createEvent()
        }
        
        // Reset edit mode
        isEditing = false
    }
    
    private func createEvent() {
        let newRecord = CKRecord(recordType: "CalendarEvent")
        
        // Set fields
        newRecord["title"] = editTitle
        newRecord["startDate"] = editStartDate
        newRecord["endDate"] = editEndDate
        
        if !editLocation.isEmpty {
            newRecord["location"] = editLocation
        }
        
        if !editNotes.isEmpty {
            newRecord["notes"] = editNotes
        }
        
        // Set recordNameMirror for queryability
        newRecord["recordNameMirror"] = newRecord.recordID.recordName
        
        // Set isArchived field to 0 (not archived) for new events
        newRecord["isArchived"] = 0
        
        // Add link URL if provided
        if !editLinkURL.isEmpty {
            if let url = URL(string: editLinkURL) {
                newRecord["linkURL"] = editLinkURL
                logLinkSaved(url: url.absoluteString, modelType: "CalendarEvent", modelId: newRecord.recordID.recordName, file: #file, function: #function, line: #line)
            } else {
                logWarning("Invalid URL format, linkURL not set: \(editLinkURL)", file: #file, function: #function, line: #line)
            }
        }
        
        // Add PDF reference if available
        if let pdfRecord = selectedPDFRecord {
            newRecord["pdfReference"] = CKRecord.Reference(record: pdfRecord, action: .deleteSelf)
        }
        
        // Log for debugging
        print("📝 Creating event with title: \(editTitle), ID: \(newRecord.recordID.recordName)")
        
        // Save the record
        database.save(newRecord) { record, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.activeAlert = .error(message: self.isSpanish ? 
                                                 "Error al crear evento: \(error.localizedDescription)" :
                                                 "Error creating event: \(error.localizedDescription)")
                    print("📝 Error creating event: \(error.localizedDescription)")
                } else if let record = record {
                    print("📝 Successfully created event with ID: \(record.recordID.recordName)")
                    // Reload events
                    self.loadEvents()
                    
                    // Trigger calendar refresh
                    self.refreshTrigger = true
                    print("📅 Triggering calendar refresh after event creation")
                    
                    // Show success alert
                    self.activeAlert = .createSuccess(title: self.editTitle)
                }
            }
        }
    }
    
    private func updateEvent(_ event: CalendarEvent) {
        database.fetch(withRecordID: event.recordID) { record, error in
            guard let record = record, error == nil else {
                DispatchQueue.main.async {
                    self.activeAlert = .error(message: self.isSpanish ?
                                                 "Error al cargar evento: \(error?.localizedDescription ?? "Unknown error")" :
                                                 "Error loading event: \(error?.localizedDescription ?? "Unknown error")")
                }
                return
            }
            
            // Update fields
            record["title"] = self.editTitle
            record["startDate"] = self.editStartDate
            record["endDate"] = self.editEndDate
            
            if !self.editLocation.isEmpty {
                record["location"] = self.editLocation
            } else {
                record["location"] = nil
            }
            
            if !self.editNotes.isEmpty {
                record["notes"] = self.editNotes
            } else {
                record["notes"] = nil
            }
            
            // Update link URL - either set or remove
            if !self.editLinkURL.isEmpty {
                if let url = URL(string: self.editLinkURL) {
                    record["linkURL"] = self.editLinkURL
                    logLinkSaved(url: url.absoluteString, modelType: "CalendarEvent", modelId: event.id, file: #file, function: #function, line: #line)
                } else {
                    logWarning("Invalid URL format, linkURL not updated: \(self.editLinkURL)", file: #file, function: #function, line: #line)
                }
            } else {
                record["linkURL"] = nil
                logInfo("Removed linkURL from event", file: #file, function: #function, line: #line)
            }
            
            // Ensure recordNameMirror is set
            if record["recordNameMirror"] == nil {
                record["recordNameMirror"] = record.recordID.recordName
            }
            
            // Update PDF reference
            if let pdfRecord = self.selectedPDFRecord {
                record["pdfReference"] = CKRecord.Reference(record: pdfRecord, action: .deleteSelf)
            } else if self.selectedPDFRecord == nil && self.selectedFileLabel.isEmpty {
                // Clear reference if nothing selected
                record["pdfReference"] = nil
            }
            
            // Save the record
            self.database.save(record) { _, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.activeAlert = .error(message: self.isSpanish ?
                                                     "Error al guardar evento: \(error.localizedDescription)" :
                                                     "Error saving event: \(error.localizedDescription)")
                    } else {
                        // Reload events
                        self.loadEvents()
                        
                        // Trigger calendar refresh
                        self.refreshTrigger = true
                        print("📅 Triggering calendar refresh after event update")
                        
                        // Show success alert
                        self.activeAlert = .updateSuccess(title: self.editTitle)
                    }
                }
            }
        }
    }
    
    private func deleteEvent(_ event: CalendarEvent) {
        database.delete(withRecordID: event.recordID) { _, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.activeAlert = .error(message: self.isSpanish ?
                        "Error al eliminar evento: \(error.localizedDescription)" :
                        "Error deleting event: \(error.localizedDescription)")
                } else {
                    // Remove from local array and reload
                    if let index = self.events.firstIndex(where: { $0.id == event.id }) {
                        self.events.remove(at: index)
                    }
                }
            }
        }
    }
    
    private func loadPDFRecord(_ reference: CKRecord.Reference) {
        database.fetch(withRecordID: reference.recordID) { record, error in
            if let record = record, error == nil {
                DispatchQueue.main.async {
                    self.selectedPDFRecord = record
                    self.selectedFileLabel = record["title"] as? String ?? "Selected PDF"
                }
            }
        }
    }
    
    private func loadPDF(for event: CalendarEvent) {
        guard let pdfRef = event.pdfReference else { return }
        
        database.fetch(withRecordID: pdfRef.recordID) { record, error in
            if let error = error {
                print("Error fetching PDF: \(error.localizedDescription)")
                return
            }
            
            guard let record = record, let asset = record["pdfFile"] as? CKAsset, let fileURL = asset.fileURL else {
                print("PDF asset not found")
                return
            }
            
            // Try to create PDF document
            if let pdfDocument = PDFKit.PDFDocument(url: fileURL) {
                DispatchQueue.main.async {
                    self.currentPDFDocument = pdfDocument
                    self.showFullPDFView = true
                }
            } else {
                // Try with data
                do {
                    let data = try Data(contentsOf: fileURL)
                    if let pdfDocument = PDFKit.PDFDocument(data: data) {
                        DispatchQueue.main.async {
                            self.currentPDFDocument = pdfDocument
                            self.showFullPDFView = true
                        }
                    }
                } catch {
                    print("Error loading PDF data: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func archiveEvent(_ event: CalendarEvent) {
        // First, add to archived events array for display
        archivedEvents.append(event)
        
        // Then remove from active events
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events.remove(at: index)
        }
        
        // Try to update in CloudKit if it's not a sample event
        if !event.title.contains("(Sample)") {
            Task {
                do {
                    // Fetch the record
                    let record = try await database.record(for: event.recordID)
                    
                    // Mark as archived using isArchived field
                    record["isArchived"] = 1
                    record["archiveDate"] = Date()
                    
                    // Save the record
                    try await database.save(record)
                    print("📚 EventManagement: Successfully archived event in CloudKit: \(event.title)")
                    
                    // Show success alert
                    await MainActor.run {
                        self.activeAlert = .archiveSuccess(title: event.title)
                    }
                } catch {
                    print("📚 EventManagement: Failed to archive event in CloudKit: \(error.localizedDescription)")
                    // The event is still archived locally, so no need to take action
                }
            }
        } else {
            print("📚 EventManagement: Archived sample event (local only): \(event.title)")
        }
    }
    
    private func unarchiveEvent(_ event: CalendarEvent) {
        // First, add back to active events
        events.append(event)
        
        // Then remove from archived events
        if let index = archivedEvents.firstIndex(where: { $0.id == event.id }) {
            archivedEvents.remove(at: index)
        }
        
        // Sort the active events based on current sort order
        sortEvents()
        
        // Try to update in CloudKit if it's not a sample event
        if !event.title.contains("(Sample)") {
            Task {
                do {
                    // Fetch the record
                    let record = try await database.record(for: event.recordID)
                    
                    // Mark as not archived using the isArchived field
                    record["isArchived"] = 0
                    record["archiveDate"] = nil
                    
                    // Save the record
                    try await database.save(record)
                    print("📚 EventManagement: Successfully unarchived event in CloudKit: \(event.title)")
                    
                    // Show success alert
                    await MainActor.run {
                        self.activeAlert = .unarchiveSuccess(title: event.title)
                    }
                } catch {
                    print("📚 EventManagement: Failed to unarchive event in CloudKit: \(error.localizedDescription)")
                    // The event is still unarchived locally, so no need to take action
                }
            }
        } else {
            print("📚 EventManagement: Unarchived sample event (local only): \(event.title)")
        }
    }
}

// MARK: - Previews

struct EventManagementView_Previews: PreviewProvider {
    static var previews: some View {
        EventManagementView(isSpanish: .constant(false), refreshTrigger: .constant(false))
    }
} 