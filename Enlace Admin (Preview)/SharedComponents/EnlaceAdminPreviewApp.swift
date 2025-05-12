//
//  EnlaceAdminPreviewApp.swift
//  Enlace Admin (Preview)
//
//  Created by Steven Mancilla on 2/5/25.
//

import SwiftUI
import CloudKit

// MARK: - SwiftUI Debug Flags Controller
// A simplified class to handle all debug management
final class DebugController {
    static let shared = DebugController()
    
    private init() {
        disableDebugOverlays()
    }
    
    func disableDebugOverlays() {
        // Environment variables approach
        setenv("SWIFTUI_DISABLE_DEBUG_OVERLAYS", "1", 1)
        setenv("SWIFT_DISABLE_DIAGNOSE", "1", 1)
        setenv("SWIFT_DISABLE_INCREMENTAL_STABLE_DEBUG", "1", 1)
        
        // User defaults approach
        UserDefaults.standard.set(false, forKey: "DEBUGGING_VIEW_ONLY")
        UserDefaults.standard.set(false, forKey: "DEBUG_MODE_ENABLED")
        UserDefaults.standard.set(false, forKey: "SHOW_DEBUG_OVERLAY")
        UserDefaults.standard.set(false, forKey: "com.apple.SwiftUI.ShowDebugStatistics")
        
        #if DEBUG
        print("🛠 Debug overlay prevention applied")
        #endif
    }
}

// Pre-main initialization function
@_cdecl("__SwiftUIDisableDebugging")
func disableDebugging() {
    DebugController.shared.disableDebugOverlays()
}

// Environment key definitions
private struct IsPreviewModeKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

private struct IsPreviewingKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

// Environment values extension
extension EnvironmentValues {
    var _isPreviewMode: Bool {
        get { self[IsPreviewModeKey.self] }
        set { self[IsPreviewModeKey.self] = newValue }
    }
    
    var _isPreviewing: Bool {
        get { self[IsPreviewingKey.self] }
        set { self[IsPreviewingKey.self] = newValue }
    }
}

@main
struct EnlaceAdminPreviewApp: App {
    @StateObject private var consentManager = ConsentManager()
    @StateObject private var languageManager = LanguageManager()
    
    init() {
        DebugController.shared.disableDebugOverlays()
        disableDebugging()
        setupPerformanceMonitoring()
        print("✅ Debug overlays and debug UI removed")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
                .environmentObject(consentManager)
                .environmentObject(languageManager)
                .preferredColorScheme(.light)
                .environment(\._isPreviewMode, false)
                .environment(\._isPreviewing, false)
                .onAppear {
                    DebugController.shared.disableDebugOverlays()
                    
                    // Add CloudKit environment debugging
                    let container = CKContainer(identifier: "iCloud.PearInc.EICT-iOS-16")
                    print("🛠️ [DEBUG] CKContainer: \(container.containerIdentifier ?? "unknown")")
                    #if DEBUG
                    print("🛠️ [DEBUG] CloudKit Environment: DEVELOPMENT")
                    #else
                    print("🛠️ [DEBUG] CloudKit Environment: PRODUCTION")
                    #endif
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
    
    // Simple performance monitoring setup
    private func setupPerformanceMonitoring() {
        #if DEBUG
        print("📱 Enlace Admin (Preview) starting up")
        print("📊 System: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        print("📊 Memory: \(ProcessInfo.processInfo.physicalMemory / (1024 * 1024)) MB available")
        
        // Setup memory cleanup notification
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            URLCache.shared.removeAllCachedResponses()
            print("🧹 Memory cleanup performed")
        }
        #endif
    }
} 