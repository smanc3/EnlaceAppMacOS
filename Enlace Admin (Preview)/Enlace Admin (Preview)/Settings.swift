//
//  Settings.swift
//  Enlace Admin (Preview)
//
//  Created by Steven Mancilla on 2/7/25.
//

import SwiftUI

struct PopupView4: View {
    @Binding var showPopupSettings: Bool // Control popup visibility
    @Binding var isSpanish: Bool       // Control language selection

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    showPopupSettings = false
                }

            VStack {
                // Title
                Text(isSpanish ? "Configuración" : "Settings")
                    .font(.largeTitle)
                //    .multilineTextAlignment(.center)
                    .padding(.top, 30)
                    .fontWeight(.bold)

                // Language Picker
                Picker(isSpanish ? "Idioma" : "Language", selection: $isSpanish) {
                    Text(isSpanish ? "Ingles" : "English").tag(false)
                    Text(isSpanish ? "Espanol" : "Spanish").tag(true)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                Spacer()
                
                // Close Button
                Button(action: {
                    showPopupSettings = false
                }) {
                    Text(isSpanish ? "Cerrar" : "Close")
                    //    .font(.headline)
                      //  .foregroundColor(.white)
                        //.padding()
                      //  .frame(maxWidth: .infinity)
                        //.background(Color.blue)
                        //.cornerRadius(8)
                }
            //    .padding(.horizontal)
                .padding(.bottom, 20)

            }
            .frame(width: 350, height: 260)
            .background()
            .cornerRadius(15)
            .shadow(radius: 10)
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
