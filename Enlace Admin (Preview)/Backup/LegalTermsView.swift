//
//  LegalTermsView.swift
//  Enlace Admin (Preview)
//
//  
//

import SwiftUI

struct LegalTermsView: View {
    @Binding var isSpanish: Bool
    @Binding var isPresented: Bool
    var onAccept: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text(isSpanish ? "Términos de Servicio" : "Terms of Service")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.blue)
                .padding(.top, 5)
            
            // Main content
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    Text(isSpanish ? 
                        "Al utilizar Enlace, aceptas acatar nuestros términos y condiciones. Estos términos rigen tu uso de la aplicación y todos los servicios relacionados." : 
                        "By using Enlace, you agree to abide by our terms and conditions. These terms govern your use of the application and all related services.")
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text(isSpanish ? "Puntos clave:" : "Key points:")
                        .font(.headline)
                        .padding(.top, 5)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text(isSpanish ? 
                            "• Debes ser un administrador autorizado para usar esta aplicación" : 
                            "• You must be an authorized administrator to use this application")
                        
                        Text(isSpanish ? 
                            "• Eres responsable de mantener la confidencialidad de tu cuenta" : 
                            "• You are responsible for maintaining the confidentiality of your account")
                        
                        Text(isSpanish ? 
                            "• Aceptas no hacer un mal uso del servicio ni interferir con otros usuarios" : 
                            "• You agree not to misuse the service or interfere with other users")
                        
                        Text(isSpanish ? 
                            "• Nos reservamos el derecho de modificar estos términos en cualquier momento" : 
                            "• We reserve the right to modify these terms at any time")
                    }
                    .padding(.horizontal)
                    
                    Text(isSpanish ? 
                        "Para consultar los términos completos, visita nuestra página web." : 
                        "For the complete terms, please visit our website.")
                        .padding(.top, 5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal)
            }
            
            // Buttons
            HStack(spacing: 15) {
                Button(action: {
                    // Open a browser with full terms
                    let url = URL(string: "https://example.com/terms")!
                    NSWorkspace.shared.open(url)
                }) {
                    Text(isSpanish ? "Ver Términos Completos" : "View Full Terms")
                        .frame(minWidth: 150)
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button(action: {
                    saveAcceptance()
                    onAccept()
                }) {
                    Text(isSpanish ? "Aceptar" : "Accept")
                        .frame(minWidth: 100)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
            .padding(.horizontal)
            .padding(.bottom, 15)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private func saveAcceptance() {
        // Save terms acceptance to UserDefaults
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "hasAcceptedTerms")
        defaults.set(Date(), forKey: "termsAcceptanceDate")
    }
}

#Preview {
    LegalTermsView(
        isSpanish: .constant(false),
        isPresented: .constant(true),
        onAccept: {}
    )
} 
