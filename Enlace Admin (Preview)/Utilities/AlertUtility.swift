//
//  AlertUtility.swift
//  Enlace Admin (Preview)
//
//  Created on 6/14/25.
//

import SwiftUI

/// A utility class for standardized alert management across the app
class AlertManager {
    /// Singleton instance
    static let shared = AlertManager()
    
    /// Private initializer for singleton
    private init() {}
    
    /// Standard Alert customization
    struct AlertStyle {
        /// Standard success alert style
        static let success = AlertStyle(
            iconName: "checkmark.circle.fill",
            iconColor: .green,
            buttonLabel: "OK"
        )
        
        /// Standard error alert style
        static let error = AlertStyle(
            iconName: "exclamationmark.triangle.fill",
            iconColor: .red,
            buttonLabel: "OK"
        )
        
        /// Standard warning alert style
        static let warning = AlertStyle(
            iconName: "exclamationmark.circle.fill",
            iconColor: .orange,
            buttonLabel: "OK"
        )
        
        /// Standard info alert style
        static let info = AlertStyle(
            iconName: "info.circle.fill",
            iconColor: .blue,
            buttonLabel: "OK"
        )
        
        let iconName: String
        let iconColor: Color
        let buttonLabel: String
    }
    
    /// Creates a standardized SwiftUI Alert for success messages
    func createSuccessAlert(title: String, message: String, onDismiss: (() -> Void)? = nil) -> Alert {
        return Alert(
            title: Text(title),
            message: Text(message),
            dismissButton: .default(Text(AlertStyle.success.buttonLabel)) {
                if let dismiss = onDismiss {
                    dismiss()
                }
            }
        )
    }
    
    /// Creates a standardized SwiftUI Alert for error messages
    func createErrorAlert(title: String, message: String, onDismiss: (() -> Void)? = nil) -> Alert {
        return Alert(
            title: Text(title),
            message: Text(message),
            dismissButton: .default(Text(AlertStyle.error.buttonLabel)) {
                if let dismiss = onDismiss {
                    dismiss()
                }
            }
        )
    }
    
    /// Creates a standardized SwiftUI Alert for confirmation with yes/no options
    func createConfirmationAlert(title: String, message: String, 
                                confirmLabel: String, cancelLabel: String,
                                isDestructive: Bool = false,
                                onConfirm: @escaping () -> Void,
                                onCancel: (() -> Void)? = nil) -> Alert {
        return Alert(
            title: Text(title),
            message: Text(message),
            primaryButton: isDestructive ? 
                .destructive(Text(confirmLabel), action: onConfirm) :
                .default(Text(confirmLabel), action: onConfirm),
            secondaryButton: .cancel(Text(cancelLabel)) {
                if let cancel = onCancel {
                    cancel()
                }
            }
        )
    }
    
    /// Logs alert presentation for debugging
    func logAlert(type: String, title: String, message: String) {
        print("🔔 [ALERT] Showing \(type) alert: \(title) - \(message)")
    }
}

/// Extension to add standardized Alert display to any View
extension View {
    /// Shows a standardized error alert
    func standardErrorAlert(isPresented: Binding<Bool>, title: String, message: String, onDismiss: (() -> Void)? = nil) -> some View {
        self.alert(isPresented: isPresented) {
            AlertManager.shared.createErrorAlert(title: title, message: message, onDismiss: onDismiss)
        }
    }
    
    /// Shows a standardized success alert
    func standardSuccessAlert(isPresented: Binding<Bool>, title: String, message: String, onDismiss: (() -> Void)? = nil) -> some View {
        self.alert(isPresented: isPresented) {
            AlertManager.shared.createSuccessAlert(title: title, message: message, onDismiss: onDismiss)
        }
    }
    
    /// Shows a standardized confirmation alert
    func standardConfirmationAlert(isPresented: Binding<Bool>, 
                                  title: String, message: String,
                                  confirmLabel: String, cancelLabel: String,
                                  isDestructive: Bool = false,
                                  onConfirm: @escaping () -> Void,
                                  onCancel: (() -> Void)? = nil) -> some View {
        self.alert(isPresented: isPresented) {
            AlertManager.shared.createConfirmationAlert(
                title: title, 
                message: message, 
                confirmLabel: confirmLabel,
                cancelLabel: cancelLabel,
                isDestructive: isDestructive,
                onConfirm: onConfirm,
                onCancel: onCancel
            )
        }
    }
} 