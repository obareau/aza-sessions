import AppKit
import AZACore
import Foundation
import SwiftUI

/// État de l'app : le document en mémoire, sauvegardé en JSON à chaque
/// modification (écriture différée de 0,6 s pour regrouper la frappe).
@MainActor
final class Store: ObservableObject {
    static let version = "1.6.0"

    @Published var data: AZAData {
        didSet {
            guard data != oldValue else { return }
            // Le patcher suit le catalogue en direct. (Réaffecter `data` dans son
            // propre didSet ne relance pas l'observateur.)
            if data.catalogue != oldValue.catalogue || data.patches != oldValue.patches {
                var d = data
                if d.syncPatches() { data = d }
            }
            scheduleSave()
        }
    }
    @Published var lastError: String?
    @Published private(set) var lastSaved: Date?

    @Published private(set) var storage: JSONStorage
    private var pending: DispatchWorkItem?
    /// Fichier illisible au chargement : on ne l'écrase jamais, même après
    /// fermeture de l'alerte. Levé seulement en changeant de fichier.
    private var saveBlocked = false

    static var savedURL: URL {
        if let p = UserDefaults.standard.string(forKey: "dataFile"), !p.isEmpty { return URL(fileURLWithPath: p) }
        return JSONStorage.defaultURL
    }

    init() {
        storage = JSONStorage(url: Self.savedURL)
        data = AZAData()
        let (d, err) = Self.open(storage)
        data = d ?? Seed.initial()
        data.syncPatches()
        saveBlocked = d == nil
        lastError = err
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.flush() }
        }
    }

    /// Charge (ou crée) le fichier. `nil` = illisible, à ne pas écraser.
    private static func open(_ storage: JSONStorage, seed: AZAData? = nil) -> (AZAData?, String?) {
        do {
            if let d = try storage.load() {
                try storage.backup()
                return (d, nil)
            }
            let fresh = seed ?? Seed.initial()
            try storage.save(fresh)
            return (fresh, nil)
        } catch {
            return (nil, "Lecture impossible de \(storage.url.path) : \(error.localizedDescription). "
                    + "Le fichier n'a pas été modifié ; la sauvegarde y est suspendue.")
        }
    }

    /// Change de fichier : ouvre celui-ci s'il existe, sinon y écrit les données actuelles.
    func switchTo(url: URL) {
        flush()
        let next = JSONStorage(url: url)
        let (d, err) = Self.open(next, seed: data)
        guard let d else { lastError = err; return }
        pending?.cancel()
        storage = next
        saveBlocked = false
        data = d
        UserDefaults.standard.set(url == JSONStorage.defaultURL ? "" : url.path, forKey: "dataFile")
    }

    func backupNow() {
        flush()
        do { try storage.backup() } catch { lastError = "Sauvegarde impossible : \(error.localizedDescription)" }
        objectWillChange.send()
    }

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
