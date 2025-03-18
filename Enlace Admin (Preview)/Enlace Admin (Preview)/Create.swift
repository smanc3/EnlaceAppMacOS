//
//  Create.swift
//  Enlace Admin (Preview)
//
//  Created by Steven Mancilla on 2/11/25.
//

import SwiftUI

struct PopupView: View {
    @Binding var showPopupCreate: Bool  // Control popup visibility
    @Binding var isSpanish: Bool      // Control language selection

    @State private var eventName: String = ""
    @State private var eventLocation: String = ""
    @State private var link: String = ""
    
    @State private var showAlert = false  // Alert for validation errors
    @State private var alertMessage = ""

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.1)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    showPopupCreate = false
                }

            VStack {
                // Title
                Text(isSpanish ? "Crear Evento" : "Create Event")
                    .font(.largeTitle)
                    .padding(.bottom)
                    .fontWeight(.bold)

                Form {
                                    // Event Name (Required)
                                    TextField(
                                        text: $eventName,
                                        prompt: Text(isSpanish ? "Requerido" : "Required")
                                    ) {
                                        Text(isSpanish ? "Nombre del Evento" : "Event Name")
                                    }
                               //     .autocapitalization(.words)

                                    // Event Location (Required)
                                    TextField(
                                        text: $eventLocation,
                                        prompt: Text(isSpanish ? "Requerido" : "Required")
                                    ) {
                                        Text(isSpanish ? "Ubicación del Evento" : "Event Location")
                                    }
                                //    .autocapitalization(.words)

                                    // Link (Optional)
                                    TextField(
                                        text: $link,
                                        prompt: Text(isSpanish ? "No obligatorio" : "Not Required")
                                    ) {
                                        Text(isSpanish ? "Enlace" : "Link")
                                    }
                                //    .autocapitalization(.none)
                                }
                                .padding([.top, .leading, .trailing], 15)

                // DatePicker
                DatePicker(
                    isSpanish ? "Fecha y Hora" : "Date and Time",
                    selection: .constant(Date())
                )
                .padding(.bottom)

                // Attach Poster Button
                Button(isSpanish ? "Adjuntar Cartel" : "Attach Poster") {
                    // Action for attaching poster
                }
                .padding(.bottom)

                // Draft and Post Buttons
                HStack {
                    Button(isSpanish ? "Guardar Borrador" : "Draft Event") {
                        if validateFields() {
                            // Action for Draft Event
                        } else {
                            showAlert = true
                        }
                    }

                    Button(isSpanish ? "Publicar Evento" : "Post Event") {
                        if validateFields() {
                            // Action for Posting Event
                        } else {
                            showAlert = true
                        }
                    }
                }
                .padding(.bottom)

                // Cancel Button
                Button(action: {
                    showPopupCreate = false
                }) {
                    Text(isSpanish ? "Cancelar" : "Cancel")
                      //  .foregroundColor(.red)
                }
            }
            .frame(width: 450, height: 360)
            .background()
            .cornerRadius(15)
            .shadow(radius: 10)
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text(isSpanish ? "Error" : "Error"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text(isSpanish ? "Cerrar" : "Close"))
                )
            }
        }
    }
    
    // Validation Logic
    private func validateFields() -> Bool {
        if eventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            alertMessage = isSpanish ? "El nombre del evento es obligatorio." : "Event name is required."
            return false
        }
        
        if eventLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            alertMessage = isSpanish ? "La ubicación del evento es obligatoria." : "Event location is required."
            return false
        }
        
        return true
    }
}

#Preview {
    ContentView()
}

