import SwiftUI
import CloudKit // Assuming NewsFeedPost uses CloudKit types

// Placeholder for the actual NewsFeedPost model if it's not globally accessible
// You might need to ensure the real NewsFeedPost model is available here
// struct NewsFeedPost: Identifiable { ... }

struct NewsFeedCardView: View {
    // Properties likely needed
    // Use @ObservedObject if NewsFeedPost is a class conforming to ObservableObject
    // Use let if it's a struct passed down
    let post: NewsFeedPost // Assuming it's passed as a struct
    @Binding var isSpanish: Bool
    @State private var showShareSheet = false // State for the share sheet
    
    // Callbacks
    var onArchive: (() -> Void)?
    
    // Placeholder for LanguageManager if used
    // @EnvironmentObject var languageManager: LanguageManager
    
    var body: some View {
        // Example structure - Replace with actual card layout if different
        HStack {
            VStack(alignment: .leading) {
                Text(post.title)
                    .font(.headline)
                Text(post.datePosted, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                // Add other relevant post details here if needed
            }
            Spacer()
            // Maybe an image or icon, e.g., for PDF
            if post.pdfReference != nil {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5)) // Example background
        .cornerRadius(8)
        // Apply the context menu here
        .contextMenu {
            // Archive option
            Button(action: {
                // Call the onArchive callback when the button is pressed.
                print("Archive button tapped for post: \(post.title)")
                self.onArchive?()
            }) {
                Label(isSpanish ? "Archivar" : "Archive",
                      systemImage: "archivebox")
            }
            
            // Share option
            Button(action: {
                showShareSheet = true
            }) {
                Label(isSpanish ? "Compartir" : "Share",
                      systemImage: "square.and.arrow.up")
            }
        }
        // Add a sheet modifier for sharing if needed
        .sheet(isPresented: $showShareSheet) {
            // Replace with your actual share sheet implementation
            Text("Sharing \(post.title)") // Placeholder
                .padding()
                .frame(minWidth: 300, minHeight: 200)
        }
    }
}

// Add a PreviewProvider if needed (requires sample data)
// struct NewsFeedCardView_Previews: PreviewProvider {
//     static var previews: some View {
//         // Create a sample CKRecord for previewing
//         let sampleRecord = CKRecord(recordType: "NewsFeedItem")
//         sampleRecord["title"] = "Sample News Title"
//         sampleRecord["datePosted"] = Date()
//         // Add other necessary fields for NewsFeedPost init
//         
//         let samplePost = NewsFeedPost(record: sampleRecord)
//         
//         NewsFeedCardView(post: samplePost, isSpanish: .constant(false), onArchive: { print("Preview Archive") })
//             .padding()
//     }
// } 