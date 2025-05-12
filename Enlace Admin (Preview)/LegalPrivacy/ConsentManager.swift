//
//  ConsentManager.swift
//  Enlace Admin (Preview)
//
//  Created on 2/10/25.
//

import Foundation
import SwiftUI
import Combine

class ConsentManager: ObservableObject {
    // MARK: - Published Properties
    @Published var hasPrivacyConsent: Bool = false
    @Published var hasTermsConsent: Bool = false
    @Published var isFirstLaunch: Bool = true
    
    // MARK: - UserDefaults Keys
    private let privacyConsentKey = "hasPrivacyConsent"
    private let termsConsentKey = "hasTermsConsent"
    private let firstLaunchKey = "isFirstLaunch"
    
    // MARK: - Private Properties
    private let userDefaults: UserDefaults
    
    // MARK: - Initialization
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadPreferences()
        NSLog("ConsentManager initialized - Privacy consent: \(hasPrivacyConsent), Terms consent: \(hasTermsConsent), First launch: \(isFirstLaunch)")
        
        // Log more detailed debug info
        NSLog("UserDefaults at initialization:")
        NSLog(" - privacyConsentKey: \(userDefaults.bool(forKey: privacyConsentKey))")
        NSLog(" - termsConsentKey: \(userDefaults.bool(forKey: termsConsentKey))")
        NSLog(" - firstLaunchKey: \(userDefaults.bool(forKey: firstLaunchKey))")
    }
    
    // MARK: - Public Methods
    public func setPrivacyConsent(accepted: Bool) {
        NSLog("Setting privacy consent to: \(accepted)")
        hasPrivacyConsent = accepted
        savePreferences()
    }
    
    public func setTermsConsent(accepted: Bool) {
        NSLog("Setting terms consent to: \(accepted)")
        hasTermsConsent = accepted
        savePreferences()
    }
    
    public func hasRequiredConsents() -> Bool {
        let requiredConsentsGiven = hasPrivacyConsent && hasTermsConsent
        NSLog("Checking required consents: \(requiredConsentsGiven)")
        return requiredConsentsGiven
    }
    
    public func completeFirstLaunch() {
        NSLog("Marking first launch as complete")
        isFirstLaunch = false
        savePreferences()
    }
    
    public func resetAllConsents() {
        NSLog("Resetting all consent settings")
        hasPrivacyConsent = false
        hasTermsConsent = false
        isFirstLaunch = true
        savePreferences()
    }
    
    // MARK: - Private Methods
    private func loadPreferences() {
        NSLog("Loading consent preferences from UserDefaults")
        hasPrivacyConsent = userDefaults.bool(forKey: privacyConsentKey)
        hasTermsConsent = userDefaults.bool(forKey: termsConsentKey)
        isFirstLaunch = !userDefaults.bool(forKey: firstLaunchKey) // Inverse logic: if firstLaunchKey is false, this is first launch
    }
    
    private func savePreferences() {
        NSLog("Saving consent preferences to UserDefaults")
        userDefaults.set(hasPrivacyConsent, forKey: privacyConsentKey)
        userDefaults.set(hasTermsConsent, forKey: termsConsentKey)
        userDefaults.set(!isFirstLaunch, forKey: firstLaunchKey) // Inverse logic: save true if not first launch
    }
}

// MARK: - Preference Key for Scroll Position
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
} 
