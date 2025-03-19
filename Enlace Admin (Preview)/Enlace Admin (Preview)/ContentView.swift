//
//  ContentView.swift
//  Enlace Admin (Preview)
//
//  Created by Steven Mancilla on 2/5/25.
//
import SwiftUI

struct ContentView: View {
    @State private var showPopupCreate = false
    @State private var showPopupDelete = false
    @State private var showPopupArchive = false
    @State private var showPopupSettings = false
    @State private var isSpanish = false  // Language state

    var body: some View {
        HStack {
            Spacer()
            
            VStack(alignment: .leading) {
                Spacer()
                
                Button(isSpanish ? "Crear Evento" : "Create Event", systemImage: "calendar.badge.plus") {
                    showPopupCreate.toggle()
                }
                
                Button(isSpanish ? "Archivar Evento" : "Archive Event", systemImage: "square.and.arrow.down.fill") {
                    showPopupArchive.toggle()
                }
                
                Button(isSpanish ? "Eliminar Evento" : "Delete Event", systemImage: "trash.fill") {
                    showPopupDelete.toggle()
                }
                
                Spacer()
                Spacer()
                Spacer()
                
                Button(isSpanish ? "Configuración" : "Settings", systemImage: "gear") {
                    showPopupSettings.toggle()
                }
                
                Spacer()
            }

            CalendarView(isSpanish: $isSpanish)  // Your calendar view
                .overlay(
                    Group {
                        if showPopupCreate {
                            PopupView(showPopupCreate: $showPopupCreate, isSpanish: $isSpanish)
                        } else if showPopupDelete {
                            PopupView2(showPopupDelete: $showPopupDelete, isSpanish: $isSpanish)
                        } else if showPopupArchive {
                            PopupView3(showPopupArchive: $showPopupArchive, isSpanish: $isSpanish)
                        } else if showPopupSettings {
                            PopupView4(showPopupSettings: $showPopupSettings, isSpanish: $isSpanish)
                        }
                    }
                )

        }
        .background()
      //  .frame(maxWidth: 700, maxHeight: 400)
       // .windowStyle()
    }
        //.controlSize(.regular)
    //    .frame(maxWidth: 500, maxHeight: 600)
}

#Preview {
    ContentView()
}

