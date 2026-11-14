import AppKit
import WebKit

/// Une fenêtre AZA : un WKWebView sur le serveur local.
///
/// WKWebView ne fait rien tout seul de ce qu'un navigateur offre d'office.
/// Sans les délégués ci-dessous, sur les pages d'AZA :
///  - `confirm()` renverrait `false` → aucun bouton « Supprimer » ne marcherait ;
///  - `<input type=file>` ne s'ouvrirait pas → pas d'import ni de restauration ;
///  - les fichiers servis en pièce jointe (export JSON, .db, Markdown) ne
///    seraient pas téléchargés ;
///  - `window.print()` serait muet → ni fiches, ni feuille d'atelier, ni rappel.
@MainActor
final class BrowserWindowController: NSWindowController, NSWindowDelegate,
                                     WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
    let webView: WKWebView
    var onClose: ((BrowserWindowController) -> Void)?
    private var titleObservation: NSKeyValueObservation?

    init(configuration: WKWebViewConfiguration, isMain: Bool) {
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1280, height: 860),
                            configuration: configuration)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1280, height: 860),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.minSize = NSSize(width: 720, height: 520)
        window.title = Paths.appName
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false
        window.contentView = webView
        super.init(window: window)

        window.delegate = self
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true
        webView.pageZoom = AppDelegate.savedPageZoom
        if #available(macOS 13.3, *) { webView.isInspectable = true }

        titleObservation = webView.observe(\.title, options: [.new]) { [weak self] view, _ in
            let title = view.title ?? ""
            self?.window?.title = title.isEmpty ? Paths.appName : title
        }

        if isMain {
            windowFrameAutosaveName = "AZAFenetrePrincipale"
            if !window.setFrameUsingName(windowFrameAutosaveName) { window.center() }
        } else {
            window.setContentSize(NSSize(width: 1100, height: 800))
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) non pris en charge") }

    // MARK: - Contenu

    func load(path: String) {
        guard let url = AppDelegate.shared.url(for: path) else { return }
        webView.load(URLRequest(url: url))
    }

    func showMessage(title: String, detail: String, busy: Bool) {
        let esc: (String) -> String = {
            $0.replacingOccurrences(of: "&", with: "&amp;")
              .replacingOccurrences(of: "<", with: "&lt;")
              .replacingOccurrences(of: ">", with: "&gt;")
        }
        let html = """
        <!doctype html><html><head><meta charset="utf-8"><style>
        html,body{margin:0;height:100%;background:#0d0d0d;color:#d6d0c4;
          font:13px ui-monospace,Menlo,monospace;display:flex;align-items:center;justify-content:center}
        .box{max-width:640px;padding:32px;text-align:center}
        h1{font-size:13px;letter-spacing:.3em;color:#e8590c;margin:0 0 18px;font-weight:600}
        p{color:#8a847a;white-space:pre-wrap;line-height:1.6;text-align:left}
        .dot{display:inline-block;width:8px;height:8px;border-radius:50%;background:#e8590c;
          margin-right:10px;animation:p 1.2s infinite}
        @keyframes p{50%{opacity:.2}}
        </style></head><body><div class="box">
        <h1>\(busy ? "<span class=\"dot\"></span>" : "")\(esc(title))</h1>
        <p>\(esc(detail))</p></div></body></html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    /// Petit message en bas de la page, qui s'efface seul (⌘S, impression…).
    func toast(_ message: String, ok: Bool = true) {
        guard let data = try? JSONSerialization.data(withJSONObject: [message]),
              let arg = String(data: data, encoding: .utf8) else { return }
        let js = """
        (function(m, ok){ var d=document.createElement('div'); d.textContent=m;
          d.style.cssText='position:fixed;bottom:24px;left:50%;transform:translateX(-50%);'+
          'z-index:2147483647;padding:10px 18px;border-radius:6px;font:12px ui-monospace,Menlo,monospace;'+
          'background:'+(ok?'#0F1F15':'#2A1710')+';color:'+(ok?'#3DCC7E':'#E8590C')+';'+
          'border:1px solid currentColor;box-shadow:0 6px 24px rgba(0,0,0,.35);transition:opacity .4s';
          document.body.appendChild(d);
          setTimeout(function(){ d.style.opacity='0'; }, 2600);
          setTimeout(function(){ d.remove(); }, 3100); })(\(arg)[0], \(ok ? "true" : "false"));
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    // MARK: - Impression

    func printPage() {
        guard let info = NSPrintInfo.shared.copy() as? NSPrintInfo else { return }
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        info.isHorizontallyCentered = true
        info.isVerticallyCentered = false
        for side in [\NSPrintInfo.topMargin, \NSPrintInfo.bottomMargin,
                     \NSPrintInfo.leftMargin, \NSPrintInfo.rightMargin] {
            info[keyPath: side] = 24
        }
        let op = webView.printOperation(with: info)
        op.showsPrintPanel = true
        op.showsProgressPanel = true
        // Sans cadre explicite, WebKit imprime des pages blanches.
        op.view?.frame = webView.bounds
        if let window = window {
            op.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        } else {
            op.run()
        }
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        onClose?(self)
    }

    // MARK: - Navigation

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        if navigationAction.shouldPerformDownload {
            decisionHandler(.download)
            return
        }
        if AppDelegate.shared.isInternal(url) {
            decisionHandler(.allow)
            return
        }
        // Lien vers l'extérieur (robotariis.com, fiche d'un fabricant, mailto,
        // fichier local) : le navigateur ou l'app par défaut, pas cette fenêtre.
        if navigationAction.navigationType == .linkActivated || navigationAction.targetFrame == nil
            || navigationAction.targetFrame?.isMainFrame == true {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)  // ressource d'un cadre secondaire
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let http = navigationResponse.response as? HTTPURLResponse,
           let disposition = http.value(forHTTPHeaderField: "Content-Disposition"),
           disposition.lowercased().hasPrefix("attachment") {
            decisionHandler(.download)
            return
        }
        decisionHandler(navigationResponse.canShowMIMEType ? .allow : .download)
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse,
                 didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction,
                 didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let url = webView.url, url.scheme == "http" {
            AppLog.write("page chargée : \(url.path) — \(webView.title ?? "")")
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        let nsError = error as NSError
        // Annulée par nous (lien externe, téléchargement) : pas une panne.
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled { return }
        if nsError.domain == "WebKitErrorDomain" && nsError.code == 102 { return }
        AppLog.write("échec de chargement : \(error.localizedDescription)")
        showMessage(title: "PAGE INACCESSIBLE",
                    detail: "\(error.localizedDescription)\n\nAZA relance son serveur si besoin ; "
                        + "sinon : menu Aide → Journal du serveur.",
                    busy: false)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        AppLog.write("processus web terminé — rechargement")
        webView.reload()
    }

    // MARK: - Téléchargements

    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse,
                  suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedFilename
        panel.canCreateDirectories = true
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory,
                                                      in: .userDomainMask).first
        let finish: (NSApplication.ModalResponse) -> Void = { result in
            guard result == .OK, let url = panel.url else { completionHandler(nil); return }
            // WKDownload refuse d'écrire sur un fichier existant ; le panneau a
            // déjà fait confirmer le remplacement.
            try? FileManager.default.removeItem(at: url)
            completionHandler(url)
        }
        if let window = window {
            panel.beginSheetModal(for: window, completionHandler: finish)
        } else {
            finish(panel.runModal())
        }
    }

    func downloadDidFinish(_ download: WKDownload) {
        toast("✓ Fichier enregistré")
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled { return }
        toast("✕ Téléchargement en échec : \(error.localizedDescription)", ok: false)
    }

    // MARK: - Fenêtres et boîtes de dialogue

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        let url = navigationAction.request.url
        if let url = url, !AppDelegate.shared.isInternal(url) {
            NSWorkspace.shared.open(url)
            return nil
        }
        // `target=_blank` vers AZA, ou `window.open("")` du Patcher pour imprimer :
        // une vraie fenêtre, avec la configuration que WebKit impose.
        let controller = AppDelegate.shared.openWindow(configuration: configuration, isMain: false)
        return controller.webView
    }

    func webViewDidClose(_ webView: WKWebView) {
        window?.close()
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = Self.alert(for: message)
        alert.addButton(withTitle: "OK")
        presentAlert(alert) { _ in completionHandler() }
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        let alert = Self.alert(for: message)
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Annuler")
        presentAlert(alert) { completionHandler($0 == .alertFirstButtonReturn) }
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        let alert = Self.alert(for: prompt)
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.stringValue = defaultText ?? ""
        alert.accessoryView = field
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Annuler")
        alert.window.initialFirstResponder = field
        presentAlert(alert) { completionHandler($0 == .alertFirstButtonReturn ? field.stringValue : nil) }
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping ([URL]?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.canChooseFiles = true
        let finish: (NSApplication.ModalResponse) -> Void = { result in
            completionHandler(result == .OK ? panel.urls : nil)
        }
        if let window = window {
            panel.beginSheetModal(for: window, completionHandler: finish)
        } else {
            finish(panel.runModal())
        }
    }

    // MARK: - Aides

    /// Première ligne en titre, le reste en détail : les `confirm()` d'AZA
    /// séparent la question de l'explication par une ligne vide.
    private static func alert(for message: String) -> NSAlert {
        let alert = NSAlert()
        let parts = message.components(separatedBy: "\n")
        alert.messageText = parts.first ?? message
        alert.informativeText = parts.dropFirst().joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return alert
    }

    private func presentAlert(_ alert: NSAlert,
                         completion: @escaping (NSApplication.ModalResponse) -> Void) {
        if let window = window, window.isVisible {
            alert.beginSheetModal(for: window, completionHandler: completion)
        } else {
            completion(alert.runModal())
        }
    }
}
