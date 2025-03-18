//
//  Settings.swift
//  Enlace Admin (Preview)
//
//  Created by Steven Mancilla on 2/7/25.
//

import SwiftUI

struct PopupView4: View {
    @Binding var showPopupSettings: Bool // Binding to control the popup visibility
//    enum Language: String, CaseIterable, Identifiable {
//        case English, Spanish
//        var id: Self { self }
//    }
    @Binding var isSpanish: Bool

 //  @State private var selectedLanguage: Language = .Spanish

    var body: some View {
        
        
        ZStack {
            Color.white.opacity(0.5) // This creates a dimmed background behind the popup
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    // Close the popup if the background is tapped
                    showPopupSettings = false
                }
            VStack {
                Text("Settings")
                    .font(.largeTitle)
                    .multilineTextAlignment(.center)
                    .padding(.top, 30.0)
                    .fontWeight(.bold)

                
                Picker("Language", selection: $isSpanish, content: {
                        Text("English").tag(false)
                        Text("Spanish").tag(true)
                    })
                
                
                .pickerStyle(.segmented)  // Use WheelPickerStyle for better compatibility in this case
                .padding()

                HStack {
                    // Add any necessary buttons or content here.
                }
                .padding(.bottom)

                

                Button(action: {
                    // Close the popup
                    showPopupSettings = false
                }) {
                    Text("Close")
                      //  .padding()
                       // .background(Color.gray)
                     //   .foregroundColor(.white)
                     //   .cornerRadius(8)
                }
                .padding()
            }
            .frame(width: 450, height: 350)
            .background() // Background color for the popup
            .cornerRadius(15)
            .shadow(radius: 10)
        }
   //     .windowResizeBehavior()
    }
}



#Preview {
    ContentView()
}
