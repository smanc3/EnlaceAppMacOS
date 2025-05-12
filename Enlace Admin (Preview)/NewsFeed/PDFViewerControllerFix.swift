import SwiftUI
import PDFKit
import AppKit

// Simple wrapper for PDF viewing in SwiftUI
struct PDFViewerControllerFix: NSViewControllerRepresentable {
    let document: PDFKit.PDFDocument
    var onDismiss: () -> Void
    
    func makeNSViewController(context: Context) -> NSViewController {
        let controller = PDFViewControllerFix(document: document, onDismiss: onDismiss)
        return controller
    }
    
    func updateNSViewController(_ nsViewController: NSViewController, context: Context) {
        if let pdfController = nsViewController as? PDFViewControllerFix {
            pdfController.document = document
        }
    }
    
    class PDFViewControllerFix: NSViewController {
        var document: PDFKit.PDFDocument
        var onDismiss: () -> Void
        var pdfView: PDFView!
        
        init(document: PDFKit.PDFDocument, onDismiss: @escaping () -> Void) {
            self.document = document
            self.onDismiss = onDismiss
            super.init(nibName: nil, bundle: nil)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func loadView() {
            let containerView = NSView()
            pdfView = PDFView()
            pdfView.autoresizingMask = [.width, .height]
            containerView.addSubview(pdfView)
            self.view = containerView
        }
        
        override func viewDidLoad() {
            super.viewDidLoad()
            pdfView.document = document
        }
    }
} 