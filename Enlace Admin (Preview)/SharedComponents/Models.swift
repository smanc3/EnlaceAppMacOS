import Foundation
import CloudKit
import PDFKit
import AppKit  // Add this for NSImage

// MARK: - Calendar Event Model
public struct CalendarEvent: Identifiable {
    public let id: String
    public let recordID: CKRecord.ID
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let location: String?
    public let notes: String?
    public let pdfReference: CKRecord.Reference?
    public var isArchived: Bool
    public let archiveDate: Date?
    public let linkURL: URL?  // New property for clickable links
    
    // Recurrence properties from CloudKit schema
    public let isRecurrenceSeries: Bool
    public let isRecurring: Bool
    public let recurrenceCount: Int?
    public let recurrenceEndType: String?
    public let recurrenceParent: CKRecord.Reference?
    public let recurrenceType: String?
    public let recurrenceWeekdays: String?
    
    // Additional debug helpers
    public var pdfRecord: CKRecord? = nil
    public var pdfURL: URL? = nil
    
    public init(record: CKRecord) {
        if let mirror = record["recordNameMirror"] as? String {
            self.id = mirror
        } else {
            self.id = record.recordID.recordName
        }
        
        self.recordID = record.recordID
        self.title = record["title"] as? String ?? "Untitled Event"
        self.startDate = record["startDate"] as? Date ?? Date()
        self.endDate = record["endDate"] as? Date ?? Date()
        self.location = record["location"] as? String
        self.notes = record["notes"] as? String
        self.pdfReference = record["pdfReference"] as? CKRecord.Reference
        
        // Handle isArchived field
        if let isArchivedValue = record["isArchived"] as? Int64 {
            self.isArchived = isArchivedValue == 1
        } else {
            self.isArchived = false
        }
        
        self.archiveDate = record["archiveDate"] as? Date
        
        // Initialize link URL if present
        if let linkString = record["linkURL"] as? String, !linkString.isEmpty {
            self.linkURL = URL(string: linkString)
        } else {
            self.linkURL = nil
        }
        
        // Initialize recurrence fields from schema
        if let isRecurrenceSeriesValue = record["isRecurrenceSeries"] as? Int64 {
            self.isRecurrenceSeries = isRecurrenceSeriesValue == 1
        } else {
            self.isRecurrenceSeries = false
        }
        
        if let isRecurringValue = record["isRecurring"] as? Int64 {
            self.isRecurring = isRecurringValue == 1
        } else {
            self.isRecurring = false
        }
        
        if let recurrenceCountValue = record["recurrenceCount"] as? Int64 {
            self.recurrenceCount = Int(recurrenceCountValue)
        } else {
            self.recurrenceCount = nil
        }
        
        self.recurrenceEndType = record["recurrenceEndType"] as? String
        self.recurrenceParent = record["recurrenceParent"] as? CKRecord.Reference
        self.recurrenceType = record["recurrenceType"] as? String
        self.recurrenceWeekdays = record["recurrenceWeekdays"] as? String
        
        print("Created CalendarEvent with ID: \(self.id), title: \(self.title)")
    }
}

// MARK: - PDF Document Details Model
public struct ModelsPDFDocumentDetails: Identifiable {
    public let id = UUID()
    public let recordID: CKRecord.ID
    public let title: String
    public let pdfAsset: CKAsset?
    public let dateUploaded: Date?
    public let fileURL: URL?
    
    public init(record: CKRecord) {
        self.recordID = record.recordID
        self.title = record["title"] as? String ?? "Untitled Document"
        // Support both field names for backward compatibility
        self.pdfAsset = (record["pdfFile"] as? CKAsset) ?? (record["pdfAsset"] as? CKAsset)
        self.dateUploaded = record["dateCreated"] as? Date
        // Support both field names for backward compatibility
        self.fileURL = ((record["pdfFile"] as? CKAsset) ?? (record["pdfAsset"] as? CKAsset))?.fileURL
    }
    
    public func generateThumbnail(completion: @escaping (NSImage?) -> Void) {
        guard let url = fileURL else {
            completion(nil)
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            if let pdfDocument = PDFKit.PDFDocument(url: url), 
               let pdfPage = pdfDocument.page(at: 0) {
                let pageImage = pdfPage.thumbnail(of: NSSize(width: 240, height: 320), for: .mediaBox)
                DispatchQueue.main.async {
                    completion(pageImage)
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
}

// MARK: - Archived News Post Model
// Make the struct conform to Hashable for List selection binding
public struct ModelsArchivedNewsPost: Identifiable, Hashable, @unchecked Sendable { 
    public let id: CKRecord.ID // Already suitable for Identifiable & Hashable
    public let title: String
    public let description: String // Added description field
    public let datePosted: Date
    public let archivedDate: Date
    public let pdfReference: CKRecord.Reference?
    public var pdfDocument: ModelsPDFDocumentDetails?
    public let recordNameMirror: String
    public let linkURL: URL?  
    
    // Explicitly conform to Hashable using the id
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Explicitly conform to Equatable (needed for Hashable) using the id
    public static func == (lhs: ModelsArchivedNewsPost, rhs: ModelsArchivedNewsPost) -> Bool {
        lhs.id == rhs.id
    }
    
    public init(record: CKRecord) {
        self.id = record.recordID
        self.title = record["title"] as? String ?? "Untitled"
        
        // Get description from "content" field, or fallback to empty string
        self.description = record["content"] as? String ?? ""
        
        self.datePosted = record["datePosted"] as? Date ?? Date()
        self.archivedDate = record["archivedDate"] as? Date ?? Date()
        self.pdfReference = record["pdfReference"] as? CKRecord.Reference
        self.recordNameMirror = record["recordNameMirror"] as? String ?? record.recordID.recordName
        self.pdfDocument = nil
        
        // Initialize link URL if present
        if let linkString = record["linkURL"] as? String, !linkString.isEmpty {
            self.linkURL = URL(string: linkString)
        } else {
            self.linkURL = nil
        }
    }
} 