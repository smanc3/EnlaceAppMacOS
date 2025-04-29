import Foundation
import SwiftUI

class LanguageManager: ObservableObject {
    // MARK: - Published Properties
    @Published var isSpanish: Bool = false
    
    // MARK: - UserDefaults Keys
    private let languageKey = "isSpanish"
    
    // MARK: - Private Properties
    private let userDefaults: UserDefaults
    
    // MARK: - Initialization
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadLanguagePreference()
        NSLog("LanguageManager initialized - isSpanish: \(isSpanish)")
    }
    
    // MARK: - Public Methods
    public func setLanguage(isSpanish: Bool) {
        NSLog("Setting language preference to: \(isSpanish ? "Spanish" : "English")")
        self.isSpanish = isSpanish
        saveLanguagePreference()
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
} 