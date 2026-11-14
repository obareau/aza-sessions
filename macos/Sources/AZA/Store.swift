import AppKit
import AZACore
import Foundation
import SwiftUI

/// État de l'app : le document en mémoire, sauvegardé en JSON à chaque
/// modification (écriture différée de 0,6 s pour regrouper la frappe).
@MainActor
final class Store: ObservableObject {
    static let version = "1.0.0"

    @Published var data: AZAData {
        didSet { if data != oldValue { scheduleSave() } }
    }
    @Published var lastError: String?
    @Published private(set) var lastSaved: Date?

    let storage: JSONStorage
    private var pending: DispatchWorkItem?

    init(storage: JSONStorage = JSONStorage(url: JSONStorage.defaultURL)) {
        self.storage = storage
        var loaded: AZAData
        var err: String?
        do {
            if let d = try storage.load() {
                loaded = d
                try storage.backup()
            } else {
                loaded = Seed.initial()
                try storage.save(loaded)
            }
        } catch {
            // Fichier illisible : on ne l'écrase surtout pas, on travaille sur
            // une base vide et la sauvegarde est suspendue.
            loaded = Seed.initial()
            err = "Lecture impossible de \(storage.url.path) : \(error.localizedDescription). " +
                  "Le fichier n'a pas été modifié ; la sauvegarde est suspendue."
        }
        data = loaded
        lastError = err
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.flush() }
        }
    }

    private var saveBlocked: Bool { lastError?.hasPrefix("Lecture impossible") == true }

    private func scheduleSave() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.flush() }
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    func flush() {
        pending?.cancel(); pending = nil
        guard !saveBlocked else { return }
        do {
            try storage.save(data)
            lastSaved = Date()
        } catch {
            lastError = "Sauvegarde impossible : \(error.localizedDescription)"
        }
    }

    // MARK: Séances

    @discardableResult
    func newSession(from template: Session? = nil) -> Int {
        var s = Session(id: data.nextSessionId(), date: Clock.today())
        if let t = template {
            for f in GearField.allCases { s[keyPath: f.keyPath] = t[keyPath: f.keyPath] }
            s.mode = t.mode; s.intention = t.intention; s.signalRouting = t.signalRouting
            s.projectId = t.projectId; s.sessionType = t.sessionType
            s.linkedSession = t.id
        }
        s.oblique = data.randomOblique() ?? ""
        data.sessions.append(s)
        return s.id
    }

    func deleteSession(_ id: Int) {
        data.sessions.removeAll { $0.id == id }
        for i in data.sessions.indices where data.sessions[i].linkedSession == id {
            data.sessions[i].linkedSession = nil
        }
    }

    func binding(session id: Int) -> Binding<Session>? {
        guard data.sessions.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { self.data.sessions.first { $0.id == id } ?? Session(id: id, date: Clock.today()) },
            set: { new in
                if let i = self.data.sessions.firstIndex(where: { $0.id == id }) { self.data.sessions[i] = new }
            })
    }

    // MARK: Fichiers

    func importSQLite(url: URL) {
        do {
            let imported = try SQLiteImport.load(path: url.path)
            flush()
            try storage.backup()
            data = imported
            flush()
        } catch {
            lastError = "Import impossible : \(error)"
        }
    }

    func importJSON(url: URL) {
        do {
            let imported = try JSONStorage.decode(Data(contentsOf: url))
            flush()
            try storage.backup()
            data = imported
            flush()
        } catch {
            lastError = "Import JSON impossible : \(error.localizedDescription)"
        }
    }

    func exportJSON(to url: URL) {
        do { try JSONStorage.encode(data).write(to: url, options: .atomic) }
        catch { lastError = "Export impossible : \(error.localizedDescription)" }
    }

    func exportMarkdown(_ sessions: [Session], to url: URL) {
        let md = sessions.map { data.markdown($0, version: Self.version) }.joined(separator: "\n\n")
        do { try md.write(to: url, atomically: true, encoding: .utf8) }
        catch { lastError = "Export impossible : \(error.localizedDescription)" }
    }

    func revealFile() {
        flush()
        NSWorkspace.shared.activateFileViewerSelecting([storage.url])
    }
}

enum Panels {
    @MainActor static func open(types: [String]) -> URL? {
        let p = NSOpenPanel()
        p.allowsMultipleSelection = false
        p.canChooseDirectories = false
        p.allowedContentTypes = types.compactMap { .init(filenameExtension: $0) }
        return p.runModal() == .OK ? p.url : nil
    }

    @MainActor static func save(name: String, ext: String) -> URL? {
        let p = NSSavePanel()
        p.nameFieldStringValue = name
        p.allowedContentTypes = [.init(filenameExtension: ext)].compactMap { $0 }
        return p.runModal() == .OK ? p.url : nil
    }

    @MainActor static func confirm(_ title: String, _ text: String, ok: String) -> Bool {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = text
        a.alertStyle = .warning
        a.addButton(withTitle: ok)
        a.addButton(withTitle: "Annuler")
        return a.runModal() == .alertFirstButtonReturn
    }
}
