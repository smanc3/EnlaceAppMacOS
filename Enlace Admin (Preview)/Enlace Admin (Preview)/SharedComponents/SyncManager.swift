import Foundation
import CloudKit
import SwiftUI

class SyncManager: ObservableObject {
    static let shared = SyncManager()
    
    @Published var lastSyncDate: Date?
    @Published var isSyncing = false
    @Published var syncError: Error?
    @Published var syncProgress: Double = 0
    
    private let container = CKContainer.default()
    private let database = CKContainer.default().privateCloudDatabase
    
    private init() {
        logInfo("SyncManager initialized")
        setupSyncNotifications()
    }
    
    private func setupSyncNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloudKitNotification(_:)),
            name: .CKAccountChanged,
            object: nil
        )
    }
    
    @objc private func handleCloudKitNotification(_ notification: Notification) {
        logInfo("Received CloudKit account change notification")
        Task {
            await checkCloudKitStatus()
        }
    }
    
    func checkCloudKitStatus() async {
        logInfo("Checking CloudKit account status")
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                logInfo("CloudKit account is available")
                await performSync()
            case .noAccount:
                logError("No iCloud account available")
                syncError = NSError(domain: "SyncError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No iCloud account available"])
            case .restricted:
                logError("CloudKit account is restricted")
                syncError = NSError(domain: "SyncError", code: 2, userInfo: [NSLocalizedDescriptionKey: "CloudKit account is restricted"])
            case .couldNotDetermine:
                logError("Could not determine CloudKit account status")
                syncError = NSError(domain: "SyncError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not determine CloudKit account status"])
            case .temporarilyUnavailable:
                logError("CloudKit account is temporarily unavailable")
                syncError = NSError(domain: "SyncError", code: 5, userInfo: [NSLocalizedDescriptionKey: "CloudKit account is temporarily unavailable"])
            @unknown default:
                logError("Unknown CloudKit account status")
                syncError = NSError(domain: "SyncError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unknown CloudKit account status"])
            }
        } catch {
            logError("Error checking CloudKit status: \(error.localizedDescription)")
            syncError = error
        }
    }
    
    func performSync() async {
        guard !isSyncing else {
            logWarning("Sync already in progress")
            return
        }
        
        logInfo("Starting sync operation")
        isSyncing = true
        syncError = nil
        syncProgress = 0
        
        do {
            // Sync calendar events
            syncProgress = 0.2
            try await syncCalendarEvents()
            
            // Sync news feed
            syncProgress = 0.4
            try await syncNewsFeed()
            
            // Sync archived events
            syncProgress = 0.6
            try await syncArchivedEvents()
            
            // Sync settings
            syncProgress = 0.8
            try await syncSettings()
            
            // Update last sync date
            syncProgress = 1.0
            lastSyncDate = Date()
            logInfo("Sync completed successfully")
        } catch {
            logError("Sync failed: \(error.localizedDescription)")
            syncError = error
        }
        
        isSyncing = false
    }
    
    private func syncCalendarEvents() async throws {
        logInfo("Syncing calendar events")
        // Implement calendar event synchronization
    }
    
    private func syncNewsFeed() async throws {
        logInfo("Syncing news feed")
        // Implement news feed synchronization
    }
    
    private func syncArchivedEvents() async throws {
        logInfo("Syncing archived events")
        // Implement archived events synchronization
    }
    
    private func syncSettings() async throws {
        logInfo("Syncing settings")
        // Implement settings synchronization
    }
    
    func forceSync() async {
        logInfo("Forcing sync operation")
        await performSync()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
} 