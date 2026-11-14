import AppKit
import AZACore
import SwiftUI
import WebKit

/// Une fiche à montrer, imprimer ou enregistrer en PDF.
struct PrintJob: Identifiable {
    let id = UUID()
    let title: String
    let html: String
    var landscape = false
    var fileName: String
}

extension Nav {
    @MainActor func print(_ job: PrintJob) { printJob = job }
}

/// Aperçu HTML + impression paginée A4 (WebKit), ou PDF via la même mise en page.
struct PrintPreview: View {
    let job: PrintJob
    let close: () -> Void
    @Local private var web: WKWebView? = nil
    @Local private var status = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(job.title).azaHeading(.headline)
                Text(job.landscape ? "A4 paysage" : "A4").foregroundStyle(.secondary).azaFont(.caption)
                Spacer()
                if !status.isEmpty { Text(status).foregroundStyle(.secondary).azaFont(.caption) }
                Button("Enregistrer en PDF…") { savePDF() }.disabled(web == nil)
                Button("Imprimer…") { run(toFile: nil) }.buttonStyle(.borderedProminent).disabled(web == nil)
                    .keyboardShortcut("p")
                Button("Fermer", action: close).keyboardShortcut(.cancelAction)
            }
            .padding(10)
            Divider()
            HTMLView(html: job.html) { web = $0 }
                .background(Color.white)
        }
        .frame(minWidth: job.landscape ? 1000 : 760, minHeight: 760)
    }

    func savePDF() {
        guard let url = Panels.save(name: job.fileName + ".pdf", ext: "pdf") else { return }
        run(toFile: url)
    }

    func run(toFile url: URL?) {
        guard let web, let window = web.window else { return }
        let info = NSPrintInfo.shared.copy() as! NSPrintInfo
        info.paperSize = NSSize(width: 595.2, height: 841.8)
        info.orientation = job.landscape ? .landscape : .portrait
        // Les marges sont tenues par la feuille elle-même (@page / .page).
        info.topMargin = 0; info.bottomMargin = 0; info.leftMargin = 0; info.rightMargin = 0
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        info.isHorizontallyCentered = true
        if let url {
            info.jobDisposition = .save
            info.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = url
        }
        let op = web.printOperation(with: info)
        op.jobTitle = job.fileName
        op.showsPrintPanel = url == nil
        op.showsProgressPanel = url == nil
        op.view?.frame = web.bounds
        op.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        if let url { status = "PDF enregistré : \(url.lastPathComponent)" }
    }
}

struct HTMLView: NSViewRepresentable {
    let html: String
    let ready: (WKWebView) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let w = WKWebView()
        w.loadHTMLString(html, baseURL: nil)
        DispatchQueue.main.async { ready(w) }
        return w
    }

    func updateNSView(_ w: WKWebView, context: Context) {}
}

/// Menu « Imprimer » d'une séance.
struct SessionPrintMenu: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    let session: Session

    var body: some View {
        Menu {
            Button("Fiche de séance") {
                nav.print(PrintJob(title: "Fiche de séance", html: Sheets.session(session, data: store.data, version: Store.version),
                                   fileName: "seance_\(session.date)_\(session.id)"))
            }
            Button("Fiche de rappel") {
                nav.print(PrintJob(title: "Fiche de rappel", html: Sheets.recall(session, data: store.data, version: Store.version),
                                   fileName: "rappel_\(session.date)_\(session.id)"))
            }
            Button("Feuille d'atelier (même matériel)") {
                nav.print(PrintJob(title: "Feuille d'atelier",
                                   html: Sheets.workshop(gear: session.allGear, data: store.data, version: Store.version),
                                   fileName: "atelier_\(Clock.today())"))
            }
            .disabled(session.allGear.isEmpty)
        } label: { Label("Imprimer", systemImage: "printer") }
    }
}
