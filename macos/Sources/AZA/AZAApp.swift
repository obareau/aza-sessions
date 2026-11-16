import AppKit
import AZACore
import SwiftUI

let azaOrange = Color(red: 0xF9 / 255, green: 0x73 / 255, blue: 0x16 / 255)

/// Navigation partagée : n'importe quel écran peut ouvrir une séance ou une fiche.
@MainActor
final class Nav: ObservableObject {
    @Published var pane: Pane = .sessions
    @Published var session: Int?
    @Published var gear: Int?
    @Published var printJob: PrintJob?
    @Published var patch: Int?
    @Published var diary: Int?
    @Published var quick: QuickRequest?
    @Published var shortcuts = false

    func open(patch id: Int) { pane = .patcher; patch = id }

    func open(session id: Int) { pane = .sessions; session = id }
    func open(gear id: Int) { pane = .catalogue; gear = id }
}

@main
struct AZAApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var store = Store()
    @StateObject private var prefs = Prefs()
    @StateObject private var nav = Nav()
    @StateObject private var midi = MIDIManager()
    @StateObject private var lore = LoreCache()
    @StateObject private var pomo = Pomodoro()

    var body: some Scene {
        WindowGroup("AZA — Journal de Sessions") {
            ContentView()
                .azaRoot()
                .frame(minWidth: 1000, minHeight: 640)
                .environmentObject(store)
                .environmentObject(prefs)
                .environmentObject(nav)
                .environmentObject(midi)
                .environmentObject(lore)
                .environmentObject(pomo)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Nouvelle séance") { nav.open(session: store.newSession()) }.keyboardShortcut("n")
                Button("Séance rapide…") { nav.quick = QuickRequest(gear: []) }.keyboardShortcut("n", modifiers: [.command, .shift])
                Button("Nouvelle entrée de journal") { nav.pane = .diary; nav.diary = store.newDiaryEntry() }
                    .keyboardShortcut("j", modifiers: [.command, .shift])
                Button("Copier le setup de la séance") {
                    let t = store.data.sessions.first { $0.id == nav.session }
                    nav.open(session: store.newSession(from: t))
                }
                .keyboardShortcut("d")
                .disabled(nav.session == nil)
                Divider()
                Button("Séance en cours") { nav.pane = .live }.keyboardShortcut("l", modifiers: [.command, .shift])
                Button("Ce soir — tirer une séance") { nav.pane = .tonight }.keyboardShortcut("t", modifiers: [.command, .shift])
                Button("Patcher") { nav.pane = .patcher }.keyboardShortcut("p", modifiers: [.command, .shift])
            }
            CommandGroup(after: .importExport) {
                Button("Importer une base sessions.db…") {
                    guard let url = Panels.open(types: ["db", "sqlite", "sqlite3"]) else { return }
                    guard Panels.confirm("Remplacer les données ?",
                                         "Le contenu actuel sera remplacé par celui de la base. " +
                                         "Une sauvegarde du JSON actuel est faite avant.",
                                         ok: "Importer") else { return }
                    nav.session = nil; nav.gear = nil
                    store.importSQLite(url: url)
                }
                Button("Importer un fichier JSON…") {
                    guard let url = Panels.open(types: ["json"]) else { return }
                    guard Panels.confirm("Remplacer les données ?",
                                         "Une sauvegarde du JSON actuel est faite avant.",
                                         ok: "Importer") else { return }
                    nav.session = nil; nav.gear = nil
                    store.importJSON(url: url)
                }
                Divider()
                Button("Exporter en JSON…") {
                    if let url = Panels.save(name: "aza-sessions-\(Clock.today()).json", ext: "json") {
                        store.exportJSON(to: url)
                    }
                }.keyboardShortcut("e", modifiers: [.command, .shift])
                Divider()
                Button("Imprimer un formulaire vierge…") {
                    nav.print(PrintJob(title: "Formulaire terrain", html: Sheets.blankForm(data: store.data, version: Store.version),
                                       fileName: "formulaire_aza"))
                }
                Button("Imprimer les fiches matériel…") {
                    nav.print(PrintJob(title: "Fiches matériel",
                                       html: Sheets.catalogue(store.data.catalogue, filter: "", version: Store.version),
                                       landscape: true, fileName: "fiches_materiel_\(Clock.today())"))
                }
                Button("Exporter les séances en CSV…") {
                    if let url = Panels.save(name: "aza_\(Clock.today().replacingOccurrences(of: "-", with: "")).csv", ext: "csv") {
                        store.exportCSV(to: url)
                    }
                }
                Button("Écrire toutes les séances dans le vault Obsidian") {
                    guard Panels.confirm("Écrire \(store.data.sessions.count) séance(s) dans le vault ?",
                                         "Dossier : \(prefs.obsidianVault)\nLes fichiers du même nom sont remplacés.",
                                         ok: "Écrire") else { return }
                    let msg = store.exportToVault(store.data.sessions.map(\.id), folder: prefs.obsidianVault)
                    if !msg.isEmpty { store.lastError = "✓ " + msg }
                }
                .disabled(prefs.obsidianVault.isEmpty)
                Button("Exporter toutes les séances en Markdown…") {
                    if let url = Panels.save(name: "aza_\(Clock.today()).md", ext: "md") {
                        store.exportMarkdown(store.data.sessions.sorted { $0.date > $1.date }, to: url)
                    }
                }
                Divider()
                Button("Afficher le fichier JSON dans le Finder") { store.revealFile() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .saveItem) {
                Button("Enregistrer maintenant") { store.flush() }.keyboardShortcut("s")
            }
            CommandGroup(after: .toolbar) {
                Button("Agrandir le texte") { prefs.scale = min(1.8, prefs.scale + 0.1) }.keyboardShortcut("+")
                Button("Réduire le texte") { prefs.scale = max(0.8, prefs.scale - 0.1) }.keyboardShortcut("-")
                Button("Taille réelle") { prefs.scale = 1.0 }.keyboardShortcut("0")
                Divider()
            }
        }

        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("À propos d'AZA") { AboutPanel.show() }
            }
            CommandGroup(replacing: .help) {
                Button("Raccourcis clavier") { nav.shortcuts = true }.keyboardShortcut("/", modifiers: .command)
                Button("Code source et releases") {
                    NSWorkspace.shared.open(URL(string: "https://github.com/obareau/aza-sessions/releases")!)
                }
            }
        }

        Settings {
            SettingsView()
                .environmentObject(store)
                .environmentObject(prefs)
                .environmentObject(lore)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Lancé hors bundle (swift run) : passer en app au premier plan quand même.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

enum Pane: String, CaseIterable, Identifiable {
    case diary
    case tonight, live, spark
    case sessions, projects, takes, stats
    case catalogue, facades, presets, patcher, sysex
    case lore, influences, obliques, tracks, inspirations, samples, mirack, wishlist
    var id: String { rawValue }

    static let groups: [(String, [Pane])] = [
        ("Écrire", [.diary]),
        ("Jouer", [.tonight, .live, .spark]),
        ("Séances", [.sessions, .projects, .takes, .stats]),
        ("Matériel", [.catalogue, .patcher, .facades, .presets, .sysex, .wishlist]),
        ("Références", [.lore, .influences, .obliques, .tracks, .inspirations, .samples, .mirack]),
    ]

    var label: String {
        switch self {
        case .diary: "Journal"
        case .tonight: "Ce soir"
        case .live: "En cours"
        case .spark: "Spark"
        case .sessions: "Séances"
        case .projects: "Projets"
        case .takes: "Prises"
        case .stats: "Statistiques"
        case .catalogue: "Catalogue"
        case .facades: "Façades"
        case .presets: "Presets"
        case .patcher: "Patcher"
        case .sysex: "SysEx"
        case .lore: "Lore"
        case .influences: "Influences"
        case .obliques: "Stratégies obliques"
        case .tracks: "Morceaux"
        case .inspirations: "Inspirations"
        case .samples: "Samples"
        case .mirack: "MiRack"
        case .wishlist: "Wishlist"
        }
    }
    var icon: String {
        switch self {
        case .diary: "book.pages"
        case .tonight: "moon.stars"
        case .live: "record.circle"
        case .spark: "sparkles"
        case .sessions: "waveform"
        case .projects: "folder"
        case .takes: "recordingtape"
        case .stats: "chart.bar"
        case .catalogue: "pianokeys"
        case .facades: "dial.medium"
        case .presets: "slider.horizontal.3"
        case .patcher: "point.3.connected.trianglepath.dotted"
        case .sysex: "cable.connector.horizontal"
        case .lore: "book.closed"
        case .influences: "person.2"
        case .obliques: "suit.diamond"
        case .tracks: "music.note.list"
        case .inspirations: "lightbulb"
        case .samples: "square.stack.3d.up"
        case .mirack: "hexagon"
        case .wishlist: "cart"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var prefs: Prefs
    @EnvironmentObject var nav: Nav

    var body: some View {
        NavigationSplitView {
            List(selection: Binding(get: { nav.pane }, set: { if let p = $0 { nav.pane = p } })) {
                ForEach(Pane.groups, id: \.0) { group in
                    SwiftUI.Section {
                        ForEach(group.1) { p in
                            Label {
                                Text(p.label).font(prefs.sidebarFont(.body))
                            } icon: {
                                Image(systemName: p.icon)
                                    .font(prefs.sidebarFont(.body))
                                    .foregroundStyle(p == .live && store.data.live != nil ? Color.red : prefs.accent)
                            }
                            .badge(count(p))
                            .tag(p)
                        }
                    } header: {
                        Text(group.0.uppercased())
                            .font(prefs.sidebarFont(.caption2, mono: prefs.monoTitles))
                            .foregroundStyle(prefs.accent)
                    }
                }
            }
            .azaSurface(alt: true)
            .navigationSplitViewColumnWidth(min: 190, ideal: 215 * max(1, prefs.sidebarScale))
            .environment(\.defaultMinListRowHeight, (prefs.compact ? 18 : 24) * prefs.sidebarScale)
            .safeAreaInset(edge: .bottom) { footer }
        } detail: {
            VStack(spacing: 0) {
                if prefs.obliqueBanner { ObliqueBanner(); Divider() }
                detail.azaSurface()
            }
        }
        .task { if SnapshotRunner.dir != nil { await SnapshotRunner.run(nav: nav, store: store) } }
        .sheet(item: $nav.quick) { q in
            QuickSessionSheet(preselection: q.gear) { nav.quick = nil }
                .environmentObject(store).environmentObject(nav).environmentObject(prefs)
                .azaRoot()
        }
        .sheet(isPresented: $nav.shortcuts) {
            ShortcutsHelp { nav.shortcuts = false }.environmentObject(prefs).azaRoot()
        }
        .sheet(item: $nav.printJob) { job in
            PrintPreview(job: job) { nav.printJob = nil }
                .environmentObject(prefs)
                .azaRoot()
        }
        .alert("AZA", isPresented: Binding(get: { store.lastError != nil },
                                           set: { if !$0 { store.lastError = nil } })) {
            Button("OK") { store.lastError = nil }
        } message: { Text(store.lastError ?? "") }
    }

    @ViewBuilder var detail: some View {
        switch nav.pane {
        case .diary: DiaryView()
        case .tonight: TonightView()
        case .live: LiveView()
        case .spark: SparkView()
        case .sessions: SessionsView(selection: $nav.session)
        case .projects: ProjectsView(openSession: { nav.open(session: $0) })
        case .takes: TakesView()
        case .stats: StatsView()
        case .catalogue: CatalogueView()
        case .facades: FacadesView()
        case .presets: PresetsView()
        case .patcher: PatcherView()
        case .sysex: SysexView()
        case .lore: LoreView()
        case .influences: InfluencesView()
        case .obliques: ObliquesView()
        case .tracks: TracksView()
        case .inspirations: InspirationsView()
        case .samples: SamplesView()
        case .mirack: MiRackView()
        case .wishlist: WishlistView()
        }
    }

    func count(_ p: Pane) -> Int {
        let d = store.data
        switch p {
        case .diary: return d.diary.count
        case .sessions: return d.sessions.count
        case .projects: return d.projects.count
        case .catalogue: return d.catalogue.count
        case .influences: return d.influences.count
        case .obliques: return d.obliques.count
        case .presets: return d.presets.count
        case .patcher: return d.patches.count
        case .sysex: return d.sysexBanks.count
        case .facades: return d.knobSheets.count
        case .tracks: return d.tracks.count
        case .inspirations: return d.inspirations.count
        case .samples: return d.samples.count
        case .mirack: return d.mirack.count
        case .wishlist: return d.wishlist.filter { !$0.acquired }.count
        case .takes: return d.takeRegistry().count
        default: return 0
        }
    }

    var footer: some View {
        VStack(alignment: .leading, spacing: 2) {
            PomodoroWidget().padding(.bottom, 6)
            Text("AZA").azaHeading(.headline)
            Text(store.storage.url.lastPathComponent).foregroundStyle(.secondary).azaFont(.caption2, mono: true)
            if let t = store.lastSaved {
                Text("enregistré \(t.formatted(date: .omitted, time: .standard))")
                    .foregroundStyle(.secondary).azaFont(.caption2, mono: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .onTapGesture(count: 2) { store.revealFile() }
        .help("Double-clic : afficher le fichier JSON dans le Finder")
    }
}

struct QuickRequest: Identifiable {
    let id = UUID()
    let gear: [String]
}
