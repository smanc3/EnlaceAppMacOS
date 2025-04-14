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

            VStack(spacing: 15) {
                // Title
                Text(isSpanish ? "Eliminar Evento" : "Delete Event")
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
                
                // Delete and Cancel Buttons
                HStack {
                    Button(isSpanish ? "Cancelar" : "Cancel") {
                        showPopupDelete = false
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button(isSpanish ? "Eliminar" : "Delete") {
                        // Delete logic here
                        showPopupDelete = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
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


