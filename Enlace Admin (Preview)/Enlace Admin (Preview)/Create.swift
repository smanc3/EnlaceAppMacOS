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
    @Binding var showPopupCreate: Bool  // Control popup visibility
    @Binding var isSpanish: Bool      // Control language selection

    @State private var documentTitle: String = ""
    @State private var selectedPDFURL: URL? = nil
    @State private var selectedFileLabel: String = ""
    @State private var isUploading: Bool = false
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600) // Default to 1 hour later
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var recordType: String = "PDFDocumentItem" // Default to PDF documents
    @State private var linkToPDF: Bool = false
    @State private var selectedPDFDocument: CKRecord.ID? = nil
    @State private var availablePDFs: [CKRecord] = []
    @State private var isPDFPickerPresented: Bool = false
    
    @State private var showAlert = false  // Alert for validation errors
    @State private var alertMessage = ""
    @State private var showSuccess = false // Success message
    
    private let container = CKContainer(identifier: "iCloud.PearInc.EICT-iOS-16")
    private var database: CKDatabase {
        return container.publicCloudDatabase
    }

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.1)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    showPopupCreate = false
                }

            VStack {
                // Title
                Text(isSpanish ? "Crear Nuevo" : "Create New")
                    .font(.title)
                    .padding(.bottom)
                    .fontWeight(.bold)
                
                // Record Type Picker
                Picker(isSpanish ? "Tipo" : "Type", selection: $recordType) {
                    Text(isSpanish ? "Documento PDF" : "PDF Document").tag("PDFDocumentItem")
                    Text(isSpanish ? "Evento de Calendario" : "Calendar Event").tag("CalendarEvent")
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                ScrollView {
                    VStack(spacing: 12) {
                        // Title Field
                        TextField(
                            isSpanish ? "Título" : "Title",
                            text: $documentTitle
                        )
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                        
                        if recordType == "PDFDocumentItem" {
                            // PDF File Selection
                            HStack {
                                Text(selectedFileLabel.isEmpty ?
                                     (isSpanish ? "Seleccionar PDF" : "Select PDF File") :
                                        selectedFileLabel)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(selectedPDFURL == nil ? Color(NSColor.controlBackgroundColor) : Color.clear)
                                .cornerRadius(6)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                
                                Spacer()
                                
                                if selectedPDFURL != nil {
                                    Button(action: { selectedPDFURL = nil; selectedFileLabel = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.trailing)
                                }
                            }
                            .padding(.horizontal)
                            
                            Button(action: selectPDFFile) {
                                Text(isSpanish ? "Seleccionar PDF" : "Select PDF")
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                            }
                            .buttonStyle(.bordered)
                            .disabled(isUploading)
                            .padding(.horizontal)
                        }
                        
                        if recordType == "CalendarEvent" {
                            // Event Location
                            TextField(
                                isSpanish ? "Ubicación" : "Location",
                                text: $location
                            )
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal)
                            
                            // Start Date
                            DatePicker(
                                isSpanish ? "Fecha y Hora de Inicio" : "Start Date & Time",
                                selection: $startDate
                            )
                            .datePickerStyle(.compact)
                            .padding(.horizontal)
                            
                            // End Date
                            DatePicker(
                                isSpanish ? "Fecha y Hora de Finalización" : "End Date & Time",
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
                            
                            // PDF Link Toggle
                            Toggle(isSpanish ? "Vincular PDF" : "Link PDF", isOn: $linkToPDF)
                                .padding(.horizontal)
                            
                            if linkToPDF {
                                Picker(isSpanish ? "Seleccionar PDF" : "Select PDF", selection: $selectedPDFDocument) {
                                    Text(isSpanish ? "Ninguno" : "None").tag(nil as CKRecord.ID?)
                                    ForEach(availablePDFs, id: \.recordID) { pdf in
                                        Text(pdf["title"] as? String ?? "Untitled").tag(pdf.recordID as CKRecord.ID?)
                                    }
                                }
                                .pickerStyle(.menu)
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                
                // Action Buttons
                HStack {
                    Button(isSpanish ? "Cancelar" : "Cancel") {
                        showPopupCreate = false
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                    .buttonStyle(.bordered)
                    .disabled(isUploading)
                    
                    Spacer()
                    
                    Button(action: saveRecord) {
                        if isUploading {
                            ProgressView()
                                .scaleEffect(0.7)
                                .padding(.horizontal, 5)
                        } else {
                            Text(isSpanish ? "Guardar" : "Save")
                                .fontWeight(.medium)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!validateFields() || isUploading)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .frame(maxWidth: 400, maxHeight: 500)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(12)
            .shadow(radius: 10)
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text(isSpanish ? "Error" : "Error"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text(isSpanish ? "Cerrar" : "Close"))
                )
            }
            .alert(isPresented: $showSuccess) {
                Alert(
                    title: Text(isSpanish ? "Éxito" : "Success"),
                    message: Text(isSpanish ? "Registro creado exitosamente" : "Record created successfully"),
                    dismissButton: .default(Text(isSpanish ? "Cerrar" : "Close")) {
                        showPopupCreate = false
                    }
                )
            }
        }
    }
    
    // PDF File Selection
    private func selectPDFFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [UTType.pdf]
        
        if panel.runModal() == .OK, let url = panel.url {
            selectedPDFURL = url
            selectedFileLabel = url.lastPathComponent
        }
    }
    
    // Load available PDFs for reference
    private func loadAvailablePDFs() {
        let query = CKQuery(recordType: "PDFDocumentItem", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "dateUploaded", ascending: false)]
        
        database.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 50) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let matchResults):
                    let records = matchResults.matchResults.compactMap { (recordID, recordResult) -> CKRecord? in
                        if case .success(let record) = recordResult {
                            return record
                        }
                        return nil
                    }
                    self.availablePDFs = records
                case .failure(let error):
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }
    
    // Save record to CloudKit
    private func saveRecord() {
        isUploading = true
        
        if recordType == "PDFDocumentItem" {
            savePDFDocument()
        } else {
            saveCalendarEvent()
        }
    }
    
    // Save PDF Document
    private func savePDFDocument() {
        let record = CKRecord(recordType: "PDFDocumentItem")
        record["title"] = documentTitle
        record["dateUploaded"] = startDate
        
        if let pdfURL = selectedPDFURL {
            record["pdfFile"] = CKAsset(fileURL: pdfURL)
        }
        
        database.save(record) { savedRecord, error in
            DispatchQueue.main.async {
                isUploading = false
                
                if let error = error {
                    alertMessage = error.localizedDescription
                    showAlert = true
                } else {
                    showSuccess = true
                }
            }
        }
    }
    
    // Save Calendar Event
    private func saveCalendarEvent() {
        let record = CKRecord(recordType: "CalendarEvent")
        record["title"] = documentTitle
        record["startDate"] = startDate
        record["endDate"] = endDate
        record["location"] = location
        
        if !notes.isEmpty {
            record["notes"] = notes
        }
        
        if linkToPDF, let pdfID = selectedPDFDocument {
            let reference = CKRecord.Reference(recordID: pdfID, action: .none)
            record["pdfReference"] = reference
        }
        
        database.save(record) { savedRecord, error in
            DispatchQueue.main.async {
                isUploading = false
                
                if let error = error {
                    alertMessage = error.localizedDescription
                    showAlert = true
                } else {
                    showSuccess = true
                }
            }
        }
    }
    
    // Validation Logic
    private func validateFields() -> Bool {
        if documentTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            alertMessage = isSpanish ? "El título es obligatorio." : "Title is required."
            return false
        }
        
        if recordType == "PDFDocumentItem" && selectedPDFURL == nil {
            alertMessage = isSpanish ? "Debe seleccionar un archivo PDF." : "You must select a PDF file."
            return false
        }
        
        if recordType == "CalendarEvent" && location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            alertMessage = isSpanish ? "La ubicación es obligatoria." : "Location is required."
            return false
        }
        
        if recordType == "CalendarEvent" && endDate < startDate {
            alertMessage = isSpanish ? "La fecha de finalización debe ser posterior a la fecha de inicio." : "End date must be after start date."
            return false
        }
        
        if recordType == "CalendarEvent" && linkToPDF && selectedPDFDocument == nil {
            alertMessage = isSpanish ? "Por favor seleccione un PDF para adjuntar." : "Please select a PDF to attach."
            return false
        }
        
        return true
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
                        selectedPDFID = pdf.recordID
                    }
                }
            }
            .navigationTitle(isSpanish ? "Seleccionar PDF" : "Select PDF")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSpanish ? "Listo" : "Done") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button(isSpanish ? "Cancelar" : "Cancel") {
                        selectedPDFID = nil
                        isPresented = false
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

