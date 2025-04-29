//
//  PrivacyPolicyView.swift
//  Enlace Admin (Preview)
//
//  Created on 2/10/25.
//

import SwiftUI
import Combine

struct PrivacyPolicyView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var consentManager: ConsentManager
    @State private var showDeclineAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Privacy Policy")
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
                    privacyHeader
                    
                    privacyContent
                    
                    consentOptions
                }
                .padding()
            }
            
            // Action buttons
            HStack(spacing: 16) {
                Button(action: {
                    consentManager.setPrivacyConsent(accepted: true)
                    NSLog("Privacy Policy accepted - consent granted")
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Accept All")
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
                title: Text("Decline Privacy Policy"),
                message: Text("If you decline the Privacy Policy, you will not be able to use this application. Are you sure you want to decline?"),
                primaryButton: .destructive(Text("Yes, Decline")) {
                    consentManager.setPrivacyConsent(accepted: false)
                    NSLog("Privacy Policy declined - consent denied")
                    presentationMode.wrappedValue.dismiss()
                },
                secondaryButton: .cancel(Text("Cancel"))
            )
        }
    }
    
    private var privacyHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Please review our Privacy Policy")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Last updated: June 15, 2023")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Divider()
        }
    }
    
    private var privacyContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("1. Information We Collect")
            
            Text("We collect information to provide better services to our users. The types of information we collect include:")
            
            bulletPoint("Account information: Email address, name, and password")
            bulletPoint("Usage data: How you interact with our application, including features used and time spent")
            bulletPoint("Device information: Hardware model, operating system, and unique device identifiers")
            bulletPoint("Location data: If enabled, we collect your approximate location to provide location-based services")
            
            sectionTitle("2. How We Use Your Information")
            
            bulletPoint("To provide and maintain our services")
            bulletPoint("To notify you about changes to our application")
            bulletPoint("To allow you to participate in interactive features")
            bulletPoint("To provide customer support")
            bulletPoint("To gather analysis or valuable information to improve our services")
            bulletPoint("To monitor the usage of our application")
            
            sectionTitle("3. Data Storage and Security")
            
            Text("We implement appropriate technical and organizational measures to protect your personal data against accidental or unlawful destruction, loss, alteration, unauthorized disclosure, or access. However, no method of transmission over the internet or electronic storage is 100% secure.")
            
            sectionTitle("4. Sharing Your Information")
            
            Text("We do not sell, trade, or rent your personal information to third parties. We may share generic aggregated demographic information not linked to any personal identification information with our business partners and trusted affiliates.")
            
            sectionTitle("5. Your Privacy Rights")
            
            bulletPoint("Access: You can request access to your personal data")
            bulletPoint("Rectification: You can request correction of inaccurate data")
            bulletPoint("Erasure: You can request deletion of your data under certain circumstances")
            bulletPoint("Restriction: You can request restriction of processing of your data")
            bulletPoint("Objection: You can object to processing of your data")
            bulletPoint("Data Portability: You can request a copy of your data in a machine-readable format")
            
            sectionTitle("6. Cookies and Similar Technologies")
            
            Text("We use cookies and similar tracking technologies to track activity on our application and hold certain information. You can instruct your browser to refuse all cookies or to indicate when a cookie is being sent.")
            
            sectionTitle("7. Children's Privacy")
            
            Text("Our application does not address anyone under the age of 13. We do not knowingly collect personally identifiable information from children under 13.")
            
            sectionTitle("8. Changes to This Privacy Policy")
            
            Text("We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the \"last updated\" date.")
            
            sectionTitle("9. Contact Us")
            
            Text("If you have any questions about this Privacy Policy, please contact us at privacy@eict.com")
                .padding(.bottom, 20)
        }
    }
    
    private var consentOptions: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Consent Options")
                .font(.headline)
                .fontWeight(.bold)
            
            Text("By accepting this privacy policy, you consent to the collection and use of your information as described above. You can withdraw your consent at any time through the settings menu.")
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
        .cornerRadius(10)
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
    PrivacyPolicyView()
        .environmentObject(ConsentManager())
} 