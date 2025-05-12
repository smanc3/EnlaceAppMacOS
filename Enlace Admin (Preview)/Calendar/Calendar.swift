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
    
    private func formatDate(_ date: Date, style: DateFormatter.Style, showTime: Bool) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = showTime ? .short : .none
        formatter.locale = isSpanish ? Locale(identifier: "es_ES") : Locale(identifier: "en_US")
        print("🌐 Calendar formatDate - isSpanish: \(isSpanish), locale: \(formatter.locale.identifier), example: \(formatter.string(from: date))")
        return formatter.string(from: date)
    }
    
    // Event selection handler
    func eventSelected(_ event: CalendarEvent) {
        print("🔍 [CalendarView] Event selected: \(event.id) - \(event.title)")
        print("🔍 [CalendarView] Event details: startDate: \(event.startDate), endDate: \(event.endDate), location: \(event.location ?? "none")")
        print("🔍 [CalendarView] Event PDF: \(event.pdfRecord != nil ? "attached" : "none"), PDF URL: \(event.pdfURL?.lastPathComponent ?? "none")")
        selectedEvent = event
        showingEventDetail = true
        print("🔍 [CalendarView] showingEventDetail set to true, sheet should appear")
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
                        Button(action: {
                            print("🔄 [Calendar] Refresh button pressed")
                            DebugLogger.trackCalendarRefresh(action: "Refresh Button Pressed", context: "Calendar", refreshTrigger: refreshTrigger)
                            loadEvents()
                        }) {
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
                    
                    // Calendar content using vertical layout
                    VStack(spacing: 0) {
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
                    
                        // Events for selected date header
                    VStack(alignment: .leading) {
                        HStack {
                            Text(isSpanish ? "Eventos para \(formatDate(selectedDate, style: .medium, showTime: false))" : "Events for \(formatDate(selectedDate, style: .medium, showTime: false))")
                                .font(.headline)
                            
                            Spacer()
                            
                            if !selectedDateEvents.isEmpty {
                                Text("\(selectedDateEvents.count) \(isSpanish ? "evento\(selectedDateEvents.count == 1 ? "" : "s")" : "event\(selectedDateEvents.count == 1 ? "" : "s")")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        }
                        
                        // Events list or empty state
                        if selectedDateEvents.isEmpty {
                            // Empty state
                            Spacer()
                                HStack {
                                    Spacer()
                                    VStack(spacing: 12) {
                                        Image(systemName: "calendar.badge.clock")
                                        .font(.system(size: 60))
                                        .foregroundColor(.gray)
                                        Text(isSpanish ? "No hay eventos programados" : "No events scheduled")
                                        .font(.title2)
                                        .foregroundColor(.gray)
                                    }
                                    Spacer()
                                }
                            Spacer()
                        } else {
                            // Events list
                            ScrollView {
                                VStack(spacing: 8) {
                                    ForEach(selectedDateEvents) { event in
                                        EventListItemView(
                                            event: event,
                                            onTap: {
                                                eventSelected(event)
                                            },
                                            isSpanish: isSpanish
                                        )
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .frame(minHeight: 150, maxHeight: .infinity)
                        }
                    }
                    
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
            DebugLogger.trackCalendarRefresh(action: "onAppear", context: "Calendar", refreshTrigger: refreshTrigger)
            loadEvents()
        }
        .onChange(of: refreshTrigger) { newValue in
            DebugLogger.trackRefreshTrigger(source: "Calendar", oldValue: refreshTrigger, newValue: newValue)
            if newValue {
                DebugLogger.trackCalendarRefresh(action: "Triggered by refreshTrigger", context: "Calendar", refreshTrigger: newValue)
                loadEvents()
                refreshTrigger = false  // Reset the trigger after refreshing
                DebugLogger.trackRefreshTrigger(source: "Calendar", oldValue: true, newValue: false)
            }
        }
        .onChange(of: showingEventDetail) { isShowing in
            print("📅 [Calendar] Sheet presentation state changed: \(isShowing ? "showing" : "hidden")")
            if isShowing {
                print("📅 [Calendar] Presenting event detail for: \(selectedEvent?.title ?? "nil")")
                print("📅 [Calendar] Selected event ID: \(selectedEvent?.id ?? "nil")")
            }
        }
        .sheet(isPresented: $showingEventDetail, onDismiss: {
            print("📅 [Calendar] Event detail sheet dismissed")
        }) {
            Group {
                if let event = selectedEvent {
                    let _ = print("📅 [Calendar] Building EventDetailView for: \(event.title)")
                    EventDetailView(event: event, isSpanish: isSpanish, container: container)
                        .onAppear {
                            print("📅 [Calendar] EventDetailView appeared in sheet")
                        }
                } else {
                    let _ = print("❌ [Calendar] WARNING: Attempting to show sheet but selectedEvent is nil!")
                    Text("No event selected")
                        .font(.headline)
                        .foregroundColor(.red)
                        .padding()
                }
            }
        }
    }
    
    private func loadEvents() {
        isLoading = true
        errorMessage = nil
        
        // For debugging, track the start time
        let startTime = Date()
        DebugLogger.trackCalendarRefresh(action: "loadEvents Started", context: "Calendar", refreshTrigger: refreshTrigger)
        DebugLogger.log("Calendar: Starting query for active events (isArchived != 1)", category: .cloudKit, level: .info)
        
        // Query for non-archived events using the isArchived field from the schema
        let query = CKQuery(recordType: "CalendarEvent", predicate: NSPredicate(format: "isArchived != %@", NSNumber(value: 1)))
        query.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]
        
        DebugLogger.log("Calendar: Query details - recordType: CalendarEvent, predicate: isArchived != 1, sort: startDate (asc)", category: .cloudKit, level: .debug)
        
        database.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 100) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success(let matchResults):
                    let records = matchResults.matchResults.compactMap { (recordID, recordResult) -> CKRecord? in
                        if case .success(let record) = recordResult {
                            return record
                        } else if case .failure(let error) = recordResult {
                            DebugLogger.log("Calendar: Error retrieving record \(recordID.recordName): \(error.localizedDescription)", category: .cloudKit, level: .error)
                        }
                        return nil
                    }
                    
                    // Debug info
                    DebugLogger.log("Calendar: Found \(records.count) records in CloudKit", category: .cloudKit, level: .info)
                    
                    if !records.isEmpty {
                        self.events = records.map { CalendarEvent(record: $0) }
                        DebugLogger.trackEventLoad(module: "Calendar", eventCount: self.events.count, startTime: startTime)
                        self.updateSelectedDateEvents()
                        DebugLogger.log("Calendar: Selected date events: \(self.selectedDateEvents.count)", category: .views, level: .debug)
                        self.usingFallbackData = false
                    } else {
                        DebugLogger.log("Calendar: No event records found in CloudKit", category: .cloudKit, level: .info)
                        // Don't create fallback events
                        self.events = []
                        self.usingFallbackData = false
                    }
                    
                case .failure(let error):
                    DebugLogger.trackEventLoad(module: "Calendar", eventCount: nil, startTime: startTime, error: error)
                    
                    // Enhanced error logging
                    if let ckError = error as? CKError {
                        let errorCode = ckError.code
                        DebugLogger.log("Calendar: CloudKit error code: \(errorCode.rawValue) - \(errorCode)", category: .cloudKit, level: .error)
                        
                        // Get the underlying error if available
                        if let underlyingError = ckError.userInfo[NSUnderlyingErrorKey] as? Error {
                            DebugLogger.log("Calendar: Underlying error: \(underlyingError.localizedDescription)", category: .cloudKit, level: .error)
                        }
                        
                        var errorDetails = "Unknown error"
                        switch errorCode {
                        case .serverRecordChanged:
                            errorDetails = "Server record changed - The record was modified by another process"
                        case .networkFailure, .networkUnavailable:
                            errorDetails = "Network connectivity issue - Check internet connection and airplane mode"
                        case .serviceUnavailable:
                            errorDetails = "CloudKit service unavailable - Servers may be down or in maintenance"
                        case .notAuthenticated:
                            errorDetails = "Not authenticated - Check iCloud sign in and entitlements"
                        case .permissionFailure:
                            errorDetails = "Permission failure - Check app entitlements and user permissions"
                        case .unknownItem:
                            errorDetails = "Unknown item - The record zone or record does not exist"
                        case .invalidArguments:
                            errorDetails = "Invalid arguments - Check schema definition and query structure"
                            if let reason = ckError.userInfo[NSLocalizedFailureReasonErrorKey] as? String {
                                errorDetails += " - Reason: \(reason)"
                            }
                        case .incompatibleVersion:
                            errorDetails = "Incompatible schema version"
                        case .constraintViolation:
                            errorDetails = "Constraint violation - Schema validation failed"
                        case .badDatabase:
                            errorDetails = "Bad database - Error accessing database"
                        case .quotaExceeded:
                            errorDetails = "Quota exceeded - CloudKit storage quota reached"
                        case .zoneBusy:
                            errorDetails = "Zone busy - Try again later"
                        case .internalError:
                            errorDetails = "Internal error - CloudKit server error"
                        case .partialFailure:
                            errorDetails = "Partial failure - Some records failed"
                            if let partialErrors = ckError.userInfo[CKPartialErrorsByItemIDKey] as? [CKRecord.ID: Error] {
                                for (recordID, partialError) in partialErrors {
                                    DebugLogger.log("Calendar: Partial error for record \(recordID.recordName): \(partialError.localizedDescription)", category: .cloudKit, level: .error)
                                }
                            }
                        case .batchRequestFailed:
                            errorDetails = "Batch request failed"
                        case .assetFileNotFound:
                            errorDetails = "Asset file not found"
                        case .assetFileModified:
                            errorDetails = "Asset file was modified during transfer"
                        case .limitExceeded:
                            errorDetails = "Limit exceeded - Request too large"
                        case .referenceViolation:
                            errorDetails = "Reference violation - Invalid reference format or referenced record doesn't exist"
                        case .missingEntitlement:
                            errorDetails = "Missing entitlement - Check app's entitlements and capabilities"
                        case .changeTokenExpired:
                            errorDetails = "Change token expired - Fetch new change token and retry"
                        case .operationCancelled:
                            errorDetails = "Operation cancelled"
                        case .requestRateLimited:
                            errorDetails = "Request rate limited - Too many requests, try again later"
                        case .zoneNotFound:
                            errorDetails = "Zone not found - The record zone doesn't exist"
                        default:
                            errorDetails = "Other CloudKit error: \(errorCode)"
                        }
                        
                        DebugLogger.log("Calendar: CloudKit error details: \(errorDetails)", category: .cloudKit, level: .error)
                    } else {
                        DebugLogger.log("Calendar: Non-CloudKit error: \(error)", category: .cloudKit, level: .error)
                    }
                    
                    // Don't create fallback events or show error message
                    self.events = []
                    self.usingFallbackData = false
                    self.errorMessage = nil
                }
                
                // Log completion
                DebugLogger.trackCalendarRefresh(action: "loadEvents Completed", context: "Calendar", refreshTrigger: self.refreshTrigger)
            }
        }
    }
    
    private func createTestEvent() {
        DebugLogger.log("Creating fallback test events for demo purposes", category: .cloudKit, level: .info)
        
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
        
        // Create events from records
        let testEvent = CalendarEvent(record: testRecord)
        let events = [testEvent]
        
        self.events = events
        self.updateSelectedDateEvents()
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
                        Text(formatDate(event.startDate, style: .full, showTime: false))
                            .fontWeight(.medium)
                        
                        HStack {
                            Text(formatTime(event.startDate))
                            
                            Text(" - \(formatTime(event.endDate))")
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
                
                // For debugging, add event ID and record info
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Event ID: \(event.id)")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                        VStack {
                            CalendarPDFPreview(document: pdf)
                                .frame(width: 400, height: 400)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(8)
                                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                                .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity)
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
            print("📅 [EventDetailView] onAppear - Event: \(event.title) (ID: \(event.id))")
            print("📅 [EventDetailView] Event data - Start: \(event.startDate), End: \(event.endDate), Location: \(event.location ?? "none")")
            print("📅 [EventDetailView] Event attachments - PDF Record: \(event.pdfRecord != nil ? "present" : "none"), PDF URL: \(event.pdfURL?.lastPathComponent ?? "none"), PDF Reference: \(event.pdfReference != nil ? "present" : "none")")
            
            if event.pdfReference != nil {
                print("📅 [EventDetailView] Loading PDF attachment for event")
                loadLinkedPDF()
            }
            
            // Log when link is presented in detail view
            if let url = event.linkURL {
                print("📅 [EventDetailView] Event has link URL: \(url)")
                logLinkClicked(url: url, context: "Displayed in calendar event detail", file: #file, function: #function, line: #line)
            }
        }
    }
    
    private func loadLinkedPDF() {
        guard let reference = event.pdfReference else { return }
        isLoadingPDF = true
        
        DebugLogger.log("Calendar: Loading linked PDF for event \(event.id)", category: .pdf, level: .info)
        
        let database = container.publicCloudDatabase
        database.fetch(withRecordID: reference.recordID) { record, error in
            DispatchQueue.main.async {
                isLoadingPDF = false

                // Handle network / CloudKit error first
                if let error = error {
                    pdfError = isSpanish ?
                        "Error al cargar PDF: \(error.localizedDescription)" :
                        "Error loading PDF: \(error.localizedDescription)"
                    DebugLogger.log("Calendar: PDF loading failed: \(error.localizedDescription)", category: .pdf, level: .error)
                    return
                }

                guard let record = record else {
                    pdfError = isSpanish ? "No se pudo cargar el PDF" : "Could not load the PDF"
                    DebugLogger.log("Calendar: PDF loading failed – record was nil", category: .pdf, level: .error)
                    return
                }

                print("📄 [DEBUG] Fetched PDF record: \(record.recordID.recordName) – keys: \(record.allKeys())")

                // Accept either pdfFile or legacy pdfAsset
                let asset = (record["pdfFile"] as? CKAsset) ?? (record["pdfAsset"] as? CKAsset)

                guard let ckAsset = asset else {
                    pdfError = isSpanish ? "No se pudo cargar el PDF" : "Could not load the PDF"
                    DebugLogger.log("Calendar: No asset found under 'pdfFile' or 'pdfAsset'", category: .pdf, level: .error)
                    return
                }

                guard let fileURL = ckAsset.fileURL else {
                    pdfError = isSpanish ? "No se pudo cargar el PDF" : "Could not load the PDF"
                    DebugLogger.log("Calendar: CKAsset.fileURL was nil", category: .pdf, level: .error)
                    return
                }

                print("📄 [DEBUG] Asset fileURL: \(fileURL.path)")
                let fileExists = FileManager.default.fileExists(atPath: fileURL.path)
                print("📄 [DEBUG] Asset file exists on disk: \(fileExists)")
                if fileExists {
                    do {
                        let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                        if let size = attrs[.size] as? Int64 {
                            print("📄 [DEBUG] Asset file size: \(size) bytes")
                        }
                    } catch {
                        print("📄 [DEBUG] Could not read asset file attributes: \(error.localizedDescription)")
                    }
                }

                // Attempt to create PDFDocument
                var pdfDoc: PDFKit.PDFDocument? = PDFKit.PDFDocument(url: fileURL)
                if pdfDoc == nil {
                    print("⚠️ [DEBUG] PDFDocument(url:) failed; trying Data-based init…")
                    do {
                        let data = try Data(contentsOf: fileURL)
                        pdfDoc = PDFKit.PDFDocument(data: data)
                        print("📄 [DEBUG] Data-based init result: \(pdfDoc != nil ? "success" : "failure") – bytes read: \(data.count)")
                    } catch {
                        print("❌ [DEBUG] Reading data from asset file failed: \(error.localizedDescription)")
                    }
                }

                if let document = pdfDoc {
                    linkedPDF = document
                    DebugLogger.log("Calendar: PDF loaded successfully, pages: \(document.pageCount)", category: .pdf, level: .info)
                } else {
                    pdfError = isSpanish ? "No se pudo cargar el PDF" : "Could not load the PDF"
                    DebugLogger.log("Calendar: PDFDocument initialization failed after fallback", category: .pdf, level: .error)
                }
            }
        }
    }
    
    private func formatDate(_ date: Date, style: DateFormatter.Style, showTime: Bool) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = showTime ? .short : .none
        formatter.locale = isSpanish ? Locale(identifier: "es_ES") : Locale(identifier: "en_US")
        print("🌐 EventDetailView formatDate - isSpanish: \(isSpanish), locale: \(formatter.locale.identifier), example: \(formatter.string(from: date))")
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.locale = isSpanish ? Locale(identifier: "es_ES") : Locale(identifier: "en_US")
        print("🌐 EventDetailView formatTime - isSpanish: \(isSpanish), locale: \(formatter.locale.identifier), example: \(formatter.string(from: date))")
        return formatter.string(from: date)
    }
}

// Calendar-specific PDF Preview to avoid name conflicts
struct CalendarPDFPreview: NSViewRepresentable {
    let document: PDFKit.PDFDocument
    
    // Required methods for NSViewRepresentable
    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = document
        view.autoScales = true
        view.displayMode = .singlePage
        view.displayDirection = .vertical
        view.backgroundColor = NSColor.clear
        view.displayBox = .cropBox
        
        return view
    }
    
    func updateNSView(_ nsView: PDFView, context: Context) {
        if nsView.document !== document {
            nsView.document = document
        }
    }
    
    // Explicitly define typealias to avoid ambiguity
    typealias NSViewType = PDFView
    typealias Context = NSViewRepresentableContext<CalendarPDFPreview>
}

// Helper view to simplify the event list item
struct EventListItemView: View {
    let event: CalendarEvent
    let onTap: () -> Void
    let isSpanish: Bool
    
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
                    Text(formatTime(event.startDate))
                    Text("–")
                    Text(formatTime(event.endDate))
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
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.locale = isSpanish ? Locale(identifier: "es_ES") : Locale(identifier: "en_US")
        print("🌐 EventListItemView formatTime - isSpanish: \(isSpanish), locale: \(formatter.locale.identifier), example: \(formatter.string(from: date))")
        return formatter.string(from: date)
    }
}

struct CalendarView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarView(isSpanish: .constant(false), refreshTrigger: .constant(false))
    }
}
