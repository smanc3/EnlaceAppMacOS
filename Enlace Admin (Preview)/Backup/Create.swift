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
    @State private var linkURL: String = ""
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
    
    // PDF importing state
    @State private var isImportingPDF: Bool = false
    
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
        VStack(spacing: 0) {
            // Top bar with Cancel and Save buttons
            HStack {
                Button(isSpanish ? "Cancelar" : "Cancel") {
                    showPopupCreate = false
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Text(isSpanish ? "Crear Nuevo Evento de Calendario" : "Create New Calendar Event")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Spacer()
                
                Button(action: saveEvent) {
                    Text(isSpanish ? "Guardar" : "Save")
                }
                .buttonStyle(.borderedProminent)
                .disabled(documentTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isUploading)
            }
            .padding(.bottom, 8)
            
            ScrollView {
                VStack(spacing: 10) {
                    // Title Field
                    HStack {
                        Text(isSpanish ? "1. Título (obligatorio):" : "1. Title (required):")
                            .font(.body.weight(.medium))
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    TextField(
                        isSpanish ? "Título" : "Title",
                        text: $documentTitle
                    )
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    
                    // Location (not required)
                    HStack {
                        Text(isSpanish ? "2. Ubicación:" : "2. Location:")
                            .font(.body.weight(.medium))
                        Spacer()
                    }
                    .padding(.horizontal)
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
                    HStack {
                        Text(isSpanish ? "Notas (opcional):" : "Notes (optional):")
                            .font(.body.weight(.medium))
                        Spacer()
                    }
                    .padding(.horizontal)
                    TextField(
                        isSpanish ? "Notas" : "Notes",
                        text: $notes
                    )
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    
                    // Link URL (optional)
                    HStack {
                        Text(isSpanish ? "Enlace URL (opcional):" : "Link URL (optional):")
                            .font(.body.weight(.medium))
                        Spacer()
                    }
                    .padding(.horizontal)
                    TextField(
                        isSpanish ? "URL del sitio web" : "Website URL",
                        text: $linkURL
                    )
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    
                    // Recurrence Section
                    HStack {
                        Text(isSpanish ? "3. Recurrencia (opcional):" : "3. Recurrence (optional):")
                            .font(.body.weight(.medium))
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
                    
                    // PDF Document section styled like News Feed
                    VStack(alignment: .leading, spacing: 8) {
                        Text(isSpanish ? "PDF Document (opcional)" : "PDF Document (optional)")
                            .font(.headline)
                            .fontWeight(.bold)
                        VStack(spacing: 10) {
                            // Upload PDF (full area clickable)
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text(isSpanish ? "Subir PDF" : "Upload PDF")
                            }
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.18), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                print("🛠️ [DEBUG] Upload PDF area tapped in CreateEvent")
                                selectedPDFURL = nil
                                selectedPDFDocument = nil
                                selectedFileLabel = ""
                                isImportingPDF = true
                                linkToPDF = true
                            }
                            // Divider with "or"
                            HStack {
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundColor(Color.gray.opacity(0.3))
                                Text(isSpanish ? "o" : "or")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundColor(Color.gray.opacity(0.3))
                            }
                            // Select Existing PDF (full area clickable)
                            HStack {
                                Image(systemName: "doc.text.magnifyingglass")
                                Text(isSpanish ? "Seleccionar PDF Existente" : "Select Existing PDF")
                            }
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.18), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                print("🛠️ [DEBUG] Select Existing PDF area tapped in CreateEvent")
                                selectedPDFURL = nil
                                selectedFileLabel = ""
                                isPDFPickerPresented = true
                                linkToPDF = true
                            }
                            if !selectedFileLabel.isEmpty {
                                HStack {
                                    Text(selectedFileLabel)
                                        .lineLimit(1)
                                    Spacer()
                                    Button(action: {
                                        selectedPDFURL = nil
                                        selectedPDFDocument = nil
                                        selectedFileLabel = ""
                                        linkToPDF = false
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(isSpanish ? "Error" : "Error"),
                message: Text(alertMessage),
                dismissButton: .default(Text(isSpanish ? "OK" : "OK"))
            )
        }
        .alert(isPresented: $showSuccess) {
            Alert(
                title: Text(isSpanish ? "Éxito" : "Success"),
                message: Text(isSpanish ? "El evento fue guardado exitosamente" : "Event was saved successfully"),
                dismissButton: .default(Text(isSpanish ? "OK" : "OK")) {
                    showPopupCreate = false
                }
            )
        }
        .sheet(isPresented: $isPDFPickerPresented) {
            PDFPickerView(
                availablePDFs: availablePDFs,
                selectedPDFID: Binding(
                    get: { selectedPDFDocument?.recordID },
                    set: { newValue in
                        if let id = newValue {
                            selectedPDFDocument = availablePDFs.first { $0.recordID == id }
                        } else {
                            selectedPDFDocument = nil
                        }
                    }
                ),
                isPresented: $isPDFPickerPresented,
                isSpanish: isSpanish
            )
        }
        // File importer for uploading a new PDF --------------------------
        .fileImporter(
            isPresented: $isImportingPDF,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    selectedPDFURL = url
                    selectedFileLabel = url.lastPathComponent
                    selectedPDFDocument = nil
                    linkToPDF = true
                }
            case .failure(let error):
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
        .task {
            // Initialize the form data
            if isEditMode {
                // If in edit mode, fetch the selected event's data
                // This would be implemented for editing functionality
            } else {
                // Set default values for new event
                startDate = Date()
                endDate = Date().addingTimeInterval(3600)
            }
            
            // Fetch available PDFs
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
                    
                    if recordType == "CalendarEvent" {
                        // Create the calendar event record with the PDF reference
                        let eventRecord = generateEventRecord(withPDFReference: pdfReference)
                        print("📝 Created event record with PDF reference")
                        
                        // Save the event
                        let savedEvent = try await database.save(eventRecord)
                        print("🎉 Successfully saved event with ID: \(savedEvent.recordID.recordName), title: \(savedEvent["title"] as? String ?? "unknown")")
                        // Verify saved event
                        await verifyEventSaved(recordID: savedEvent.recordID)
                    } else if recordType == "NewsFeedItem" {
                        // Create a NewsFeedItem record with PDF reference
                        let newsFeedRecord = generateNewsFeedRecord(withPDFReference: pdfReference)
                        print("📝 Created news feed record with PDF reference")
                        
                        // Save the news feed item
                        let savedNewsFeed = try await database.save(newsFeedRecord)
                        print("🎉 Successfully saved news feed item with ID: \(savedNewsFeed.recordID.recordName), title: \(savedNewsFeed["title"] as? String ?? "unknown")")
                    }
                    
                    self.isUploading = false
                    self.showSuccess = true
                } else if let selectedPDFURL = selectedPDFURL {
                    print("📤 Uploading new PDF from URL: \(selectedPDFURL.lastPathComponent)")
                    
                    // Create the PDF document record
                    let pdfRecord = CKRecord(recordType: "PDFDocumentItem")
                    
                    // Set metadata for the PDF
                    pdfRecord["title"] = documentTitle
                    pdfRecord["dateUploaded"] = Date()
                    
                    // Securely access the selected file
                    // Diagnostics
                    print("🔍 PDF URL path: \(selectedPDFURL.path)")
                    do {
                        let attr = try FileManager.default.attributesOfItem(atPath: selectedPDFURL.path)
                        print("🔍 Original PDF file size: \(attr[.size] ?? 0) bytes – permissions: \(String(describing: attr[.posixPermissions]))")
                    } catch {
                        print("❌ Could not read attributes of selected PDF: \(error.localizedDescription)")
                    }

                    let tempDirectory = FileManager.default.temporaryDirectory
                    let tempFile = tempDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")
                    print("🔍 Staging temp file path: \(tempFile.path)")

                    var copySucceeded = false
                    if selectedPDFURL.startAccessingSecurityScopedResource() {
                        print("🔐 Obtained security-scoped access to selected PDF")
                        defer { selectedPDFURL.stopAccessingSecurityScopedResource() }
                        do {
                            // First try simple copy
                            try FileManager.default.copyItem(at: selectedPDFURL, to: tempFile)
                            copySucceeded = true
                            print("✅ Copied PDF to temp location: \(tempFile.path)")
                        } catch {
                            print("⚠️ Direct copy failed (\(error.localizedDescription)). Attempting data-read fallback…")
                            do {
                                let data = try Data(contentsOf: selectedPDFURL)
                                try data.write(to: tempFile, options: .atomic)
                                copySucceeded = true
                                print("✅ Wrote PDF data to temp location after fallback – size: \(data.count) bytes")
                            } catch {
                                print("❌ Fallback write failed: \(error.localizedDescription)")
                            }
                        }
                    } else {
                        print("❌ Unable to access security-scoped resource for URL: \(selectedPDFURL.path)")
                    }

                    guard copySucceeded else {
                        throw NSError(domain: "CreateEvent", code: -21, userInfo: [NSLocalizedDescriptionKey: "Unable to stage PDF file into temporary directory for CloudKit upload."])
                    }

                    let pdfAsset = CKAsset(fileURL: tempFile)
                    pdfRecord["pdfFile"] = pdfAsset
                    print("📎 Attached asset to field 'pdfFile' (size: \((try? Data(contentsOf: tempFile))?.count ?? 0) bytes)")
                    
                    print("💾 Saving PDF document record...")
                    // Upload the PDF document
                    let savedPDFRecord = try await database.save(pdfRecord)
                    print("✅ PDF saved successfully with ID: \(savedPDFRecord.recordID.recordName)")
                    
                    // Create a reference to the PDF document
                    let pdfReference = CKRecord.Reference(recordID: savedPDFRecord.recordID, action: .none)
                    
                    if recordType == "CalendarEvent" {
                        // Create the calendar event record with the PDF reference
                        let eventRecord = generateEventRecord(withPDFReference: pdfReference)
                        print("📝 Created event record with reference to newly uploaded PDF")
                        
                        // Save the event
                        let savedEvent = try await database.save(eventRecord)
                        print("🎉 Successfully saved event with ID: \(savedEvent.recordID.recordName), title: \(savedEvent["title"] as? String ?? "unknown")")
                        // Verify saved event
                        await verifyEventSaved(recordID: savedEvent.recordID)
                    } else if recordType == "NewsFeedItem" {
                        // Create a NewsFeedItem record with PDF reference
                        let newsFeedRecord = generateNewsFeedRecord(withPDFReference: pdfReference)
                        print("📝 Created news feed record with reference to newly uploaded PDF")
                        
                        // Save the news feed item
                        let savedNewsFeed = try await database.save(newsFeedRecord)
                        print("🎉 Successfully saved news feed item with ID: \(savedNewsFeed.recordID.recordName), title: \(savedNewsFeed["title"] as? String ?? "unknown")")
                    }
                    
                    // Clean up the temporary file
                    try? FileManager.default.removeItem(at: tempFile)
                    
                    self.isUploading = false
                    self.showSuccess = true
                } else {
                    print("⚠️ PDF linking was enabled but no PDF was selected")
                    
                    if recordType == "CalendarEvent" {
                        // Create the calendar event record without a PDF reference
                        let eventRecord = generateEventRecord(withPDFReference: nil)
                        print("📝 Created event record without PDF reference (fallback)")
                        
                        // Save the event
                        let savedEvent = try await database.save(eventRecord)
                        print("🎉 Successfully saved event with ID: \(savedEvent.recordID.recordName), title: \(savedEvent["title"] as? String ?? "unknown")")
                        // Verify saved event
                        await verifyEventSaved(recordID: savedEvent.recordID)
                    } else if recordType == "NewsFeedItem" {
                        // Create a NewsFeedItem without a PDF reference
                        let newsFeedRecord = generateNewsFeedRecord(withPDFReference: nil)
                        print("📝 Created news feed record without PDF reference (fallback)")
                        
                        // Save the news feed item
                        let savedNewsFeed = try await database.save(newsFeedRecord)
                        print("🎉 Successfully saved news feed item with ID: \(savedNewsFeed.recordID.recordName)")
                    }
                    
                    self.isUploading = false
                    self.showSuccess = true
                }
            } else {
                print("📝 Creating record without PDF attachment")
                
                if recordType == "CalendarEvent" {
                    // Create the calendar event record without a PDF reference
                    let eventRecord = generateEventRecord(withPDFReference: nil)
                    
                    // Save the event
                    let savedEvent = try await database.save(eventRecord)
                    print("🎉 Successfully saved event with ID: \(savedEvent.recordID.recordName), title: \(savedEvent["title"] as? String ?? "unknown")")
                    // Verify saved event
                    await verifyEventSaved(recordID: savedEvent.recordID)
                } else if recordType == "NewsFeedItem" {
                    // Create a NewsFeedItem without a PDF reference
                    let newsFeedRecord = generateNewsFeedRecord(withPDFReference: nil)
                    
                    // Save the news feed item
                    let savedNewsFeed = try await database.save(newsFeedRecord)
                    print("🎉 Successfully saved news feed item with ID: \(savedNewsFeed.recordID.recordName)")
                }
                
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
        // For News Feed items, always enable PDF linking
        if recordType == "NewsFeedItem" {
            linkToPDF = true
        }
        
        // Common validation for all record types
        if documentTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            await MainActor.run {
                alertMessage = isSpanish ? "El título es obligatorio." : "Title is required."
                showAlert = true
            }
            return false
        }
        
        // Type-specific validations
        if recordType == "CalendarEvent" {
            // Calendar events require valid dates
            if endDate < startDate {
                await MainActor.run {
                    alertMessage = isSpanish ? "La fecha de finalización debe ser posterior a la fecha de inicio." : "End date must be after start date."
                    showAlert = true
                }
                return false
            }
        }
        
        // PDF validation for both record types
        if linkToPDF && selectedPDFDocument == nil && selectedPDFURL == nil {
            await MainActor.run {
                alertMessage = isSpanish ? "Por favor seleccione un PDF para adjuntar." : "Please select a PDF to attach."
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
            for key in baseEvent.getAllKeys() {
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
        linkURL = ""
        linkToPDF = false
    }
    
    // Generate an event record with optional PDF reference
    private func generateEventRecord(withPDFReference pdfReference: CKRecord.Reference?) -> CKRecord {
        // Create a new event record
        let eventRecord = CKRecord(recordType: "CalendarEvent")
        
        // Required fields
        eventRecord["title"] = documentTitle
        eventRecord["startDate"] = startDate
        eventRecord["endDate"] = endDate
        eventRecord["dateCreated"] = Date()
        eventRecord["isArchived"] = 0
        eventRecord["recordNameMirror"] = eventRecord.recordID.recordName
        
        // Optional fields
        if !location.isEmpty {
            eventRecord["location"] = location
            print("📍 Added location: \(location)")
        }
        
        if !notes.isEmpty {
            eventRecord["notes"] = notes
            print("📝 Added notes")
        }
        
        // Add link URL if not empty
        if !linkURL.isEmpty {
            eventRecord["linkURL"] = formatURL(linkURL)
            print("🔗 Added link URL: \(linkURL)")
        }
        
        // Add PDF reference if provided
        if let reference = pdfReference {
            eventRecord["pdfReference"] = reference
            print("📄 Added PDF reference")
        }
        
        return eventRecord
    }
    
    // Generate a news feed item record with optional PDF reference
    private func generateNewsFeedRecord(withPDFReference pdfReference: CKRecord.Reference?) -> CKRecord {
        print("🔄 Generating news feed record with title: \(documentTitle)")
        
        // Create the news feed record
        let newsFeedRecord = CKRecord(recordType: "NewsFeedItem")
        newsFeedRecord["title"] = documentTitle
        newsFeedRecord["scheduledDate"] = Date()
        
        // Set recordNameMirror for queryability
        newsFeedRecord["recordNameMirror"] = newsFeedRecord.recordID.recordName
        print("📋 Setting recordNameMirror to: \(newsFeedRecord.recordID.recordName)")
        
        // Add PDF reference if provided
        if let pdfReference = pdfReference {
            newsFeedRecord["pdfReference"] = pdfReference
            print("🔗 Linked PDF reference: \(pdfReference.recordID.recordName)")
            print("📱 DEBUG: This NewsFeedItem record refers to a PDFDocumentItem record")
            print("📱 DEBUG: Mobile app will see this item in both NewsFeedItem & PDFDocumentItem queries")
            print("📱 DEBUG: Admin app will now see this item in the News Feed section")
        } else {
            print("📱 DEBUG: This NewsFeedItem has no linked PDF document")
        }
        
        return newsFeedRecord
    }
    
    // Add this new helper method to format URLs properly
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
    
    // New saveEvent function
    private func saveEvent() {
        Task {
            if await validateFields() {
                isUploading = true
                await saveRecord()
                
                // Update UI on main thread
                await MainActor.run {
                    isUploading = false
                    showSuccess = true
                    onEventCreated?()
                }
            }
        }
    }
    
    // MARK: - Verification Helper
    /// Fetch the saved event back from CloudKit and print its key fields to verify correctness.
    private func verifyEventSaved(recordID: CKRecord.ID) async {
        do {
            let fetchedRecord = try await database.record(for: recordID)
            print("🔍 VERIFICATION: Fetched event record \(recordID.recordName) from CloudKit – fields:")
            let keysToCheck = ["title", "startDate", "endDate", "location", "notes", "isArchived", "pdfReference", "linkURL"]
            for key in keysToCheck {
                if let value = fetchedRecord[key] {
                    print("   • \(key): \(value)")
                } else {
                    print("   • \(key): <nil>")
                }
            }
        } catch {
            print("❌ VERIFICATION FAILED: Could not fetch saved event – \(error.localizedDescription)")
        }
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
            // Container view to apply modifiers to
            VStack {
                // Show placeholder if there are no PDFs to display
                if availablePDFs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50)
                            .foregroundColor(.secondary)
                        Text(isSpanish ? "No hay PDFs disponibles" : "No PDFs available")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
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
                    .disabled(selectedPDFID == nil)
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

