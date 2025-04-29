import Foundation
import SwiftUI

// Extension to handle string localization using the isSpanish flag
extension String {
    func localized(isSpanish: Bool) -> String {
        if !isSpanish {
            return self
        }
        
        // Dictionary of translations
        let translations: [String: String] = [
            // Settings
            "Settings": "Configuración",
            "Language / Idioma": "Language / Idioma",
            "Spanish/English": "Español",
            "Switch to Spanish": "Cambiar a inglés",
            "Consent Management": "Gestión de Consentimiento",
            "Privacy Policy": "Política de Privacidad",
            "Required to use the application": "Requerido para usar la aplicación",
            "View Privacy Policy": "Ver Política de Privacidad",
            "Terms of Service": "Términos de Servicio",
            "View Terms of Service": "Ver Términos de Servicio",
            "Reset All Consents": "Reiniciar Todos los Consentimientos",
            "This will reset all your consent preferences. You will need to go through the consent process again. Are you sure you want to continue?": "Esto restablecerá todas tus preferencias de consentimiento. Tendrás que pasar por el proceso de consentimiento nuevamente. ¿Estás seguro de que quieres continuar?",
            "Reset": "Reiniciar",
            "Cancel": "Cancelar",
            "About": "Acerca de",
            "Version": "Versión",
            "Last Consent Update": "Última Actualización de Consentimiento",
            
            // Onboarding
            "Back": "Atrás",
            "Next": "Siguiente",
            "Get Started": "Comenzar",
            "Welcome to Enlace Admin": "Bienvenido a Enlace Admin",
            "Your all-in-one solution for managing community events, resources, and communications.": "Su solución integral para gestionar eventos comunitarios, recursos y comunicaciones.",
            "Event Management": "Gestión de Eventos",
            "Create and manage community events with ease": "Cree y gestione eventos comunitarios con facilidad",
            "Resource Library": "Biblioteca de Recursos",
            "Store and share important documents": "Almacene y comparta documentos importantes",
            "Notifications": "Notificaciones",
            "Keep your community informed with timely updates": "Mantenga a su comunidad informada con actualizaciones oportunas",
            "Analytics": "Analíticas",
            "Track engagement and participation metrics": "Haga seguimiento de métricas de participación y compromiso",
            "Privacy Consent": "Consentimiento de Privacidad",
            "We value your privacy and want to be transparent about how we use your data.": "Valoramos su privacidad y queremos ser transparentes sobre cómo usamos sus datos.",
            "Accept Privacy Policy": "Aceptar Política de Privacidad",
            "Read Full Privacy Policy": "Leer Política de Privacidad Completa",
            "Accept Terms of Service": "Aceptar Términos de Servicio",
            "Read Full Terms of Service": "Leer Términos de Servicio Completos",
            "Please review and accept our Terms of Service to continue.": "Por favor revise y acepte nuestros Términos de Servicio para continuar.",
            "You must accept both the Privacy Policy and Terms of Service to continue.": "Debe aceptar tanto la Política de Privacidad como los Términos de Servicio para continuar.",
            
            // Calendar
            "Events for": "Eventos para",
            "No events scheduled": "No hay eventos programados",
            "Test Event (Local)": "Evento de Prueba (Local)",
            "Conference Room": "Sala de Conferencias",
            "This is a local test event. Your CloudKit database may not be properly set up.": "Este es un evento de prueba local. Es posible que su base de datos CloudKit no esté configurada correctamente.",
            "Meeting with Team (Local)": "Reunión con el Equipo (Local)",
            "Main Office": "Oficina Principal",
            "Discuss project progress": "Discutir el progreso del proyecto",
            "Client Presentation (Local)": "Presentación al Cliente (Local)",
            "Conference Hall": "Salón de Conferencias",
            "Product demo to key clients": "Demostración del producto a clientes clave",
            "Event Details": "Detalles del Evento",
            "No location": "No hay ubicación",
            "Notes:": "Notas:",
            "Attached Document:": "Documento adjunto:",
            "Load PDF": "Cargar PDF",
            "Error loading PDF:": "Error al cargar PDF:",
            "Could not load the PDF": "No se pudo cargar el PDF",
            
            // News Management
            "News Management": "Gestión de Noticias",
            "Post to News Feed": "Publicar en Noticias",
            "Manage News Feed": "Gestionar Noticias",
            "View Archived News": "Ver Noticias Archivadas",
            
            // Event Management
            "Create Event": "Crear Evento",
            "Manage Events": "Gestionar Eventos",
            "View Archived Events": "Ver Eventos Archivados"
        ]
        
        // Return the translation if it exists, otherwise return the original string
        return translations[self] ?? self
    }
}

// Convenience extension for Text views
extension Text {
    static func localized(_ key: String, isSpanish: Bool) -> Text {
        Text(key.localized(isSpanish: isSpanish))
    }
}

// Example usage:
// Text.localized("Hello", isSpanish: isSpanish)
// Or directly in a Text view:
// Text("Hello".localized(isSpanish: isSpanish)) 