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
    @State private var showPopupNewsFeed = false
    @State private var isSpanish = false  // Language state
    
    // Function to ensure only one popup is shown at a time
    private func showPopup(_ popup: inout Bool) {
        // Close all other popups
        if popup != showPopupCreate { showPopupCreate = false }
        if popup != showPopupDelete { showPopupDelete = false }
        if popup != showPopupArchive { showPopupArchive = false }
        if popup != showPopupSettings { showPopupSettings = false }
        if popup != showPopupNewsFeed { showPopupNewsFeed = false }
        
        // Toggle the selected popup
        popup.toggle()
    }

    var body: some View {
        HStack {
            Spacer()
            
            VStack(alignment: .leading) {
                Spacer()
                
                // News Feed Section - Visually distinct
                VStack(alignment: .leading, spacing: 5) {
                    Text(isSpanish ? "Gestión de Noticias" : "News Management")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 5)
                    
                    Button(isSpanish ? "Publicar en Noticias" : "Post to News Feed", systemImage: "doc.text.fill") {
                        showPopup(&showPopupNewsFeed)
                    }
                    .foregroundColor(showPopupNewsFeed ? .white : .blue)
                    .background(showPopupNewsFeed ? Color.blue.opacity(0.7) : Color.clear)
                    .cornerRadius(6)
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                .cornerRadius(10)
                .padding(.bottom, 20)
                
                // Event Management Section - Grouped together
                VStack(alignment: .leading, spacing: 5) {
                    Text(isSpanish ? "Gestión de Eventos" : "Event Management")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 5)
                    
                    Button(isSpanish ? "Crear Evento" : "Create Event", systemImage: "calendar.badge.plus") {
                        showPopup(&showPopupCreate)
                    }
                    .foregroundColor(showPopupCreate ? .white : .primary)
                    .background(showPopupCreate ? Color.blue.opacity(0.7) : Color.clear)
                    .cornerRadius(6)
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 8)
                    
                    Button(isSpanish ? "Archivar Evento" : "Archive Event", systemImage: "square.and.arrow.down.fill") {
                        showPopup(&showPopupArchive)
                    }
                    .foregroundColor(showPopupArchive ? .white : .primary)
                    .background(showPopupArchive ? Color.blue.opacity(0.7) : Color.clear)
                    .cornerRadius(6)
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 8)
                    
                    Button(isSpanish ? "Eliminar Evento" : "Delete Event", systemImage: "trash.fill") {
                        showPopup(&showPopupDelete)
                    }
                    .foregroundColor(showPopupDelete ? .white : .primary)
                    .background(showPopupDelete ? Color.blue.opacity(0.7) : Color.clear)
                    .cornerRadius(6)
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                .cornerRadius(10)
                
                Spacer()
                
                // Settings at the bottom
                Button(isSpanish ? "Configuración" : "Settings", systemImage: "gear") {
                    showPopup(&showPopupSettings)
                }
                .foregroundColor(showPopupSettings ? .white : .primary)
                .background(showPopupSettings ? Color.blue.opacity(0.7) : Color.clear)
                .cornerRadius(6)
                .buttonStyle(.plain)
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .padding(.top, 20)
                
                Spacer()
            }
            .padding()

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
                        } else if showPopupNewsFeed {
                            NewsFeedPopupView(showPopup: $showPopupNewsFeed, isSpanish: $isSpanish)
                        }
                    }
                )
        }
        .background()
    }
}

#Preview {
    ContentView()
}

