import AppKit
import AZACore
import SwiftUI

/// Corpus chargé une fois (hors fil principal), rechargé quand le chemin change.
@MainActor
final class LoreCache: ObservableObject {
    @Published var path: String {
        didSet { UserDefaults.standard.set(path, forKey: "lorePath"); reload() }
    }
    @Published private(set) var available = false
    @Published private(set) var loading = false
    @Published private(set) var entries: [LoreEntry] = []
    @Published private(set) var timeline: [LoreEvent] = []
    @Published private(set) var quotes: [LoreQuote] = []
    @Published private(set) var loadedAt: Date?

    init() {
        path = UserDefaults.standard.string(forKey: "lorePath") ?? ""
        reload()
    }

    var reader: LoreReader { LoreReader(path: path) }

    func reload() {
        let r = reader
        loading = true
        Task.detached(priority: .utility) {
            let ok = r.available
            let e = ok ? r.all() : []
            let t = ok ? r.timeline() : []
            let q = ok ? r.quotes(in: e) : []
            await MainActor.run {
                self.available = ok; self.entries = e; self.timeline = t; self.quotes = q
                self.loading = false; self.loadedAt = Date()
            }
        }
    }

    func chooseFolder() {
        let p = NSOpenPanel()
        p.canChooseDirectories = true
        p.canChooseFiles = false
        p.message = "Choisis le dossier qui contient « Lore/ » (ex. PUBLICATIONS-QUARTZ)"
        if p.runModal() == .OK, let url = p.url {
            // Si on a pointé « Lore » lui-même, remonter d'un cran.
            path = url.lastPathComponent == "Lore" ? url.deletingLastPathComponent().path : url.path
        }
    }

    func count(_ section: String) -> Int { entries.filter { $0.section == section }.count }
}

struct LoreView: View {
    @EnvironmentObject var lore: LoreCache
    @EnvironmentObject var prefs: Prefs
    @Local private var tab = 0
    @Local private var section: String? = nil
    @Local private var query = ""
    @Local private var quote: LoreQuote? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("", selection: $tab) {
                    Text("Sections").tag(0)
                    Text("Chronologie").tag(1)
                    Text("Citations").tag(2)
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 330)
                if tab == 0 {
                    TextField("Chercher un lieu, une faction, un concept…", text: $query)
                        .textFieldStyle(.roundedBorder).frame(maxWidth: 360)
                }
                Spacer()
                if lore.loading { ProgressView().controlSize(.small) }
                Button { lore.reload() } label: { Image(systemName: "arrow.clockwise") }.help("Relire le vault")
            }
            .padding(10)
            Divider()
            if !lore.available && !lore.loading {
                unavailable
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        quoteCard
                        switch tab {
                        case 1: timelineView
                        case 2: quotesView
                        default: sectionsView
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: 900, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Lore")
        .navigationSubtitle(lore.available ? "Corpus Robōtariis — lu depuis le vault, jamais copié" : "Source non configurée")
        .onAppear { if quote == nil { quote = lore.quotes.randomElement() } }
        .onChange(of: lore.quotes) { q in if quote == nil || !q.contains(quote!) { quote = q.randomElement() } }
    }

    var surface: Color { prefs.palette?.surface ?? Color(nsColor: .controlBackgroundColor) }

    var unavailable: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CORPUS DE LORE INTROUVABLE").azaHeading()
            Text("Aucun dossier « Lore/ » sous \(lore.reader.root.path).")
                .azaFont(.body, mono: true).textSelection(.enabled)
            Text("Le lore n'est pas stocké dans AZA : il vit dans le vault Obsidian, qui en reste la seule référence. "
                 + "Le journal ne fait que le lire.")
                .foregroundStyle(.secondary)
            Button("Choisir le dossier du vault…") { lore.chooseFolder() }.buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: 640, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder var quoteCard: some View {
        if let q = quote {
            HStack(alignment: .top) {
                Rectangle().fill(prefs.palette?.accent2 ?? .blue).frame(width: 2)
                VStack(alignment: .leading, spacing: 6) {
                    Text(q.text).italic().azaFont(.body, mono: true).textSelection(.enabled)
                    Text("— \(q.source.uppercased())").foregroundStyle(.secondary).azaFont(.caption2, mono: true)
                }
                Spacer()
                Button { quote = lore.quotes.randomElement() } label: { Image(systemName: "shuffle") }
                    .buttonStyle(.borderless).help("Une autre citation")
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 4).fill(surface))
        }
    }

    // MARK: Sections

    @ViewBuilder var sectionsView: some View {
        let results = LoreReader.search(lore.entries, query)
        if !query.trimmingCharacters(in: .whitespaces).isEmpty {
            Text("\(results.count) RÉSULTAT(S) POUR « \(query.uppercased()) »").azaHeading()
            cards(results)
        } else if let s = section {
            HStack {
                Button { section = nil } label: { Label("Sections", systemImage: "chevron.left") }.buttonStyle(.link)
                Text((LoreReader.sections.first { $0.key == s }?.name ?? s).uppercased()).azaHeading()
            }
            cards(lore.entries.filter { $0.section == s })
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
                ForEach(LoreReader.sections.filter { lore.count($0.key) > 0 }, id: \.key) { s in
                    Button { section = s.key } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(lore.count(s.key))").azaFont(.title, mono: true).foregroundStyle(.tint)
                            Text(s.name.uppercased()).foregroundStyle(.secondary).azaFont(.caption2, mono: true)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 6).fill(surface))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("Les entités, lieux et factions sont validés dans le vault Obsidian. Les recopier dans le journal "
                 + "créerait deux vérités, qui divergeraient à la première correction faite d'un seul côté. "
                 + "AZA lit — et renvoie au texte complet.")
                .foregroundStyle(.secondary).azaFont(.caption).padding(.top, 8)
        }
    }

    func cards(_ entries: [LoreEntry]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], alignment: .leading, spacing: 12) {
            ForEach(entries) { e in LoreCard(entry: e, surface: surface) }
        }
    }

    // MARK: Chronologie

    @ViewBuilder var timelineView: some View {
        if lore.timeline.isEmpty {
            Text("Pas de « Lore/Temps/timeline.md » lisible dans le vault.").foregroundStyle(.secondary)
        }
        let eras = lore.timeline.reduce(into: [String]()) { if $0.last != $1.era { $0.append($1.era) } }
        ForEach(Array(eras.enumerated()), id: \.offset) { _, era in
            VStack(alignment: .leading, spacing: 6) {
                if !era.isEmpty { Text(era.uppercased()).azaHeading() }
                ForEach(Array(lore.timeline.filter { $0.era == era }.enumerated()), id: \.offset) { _, ev in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(ev.date).azaFont(.body, mono: true).foregroundStyle(.tint).frame(width: 110, alignment: .leading)
                        Text(ev.gregorian).foregroundStyle(.secondary).azaFont(.caption, mono: true).frame(width: 70, alignment: .leading)
                        Text(ev.event).textSelection(.enabled)
                    }
                }
            }
            .padding(.bottom, 8)
        }
    }

    // MARK: Citations

    @ViewBuilder var quotesView: some View {
        Text("\(lore.quotes.count) CITATIONS DU CORPUS").azaHeading()
        ForEach(lore.quotes, id: \.self) { q in
            VStack(alignment: .leading, spacing: 4) {
                Text(q.text).italic().textSelection(.enabled)
                Text("— \(q.source)").foregroundStyle(.secondary).azaFont(.caption)
            }
            .padding(.vertical, 4)
        }
    }
}

struct LoreCard: View {
    let entry: LoreEntry
    let surface: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.title).azaFont(.headline, mono: true)
            Text([entry.sectionName, entry.subsection].filter { !$0.isEmpty }.joined(separator: " / ").uppercased())
                .foregroundStyle(.secondary).azaFont(.caption2, mono: true)
            if !entry.description.isEmpty {
                Text(entry.description).azaFont(.callout).lineLimit(5)
            }
            if !entry.tags.isEmpty {
                Text(entry.tags.map { "#" + $0 }.joined(separator: " ")).foregroundStyle(.tint).azaFont(.caption)
            }
            Spacer(minLength: 0)
            HStack(spacing: 12) {
                Button("Obsidian") { LoreCard.openInObsidian(entry.path) }
                    .help("Ouvrir la note dans Obsidian")
                Button("Fichier") { NSWorkspace.shared.open(entry.path) }
                    .help("Ouvrir avec l'éditeur Markdown par défaut")
                Button("Copier le titre") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(entry.title, forType: .string)
                }
            }
            .buttonStyle(.link).azaFont(.caption)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 6).fill(surface))
    }

    static func openInObsidian(_ path: URL) {
        var c = URLComponents()
        c.scheme = "obsidian"; c.host = "open"
        c.queryItems = [URLQueryItem(name: "path", value: path.path)]
        if let url = c.url, NSWorkspace.shared.urlForApplication(toOpen: url) != nil {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.open(path)
        }
    }
}

/// Choix d'une entrée du corpus pour le champ « Lien lore » d'une séance.
struct LoreLinkPicker: View {
    @EnvironmentObject var lore: LoreCache
    @Binding var value: String

    var body: some View {
        Menu {
            if !lore.available { Text("Corpus de lore non configuré (Réglages › Données)") }
            ForEach(LoreReader.sections.filter { lore.count($0.key) > 0 }, id: \.key) { s in
                Menu(s.name) {
                    ForEach(lore.entries.filter { $0.section == s.key }) { e in Button(e.title) { value = e.title } }
                }
            }
        } label: { Image(systemName: "book.closed") }
            .menuStyle(.borderlessButton).frame(width: 36)
            .help("Choisir une entrée du lore")
    }
}
