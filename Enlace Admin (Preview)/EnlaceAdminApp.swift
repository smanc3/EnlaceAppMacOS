import SwiftUI
import CloudKit

var body: some Scene {
    WindowGroup {
        ContentView()
            .onAppear {
                // ENHANCED DEBUG: Log CloudKit container and environment
                let container = CKContainer(identifier: "iCloud.PearInc.EICT-iOS-16")
                print("🛠️ [DEBUG] CKContainer: \(container.containerIdentifier ?? "nil")")
                #if DEBUG
                print("🛠️ [DEBUG] CloudKit Environment: DEVELOPMENT")
                #else
                print("🛠️ [DEBUG] CloudKit Environment: PRODUCTION")
                #endif
                
                // Existing code...
            }
    }
} 