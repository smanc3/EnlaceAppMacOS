//
//  TermsOfServiceView.swift
//  Enlace Admin (Preview)
//
//  Created on 2/10/25.
//

import SwiftUI

struct TermsOfServiceView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var consentManager: ConsentManager
    @State private var showDeclineAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Terms of Service")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    termsHeader
                    
                    termsContent
                    
                    acceptanceSection
                }
                .padding()
            }
            
            // Action buttons
            HStack(spacing: 16) {
                Button(action: {
                    showDeclineAlert = true
                }) {
                    Text("Decline")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    consentManager.setTermsConsent(accepted: true)
                    NSLog("Terms of Service accepted")
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Accept")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding()
        }
        .frame(width: 700, height: 600)
        .alert(isPresented: $showDeclineAlert) {
            Alert(
                title: Text("Decline Terms of Service"),
                message: Text("If you decline the Terms of Service, you will not be able to use this application. Are you sure you want to decline?"),
                primaryButton: .destructive(Text("Yes, Decline")) {
                    consentManager.setTermsConsent(accepted: false)
                    NSLog("Terms of Service declined")
                    presentationMode.wrappedValue.dismiss()
                },
                secondaryButton: .cancel(Text("Cancel"))
            )
        }
    }
    
    private var termsHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Please read and accept our Terms of Service")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Last updated: June 15, 2023")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Divider()
        }
    }
    
    private var termsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("1. Acceptance of Terms")
            
            Text("By accessing or using the Enlace Admin application, you agree to be bound by these Terms of Service and all applicable laws and regulations. If you do not agree with any of these terms, you are prohibited from using or accessing this application.")
            
            sectionTitle("2. Use License")
            
            bulletPoint("This application is licensed, not sold, to you by EICT for use strictly in accordance with these terms.")
            bulletPoint("You may not modify, decompile, or create derivative works based upon the application.")
            bulletPoint("You may not transfer the application to another person or 'mirror' the application on any other server.")
            
            sectionTitle("3. User Accounts")
            
            bulletPoint("You are responsible for maintaining the confidentiality of your account and password.")
            bulletPoint("You agree to accept responsibility for all activities that occur under your account.")
            bulletPoint("The application reserves the right to refuse service, terminate accounts, or cancel orders at its discretion.")
            
            sectionTitle("4. Data Management")
            
            bulletPoint("You are responsible for all data you input into the application.")
            bulletPoint("The application will handle data in accordance with our Privacy Policy.")
            bulletPoint("While we strive to protect your data, we cannot guarantee absolute security.")
            
            sectionTitle("5. Limitation of Liability")
            
            Text("In no event shall EICT, its officers, directors, employees, or agents, be liable for any indirect, incidental, special, consequential or punitive damages, including without limitation, loss of profits, data, use, goodwill, or other intangible losses, resulting from your access to or use of or inability to access or use the application.")
            
            sectionTitle("6. Governing Law")
            
            Text("These Terms shall be governed by and construed in accordance with the laws of the United States, without regard to its conflict of law provisions.")
            
            sectionTitle("7. Changes to Terms")
            
            Text("We reserve the right to modify or replace these Terms at any time. We will provide notice of any changes by posting the new Terms on the application. Your continued use of the application after any such changes constitutes your acceptance of the new Terms.")
            
            sectionTitle("8. Contact Us")
            
            Text("If you have any questions about these Terms, please contact us at legal@eict.com")
                .padding(.bottom, 40)
        }
    }
    
    private var acceptanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("By clicking 'Accept', you acknowledge that you have read, understood, and agree to be bound by these Terms of Service.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 16)
        }
    }
    
    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .fontWeight(.bold)
            .padding(.top, 8)
    }
    
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.body)
            
            Text(text)
                .font(.body)
        }
    }
}

#Preview {
    TermsOfServiceView()
        .environmentObject(ConsentManager())
} 