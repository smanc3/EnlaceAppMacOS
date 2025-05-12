//
//  PrivacyConsentView.swift
//  Enlace Admin (Preview)
//
//  Created on 2/10/25.
//

import SwiftUI
import CloudKit

struct PrivacyConsentView: View {
    @EnvironmentObject var consentManager: ConsentManager
    @State private var showAdvancedSettings = false
    @State private var analyticsConsent = true
    @State private var locationConsent = true
    @State private var notificationsConsent = true
    @State private var showDeclineConfirmation = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Privacy Consent")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.bottom, 10)
            
            // Scrollable content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Data Collection and Usage")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text("Enlace Admin collects the following data to provide you with a better experience:")
                    
                    dataCollectionSection
                    
                    Text("How We Use Your Data")
                        .font(.headline)
                        .fontWeight(.bold)
                        .padding(.top, 10)
                    
                    dataUsageSection
                    
                    Text("Your Rights")
                        .font(.headline)
                        .fontWeight(.bold)
                        .padding(.top, 10)
                    
                    userRightsSection
                    
                    if showAdvancedSettings {
                        advancedSettingsSection
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            
            // Action Buttons
            HStack(spacing: 20) {
                Button {
                    showAdvancedSettings.toggle()
                } label: {
                    Text(showAdvancedSettings ? "Hide Advanced Settings" : "Advanced Settings")
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
                
                Spacer()
                
                Button {
                    showDeclineConfirmation = true
                } label: {
                    Text("Decline")
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.red)
                        .cornerRadius(8)
                }
                
                Button {
                    consentManager.setPrivacyConsent(accepted: true)
                } label: {
                    Text("Accept")
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.green)
                        .cornerRadius(8)
                }
            }
            .padding(.top, 10)
        }
        .padding()
        .alert(isPresented: $showDeclineConfirmation) {
            Alert(
                title: Text("Limited Functionality"),
                message: Text("Declining consent may limit app functionality. Some features require data access to work properly."),
                primaryButton: .destructive(Text("Decline Anyway")) {
                    consentManager.setPrivacyConsent(accepted: false)
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    private var dataCollectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            bulletPoint("Calendar data: Event details including titles, dates, times, locations, and notes")
            bulletPoint("User information: Name, role, and organizational affiliation")
            bulletPoint("Usage analytics: How you interact with the app's features")
            bulletPoint("Location data: When accessing location-based features")
            bulletPoint("Device information: OS version, device type, and app version")
        }
    }
    
    private var dataUsageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            bulletPoint("Provide calendar management and event coordination")
            bulletPoint("Improve app functionality and user experience")
            bulletPoint("Troubleshoot issues and debug problems")
            bulletPoint("Provide relevant notifications about events")
            bulletPoint("Comply with legal requirements and enforce our terms")
        }
    }
    
    private var userRightsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            bulletPoint("Access your data at any time")
            bulletPoint("Request correction of inaccurate data")
            bulletPoint("Request deletion of your data")
            bulletPoint("Withdraw consent at any time through app settings")
            bulletPoint("Receive a copy of your data upon request")
        }
    }
    
    private var advancedSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Granular Consent Options")
                .font(.headline)
                .fontWeight(.bold)
                .padding(.top, 10)
            
            Toggle("Analytics data collection", isOn: $analyticsConsent)
                .padding(.vertical, 5)
            
            Toggle("Location data access", isOn: $locationConsent)
                .padding(.vertical, 5)
            
            Toggle("Push notifications", isOn: $notificationsConsent)
                .padding(.vertical, 5)
            
            Text("You can change these settings later in the app's Privacy settings.")
                .font(.footnote)
                .foregroundColor(.gray)
                .padding(.top, 5)
        }
    }
    
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top) {
            Text("•")
                .font(.body)
                .foregroundColor(.blue)
            Text(text)
                .font(.body)
            Spacer()
        }
    }
}

// MARK: - Preview
struct PrivacyConsentView_Previews: PreviewProvider {
    static var previews: some View {
        PrivacyConsentView()
            .environmentObject(ConsentManager())
    }
} 