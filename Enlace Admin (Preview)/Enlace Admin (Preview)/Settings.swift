//
//  Settings.swift
//  Enlace Admin (Preview)
//
//  Created by Steven Mancilla on 2/7/25.
//

import SwiftUI

struct PopupView4: View {
    @Binding var showPopupSettings: Bool // Binding to control the popup visibility
    @State private var EventName: String = ""
    @State private var EventLocation: String = ""
    @State private var link: String = ""
    @State private var selectedOption: String = "Option 1"
    let options = ["English", "Spanish"]

    var body: some View {
        ZStack {
            Color.black.opacity(0.1) // This creates a dimmed background behind the popup
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    // Close the popup if the background is tapped
                    showPopupSettings = false
                }

            VStack {
                Text("Settings")
                    .font(.largeTitle)
                    .padding(.bottom)
                    .fontWeight(.bold)

                Picker("Pick a language:", selection: $selectedOption) {
                    ForEach(options, id: \.self) { option in
                        Text(option)
                    }
                }
                .pickerStyle(MenuPickerStyle())  // Use WheelPickerStyle for better compatibility in this case
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
            }
            .frame(width: 450, height: 350)
            .background(Color.black) // Background color for the popup
            .cornerRadius(15)
            .shadow(radius: 10)
        }
    }
}



#Preview {
    ContentView()
}
