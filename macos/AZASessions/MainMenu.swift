import AppKit

/// La barre de menus. Sans menu Édition, ⌘C / ⌘V / ⌘Z ne marchent PAS dans un
/// WKWebView : ce sont les éléments de menu qui portent les raccourcis.
enum MainMenu {
    static func build(target: AppDelegate) -> NSMenu {
        let bar = NSMenu()

        // AZA Sessions
        let app = submenu(bar, Paths.appName)
        app.addItem(withTitle: "À propos d'\(Paths.appName)",
                    action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        app.addItem(.separator())
        app.addItem(item("Réglages…", #selector(AppDelegate.goSettings(_:)), ",", target))
        app.addItem(.separator())
        let services = NSMenu(title: "Services")
        let servicesItem = app.addItem(withTitle: "Services", action: nil, keyEquivalent: "")
        servicesItem.submenu = services
        NSApp.servicesMenu = services
        app.addItem(.separator())
        app.addItem(withTitle: "Masquer \(Paths.appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let others = app.addItem(withTitle: "Masquer les autres",
                                 action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        others.keyEquivalentModifierMask = [.command, .option]
        app.addItem(withTitle: "Tout afficher", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        app.addItem(.separator())
        app.addItem(withTitle: "Quitter \(Paths.appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        // Fichier
        let file = submenu(bar, "Fichier")
        file.addItem(item("Nouvelle séance rapide", #selector(AppDelegate.goQuick(_:)), "n", target))
        file.addItem(item("Nouvelle séance complète", #selector(AppDelegate.goNewSession(_:)), "N", target))
        file.addItem(.separator())
        file.addItem(item("Sauvegarder maintenant", #selector(AppDelegate.saveNow(_:)), "s", target))
        file.addItem(item("Sauvegardes et restauration…", #selector(AppDelegate.goBackups(_:)), "", target))
        file.addItem(item("Ouvrir le dossier des sauvegardes", #selector(AppDelegate.revealBackups(_:)), "", target))
        file.addItem(item("Choisir le dossier des sauvegardes…", #selector(AppDelegate.chooseBackupFolder(_:)), "", target))
        file.addItem(.separator())
        file.addItem(item("Imprimer…", #selector(AppDelegate.printPage(_:)), "p", target))
        file.addItem(.separator())
        file.addItem(withTitle: "Fermer la fenêtre", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        // Édition — actions standard, cible nil : la chaîne de répondeurs les
        // amène au WKWebView qui a le focus.
        let edit = submenu(bar, "Édition")
        edit.addItem(withTitle: "Annuler", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "Rétablir", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Couper", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copier", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Coller", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Tout sélectionner", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        // Présentation
        let view = submenu(bar, "Présentation")
        view.addItem(item("Recharger la page", #selector(AppDelegate.reloadPage(_:)), "r", target))
        view.addItem(.separator())
        view.addItem(item("Taille réelle", #selector(AppDelegate.zoomReset(_:)), "0", target))
        view.addItem(item("Agrandir", #selector(AppDelegate.zoomIn(_:)), "+", target))
        view.addItem(item("Réduire", #selector(AppDelegate.zoomOut(_:)), "-", target))
        view.addItem(.separator())
        let full = view.addItem(withTitle: "Plein écran", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        full.keyEquivalentModifierMask = [.command, .control]

        // Aller
        let go = submenu(bar, "Aller")
        go.addItem(item("Précédent", #selector(AppDelegate.goBack(_:)), "[", target))
        go.addItem(item("Suivant", #selector(AppDelegate.goForward(_:)), "]", target))
        go.addItem(.separator())
        go.addItem(item("Journal", #selector(AppDelegate.goHome(_:)), "H", target))
        go.addItem(item("Ce soir", #selector(AppDelegate.goTonight(_:)), "1", target))
        go.addItem(item("Feuille d'atelier", #selector(AppDelegate.goWorkshop(_:)), "2", target))
        go.addItem(item("Statistiques", #selector(AppDelegate.goStats(_:)), "3", target))
        go.addItem(item("Catalogue", #selector(AppDelegate.goCatalogue(_:)), "4", target))
        go.addItem(item("Prises", #selector(AppDelegate.goTakes(_:)), "5", target))
        go.addItem(item("Lore", #selector(AppDelegate.goLore(_:)), "6", target))
        go.addItem(.separator())
        // Le SysEx a besoin de Web MIDI, que WebKit n'a pas : Chrome l'a.
        go.addItem(item("Ouvrir dans le navigateur", #selector(AppDelegate.openInBrowser(_:)), "O", target))

        // Fenêtre
        let window = submenu(bar, "Fenêtre")
        window.addItem(withTitle: "Placer dans le Dock", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        window.addItem(withTitle: "Réduire/agrandir", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        window.addItem(.separator())
        window.addItem(withTitle: "Tout ramener au premier plan", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        NSApp.windowsMenu = window

        // Aide
        let help = submenu(bar, "Aide")
        help.addItem(item("Dossier des sauvegardes", #selector(AppDelegate.revealBackups(_:)), "", target))
        help.addItem(item("Dossier de la base", #selector(AppDelegate.revealData(_:)), "", target))
        help.addItem(item("Journal du serveur", #selector(AppDelegate.revealServerLog(_:)), "", target))
        NSApp.helpMenu = help

        return bar
    }

    private static func submenu(_ bar: NSMenu, _ title: String) -> NSMenu {
        let menu = NSMenu(title: title)
        let holder = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        holder.submenu = menu
        bar.addItem(holder)
        return menu
    }

    private static func item(_ title: String, _ action: Selector, _ key: String,
                             _ target: AnyObject) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target
        return item
    }
}
