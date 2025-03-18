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
               //     .autocapitalization(.words)
                    .padding()
                }
                .padding([.top, .leading, .trailing], 15.0)

                // DatePicker
                DatePicker(
                    isSpanish ? "Fecha y Hora" : "Date and Time",
                    selection: .constant(Date())
                )
                .padding(.bottom)

                // Delete and Cancel Buttons
                Button(action: {
                    // Logic for deleting event
                    showPopupDelete = false
                }) {
                    Text(isSpanish ? "Eliminar Evento" : "Delete Event")
                        .foregroundColor(.red)
                       // .padding()
                }

                Button(action: {
                    showPopupDelete = false
                }) {
                    Text(isSpanish ? "Cancelar" : "Cancel")
                       // .foregroundColor(.gray)
                       // .padding()
                }
            }
            .frame(width: 450, height: 360)
            .background()
            .cornerRadius(15)
            .shadow(radius: 10)
        }
    }
}

#Preview {
    ContentView()
}


