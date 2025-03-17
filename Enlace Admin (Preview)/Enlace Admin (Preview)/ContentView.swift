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
    @State private var isSpanish = false
  
    var body: some View {        
        HStack{
        Spacer()
            VStack(alignment: .leading) {
                Spacer()
                Button("Create Event", systemImage: "calendar.badge.plus") {
                    showPopupCreate.toggle()
                }
                Button("Archive Event", systemImage: "cloud.fill") {
                    showPopupArchive.toggle()
                    
                }
                Button(" Delete Event", systemImage: "trash.fill") {
                    showPopupDelete.toggle()
                }
                
                Spacer()
                Spacer()
                Spacer()
                Button("Settings", systemImage: "gear") {
                    showPopupSettings.toggle()
                    //isSpanish.toggle()
                }
                
               Spacer()
            }
            CalendarView()
                .overlay(
                    // Show the popup when the state is true
                    Group {
                        if showPopupCreate {
                            PopupView(showPopupCreate: $showPopupCreate)
                        }
                    }
                )
                .overlay(
                    Group {
                    if showPopupDelete {
                        PopupView2(showPopupDelete: $showPopupDelete)
                        }
                    }
                )
                .overlay(
                    Group {
                    if showPopupArchive {
                        PopupView3(showPopupArchive: $showPopupArchive)
                        }
                    }
                )
                .overlay(
                    Group {
                    if showPopupSettings {
                        PopupView4(showPopupSettings: $showPopupSettings)
                        }
                    }
                )
                
        }
        .background(Color(.black))
    }
}

#Preview {
    ContentView()
}
