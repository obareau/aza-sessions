import AppKit

// Point d'entrée de l'app Mac. Toute la logique est dans AppDelegate.
let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.regular)
application.run()
