import Foundation
import SwiftUI

class LanguageManager: ObservableObject {
    // MARK: - Static shared instance
    static let shared = LanguageManager()
    
    // MARK: - Published Properties
    @Published var isSpanish: Bool = false
    
    // MARK: - UserDefaults Keys
    private let languageKey = "isSpanish"
    
    // MARK: - Private Properties
    private let userDefaults: UserDefaults
    
    // MARK: - Date Formatter
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = isSpanish ? Locale(identifier: "es_ES") : Locale(identifier: "en_US")
        return formatter
    }()
    
    // MARK: - Initialization
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadLanguagePreference()
        NSLog("LanguageManager initialized - isSpanish: \(isSpanish)")
        NSLog("LanguageManager Locale - Current locale: \(isSpanish ? "es_ES" : "en_US")")
    }
    
    // MARK: - Public Methods
    public func setLanguage(isSpanish: Bool) {
        NSLog("Setting language preference to: \(isSpanish ? "Spanish" : "English")")
        self.isSpanish = isSpanish
        saveLanguagePreference()
        updateDateFormatterLocale()
        
        // Log current locale information for debugging
        NSLog("LanguageManager Locale - Updated to: \(isSpanish ? "es_ES" : "en_US")")
        
        // Log an example date formatting to verify
        let exampleDate = Date()
        let formattedDate = formatDate(exampleDate)
        NSLog("LanguageManager Date Format - Example date: \(formattedDate)")
    }
    
    public func formatDate(_ date: Date, style: DateFormatter.Style = .medium) -> String {
        dateFormatter.dateStyle = style
        dateFormatter.timeStyle = .none
        let formattedResult = dateFormatter.string(from: date)
        NSLog("LanguageManager formatDate - Using locale: \(dateFormatter.locale?.identifier ?? "unknown"), result: \(formattedResult)")
        return formattedResult
    }
    
    public func formatDateTime(_ date: Date, dateStyle: DateFormatter.Style = .medium, timeStyle: DateFormatter.Style = .short) -> String {
        dateFormatter.dateStyle = dateStyle
        dateFormatter.timeStyle = timeStyle
        let formattedResult = dateFormatter.string(from: date)
        NSLog("LanguageManager formatDateTime - Using locale: \(dateFormatter.locale?.identifier ?? "unknown"), result: \(formattedResult)")
        return formattedResult
    }
    
    // MARK: - Private Methods
    private func loadLanguagePreference() {
        NSLog("Loading language preference from UserDefaults")
        isSpanish = userDefaults.bool(forKey: languageKey)
    }
    
    private func saveLanguagePreference() {
        NSLog("Saving language preference to UserDefaults")
        userDefaults.set(isSpanish, forKey: languageKey)
    }
    
    private func updateDateFormatterLocale() {
        let newLocale = isSpanish ? Locale(identifier: "es_ES") : Locale(identifier: "en_US")
        dateFormatter.locale = newLocale
        NSLog("LanguageManager Locale - Updated formatter locale to: \(newLocale.identifier)")
    }
} 