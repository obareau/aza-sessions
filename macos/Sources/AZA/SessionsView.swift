import AZACore
import SwiftUI

struct SessionsView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var prefs: Prefs
    @Local private var exportNote = ""
    @Binding var selection: Int?
    @Local private var query = ""
    @Local private var projectFilter: Int? = nil
    @Local private var modeFilter = ""
    @Local private var onlyRework = false
    @Local private var typeFilter = ""
    @Local private var intentionFilter = ""
    @Local private var minRating = 0
    @Local private var monthFilter = ""
    @Local private var showHeatmap = false

    var activeFilters: Int {
        [typeFilter.isEmpty, intentionFilter.isEmpty, minRating == 0, monthFilter.isEmpty].filter { !$0 }.count
    }

    func matches(_ s: Session) -> Bool {
        if let p = projectFilter, s.projectId != p { return false }
        if !modeFilter.isEmpty && s.mode != modeFilter { return false }
        if onlyRework && !s.toRework { return false }
        if !typeFilter.isEmpty && s.sessionType != typeFilter { return false }
        if !intentionFilter.isEmpty && s.intention != intentionFilter { return false }
        if minRating > 0 && (s.rating ?? 0) < minRating { return false }
        if !monthFilter.isEmpty && !s.date.hasPrefix(monthFilter) { return false }
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return true }
        var parts: [String] = [s.title, s.date, s.mode, s.intention, s.comments, s.patches, s.audioFile,
                               s.signalRouting, s.loreLink, s.oblique, s.tempo, s.tonality, s.recapClaude]
        parts += s.tags
        parts += s.allGear
        parts += s.influences
        parts += s.character
        return parts.joined(separator: " ").lowercased().contains(q)
    }

    var filtered: [Session] {
        store.data.sessions.filter(matches).sorted { ($0.date, $0.id) > ($1.date, $1.id) }
    }

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                filters
                List(filtered, selection: $selection) { s in
                    SessionRow(session: s).tag(s.id)
                        .contextMenu {
                            Button("Copier le setup") { selection = store.newSession(from: s) }
                            Button("Supprimer…", role: .destructive) { delete(s) }
                        }
                }
                .listStyle(.inset)
            }
            .frame(minWidth: 280, idealWidth: 330, maxWidth: 460)

            Group {
                if let id = selection, let b = store.binding(session: id) {
                    SessionEditor(session: b, onOpen: { selection = $0 }).id(id)
                } else {
                    VStack(spacing: 12) {
                        Text("Aucune séance sélectionnée").azaFont(.title3, mono: true)
                        Button("Nouvelle séance  ⌘N") { selection = store.newSession() }
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 520, maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Séances")
        .navigationSubtitle(exportNote.isEmpty ? "\(filtered.count) / \(store.data.sessions.count)" : exportNote)
        .onChange(of: selection) { _ in exportNote = "" }
        .toolbar {
            ToolbarItemGroup {
                Button { selection = store.newSession() } label: { Label("Nouvelle", systemImage: "plus") }
                    .help("Nouvelle séance (⌘N)")
                if let s = current { SessionPrintMenu(session: s) }
                Menu {
                    Button("Markdown…") {
                        if let s = current, let url = Panels.save(name: "session_\(s.date)_\(s.id).md", ext: "md") {
                            store.exportMarkdown([s], to: url)
                        }
                    }
                    Button("→ Vault Obsidian") {
                        if let s = current { exportNote = store.exportToVault([s.id], folder: prefs.obsidianVault) }
                    }
                    .disabled(prefs.obsidianVault.isEmpty)
                } label: { Label("Exporter", systemImage: "square.and.arrow.up") }
                    .help(prefs.obsidianVault.isEmpty ? "Exporter la séance (vault Obsidian : à régler dans les Réglages)"
                                                      : "Exporter la séance").disabled(current == nil)
                Button { if let s = current { delete(s) } } label: { Label("Supprimer", systemImage: "trash") }
                    .help("Supprimer la séance").disabled(current == nil)
            }
        }
    }

    var current: Session? { store.data.sessions.first { $0.id == selection } }

    var filters: some View {
        VStack(spacing: 6) {
            TextField("Rechercher…", text: $query).textFieldStyle(.roundedBorder)
            HStack {
                Picker("", selection: $projectFilter) {
                    Text("Tous projets").tag(Int?.none)
                    ForEach(store.data.projects) { p in Text(p.title).tag(Int?.some(p.id)) }
                }.labelsHidden()
                Picker("", selection: $modeFilter) {
                    Text("Tous modes").tag("")
                    ForEach(Vocab.modes, id: \.self) { Text($0).tag($0) }
                }.labelsHidden()
                Toggle("↻", isOn: $onlyRework).toggleStyle(.button).help("À retravailler seulement")
                Menu {
                    Picker("Type", selection: $typeFilter) {
                        Text("Tous types").tag("")
                        ForEach(Vocab.sessionTypes, id: \.key) { Text($0.label).tag($0.key) }
                    }
                    Picker("Intention", selection: $intentionFilter) {
                        Text("Toutes intentions").tag("")
                        ForEach(Vocab.intentions, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Note", selection: $minRating) {
                        Text("Toutes notes").tag(0)
                        ForEach(1...5, id: \.self) { Text(String(repeating: "★", count: $0) + " et plus").tag($0) }
                    }
                    Picker("Mois", selection: $monthFilter) {
                        Text("Tous les mois").tag("")
                        ForEach(Array(Set(store.data.sessions.map { String($0.date.prefix(7)) })).sorted(by: >), id: \.self) {
                            Text($0).tag($0)
                        }
                    }
                    Divider()
                    Button("Effacer les filtres") { typeFilter = ""; intentionFilter = ""; minRating = 0; monthFilter = "" }
                } label: {
                    Image(systemName: activeFilters > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
                .menuStyle(.borderlessButton).frame(width: 34)
                .help(activeFilters > 0 ? "\(activeFilters) filtre(s) actif(s)" : "Plus de filtres")
                Toggle(isOn: $showHeatmap) { Image(systemName: "square.grid.3x3.fill") }
                    .toggleStyle(.button).help("Activité de l'année")
            }
            if showHeatmap {
                Heatmap(counts: Dictionary(store.data.sessions.map { (String($0.date.prefix(10)), 1) }, uniquingKeysWith: +))
                    .frame(height: 60)
            }
        }
        .padding(8)
    }

    func delete(_ s: Session) {
        guard Panels.confirm("Supprimer « \(s.displayTitle) » ?",
                             "La séance est retirée du fichier JSON (les sauvegardes la conservent).",
                             ok: "Supprimer") else { return }
        if selection == s.id { selection = nil }
        store.deleteSession(s.id)
    }
}

struct SessionRow: View {
    @EnvironmentObject var store: Store
    let session: Session

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(store.data.project(session.projectId).map { Color(hex: $0.color) } ?? .clear)
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.displayTitle).azaFont(.body, mono: true).lineLimit(1)
                HStack(spacing: 6) {
                    Text(session.date)
                    if !session.mode.isEmpty { Text(session.mode) }
                    if let r = session.rating, r > 0 { Text(String(repeating: "★", count: r)).foregroundStyle(.tint) }
                    if session.toRework { Text("↻") }
                    if session.releasePotential { Text("◆").foregroundStyle(.tint) }
                }
                .azaFont(.caption, mono: true).foregroundStyle(.secondary)
                let gear = session.allGear
                if !gear.isEmpty {
                    Text(gear.joined(separator: " · ")).azaFont(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct SessionEditor: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var prefs: Prefs
    @Binding var session: Session
    var onOpen: (Int) -> Void
    @Local private var titles: [String] = Titles.propose(6)

    var body: some View {
        Form {
            Section {
                HStack {
                    TextField("Titre", text: $session.title, prompt: Text(session.displayTitle))
                    Menu {
                        ForEach(titles, id: \.self) { t in Button(t) { session.title = t } }
                        Divider()
                        Button("Autres propositions") { titles = Titles.propose(6) }
                    } label: { Image(systemName: "wand.and.stars") }
                        .menuStyle(.borderlessButton).frame(width: 36)
                        .help("Proposer un titre dans l'esthétique d'AZA")
                }
                HStack {
                    DatePicker("Date", selection: Binding(
                        get: { Clock.day(session.date) ?? Date() },
                        set: { session.date = Clock.day($0) }), displayedComponents: .date)
                    Picker("Type", selection: $session.sessionType) {
                        ForEach(Vocab.sessionTypes, id: \.key) { Text($0.label).tag($0.key) }
                    }
                }
                HStack {
                    Picker("Mode", selection: $session.mode) {
                        Text("—").tag("")
                        ForEach(Vocab.modes, id: \.self) { Text($0).tag($0) }
                        if !session.mode.isEmpty && !Vocab.modes.contains(session.mode) { Text(session.mode).tag(session.mode) }
                    }
                    Picker("Intention", selection: $session.intention) {
                        Text("—").tag("")
                        ForEach(Vocab.intentions, id: \.self) { Text($0).tag($0) }
                        if !session.intention.isEmpty && !Vocab.intentions.contains(session.intention) {
                            Text(session.intention).tag(session.intention)
                        }
                    }
                }
                HStack {
                    TextField("Durée (min)", value: $session.durationMin, format: .number)
                    Picker("Projet", selection: $session.projectId) {
                        Text("Aucun").tag(Int?.none)
                        ForEach(store.data.projects) { p in Text(p.title).tag(Int?.some(p.id)) }
                    }
                }
                HStack(spacing: 24) {
                    LabeledContent("Note") { Dots(value: $session.rating, symbol: "★") }
                    LabeledContent("Énergie") { Dots(value: $session.energyLevel, symbol: "⚡", max: 3) }
                }
                HStack {
                    Toggle("À retravailler", isOn: $session.toRework)
                    Toggle("Potentiel release", isOn: $session.releasePotential)
                }
            } header: { header("Séance #\(session.id)") }

            Section {
                ForEach(GearField.allCases, id: \.self) { f in
                    GearPicker(field: f, values: $session[dynamicMember: f.keyPath])
                }
            } header: { header("Matériel") }

            Section {
                HStack {
                    TextField("Tempo", text: $session.tempo)
                    TextField("Tonalité", text: $session.tonality)
                    TextField("Algo MicroFreak", text: $session.microfreakAlgo)
                }
                LabeledContent("Caractère") {
                    FlowToggles(options: Vocab.characters, values: $session.character)
                }
                MultiLine("Patches / presets", text: $session.patches)
                MultiLine("Signal routing", text: $session.signalRouting)
            } header: { header("Son") }

            Section {
                HStack {
                    TextField("Fichier audio / nom de prise", text: $session.audioFile)
                    let take = store.data.takeName(for: session)
                    Button("Prise : \(take.isEmpty ? "—" : take)") { session.audioFile = take }
                        .disabled(take.isEmpty)
                        .help(take.isEmpty ? "Aucune fiche du setup n'a de code catalogue"
                                           : "Nom de projet Zoom R8 (8 car. max)")
                }
                let path = (session.audioFile as NSString).expandingTildeInPath
                if session.audioFile.contains("/"), FileManager.default.fileExists(atPath: path) {
                    Button("Révéler le fichier dans le Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                    }.buttonStyle(.link)
                }
                MultiLine("Timestamps intéressants", text: $session.timestamps)
            } header: { header("Enregistrement") }

            Section {
                ListField("Tags", values: $session.tags)
                LabeledContent("Influences") {
                    NamePicker(options: store.data.influences.filter(\.active).map(\.name),
                               values: $session.influences, title: "Influences")
                }
                HStack {
                    TextField("Lien lore AZA", text: $session.loreLink)
                    LoreLinkPicker(value: $session.loreLink)
                }
                HStack(alignment: .top) {
                    TextField("Stratégie oblique", text: $session.oblique, axis: .vertical)
                    Button { session.oblique = store.data.randomOblique() ?? session.oblique } label: {
                        Image(systemName: "dice")
                    }.help("Tirer une autre stratégie")
                }
                Picker("Séance liée", selection: $session.linkedSession) {
                    Text("Aucune").tag(Int?.none)
                    ForEach(store.data.sessions.filter { $0.id != session.id }.sorted { $0.date > $1.date }) { s in
                        Text("\(s.date) — \(s.displayTitle)").tag(Int?.some(s.id))
                    }
                }
                if let l = session.linkedSession {
                    Button("Ouvrir la séance liée →") { onOpen(l) }.buttonStyle(.link)
                }
            } header: { header("Contexte") }

            Section {
                MultiLine("Notes libres", text: $session.comments, minHeight: 120)
                MultiLine("Récap", text: $session.recapClaude)
                HStack {
                    let running = store.recapRunning.contains(session.id)
                    Button {
                        store.generateRecap(session.id, baseURL: prefs.ollamaURL, model: prefs.ollamaModel)
                    } label: {
                        Label(session.recapClaude.isEmpty ? "Générer le récap" : "Régénérer le récap", systemImage: "sparkles")
                    }
                    .disabled(running)
                    if running { ProgressView().controlSize(.small); Text("Ollama rédige…").foregroundStyle(.secondary) }
                    Spacer()
                    Text(prefs.ollamaModel).foregroundStyle(.tertiary).azaFont(.caption2, mono: true)
                }
                if let err = store.recapErrors[session.id] {
                    Label(err, systemImage: "exclamationmark.triangle").foregroundStyle(.orange).azaFont(.caption)
                        .textSelection(.enabled)
                }
            } header: { header("Notes") }
        }
        .formStyle(.grouped)
    }

    func header(_ s: String) -> some View {
        Text(s.uppercased()).azaHeading()
    }
}

// MARK: - Champs réutilisables

struct Dots: View {
    @Binding var value: Int?
    let symbol: String
    var max = 5
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...max, id: \.self) { i in
                Text(symbol)
                    .opacity((value ?? 0) >= i ? 1 : 0.2)
                    .onTapGesture { value = value == i ? nil : i }
            }
        }
        .foregroundStyle(.tint)
        .help("Clic pour noter, re-clic pour effacer")
    }
}

struct MultiLine: View {
    let title: String
    @Binding var text: String
    var minHeight: CGFloat = 54
    init(_ title: String, text: Binding<String>, minHeight: CGFloat = 54) {
        self.title = title; _text = text; self.minHeight = minHeight
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).azaFont(.caption).foregroundStyle(.secondary)
            TextEditor(text: $text)
                .azaFont(.body, mono: true)
                .frame(minHeight: minHeight)
                .scrollContentBackground(.hidden)
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color(nsColor: .textBackgroundColor)))
        }
    }
}

/// Liste saisie en texte « a, b, c ».
struct ListField: View {
    let title: String
    @Binding var values: [String]
    @Local private var text = ""
    init(_ title: String, values: Binding<[String]>) { self.title = title; _values = values }
    var body: some View {
        TextField(title, text: $text, prompt: Text("séparés par des virgules"))
            .onAppear { text = values.joined(separator: ", ") }
            .onChange(of: text) { values = splitList($0) }
    }
}

struct FlowToggles: View {
    let options: [String]
    @Binding var values: [String]
    var body: some View {
        let all = options + values.filter { !options.contains($0) }
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 4)], alignment: .leading, spacing: 4) {
            ForEach(all, id: \.self) { o in
                Toggle(o, isOn: Binding(
                    get: { values.contains(o) },
                    set: { on in if on { values.append(o) } else { values.removeAll { $0 == o } } }))
                .toggleStyle(.button).controlSize(.small)
            }
        }
    }
}

/// Sélection multiple dans une liste de noms, via un menu à cases.
struct NamePicker: View {
    let options: [String]
    @Binding var values: [String]
    let title: String
    @Local private var open = false
    @Local private var filter = ""

    var body: some View {
        HStack {
            Text(values.isEmpty ? "—" : values.joined(separator: ", "))
                .foregroundStyle(values.isEmpty ? .secondary : .primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Choisir…") { open = true }
                .popover(isPresented: $open, arrowEdge: .trailing) { popover }
        }
    }

    var popover: some View {
        let extra = values.filter { !options.contains($0) }
        let shown = (options + extra).filter { filter.isEmpty || $0.localizedCaseInsensitiveContains(filter) }
        return VStack(alignment: .leading, spacing: 6) {
            Text(title).azaFont(.headline, mono: true)
            TextField("Filtrer ou ajouter…", text: $filter)
                .onSubmit {
                    let n = filter.trimmingCharacters(in: .whitespaces)
                    if !n.isEmpty && !values.contains(n) { values.append(n) }
                    filter = ""
                }
            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(shown, id: \.self) { o in
                        Toggle(o, isOn: Binding(
                            get: { values.contains(o) },
                            set: { on in if on { values.append(o) } else { values.removeAll { $0 == o } } }))
                    }
                }
            }.frame(height: min(320, CGFloat(shown.count) * 22 + 8))
            Text("Entrée : ajouter un nom libre").azaFont(.caption2).foregroundStyle(.secondary)
        }
        .padding(12).frame(width: 280)
    }
}

struct GearPicker: View {
    @EnvironmentObject var store: Store
    let field: GearField
    @Binding var values: [String]

    var body: some View {
        let items = store.data.catalogue
            .filter { $0.type == field.catalogueType && $0.active }
            .sorted { ($0.favorite ? 0 : 1, $0.manufacturer, $0.name) < ($1.favorite ? 0 : 1, $1.manufacturer, $1.name) }
        LabeledContent(field.label) {
            NamePicker(options: items.map(\.name), values: $values, title: field.label)
        }
    }
}

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        let v = UInt64(s, radix: 16) ?? 0xD4380D
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }

    var hex: String {
        let c = NSColor(self).usingColorSpace(.sRGB) ?? .orange
        return String(format: "#%02X%02X%02X", Int(c.redComponent * 255),
                      Int(c.greenComponent * 255), Int(c.blueComponent * 255))
    }
}
