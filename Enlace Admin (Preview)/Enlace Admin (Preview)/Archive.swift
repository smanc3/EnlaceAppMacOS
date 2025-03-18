//
//  Archive.swift
//  Enlace Admin (Preview)
//
//  Created by Steven Mancilla on 2/25/25.
//

import SwiftUI

struct PopupView3: View {
    @Binding var showPopupArchive: Bool  // Control popup visibility
    @Binding var isSpanish: Bool      // Control language selection

    @State private var eventName: String = ""

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.1)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    showPopupArchive = false
                }

            VStack {
                // Title
                Text(isSpanish ? "Archivar Evento" : "Archive Event")
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
                //    .autocapitalization(.words)
                    .padding()
                }
                .padding([.top, .leading, .trailing], 15.0)

                // DatePicker
                DatePicker(
                    isSpanish ? "Fecha y Hora" : "Date and Time",
                    selection: .constant(Date())
                )
                .padding(.bottom)

                // Archive and Cancel Buttons
                Button(action: {
                    // Archive event logic
                    showPopupArchive = false
                }) {
                    Text(isSpanish ? "Archivar Evento" : "Archive Event")
                       // .foregroundColor(.blue)
                      //  .padding()
                }

                Button(action: {
                    showPopupArchive = false
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
