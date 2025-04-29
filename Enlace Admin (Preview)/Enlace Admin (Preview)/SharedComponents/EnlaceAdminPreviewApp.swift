//
//  EnlaceAdminPreviewApp.swift
//  Enlace Admin (Preview)
//
//  Created by Steven Mancilla on 2/5/25.
//

import SwiftUI

@main
struct EnlaceAdminPreviewApp: App {
    // Create a ConsentManager instance at the app level
    @StateObject private var consentManager = ConsentManager()
    @StateObject private var languageManager = LanguageManager()
    @StateObject private var authManager = AuthenticationManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
                .environmentObject(consentManager) // Pass the ConsentManager to the entire app
                .environmentObject(languageManager) // Pass the LanguageManager to the entire app
                .environmentObject(authManager) // Pass the AuthenticationManager to the entire app
                .preferredColorScheme(.light) // Force light mode for the entire application
        }
        .defaultSize(CGSize(width: 1200, height: 800))
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
} 