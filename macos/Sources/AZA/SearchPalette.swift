import AppKit
import AZACore
import SwiftUI

/// Une ligne de la palette : un résultat de recherche, un écran ou une action.
struct PaletteRow: Identifiable {
    let id: String
    let icon: String
    let title: String
    let subtitle: String
    let snippet: String
    let badge: String
    let run: () -> Void
}

/// Palette ⌘K : chercher dans tout AZA, aller à un écran, lancer une action.
struct SearchPalette: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @EnvironmentObject var prefs: Prefs
    @EnvironmentObject var lore: LoreCache
    @Local private var query = ""
    @Local private var index = 0
    @Local private var monitor: Any? = nil
    @Local private var contentHeight: CGFloat = 200
    @FocusState private var focused: Bool

    var rows: [PaletteRow] {
        let q = query.trimmingCharacters(in: .whitespaces)
        var out: [PaletteRow] = []
        let terms = SearchText.terms(q)
        // Actions et écrans dont le nom correspond (ou les principaux quand rien n'est tapé)
        let commands = actions + Pane.allCases.map { p in
            PaletteRow(id: "pane-\(p.rawValue)", icon: p.icon, title: p.label, subtitle: "Aller à", snippet: "", badge: "Écran") {
                nav.pane = p
            }
        }
        let matching = commands.filter { r in
            let t = SearchText.fold(r.title)
            return !terms.isEmpty && terms.allSatisfy { t.contains($0) }
        }
        if q.isEmpty {
            out += recent
            out += actions
        } else {
            out += matching.prefix(4)
            out += store.data.globalSearch(q, lore: lore.entries).map(row)
        }
        return out
    }

    var actions: [PaletteRow] {
        [
            PaletteRow(id: "a-session", icon: "plus", title: "Nouvelle séance", subtitle: "⌘N", snippet: "", badge: "Action") {
                nav.open(session: store.newSession())
            },
            PaletteRow(id: "a-diary", icon: "square.and.pencil", title: "Nouvelle entrée de journal", subtitle: "⇧⌘J", snippet: "", badge: "Action") {
                nav.pane = .diary; nav.diary = store.newDiaryEntry()
            },
            PaletteRow(id: "a-quick", icon: "bolt", title: "Séance rapide", subtitle: "⇧⌘N", snippet: "", badge: "Action") {
                nav.quick = QuickRequest(gear: [])
            },
            PaletteRow(id: "a-live", icon: "record.circle", title: store.data.live == nil ? "Démarrer une séance en cours" : "Séance en cours",
                       subtitle: "⇧⌘L", snippet: "", badge: "Action") {
                store.startLive(); nav.pane = .live
            },
            PaletteRow(id: "a-tonight", icon: "moon.stars", title: "Ce soir — tirer une séance", subtitle: "⇧⌘T", snippet: "", badge: "Action") {
                nav.pane = .tonight
            },
            PaletteRow(id: "a-history", icon: "clock.arrow.circlepath", title: "Historique et restauration", subtitle: "⇧⌘Y", snippet: "", badge: "Action") {
                nav.history = true
            },
        ]
    }

    /// Sans saisie : ce sur quoi tu as travaillé dernièrement.
    var recent: [PaletteRow] {
        let s = store.data.sessions.sorted { ($0.date, $0.id) > ($1.date, $1.id) }.prefix(3).map { x in
            row(SearchHit(kind: .session, ref: String(x.id), title: x.displayTitle, subtitle: x.date, snippet: "", score: 0, date: x.date))
        }
        let d = store.data.diary.sorted { $0.updatedAt > $1.updatedAt }.prefix(3).map { e in
            row(SearchHit(kind: .diary, ref: String(e.id), title: e.displayTitle, subtitle: e.day, snippet: "", score: 0, date: e.date))
        }
        return d + s
    }

    func row(_ h: SearchHit) -> PaletteRow {
        let icon: String
        switch h.kind {
        case .session: icon = "waveform"
        case .diary: icon = "book.pages"
        case .gear: icon = "pianokeys"
        case .patch: icon = "point.3.connected.trianglepath.dotted"
        case .project: icon = "folder"
        case .preset: icon = "slider.horizontal.3"
        case .knob: icon = "dial.medium"
        case .lore: icon = "book.closed"
        case .influence: icon = "person.2"
        case .oblique: icon = "suit.diamond"
        case .track: icon = "music.note.list"
        case .inspiration: icon = "lightbulb"
        case .sample: icon = "square.stack.3d.up"
        case .mirack: icon = "hexagon"
        case .wish: icon = "cart"
        case .sysex: icon = "cable.connector.horizontal"
        }
        return PaletteRow(id: h.id, icon: icon, title: h.title, subtitle: h.subtitle, snippet: h.snippet, badge: h.kind.rawValue) {
            open(h)
        }
    }

    /// Aller à l'élément trouvé.
    func open(_ h: SearchHit) {
        switch h.kind {
        case .session: if let i = h.intRef { nav.open(session: i) }
        case .diary: nav.pane = .diary; nav.diary = h.intRef
        case .gear: if let i = h.intRef { nav.open(gear: i) }
        case .patch: if let i = h.intRef { nav.open(patch: i) }
        case .project: nav.pane = .projects
        case .preset: nav.paneQuery = h.title; nav.pane = .presets
        case .knob:
            if let k = store.data.knobSheets.first(where: { String($0.id) == h.ref }) { nav.open(gear: k.gearId) }
        case .lore: nav.paneQuery = h.title; nav.pane = .lore
        case .influence: nav.pane = .influences
        case .oblique: nav.pane = .obliques
        case .track: nav.paneQuery = h.title; nav.pane = .tracks
        case .inspiration: nav.paneQuery = h.title; nav.pane = .inspirations
        case .sample: nav.paneQuery = h.title; nav.pane = .samples
        case .mirack: nav.paneQuery = h.title; nav.pane = .mirack
        case .wish: nav.paneQuery = h.title; nav.pane = .wishlist
        case .sysex: nav.pane = .sysex
        }
    }

    func runSelected() {
        let r = rows
        guard r.indices.contains(index) else { return }
        close()
        r[index].run()
    }

    func close() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
        nav.palette = false
    }

    var body: some View {
        let list = rows
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary).font(.title3)
                TextField("Chercher dans AZA, ou aller à…", text: $query)
                    .textFieldStyle(.plain).azaFont(.title3)
                    .focused($focused)
                    .onSubmit(runSelected)
                Text("esc").foregroundStyle(.tertiary).azaFont(.caption2, mono: true)
            }
            .padding(14)
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        if query.trimmingCharacters(in: .whitespaces).isEmpty {
                            Text("RÉCENT ET ACTIONS").azaHeading(.caption2).padding(.horizontal, 12).padding(.top, 8)
                        } else if list.isEmpty {
                            Text("Rien trouvé pour « \(query) ».").foregroundStyle(.secondary).padding(16)
                        }
                        ForEach(Array(list.enumerated()), id: \.element.id) { i, r in
                            PaletteRowView(row: r, selected: i == index)
                                .id(i)
                                .contentShape(Rectangle())
                                .onTapGesture { index = i; runSelected() }
                        }
                    }
                    .padding(6)
                    .background(GeometryReader { g in
                        Color.clear.preference(key: PaletteHeight.self, value: g.size.height)
                    })
                }
                .onPreferenceChange(PaletteHeight.self) { contentHeight = $0 }
                .onChange(of: index) { i in withAnimation(.linear(duration: 0.08)) { proxy.scrollTo(i) } }
            }
            // Hauteur au plus juste (mesurée) : pas de grand vide quand il y a peu de résultats.
            .frame(height: min(420, max(48, contentHeight)))
            Divider()
            HStack(spacing: 14) {
                Text("↑↓ choisir · ↩ ouvrir · esc fermer").foregroundStyle(.tertiary)
                Spacer()
                if !query.isEmpty { Text("\(list.count) résultat(s)").foregroundStyle(.secondary) }
            }
            .azaFont(.caption2, mono: true)
            .padding(.horizontal, 14).padding(.vertical, 7)
        }
        .frame(width: 640)
        .background(RoundedRectangle(cornerRadius: 12).fill(prefs.palette?.surface ?? Color(nsColor: .windowBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.3)))
        .shadow(color: .black.opacity(0.35), radius: 24, y: 10)
        .onChange(of: query) { _ in index = 0 }
        .onExitCommand(perform: close)
        .onAppear {
            focused = true
            if SnapshotRunner.dir != nil { query = "quai" }   // capture de démonstration
            // ↑ / ↓ dans le champ de saisie : macOS 13 n'a pas onKeyPress, on écoute le clavier le temps de la palette.
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
                switch e.keyCode {
                case 125: index = min(index + 1, max(0, rows.count - 1)); return nil
                case 126: index = max(index - 1, 0); return nil
                case 53: close(); return nil
                default: return e
                }
            }
        }
        .onDisappear { if let m = monitor { NSEvent.removeMonitor(m); monitor = nil } }
    }
}

struct PaletteRowView: View {
    let row: PaletteRow
    let selected: Bool
    @Environment(\.azaStyle) private var style

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: row.icon).frame(width: 22).foregroundStyle(selected ? Color.white : style.accent)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(row.title).lineLimit(1).azaFont(.body)
                    if !row.subtitle.isEmpty {
                        Text(row.subtitle).lineLimit(1).foregroundStyle(selected ? Color.white.opacity(0.8) : .secondary).azaFont(.caption)
                    }
                }
                if !row.snippet.isEmpty {
                    Text(row.snippet).lineLimit(2).foregroundStyle(selected ? Color.white.opacity(0.85) : .secondary).azaFont(.caption)
                }
            }
            Spacer(minLength: 6)
            Text(row.badge.uppercased()).azaFont(.caption2, mono: true)
                .foregroundStyle(selected ? Color.white.opacity(0.85) : .secondary)
        }
        .foregroundStyle(selected ? Color.white : Color.primary)
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 7).fill(selected ? style.accent : Color.clear))
    }
}

private struct PaletteHeight: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
