import Foundation

// MARK: - Notification Names
extension Notification.Name {
    // News Feed notifications
    static let postArchived = Notification.Name("ArchivedNewsPostNotification")
    static let postUnarchived = Notification.Name("NewsFeedUnarchivePostNotification")
    static let newsFeedRefresh = Notification.Name("NewsFeedRefreshNotification")
    
    // General app notifications
    static let languageChanged = Notification.Name("LanguageChangedNotification")
    static let appMemoryWarning = Notification.Name("AppMemoryWarningNotification")
} 