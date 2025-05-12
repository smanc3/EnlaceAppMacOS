//
//  ContentView.swift
//  Enlace Admin (Preview)
//
//  Created by Steven Mancilla on 2/5/25.
//
import SwiftUI

// Custom SidebarButton component with consistent icon alignment
struct SidebarButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 10) {
                // Fixed-width container for icon to ensure consistent alignment
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .regular))
                    .frame(width: 24, height: 24, alignment: .center)
                    .alignmentGuide(.firstTextBaseline) { d in d[.firstTextBaseline] }
                Text(title)
                    .font(.system(size: 15, weight: .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
                    .alignmentGuide(.firstTextBaseline) { d in d[.firstTextBaseline] }
                Spacer(minLength: 0)
            }
            .frame(height: 36)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .foregroundColor(isSelected ? .white : .primary)
        .background(isSelected ? Color.blue.opacity(0.7) : Color.clear)
        .cornerRadius(6)
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
    }
}

// Standard sizes for popups - defined outside of generic type
fileprivate struct PopupSizes {
    static let standard = CGSize(width: 800, height: 650)
    static let minimum = CGSize(width: 400, height: 300)
    static let maximum = CGSize(width: 1200, height: 800)
}

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
    
    init(isPresented: Binding<Bool>, initialSize: CGSize? = nil, 
         minSize: CGSize = PopupSizes.minimum, 
         maxSize: CGSize = PopupSizes.maximum,
         @ViewBuilder content: () -> Content) {
        self._isPresented = isPresented
        self.content = content()
        
        // Use the standard size unless a specific size is requested
        let sizeToUse = initialSize ?? PopupSizes.standard
        self._size = State(initialValue: sizeToUse)
        self._currentSize = State(initialValue: sizeToUse)
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
        case fixNewsDate  // New popup for news date fixer
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
    
    private var showPopupFixNewsDate: Bool {
        get { activePopup == .fixNewsDate }
        set { activePopup = newValue ? .fixNewsDate : .none }
    }
    
    @AppStorage("isSpanish") private var isSpanish = false  // Use AppStorage for language state
    
    // Keep calendar as the main view
    @State private var calendarNeedsRefresh: Bool = false {
        didSet {
            DebugLogger.trackRefreshTrigger(source: "ContentView", oldValue: oldValue, newValue: calendarNeedsRefresh)
            DebugLogger.log("ContentView calendarNeedsRefresh changed from \(oldValue) to \(calendarNeedsRefresh)", category: .refresh, level: .info)
        }
    }
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
                    
                    SidebarButton(
                        title: isSpanish ? "Publicar en Noticias" : "Post to News Feed",
                        icon: "doc.badge.plus",
                        isSelected: showPopupPostNews,
                        action: { activePopup = .postNews }
                    )
                    
                    SidebarButton(
                        title: isSpanish ? "Gestionar Noticias" : "Manage News Feed",
                        icon: "newspaper",
                        isSelected: showPopupViewNews,
                        action: { activePopup = .viewNews }
                    )
                    
                    SidebarButton(
                        title: isSpanish ? "Ver Noticias Archivadas" : "View Archived News",
                        icon: "archivebox",
                        isSelected: showPopupArchivedNews,
                        action: { activePopup = .archivedNews }
                    )
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
                    
                    SidebarButton(
                        title: isSpanish ? "Crear Evento" : "Create Event",
                        icon: "calendar.badge.plus",
                        isSelected: showPopupCreate,
                        action: { activePopup = .create }
                    )
                    
                    SidebarButton(
                        title: isSpanish ? "Gestionar Eventos" : "Manage Events",
                        icon: "pencil.and.list.clipboard",
                        isSelected: showPopupManageEvents,
                        action: { activePopup = .manageEvents }
                    )
                    
                    SidebarButton(
                        title: isSpanish ? "Ver Eventos Archivados" : "View Archived Events",
                        icon: "archivebox",
                        isSelected: showPopupArchivedEvents,
                        action: { activePopup = .archivedEvents }
                    )
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                .cornerRadius(10)
                
                // Settings Section
                SidebarButton(
                    title: isSpanish ? "Configuración" : "Settings",
                    icon: "gear",
                    isSelected: showPopupSettings,
                    action: { activePopup = .settings }
                )
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
                    )) {
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
                    )) {
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
                    )) {
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
                    )) { // Adjust size as needed
                        SettingsView()
                            .environmentObject(consentManager) // Pass ConsentManager
                    }
                } else if activePopup == .postNews {
                    ResizablePopupView(isPresented: Binding<Bool>(
                        get: { activePopup == .postNews },
                        set: { if !$0 { activePopup = .none } }
                    )) {
                        NewsFeedPopupView(onDismiss: {
                            activePopup = .none
                        })
                    }
                } else if activePopup == .viewNews {
                    // Use resizable popup for all news management functions
                    ResizablePopupView(isPresented: Binding<Bool>(
                        get: { activePopup == .viewNews },
                        set: { if !$0 { activePopup = .none } }
                    )) {
                        NewsFeedManagementView(isSpanish: $isSpanish)
                    }
                } else if activePopup == .editNews || activePopup == .archiveNews || activePopup == .deleteNews {
                    // Use resizable popup for all news management functions
                    ResizablePopupView(isPresented: Binding<Bool>(
                        get: { activePopup == .editNews || activePopup == .archiveNews || activePopup == .deleteNews },
                        set: { if !$0 { activePopup = .none } }
                    )) {
                        NewsFeedManagementView(isSpanish: $isSpanish)
                    }
                } else if activePopup == .editEvent {
                    ResizablePopupView(isPresented: Binding<Bool>(
                        get: { activePopup == .editEvent },
                        set: { if !$0 { activePopup = .none } }
                    )) {
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
                    )) {
                        ArchivedNewsView(isSpanish: $isSpanish, refreshTrigger: $archivedNewsNeedsRefresh)
                    }
                } else if activePopup == .manageEvents {
                    // Show event management view
                    ResizablePopupView(isPresented: Binding<Bool>(
                        get: { activePopup == .manageEvents },
                        set: { if !$0 { activePopup = .none } }
                    )) {
                        EventManagementView(isSpanish: $isSpanish, refreshTrigger: $calendarNeedsRefresh)
                    }
                } else if activePopup == .archivedEvents {
                    // Show archived events view
                    ResizablePopupView(isPresented: Binding<Bool>(
                        get: { activePopup == .archivedEvents },
                        set: { if !$0 { activePopup = .none } }
                    )) {
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

