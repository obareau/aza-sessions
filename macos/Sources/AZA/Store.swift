import AppKit
import AZACore
import Foundation
import SwiftUI

/// État de l'app : le document en mémoire, sauvegardé en JSON à chaque
/// modification (écriture différée de 0,6 s pour regrouper la frappe).
@MainActor
final class Store: ObservableObject {
    static let version = "1.11.0"

    @Published var data: AZAData {
        didSet {
            guard data != oldValue else { return }
            // Le patcher suit le catalogue en direct. (Réaffecter `data` dans son
            // propre didSet ne relance pas l'observateur.)
            if data.catalogue != oldValue.catalogue || data.patches != oldValue.patches {
                var d = data
                if d.syncPatches() { data = d }
            }
            // Un rechargement depuis le disque (autre Mac) n'est pas une modification locale.
            if applyingExternal { return }
            if !applyingUndo { history.record(before: oldValue, after: data) }
            dirty = true
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
    /// Modifications locales pas encore écrites. Sans elles, rien n'est écrit :
    /// sur un dossier synchronisé, réécrire un fichier inchangé pourrait écraser
    /// ce qu'un autre Mac vient d'y mettre.
    private var dirty = false
    private var applyingExternal = false
    private var applyingUndo = false
    /// Annuler / rétablir sur tout le document (⌘Z / ⇧⌘Z).
    @Published private(set) var history = EditHistory()
    static let localBackups = 12
    /// Empreinte du fichier tel que nous l'avons lu ou écrit en dernier.
    private var diskPrint: FileFingerprint?
    private var watchTimer: Timer?
    @Published private(set) var lastExternalReload: Date?
    @Published private(set) var lastCloudBackup: Date? = UserDefaults.standard.object(forKey: "lastCloudBackup") as? Date
    @Published var cloudStatus = ""

    var inCloud: Bool { CloudDrive.contains(storage.url) }

    static var savedURL: URL {
        if let p = UserDefaults.standard.string(forKey: "dataFile"), !p.isEmpty { return URL(fileURLWithPath: p) }
        return JSONStorage.defaultURL
    }

    init() {
        storage = Self.makeStorage(Self.savedURL)
        data = AZAData()
        Self.ensureDownloaded(storage.url)
        let (d, err) = Self.open(storage)
        data = d ?? Seed.initial()
        data.syncPatches()
        saveBlocked = d == nil
        lastError = err
        // Les affectations ci-dessus passent par l'observateur de `data` : ce n'est
        // pas une modification. Sans ça, le fichier était réécrit à l'identique une
        // seconde après l'ouverture — de quoi écraser le travail d'un autre Mac.
        pending?.cancel(); pending = nil
        dirty = false
        history.clear()
        diskPrint = FileFingerprint.of(storage.url)
        // Sauvegarde locale toutes les heures (seulement si le fichier a changé).
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.flush(); try? self?.storage.backup() }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.flush()
                if UserDefaults.standard.bool(forKey: "cloudBackup") { self?.runCloudBackup() }
            }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkExternalChange() }
        }
        // Un autre Mac peut écrire à tout moment : on regarde le fichier toutes les 4 s.
        watchTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkExternalChange() }
        }
        // Sauvegarde iCloud : au lancement (après quelques secondes), puis toutes les heures.
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            MainActor.assumeIsolated { self?.cloudBackupIfDue() }
        }
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.cloudBackupIfDue() }
        }
    }

    /// iCloud « Optimiser le stockage » peut avoir déchargé le fichier : on le
    /// fait redescendre avant de lire (15 s au plus).
    static func ensureDownloaded(_ url: URL) {
        guard CloudDrive.isEvicted(url) else { return }
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/brctl")
        p.arguments = ["download", url.path]
        try? p.run()
        let limit = Date().addingTimeInterval(15)
        while CloudDrive.isEvicted(url) && Date() < limit { Thread.sleep(forTimeInterval: 0.25) }
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

    static func makeStorage(_ url: URL) -> JSONStorage {
        var s = JSONStorage(url: url)
        s.backupCount = localBackups
        return s
    }

    // MARK: Séance en cours

    func startLive(oblique: Bool = true) {
        guard data.live == nil else { return }
        var l = LiveSession()
        if oblique { l.oblique = data.randomOblique() ?? "" }
        data.live = l
    }

    /// Termine la séance en cours : crée la séance (durée, matériel, notes, prise) et lance le récap.
    @discardableResult
    func finishLive(prefs: Prefs) -> Int? {
        guard let l = data.live else { return nil }
        var s = Session(id: data.nextSessionId(), date: String(l.startedAt.prefix(10)))
        if let start = l.startDate { s.durationMin = max(1, Int(Date().timeIntervalSince(start) / 60)) }
        s.machines = l.machines; s.effects = l.effects; s.daws = l.daws; s.synthsIOS = l.synthsIOS
        s.plugins = l.plugins; s.mode = l.mode; s.intention = l.intention; s.oblique = l.oblique
        s.projectId = l.projectId; s.comments = l.notes
        s.audioFile = data.takeName(for: s)
        data.sessions.append(s)
        data.live = nil
        // Comme /new?from_live=1 de l'app web : le récap part en fond, la séance est déjà enregistrée.
        if prefs.recapAfterLive { generateRecap(s.id, baseURL: prefs.ollamaURL, model: prefs.ollamaModel) }
        return s.id
    }

    // MARK: Annuler / rétablir

    func undo() {
        guard let state = history.undo(current: data) else { return }
        applyingUndo = true
        data = state
        applyingUndo = false
    }

    func redo() {
        guard let state = history.redo(current: data) else { return }
        applyingUndo = true
        data = state
        applyingUndo = false
    }

    /// Remplace tout le document par une sauvegarde (annulable, et l'état actuel est sauvegardé avant).
    func restoreAll(from backup: AZAData) {
        flush()
        try? storage.backup()
        data = backup
    }

    /// Change de fichier : ouvre celui-ci s'il existe, sinon y écrit les données actuelles.
    func switchTo(url: URL) {
        flush()
        let next = Self.makeStorage(url)
        let (d, err) = Self.open(next, seed: data)
        guard let d else { lastError = err; return }
        pending?.cancel()
        storage = next
        saveBlocked = false
        applyingExternal = true
        data = d
        applyingExternal = false
        dirty = false
        history.clear()
        diskPrint = FileFingerprint.of(next.url)
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
        guard !saveBlocked, dirty else { return }
        // Le fichier a changé sur le disque depuis notre dernière lecture (un autre
        // Mac, via iCloud) alors qu'on a aussi des modifications : on garde les
        // deux. La version du disque part en « conflit-… » dans backups/.
        if let disk = FileFingerprint.of(storage.url), let known = diskPrint, disk != known {
            let dest = storage.backupDir.appendingPathComponent("conflit-\(Clock.stamp().replacingOccurrences(of: ":", with: "-")).json")
            try? FileManager.default.createDirectory(at: storage.backupDir, withIntermediateDirectories: true)
            try? FileManager.default.copyItem(at: storage.url, to: dest)
            lastError = "Le fichier a été modifié ailleurs (un autre Mac ?) pendant que tu écrivais ici. Tes modifications "
                + "sont gardées ; l'autre version est conservée dans backups/\(dest.lastPathComponent)."
        }
        do {
            try coordinatedSave(data)
            dirty = false
            diskPrint = FileFingerprint.of(storage.url)
            lastSaved = Date()
        } catch {
            lastError = "Sauvegarde impossible : \(error.localizedDescription)"
        }
    }

    /// Écriture coordonnée : iCloud Drive sait qu'on écrit et ne mélange pas les versions.
    private func coordinatedSave(_ d: AZAData) throws {
        guard inCloud else { try storage.save(d); return }
        var coordErr: NSError?
        var saveErr: Error?
        NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: storage.url, options: .forReplacing, error: &coordErr) { url in
            do { try JSONStorage(url: url).save(d) } catch { saveErr = error }
        }
        if let e = coordErr ?? saveErr { throw e }
    }

    /// Recharge si un autre Mac a écrit le fichier (et qu'on n'a rien en attente ici).
    func checkExternalChange() {
        guard !saveBlocked, !dirty else { return }
        if CloudDrive.isEvicted(storage.url) {
            try? FileManager.default.startDownloadingUbiquitousItem(at: storage.url)
            return
        }
        guard let disk = FileFingerprint.of(storage.url), disk != diskPrint,
              let raw = try? Data(contentsOf: storage.url),
              let fresh = try? JSONStorage.decode(raw) else { return }   // fichier en cours de synchro : on réessaiera
        applyingExternal = true
        var d = fresh
        d.syncPatches()
        data = d
        applyingExternal = false
        diskPrint = disk
        // Annuler ramènerait l'état d'avant l'autre Mac : on repart d'une pile vide.
        history.clear()
        lastExternalReload = Date()
    }

    // MARK: iCloud Drive

    /// Déplace les données (JSON, médias, sauvegardes) dans iCloud Drive.
    /// `useExisting` : un fichier AZA y est déjà (autre Mac) — on l'ouvre au lieu de l'écraser.
    func moveToCloud(useExisting: Bool) {
        flush()
        let dst = CloudDrive.dataFolder.appendingPathComponent("aza-sessions.json")
        do {
            try DataFolder.copy(json: storage.url, to: dst, overwriteJSON: !useExisting)
            switchTo(url: dst)
            cloudStatus = useExisting ? "✓ Données d'iCloud Drive ouvertes (médias et sauvegardes de ce Mac ajoutés)"
                                      : "✓ Données déplacées dans iCloud Drive"
        } catch {
            lastError = "Copie vers iCloud Drive impossible : \(error.localizedDescription)"
        }
    }

    /// Revient au stockage local (copie depuis iCloud Drive, qui reste intact).
    func moveToLocal() {
        flush()
        let dst = JSONStorage.defaultURL
        do {
            try DataFolder.copy(json: storage.url, to: dst, overwriteJSON: true)
            switchTo(url: dst)
            cloudStatus = "✓ Données recopiées sur ce Mac ; la copie dans iCloud Drive n'est plus utilisée"
        } catch {
            lastError = "Copie vers ce Mac impossible : \(error.localizedDescription)"
        }
    }

    func cloudBackupIfDue() {
        guard UserDefaults.standard.bool(forKey: "cloudBackup") else { return }
        if let last = lastCloudBackup, Date().timeIntervalSince(last) < 6 * 3600 { return }
        runCloudBackup()
    }

    /// Copie datée du JSON (30 jours) et miroir des médias dans iCloud Drive.
    func runCloudBackup() {
        guard CloudDrive.available else { cloudStatus = "✗ iCloud Drive n'est pas activé sur ce Mac"; return }
        flush()
        do {
            let r = try CloudBackup.run(json: storage.url, media: mediaDir, into: CloudDrive.backupFolder)
            lastCloudBackup = Date()
            UserDefaults.standard.set(lastCloudBackup, forKey: "lastCloudBackup")
            cloudStatus = (r.file.map { "✓ Sauvegardé : \($0.lastPathComponent)" } ?? "✓ Déjà à jour")
                + (r.mediaCopied > 0 ? " · \(r.mediaCopied) média(s) copiés" : "")
        } catch {
            cloudStatus = "✗ Sauvegarde iCloud impossible : \(error.localizedDescription)"
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

    // MARK: Récap IA

    @Published private(set) var recapRunning: Set<Int> = []
    @Published var recapErrors: [Int: String] = [:]

    /// Récap Ollama d'une séance, en tâche de fond. Tout échec est gardé et affiché.
    func generateRecap(_ id: Int, baseURL: String, model: String) {
        guard !recapRunning.contains(id), let s = data.sessions.first(where: { $0.id == id }) else { return }
        guard let req = Recap.request(for: s, baseURL: baseURL, model: model) else {
            recapErrors[id] = "Adresse du serveur Ollama invalide : « \(baseURL) » (Réglages › Obsidian & IA)."
            return
        }
        recapRunning.insert(id)
        recapErrors[id] = nil
        Task {
            do {
                let (body, resp) = try await URLSession.shared.data(for: req)
                switch Recap.parse(body, status: (resp as? HTTPURLResponse)?.statusCode ?? 0) {
                case .success(let text):
                    if let i = data.sessions.firstIndex(where: { $0.id == id }) { data.sessions[i].recapClaude = text }
                case .failure(let e):
                    recapErrors[id] = e.message + " (modèle « \(model) »)"
                }
            } catch {
                recapErrors[id] = "Ollama injoignable sur \(baseURL) : \(error.localizedDescription)"
            }
            recapRunning.remove(id)
        }
    }

    // MARK: Vault Obsidian

    /// Écrit la séance dans le vault ; rend un message pour l'interface.
    @discardableResult
    func exportToVault(_ ids: [Int], folder: String) -> String {
        guard !folder.isEmpty else {
            lastError = "Dossier du vault Obsidian non configuré (Réglages › Obsidian & IA)."
            return ""
        }
        let url = URL(fileURLWithPath: (folder as NSString).expandingTildeInPath, isDirectory: true)
        var written = 0
        for id in ids {
            guard let s = data.sessions.first(where: { $0.id == id }) else { continue }
            do { _ = try data.exportToVault(s, folder: url, version: Self.version); written += 1 }
            catch { lastError = "Écriture dans le vault impossible : \(error.localizedDescription)"; return "" }
        }
        return ids.count == 1 ? "→ \(AZAData.obsidianFileName(data.sessions.first { $0.id == ids[0] }!))"
                              : "\(written) séance(s) écrites dans le vault"
    }

    func exportCSV(to url: URL) {
        do { try data.csv().write(to: url, atomically: true, encoding: .utf8) }
        catch { lastError = "Export CSV impossible : \(error.localizedDescription)" }
    }

    /// Supprime toutes les séances (après une sauvegarde datée).
    func resetSessions() {
        flush()
        try? storage.backup()
        data.sessions = []
        data.live = nil
        for p in data.patches.indices { data.patches[p].sessionId = nil }
        for i in data.presets.indices { data.presets[i].sessionId = nil }
        for i in data.knobSheets.indices { data.knobSheets[i].sessionId = nil }
        flush()
    }

    // MARK: Journal — médias à côté du JSON

    var mediaDir: URL {
        storage.url.deletingLastPathComponent().appendingPathComponent("journal-media", isDirectory: true)
    }

    func mediaURL(_ a: DiaryAttachment) -> URL { mediaDir.appendingPathComponent(a.file) }

    @discardableResult
    func newDiaryEntry(prompt: DiaryPrompt? = nil, day: String? = nil) -> Int {
        var e = DiaryEntry(id: nextId(data.diary))
        if let day { e.date = day + " " + String(Clock.stamp().suffix(8)) }
        if let p = prompt {
            e.prompt = p.text
            if let s = p.sessionId { e.sessionIds = [s]; e.associations = ["Musique"] }
            if let g = p.gearId { e.gearIds = [g]; e.associations = ["Matériel"] }
            if let pa = p.patchId { e.patchIds = [pa] }
            if p.lore != nil { e.associations = ["Lore"] }
        }
        data.diary.append(e)
        return e.id
    }

    /// Copie un fichier dans journal-media/ et l'attache à l'entrée.
    func attach(_ source: URL, to entryId: Int, kind: DiaryAttachment.Kind? = nil, move: Bool = false) {
        guard let i = data.diary.firstIndex(where: { $0.id == entryId }) else { return }
        do {
            try FileManager.default.createDirectory(at: mediaDir, withIntermediateDirectories: true)
            let ext = source.pathExtension.isEmpty ? "bin" : source.pathExtension.lowercased()
            let name = "\(UUID().uuidString.prefix(8).lowercased())-\(Clock.day(Date()).replacingOccurrences(of: "-", with: "")).\(ext)"
            let dest = mediaDir.appendingPathComponent(name)
            if move { try FileManager.default.moveItem(at: source, to: dest) }
            else { try FileManager.default.copyItem(at: source, to: dest) }
            var a = DiaryAttachment(kind: kind ?? DiaryAttachment.kind(forExtension: ext), file: name)
            if !move { a.caption = source.deletingPathExtension().lastPathComponent }
            data.diary[i].attachments.append(a)
            data.diary[i].updatedAt = Clock.stamp()
        } catch {
            lastError = "Impossible d'ajouter « \(source.lastPathComponent) » : \(error.localizedDescription)"
        }
    }

    /// Retire un média : le fichier part à la corbeille (récupérable), jamais effacé.
    func detach(_ a: DiaryAttachment, from entryId: Int) {
        guard let i = data.diary.firstIndex(where: { $0.id == entryId }) else { return }
        data.diary[i].attachments.removeAll { $0.id == a.id }
        try? FileManager.default.trashItem(at: mediaURL(a), resultingItemURL: nil)
    }

    func deleteDiaryEntry(_ id: Int) {
        guard let e = data.diary.first(where: { $0.id == id }) else { return }
        for a in e.attachments { try? FileManager.default.trashItem(at: mediaURL(a), resultingItemURL: nil) }
        data.diary.removeAll { $0.id == id }
    }

    func exportDiaryToVault(_ ids: [Int], folder: String) -> String {
        guard !folder.isEmpty else {
            lastError = "Dossier du vault Obsidian non configuré (Réglages › Obsidian & IA)."
            return ""
        }
        let base = URL(fileURLWithPath: (folder as NSString).expandingTildeInPath, isDirectory: true)
        let dir = base.appendingPathComponent("Journal", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            for id in ids {
                guard let e = data.diary.first(where: { $0.id == id }) else { continue }
                try data.diaryMarkdown(e).write(to: dir.appendingPathComponent(AZAData.diaryFileName(e)), atomically: true, encoding: .utf8)
                // Les médias suivent, pour que les ![[…]] s'affichent dans Obsidian.
                for a in e.attachments where FileManager.default.fileExists(atPath: mediaURL(a).path) {
                    let dest = dir.appendingPathComponent(a.file)
                    if !FileManager.default.fileExists(atPath: dest.path) { try FileManager.default.copyItem(at: mediaURL(a), to: dest) }
                }
            }
            return "\(ids.count) entrée(s) écrite(s) dans \(dir.lastPathComponent)/"
        } catch {
            lastError = "Écriture dans le vault impossible : \(error.localizedDescription)"
            return ""
        }
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
