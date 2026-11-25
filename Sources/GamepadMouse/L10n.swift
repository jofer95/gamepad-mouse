import Foundation

/// English and Spanish, following the Mac's language order (or the per-app language set in
/// System Settings → General → Language & Region → Applications).
enum L10n {
    static let isSpanish: Bool = {
        let first = Locale.preferredLanguages.first { $0.hasPrefix("en") || $0.hasPrefix("es") }
        return first?.hasPrefix("es") ?? false
    }()
}

/// The text for the app's language: `tr("Close window", "Cerrar ventana")`.
func tr(_ english: String, _ spanish: String) -> String {
    L10n.isSpanish ? spanish : english
}
