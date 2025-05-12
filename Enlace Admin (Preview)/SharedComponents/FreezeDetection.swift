import Foundation
import CloudKit
import Darwin // For mach memory APIs
import AppKit

/// FreezeDetection - A specialized system for detecting and diagnosing UI freezes
/// This component focuses on identifying performance bottlenecks in the Enlace Admin app,
/// with special emphasis on the EventManagementView freezing issues.
public class FreezeDetection {
    
    // MARK: - Types and Constants
    
    /// Severity levels for performance issues
    public enum Severity: String {
        case normal = "Normal operation"
        case minor = "Minor lag detected"
        case moderate = "UI slowdown"
        case major = "UI freeze detected"
        case critical = "Critical freeze"
        
        /// Get severity based on duration
        static func forDuration(_ duration: TimeInterval) -> Severity {
            switch duration {
            case 0.0..<0.3: return .normal
            case 0.3..<1.0: return .minor
            case 1.0..<3.0: return .moderate
            case 3.0..<10.0: return .major
            default: return .critical
            }
        }
        
        /// Get emoji representation for logs
        var emoji: String {
            switch self {
            case .normal: return "✅"
            case .minor: return "⚠️"
            case .moderate: return "🔶"
            case .major: return "🔴"
            case .critical: return "🚨"
            }
        }
    }
    
    /// Areas in the app where freezes can be detected and monitored
    public enum Area: String {
        case eventSelection = "Event Selection"
        case pdfLoading = "PDF Loading"
        case cloudKitFetch = "CloudKit Fetch"
        case uiRendering = "UI Rendering"
        case eventDetailsLoading = "Event Details Loading"
        case viewTransition = "View Transition"
        case dataProcessing = "Data Processing"
        case custom = "Custom Area"
    }
    
    // MARK: - Properties
    
    /// Current active detection session
    private static var activeDetectionArea: Area?
    
    /// Start time of active detection
    private static var activeDetectionStartTime: Date?
    
    /// Context information for the active detection
    private static var activeDetectionContext: [String: Any]?
    
    /// Timer to catch operations that take too long
    private static var detectionTimer: Timer?
    
    /// Whether detection logging should be verbose
    public static var isVerboseLogging: Bool = true
    
    /// Default timeout for operations before triggering detection
    public static var defaultTimeoutSeconds: TimeInterval = 5.0
    
    // MARK: - Core Detection Methods
    
    /// Start monitoring a specific area for freezes
    public static func startDetection(
        area: Area,
        timeoutSeconds: TimeInterval? = nil,
        context: [String: Any] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        // Cancel any existing timer
        detectionTimer?.invalidate()
        
        // Set the active detection state
        activeDetectionArea = area
        activeDetectionStartTime = Date()
        
        // Add basic metrics to the context
        var enrichedContext = context
        enrichedContext["memoryBeforeMB"] = getMemoryUsageMB()
        enrichedContext["startTimestamp"] = Date().timeIntervalSince1970
        enrichedContext["file"] = URL(fileURLWithPath: file).lastPathComponent
        enrichedContext["function"] = function
        enrichedContext["line"] = line
        activeDetectionContext = enrichedContext
        
        // Log start if verbose
        if isVerboseLogging {
            let contextString = enrichedContext.map { "\($0): \($1)" }.joined(separator: ", ")
            print("🔍 FREEZE DETECTION: Starting in \(area.rawValue) with context: \(contextString)")
        } else {
            print("🔍 FREEZE DETECTION: Starting in \(area.rawValue)")
        }
        
        // Start timeout timer
        let timeout = timeoutSeconds ?? defaultTimeoutSeconds
        detectionTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
            // If timer fires and detection wasn't stopped, we have a freeze
            if let activeArea = activeDetectionArea, activeArea == area {
                let duration = Date().timeIntervalSince(activeDetectionStartTime ?? Date())
                
                // Log timeout warning
                print("⚠️ FREEZE WARNING: Operation in \(area.rawValue) exceeding \(String(format: "%.1f", timeout))s timeout (currently at \(String(format: "%.2f", duration))s)")
                
                // Capture additional context
                var timeoutContext = activeDetectionContext ?? [:]
                timeoutContext["timeoutSeconds"] = timeout
                timeoutContext["actualDuration"] = duration
                timeoutContext["memoryCurrentMB"] = getMemoryUsageMB()
                timeoutContext["callStack"] = Thread.callStackSymbols
                
                // Report potential freeze but don't stop detection
                reportFreeze(
                    area: area,
                    duration: duration,
                    severity: .major,
                    context: timeoutContext,
                    isContinuing: true
                )
            }
        }
    }
    
    /// Stop monitoring and calculate results
    public static func stopDetection(
        additionalContext: [String: Any] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        // First ensure there is an active detection
        guard let area = activeDetectionArea, let startTime = activeDetectionStartTime else {
            print("⚠️ FREEZE DETECTION: attempted to stop when no detection was active")
            return
        }
        
        // Cancel timer - ENSURE this happens on main thread
        DispatchQueue.main.async {
            if let timer = detectionTimer, timer.isValid {
                timer.invalidate()
                print("🔍 FREEZE DETECTION: Successfully invalidated active timer")
            }
            detectionTimer = nil
        }
        
        // Calculate duration
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Get memory info
        let memoryEndMB = getMemoryUsageMB()
        let memoryStartMB = (activeDetectionContext?["memoryBeforeMB"] as? UInt64) ?? 0
        let memoryDeltaMB = Int64(memoryEndMB) - Int64(memoryStartMB)
        
        // Combine contexts
        var combinedContext = activeDetectionContext ?? [:]
        for (key, value) in additionalContext {
            combinedContext[key] = value
        }
        
        // Add metrics to context
        combinedContext["durationSeconds"] = duration
        combinedContext["memoryEndMB"] = memoryEndMB
        combinedContext["memoryDeltaMB"] = memoryDeltaMB
        combinedContext["endTimestamp"] = Date().timeIntervalSince1970
        combinedContext["completedFile"] = URL(fileURLWithPath: file).lastPathComponent
        combinedContext["completedFunction"] = function
        combinedContext["completedLine"] = line
        
        // Add explicit note this detection was properly stopped
        combinedContext["properlyCompleted"] = true
        
        // Determine severity
        let severity = Severity.forDuration(duration)
        
        // Log completion
        let durStr = String(format: "%.3f", duration)
        let memStr = String(format: "%+d", memoryDeltaMB)
        print("\(severity.emoji) FREEZE DETECTION: Completed \(area.rawValue) in \(durStr)s with \(memStr)MB memory change")
        
        // If we have a significant operation, report it
        if severity != .normal {
            reportFreeze(area: area, duration: duration, severity: severity, context: combinedContext)
        }
        
        // IMPORTANT: Clear detection state - MUST HAPPEN AFTER REPORTING
        DispatchQueue.main.async {
            activeDetectionArea = nil
            activeDetectionStartTime = nil
            activeDetectionContext = nil
        }
    }
    
    /// Report a detected freeze
    public static func reportFreeze(
        area: Area,
        duration: TimeInterval,
        severity: Severity,
        context: [String: Any],
        isContinuing: Bool = false
    ) {
        // Build report header
        var report = """
        \(severity.emoji) \(severity.rawValue): \(area.rawValue)
        Duration: \(String(format: "%.3f", duration))s
        Memory: \(context["memoryCurrentMB"] ?? context["memoryEndMB"] ?? "Unknown") MB
        """
        
        // Add context details
        report += "\n--- Context ---"
        for (key, value) in context.sorted(by: { $0.key < $1.key }) {
            // Skip call stack for now as it's long
            if key != "callStack" {
                report += "\n\(key): \(value)"
            }
        }
        
        // Add call stack if available
        if let callStack = context["callStack"] as? [String] {
            report += "\n\n--- Call Stack ---"
            for (index, frame) in callStack.enumerated() {
                if index < 15 { // Limit to first 15 frames
                    report += "\n\(index). \(frame)"
                }
            }
            if callStack.count > 15 {
                report += "\n... (\(callStack.count - 15) more frames)"
            }
        }
        
        // Add specialized diagnostics for specific areas
        if area == .eventSelection {
            report += "\n\n--- Event Selection Diagnostics ---"
            // Add event ID if available
            if let eventId = context["eventId"] as? String {
                report += "\nEvent ID: \(eventId)"
            }
            
            // Add event title if available
            if let eventTitle = context["eventTitle"] as? String {
                report += "\nEvent Title: \(eventTitle)"
            }
            
            // Add possible causes based on patterns we've observed
            report += "\nPossible causes:"
            report += "\n- PDF reference processing (check if event has PDF)"
            report += "\n- CloudKit latency (network conditions)"
            report += "\n- Memory pressure (check memory metrics)"
            report += "\n- UI thread blocking operations"
            
            // Add recommended actions
            report += "\n\nRecommendations:"
            report += "\n- Consider implementing lazy PDF loading"
            report += "\n- Move more operations to background threads"
            report += "\n- Add progress indicators for operations > 500ms"
            report += "\n- Consider splitting the event selection process into phases"
        }
        
        // Add PDF loading diagnostics
        if area == .pdfLoading {
            report += "\n\n--- PDF Loading Diagnostics ---"
            if let pdfPageCount = context["pdfPageCount"] as? Int {
                report += "\nPDF Page Count: \(pdfPageCount)"
                if pdfPageCount > 20 {
                    report += "\nNote: Large PDFs (>20 pages) may cause performance issues"
                }
            }
            
            // Memory analysis
            if let memoryBefore = context["memoryBeforeMB"] as? UInt64,
               let memoryAfter = context["memoryAfterMB"] as? UInt64 {
                let memoryDelta = Int64(memoryAfter) - Int64(memoryBefore)
                let percentIncrease = memoryBefore > 0 ? (Double(memoryDelta) / Double(memoryBefore) * 100.0) : 0
                
                report += "\nMemory Impact: \(memoryDelta)MB (\(String(format: "%.1f", percentIncrease))% increase)"
                
                if percentIncrease > 50 {
                    report += "\nWarning: Significant memory increase during PDF loading"
                }
            }
        }
        
        // Add CloudKit fetch diagnostics
        if area == .cloudKitFetch {
            report += "\n\n--- CloudKit Fetch Diagnostics ---"
            if let queryType = context["queryType"] as? String {
                report += "\nQuery Type: \(queryType)"
            }
            if let recordCount = context["recordCount"] as? Int {
                report += "\nRecord Count: \(recordCount)"
                if recordCount > 100 {
                    report += "\nNote: Large result sets (>100 records) may impact performance"
                }
            }
            
            report += "\nRecommendations:"
            report += "\n- Consider pagination for large result sets"
            report += "\n- Add network quality monitoring"
            report += "\n- Implement local caching for frequently accessed records"
        }
        
        // Log the report
        print("\n" + report + "\n")
        
        // Additional actions based on severity
        if severity == .critical {
            // Request emergency cleanup if memory pressure is high
            if let memoryMB = context["memoryCurrentMB"] as? UInt64 ?? context["memoryEndMB"] as? UInt64,
               memoryMB > 700 { // 700MB threshold
                print("🧹 FREEZE DETECTION: Requesting emergency memory cleanup due to critical freeze")
                // Note: actual cleanup implemented elsewhere
            }
            
            // Collect additional system diagnostics for critical freezes
            collectSystemDiagnostics(area: area, context: context)
        }
    }
    
    /// Collect additional system diagnostics for critical freezes
    private static func collectSystemDiagnostics(area: Area, context: [String: Any]) {
        // Current date/time
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        let timestamp = dateFormatter.string(from: Date())
        
        // System info
        let systemVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let memoryTotal = ProcessInfo.processInfo.physicalMemory / (1024 * 1024)
        let memoryUsed = getMemoryUsageMB()
        let memoryPercent = Double(memoryUsed) * 100.0 / Double(memoryTotal)
        
        // Build diagnostics report
        var diagnostics = """
        🔬 SYSTEM DIAGNOSTICS - \(timestamp)
        Area: \(area.rawValue)
        System: \(systemVersion)
        Memory: \(memoryUsed)MB of \(memoryTotal)MB (\(String(format: "%.1f", memoryPercent))%)
        Processor Count: \(ProcessInfo.processInfo.processorCount)
        Active Processor Count: \(ProcessInfo.processInfo.activeProcessorCount)
        """
        
        // Running processes (simplified)
        if let psOutput = runCommand("ps -axm -o pid,pmem,rss,command | head -n 10") {
            diagnostics += "\n\n--- Top Processes ---\n\(psOutput)"
        }
        
        // Network status (simplified)
        if let networkStatus = runCommand("ifconfig en0 | grep 'status'") {
            diagnostics += "\n\n--- Network Status ---\n\(networkStatus)"
        }
        
        // Print diagnostics
        print("\n" + diagnostics + "\n")
    }
    
    /// Run a shell command and return the output (for diagnostics only)
    private static func runCommand(_ command: String) -> String? {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/sh"
        
        do {
            try task.run()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return output
            }
        } catch {
            print("Error running command: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    // MARK: - Helper Methods
    
    /// Get memory usage in MB using mach_task_basic_info
    public static func getMemoryUsageMB() -> UInt64 {
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return (kerr == KERN_SUCCESS) ? taskInfo.resident_size / (1024 * 1024) : 0
    }
    
    /// Track an operation with automatic freeze detection
    public static func track<T>(
        area: Area,
        context: [String: Any] = [:],
        operation: () throws -> T
    ) rethrows -> T {
        // Start detection
        startDetection(area: area, context: context)
        
        do {
            // Perform operation
            let result = try operation()
            
            // Stop detection with success context
            stopDetection(additionalContext: ["success": true])
            
            return result
        } catch {
            // Stop detection with error context
            stopDetection(additionalContext: [
                "success": false,
                "error": error.localizedDescription,
                "errorType": String(describing: type(of: error))
            ])
            
            throw error
        }
    }
    
    /// Track an async operation with automatic freeze detection
    public static func track<T>(
        area: Area,
        context: [String: Any] = [:],
        operation: () async throws -> T
    ) async rethrows -> T {
        // Start detection
        startDetection(area: area, context: context)
        
        do {
            // Perform operation
            let result = try await operation()
            
            // Stop detection with success context
            stopDetection(additionalContext: ["success": true])
            
            return result
        } catch {
            // Stop detection with error context
            stopDetection(additionalContext: [
                "success": false,
                "error": error.localizedDescription,
                "errorType": String(describing: type(of: error))
            ])
            
            throw error
        }
    }
    
    /// Emergency cancellation of any ongoing freeze detection
    /// This can be called in situations where you need to immediately stop detection
    /// regardless of the current state
    public static func emergencyCancelDetection(reason: String = "Unknown") {
        DispatchQueue.main.async {
            if let timer = detectionTimer, timer.isValid {
                timer.invalidate()
                print("🚨 FREEZE DETECTION: Emergency cancellation of active timer. Reason: \(reason)")
            }
            
            // Log what was cancelled
            if let area = activeDetectionArea {
                print("🚨 FREEZE DETECTION: Cancelled active detection in area: \(area.rawValue)")
                
                // Create a snapshot of context
                var contextCopy = activeDetectionContext ?? [:]
                contextCopy["emergencyCancellation"] = true
                contextCopy["cancellationReason"] = reason
                
                if let startTime = activeDetectionStartTime {
                    let duration = Date().timeIntervalSince(startTime)
                    contextCopy["partialDuration"] = duration
                    
                    print("🚨 FREEZE DETECTION: Cancelled after running for \(String(format: "%.3f", duration))s")
                }
                
                // Report as a warning
                reportFreeze(
                    area: area,
                    duration: 0, // Use zero since it wasn't completed
                    severity: .moderate,
                    context: contextCopy
                )
            }
            
            // Clear all state
            detectionTimer = nil
            activeDetectionArea = nil
            activeDetectionStartTime = nil
            activeDetectionContext = nil
            
            print("🚨 FREEZE DETECTION: All detection state cleared")
        }
    }
}

// MARK: - Global Convenience Functions

/// Start monitoring a specific area for freezes
public func startFreezeDetection(
    area: FreezeDetection.Area,
    timeoutSeconds: TimeInterval? = nil,
    context: [String: Any] = [:],
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    FreezeDetection.startDetection(
        area: area,
        timeoutSeconds: timeoutSeconds,
        context: context,
        file: file,
        function: function,
        line: line
    )
}

/// Stop monitoring and calculate results
public func stopFreezeDetection(
    additionalContext: [String: Any] = [:],
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    FreezeDetection.stopDetection(
        additionalContext: additionalContext,
        file: file,
        function: function,
        line: line
    )
}

/// Track an operation with automatic freeze detection
public func trackWithFreezeDetection<T>(
    area: FreezeDetection.Area,
    context: [String: Any] = [:],
    operation: () throws -> T
) rethrows -> T {
    return try FreezeDetection.track(area: area, context: context, operation: operation)
}

/// Track an async operation with automatic freeze detection
public func trackWithFreezeDetection<T>(
    area: FreezeDetection.Area,
    context: [String: Any] = [:],
    operation: () async throws -> T
) async rethrows -> T {
    return try await FreezeDetection.track(area: area, context: context, operation: operation)
}

/// Get current memory usage in MB
public func getMemoryUsageMB() -> UInt64 {
    return FreezeDetection.getMemoryUsageMB()
}

/// Emergency cancellation of any ongoing freeze detection
public func emergencyCancelFreezeDetection(reason: String = "Unknown") {
    FreezeDetection.emergencyCancelDetection(reason: reason)
} 