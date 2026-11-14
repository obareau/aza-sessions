import AppKit
import AZACore
import SwiftUI

let azaOrange = Color(red: 0xF9 / 255, green: 0x73 / 255, blue: 0x16 / 255)

@main
struct AZAApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var store = Store()
    @Local private var section: Pane = .sessions
    @Local private var selectedSession: Int?

    var body: some Scene {
        WindowGroup("AZA — Journal de Sessions") {
            ContentView(section: $section, selectedSession: $selectedSession)
                .environmentObject(store)
                .tint(azaOrange)
                .frame(minWidth: 980, minHeight: 620)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Nouvelle séance") {
                    section = .sessions
                    selectedSession = store.newSession()
                }.keyboardShortcut("n")
                Button("Copier le setup de la séance") {
                    let t = store.data.sessions.first { $0.id == selectedSession }
                    section = .sessions
                    selectedSession = store.newSession(from: t)
                }
                .keyboardShortcut("d")
                .disabled(selectedSession == nil)
            }
            CommandGroup(after: .importExport) {
                Button("Importer une base sessions.db…") {
                    guard let url = Panels.open(types: ["db", "sqlite", "sqlite3"]) else { return }
                    guard Panels.confirm("Remplacer les données ?",
                                         "Le contenu actuel sera remplacé par celui de la base. " +
                                         "Une sauvegarde du JSON actuel est faite avant.",
                                         ok: "Importer") else { return }
                    selectedSession = nil
                    store.importSQLite(url: url)
                }
                Button("Importer un fichier JSON…") {
                    guard let url = Panels.open(types: ["json"]) else { return }
                    guard Panels.confirm("Remplacer les données ?",
                                         "Une sauvegarde du JSON actuel est faite avant.",
                                         ok: "Importer") else { return }
                    selectedSession = nil
                    store.importJSON(url: url)
                }
                Divider()
                Button("Exporter en JSON…") {
                    if let url = Panels.save(name: "aza-sessions-\(Clock.today()).json", ext: "json") {
                        store.exportJSON(to: url)
                    }
                }.keyboardShortcut("e", modifiers: [.command, .shift])
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
    case sessions, projects, catalogue, influences, obliques
    var id: String { rawValue }
    var label: String {
        switch self {
        case .sessions: "Séances"
        case .projects: "Projets"
        case .catalogue: "Catalogue"
        case .influences: "Influences"
        case .obliques: "Stratégies obliques"
        }
    }
    var icon: String {
        switch self {
        case .sessions: "waveform"
        case .projects: "folder"
        case .catalogue: "pianokeys"
        case .influences: "person.2"
        case .obliques: "suit.diamond"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var store: Store
    @Binding var section: Pane
    @Binding var selectedSession: Int?

    var body: some View {
        NavigationSplitView {
            List(Pane.allCases, selection: Binding(get: { section }, set: { if let s = $0 { section = s } })) { s in
                Label(s.label, systemImage: s.icon)
                    .badge(count(s))
                    .tag(s)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .safeAreaInset(edge: .bottom) { footer }
        } detail: {
            Group {
                switch section {
                case .sessions: SessionsView(selection: $selectedSession)
                case .projects: ProjectsView(openSession: { section = .sessions; selectedSession = $0 })
                case .catalogue: CatalogueView()
                case .influences: InfluencesView()
                case .obliques: ObliquesView()
                }
            }
        }
        .alert("AZA", isPresented: Binding(get: { store.lastError != nil },
                                           set: { if !$0 { store.lastError = nil } })) {
            Button("OK") { store.lastError = nil }
        } message: { Text(store.lastError ?? "") }
    }

    func count(_ s: Pane) -> Int {
        switch s {
        case .sessions: store.data.sessions.count
        case .projects: store.data.projects.count
        case .catalogue: store.data.catalogue.count
        case .influences: store.data.influences.count
        case .obliques: store.data.obliques.count
        }
    }

    var footer: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("AZA").font(.system(.headline, design: .monospaced)).foregroundStyle(azaOrange)
            Text(store.storage.url.lastPathComponent)
                .font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary)
            if let t = store.lastSaved {
                Text("enregistré \(t.formatted(date: .omitted, time: .standard))")
                    .font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .onTapGesture(count: 2) { store.revealFile() }
        .help("Double-clic : afficher le fichier JSON dans le Finder")
    }
}
