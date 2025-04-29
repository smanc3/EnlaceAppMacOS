import Foundation
import os.log
import CloudKit
import AppKit

/// A utility class for enhanced debugging across the application
class DebugLogger {
    /// Subsystem categories for organizing logs
    enum Category: String, CaseIterable {
        case models = "Models"
        case views = "Views"
        case cloudKit = "CloudKit"
        case pdf = "PDF"
        case general = "General"
        case archive = "Archive"
        case calendar = "Calendar"
        case newsFeed = "NewsFeed"
        case privacy = "Privacy"
        case network = "Network"
        case performance = "Performance"
        case symbolValidation = "Symbols"
        case cloudKitQuery = "CloudKitQuery"
        case fallbackMethods = "Fallbacks"
        case ui = "UI"
        case data = "Data"
        case sync = "Sync"
        case database = "Database"
        case linkManager = "LinkManager"
    }
    
    /// Log levels for different types of information
    enum Level: String {
        case info = "ℹ️"
        case debug = "🔍"
        case warning = "⚠️"
        case error = "❌"
        case critical = "🚨"
    }
    
    /// The app's main bundle identifier
    private static let bundleID = Bundle.main.bundleIdentifier ?? "com.enlace.admin"
    
    /// OS Logger instances for different categories
    private static let loggers: [Category: OSLog] = {
        var loggers: [Category: OSLog] = [:]
        for category in Category.allCases {
            loggers[category] = OSLog(subsystem: bundleID, category: category.rawValue)
        }
        return loggers
    }()
    
    /// Log a message with the specified category and level
    static func log(
        _ message: String,
        category: Category = .general,
        level: Level = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let prefix = "\(level.rawValue) [\(fileName):\(line)] \(function)"
        let formattedMessage = "\(prefix) - \(message)"
        
        guard let logger = loggers[category] else { return }
        
        switch level {
        case .info:
            os_log("%{public}@", log: logger, type: .info, formattedMessage)
        case .debug:
            os_log("%{public}@", log: logger, type: .debug, formattedMessage)
        case .warning:
            os_log("%{public}@", log: logger, type: .default, formattedMessage)
        case .error:
            os_log("%{public}@", log: logger, type: .error, formattedMessage)
        case .critical:
            os_log("%{public}@", log: logger, type: .fault, formattedMessage)
        }
        
        // Also print to console for easier debugging during development
        print(formattedMessage)
    }
    
    /// Measure execution time of a block of code
    static func measure<T>(_ operation: String, file: String = #file, function: String = #function, line: Int = #line, block: () throws -> T) rethrows -> T {
        let startTime = Date()
        let result = try block()
        let duration = Date().timeIntervalSince(startTime)
        
        log("\(operation) took \(String(format: "%.3f", duration))s", category: .performance, level: .debug, file: file, function: function, line: line)
        return result
    }
    
    /// Log UI state changes
    static func logUIState(_ viewName: String, state: String, file: String = #file, function: String = #function, line: Int = #line) {
        log("\(viewName) state changed to: \(state)", category: .ui, level: .debug, file: file, function: function, line: line)
    }
    
    /// Log data operations
    static func logDataOperation(_ operation: String, entity: String, success: Bool, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        let status = success ? "succeeded" : "failed"
        var message = "\(operation) operation for \(entity) \(status)"
        
        if let error = error {
            message += ": \(error.localizedDescription)"
            log(message, category: .data, level: .error, file: file, function: function, line: line)
        } else {
            log(message, category: .data, level: .info, file: file, function: function, line: line)
        }
    }
    
    /// Log synchronization events
    static func logSyncEvent(_ event: String, source: String, target: String, success: Bool, file: String = #file, function: String = #function, line: Int = #line) {
        let status = success ? "succeeded" : "failed"
        log("Sync \(event) from \(source) to \(target) \(status)", category: .sync, level: success ? .info : .error, file: file, function: function, line: line)
    }
    
    /// Log memory usage
    static func logMemoryUsage(file: String = #file, function: String = #function, line: Int = #line) {
        let memory = ProcessInfo.processInfo.physicalMemory / 1_073_741_824 // Convert to GB
        log("Memory usage: \(String(format: "%.2f", memory))GB", category: .performance, level: .debug, file: file, function: function, line: line)
    }
    
    /// Log CloudKit account status
    static func logCloudKitAccountStatus(file: String = #file, function: String = #function, line: Int = #line) {
        CKContainer.default().accountStatus { status, error in
            DispatchQueue.main.async {
                let statusMessage = "CloudKit account status: \(status.rawValue)"
                if let error = error {
                    log("\(statusMessage) (Error: \(error.localizedDescription))", category: .cloudKit, level: .error, file: file, function: function, line: line)
                } else {
                    log(statusMessage, category: .cloudKit, level: .info, file: file, function: function, line: line)
                }
            }
        }
    }
}

// MARK: - Convenience global functions for logging

/// Log general information
func logInfo(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    DebugLogger.log(message, level: .info, file: file, function: function, line: line)
}

/// Log debug information
func logDebug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    DebugLogger.log(message, level: .debug, file: file, function: function, line: line)
}

/// Log warnings
func logWarning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    DebugLogger.log(message, level: .warning, file: file, function: function, line: line)
}

/// Log errors
func logError(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    DebugLogger.log(message, level: .error, file: file, function: function, line: line)
}

/// Log critical errors
func logCritical(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    DebugLogger.log(message, level: .critical, file: file, function: function, line: line)
}

/// Log UI state changes
func logUIState(_ viewName: String, state: String, file: String = #file, function: String = #function, line: Int = #line) {
    DebugLogger.logUIState(viewName, state: state, file: file, function: function, line: line)
}

/// Log data operations
func logDataOperation(_ operation: String, entity: String, success: Bool, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
    DebugLogger.logDataOperation(operation, entity: entity, success: success, error: error, file: file, function: function, line: line)
}

/// Log synchronization events
func logSyncEvent(_ event: String, source: String, target: String, success: Bool, file: String = #file, function: String = #function, line: Int = #line) {
    DebugLogger.logSyncEvent(event, source: source, target: target, success: success, file: file, function: function, line: line)
}

/// Measure execution time of a block of code
func measurePerformance<T>(_ operation: String, file: String = #file, function: String = #function, line: Int = #line, block: () throws -> T) rethrows -> T {
    return try DebugLogger.measure(operation, file: file, function: function, line: line, block: block)
}

/// Log memory usage
func logMemoryUsage(file: String = #file, function: String = #function, line: Int = #line) {
    DebugLogger.logMemoryUsage(file: file, function: function, line: line)
}

/// Log CloudKit account status
func logCloudKitAccountStatus(file: String = #file, function: String = #function, line: Int = #line) {
    DebugLogger.logCloudKitAccountStatus(file: file, function: function, line: line)
}

// MARK: - Extensions for common types

extension Error {
    /// Log this error with context
    func log(context: String, file: String = #file, function: String = #function, line: Int = #line) {
        let errorDetails = self.localizedDescription
        DebugLogger.log("\(context): \(errorDetails)", level: .error, file: file, function: function, line: line)
    }
}

extension CKError {
    /// Log this CloudKit error with recommended solutions
    func logWithSolutions(operation: String, file: String = #file, function: String = #function, line: Int = #line) {
        DebugLogger.logCloudKitError(self, operation: operation, file: file, function: function, line: line)
    }
}

extension NSPredicate {
    /// Log this predicate for CloudKit query debugging
    func logForCloudKit(recordType: String, description: String, file: String = #file, function: String = #function, line: Int = #line) {
        DebugLogger.trackCloudKitQuery(recordType: recordType, predicate: self, queryDescription: description, file: file, function: function, line: line)
    }
}

#if DEBUG
/// Print debug breadcrumbs to trace execution path
func breadcrumb(_ message: String = "", file: String = #file, function: String = #function, line: Int = #line) {
    let fileName = URL(fileURLWithPath: file).lastPathComponent
    let breadcrumb = "🍞 [\(fileName):\(line)] \(function) \(message)"
    print(breadcrumb)
}

/// Check if SF Symbol exists and provide alternative if it doesn't
func validateSymbol(_ symbolName: String, file: String = #file, function: String = #function, line: Int = #line) -> Bool {
    return DebugLogger.validateSymbol(symbolName, file: file, function: function, line: line)
}
#endif

// MARK: - Archive Logging
extension DebugLogger {
    /// Log a message related to archive operations
    public static func logArchive(_ message: String, level: Level = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: .archive, level: level, file: file, function: function, line: line)
    }

    /// Log archive info message
    public static func archiveInfo(_ message: String, level: Level = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: .archive, level: level, file: file, function: function, line: line)
    }

    /// Log information about a specific archive operation
    public static func logArchiveInfo(_ message: String, level: Level = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: .archive, level: level, file: file, function: function, line: line)
    }

    /// Log a specific archive operation
    public static func logArchiveOperation(operation: String, itemType: String, itemTitle: String, success: Bool, errorMessage: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        let status = success ? "✅ Successful" : "❌ Failed"
        var message = "[\(operation)] \(itemType): '\(itemTitle)' - \(status)"
        
        if let errorMessage = errorMessage, !success {
            message += " - Error: \(errorMessage)"
        }
        
        log(message, category: .archive, level: success ? .info : .error, file: file, function: function, line: line)
    }
}

// MARK: - CloudKit Error Logging
extension DebugLogger {
    /// Log CloudKit errors with recommended solutions
    static func logCloudKitError(_ error: CKError, operation: String, file: String = #file, function: String = #function, line: Int = #line) {
        var message = "CloudKit Error in \(operation): \(error.localizedDescription)"
        
        // Add specific error handling based on error code
        switch error.code {
        case .networkUnavailable:
            message += "\nRecommendation: Check network connectivity"
        case .networkFailure:
            message += "\nRecommendation: Retry the operation"
        case .quotaExceeded:
            message += "\nRecommendation: Wait before retrying or optimize data usage"
        case .serverResponseLost:
            message += "\nRecommendation: Retry the operation"
        case .serverRecordChanged:
            message += "\nRecommendation: Fetch latest record and merge changes"
            if let serverRecord = error.serverRecord {
                message += "\nServer Record ID: \(serverRecord.recordID.recordName)"
            }
            if let clientRecord = error.clientRecord {
                message += "\nClient Record ID: \(clientRecord.recordID.recordName)"
            }
        case .zoneNotFound, .userDeletedZone:
            let actionText = error.code == .zoneNotFound ? "Verify zone exists or create it" : "Recreate zone or handle deletion"
            message += "\nRecommendation: \(actionText)"
            // Try to get zone information from the error details if available
            message += "\nAffected Zone: Check CloudKit Dashboard for zone details"
        case .partialFailure:
            message += "\nRecommendation: Check individual error results"
            if let partialErrors = error.userInfo[CKPartialErrorsByItemIDKey] as? [CKRecord.ID: Error] {
                message += "\nPartial Errors Count: \(partialErrors.count)"
            }
        default:
            message += "\nRecommendation: Check error details and retry"
        }
        
        // Add any additional error information from userInfo
        if let errorDescription = error.errorUserInfo[NSLocalizedDescriptionKey] as? String {
            message += "\nError Description: \(errorDescription)"
        }
        
        // Get retry after information using string key
        if let retryAfterValue = error.userInfo["CKErrorRetryAfterKey"] as? NSNumber {
            message += "\nRetry After: \(retryAfterValue.doubleValue) seconds"
        }
        
        // Print all user info keys for debugging
        message += "\nUser Info Keys: \(error.userInfo.keys.map { $0.description }.joined(separator: ", "))"
        
        log(message, category: .cloudKit, level: .error, file: file, function: function, line: line)
    }
    
    /// Track CloudKit queries for debugging and optimization
    static func trackCloudKitQuery(recordType: String, predicate: NSPredicate, queryDescription: String, file: String = #file, function: String = #function, line: Int = #line) {
        let message = """
        CloudKit Query:
        - Record Type: \(recordType)
        - Predicate: \(predicate.predicateFormat)
        - Description: \(queryDescription)
        """
        
        log(message, category: .cloudKitQuery, level: .debug, file: file, function: function, line: line)
    }
}

// MARK: - Symbol Validation
extension DebugLogger {
    /// Validate SF Symbol existence
    static func validateSymbol(_ symbolName: String, file: String = #file, function: String = #function, line: Int = #line) -> Bool {
        let symbolExists = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) != nil
        
        if !symbolExists {
            log("Invalid SF Symbol: '\(symbolName)'", category: .symbolValidation, level: .warning, file: file, function: function, line: line)
        }
        
        return symbolExists
    }
}

// MARK: - PDF Logging Extensions
extension DebugLogger {
    /// Log PDF-specific information
    static func logPDF(_ message: String, level: Level = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: .pdf, level: level, file: file, function: function, line: line)
    }
    
    /// Start a group of logs for better organization
    static func startLogGroup(_ groupName: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        let groupMarker = "┏━━━━━━━━━━━━ BEGIN: \(groupName) ━━━━━━━━━━━━┓"
        log(groupMarker, category: category, level: .info, file: file, function: function, line: line)
    }
    
    /// End a group of logs
    static func endLogGroup(_ groupName: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        let groupMarker = "┗━━━━━━━━━━━━ END: \(groupName) ━━━━━━━━━━━━┛"
        log(groupMarker, category: category, level: .info, file: file, function: function, line: line)
    }
}

// MARK: - Global PDF Logging Functions
/// Log PDF information
func logPDF(_ message: String, level: DebugLogger.Level = .info, file: String = #file, function: String = #function, line: Int = #line) {
    DebugLogger.logPDF(message, level: level, file: file, function: function, line: line)
}

/// Start a log group for better organization
func startLogGroup(_ groupName: String, category: DebugLogger.Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
    DebugLogger.startLogGroup(groupName, category: category, file: file, function: function, line: line)
}

/// End a log group
func endLogGroup(_ groupName: String, category: DebugLogger.Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
    DebugLogger.endLogGroup(groupName, category: category, file: file, function: function, line: line)
}

// MARK: - Global Archive Logging Functions
/// Log archive-related information
func logArchive(_ message: String, level: DebugLogger.Level = .info, file: String = #file, function: String = #function, line: Int = #line) {
    DebugLogger.logArchive(message, level: level, file: file, function: function, line: line)
}

/// Log archive-specific information
func logArchiveInfo(_ message: String, level: DebugLogger.Level = .info, file: String = #file, function: String = #function, line: Int = #line) {
    DebugLogger.logArchiveInfo(message, level: level, file: file, function: function, line: line)
}

/// Log archive operations
func logArchiveOperation(operation: String, itemType: String, itemTitle: String, success: Bool, errorMessage: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
    DebugLogger.logArchiveOperation(operation: operation, itemType: itemType, itemTitle: itemTitle, success: success, errorMessage: errorMessage, file: file, function: function, line: line)
}

// MARK: - Link Management Extension for DebugLogger

extension DebugLogger {
    // Log link clicked
    static func logLinkClicked(url: URL, context: String, file: String = #file, function: String = #function, line: Int = #line) {
        log("Link clicked: \(url.absoluteString) from \(context)", category: .linkManager, level: .info, file: file, function: function, line: line)
    }
    
    // Log link validation
    static func logLinkValidation(url: String, isValid: Bool, file: String = #file, function: String = #function, line: Int = #line) {
        if isValid {
            log("Link validated successfully: \(url)", category: .linkManager, level: .debug, file: file, function: function, line: line)
        } else {
            log("Link validation failed: \(url)", category: .linkManager, level: .warning, file: file, function: function, line: line)
        }
    }
    
    // Log link saved to model
    static func logLinkSaved(url: String, modelType: String, modelId: String, file: String = #file, function: String = #function, line: Int = #line) {
        log("Link saved to \(modelType) with ID \(modelId): \(url)", category: .linkManager, level: .info, file: file, function: function, line: line)
    }
    
    // Log link opened externally
    static func logLinkOpenedExternally(url: URL, success: Bool, file: String = #file, function: String = #function, line: Int = #line) {
        if success {
            log("Link opened in external browser: \(url.absoluteString)", category: .linkManager, level: .info, file: file, function: function, line: line)
        } else {
            log("Failed to open link in external browser: \(url.absoluteString)", category: .linkManager, level: .error, file: file, function: function, line: line)
        }
    }
}

// MARK: - Convenience global functions for link logging

/// Log when a link is clicked
func logLinkClicked(url: URL, context: String, file: String = #file, function: String = #function, line: Int = #line) {
    DebugLogger.logLinkClicked(url: url, context: context, file: file, function: function, line: line)
}

/// Log link validation result
func logLinkValidation(url: String, isValid: Bool, file: String = #file, function: String = #function, line: Int = #line) {
    DebugLogger.logLinkValidation(url: url, isValid: isValid, file: file, function: function, line: line)
}

/// Log when a link is saved to a model
func logLinkSaved(url: String, modelType: String, modelId: String, file: String = #file, function: String = #function, line: Int = #line) {
    DebugLogger.logLinkSaved(url: url, modelType: modelType, modelId: modelId, file: file, function: function, line: line)
}

/// Log when a link is opened in an external browser
func logLinkOpenedExternally(url: URL, success: Bool, file: String = #file, function: String = #function, line: Int = #line) {
    DebugLogger.logLinkOpenedExternally(url: url, success: success, file: file, function: function, line: line)
} 