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
                }

                // DatePicker
                DatePicker(
                    isSpanish ? "Fecha y Hora" : "Date and Time",
                    selection: .constant(Date())
                )
                .padding(.bottom)

                // Archive and Cancel Buttons in an HStack
                HStack {
                    // Cancel Button
                    Button(action: {
                        showPopupArchive = false
                    }) {
                        Text(isSpanish ? "Cancelar" : "Cancel")
                       // .foregroundColor(.gray)
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.escape, modifiers: [])
                    
                    Spacer()

                    // Archive Button
                    Button(action: {
                        // Archive event logic
                        showPopupArchive = false
                    }) {
                        Text(isSpanish ? "Archivar Evento" : "Archive Event")
                       // .foregroundColor(.blue)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue) // Keep it blue for archive?
                }
                .padding(.top) // Add some space above buttons
            }
            // Apply standard styling, remove fixed height
            .padding() // Add padding
            .frame(width: 500) // Keep width 500
            // REMOVE fixed height: .frame(width: 500, height: 360)
            .fixedSize(horizontal: false, vertical: true) // Allow vertical resizing
            .background(Color(NSColor.windowBackgroundColor)) // Standard background
            .cornerRadius(12) // Standard radius
            .shadow(radius: 10)
        }
    }
}

#Preview {
    ContentView()
}
