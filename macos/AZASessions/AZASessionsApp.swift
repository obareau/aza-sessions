import AppKit

/// Point d'entrée de l'app Mac. Toute la logique est dans AppDelegate.
///
/// ⚠️ Pas de `main.swift` : en mode Swift 5, le code de premier niveau n'est pas
/// isolé sur le fil principal et ne peut pas créer un AppDelegate `@MainActor`
/// (erreur de compilation avec Xcode 16). Un `@main` explicitement `@MainActor`
/// le peut.
@main
enum AZASessionsApp {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) {
            application.run()
        }
    }
}
