import Foundation
import PDFKit
import AppKit

// MARK: - PDF and CloudKit Debug Extensions

/// Extensions to assist with PDF debugging
extension PDFDocument {
    /// Log detailed information about this PDF document
    func debugInfo() -> String {
        var info = "PDF Document Info:\n"
        info += "- Page count: \(self.pageCount)\n"
        info += "- Is encrypted: \(self.isEncrypted)\n"
        info += "- Is locked: \(self.isLocked)\n"
        
        // Get document attributes if available
        if let attributes = self.documentAttributes {
            info += "- Attributes:\n"
            if let title = attributes[PDFDocumentAttribute.titleAttribute] as? String {
                info += "  - Title: \(title)\n"
            }
            if let author = attributes[PDFDocumentAttribute.authorAttribute] as? String {
                info += "  - Author: \(author)\n"
            }
            if let creator = attributes[PDFDocumentAttribute.creatorAttribute] as? String {
                info += "  - Creator: \(creator)\n"
            }
            if let creationDate = attributes[PDFDocumentAttribute.creationDateAttribute] as? Date {
                info += "  - Creation Date: \(creationDate.formatted())\n"
            }
            if let modDate = attributes[PDFDocumentAttribute.modificationDateAttribute] as? Date {
                info += "  - Modification Date: \(modDate.formatted())\n"
            }
            if let size = attributes[PDFDocumentAttribute.keywordsAttribute] as? [String] {
                info += "  - Keywords: \(size.joined(separator: ", "))\n"
            }
        }
        
        // Check first page dimensions if available
        if self.pageCount > 0, let firstPage = self.page(at: 0) {
            let mediaBox = firstPage.bounds(for: .mediaBox)
            info += "- First page dimensions: \(mediaBox.width) x \(mediaBox.height) points\n"
            
            // Check for annotations
            let annotations = firstPage.annotations
            if !annotations.isEmpty {
                info += "- First page has \(annotations.count) annotations\n"
            }
        }
        
        return info
    }
    
    /// Print detailed debugging information about this PDF document
    func printDebugInfo() {
        let info = self.debugInfo()
        Swift.print("\n📄 PDF DEBUG: \(info)")
    }
    
    /// Generate a debug report for a PDF document
    func debugReport(label: String) -> String {
        let pageCount = self.pageCount
        let documentAttributes = self.documentAttributes ?? [:]
        let title = documentAttributes[PDFDocumentAttribute.titleAttribute] as? String ?? "Unknown"
        let author = documentAttributes[PDFDocumentAttribute.authorAttribute] as? String ?? "Unknown"
        let creator = documentAttributes[PDFDocumentAttribute.creatorAttribute] as? String ?? "Unknown"
        let fileSize = self.dataRepresentation()?.count ?? 0
        
        return """
        📄 PDF DEBUG REPORT: \(label)
        - Title: \(title)
        - Author: \(author)
        - Creator: \(creator)
        - Page Count: \(pageCount)
        - File Size: \(ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file))
        - Version: \(self.majorVersion).\(self.minorVersion)
        - Is Encrypted: \(self.isEncrypted)
        - Is Locked: \(self.isLocked)
        - Allows Copying: \(self.allowsCopying)
        - Allows Printing: \(self.allowsPrinting)
        """
    }
    
    /// Log comprehensive information about the PDF document to help with troubleshooting
    func logDiagnostics(label: String, file: String = #file, function: String = #function, line: Int = #line) {
        startLogGroup("PDF Diagnostics: \(label)", category: .pdf)
        
        logPDF("Document diagnostics for: \(label)")
        logPDF(debugReport(label: label))
        
        // Check for common PDF issues
        if self.pageCount == 0 {
            logPDF("⚠️ Warning: PDF has zero pages", level: .warning)
        }
        
        if self.isLocked {
            logPDF("🔒 Warning: PDF is locked/secured", level: .warning)
        }
        
        // Check each page for potential rendering issues
        for i in 0..<self.pageCount {
            if let page = self.page(at: i) {
                let pageSize = page.bounds(for: .mediaBox).size
                logPDF("Page \(i+1) size: \(pageSize.width) x \(pageSize.height) points")
                
                if pageSize.width <= 0 || pageSize.height <= 0 {
                    logPDF("⚠️ Warning: Invalid page size on page \(i+1)", level: .warning)
                }
                
                // Check if page has content - using dataRepresentation property correctly
                let pageContent = page.dataRepresentation
                if pageContent == nil || pageContent?.count ?? 0 < 100 {
                    logPDF("⚠️ Warning: Page \(i+1) has minimal content (\(pageContent?.count ?? 0) bytes)", level: .warning)
                }
            } else {
                logPDF("❌ Error: Failed to access page \(i+1)", level: .error)
            }
        }
        
        // Check for text extraction capability
        if let firstPage = self.page(at: 0), firstPage.string?.isEmpty ?? true {
            logPDF("ℹ️ Note: First page has no extractable text. PDF might be scanned or image-based.")
        }
        
        endLogGroup("PDF Diagnostics: \(label)", category: .pdf)
    }
}

extension PDFView {
    /// Log detailed information about this PDF view
    func debugInfo() -> String {
        var info = "PDF View Info:\n"
        info += "- Frame: \(self.frame)\n"
        info += "- Bounds: \(self.bounds)\n"
        info += "- Scale factor: \(self.scaleFactor)\n"
        info += "- Auto scales: \(self.autoScales)\n"
        info += "- Display mode: \(self.displayMode.rawValue)\n"
        info += "- Display direction: \(self.displayDirection.rawValue)\n"
        
        // Document info
        if let document = self.document {
            info += "- Has document: Yes (\(document.pageCount) pages)\n"
            if let currentPage = self.currentPage {
                info += "- Current page: \(document.index(for: currentPage) + 1) of \(document.pageCount)\n"
            } else {
                info += "- Current page: None set\n"
            }
        } else {
            info += "- Has document: No\n"
        }
        
        // Visible pages
        let visiblePages = self.visiblePages
        info += "- Visible pages: \(visiblePages.count)\n"
        for (index, page) in visiblePages.enumerated() {
            if let document = self.document {
                let pageIndex = document.index(for: page)
                info += "  - Visible page \(index + 1): Page \(pageIndex + 1)\n"
            }
        }
        
        return info
    }
    
    /// Print detailed debugging information about this PDF view
    func printDebugInfo() {
        let info = self.debugInfo()
        Swift.print("\n📄 PDF VIEW DEBUG: \(info)")
    }
    
    /// Generate a debug report for a PDFView
    func debugReport(label: String) -> String {
        let document = self.document
        let currentPage = self.currentPage
        let currentPageIndex = currentPage.flatMap { self.document?.index(for: $0) } ?? -1
        let displayBox = self.displayBox
        let displayMode = self.displayMode
        let displayDirection = self.displayDirection
        let scaleFactor = self.scaleFactor
        let visiblePages = self.visiblePages
        
        var report = """
        📄 PDFVIEW DEBUG REPORT: \(label)
        - Has Document: \(document != nil)
        - Current Page Index: \(currentPageIndex >= 0 ? "\(currentPageIndex + 1)" : "None")
        - Display Box: \(displayBox.rawValue)
        - Display Mode: \(displayMode.rawValue)
        - Display Direction: \(displayDirection.rawValue)
        - Scale Factor: \(scaleFactor)
        - Frame: \(self.frame)
        - Visible Pages Count: \(visiblePages.count)
        - Auto Scales: \(self.autoScales)
        """
        
        // Add document info if available
        if let document = document {
            report += "\n\nDocument Info:\n"
            report += "- Page Count: \(document.pageCount)"
            report += "\n- Is Locked: \(document.isLocked)"
        }
        
        // Add visible pages info
        if !visiblePages.isEmpty {
            report += "\n\nVisible Pages:\n"
            for (index, page) in visiblePages.enumerated() {
                if let pageIndex = document?.index(for: page) {
                    report += "- Page \(pageIndex + 1) (visible at position \(index))\n"
                }
            }
        }
        
        return report
    }
    
    /// Log the current state of the PDFView
    func logViewState(label: String, file: String = #file, function: String = #function, line: Int = #line) {
        startLogGroup("PDFView State: \(label)", category: .pdf)
        logPDF(debugReport(label: label))
        
        // Check for common PDFView issues
        if self.document == nil {
            logPDF("❌ Error: No document set on PDFView", level: .error)
        } else if self.document?.pageCount == 0 {
            logPDF("⚠️ Warning: Document has zero pages", level: .warning)
        }
        
        if self.frame.width <= 0 || self.frame.height <= 0 {
            logPDF("⚠️ Warning: PDFView has invalid frame size: \(self.frame.size)", level: .warning)
        }
        
        if self.visiblePages.isEmpty && self.document?.pageCount ?? 0 > 0 {
            logPDF("⚠️ Warning: No visible pages despite document having \(self.document?.pageCount ?? 0) pages", level: .warning)
        }
        
        endLogGroup("PDFView State: \(label)", category: .pdf)
    }
    
    /// Monitor for PDF view rendering issues
    func startRenderingMonitor(label: String, file: String = #file, function: String = #function, line: Int = #line) {
        // Check initial state
        logViewState(label: "\(label) - Initial State")
        
        // Set up a timer to periodically check view state
        let timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                logPDF("PDFView monitor stopped: view was deallocated", level: .debug)
                return
            }
            
            // Only log if there are issues
            if self.document == nil || 
               self.visiblePages.isEmpty || 
               self.frame.width <= 0 || 
               self.frame.height <= 0 {
                self.logViewState(label: "\(label) - Monitoring Update")
            }
        }
        
        // Store the timer somewhere or it will be deallocated
        objc_setAssociatedObject(self, "renderMonitorTimer", timer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        logPDF("Started rendering monitor for PDFView: \(label)")
    }
    
    /// Stop the rendering monitor
    func stopRenderingMonitor() {
        if let timer = objc_getAssociatedObject(self, "renderMonitorTimer") as? Timer {
            timer.invalidate()
            objc_setAssociatedObject(self, "renderMonitorTimer", nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            logPDF("Stopped rendering monitor for PDFView")
        }
    }
}

// MARK: - Helper Functions

/// Log PDF loading progress with timing information
func logPDFLoading(_ message: String, level: PDFLogLevel = .info) {
    let prefix: String
    switch level {
    case .debug:
        prefix = "🔍 PDF DEBUG"
    case .info:
        prefix = "📄 PDF INFO"
    case .warning:
        prefix = "⚠️ PDF WARNING"
    case .error:
        prefix = "❌ PDF ERROR"
    }
    Swift.print("\(prefix): \(message)")
}

/// Log PDF view updates
func logPDFViewUpdate(_ message: String, level: PDFLogLevel = .info) {
    let prefix: String
    switch level {
    case .debug:
        prefix = "🔍 PDF VIEW DEBUG"
    case .info:
        prefix = "📄 PDF VIEW INFO"
    case .warning:
        prefix = "⚠️ PDF VIEW WARNING"
    case .error:
        prefix = "❌ PDF VIEW ERROR"
    }
    Swift.print("\(prefix): \(message)")
}

/// Log levels for PDF debugging
enum PDFLogLevel {
    case debug
    case info
    case warning
    case error
}

// MARK: - Convenience functions for PDF debugging

/// Measure PDF operation performance
func measurePDFOperation<T>(_ operation: String, file: String = #file, function: String = #function, line: Int = #line, block: () throws -> T) rethrows -> T {
    return try DebugLogger.measure(operation, file: file, function: function, line: line, block: block)
}

/// Track PDF loading process with detailed diagnostics
func trackPDFLoading(url: URL, label: String, file: String = #file, function: String = #function, line: Int = #line) -> PDFDocument? {
    startLogGroup("PDF Loading: \(label)", category: .pdf)
    
    // Log file info
    logPDF("PDF Load: Attempting to load PDF: \(label)")
    logPDF("PDF Load: File URL: \(url.path)")
    logPDF("PDF Load: File URL scheme: \(url.scheme ?? "none")")
    logPDF("PDF Load: File URL isFileURL: \(url.isFileURL)")
    
    // Check file size
    if url.isFileURL {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? Int64 {
                let formattedSize = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
                logPDF("PDF Load: File size: \(fileSize) bytes (\(formattedSize))")
            }
        } catch {
            logPDF("PDF Load: Error getting file size: \(error.localizedDescription)", level: .warning)
        }
    }
    
    // Check system memory
    let totalMemory = ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024)
    logPDF("System Memory: Total: \(totalMemory)GB")
    
    // Attempt to create PDF document
    logPDF("PDF Load: Attempting to create PDFDocument from URL...")
    
    let startTime = Date()
    
    // Create the document - removing unnecessary try/catch as PDFDocument init doesn't throw
    let document = measurePDFOperation("Create PDFDocument") {
        PDFDocument(url: url)
    }
    
    let duration = Date().timeIntervalSince(startTime)
    
    if let doc = document {
        logPDF("✅ PDF Load SUCCESS: Created PDFDocument from URL in \(String(format: "%.3f", duration))s")
        logPDF("PDF Details: Page count: \(doc.pageCount)")
        
        // Run more detailed diagnostics
        doc.logDiagnostics(label: label)
    } else {
        logPDF("❌ PDF Load FAILED: Could not create PDFDocument from URL", level: .error)
    }
    
    let totalDuration = Date().timeIntervalSince(startTime)
    logPDF("PDF Total loading time: \(String(format: "%.3f", totalDuration))s")
    
    endLogGroup("PDF Loading: \(label)", category: .pdf)
    
    return document
}

/// Track detailed memory usage during PDF operations
func trackPDFMemoryUsage(operation: String, file: String = #file, function: String = #function, line: Int = #line) {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
    
    let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    
    if kerr == KERN_SUCCESS {
        let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
        logPDF("📊 Memory Usage (\(operation)): \(String(format: "%.2f", usedMB))MB", file: file, function: function, line: line)
    } else {
        logPDF("Failed to get memory usage info", level: .warning, file: file, function: function, line: line)
    }
} 