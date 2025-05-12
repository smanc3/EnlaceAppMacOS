import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var consentManager: ConsentManager
    @State private var currentPage = 0
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false
    @AppStorage("isSpanish") private var isSpanish = false
    
    var body: some View {
        VStack {
            // Progress indicator
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(currentPage == index ? Color.blue : Color.gray.opacity(0.5))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 20)
            
            // Page content
            TabView(selection: $currentPage) {
                welcomePage
                    .tag(0)
                
                privacyPolicyPage
                    .tag(1)
                
                termsOfServicePage
                    .tag(2)
            }
            .tabViewStyle(DefaultTabViewStyle())
            
            // Navigation buttons
            HStack {
                if currentPage > 0 {
                    Button(action: {
                        withAnimation {
                            currentPage -= 1
                        }
                    }) {
                        Text(isSpanish ? "Atrás" : "Back")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(10)
                    }
                } else {
                    Spacer()
                }
                
                if currentPage < 2 {
                    Button(action: {
                        withAnimation {
                            currentPage += 1
                        }
                    }) {
                        Text(isSpanish ? "Siguiente" : "Next")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                } else {
                    Button(action: {
                        if consentManager.hasRequiredConsents() {
                            // Proceed to main app
                            NSLog("User completed onboarding with all required consents")
                            consentManager.completeFirstLaunch()
                        } else {
                            // Show alert or feedback that consents are required
                            NSLog("User attempted to complete onboarding without required consents")
                        }
                    }) {
                        Text(isSpanish ? "Comenzar" : "Get Started")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                consentManager.hasRequiredConsents() ? Color.blue : Color.gray
                            )
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(!consentManager.hasRequiredConsents())
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
        .frame(width: 700, height: 600)
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
                .environmentObject(consentManager)
        }
        .sheet(isPresented: $showTermsOfService) {
            TermsOfServiceView()
                .environmentObject(consentManager)
        }
    }
    
    private var welcomePage: some View {
        VStack(spacing: 20) {
            // Language toggle at the top right
            HStack {
                Spacer()
                Picker("Language", selection: $isSpanish) {
                    Text("English").tag(false)
                    Text("Español").tag(true)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
                .onChange(of: isSpanish) { newValue in
                    NSLog("Language changed to: \(newValue ? "Spanish" : "English")")
                }
            }
            .padding(.top, 8)
            Image(systemName: "building.columns.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
                .padding()
            
            Text(isSpanish ? "Bienvenido a Enlace Admin" : "Welcome to Enlace Admin")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text(isSpanish ? "Su solución integral para gestionar eventos comunitarios, recursos y comunicaciones." : "Your all-in-one solution for managing community events, resources, and communications.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 15) {
                featureRow(icon: "calendar", 
                          title: isSpanish ? "Gestión de Eventos" : "Event Management", 
                          description: isSpanish ? "Cree y gestione eventos comunitarios con facilidad" : "Create and manage community events with ease")
                featureRow(icon: "doc.text.fill", 
                          title: isSpanish ? "Biblioteca de Recursos" : "Resource Library", 
                          description: isSpanish ? "Almacene y comparta documentos importantes" : "Store and share important documents")
                featureRow(icon: "bell.fill", 
                          title: isSpanish ? "Notificaciones" : "Notifications", 
                          description: isSpanish ? "Mantenga a su comunidad informada con actualizaciones oportunas" : "Keep your community informed with timely updates")
            }
            .padding()
            
            Spacer()
        }
        .padding()
    }
    
    private var privacyPolicyPage: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.blue)
                .padding()
            
            Text(isSpanish ? "Consentimiento de Privacidad" : "Privacy Consent")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text(isSpanish ? "Valoramos su privacidad y queremos ser transparentes sobre cómo usamos sus datos." : "We value your privacy and want to be transparent about how we use your data.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                
            VStack(alignment: .leading, spacing: 16) {
                Toggle(isOn: $consentManager.hasPrivacyConsent) {
                    VStack(alignment: .leading) {
                        Text(isSpanish ? "Aceptar Política de Privacidad" : "Accept Privacy Policy")
                            .font(.headline)
                        Text(isSpanish ? "Requerido para usar la aplicación" : "Required to use the application")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                
                Button(action: {
                    showPrivacyPolicy = true
                }) {
                    Text(isSpanish ? "Leer Política de Privacidad Completa" : "Read Full Privacy Policy")
                        .underline()
                        .foregroundColor(.blue)
                }
                .padding(.top, 4)
            }
            .padding()
            
            Spacer()
        }
        .padding()
    }
    
    private var termsOfServicePage: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.blue)
                .padding()
            
            Text(isSpanish ? "Términos de Servicio" : "Terms of Service")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text(isSpanish ? "Por favor revise y acepte nuestros Términos de Servicio para continuar." : "Please review and accept our Terms of Service to continue.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 16) {
                Toggle(isOn: Binding(
                    get: { consentManager.hasTermsConsent },
                    set: { newValue in
                        consentManager.setTermsConsent(accepted: newValue)
                        NSLog("Terms of Service toggle changed to: \(newValue)")
                    }
                )) {
                    VStack(alignment: .leading) {
                        Text(isSpanish ? "Aceptar Términos de Servicio" : "Accept Terms of Service")
                            .font(.headline)
                        Text(isSpanish ? "Requerido para usar la aplicación" : "Required to use the application")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                
                Button(action: {
                    showTermsOfService = true
                }) {
                    Text(isSpanish ? "Leer Términos de Servicio Completos" : "Read Full Terms of Service")
                        .underline()
                        .foregroundColor(.blue)
                }
                .padding(.top, 4)
                
                if !consentManager.hasRequiredConsents() {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        
                        Text(isSpanish ? "Debe aceptar tanto la Política de Privacidad como los Términos de Servicio para continuar." : "You must accept both the Privacy Policy and Terms of Service to continue.")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.top, 20)
                }
            }
            .padding()
            
            Spacer()
        }
        .padding()
    }
    
    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(ConsentManager())
} 