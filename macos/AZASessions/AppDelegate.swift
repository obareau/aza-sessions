import AppKit
import WebKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation, ServerProcessDelegate {
    private(set) static var shared: AppDelegate!

    let server = ServerProcess()
    private(set) var port: Int?
    private var controllers: [BrowserWindowController] = []
    private weak var mainController: BrowserWindowController?
    private var quitting = false
    private var pendingPath: String?
    private var signalSources: [DispatchSourceSignal] = []
    private var unexpectedStops: [Date] = []
    private let bridge = ScriptBridge()

    /// Partagée par toutes les fenêtres : WebKit impose aux fenêtres ouvertes
    /// par une page la configuration de celle-ci — donc le même pont JS.
    private lazy var configuration: WKWebViewConfiguration = {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        let ucc = WKUserContentController()
        ucc.add(self.bridge, name: ScriptBridge.printHandler)
        ucc.addUserScript(WKUserScript(source: ScriptBridge.printShim,
                                       injectionTime: .atDocumentStart,
                                       forMainFrameOnly: false))
        config.userContentController = ucc
        return config
    }()

    static var savedPageZoom: CGFloat {
        let z = UserDefaults.standard.double(forKey: Paths.Key.pageZoom)
        return z > 0 ? CGFloat(z) : 1.0
    }

    // MARK: - Cycle de vie

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        NSApp.mainMenu = MainMenu.build(target: self)
        installSignalHandlers()
        AppLog.write("lancement — v\(Self.version), macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")

        let main = openWindow(configuration: configuration, isMain: true)
        main.showMessage(title: "AZA SESSIONS", detail: "démarrage…", busy: true)
        main.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)

        server.delegate = self
        server.start()
    }

    /// Arrêt SYNCHRONE du serveur, pas `.terminateLater` : quand la fermeture
    /// vient d'un bloc de la file principale (SIGTERM), une réponse renvoyée à
    /// cette même file n'arrive jamais — l'app restait ouverte indéfiniment.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        quitting = true
        if server.isRunning {
            AppLog.write("fermeture — dernière sauvegarde")
            server.stopAndWait()
            AppLog.write("serveur arrêté proprement")
        }
        AppLog.flush()
        return .terminateNow
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    /// `kill` (SIGTERM) ou Ctrl-C : passer par la fermeture normale, qui
    /// déclenche la dernière sauvegarde, au lieu de mourir sur place.
    private func installSignalHandlers() {
        for sig in [SIGTERM, SIGINT] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler { NSApp.terminate(nil) }
            source.resume()
            signalSources.append(source)
        }
    }

    // MARK: - Fenêtres

    @discardableResult
    func openWindow(configuration: WKWebViewConfiguration, isMain: Bool) -> BrowserWindowController {
        let controller = BrowserWindowController(configuration: configuration, isMain: isMain)
        controller.onClose = { [weak self] closed in
            self?.controllers.removeAll { $0 === closed }
        }
        controllers.append(controller)
        if isMain {
            mainController = controller
        } else if let anchor = currentController?.window, let window = controller.window {
            window.setFrameTopLeftPoint(window.cascadeTopLeft(from: NSPoint(x: anchor.frame.minX,
                                                                            y: anchor.frame.maxY)))
        }
        controller.showWindow(nil)
        return controller
    }

    /// La fenêtre au premier plan, ou la principale ; recrée celle-ci si besoin.
    private var currentController: BrowserWindowController? {
        if let key = NSApp.keyWindow?.windowController as? BrowserWindowController { return key }
        return mainController ?? controllers.last
    }

    private func controllerForNavigation() -> BrowserWindowController {
        if let c = currentController { return c }
        let c = openWindow(configuration: configuration, isMain: true)
        return c
    }

    func url(for path: String) -> URL? {
        guard let port = port else { return nil }
        return URL(string: "http://127.0.0.1:\(port)\(path)")
    }

    /// Ce qui s'affiche dans l'app plutôt que dans le navigateur.
    func isInternal(_ url: URL) -> Bool {
        switch url.scheme {
        case "about", "data", "blob":
            return true
        case "http":
            guard let port = port else { return false }
            return (url.host == "127.0.0.1" || url.host == "localhost") && url.port == port
        default:
            return url.absoluteString.isEmpty
        }
    }

    private func go(_ path: String) {
        guard port != nil else { pendingPath = path; return }
        let c = controllerForNavigation()
        c.load(path: path)
        c.showWindow(nil)
    }

    // MARK: - ServerProcessDelegate

    func serverDidBecomeReady(port: Int, firstLaunch: Bool) {
        self.port = port
        AppLog.write("serveur prêt sur le port \(port)\(firstLaunch ? " — base neuve" : "")")
        let start = pendingPath ?? (firstLaunch ? "/settings?premiere=1" : "/")
        pendingPath = nil
        let c = controllerForNavigation()
        c.load(path: start)
    }

    func serverDidFailToStart(message: String) {
        AppLog.write("échec du démarrage : \(message)")
        mainController?.showMessage(title: "DÉMARRAGE IMPOSSIBLE", detail: message, busy: false)
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "AZA Sessions n'a pas pu démarrer"
        alert.informativeText = message + "\n\nTa base n'a pas été touchée."
        alert.addButton(withTitle: "Réessayer")
        alert.addButton(withTitle: "Ouvrir le journal")
        alert.addButton(withTitle: "Quitter")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            server.start()
        case .alertSecondButtonReturn:
            NSWorkspace.shared.open(Paths.serverLog)
            serverDidFailToStart(message: message)
        default:
            NSApp.terminate(nil)
        }
    }

    func serverDidStopUnexpectedly(status: Int32) {
        port = nil
        guard !quitting else { return }
        // Une relance, pas une boucle : trois arrêts en cinq minutes, c'est une
        // panne — on le dit au lieu de relancer indéfiniment.
        let now = Date()
        unexpectedStops = unexpectedStops.filter { now.timeIntervalSince($0) < 300 } + [now]
        if unexpectedStops.count >= 3 {
            unexpectedStops.removeAll()
            serverDidFailToStart(message: "Le serveur s'est arrêté trois fois en cinq minutes "
                                 + "(dernier code \(status)).\n\n" + server.logTail(lines: 12))
            return
        }
        AppLog.write("serveur arrêté de façon inattendue (code \(status)) — relance")
        mainController?.showMessage(title: "RELANCE DU SERVEUR",
                                    detail: "Le serveur s'est arrêté (code \(status)). Relance…",
                                    busy: true)
        pendingPath = currentController?.webView.url.flatMap { url in
            url.scheme == "http" ? url.path + (url.query.map { "?" + $0 } ?? "") : nil
        }
        server.start()
    }

    // MARK: - Menus : navigation

    @objc func goHome(_ sender: Any?) { go("/") }
    @objc func goQuick(_ sender: Any?) { go("/vite") }
    @objc func goNewSession(_ sender: Any?) { go("/new") }
    @objc func goTonight(_ sender: Any?) { go("/ce-soir") }
    @objc func goWorkshop(_ sender: Any?) { go("/atelier") }
    @objc func goStats(_ sender: Any?) { go("/stats") }
    @objc func goCatalogue(_ sender: Any?) { go("/catalogue") }
    @objc func goTakes(_ sender: Any?) { go("/prises") }
    @objc func goLore(_ sender: Any?) { go("/lore") }
    @objc func goSettings(_ sender: Any?) { go("/settings") }
    @objc func goBackups(_ sender: Any?) { go("/settings#sauvegardes") }

    @objc func goBack(_ sender: Any?) { currentController?.webView.goBack() }
    @objc func goForward(_ sender: Any?) { currentController?.webView.goForward() }
    @objc func reloadPage(_ sender: Any?) { currentController?.webView.reload() }

    @objc func printPage(_ sender: Any?) { currentController?.printPage() }

    @objc func openInBrowser(_ sender: Any?) {
        guard let url = currentController?.webView.url, url.scheme == "http" else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Menus : zoom

    private func setZoom(_ zoom: CGFloat) {
        let z = min(max(zoom, 0.5), 3.0)
        UserDefaults.standard.set(Double(z), forKey: Paths.Key.pageZoom)
        for c in controllers { c.webView.pageZoom = z }
    }

    @objc func zoomIn(_ sender: Any?) { setZoom(Self.savedPageZoom + 0.1) }
    @objc func zoomOut(_ sender: Any?) { setZoom(Self.savedPageZoom - 0.1) }
    @objc func zoomReset(_ sender: Any?) { setZoom(1.0) }

    // MARK: - Menus : sauvegardes

    @objc func saveNow(_ sender: Any?) {
        guard let url = url(for: "/api/sauvegarde") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            let state = data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]
            DispatchQueue.main.async {
                guard let c = self?.currentController else { return }
                if let err = (state?["erreur"] as? String) ?? error?.localizedDescription {
                    c.toast("✕ Sauvegarde en échec : \(err)", ok: false)
                } else if let name = state?["ecrit"] as? String {
                    c.toast("✓ Sauvegardé — \(name)")
                } else {
                    c.toast("✓ Déjà à jour — rien de neuf depuis la dernière sauvegarde")
                }
            }
        }.resume()
    }

    @objc func revealBackups(_ sender: Any?) {
        Paths.ensureDirectory(Paths.backupDirectory)
        NSWorkspace.shared.open(Paths.backupDirectory)
    }

    @objc func revealData(_ sender: Any?) {
        Paths.ensureDirectory(Paths.dataDirectory)
        NSWorkspace.shared.open(Paths.dataDirectory)
    }

    @objc func revealServerLog(_ sender: Any?) {
        NSWorkspace.shared.activateFileViewerSelecting([Paths.serverLog])
    }

    @objc func chooseBackupFolder(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choisir"
        panel.message = "Où écrire les sauvegardes JSON ? (iCloud Drive, un disque externe, un NAS…)"
        panel.directoryURL = Paths.backupDirectory
        guard panel.runModal() == .OK, let chosen = panel.url else { return }
        let previous = Paths.backupDirectory
        UserDefaults.standard.set(chosen.path, forKey: Paths.Key.backupDirectory)
        AppLog.write("dossier des sauvegardes : \(chosen.path)")
        restartServer(then: "/settings#sauvegardes")

        let alert = NSAlert()
        alert.messageText = "Les sauvegardes iront désormais dans « \(chosen.lastPathComponent) »"
        alert.informativeText = "Une première sauvegarde complète y est écrite tout de suite.\n"
            + "Les anciennes restent où elles étaient :\n\(previous.path)"
        alert.runModal()
    }

    private func restartServer(then path: String) {
        pendingPath = path
        port = nil
        server.stopAndWait()  // arrêt voulu : pas de « relance » derrière
        server.start()
    }

    // MARK: - Validation des menus

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(goBack(_:)):
            return currentController?.webView.canGoBack ?? false
        case #selector(goForward(_:)):
            return currentController?.webView.canGoForward ?? false
        case #selector(saveNow(_:)), #selector(openInBrowser(_:)), #selector(printPage(_:)),
             #selector(reloadPage(_:)):
            return port != nil && currentController != nil
        default:
            return true
        }
    }

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }
}

/// Le pont JS → app. Un seul message pour l'instant : imprimer.
@MainActor
final class ScriptBridge: NSObject, WKScriptMessageHandler {
    static let printHandler = "azaPrint"

    /// `window.print()` n'a aucun effet dans un WKWebView : on le redirige vers
    /// l'impression native. Les fenêtres ouvertes par `window.open("")` (export
    /// PDF du Patcher) reçoivent la même redirection.
    static let printShim = """
    (function () {
      function bridge(w) {
        try {
          w.print = function () { w.webkit.messageHandlers.\(printHandler).postMessage(null); };
        } catch (e) {}
      }
      bridge(window);
      var open = window.open;
      window.open = function () {
        var w = open.apply(window, arguments);
        if (w) bridge(w);
        return w;
      };
    })();
    """

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == Self.printHandler,
              let controller = message.webView?.window?.windowController as? BrowserWindowController
        else { return }
        // Laisser la page finir son tour de boucle (images, polices) avant d'imprimer.
        DispatchQueue.main.async { controller.printPage() }
    }
}
