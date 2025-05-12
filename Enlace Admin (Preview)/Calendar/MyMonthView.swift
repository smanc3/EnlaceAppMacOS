//
//  MyMonthView.swift
//  Enlace Admin (Preview)
//
//  Created on 4/25/25.
//

import SwiftUI
import PDFKit

// PDF Preview component needed for MyMonthView
struct MonthViewPDFPreview: NSViewRepresentable {
    let document: PDFKit.PDFDocument
    
    func makeNSView(context: NSViewRepresentableContext<MonthViewPDFPreview>) -> PDFView {
        let view = PDFView()
        view.document = document
        view.autoScales = true
        return view
    }
    
    func updateNSView(_ nsView: PDFView, context: NSViewRepresentableContext<MonthViewPDFPreview>) {
        nsView.document = document
    }
}

struct MyMonthView: View {
    @State private var linkedPDF: PDFKit.PDFDocument? = nil
    
    var body: some View {
        VStack {
            Text("Month View")
                .font(.title)
            
            if let pdf = linkedPDF {
                MonthViewPDFPreview(document: pdf)
                    .frame(height: 400)
                    .cornerRadius(8)
            } else {
                Text("No PDF selected")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
    
    func loadPDF(from fileURL: URL) {
        self.linkedPDF = PDFKit.PDFDocument(url: fileURL)
    }
}

struct MyMonthView_Previews: PreviewProvider {
    static var previews: some View {
        MyMonthView()
    }
} 
