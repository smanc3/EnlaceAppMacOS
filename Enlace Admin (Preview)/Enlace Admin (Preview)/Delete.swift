//
//  Delete.swift
//  Enlace Admin (Preview)
//
//  Created by Steven Mancilla on 2/25/25.
//

import SwiftUI

struct PopupView2: View {
    @Binding var showPopupDelete: Bool // Binding to control the popup visibility
    @State private var EventName: String = ""
    @State private var EventLocation: String = ""
    @State private var link: String = ""

    var body: some View {
        ZStack {
            Color.black.opacity(0.1) // This creates a dimmed background behind the popup
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    // Close the popup if the background is tapped
                    showPopupDelete = false
                }

            VStack {
                Text("Delete Event")
                    .font(.largeTitle)
                    .padding(.bottom)
                    .fontWeight(.bold)
                Form {
                    TextField("Event Name:", text: $EventName)
                    //    .padding()
                    
                        .padding()
                }
                .padding([.top, .leading, .trailing], 15.0)
                
                DatePicker(selection: .constant(Date()), label: { Text("Date and Time") })
                    .padding(.bottom)

                
                .padding(.bottom)

                HStack {
                    
                }
                .padding(.bottom)
                
                Button(action: {
                    // Close the popup
                    showPopupDelete = false
                }) {
                    Text("Delete Event")
                }
                .padding()
                Button(action: {
                    // Close the popup
                    showPopupDelete = false
                }) {
                    Text("Cancel")
                }
                
            }
            .frame(width: 450, height: 350)
            .background(Color.black) // Use white for the popup background so it's distinguishable
            .cornerRadius(15)
            .shadow(radius: 10)
        }
    }
}

#Preview {
    ContentView()
}

