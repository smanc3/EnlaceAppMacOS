import SwiftUI
import CloudKit
import PDFKit

// MARK: - Helper: sortPosts
func sortPosts(_ posts: [NewsFeedPost]) -> [NewsFeedPost] {
    print("🛠️ sortPosts called with \(posts.count) posts")
    // Minimal: sort by datePosted descending, then title
    return posts.sorted {
        if $0.datePosted != $1.datePosted {
            return $0.datePosted > $1.datePosted
        } else {
            return $0.title < $1.title
        }
    }
}

// MARK: - Helper: EditNewsPostInfo
struct EditNewsPostInfo {
    let title: String
    let scheduledDate: Date?
    let pdfRecord: CKRecord?
    let pdfURL: URL?
    let linkURL: String?
}

// MARK: - Placeholder Views
func loadingView(message: String) -> some View {
    VStack {
        Spacer()
        VStack(spacing: 16) {
            // Centered loading indicator with animation
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
                .padding()
                // Add subtle animation to make it more engaging
                .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 0)
                // Center in the frame
                .frame(maxWidth: .infinity, alignment: .center)
                
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                // Center text
                .frame(maxWidth: .infinity, alignment: .center)
        }
        // Position the loading group slightly above center for better visual balance
        .offset(y: -20)
        Spacer()
    }
}

func errorView(error: String, retryAction: @escaping () -> Void) -> some View {
    VStack {
        Spacer()
        Image(systemName: "exclamationmark.triangle")
            .font(.system(size: 50))
            .foregroundColor(.orange)
        Text(error)
            .font(.headline)
            .multilineTextAlignment(.center)
            .padding()
        Button("Retry", action: retryAction)
            .buttonStyle(.bordered)
        Spacer()
    }
}

// MARK: - NewsPostRow
struct NewsPostRow: View {
    @ObservedObject var post: NewsFeedPost
    let isSpanish: Bool
    let onEdit: () -> Void
    let onArchive: () -> Void
    let onDelete: () -> Void
    
    // Add state to track button press animations
    @State private var editPressed = false
    @State private var archivePressed = false
    @State private var deletePressed = false
    
    var body: some View {
        HStack {
            if let pdfDoc = post.pdfDocument, let thumbnail = pdfDoc.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .frame(width: 32, height: 32)
                    .cornerRadius(4)
            } else if post.pdfReference != nil {
                Image(systemName: "doc.text")
                    .foregroundColor(.red)
            } else {
                Image(systemName: "newspaper")
                    .foregroundColor(.gray)
            }
            VStack(alignment: .leading) {
                Text(post.title)
                    .fontWeight(.bold)
                Text(DateFormatter.localizedString(from: post.datePosted, dateStyle: .short, timeStyle: .short))
                    .font(.caption)
                    .foregroundColor(.green)
            }
            Spacer()
            
            // Edit button
            Button(action: {
                print("🔔 [BUTTON] Edit button tapped for post: \(post.title)")
                self.onEdit()
            }) {
                Image(systemName: "pencil")
                    .font(.system(size: 16, weight: .medium))
            }
            .buttonStyle(.plain)

            // Archive button
            Button(action: {
                print("🔔 [BUTTON] Archive button tapped for post: \(post.title) ID: \(post.id.recordName)")
                self.onArchive()
            }) {
                Image(systemName: "archivebox")
                    .font(.system(size: 16, weight: .medium))
            }
            .buttonStyle(.plain)

            // Delete button
            Button(action: {
                print("🔔 [BUTTON] Delete button tapped for post: \(post.title) ID: \(post.id.recordName)")
                self.onDelete()
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.system(size: 16, weight: .medium))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Minimal Logic Functions
func updatePost(originalPost: NewsFeedPost, updatedPost: EditNewsPostInfo) {
    print("🛠️ updatePost called for post: \(originalPost.title)")
}

func createNewPost(title: String, scheduledDate: Date?, pdfRecord: CKRecord?, pdfURL: URL?, linkURL: String?) {
    print("🛠️ createNewPost called with title: \(title)")
}

// MARK: - Placeholder Views for Details
func selectedPostDetailView(post: NewsFeedPost) -> some View {
    VStack(alignment: .leading) {
        Text(post.title).font(.title2).fontWeight(.bold)
        Text("Posted: " + DateFormatter.localizedString(from: post.datePosted, dateStyle: .short, timeStyle: .short))
            .font(.caption)
        if let link = post.linkURL {
            Text("Link: \(link.absoluteString)").font(.caption2)
        }
        Spacer()
    }.padding()
}

// MARK: - Notification Setup
func setupNotifications() {
    print("🛠️ setupNotifications called")
}

func removeNotifications() {
    print("🛠️ removeNotifications called")
}

// MARK: - Data Loading
func loadPosts() {
    print("🛠️ loadPosts called")
}

func loadArchivedPosts() {
    print("🛠️ loadArchivedPosts called")
} 