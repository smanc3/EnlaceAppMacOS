//
//  Settings.swift
//  Enlace Admin (Preview)
//
//  Created on 2/10/25.
//

import SwiftUI

// Add the DataPreferences struct locally since it's removed from ContentView
struct DataPreferences {
    var allowAccountData: Bool = true
    var allowUsageData: Bool = true
    var allowDeviceData: Bool = true
    var allowThirdPartySharing: Bool = true
}

struct PopupView4: View {
    @Binding var showPopupSettings: Bool
    @EnvironmentObject var languageManager: LanguageManager
    
    // Privacy settings from UserDefaults
    @State private var dataPreferences = DataPreferences()
    
    // State to show privacy and legal popups
    @State private var showPrivacyConsent: Bool = false
    @State private var showLegalTerms: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(languageManager.isSpanish ? "Configuración" : "Settings")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    showPopupSettings = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Language settings section
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(languageManager.isSpanish ? "Idioma" : "Language")
                                .font(.headline)
                            
                            Toggle(isOn: $languageManager.isSpanish) {
                                Text(languageManager.isSpanish ? "Español" : "Spanish")
                            }
                            .toggleStyle(.switch)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(10)
                    
                    // Privacy and Legal section
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(languageManager.isSpanish ? "Privacidad y Legal" : "Privacy & Legal")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 15) {
                                Button(action: {
                                    showPrivacyConsent = true
                                }) {
                                    HStack {
                                        Image(systemName: "hand.raised")
                                        Text(languageManager.isSpanish ? "Configuración de privacidad" : "Privacy Settings")
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                
                                Divider()
                                
                                Button(action: {
                                    showLegalTerms = true
                                }) {
                                    HStack {
                                        Image(systemName: "doc.text")
                                        Text(languageManager.isSpanish ? "Términos de servicio" : "Terms of Service")
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 5)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(10)
                    
                    // Data management section
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(languageManager.isSpanish ? "Gestión de Datos" : "Data Management")
                                .font(.headline)
                            
                            Button(action: {
                                resetUserData()
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                    Text(languageManager.isSpanish ? "Eliminar mis datos" : "Delete My Data")
                                        .foregroundColor(.red)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(10)
                }
                .padding()
            }
        }
        .onAppear {
            loadPrivacySettings()
        }
        .sheet(isPresented: $showPrivacyConsent) {
            PrivacyConsentView()
                .frame(width: 550, height: 450)
        }
        .sheet(isPresented: $showLegalTerms) {
            TermsOfServiceView()
                .frame(width: 550, height: 450)
        }
    }
    
    private func loadPrivacySettings() {
        let defaults = UserDefaults.standard
        dataPreferences.allowAccountData = defaults.bool(forKey: "allowAccountData")
        dataPreferences.allowUsageData = defaults.bool(forKey: "allowUsageData")
        dataPreferences.allowDeviceData = defaults.bool(forKey: "allowDeviceData")
        dataPreferences.allowThirdPartySharing = defaults.bool(forKey: "allowThirdPartySharing")
    }
    
    private func resetUserData() {
        // Show confirmation dialog
        let alert = NSAlert()
        alert.messageText = languageManager.isSpanish ? "¿Estás seguro de que quieres eliminar tus datos?" : "Are you sure you want to delete your data?"
        alert.informativeText = languageManager.isSpanish ? "Esta acción no se puede deshacer." : "This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: languageManager.isSpanish ? "Cancelar" : "Cancel")
        alert.addButton(withTitle: languageManager.isSpanish ? "Eliminar" : "Delete")
        
        let response = alert.runModal()
        
        if response == .alertSecondButtonReturn {
            // Reset all privacy settings
            let defaults = UserDefaults.standard
            defaults.set(false, forKey: "allowAccountData")
            defaults.set(false, forKey: "allowUsageData")
            defaults.set(false, forKey: "allowDeviceData")
            defaults.set(false, forKey: "allowThirdPartySharing")
            
            // Reset our local data preferences
            dataPreferences = DataPreferences(
                allowAccountData: false,
                allowUsageData: false,
                allowDeviceData: false,
                allowThirdPartySharing: false
            )
            
            // Show confirmation
            let confirmAlert = NSAlert()
            confirmAlert.messageText = languageManager.isSpanish ? "Datos eliminados" : "Data Deleted"
            confirmAlert.informativeText = languageManager.isSpanish ? "Tus datos han sido eliminados exitosamente." : "Your data has been successfully deleted."
            confirmAlert.alertStyle = .informational
            confirmAlert.runModal()
        }
    }
}

#Preview {
    PopupView4(showPopupSettings: .constant(true))
        .environmentObject(LanguageManager())
}
