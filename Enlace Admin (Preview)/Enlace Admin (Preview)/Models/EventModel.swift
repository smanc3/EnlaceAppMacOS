import SwiftUI
import CloudKit
import CoreLocation

// MARK: - Event Status
enum EventStatus: String {
    case upcoming = "Upcoming"
    case past = "Past"
    case archived = "Archived"
}

// MARK: - Event Type
enum EventType: String {
    case general = "General"
    case special = "Special"
    case holiday = "Holiday"
}

// MARK: - Event Location
struct EventLocation {
    let name: String
    let address: String
    let coordinates: CLLocationCoordinate2D?
}

// MARK: - Event Time
struct EventTime {
    let startTime: Date
    let endTime: Date?
    let isAllDay: Bool
} 