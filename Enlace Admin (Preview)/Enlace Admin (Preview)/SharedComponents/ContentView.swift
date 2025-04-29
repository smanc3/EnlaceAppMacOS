//
//  ContentView.swift
//  Enlace Admin (Preview)
//
//  Created by Steven Mancilla on 2/5/25.
//
import SwiftUI

// New resizable popup container view
struct ResizablePopupView<Content: View>: View {
    @Binding var isPresented: Bool
    let content: Content
    @State private var size: CGSize
    let minSize: CGSize
    let maxSize: CGSize
    @State private var dragOffset: CGSize = .zero
    @State private var previousDragOffset: CGSize = .zero
    @State private var currentSize: CGSize
    
    init(isPresented: Binding<Bool>, initialSize: CGSize = CGSize(width: 650, height: 550), 
         minSize: CGSize = CGSize(width: 400, height: 300), 
         maxSize: CGSize = CGSize(width: 900, height: 700),
         @ViewBuilder content: () -> Content) {
        self._isPresented = isPresented
        self.content = content()
        self._size = State(initialValue: initialSize)
        self._currentSize = State(initialValue: initialSize)
        self.minSize = minSize
        self.maxSize = maxSize
    }
    
    var body: some View {
        ZStack {
            // Semi-transparent dimmed background that covers the entire screen
            // but allows the calendar to be visible underneath
            Rectangle()
                .fill(Color.black.opacity(0.3))
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    isPresented = false
                }
                .zIndex(1)
            
            // Popup content with resize handles
            ZStack {
                // Background for the popup - semi-transparent to allow calendar visibility
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.windowBackgroundColor).opacity(0.95))
                    .shadow(radius: 10)
                
                // Content view - wrapped with a clear color background to override any existing backgrounds
                content
                    .padding()
                    .background(Color.clear) // Ensure content has transparent background
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped() // Prevent content from overflowing
            }
            .frame(width: currentSize.width, height: currentSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 12)) // Clip any overflowing content
            .overlay(
                // Bottom right resize handle
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                }
                .offset(x: currentSize.width/2 - 18, y: currentSize.height/2 - 18)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let newWidth = size.width + value.translation.width - previousDragOffset.width
                            let newHeight = size.height + value.translation.height - previousDragOffset.height
                            
                            // Constrain to min/max size
                            currentSize.width = min(max(newWidth, minSize.width), maxSize.width)
                            currentSize.height = min(max(newHeight, minSize.height), maxSize.height)
                            
                            dragOffset = value.translation
                        }
                        .onEnded { value in
                            size = currentSize
                            previousDragOffset = .zero
                            dragOffset = .zero
                        }
                )
            )
            .zIndex(2)
        }
        .transition(.opacity)
    }
}

struct ContentView: View {
    // Define an enum to represent which popup is currently visible
    enum ActivePopup {
        case none
        case create
        case delete
        case archive
        case settings
        case postNews
        case viewNews
        case editNews
        case archiveNews
        case deleteNews
        case editEvent
        case archivedNews
        case manageEvents
        case archivedEvents
    }
    
    // Use a single property to track which popup is active
    @State private var activePopup: ActivePopup = .none
    
    // Use ConsentManager for state
    @StateObject private var consentManager = ConsentManager()
    
    // Computed properties to bind to each popup visibility
    private var showPopupCreate: Bool {
        get { activePopup == .create }
        set { activePopup = newValue ? .create : .none }
    }
    
    private var showPopupDelete: Bool {
        get { activePopup == .delete }
        set { activePopup = newValue ? .delete : .none }
    }
    
    private var showPopupArchive: Bool {
        get { activePopup == .archive }
        set { activePopup = newValue ? .archive : .none }
    }
    
    private var showPopupSettings: Bool {
        get { activePopup == .settings }
        set { activePopup = newValue ? .settings : .none }
    }
    
    private var showPopupPostNews: Bool {
        get { activePopup == .postNews }
        set { activePopup = newValue ? .postNews : .none }
    }
    
    private var showPopupViewNews: Bool {
        get { activePopup == .viewNews }
        set { activePopup = newValue ? .viewNews : .none }
    }
    
    private var showPopupEditNews: Bool {
        get { activePopup == .editNews }
        set { activePopup = newValue ? .editNews : .none }
    }
    
    private var showPopupArchiveNews: Bool {
        get { activePopup == .archiveNews }
        set { activePopup = newValue ? .archiveNews : .none }
    }
    
    private var showPopupDeleteNews: Bool {
        get { activePopup == .deleteNews }
        set { activePopup = newValue ? .deleteNews : .none }
    }
    
    private var showPopupEditEvent: Bool {
        get { activePopup == .editEvent }
        set { activePopup = newValue ? .editEvent : .none }
    }
    
    private var showPopupArchivedNews: Bool {
        get { activePopup == .archivedNews }
        set { activePopup = newValue ? .archivedNews : .none }
    }
    
    private var showPopupManageEvents: Bool {
        get { activePopup == .manageEvents }
        set { activePopup = newValue ? .manageEvents : .none }
    }
    
    private var showPopupArchivedEvents: Bool {
        get { activePopup == .archivedEvents }
        set { activePopup = newValue ? .archivedEvents : .none }
    }
    
    @AppStorage("isSpanish") private var isSpanish = false  // Use AppStorage for language state
    
    // Keep calendar as the main view
    @State private var calendarNeedsRefresh: Bool = false
    @State private var archivedNewsNeedsRefresh: Bool = false

    var body: some View {
        // Check if it's first launch or if consents are not granted
        if consentManager.isFirstLaunch || !consentManager.hasRequiredConsents() {
            // Show OnboardingView modally if consents are not granted
            OnboardingView()
                .environmentObject(consentManager) // Pass manager down
        } else {
            // Show main content if consents are granted
            mainContentView
                .environmentObject(consentManager) // Pass manager down
        }
    }
    
    // Extracted main content view
    private var mainContentView: some View {
        HStack(spacing: 0) {
            // Left sidebar with fixed width
            VStack(alignment: .leading) {
                Spacer()
                
                // News Feed Section - Visually distinct
                VStack(alignment: .leading, spacing: 5) {
                    Text(isSpanish ? "Gestión de Noticias" : "News Management")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 5)
                    
                    Button(isSpanish ? "Publicar en Noticias" : "Post to News Feed", systemImage: "doc.badge.plus") {
                        activePopup = .postNews
                    }
                    .foregroundColor(showPopupPostNews ? .white : .blue)
                    .background(showPopupPostNews ? Color.blue.opacity(0.7) : Color.clear)
                    .cornerRadius(6)
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    
                    Button(isSpanish ? "Gestionar Noticias" : "Manage News Feed", systemImage: "newspaper") {
                        activePopup = .viewNews
                    }
                    .foregroundColor(showPopupViewNews ? .white : .blue)
                    .background(showPopupViewNews ? Color.blue.opacity(0.7) : Color.clear)
                    .cornerRadius(6)
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    
                    Button(isSpanish ? "Ver Noticias Archivadas" : "View Archived News", systemImage: "archivebox") {
                        activePopup = .archivedNews
                    }
                    .foregroundColor(showPopupArchivedNews ? .white : .blue)
                    .background(showPopupArchivedNews ? Color.blue.opacity(0.7) : Color.clear)
                    .cornerRadius(6)
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                .cornerRadius(10)
                .padding(.bottom, 20)
                
                // Event Management Section - Grouped together
                VStack(alignment: .leading, spacing: 5) {
                    Text(isSpanish ? "Gestión de Eventos" : "Event Management")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 5)
                    
                    Button(isSpanish ? "Crear Evento" : "Create Event", systemImage: "calendar.badge.plus") {
                        activePopup = .create
                    }
                    .foregroundColor(showPopupCreate ? .white : .primary)
                    .background(showPopupCreate ? Color.blue.opacity(0.7) : Color.clear)
                    .cornerRadius(6)
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    
                    Button(isSpanish ? "Gestionar Eventos" : "Manage Events", systemImage: "pencil.and.list.clipboard") {
                        activePopup = .manageEvents
                    }
                    .foregroundColor(showPopupManageEvents ? .white : .primary)
                    .background(showPopupManageEvents ? Color.blue.opacity(0.7) : Color.clear)
                    .cornerRadius(6)
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    
                    Button(isSpanish ? "Ver Eventos Archivados" : "View Archived Events", systemImage: "archivebox") {
                        activePopup = .archivedEvents
                    }
                    .foregroundColor(showPopupArchivedEvents ? .white : .primary)
                    .background(showPopupArchivedEvents ? Color.blue.opacity(0.7) : Color.clear)
                    .cornerRadius(6)
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                .cornerRadius(10)
                
                Spacer()
                
                // Settings at the bottom
                Button(isSpanish ? "Configuración" : "Settings", systemImage: "gear") {
                    activePopup = .settings
                }
                .foregroundColor(showPopupSettings ? .white : .primary)
                .background(showPopupSettings ? Color.blue.opacity(0.7) : Color.clear)
                .cornerRadius(6)
                .buttonStyle(.plain)
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .padding(.top, 20)
                
                Spacer()
            }
            .padding()
            .frame(width: 250) // Fixed width for the sidebar
            .background(Color(NSColor.windowBackgroundColor))
            
            // Main content area with calendar
            ZStack {
                // Calendar view always visible as the base layer
                CalendarView(isSpanish: $isSpanish, refreshTrigger: $calendarNeedsRefresh)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // All popups now appear over the calendar using the resizable container
                if activePopup == .create {
                    ResizablePopupView(isPresented: Binding<Bool>(
                        get: { activePopup == .create },
                        set: { if !$0 { activePopup = .none } }
                    ), initialSize: CGSize(width: 650, height: 550)) {
                        PopupView(
                            showPopupCreate: Binding<Bool>(
                                get: { activePopup == .create },
                                set: { if !$0 { activePopup = .none } }
                            ),
                            isSpanish: $isSpanish,
                            onEventCreated: {
                                calendarNeedsRefresh = true
                            }
                        )
                    }
                } else if activePopup == .delete {
                    ResizablePopupView(isPresented: Binding<Bool>(
                        get: { activePopup == .delete },
                        set: { if !$0 { activePopup = .none } }
                    ), initialSize: CGSize(width: 650, height: 550)) {
                        PopupView2(
                            showPopupDelete: Binding<Bool>(
                                get: { activePopup == .delete },
                                set: { if !$0 { activePopup = .none } }
                            ),
                            isSpanish: $isSpanish
                        )
                    }
                } else if activePopup == .archive {
                    ResizablePopupView(isPresented: Binding<Bool>(
                        get: { activePopup == .archive },
                        set: { if !$0 { activePopup = .none } }
                    ), initialSize: CGSize(width: 650, height: 550)) {
                        PopupView3(
                            showPopupArchive: Binding<Bool>(
                                get: { activePopup == .archive },
                                set: { if !$0 { activePopup = .none } }
                            ),
                            isSpanish: $isSpanish,
                            onEventArchived: {
                                calendarNeedsRefresh = true
                            }
                        )
                    }
                } else if activePopup == .settings {
                    // Present the NEW SettingsView using ResizablePopupView
                    ResizablePopupView(isPresented: Binding<Bool>(
                        get: { activePopup == .settings },
                        set: { if !$0 { activePopup = .none } }
                    ), initialSize: CGSize(width: 600, height: 650)) { // Adjust size as needed
                        SettingsView()
                            .environmentObject(consentManager) // Pass ConsentManager
                    }
                } else if activePopup == .postNews {
                    ResizablePopupView(isPresented: Binding<Bool>(
                        get: { activePopup == .postNews },
                        set: { if !$0 { activePopup = .none } }
                    ), initialSize: CGSize(width: 650, height: 550)) {
                        NewsFeedPopupView(onDismiss: {
                            activePopup = .none
                        })
                    }
                } else if activePopup == .viewNews {
                    // Use resizable popup for all news management functions
                    ResizablePopupView(isPresented: Binding<Bool>(
                        get: { activePopup == .viewNews },
                        set: { if !$0 { activePopup = .none } }
                    ), initialSize: CGSize(width: 700, height: 600)) {
                        NewsFeedManagementView(isSpanish: $isSpanish)
                    }
                } else if activePopup == .editNews || activePopup == .archiveNews || activePopup == .deleteNews {
                    // Use resizable popup for all news management functions
                    ResizablePopupView(isPresented: Binding<Bool>(
                        get: { activePopup == .editNews || activePopup == .archiveNews || activePopup == .deleteNews },
                        set: { if !$0 { activePopup = .none } }
                    ), initialSize: CGSize(width: 650, height: 550)) {
                        NewsFeedManagementView(isSpanish: $isSpanish)
                    }
                } else if activePopup == .editEvent {
                    ResizablePopupView(isPresented: Binding<Bool>(
                        get: { activePopup == .editEvent },
                        set: { if !$0 { activePopup = .none } }
                    ), initialSize: CGSize(width: 650, height: 550)) {
                        PopupView(
                            showPopupCreate: Binding<Bool>(
                                get: { activePopup == .editEvent },
                                set: { if !$0 { activePopup = .none } }
                            ),
                            isSpanish: $isSpanish,
                            onEventCreated: {
                                calendarNeedsRefresh = true
                            },
                            isEditMode: true
                        )
                    }
                } else if activePopup == .archivedNews {
                    // Show archived news view
                    ResizablePopupView(isPresented: Binding<Bool>(
                        get: { activePopup == .archivedNews },
                        set: { if !$0 { activePopup = .none } }
                    ), initialSize: CGSize(width: 700, height: 600)) {
                        ArchivedNewsView(isSpanish: $isSpanish, refreshTrigger: $archivedNewsNeedsRefresh)
                    }
                } else if activePopup == .manageEvents {
                    // Show event management view
                    ResizablePopupView(isPresented: Binding<Bool>(
                        get: { activePopup == .manageEvents },
                        set: { if !$0 { activePopup = .none } }
                    ), initialSize: CGSize(width: 800, height: 650)) {
                        EventManagementView(isSpanish: $isSpanish, refreshTrigger: $calendarNeedsRefresh)
                    }
                } else if activePopup == .archivedEvents {
                    // Show archived events view
                    ResizablePopupView(isPresented: Binding<Bool>(
                        get: { activePopup == .archivedEvents },
                        set: { if !$0 { activePopup = .none } }
                    ), initialSize: CGSize(width: 800, height: 650)) {
                        ArchivedEventsView(isSpanish: $isSpanish, refreshTrigger: $calendarNeedsRefresh)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
        }
    }
}

#Preview {
    ContentView()
}

