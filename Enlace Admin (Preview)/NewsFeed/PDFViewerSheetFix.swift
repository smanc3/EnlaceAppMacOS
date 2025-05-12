import SwiftUI
import PDFKit

// This is a stripped-down version just for testing
struct PDFDocumentDetailsTest: Identifiable {
    let id: String
    let title: String
    
    func getPDFDocument() -> PDFKit.PDFDocument? {
        return nil
    }
}

// MARK: - PDF Viewer Sheet Test
struct PDFViewerSheetTest: View {
    let details: PDFDocumentDetailsTest
    let dismissAction: () -> Void
    
    @State private var pdfDocument: PDFKit.PDFDocument? = nil
    @State private var isLoading: Bool = true
    
    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading PDF…")
                        .font(.headline)
                }
                .frame(minWidth: 400, minHeight: 300)
            } else if pdfDocument != nil {
                VStack(spacing: 0) {
                    Text("PDF Loaded")
                }
            } else {
                VStack(spacing: 16) {
                    Text("Error loading PDF")
                        .foregroundColor(.red)
                    Button("Close") { dismissAction() }
                        .buttonStyle(.bordered)
                }
                .frame(width: 400, height: 200)
            }
        }
        .onAppear(perform: loadPDF)
    }
    
    private func loadPDF() {
        // Load the PDF on a high-priority background queue to avoid blocking the UI
        DispatchQueue.global(qos: .userInitiated).async {
            let doc = details.getPDFDocument()
            DispatchQueue.main.async {
                self.pdfDocument = doc
                self.isLoading = false
            }
        }
    }
} 