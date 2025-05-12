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
        case refresh = "Refresh"
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
            message += "\nNetwork Status: \(getNetworkStatus())"
        case .networkFailure:
            message += "\nRecommendation: Retry the operation"
            message += "\nNetwork Status: \(getNetworkStatus())"
        case .quotaExceeded:
            message += "\nRecommendation: Wait before retrying or optimize data usage"
            message += "\nCurrent Usage: \(getCloudKitUsage())"
        case .serverResponseLost:
            message += "\nRecommendation: Retry the operation"
            message += "\nServer Status: \(getServerStatus())"
        case .serverRecordChanged:
            message += "\nRecommendation: Fetch latest record and merge changes"
            if let serverRecord = error.serverRecord {
                message += "\nServer Record ID: \(serverRecord.recordID.recordName)"
                message += "\nServer Record Fields: \(serverRecord.getAllKeys().joined(separator: ", "))"
            }
            if let clientRecord = error.clientRecord {
                message += "\nClient Record ID: \(clientRecord.recordID.recordName)"
                message += "\nClient Record Fields: \(clientRecord.getAllKeys().joined(separator: ", "))"
            }
        case .zoneNotFound, .userDeletedZone:
            let actionText = error.code == .zoneNotFound ? "Verify zone exists or create it" : "Recreate zone or handle deletion"
            message += "\nRecommendation: \(actionText)"
            message += "\nZone Information: \(getZoneInfo())"
        case .partialFailure:
            message += "\nRecommendation: Check individual error results"
            if let partialErrors = error.userInfo[CKPartialErrorsByItemIDKey] as? [CKRecord.ID: Error] {
                message += "\nPartial Errors Count: \(partialErrors.count)"
                for (recordID, error) in partialErrors {
                    message += "\n- Record \(recordID.recordName): \(error.localizedDescription)"
                }
            }
        case .unknownItem:
            message += "\nRecommendation: Verify record existence and permissions"
            message += "\nRecord Type: \(error.userInfo["CKRecordType"] as? String ?? "Unknown")"
        case .invalidArguments:
            message += "\nRecommendation: Check query structure and schema"
            if let reason = error.userInfo[NSLocalizedFailureReasonErrorKey] as? String {
                message += "\nReason: \(reason)"
            }
        case .incompatibleVersion:
            message += "\nRecommendation: Update schema version"
            message += "\nCurrent Schema Version: \(getSchemaVersion())"
        case .constraintViolation:
            message += "\nRecommendation: Check record constraints"
            message += "\nViolated Constraints: \(getConstraintViolations())"
        case .badDatabase:
            message += "\nRecommendation: Contact support"
            message += "\nDatabase Status: \(getDatabaseStatus())"
        case .zoneBusy:
            message += "\nRecommendation: Implement retry with exponential backoff"
            message += "\nRetry After: \(getRetryAfterTime())"
        case .internalError:
            message += "\nRecommendation: Contact support"
            message += "\nError Details: \(getInternalErrorDetails())"
        case .assetFileNotFound:
            message += "\nRecommendation: Verify asset existence"
            message += "\nAsset Details: \(getAssetDetails())"
        case .assetFileModified:
            message += "\nRecommendation: Retry asset upload"
            message += "\nAsset Status: \(getAssetStatus())"
        case .limitExceeded:
            message += "\nRecommendation: Reduce request size"
            message += "\nRequest Size: \(getRequestSize())"
        case .tooManyParticipants:
            message += "\nRecommendation: Reduce participant count"
            message += "\nCurrent Participants: \(getParticipantCount())"
        case .referenceViolation:
            message += "\nRecommendation: Check reference integrity"
            message += "\nReference Details: \(getReferenceDetails())"
        case .missingEntitlement:
            message += "\nRecommendation: Verify entitlements"
            message += "\nRequired Entitlements: \(getRequiredEntitlements())"
        case .changeTokenExpired:
            message += "\nRecommendation: Fetch new change token"
            message += "\nToken Status: \(getTokenStatus())"
        case .operationCancelled:
            message += "\nRecommendation: Check operation cancellation reason"
            message += "\nCancellation Details: \(getCancellationDetails())"
        case .requestRateLimited:
            message += "\nRecommendation: Implement rate limiting"
            message += "\nRate Limit Info: \(getRateLimitInfo())"
        default:
            message += "\nRecommendation: Check error details and retry"
        }
        
        // Add any additional error information from userInfo
        if let errorDescription = error.errorUserInfo[NSLocalizedDescriptionKey] as? String {
            message += "\nError Description: \(errorDescription)"
        }
        
        // Get retry after information
        if let retryAfterValue = error.userInfo["CKErrorRetryAfterKey"] as? NSNumber {
            message += "\nRetry After: \(retryAfterValue.doubleValue) seconds"
        }
        
        // Print all user info keys for debugging
        message += "\nUser Info Keys: \(error.userInfo.keys.map { $0.description }.joined(separator: ", "))"
        
        // Add timestamp and context
        message += "\nTimestamp: \(Date())"
        message += "\nContext: \(file):\(line) - \(function)"
        
        log(message, category: .cloudKit, level: .error, file: file, function: function, line: line)
    }
    
    /// Track CloudKit queries for debugging and optimization
    static func trackCloudKitQuery(recordType: String, predicate: NSPredicate, queryDescription: String, file: String = #file, function: String = #function, line: Int = #line) {
        let message = """
        CloudKit Query:
        - Record Type: \(recordType)
        - Predicate: \(predicate.predicateFormat)
        - Description: \(queryDescription)
        - Timestamp: \(Date())
        - Context: \(file):\(line) - \(function)
        - Query Performance: \(getQueryPerformanceMetrics())
        """
        
        log(message, category: .cloudKitQuery, level: .debug, file: file, function: function, line: line)
    }
    
    // MARK: - Helper Methods for Enhanced Logging
    
    private static func getNetworkStatus() -> String {
        // Implement network status check
        return "Not implemented"
    }
    
    private static func getCloudKitUsage() -> String {
        // Implement CloudKit usage check
        return "Not implemented"
    }
    
    private static func getServerStatus() -> String {
        // Implement server status check
        return "Not implemented"
    }
    
    private static func getZoneInfo() -> String {
        // Implement zone info check
        return "Not implemented"
    }
    
    private static func getSchemaVersion() -> String {
        // Implement schema version check
        return "Not implemented"
    }
    
    private static func getConstraintViolations() -> String {
        // Implement constraint violations check
        return "Not implemented"
    }
    
    private static func getDatabaseStatus() -> String {
        // Implement database status check
        return "Not implemented"
    }
    
    private static func getStorageUsage() -> String {
        // Implement storage usage check
        return "Not implemented"
    }
    
    private static func getRetryAfterTime() -> String {
        // Implement retry after time check
        return "Not implemented"
    }
    
    private static func getInternalErrorDetails() -> String {
        // Implement internal error details check
        return "Not implemented"
    }
    
    private static func getPartialFailureDetails() -> String {
        // Implement partial failure details check
        return "Not implemented"
    }
    
    private static func getAssetDetails() -> String {
        // Implement asset details check
        return "Not implemented"
    }
    
    private static func getAssetStatus() -> String {
        // Implement asset status check
        return "Not implemented"
    }
    
    private static func getRequestSize() -> String {
        // Implement request size check
        return "Not implemented"
    }
    
    private static func getParticipantCount() -> String {
        // Implement participant count check
        return "Not implemented"
    }
    
    private static func getReferenceDetails() -> String {
        // Implement reference details check
        return "Not implemented"
    }
    
    private static func getRequiredEntitlements() -> String {
        // Implement required entitlements check
        return "Not implemented"
    }
    
    private static func getTokenStatus() -> String {
        // Implement token status check
        return "Not implemented"
    }
    
    private static func getCancellationDetails() -> String {
        // Implement cancellation details check
        return "Not implemented"
    }
    
    private static func getRateLimitInfo() -> String {
        // Implement rate limit info check
        return "Not implemented"
    }
    
    private static func getQueryPerformanceMetrics() -> String {
        // Implement query performance metrics
        return "Not implemented"
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

// MARK: - Event Management Extension for DebugLogger

extension DebugLogger {
    enum EventAction: String {
        case select = "SELECT"
        case deselect = "DESELECT"
        case load = "LOAD"
        case cloudKitFetch = "CLOUDKIT_FETCH"
        case stateChange = "STATE_CHANGE"
        case pdfLoad = "PDF_LOAD"
        case freeze = "FREEZE_DETECTED"
        case memoryPressure = "MEMORY_PRESSURE"
    }
    
    static func logEventAction(
        action: EventAction,
        id: String? = nil,
        title: String? = nil,
        details: [String: Any]? = nil,
        executionTime: TimeInterval? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let timestamp = Date().timeIntervalSince1970
        var message = "[\(action.rawValue)] "
        
        if let id = id {
            message += "ID: \(id) "
        }
        
        if let title = title {
            message += "'\(title)' "
        }
        
        if let executionTime = executionTime {
            message += "Duration: \(String(format: "%.4f", executionTime))s "
        }
        
        if let details = details, !details.isEmpty {
            let detailsStr = details.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            message += "[\(detailsStr)]"
        }
        
        message += " @ \(timestamp)"
        
        // Use different log levels based on action type
        let level: Level = action == .freeze || action == .memoryPressure ? .critical : .info
        log(message, category: .calendar, level: level, file: file, function: function, line: line)
    }
    
    static func trackEventOperation<T>(
        action: EventAction,
        id: String? = nil, 
        title: String? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        operation: () throws -> T
    ) rethrows -> T {
        let startTime = Date()
        let result = try operation()
        let executionTime = Date().timeIntervalSince(startTime)
        
        logEventAction(
            action: action,
            id: id,
            title: title,
            details: ["timestamp": Date().timeIntervalSince1970],
            executionTime: executionTime,
            file: file,
            function: function,
            line: line
        )
        
        // Flag if operation took too long (possibly causing a freeze)
        if executionTime > 0.5 { // 500ms threshold for potential UI freezes
            logEventAction(
                action: .memoryPressure,
                id: id,
                title: title,
                details: [
                    "executionTime": executionTime,
                    "actionType": action.rawValue,
                    "memoryUsage": ProcessInfo.processInfo.physicalMemory / 1_048_576 // MB
                ],
                file: file,
                function: function,
                line: line
            )
        }
        
        return result
    }
    
    static func beginEventLoad(file: String = #file, function: String = #function, line: Int = #line) {
        startLogGroup("EVENT LOADING", category: .calendar, file: file, function: function, line: line)
        log("Beginning event loading process", category: .calendar, level: .info, file: file, function: function, line: line)
    }
    
    static func endEventLoad(count: Int, success: Bool, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        if success {
            log("Event loading completed successfully. Loaded \(count) events", category: .calendar, level: .info, file: file, function: function, line: line)
        } else if let error = error {
            log("Event loading failed: \(error.localizedDescription)", category: .calendar, level: .error, file: file, function: function, line: line)
        } else {
            log("Event loading ended with unknown status", category: .calendar, level: .warning, file: file, function: function, line: line)
        }
        endLogGroup("EVENT LOADING", category: .calendar, file: file, function: function, line: line)
    }
    
    static func detectFreeze(area: String, context: [String: Any], file: String = #file, function: String = #function, line: Int = #line) {
        var contextInfo = context
        contextInfo["memoryUsage"] = ProcessInfo.processInfo.physicalMemory / 1_048_576 // MB
        contextInfo["timestamp"] = Date().timeIntervalSince1970
        
        log("⚠️⚠️⚠️ FREEZE DETECTED in \(area) ⚠️⚠️⚠️", category: .performance, level: .critical, file: file, function: function, line: line)
        
        // Log detailed context information
        let contextStr = contextInfo.map { "\($0.key): \($0.value)" }.joined(separator: "\n- ")
        log("Freeze context:\n- \(contextStr)", category: .performance, level: .critical, file: file, function: function, line: line)
    }
}

// MARK: - Global event tracking functions

/// Log an event action with detailed information
func logEventAction(
    action: DebugLogger.EventAction,
    id: String? = nil,
    title: String? = nil,
    details: [String: Any]? = nil,
    executionTime: TimeInterval? = nil,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    DebugLogger.logEventAction(
        action: action,
        id: id,
        title: title,
        details: details,
        executionTime: executionTime,
        file: file,
        function: function,
        line: line
    )
}

/// Track an event operation with timing
func trackEventOperation<T>(
    action: DebugLogger.EventAction,
    id: String? = nil,
    title: String? = nil,
    file: String = #file,
    function: String = #function,
    line: Int = #line,
    operation: () throws -> T
) rethrows -> T {
    return try DebugLogger.trackEventOperation(
        action: action,
        id: id,
        title: title,
        file: file,
        function: function,
        line: line,
        operation: operation
    )
}

/// Log the beginning of an event loading process
func beginEventLoad(file: String = #file, function: String = #function, line: Int = #line) {
    DebugLogger.beginEventLoad(file: file, function: function, line: line)
}

/// Log the end of an event loading process
func endEventLoad(count: Int, success: Bool, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
    DebugLogger.endEventLoad(count: count, success: success, error: error, file: file, function: function, line: line)
}

/// Log a detected freeze in the app
func detectFreeze(area: String, context: [String: Any] = [:], file: String = #file, function: String = #function, line: Int = #line) {
    DebugLogger.detectFreeze(area: area, context: context, file: file, function: function, line: line)
}

// MARK: - Timer-Based Freeze Detection System

/// A class that uses periodic timer checks to detect UI thread freezes
class TimerBasedFreezeDetector {
    /// Singleton instance for app-wide freeze detection
    static let shared = TimerBasedFreezeDetector()
    
    /// The minimum duration (in seconds) that must pass without a heartbeat to consider the UI frozen
    private let freezeThreshold: TimeInterval = 1.0 
    
    /// How frequently to check for freezes (in seconds)
    private let checkInterval: TimeInterval = 0.5
    
    /// Timer that runs on a background thread to detect main thread freezes
    private var heartbeatTimer: DispatchSourceTimer?
    
    /// The last time a heartbeat was recorded (on the main thread)
    private var lastHeartbeatTime = Date()
    
    /// Main-thread timer that updates lastHeartbeatTime
    private var mainThreadTimer: Timer?
    
    /// Whether the detector is currently running
    private(set) var isRunning = false
    
    /// Area currently being monitored, if specified
    private var monitoredArea: String?
    
    /// Additional context to include with freeze reports
    private var monitorContext: [String: Any]?
    
    /// Main thread consecutive heartbeat count (for debugging)
    private var heartbeatCount = 0
    
    private init() {}
    
    /// Start the freeze detector with optional area and context information
    func start(area: String? = nil, context: [String: Any]? = nil) {
        guard !isRunning else { return }
        
        monitoredArea = area
        monitorContext = context
        
        // Record initial heartbeat time
        lastHeartbeatTime = Date()
        heartbeatCount = 0
        
        // Set up main thread timer to update heartbeat times
        mainThreadTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.lastHeartbeatTime = Date()
            self.heartbeatCount += 1
        }
        
        // Set up background thread timer to check for freezes
        let queue = DispatchQueue(label: "com.enlace.freezeDetector", qos: .utility)
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + checkInterval, repeating: checkInterval)
        
        timer.setEventHandler { [weak self] in
            self?.checkForFreeze()
        }
        
        heartbeatTimer = timer
        timer.resume()
        
        isRunning = true
        
        logInfo("Freeze detector started" + (area != nil ? " for area: \(area!)" : ""))
    }
    
    /// Stop the freeze detector
    func stop() {
        guard isRunning else { return }
        
        mainThreadTimer?.invalidate()
        mainThreadTimer = nil
        
        heartbeatTimer?.cancel()
        heartbeatTimer = nil
        
        isRunning = false
        monitoredArea = nil
        monitorContext = nil
        
        logInfo("Freeze detector stopped")
    }
    
    /// Check if the main thread has been frozen
    private func checkForFreeze() {
        let currentTime = Date()
        let timeSinceLastHeartbeat = currentTime.timeIntervalSince(lastHeartbeatTime)
        
        // If time since last heartbeat exceeds threshold, report a freeze
        if timeSinceLastHeartbeat > freezeThreshold {
            // Prepare freeze context information
            var context: [String: Any] = [
                "freezeDuration": timeSinceLastHeartbeat,
                "heartbeatCount": heartbeatCount,
                "lastHeartbeatTime": lastHeartbeatTime.timeIntervalSince1970,
                "detectionTime": currentTime.timeIntervalSince1970
            ]
            
            // Add monitored area and custom context if available
            if let area = monitoredArea {
                context["monitoredArea"] = area
            }
            
            if let customContext = monitorContext {
                for (key, value) in customContext {
                    context[key] = value
                }
            }
            
            // Log the freeze with detailed context
            let area = monitoredArea ?? "Unknown Area"
            
            // Use a direct print since the main thread is likely frozen
            print("⚠️⚠️⚠️ CRITICAL: UI FREEZE DETECTED in \(area) - \(String(format: "%.2f", timeSinceLastHeartbeat))s without heartbeat ⚠️⚠️⚠️")
            
            // Also log to the debug system once the main thread unfreezes
            DispatchQueue.main.async {
                detectFreeze(area: area, context: context)
                
                // Also log as an event action for better tracking
                logEventAction(
                    action: .freeze,
                    details: [
                        "area": area,
                        "duration": timeSinceLastHeartbeat,
                        "heartbeatCount": self.heartbeatCount
                    ],
                    executionTime: timeSinceLastHeartbeat
                )
            }
        }
    }
}

// MARK: - Global freeze detector convenience functions

/// Start the freeze detector for a specific area of the app
func startFreezeDetection(area: String, context: [String: Any]? = nil) {
    TimerBasedFreezeDetector.shared.start(area: area, context: context)
}

/// Stop the freeze detector
func stopFreezeDetection() {
    TimerBasedFreezeDetector.shared.stop()
}

// MARK: - Calendar Refresh Debugging
extension DebugLogger {
    static func trackCalendarRefresh(action: String, context: String, refreshTrigger: Bool, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        log("📆 REFRESH [\(context)] \(action) - refreshTrigger: \(refreshTrigger) - Location: \(fileName):\(line) - \(function)", category: .refresh, level: .debug)
    }
    
    static func trackEventLoad(module: String, eventCount: Int?, startTime: Date, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        let duration = Date().timeIntervalSince(startTime)
        let durationStr = String(format: "%.3f", duration)
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        
        if let error = error {
            log("❌ EVENTS [\(module)] Load failed in \(durationStr)s - Error: \(error.localizedDescription) - Location: \(fileName):\(line)", category: .cloudKit, level: .error)
        } else if let count = eventCount {
            log("✅ EVENTS [\(module)] Loaded \(count) events in \(durationStr)s - Location: \(fileName):\(line)", category: .cloudKit, level: .info)
        } else {
            log("⚠️ EVENTS [\(module)] Unknown result in \(durationStr)s - Location: \(fileName):\(line)", category: .cloudKit, level: .warning)
        }
    }
    
    static func trackRefreshTrigger(source: String, oldValue: Bool, newValue: Bool, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        log("🔄 TRIGGER [\(source)] Changed: \(oldValue) → \(newValue) - Location: \(fileName):\(line) - \(function)", category: .refresh, level: .info)
    }
}

// MARK: - CloudKit Logging Extensions
extension DebugLogger {
    /// Log CloudKit-specific information
    static func logCloudKit(_ message: String, level: Level = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: .cloudKit, level: level, file: file, function: function, line: line)
    }
}

// Global CloudKit logging convenience
func logCloudKit(_ message: String, level: DebugLogger.Level = .info, file: String = #file, function: String = #function, line: Int = #line) {
    DebugLogger.logCloudKit(message, level: level, file: file, function: function, line: line)
} 