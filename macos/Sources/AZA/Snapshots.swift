import AppKit
import AZACore
import SwiftUI

/// Mode capture (documentation) : `AZA -snapshotDir <dossier> [-dataFile demo.json] [-theme machine]`.
///
/// L'app parcourt ses écrans et photographie SA PROPRE fenêtre (cacheDisplay),
/// ce qui ne demande aucune autorisation d'enregistrement d'écran, puis quitte.
/// Les arguments passent par le domaine NSArgumentDomain : rien n'est écrit
/// dans les préférences de l'utilisateur.
@MainActor
enum SnapshotRunner {
    static var dir: URL? {
        UserDefaults.standard.string(forKey: "snapshotDir").map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    static func run(nav: Nav, store: Store, prefs: Prefs, pomo: Pomodoro) async {
        guard let dir else { return }
        func log(_ m: String) { FileHandle.standardError.write("SNAP \(m)\n".data(using: .utf8)!) }
        log("début · fenêtres : \(NSApp.windows.map { "\($0.identifier?.rawValue ?? "-")|\($0.title)|\($0.isVisible)" })")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        guard let window = NSApp.windows.first(where: { $0.identifier?.rawValue.hasPrefix("main") == true })
                ?? NSApp.mainWindow else { NSApp.terminate(nil); return }
        window.setContentSize(NSSize(width: 1440, height: 900))
        window.center()
        let first = store.data.sessions.sorted { ($0.date, $0.id) > ($1.date, $1.id) }.first?.id
        let gear = store.data.catalogue.first { $0.name == "MicroFreak" }?.id
        let shots: [(String, () -> Void)] = [
            ("journal", { nav.pane = .diary; nav.diary = store.data.diary.max { $0.date < $1.date }?.id }),
            ("journal-calendar", { nav.pane = .diary; NotificationCenter.default.post(name: .azaDiaryMode, object: "Calendrier") }),
            ("journal-insights", { nav.pane = .diary; NotificationCenter.default.post(name: .azaDiaryMode, object: "Aperçu") }),
            ("sessions", { nav.pane = .sessions; nav.session = first }),
            ("tonight", { nav.pane = .tonight }),
            ("patcher", { nav.pane = .patcher; nav.patch = store.data.patches.first?.id }),
            ("stats", { nav.pane = .stats }),
            ("catalogue", { nav.pane = .catalogue; nav.gear = gear }),
            ("sysex", { nav.pane = .sysex }),
            ("spark", { nav.pane = .spark }),
        ]
        log("fenêtre retenue : \(window.identifier?.rawValue ?? "-")")
        for (name, setup) in shots {
            log(name)
            setup()
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            save(window, to: dir.appendingPathComponent(name + ".png"))
        }
        // Historique (feuille attachée à la fenêtre)
        nav.history = true
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        if let sheet = window.attachedSheet { save(sheet, to: dir.appendingPathComponent("history.png")) }
        nav.history = false
        try? await Task.sleep(nanoseconds: 800_000_000)
        // Panneau de la barre de menus, rendu dans une fenêtre le temps de la capture
        let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 340, height: 600), styleMask: [.borderless], backing: .buffered, defer: false)
        let host = NSHostingView(rootView: MenuBarPanel()
            .azaRoot().background(prefs.palette?.bg ?? Color(nsColor: .windowBackgroundColor))
            .environmentObject(store).environmentObject(nav).environmentObject(prefs).environmentObject(pomo))
        panel.contentView = host
        panel.setContentSize(host.fittingSize)
        panel.orderFront(nil)
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        save(panel, to: dir.appendingPathComponent("menubar.png"))
        panel.orderOut(nil)
        // Fenêtre de réglages
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        if let settings = NSApp.windows.first(where: {
            $0.isVisible && $0 !== window && $0.frame.width > 300 && !String(describing: type(of: $0)).contains("StatusBar")
        }) {
            save(settings, to: dir.appendingPathComponent("settings.png"))
        }
        NSApp.terminate(nil)
    }

    static func save(_ window: NSWindow, to url: URL) {
        // La vue de cadre inclut la barre de titre et la barre d'outils.
        guard let view = window.contentView?.superview ?? window.contentView else { return }
        view.layoutSubtreeIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}

extension Notification.Name {
    /// Mode capture : demande à l'écran Journal de changer de vue.
    static let azaDiaryMode = Notification.Name("azaDiaryMode")
}

extension Notification.Name {
    /// Ouvre la fenêtre Historique depuis les Réglages.
    static let azaShowHistory = Notification.Name("azaShowHistory")
}
