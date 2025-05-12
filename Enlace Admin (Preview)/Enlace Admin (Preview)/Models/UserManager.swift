import Foundation
import CloudKit
import SwiftUI

/// Manages user authentication and access to user records in CloudKit
class AuthenticationManager: ObservableObject {
    // MARK: - Published Properties
    
    @Published private(set) var userStatus: UserStatus = .checking
    @Published private(set) var userRecord: CKRecord?
    
    // MARK: - Properties
    
    private let container = CKContainer(identifier: "iCloud.PearInc.EICT-iOS-16")
    
    // MARK: - Lifecycle
    
    init() {
        print("👤 AuthenticationManager: Initializing")
        checkUserStatus()
    }
    
    // MARK: - Public Methods
    
    /// Checks the current iCloud user account status
    func checkUserStatus() {
        print("👤 AuthenticationManager: Checking user status")
        
        userStatus = .checking
        
        container.accountStatus { [weak self] status, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("👤 AuthenticationManager: Error checking account status: \(error.localizedDescription)")
                    self.userStatus = .error(error)
                    return
                }
                
                switch status {
                case .available:
                    print("👤 AuthenticationManager: iCloud account available")
                    self.fetchUserRecord()
                case .noAccount:
                    print("👤 AuthenticationManager: No iCloud account")
                    self.userStatus = .noAccount
                case .restricted:
                    print("👤 AuthenticationManager: iCloud account restricted")
                    self.userStatus = .restricted
                case .couldNotDetermine:
                    print("👤 AuthenticationManager: Could not determine iCloud status")
                    self.userStatus = .undetermined
                case .temporarilyUnavailable:
                    print("👤 AuthenticationManager: iCloud temporarily unavailable")
                    self.userStatus = .temporarilyUnavailable
                @unknown default:
                    print("👤 AuthenticationManager: Unknown iCloud account status")
                    self.userStatus = .undetermined
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func fetchUserRecord() {
        print("👤 AuthenticationManager: Fetching user record")
        
        container.fetchUserRecordID { [weak self] recordID, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("👤 AuthenticationManager: Error fetching user record ID: \(error.localizedDescription)")
                    self.userStatus = .error(error)
                    return
                }
                
                guard let recordID = recordID else {
                    print("👤 AuthenticationManager: No user record ID found")
                    self.userStatus = .noAccount
                    return
                }
                
                // Fetch the full user record
                self.container.publicCloudDatabase.fetch(withRecordID: recordID) { record, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("👤 AuthenticationManager: Error fetching user record: \(error.localizedDescription)")
                            self.userStatus = .error(error)
                            return
                        }
                        
                        self.userRecord = record
                        print("👤 AuthenticationManager: User record fetched successfully")
                        self.userStatus = .authenticated
                    }
                }
            }
        }
    }
}

// MARK: - UserStatus Enum

/// Represents the current status of the user's iCloud account
enum UserStatus: Equatable {
    case checking
    case authenticated
    case noAccount
    case restricted
    case undetermined
    case temporarilyUnavailable
    case error(Error)
    
    static func == (lhs: UserStatus, rhs: UserStatus) -> Bool {
        switch (lhs, rhs) {
        case (.checking, .checking),
             (.authenticated, .authenticated),
             (.noAccount, .noAccount),
             (.restricted, .restricted),
             (.undetermined, .undetermined),
             (.temporarilyUnavailable, .temporarilyUnavailable):
            return true
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
} 