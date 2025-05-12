//
//  ArchivedNewsDetailView.swift
//  Enlace Admin (Preview)
//
//  Created on 6/21/25.
//

import SwiftUI
import CloudKit
// Remove PDFKit import if no longer needed after other removals
// import PDFKit 
import Foundation

// MARK: - Archived News Detail View
struct ArchivedNewsDetailView: View {
    // MARK: - Properties
    let post: ModelsArchivedNewsPost
    let isSpanish: Bool
    let container: CKContainer
    var onDelete: ((ModelsArchivedNewsPost) -> Void)? = nil
    var onUnarchive: ((ModelsArchivedNewsPost) -> Void)? = nil
    
    // Remove PDF-related state variables
    // @State private var pdfDocument: PDFDocument? = nil 
    // @State private var isLoadingPDF: Bool = false
    // @State private var pdfLoadError: String? = nil
    // @State private var currentPage: Int = 1
    // @State private var totalPages: Int = 1
    
    @EnvironmentObject var languageManager: LanguageManager
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    // MARK: - View Body
    var body: some View {
        VStack(spacing: 0) {
            // Header with post information
            headerView
            
            Divider()
            
            // Remove the entire PDF content area
            // if post.pdfReference != nil { ... } else { ... }
            
            // Add a placeholder or message if needed, or just let the header fill the space
            Spacer() // Add spacer to push header to top if no PDF area remains
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Remove .onAppear for PDF loading
        // .onAppear { ... }
    }
    
    // MARK: - Subviews
    
    /// Header view with post information and buttons
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(post.title)
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                    Text(isSpanish ? "Fecha de publicación:" : "Post date:")
                        .fontWeight(.medium)
                    Text(dateFormatter.string(from: post.datePosted))
                }
                
                HStack {
                    Image(systemName: "archivebox")
                        .foregroundColor(.orange)
                    Text(isSpanish ? "Fecha de archivo:" : "Archive date:")
                        .fontWeight(.medium)
                    Text(dateFormatter.string(from: post.archivedDate))
                }
                
                // Link if available
                if let linkURL = post.linkURL {
                    HStack {
                        Image(systemName: "link")
                            .foregroundColor(.blue)
                        Text(isSpanish ? "Enlace:" : "Link:")
                            .fontWeight(.medium)
                        Link(destination: linkURL) {
                            Text(linkURL.absoluteString)
                                .foregroundColor(.blue)
                                .underline()
                        }
                    }
                    .padding(.top, 4)
                }
            }
            
            Spacer().frame(height: 10)
            
            // Action buttons
            HStack {
                Spacer()
                
                Button(action: {
                    if let onUnarchive = onUnarchive {
                        print("📰 ArchivedNewsDetail: Unarchive button tapped")
                        onUnarchive(post)
                    }
                }) {
                    Label(isSpanish ? "Desarchivar" : "Unarchive", systemImage: "arrow.up.bin")
                }
                .buttonStyle(.bordered)
                
                Button(role: .destructive, action: {
                    if let onDelete = onDelete {
                        print("📰 ArchivedNewsDetail: Delete button tapped")
                        onDelete(post)
                    }
                }) {
                    Label(isSpanish ? "Eliminar" : "Delete", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // Remove PDF-related helper views
    // private var loadingView: some View { ... }
    // private func errorView(message: String) -> some View { ... }
    // private func pdfView(document: PDFDocument) -> some View { ... }
    // private var noPDFView: some View { ... }
    // private var noPDFAttachedView: some View { ... }
    
    // MARK: - Methods
    
    // Remove PDF loading methods
    // private func loadPDFDocument() { ... }
    // private func fetchPDFDocument() { ... } // Assuming this method exists and needs removal too
}

// Remove ArchivedNewsDetailPDFViewer if it's defined here and no longer needed
// struct ArchivedNewsDetailPDFViewer: NSViewRepresentable { ... } 

// If ArchivedNewsDetailPDFViewer is defined elsewhere, just ensure it's not used here.

// Preview Provider might need adjustment if it relied on PDF state
// struct ArchivedNewsDetailView_Previews: PreviewProvider { ... } 