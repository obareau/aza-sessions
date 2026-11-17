import AppKit
import AZACore
import SwiftUI

/// Une sauvegarde listée dans l'historique.
struct BackupItem: Identifiable, Hashable {
    enum Origin: String { case local = "Sur ce Mac", conflict = "Conflits", cloud = "iCloud Drive", other = "Autre fichier" }
    let url: URL
    let origin: Origin
    var id: String { url.path }

    var date: Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }
    var size: String {
        let b = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        return ByteCountFormatter.string(fromByteCount: Int64(b), countStyle: .file)
    }
}

struct HistoryView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var prefs: Prefs
    let close: () -> Void
    @Local private var items: [BackupItem] = []
    @Local private var selected: BackupItem? = nil
    @Local private var backup: AZAData? = nil
    @Local private var loadError = ""
    @Local private var pickSessions: Set<Int> = []
    @Local private var pickDiary: Set<Int> = []
    @Local private var status = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("HISTORIQUE ET RESTAURATION").azaHeading(.headline)
                Spacer()
                if store.history.canUndo {
                    Text("⌘Z annule : \(store.history.undoLabel ?? "")").foregroundStyle(.secondary).azaFont(.caption)
                }
                Button("Fermer", action: close).keyboardShortcut(.cancelAction)
            }
            .padding(12)
            Divider()
            HSplitView {
                list.frame(minWidth: 260, idealWidth: 300, maxWidth: 380)
                detail.frame(minWidth: 460, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 860, minHeight: 560)
        .onAppear {
            reload()
            // Mode capture : ouvrir la plus ancienne sauvegarde locale, pour montrer une comparaison.
            if SnapshotRunner.dir != nil, let old = items.filter({ $0.origin == .local }).last { select(old) }
        }
    }

    func reload() {
        var out: [BackupItem] = []
        let fm = FileManager.default
        out += ((try? store.storage.backups()) ?? []).map { BackupItem(url: $0, origin: .local) }
        let dir = store.storage.backupDir
        out += ((try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [])
            .filter { ($0.lastPathComponent.hasPrefix("conflit-") || $0.lastPathComponent.hasPrefix("remplace-")) && $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
            .map { BackupItem(url: $0, origin: .conflict) }
        // En mode capture (données de démo), on ne montre pas les vraies sauvegardes iCloud.
        if SnapshotRunner.dir == nil {
            out += CloudBackup.list(CloudDrive.backupFolder).map { BackupItem(url: $0, origin: .cloud) }
        }
        out += CloudDrive.conflictCopies(of: store.storage.url).map { BackupItem(url: $0, origin: .conflict) }
        items = out
    }

    var list: some View {
        VStack(spacing: 0) {
            List(selection: Binding(get: { selected }, set: { select($0) })) {
                ForEach([BackupItem.Origin.local, .conflict, .cloud, .other], id: \.self) { o in
                    let group = items.filter { $0.origin == o }
                    if !group.isEmpty {
                        SwiftUI.Section {
                            ForEach(group) { b in
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(b.date?.formatted(date: .abbreviated, time: .shortened) ?? b.url.lastPathComponent)
                                    Text("\(b.url.lastPathComponent) · \(b.size)").foregroundStyle(.secondary).azaFont(.caption2, mono: true)
                                        .lineLimit(1)
                                }
                                .tag(Optional(b))
                            }
                        } header: { Text(o.rawValue.uppercased()).azaHeading(.caption2) }
                    }
                }
            }
            HStack {
                Button("Autre fichier…") {
                    if let u = Panels.open(types: ["json"]) {
                        let b = BackupItem(url: u, origin: .other)
                        items.append(b); select(b)
                    }
                }
                Button { reload() } label: { Image(systemName: "arrow.clockwise") }
                Spacer()
                Text("\(items.count) sauvegarde(s)").foregroundStyle(.secondary).azaFont(.caption)
            }
            .padding(8)
        }
    }

    func select(_ b: BackupItem?) {
        selected = b; backup = nil; loadError = ""; pickSessions = []; pickDiary = []; status = ""
        guard let b else { return }
        Store.ensureDownloaded(b.url)
        do { backup = try JSONStorage.decode(Data(contentsOf: b.url)) }
        catch { loadError = "Lecture impossible : \(error.localizedDescription)" }
    }

    @ViewBuilder var detail: some View {
        if let b = backup, let item = selected {
            let d = store.data.diff(fromBackup: b)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(item.date?.formatted(date: .complete, time: .shortened) ?? "").azaFont(.title3, mono: true)
                    Text("\(b.sessions.count) séances · \(b.diary.count) entrées de journal · \(b.catalogue.count) fiches · \(b.patches.count) patch\(b.patches.count > 1 ? "es" : "")")
                        .foregroundStyle(.secondary)
                    if d.isEmpty {
                        Label("Identique à l'état actuel.", systemImage: "checkmark.circle").foregroundStyle(.secondary)
                    } else {
                        Text("DEPUIS CETTE SAUVEGARDE").azaHeading()
                        ForEach(d.parts.filter { !$0.isEmpty }, id: \.name) { p in
                            HStack(alignment: .firstTextBaseline) {
                                Text(p.name).frame(width: 150, alignment: .leading)
                                Text(summary(p)).foregroundStyle(.secondary)
                            }
                        }
                        if !d.otherChanges.isEmpty {
                            HStack(alignment: .firstTextBaseline) {
                                Text("Aussi").frame(width: 150, alignment: .leading)
                                Text(d.otherChanges.joined(separator: ", ")).foregroundStyle(.secondary)
                            }
                        }
                        recoverable(b, d)
                    }
                    Divider()
                    HStack {
                        Button("Restaurer tout depuis cette sauvegarde…") {
                            guard Panels.confirm("Revenir à cette sauvegarde ?",
                                                 "Tout le document est remplacé. L'état actuel est sauvegardé avant, et ⌘Z annule.",
                                                 ok: "Restaurer") else { return }
                            store.restoreAll(from: b)
                            status = "✓ Restauré. ⌘Z pour annuler."
                            reload()
                        }
                        .disabled(d.isEmpty)
                        Button("Afficher dans le Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
                        Spacer()
                        Text(status).foregroundStyle(.secondary)
                    }
                }
                .padding(16)
            }
        } else if !loadError.isEmpty {
            Label(loadError, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath").font(.system(size: 34)).foregroundStyle(.tint)
                Text("Choisis une sauvegarde pour voir ce qui a changé depuis.").foregroundStyle(.secondary)
                Text("Les sauvegardes locales sont prises à l'ouverture et toutes les heures (12 gardées) ; "
                     + "celles d'iCloud Drive une fois par jour (30 gardées).")
                    .foregroundStyle(.tertiary).azaFont(.caption).multilineTextAlignment(.center).frame(maxWidth: 380)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    func summary(_ p: CollectionDiff) -> String {
        var parts: [String] = []
        if !p.onlyInBackup.isEmpty { parts.append("\(p.onlyInBackup.count) supprimé(s) depuis") }
        if !p.onlyInCurrent.isEmpty { parts.append("\(p.onlyInCurrent.count) créé(s) depuis") }
        if !p.changed.isEmpty { parts.append("\(p.changed.count) modifié(s)") }
        return parts.joined(separator: " · ")
    }

    /// Séances et entrées de journal récupérables une à une.
    @ViewBuilder func recoverable(_ b: AZAData, _ d: BackupDiff) -> some View {
        let s = d.parts.first { $0.name == "Séances" }!
        let j = d.parts.first { $0.name == "Journal" }!
        let sIds = s.onlyInBackup + s.changed, jIds = j.onlyInBackup + j.changed
        if !sIds.isEmpty || !jIds.isEmpty {
            Text("RÉCUPÉRER SANS TOUT RESTAURER").azaHeading()
            ForEach(sIds, id: \.self) { id in
                if let x = b.sessions.first(where: { $0.id == id }) {
                    Toggle(isOn: toggle($pickSessions, id)) {
                        Text("Séance · \(x.date) — \(x.displayTitle)") + Text(s.changed.contains(id) ? "  (modifiée depuis)" : "  (supprimée depuis)").foregroundColor(.secondary)
                    }
                }
            }
            ForEach(jIds, id: \.self) { id in
                if let x = b.diary.first(where: { $0.id == id }) {
                    Toggle(isOn: toggle($pickDiary, id)) {
                        Text("Journal · \(x.day) — \(x.displayTitle)") + Text(j.changed.contains(id) ? "  (modifiée depuis)" : "  (supprimée depuis)").foregroundColor(.secondary)
                    }
                }
            }
            HStack {
                Button("Récupérer la sélection") {
                    var cur = store.data
                    let n = cur.recover(sessions: Array(pickSessions), diary: Array(pickDiary), from: b)
                    store.data = cur
                    status = "✓ \(n) élément(s) récupéré(s). ⌘Z pour annuler."
                    pickSessions = []; pickDiary = []
                }
                .buttonStyle(.borderedProminent)
                .disabled(pickSessions.isEmpty && pickDiary.isEmpty)
                Text("Une version modifiée depuis revient à côté de l'actuelle, marquée « (restaurée) ».")
                    .foregroundStyle(.tertiary).azaFont(.caption)
            }
        }
    }

    func toggle(_ set: Binding<Set<Int>>, _ id: Int) -> Binding<Bool> {
        Binding(get: { set.wrappedValue.contains(id) },
                set: { on in if on { set.wrappedValue.insert(id) } else { set.wrappedValue.remove(id) } })
    }
}
