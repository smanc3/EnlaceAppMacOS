//
//  Create.swift
//  Enlace Admin (Preview)
//
//  Created by Steven Mancilla on 2/11/25.
//

import SwiftUI
import CloudKit
import UniformTypeIdentifiers

struct PopupView: View {
    @Binding var showPopupCreate: Bool
    @Binding var isSpanish: Bool
    var onEventCreated: (() -> Void)? = nil
    var isEditMode: Bool = false
    
    @State private var documentTitle: String = ""
    @State private var selectedPDFURL: URL? = nil
    @State private var selectedFileLabel: String = ""
    @State private var isUploading: Bool = false
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600)
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var recordType: String = "CalendarEvent"
    @State private var linkToPDF: Bool = false
    @State private var selectedPDFDocument: CKRecord? = nil
    @State private var availablePDFs: [CKRecord] = []
    @State private var isPDFPickerPresented: Bool = false
    @State private var showProgressView: Bool = false
    
    // Recurring event properties
    @State private var isRecurring: Bool = false
    @State private var recurrenceType: RecurrenceType = .daily
    @State private var recurrenceEndDate: Date = Date().addingTimeInterval(30 * 24 * 3600) // 30 days from now
    @State private var recurrenceCount: Int = 5
    @State private var recurrenceEndType: RecurrenceEndType = .afterOccurrences
    @State private var weekdaySelection: [Bool] = Array(repeating: false, count: 7)
    @State private var monthlyRecurrenceType: MonthlyRecurrenceType = .onDay
    @State private var monthlyDayOfMonth: Int = Calendar.current.component(.day, from: Date())
    @State private var showRecurrenceOptions: Bool = false
    
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showSuccess = false
    @State private var showConfirmation = false
    
    private let container = CKContainer(identifier: "iCloud.PearInc.EICT-iOS-16")
    private var database: CKDatabase {
        return container.publicCloudDatabase
    }
    
    // Enum types for recurrence
    enum RecurrenceType: String, CaseIterable, Identifiable {
        case daily, weekly, monthly, yearly
        
        var id: String { self.rawValue }
        
        var localizedName: String {
            switch self {
            case .daily: return "Daily"
            case .weekly: return "Weekly"
            case .monthly: return "Monthly"
            case .yearly: return "Yearly"
            }
        }
        
        var localizedNameSpanish: String {
            switch self {
            case .daily: return "Diario"
            case .weekly: return "Semanal"
            case .monthly: return "Mensual"
            case .yearly: return "Anual"
            }
        }
    }
    
    enum RecurrenceEndType: String, CaseIterable, Identifiable {
        case never, onDate, afterOccurrences
        
        var id: String { self.rawValue }
        
        var localizedName: String {
            switch self {
            case .never: return "Never"
            case .onDate: return "On date"
            case .afterOccurrences: return "After occurrences"
            }
        }
        
        var localizedNameSpanish: String {
            switch self {
            case .never: return "Nunca"
            case .onDate: return "En fecha"
            case .afterOccurrences: return "Después de ocurrencias"
            }
        }
    }
    
    enum MonthlyRecurrenceType: String, CaseIterable, Identifiable {
        case onDay, onWeekday
        
        var id: String { self.rawValue }
        
        var localizedName: String {
            switch self {
            case .onDay: return "On day of month"
            case .onWeekday: return "On specific weekday"
            }
        }
        
        var localizedNameSpanish: String {
            switch self {
            case .onDay: return "En día del mes"
            case .onWeekday: return "En día específico de la semana"
            }
        }
    }
    
    var body: some View {
        VStack {
            // Title
            Text(isSpanish ? "Crear Nuevo" : "Create New")
                .font(.title)
                .padding(.top, 20)
                .padding(.bottom, 10)
                .fontWeight(.bold)
            
            // Record Type Picker
            Picker(isSpanish ? "Tipo" : "Type", selection: $recordType) {
                Text(isSpanish ? "Evento de Calendario" : "Calendar Event").tag("CalendarEvent")
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 20)
            
            ScrollView {
                VStack(spacing: 10) {
                    // Title Field
                    HStack {
                        Text(isSpanish ? "1. Título:" : "1. Title:")
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    TextField(
                        isSpanish ? "Título" : "Title",
                        text: $documentTitle
                    )
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    
                    // Event Details
                    HStack {
                        Text(isSpanish ? "2. Detalles del Evento:" : "2. Event Details:")
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Event Location
                    TextField(
                        isSpanish ? "Ubicación" : "Location",
                        text: $location
                    )
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    
                    // Start Date
                    DatePicker(
                        isSpanish ? "Inicio" : "Start",
                        selection: $startDate
                    )
                    .datePickerStyle(.compact)
                    .padding(.horizontal)
                    
                    // End Date
                    DatePicker(
                        isSpanish ? "Fin" : "End",
                        selection: $endDate
                    )
                    .datePickerStyle(.compact)
                    .padding(.horizontal)
                    
                    // Notes
                    TextField(
                        isSpanish ? "Notas" : "Notes",
                        text: $notes
                    )
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    
                    // Recurrence Section
                    HStack {
                        Text(isSpanish ? "3. Recurrencia (Opcional):" : "3. Recurrence (Optional):")
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Recurrence toggle
                    Toggle(isSpanish ? "Evento recurrente" : "Recurring event", isOn: $isRecurring)
                        .padding(.horizontal)
                        
                    if isRecurring {
                        VStack(alignment: .leading, spacing: 10) {
                            // Recurrence type selector
                            Picker(isSpanish ? "Repetir:" : "Repeat:", selection: $recurrenceType) {
                                ForEach(RecurrenceType.allCases) { type in
                                    Text(isSpanish ? type.localizedNameSpanish : type.localizedName)
                                        .tag(type)
                                }
                            }
                            .pickerStyle(.menu)
                            
                            // Weekly recurrence options
                            if recurrenceType == .weekly {
                                VStack(alignment: .leading) {
                                    Text(isSpanish ? "Días de la semana:" : "Days of week:")
                                        .font(.subheadline)
                                    
                                    HStack {
                                        ForEach(0..<7, id: \.self) { index in
                                            Toggle(Calendar.current.weekdaySymbols[index].prefix(1).uppercased(), isOn: $weekdaySelection[index])
                                                .toggleStyle(.button)
                                                .frame(maxWidth: .infinity)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // Monthly recurrence options
                            if recurrenceType == .monthly {
                                VStack(alignment: .leading) {
                                    Picker(isSpanish ? "Tipo mensual:" : "Monthly type:", selection: $monthlyRecurrenceType) {
                                        ForEach(MonthlyRecurrenceType.allCases) { type in
                                            Text(isSpanish ? type.localizedNameSpanish : type.localizedName)
                                                .tag(type)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    
                                    if monthlyRecurrenceType == .onDay {
                                        HStack {
                                            Text(isSpanish ? "Día del mes:" : "Day of month:")
                                            Picker("", selection: $monthlyDayOfMonth) {
                                                ForEach(1...31, id: \.self) { day in
                                                    Text("\(day)").tag(day)
                                                }
                                            }
                                            .frame(width: 60)
                                        }
                                    } else {
                                        // This would be for the "nth weekday" option
                                        // Simplified for brevity
                                        Text(isSpanish ? "Mismo día de la semana que la fecha inicial" : "Same weekday as start date")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // Recurrence end options
                            VStack(alignment: .leading) {
                                Text(isSpanish ? "Finaliza:" : "Ends:")
                                    .font(.subheadline)
                                
                                Picker("", selection: $recurrenceEndType) {
                                    ForEach(RecurrenceEndType.allCases) { type in
                                        Text(isSpanish ? type.localizedNameSpanish : type.localizedName)
                                            .tag(type)
                                    }
                                }
                                .pickerStyle(.segmented)
                                
                                if recurrenceEndType == .onDate {
                                    DatePicker(
                                        isSpanish ? "Fecha final:" : "End date:",
                                        selection: $recurrenceEndDate,
                                        displayedComponents: [.date]
                                    )
                                    .datePickerStyle(.compact)
                                } else if recurrenceEndType == .afterOccurrences {
                                    HStack {
                                        Text(isSpanish ? "Después de" : "After")
                                        TextField("", value: $recurrenceCount, formatter: NumberFormatter())
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: 50)
                                        Text(isSpanish ? "ocurrencias" : "occurrences")
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Step indicator for optional PDF linking
                    HStack {
                        Text(isSpanish ? "4. PDF (Opcional):" : "4. PDF (Optional):")
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // PDF Link Toggle with improved UI
                    Toggle(isSpanish ? "Vincular PDF" : "Link PDF", isOn: $linkToPDF)
                        .padding(.horizontal)
                    
                    if linkToPDF {
                        // Show a note explaining PDF management
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            
                            Text(isSpanish ? "Seleccione un PDF desde la biblioteca de documentos" : "Select a PDF from your document library")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                        
                        // Only show PDF selector when toggle is on
                        PDFSelectorView(
                            selectedPDFRecord: $selectedPDFDocument,
                            selectedPDFURL: $selectedPDFURL,
                            selectedFileLabel: $selectedFileLabel,
                            isSpanish: $isSpanish
                        )
                        .frame(height: 330)
                        .padding(.horizontal, 4)
                    }
                }
                .padding(.vertical, 5)
            }
            // Allow content to fill available space
            .frame(maxHeight: .infinity)
            
            // Action Buttons
            HStack {
                Button(action: {
                    showPopupCreate = false
                }) {
                    Text(isSpanish ? "Cancelar" : "Cancel")
                }
                .keyboardShortcut(.escape, modifiers: [])
                .buttonStyle(.bordered)
                .disabled(isUploading)
                
                Spacer()
                
                Button(action: {
                    Task {
                        if await validateFields() {
                            // Show confirmation dialog instead of immediately saving
                            showConfirmation = true
                        }
                    }
                }) {
                    if isUploading {
                        ProgressView()
                            .scaleEffect(0.7)
                            .padding(.horizontal, 5)
                    } else {
                        Text(isSpanish ? "GUARDAR" : "SAVE")
                            .fontWeight(.bold)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 15)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(isUploading)
                .keyboardShortcut(.return, modifiers: [.command])
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
        }
        // Remove any background or fixed size elements
        .background(Color.clear)
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(isSpanish ? "Error" : "Error"),
                message: Text(alertMessage),
                dismissButton: .default(Text(isSpanish ? "Cerrar" : "Close"))
            )
        }
        .alert(isSpanish ? "Éxito" : "Success", isPresented: $showSuccess) {
            Button(isSpanish ? "Cerrar" : "Close") {
                resetForm()
                showPopupCreate = false
                onEventCreated?()
            }
        } message: {
            Text(isSpanish ? "Evento creado exitosamente" : "Event created successfully")
        }
        // Add confirmation dialog
        .confirmationDialog(
            isSpanish ? "¿Confirmar creación de evento?" : "Confirm Event Creation",
            isPresented: $showConfirmation,
            titleVisibility: .visible
        ) {
            Button(isSpanish ? "Crear Evento" : "Create Event") {
                Task {
                    isUploading = true
                    await saveRecord()
                }
            }
            .keyboardShortcut(.defaultAction)
            
            Button(isSpanish ? "Cancelar" : "Cancel", role: .cancel) { }
        } message: {
            Text(isSpanish ? "¿Estás seguro de que quieres crear este evento?" : "Are you sure you want to create this event?")
        }
        .task {
            await loadPDFs()
        }
    }
    
    // PDF File Selection
    private func selectPDFFile() async {
        // This is now handled by the PDFSelectorView
        // Keeping this method empty for backward compatibility
    }
    
    // Save record to CloudKit
    private func saveRecord() async {
        self.isUploading = true
        self.showAlert = false
        
        do {
            // If PDF is linked, upload it first
            if linkToPDF {
                print("📄 PDF linking enabled - Processing PDF document")
                
                if let selectedPDFRecord = selectedPDFDocument {
                    print("✅ Selected existing PDF: \(selectedPDFRecord.recordID.recordName), title: \(selectedPDFRecord["title"] as? String ?? "unknown")")
                    
                    // Create a reference to the selected PDF
                    let pdfReference = CKRecord.Reference(recordID: selectedPDFRecord.recordID, action: .none)
                    
                    // Create the calendar event record with the PDF reference
                    let eventRecord = generateEventRecord(withPDFReference: pdfReference)
                    print("📝 Created event record with PDF reference")
                    
                    // Save the event
                    let savedEvent = try await database.save(eventRecord)
                    print("🎉 Successfully saved event with ID: \(savedEvent.recordID.recordName), title: \(savedEvent["title"] as? String ?? "unknown")")
                    
                    self.isUploading = false
                    self.showSuccess = true
                } else if let selectedPDFURL = selectedPDFURL {
                    print("📤 Uploading new PDF from URL: \(selectedPDFURL.lastPathComponent)")
                    
                    // Create the PDF document record
                    let pdfRecord = CKRecord(recordType: "PDFDocumentItem")
                    
                    // Set metadata for the PDF
                    pdfRecord["title"] = documentTitle
                    pdfRecord["dateUploaded"] = Date()
                    
                    // Convert the PDF file to a CKAsset
                    let tempDirectory = FileManager.default.temporaryDirectory
                    let tempFile = tempDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")
                    
                    // Copy the PDF file to the temporary location
                    try FileManager.default.copyItem(at: selectedPDFURL, to: tempFile)
                    let pdfAsset = CKAsset(fileURL: tempFile)
                    pdfRecord["pdfAsset"] = pdfAsset
                    
                    print("💾 Saving PDF document record...")
                    // Upload the PDF document
                    let savedPDFRecord = try await database.save(pdfRecord)
                    print("✅ PDF saved successfully with ID: \(savedPDFRecord.recordID.recordName)")
                    
                    // Create a reference to the PDF document
                    let pdfReference = CKRecord.Reference(recordID: savedPDFRecord.recordID, action: .none)
                    
                    // Create the calendar event record with the PDF reference
                    let eventRecord = generateEventRecord(withPDFReference: pdfReference)
                    print("📝 Created event record with reference to newly uploaded PDF")
                    
                    // Save the event
                    let savedEvent = try await database.save(eventRecord)
                    print("🎉 Successfully saved event with ID: \(savedEvent.recordID.recordName), title: \(savedEvent["title"] as? String ?? "unknown")")
                    
                    // Clean up the temporary file
                    try? FileManager.default.removeItem(at: tempFile)
                    
                    self.isUploading = false
                    self.showSuccess = true
                } else {
                    print("⚠️ PDF linking was enabled but no PDF was selected")
                    
                    // Create the calendar event record without a PDF reference
                    let eventRecord = generateEventRecord(withPDFReference: nil)
                    print("📝 Created event record without PDF reference (fallback)")
                    
                    // Save the event
                    let savedEvent = try await database.save(eventRecord)
                    print("🎉 Successfully saved event with ID: \(savedEvent.recordID.recordName), title: \(savedEvent["title"] as? String ?? "unknown")")
                    
                    self.isUploading = false
                    self.showSuccess = true
                }
            } else {
                print("📝 Creating event without PDF attachment")
                
                // Create the calendar event record without a PDF reference
                let eventRecord = generateEventRecord(withPDFReference: nil)
                
                // Save the event
                let savedEvent = try await database.save(eventRecord)
                print("🎉 Successfully saved event with ID: \(savedEvent.recordID.recordName), title: \(savedEvent["title"] as? String ?? "unknown")")
                
                self.isUploading = false
                self.showSuccess = true
            }
        } catch {
            print("❌ Error saving record: \(error.localizedDescription)")
            if let ckError = error as? CKError {
                print("🔍 CloudKit error code: \(ckError.errorCode)")
            }
            
            self.isUploading = false
            self.showAlert = true
            self.alertMessage = isSpanish ? "Error: \(error.localizedDescription)" : "Error: \(error.localizedDescription)"
        }
    }
    
    // Load available PDFs
    private func loadAvailablePDFs() {
        let query = CKQuery(recordType: "PDFDocumentItem", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "dateUploaded", ascending: false)]
        
        database.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 50) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let (matchResults, _)):
                    self.availablePDFs = matchResults.compactMap { (_, recordResult) -> CKRecord? in
                        if case .success(let record) = recordResult {
                            return record
                        }
                        return nil
                    }
                case .failure(let error):
                    self.alertMessage = error.localizedDescription
                    self.showAlert = true
                }
            }
        }
    }
    
    // Async wrapper for loadAvailablePDFs
    private func loadPDFs() async {
        // Call the existing method that uses completion handlers
        print("📄 Loading available PDFs for selection...")
        
        // Create a continuation that will be resumed when the async work completes
        return await withCheckedContinuation { continuation in
            let query = CKQuery(recordType: "PDFDocumentItem", predicate: NSPredicate(value: true))
            query.sortDescriptors = [NSSortDescriptor(key: "dateUploaded", ascending: false)]
            
            database.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 50) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let (matchResults, _)):
                        self.availablePDFs = matchResults.compactMap { (_, recordResult) -> CKRecord? in
                            if case .success(let record) = recordResult {
                                return record
                            }
                            return nil
                        }
                        print("📄 Loaded \(self.availablePDFs.count) PDF documents")
                    case .failure(let error):
                        self.alertMessage = error.localizedDescription
                        self.showAlert = true
                        print("❌ Error loading PDFs: \(error.localizedDescription)")
                    }
                    // Resume the continuation to signal that the async work is complete
                    continuation.resume()
                }
            }
        }
    }
    
    // Validation Logic
    private func validateFields() async -> Bool {
        if documentTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            await MainActor.run {
                alertMessage = isSpanish ? "El título es obligatorio." : "Title is required."
                showAlert = true
            }
            return false
        }
        
        if location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            await MainActor.run {
                alertMessage = isSpanish ? "La ubicación es obligatoria." : "Location is required."
                showAlert = true
            }
            return false
        }
        
        if endDate < startDate {
            await MainActor.run {
                alertMessage = isSpanish ? "La fecha de finalización debe ser posterior a la fecha de inicio." : "End date must be after start date."
                showAlert = true
            }
            return false
        }
        
        if linkToPDF && selectedPDFDocument == nil {
            await MainActor.run {
                alertMessage = isSpanish ? "Por favor seleccione un PDF existente para adjuntar." : "Please select an existing PDF to attach."
                showAlert = true
            }
            return false
        }
        
        return true
    }
    
    // Helper function to create recurring events
    private func createRecurringEvents(baseEvent: CKRecord) async throws {
        // Get the original dates
        let originalStart = baseEvent["startDate"] as! Date
        let originalEnd = baseEvent["endDate"] as! Date
        let eventDuration = originalEnd.timeIntervalSince(originalStart)
        
        // Calculate the recurring dates based on recurrence settings
        var recurrenceDates: [Date] = []
        let calendar = Calendar.current
        var currentDate = originalStart
        var occurrenceCount = 0
        
        while true {
            // Skip the first one (the original event)
            if occurrenceCount > 0 {
                recurrenceDates.append(currentDate)
            }
            
            occurrenceCount += 1
            
            // Check end conditions
            if recurrenceEndType == .afterOccurrences && recurrenceDates.count >= recurrenceCount {
                break
            }
            
            if recurrenceEndType == .onDate && currentDate > recurrenceEndDate {
                // Remove the last one if it's past the end date
                if !recurrenceDates.isEmpty && recurrenceDates.last! > recurrenceEndDate {
                    recurrenceDates.removeLast()
                }
                break
            }
            
            // Calculate the next date based on recurrence type
            var nextDate: Date?
            
            switch recurrenceType {
            case .daily:
                nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate)
                
            case .weekly:
                // For weekly, find the next selected weekday
                var daysToAdd = 1
                var nextWeekday = calendar.component(.weekday, from: currentDate) - 1
                
                for _ in 0..<7 {
                    nextWeekday = (nextWeekday + 1) % 7
                    if weekdaySelection[nextWeekday] {
                        break
                    }
                    daysToAdd += 1
                }
                
                nextDate = calendar.date(byAdding: .day, value: daysToAdd, to: currentDate)
                
            case .monthly:
                if monthlyRecurrenceType == .onDay {
                    // On specific day of month
                    var dateComponents = calendar.dateComponents([.year, .month], from: currentDate)
                    dateComponents.day = monthlyDayOfMonth
                    
                    // Get a date for the next month
                    dateComponents.month! += 1
                    nextDate = calendar.date(from: dateComponents)
                } else {
                    // On same weekday (e.g., "third Monday")
                    let originalWeekday = calendar.component(.weekday, from: originalStart)
                    let originalWeekdayOrdinal = calendar.component(.weekdayOrdinal, from: originalStart)
                    
                    var components = DateComponents()
                    components.month = 1
                    components.weekday = originalWeekday
                    components.weekdayOrdinal = originalWeekdayOrdinal
                    
                    nextDate = calendar.nextDate(after: currentDate, matching: components, matchingPolicy: .nextTime)
                }
                
            case .yearly:
                nextDate = calendar.date(byAdding: .year, value: 1, to: currentDate)
            }
            
            guard let next = nextDate else { break }
            currentDate = next
        }
        
        // Now create recurring event records
        for startDate in recurrenceDates {
            let recEvent = CKRecord(recordType: "CalendarEvent")
            
            // Copy all properties from the base event
            for key in baseEvent.allKeys() {
                if key != "startDate" && key != "endDate" {
                    recEvent[key] = baseEvent[key]
                }
            }
            
            // Set dates for this occurrence
            recEvent["startDate"] = startDate
            recEvent["endDate"] = startDate.addingTimeInterval(eventDuration)
            
            // Set recordNameMirror for queryability
            recEvent["recordNameMirror"] = recEvent.recordID.recordName
            
            // Mark as part of a recurrence series and link to the original event
            recEvent["isRecurrenceSeries"] = true
            recEvent["recurrenceParent"] = CKRecord.Reference(record: baseEvent, action: .none)
            
            // Save this recurring event
            _ = try await database.save(recEvent)
        }
    }
    
    private func resetForm() {
        documentTitle = ""
        selectedPDFURL = nil
        selectedFileLabel = ""
        isRecurring = false
        recurrenceType = .daily
        recurrenceEndDate = Date().addingTimeInterval(30 * 24 * 3600) // 30 days from now
        recurrenceCount = 5
        recurrenceEndType = .afterOccurrences
        weekdaySelection = Array(repeating: false, count: 7)
        monthlyRecurrenceType = .onDay
        monthlyDayOfMonth = Calendar.current.component(.day, from: Date())
        showRecurrenceOptions = false
        selectedPDFDocument = nil
        location = ""
        notes = ""
        linkToPDF = false
    }
    
    // Generate an event record with optional PDF reference
    private func generateEventRecord(withPDFReference pdfReference: CKRecord.Reference?) -> CKRecord {
        print("🔄 Generating event record with title: \(documentTitle)")
        
        // Create the event record
        let eventRecord = CKRecord(recordType: "CalendarEvent")
        eventRecord["title"] = documentTitle
        eventRecord["startDate"] = startDate
        eventRecord["endDate"] = endDate
        eventRecord["location"] = location
        eventRecord["notes"] = notes
        
        // Set recordNameMirror for queryability
        eventRecord["recordNameMirror"] = eventRecord.recordID.recordName
        print("📋 Setting recordNameMirror to: \(eventRecord.recordID.recordName)")
        
        // Add PDF reference if provided
        if let pdfReference = pdfReference {
            eventRecord["pdfReference"] = pdfReference
            print("🔗 Linked PDF reference: \(pdfReference.recordID.recordName)")
        }
        
        // Add recurrence metadata if enabled
        if isRecurring {
            print("🔄 Adding recurrence metadata - Type: \(recurrenceType.rawValue)")
            eventRecord["isRecurring"] = true
            eventRecord["recurrenceType"] = recurrenceType.rawValue
            
            // Handle specific recurrence type options
            switch recurrenceType {
            case .daily:
                print("📅 Daily recurrence pattern")
                
            case .weekly:
                // Save weekday selections as a binary string (e.g., "1010101")
                let weekdaysString = weekdaySelection.map { $0 ? "1" : "0" }.joined()
                eventRecord["recurrenceWeekdays"] = weekdaysString
                print("📅 Weekly recurrence pattern with days: \(weekdaysString)")
                
            case .monthly:
                eventRecord["monthlyRecurrenceType"] = monthlyRecurrenceType.rawValue
                if monthlyRecurrenceType == .onDay {
                    eventRecord["monthlyDayOfMonth"] = monthlyDayOfMonth
                    print("📅 Monthly recurrence on day \(monthlyDayOfMonth)")
                } else {
                    print("📅 Monthly recurrence on relative position (e.g., first Monday)")
                }
                
            case .yearly:
                print("📅 Yearly recurrence pattern")
            }
            
            // Handle recurrence end
            eventRecord["recurrenceEndType"] = recurrenceEndType.rawValue
            switch recurrenceEndType {
            case .never:
                print("🔄 Recurrence never ends")
                
            case .onDate:
                eventRecord["recurrenceEndDate"] = recurrenceEndDate
                print("🔄 Recurrence ends on date: \(recurrenceEndDate)")
                
            case .afterOccurrences:
                eventRecord["recurrenceCount"] = recurrenceCount
                print("🔄 Recurrence ends after \(recurrenceCount) occurrences")
            }
        } else {
            print("📅 Creating single (non-recurring) event")
        }
        
        return eventRecord
    }
}

// PDF Picker View for linking existing PDFs to calendar events
struct PDFPickerView: View {
    let availablePDFs: [CKRecord]
    @Binding var selectedPDFID: CKRecord.ID?
    @Binding var isPresented: Bool
    var isSpanish: Bool
    
    var body: some View {
        NavigationView {
            List {
                ForEach(availablePDFs, id: \.recordID) { pdf in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(pdf["title"] as? String ?? "Untitled")
                                .font(.headline)
                            if let date = pdf["dateUploaded"] as? Date {
                                Text(DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if selectedPDFID == pdf.recordID {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Task { @MainActor in
                            selectedPDFID = pdf.recordID
                        }
                    }
                }
            }
            .navigationTitle(isSpanish ? "Seleccionar PDF" : "Select PDF")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSpanish ? "Listo" : "Done") {
                        Task { @MainActor in
                            isPresented = false
                        }
                    }
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button(isSpanish ? "Cancelar" : "Cancel") {
                        Task { @MainActor in
                            selectedPDFID = nil
                            isPresented = false
                        }
                    }
                }
            }
        }
    }
}

struct Create: View {
    @State private var showPopupCreate = false
    @State private var isSpanish = false

    var body: some View {
        VStack {
            Button(action: {
                showPopupCreate = true
            }) {
                Text(isSpanish ? "Crear Nuevo" : "Create New")
                    .fontWeight(.bold)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
            
            if showPopupCreate {
                PopupView(showPopupCreate: $showPopupCreate, isSpanish: $isSpanish)
            }
        }
    }
}

#Preview {
    Create()
}

