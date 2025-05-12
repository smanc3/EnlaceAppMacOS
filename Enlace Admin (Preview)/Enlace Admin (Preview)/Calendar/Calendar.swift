//
//  Calendar.swift
//  Enlace Admin (Preview)
//
//  Created by Steven Mancilla on 2/7/25.
//

import SwiftUI
import CloudKit
import PDFKit
import Foundation

// CalendarEvent struct is now defined in Models.swift

struct CalendarView: View {
    @Binding var isSpanish: Bool  // Binding to control language selection
    @Binding var refreshTrigger: Bool  // Binding to trigger refresh when new events are created
    
    @State private var selectedDate = Date()
    @State private var currentMonthDate = Date()
    @State private var events: [CalendarEvent] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var selectedDateEvents: [CalendarEvent] = []
    @State private var selectedEvent: CalendarEvent? = nil
    @State private var isEventDetailPresented: Bool = false
    @State private var showingEventDetail: Bool = false
    @State private var usingFallbackData: Bool = false
    
    private let container = CKContainer(identifier: "iCloud.PearInc.EICT-iOS-16")
    private var database: CKDatabase {
        return container.publicCloudDatabase
    }
    
    private var daysOfWeek: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isSpanish ? "es_ES" : "en_US")
        return formatter.veryShortWeekdaySymbols
    }
    
    private var currentMonth: [Date] {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: currentMonthDate)!
        let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonthDate))!
        
        var days: [Date] = []
        
        // Add leading empty days before the first day of the month
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth) - 1
        for _ in 0..<firstWeekday {
            days.append(Date.distantPast)  // Dummy date for empty space
        }
        
        // Add the actual days of the month
        for day in range {
            if let dayDate = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                days.append(dayDate)
            }
        }
        
        return days
    }
    
    private func isSelected(date: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(date, inSameDayAs: selectedDate)
    }
    
    private func hasEvent(date: Date) -> Bool {
        let calendar = Calendar.current
        return events.contains { event in
            calendar.isDate(event.startDate, inSameDayAs: date)
        }
    }
    
    private func monthYearString(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isSpanish ? "es_ES" : "en_US")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date).capitalized
    }
    
    private func goToNextMonth() {
        currentMonthDate = Calendar.current.date(byAdding: .month, value: 1, to: currentMonthDate) ?? currentMonthDate
    }
    
    private func goToPreviousMonth() {
        currentMonthDate = Calendar.current.date(byAdding: .month, value: -1, to: currentMonthDate) ?? currentMonthDate
    }
    
    private func updateSelectedDateEvents() {
        let calendar = Calendar.current
        selectedDateEvents = events.filter { event in
            calendar.isDate(event.startDate, inSameDayAs: selectedDate)
        }
    }
    
    var body: some View {
        VStack {
            ZStack {
                Color.white
                    .cornerRadius(20)
                    .shadow(radius: 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                VStack(spacing: 10) {
                    // Month Header Section
                    HStack {
                        Button(action: goToPreviousMonth) {
                            Image(systemName: "chevron.left")
                                .font(.title)
                                .foregroundColor(.orange)
                        }
                        
                        Spacer()
                        
                        Text(monthYearString(date: currentMonthDate))
                            .font(.title)
                            .bold()
                            .foregroundColor(.orange)
                        
                        Spacer()
                        
                        // Add refresh button
                        Button(action: loadEvents) {
                            Image(systemName: "arrow.clockwise")
                                .font(.title2)
                                .foregroundColor(.orange)
                        }
                        .padding(.trailing, 5)
                        
                        Button(action: goToNextMonth) {
                            Image(systemName: "chevron.right")
                                .font(.title)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding([.horizontal, .top])
                    
                    // Show a banner when displaying fallback data
                    if usingFallbackData {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(isSpanish ? "Mostrando eventos de ejemplo (sin conexión a CloudKit)" : "Showing sample events (no CloudKit connection)")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Spacer()
                            Button(action: loadEvents) {
                                Label(isSpanish ? "Reintentar" : "Retry", systemImage: "arrow.clockwise")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(.blue)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(4)
                        .padding(.horizontal)
                    }
                    
                    Divider()
                    
                    // Weekday Row Section
                    HStack {
                        ForEach(Array(daysOfWeek.enumerated()), id: \.offset) { index, day in
                            Text(day.prefix(1))
                                .font(.headline)
                                .foregroundColor(.orange)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 6)
                    
                    Divider()
                    
                    // Calendar Days Grid Section
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                        ForEach(Array(currentMonth.enumerated()), id: \.offset) { index, date in
                            if date == Date.distantPast {
                                Rectangle()
                                    .foregroundColor(.clear)
                                    .frame(height: 40)
                                    .id("empty_\(index)")
                            } else {
                                ZStack {
                                    // Background circle for selection state
                                    Circle()
                                        .fill(isSelected(date: date) ? Color.orange : Color.clear)
                                        .frame(width: 40, height: 40)
                                    
                                    // Day number text
                                    Text("\(Calendar.current.component(.day, from: date))")
                                        .foregroundColor(isSelected(date: date) ? Color.white : Color.black)
                                    
                                    // Event indicator dot
                                    if hasEvent(date: date) {
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 5, height: 5)
                                            .offset(y: 12)
                                    }
                                }
                                .frame(width: 40, height: 40)
                                .contentShape(Circle())
                                .onTapGesture {
                                    selectedDate = date
                                    updateSelectedDateEvents()
                                }
                                .id("day_\(index)")
                            }
                        }
                    }
                    .padding(.horizontal, 5)
                    
                    Divider()
                    
                    // Events for selected date - IMPROVED VERSION
                    VStack(alignment: .leading) {
                        HStack {
                            Text(isSpanish ? "Eventos para \(DateFormatter.localizedString(from: selectedDate, dateStyle: .medium, timeStyle: .none))" : "Events for \(DateFormatter.localizedString(from: selectedDate, dateStyle: .medium, timeStyle: .none))")
                                .font(.headline)
                            
                            Spacer()
                            
                            if !selectedDateEvents.isEmpty {
                                Text("\(selectedDateEvents.count) \(isSpanish ? "evento\(selectedDateEvents.count == 1 ? "" : "s")" : "event\(selectedDateEvents.count == 1 ? "" : "s")")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        
                        if selectedDateEvents.isEmpty {
                            VStack {
                                Spacer(minLength: 20)
                                HStack {
                                    Spacer()
                                    VStack(spacing: 12) {
                                        Image(systemName: "calendar.badge.clock")
                                            .font(.largeTitle)
                                            .foregroundColor(.secondary.opacity(0.5))
                                        Text(isSpanish ? "No hay eventos programados" : "No events scheduled")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                Spacer(minLength: 20)
                            }
                            .frame(height: 120)
                            .background(Color(NSColor.windowBackgroundColor))
                            .cornerRadius(8)
                            .padding(.horizontal)
                        } else {
                            ScrollView {
                                VStack(spacing: 8) {
                                    ForEach(selectedDateEvents) { event in
                                        EventListItemView(
                                            event: event,
                                            onTap: {
                                                selectedEvent = event
                                                showingEventDetail = true
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .frame(minHeight: 150, maxHeight: 300)
                            .background(Color(NSColor.windowBackgroundColor))
                            .cornerRadius(8)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top, 5)
                    .padding(.bottom, 15)
                    
                    Spacer()
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
        .background(Color(.gray))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            print("📅 CalendarView appeared")
            DebugLogger.log("CalendarView appeared and is loading events", category: .views, level: .info)
            loadEvents()
        }
        .onChange(of: refreshTrigger) { oldValue, newValue in
            if newValue {
                loadEvents()
                refreshTrigger = false  // Reset the trigger after refreshing
            }
        }
        .sheet(isPresented: $showingEventDetail) {
            if let event = selectedEvent {
                EventDetailView(event: event, isSpanish: isSpanish, container: container)
            }
        }
    }
    
    private func loadEvents() {
        isLoading = true
        errorMessage = nil
        
        // Query for non-archived events using the isArchived field from the schema
        let query = CKQuery(recordType: "CalendarEvent", predicate: NSPredicate(format: "isArchived != %@", NSNumber(value: 1)))
        query.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]
        
        print("📅 Calendar: Querying for active events (isArchived != 1)")
        print("📅 Calendar: Query details - recordType: CalendarEvent, predicate: isArchived != 1")
        print("📅 Calendar: Sort order - startDate (ascending)")
        
        database.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 100) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success(let matchResults):
                    let records = matchResults.matchResults.compactMap { (recordID, recordResult) -> CKRecord? in
                        if case .success(let record) = recordResult {
                            return record
                        } else if case .failure(let error) = recordResult {
                            print("📅 Calendar: Error retrieving individual record \(recordID.recordName): \(error.localizedDescription)")
                        }
                        return nil
                    }
                    
                    // Debug info
                    print("📅 Calendar: Found \(records.count) records")
                    for record in records {
                        let fields = record.allKeys().joined(separator: ", ")
                        print("📅 Calendar record: ID=\(record.recordID.recordName), title=\(record["title"] ?? "No title"), fields=[\(fields)]")
                    }
                    
                    if !records.isEmpty {
                        self.events = records.map { CalendarEvent(record: $0) }
                        print("📅 Calendar: Loaded \(self.events.count) actual events from CloudKit")
                        self.updateSelectedDateEvents()
                        print("📅 Calendar: Selected date events count: \(self.selectedDateEvents.count)")
                        self.usingFallbackData = false
                    } else {
                        print("📅 Calendar: No records found in CloudKit, creating fallback events")
                        // Create a fallback event if no events found
                        self.createTestEvent()
                        self.usingFallbackData = true
                    }
                    
                case .failure(let error):
                    print("📅 Calendar error: \(error.localizedDescription)")
                    
                    // Enhanced error logging
                    if let ckError = error as? CKError {
                        let errorCode = ckError.code
                        print("📅 CloudKit error code: \(errorCode.rawValue) - \(errorCode)")
                        
                        // Get the underlying error if available
                        if let underlyingError = ckError.userInfo[NSUnderlyingErrorKey] as? Error {
                            print("📅 CloudKit underlying error: \(underlyingError.localizedDescription)")
                        }
                        
                        switch errorCode {
                        case .serverRecordChanged:
                            print("📅 Server record changed - The record on the server was modified by another process")
                        case .networkFailure:
                            print("📅 Network error - Check device connectivity")
                        case .networkUnavailable:
                            print("📅 Network unavailable - Check device connectivity and airplane mode")
                        case .serviceUnavailable:
                            print("📅 Service unavailable - CloudKit servers may be down or maintenance in progress")
                        case .notAuthenticated:
                            print("📅 Not authenticated - Check iCloud sign in or entitlements")
                        case .permissionFailure:
                            print("📅 Permission failure - Check app entitlements and user permissions")
                        case .unknownItem:
                            print("📅 Unknown item - The record zone or record does not exist")
                        case .invalidArguments:
                            print("📅 Invalid arguments - Check schema definition and query structure")
                            if let reason = ckError.userInfo[NSLocalizedFailureReasonErrorKey] as? String {
                                print("📅 Reason: \(reason)")
                            }
                        case .incompatibleVersion:
                            print("📅 Incompatible schema version")
                        case .constraintViolation:
                            print("📅 Constraint violation - Schema validation failed")
                        case .badDatabase:
                            print("📅 Bad database - Error accessing database")
                        case .quotaExceeded:
                            print("📅 Quota exceeded - CloudKit storage quota reached")
                        case .zoneBusy:
                            print("📅 Zone busy - Try again later")
                        case .internalError:
                            print("📅 Internal error - CloudKit server error")
                        case .partialFailure:
                            print("📅 Partial failure - Some records failed")
                            if let partialErrors = ckError.userInfo[CKPartialErrorsByItemIDKey] as? [CKRecord.ID: Error] {
                                for (recordID, error) in partialErrors {
                                    print("📅 Partial error for record \(recordID.recordName): \(error.localizedDescription)")
                                }
                            }
                        case .batchRequestFailed:
                            print("📅 Batch request failed")
                        case .assetFileNotFound:
                            print("📅 Asset file not found")
                        case .assetFileModified:
                            print("📅 Asset file was modified during transfer")
                        case .limitExceeded:
                            print("📅 Limit exceeded - Request too large")
                        case .tooManyParticipants:
                            print("📅 Too many participants")
                        case .referenceViolation:
                            print("📅 Reference violation - Invalid reference format or referenced record doesn't exist")
                        case .missingEntitlement:
                            print("📅 Missing entitlement - Check app's entitlements and capabilities")
                        case .changeTokenExpired:
                            print("📅 Change token expired - Fetch new change token and retry")
                        case .operationCancelled:
                            print("📅 Operation cancelled")
                        case .requestRateLimited:
                            print("📅 Request rate limited - Too many requests, try again later")
                        case .zoneNotFound:
                            print("📅 Zone not found - The record zone doesn't exist")
                        default:
                            print("📅 Other CloudKit error: \(errorCode)")
                        }
                    } else {
                        print("📅 Non-CloudKit error: \(error)")
                    }
                    
                    // Create a fallback event if error occurs
                    print("📅 Calendar: Creating fallback events due to error")
                    self.createTestEvent()
                    self.usingFallbackData = true
                    self.errorMessage = nil // Don't show error to user since we're providing fallback data
                }
            }
        }
    }
    
    private func createTestEvent() {
        print("📅 Calendar: Creating fallback test events for demo purposes")
        
        // Add the Test event that was created earlier
        let testRecord = CKRecord(recordType: "CalendarEvent")
        let testId = UUID().uuidString
        testRecord["title"] = isSpanish ? "Evento de Prueba (Local)" : "Test Event (Local)"
        testRecord["startDate"] = Date()
        testRecord["endDate"] = Date().addingTimeInterval(3600)
        testRecord["location"] = isSpanish ? "Sala de Conferencias" : "Conference Room"
        testRecord["notes"] = isSpanish ? 
            "Este es un evento de prueba local creado automáticamente.\n\nID: \(testId)\n\nPosibles problemas de CloudKit:\n- Asegúrese de estar conectado a iCloud\n- Verifique que el esquema de CloudKit esté configurado correctamente\n- Compruebe las capacidades de la aplicación en Xcode\n- Verifique los permisos de la aplicación" : 
            "This is an automatically created local test event.\n\nID: \(testId)\n\nPossible CloudKit issues:\n- Ensure you are signed in to iCloud\n- Verify CloudKit schema is properly configured\n- Check app capabilities in Xcode\n- Verify app permissions"
        testRecord["recordNameMirror"] = testId
        testRecord["isArchived"] = 0
        
        // Create additional sample events
        print("📅 Creating additional sample events with dates relative to current date")
        
        // Tomorrow's event
        let additionalEvent1 = CKRecord(recordType: "CalendarEvent")
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let event1Id = UUID().uuidString
        additionalEvent1["title"] = isSpanish ? "Reunión con el Equipo (Local)" : "Meeting with Team (Local)"
        additionalEvent1["startDate"] = tomorrow.addingTimeInterval(10 * 3600) // 10 AM tomorrow
        additionalEvent1["endDate"] = tomorrow.addingTimeInterval(11 * 3600) // 11 AM tomorrow
        additionalEvent1["location"] = isSpanish ? "Oficina Principal" : "Main Office"
        additionalEvent1["notes"] = isSpanish ? 
            "Evento de muestra local creado automáticamente.\n\nID: \(event1Id)\n\nEste evento simula una reunión de equipo que ocurriría mañana." : 
            "Automatically created local sample event.\n\nID: \(event1Id)\n\nThis event simulates a team meeting that would occur tomorrow."
        additionalEvent1["recordNameMirror"] = event1Id
        additionalEvent1["isArchived"] = 0
        
        // Day after tomorrow event
        let additionalEvent2 = CKRecord(recordType: "CalendarEvent")
        let dayAfterTomorrow = Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()
        let event2Id = UUID().uuidString
        additionalEvent2["title"] = isSpanish ? "Presentación al Cliente (Local)" : "Client Presentation (Local)"
        additionalEvent2["startDate"] = dayAfterTomorrow.addingTimeInterval(14 * 3600) // 2 PM day after tomorrow
        additionalEvent2["endDate"] = dayAfterTomorrow.addingTimeInterval(16 * 3600) // 4 PM day after tomorrow
        additionalEvent2["location"] = isSpanish ? "Salón de Conferencias" : "Conference Hall"
        additionalEvent2["notes"] = isSpanish ? 
            "Evento de muestra local creado automáticamente.\n\nID: \(event2Id)\n\nEste evento simula una presentación a clientes que ocurriría en dos días." : 
            "Automatically created local sample event.\n\nID: \(event2Id)\n\nThis event simulates a client presentation that would occur in two days."
        additionalEvent2["recordNameMirror"] = event2Id
        additionalEvent2["isArchived"] = 0
        
        // Next week event
        let additionalEvent3 = CKRecord(recordType: "CalendarEvent")
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        let event3Id = UUID().uuidString
        additionalEvent3["title"] = isSpanish ? "Taller de Capacitación (Local)" : "Training Workshop (Local)"
        additionalEvent3["startDate"] = nextWeek.addingTimeInterval(9 * 3600) // 9 AM next week
        additionalEvent3["endDate"] = nextWeek.addingTimeInterval(17 * 3600) // 5 PM next week
        additionalEvent3["location"] = isSpanish ? "Centro de Formación" : "Training Center"
        additionalEvent3["notes"] = isSpanish ? 
            "Evento de muestra local creado automáticamente.\n\nID: \(event3Id)\n\nEste evento simula un taller de capacitación que ocurriría la próxima semana." : 
            "Automatically created local sample event.\n\nID: \(event3Id)\n\nThis event simulates a training workshop that would occur next week."
        additionalEvent3["recordNameMirror"] = event3Id
        additionalEvent3["isArchived"] = 0
        
        // Create events from records
        let testEvent = CalendarEvent(record: testRecord)
        let events = [
            testEvent, 
            CalendarEvent(record: additionalEvent1), 
            CalendarEvent(record: additionalEvent2),
            CalendarEvent(record: additionalEvent3)
        ]
        
        self.events = events
        print("📅 Calendar: Created \(events.count) local events as fallback")
        print("📅 Calendar: Event IDs: \(events.map { $0.id })")
        self.updateSelectedDateEvents()
        print("📅 Calendar: Selected date events count after creating fallback events: \(self.selectedDateEvents.count)")
    }
}

// Detail view for an event
struct EventDetailView: View {
    let event: CalendarEvent
    let isSpanish: Bool
    let container: CKContainer
    
    @State private var linkedPDF: PDFKit.PDFDocument? = nil
    @State private var isLoadingPDF: Bool = false
    @State private var pdfError: String? = nil
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                // Title
                Text(event.title)
                    .font(.title)
                    .fontWeight(.bold)
                
                // Date and Time
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading) {
                        Text(DateFormatter.localizedString(from: event.startDate, dateStyle: .full, timeStyle: .none))
                            .fontWeight(.medium)
                        
                        HStack {
                            Text(DateFormatter.localizedString(from: event.startDate, dateStyle: .none, timeStyle: .short))
                            
                            Text(" - \(DateFormatter.localizedString(from: event.endDate, dateStyle: .none, timeStyle: .short))")
                        }
                    }
                }
                
                // Location
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(.red)
                    
                    if let location = event.location, !location.isEmpty {
                        Text(location)
                            .fontWeight(.medium)
                    } else {
                        Text(isSpanish ? "No hay ubicación" : "No location")
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Notes
                if let notes = event.notes, !notes.isEmpty {
                    Divider()
                    
                    Text(isSpanish ? "Notas:" : "Notes:")
                        .font(.headline)
                    
                    Text(notes)
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                }
                
                // Web Link (if available)
                if let linkURL = event.linkURL {
                    Divider()
                    
                    Text(isSpanish ? "Enlace:" : "Link:")
                        .font(.headline)
                    
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
                    .onHover { hovering in
                        if hovering {
                            NSCursor.pointingHand.set()
                        } else {
                            NSCursor.arrow.set()
                        }
                    }
                    .onTapGesture {
                        // Log when a link is clicked in the calendar's event detail view
                        logLinkClicked(url: linkURL, context: "Calendar event detail view for: \(event.title)", file: #file, function: #function, line: #line)
                    }
                }
                
                // Linked PDF
                if event.pdfReference != nil {
                    Divider()
                    
                    Text(isSpanish ? "Documento adjunto:" : "Attached Document:")
                        .font(.headline)
                    
                    if isLoadingPDF {
                        ProgressView()
                            .padding()
                    } else if let error = pdfError {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                    } else if let pdf = linkedPDF {
                        CalendarPDFPreview(document: pdf)
                            .frame(height: 400)
                            .cornerRadius(8)
                    } else {
                        Button(action: loadLinkedPDF) {
                            Label(isSpanish ? "Cargar PDF" : "Load PDF", systemImage: "doc.text")
                        }
                        .buttonStyle(.bordered)
                        .padding()
                    }
                }
            }
            .padding()
        }
        .navigationTitle(isSpanish ? "Detalles del Evento" : "Event Details")
        .onAppear {
            if event.pdfReference != nil {
                loadLinkedPDF()
            }
            
            // Log when link is presented in detail view
            if let url = event.linkURL {
                logLinkClicked(url: url, context: "Displayed in calendar event detail", file: #file, function: #function, line: #line)
            }
        }
    }
    
    private func loadLinkedPDF() {
        guard let reference = event.pdfReference else { return }
        isLoadingPDF = true
        
        let database = container.publicCloudDatabase
        database.fetch(withRecordID: reference.recordID) { record, error in
            DispatchQueue.main.async {
                isLoadingPDF = false
                
                if let error = error {
                    pdfError = isSpanish ? 
                        "Error al cargar PDF: \(error.localizedDescription)" : 
                        "Error loading PDF: \(error.localizedDescription)"
                } else if let record = record, 
                          let asset = record["pdfFile"] as? CKAsset,
                          let fileURL = asset.fileURL,
                          let document = PDFKit.PDFDocument(url: fileURL) {
                    linkedPDF = document
                } else {
                    pdfError = isSpanish ? 
                        "No se pudo cargar el PDF" : 
                        "Could not load the PDF"
                }
            }
        }
    }
}

// Calendar-specific PDF Preview to avoid name conflicts
struct CalendarPDFPreview: NSViewRepresentable {
    let document: PDFKit.PDFDocument
    
    func makeNSView(context: NSViewRepresentableContext<CalendarPDFPreview>) -> PDFView {
        let view = PDFView()
        view.document = document
        view.autoScales = true
        return view
    }
    
    func updateNSView(_ nsView: PDFView, context: NSViewRepresentableContext<CalendarPDFPreview>) {
        nsView.document = document
    }
}

// Helper view to simplify the event list item
struct EventListItemView: View {
    let event: CalendarEvent
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Colored time indicator
            VStack {
                Rectangle()
                    .fill(Color.orange.opacity(0.8))
                    .frame(width: 4)
                    .cornerRadius(2)
            }
            .frame(height: 50)
            .padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(event.title)
                    .font(.headline)
                    .lineLimit(1)
                
                // Time range
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text(DateFormatter.localizedString(from: event.startDate, dateStyle: .none, timeStyle: .short))
                    Text("–")
                    Text(DateFormatter.localizedString(from: event.endDate, dateStyle: .none, timeStyle: .short))
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                // Location if available
                if let location = event.location, !location.isEmpty {
                    HStack {
                        Image(systemName: "mappin.circle")
                            .font(.caption)
                            .foregroundColor(.red)
                        Text(location)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // Icons for notes and PDF
            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 4) {
                    if event.notes != nil {
                        Image(systemName: "note.text")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    if event.pdfReference != nil {
                        Image(systemName: "doc.text")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                // Disclosure indicator
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.trailing, 4)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct CalendarView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarView(isSpanish: .constant(false), refreshTrigger: .constant(false))
    }
}
