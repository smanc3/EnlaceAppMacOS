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

            VStack(spacing: 15) {
                // Title
                Text(isSpanish ? "Archivar Evento" : "Archive Event")
                    .font(.title)
                    .fontWeight(.bold)
                
                ScrollView {
                    VStack(spacing: 12) {
                        // Event Name TextField
                        TextField(
                            isSpanish ? "Nombre del Evento" : "Event Name",
                            text: $eventName
                        )
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                        
                        // DatePicker
                        DatePicker(
                            isSpanish ? "Fecha y Hora" : "Date and Time",
                            selection: .constant(Date())
                        )
                        .datePickerStyle(.compact)
                        .padding(.horizontal)
                    }
                }
                
                // Archive and Cancel Buttons
                HStack {
                    Button(isSpanish ? "Cancelar" : "Cancel") {
                        showPopupArchive = false
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button(isSpanish ? "Archivar" : "Archive") {
                        // Archive logic here
                        showPopupArchive = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(eventName.isEmpty)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .frame(maxWidth: 400, maxHeight: 500)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(12)
            .shadow(radius: 10)
        }
    }
}

#Preview {
    ContentView()
}
