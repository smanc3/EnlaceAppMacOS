//
//  Delete.swift
//  Enlace Admin (Preview)
//
//  Created by Steven Mancilla on 2/25/25.
//

import SwiftUI

struct PopupView2: View {
    @Binding var showPopupDelete: Bool  // Control popup visibility
    @Binding var isSpanish: Bool      // Control language selection

    @State private var eventName: String = ""

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.1)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    showPopupDelete = false
                }

            VStack {
                // Title
                Text(isSpanish ? "Eliminar Evento" : "Delete Event")
                    .font(.largeTitle)
                    .padding(.bottom)
                    .fontWeight(.bold)

                Form {
                    // Event Name TextField
                    TextField(
                        text: $eventName,
                        prompt: Text(isSpanish ? "Requerido" : "Required")
                    ) {
                        Text(isSpanish ? "Nombre del Evento" : "Event Name")
                    }
                    // Remove inner padding, let Form handle it
                    // .padding()
                }
                // Remove outer padding for Form, rely on main VStack padding
                // .padding([.top, .leading, .trailing], 15.0)

                // DatePicker
                DatePicker(
                    isSpanish ? "Fecha y Hora" : "Date and Time",
                    selection: .constant(Date())
                )
                // Keep some bottom padding to separate from buttons
                .padding(.bottom)

                // Delete and Cancel Buttons in an HStack
                HStack {
                    // Cancel Button
                    Button(action: {
                        showPopupDelete = false
                    }) {
                        Text(isSpanish ? "Cancelar" : "Cancel")
                           // .foregroundColor(.gray)
                    }
                    .buttonStyle(.bordered) // Add border for visual separation
                    .keyboardShortcut(.escape, modifiers: []) // Allow Esc to cancel
                    
                    Spacer()
                    
                    // Delete Button
                    Button(action: {
                        // Logic for deleting event
                        showPopupDelete = false
                    }) {
                        Text(isSpanish ? "Eliminar Evento" : "Delete Event")
                            .foregroundColor(.white) // White text on red
                    }
                    .buttonStyle(.borderedProminent) // Prominent style
                    .tint(.red) // Red background
                }
                .padding(.top) // Add some space above buttons
            }
            .padding()
            .frame(width: 500)
            .fixedSize(horizontal: false, vertical: true)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(12)
            .shadow(radius: 10)
        }
    }
}

#Preview {
    ContentView()
}


