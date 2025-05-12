import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var consentManager: ConsentManager
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false
    @AppStorage("isSpanish") private var isSpanish = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Language / Idioma")) {
                    Toggle(isOn: $isSpanish) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(isSpanish ? "Español" : "Spanish/English")
                                .font(.headline)
                            Text(isSpanish ? "Cambiar a inglés" : "Switch to Spanish")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .onChange(of: isSpanish) { oldValue, newValue in
                        NSLog("Language preference changed to: \(newValue ? "Spanish" : "English")")
                    }
                }
                
                Section(header: Text(isSpanish ? "Gestión de Consentimiento" : "Consent Management")) {
                    Toggle(isOn: $consentManager.hasPrivacyConsent) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(isSpanish ? "Política de Privacidad" : "Privacy Policy")
                                .font(.headline)
                            Text(isSpanish ? "Requerido para usar la aplicación" : "Required to use the application")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .disabled(true) // Privacy consent is required
                    
                    Button(action: {
                        showPrivacyPolicy = true
                    }) {
                        Text(isSpanish ? "Ver Política de Privacidad" : "View Privacy Policy")
                            .foregroundColor(.blue)
                    }
                    
                    Toggle(isOn: $consentManager.hasTermsConsent) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(isSpanish ? "Términos de Servicio" : "Terms of Service")
                                .font(.headline)
                            Text(isSpanish ? "Requerido para usar la aplicación" : "Required to use the application")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .disabled(true) // Terms consent is required
                    
                    Button(action: {
                        showTermsOfService = true
                    }) {
                        Text(isSpanish ? "Ver Términos de Servicio" : "View Terms of Service")
                            .foregroundColor(.blue)
                    }
                }
                
                Section(header: Text(isSpanish ? "Acerca de" : "About")) {
                    HStack {
                        Text(isSpanish ? "Versión" : "Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text(isSpanish ? "Última Actualización de Consentimiento" : "Last Consent Update")
                        Spacer()
                        Text(formattedDate())
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listStyle(DefaultListStyle())
            .navigationTitle(isSpanish ? "Configuración" : "Settings")
            .sheet(isPresented: $showPrivacyPolicy) {
                PrivacyPolicyView()
                    .environmentObject(consentManager)
            }
            .sheet(isPresented: $showTermsOfService) {
                TermsOfServiceView()
                    .environmentObject(consentManager)
            }
        }
    }
    
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
}

#Preview {
    SettingsView()
        .environmentObject(ConsentManager())
} 