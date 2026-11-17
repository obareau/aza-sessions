import AZACore
import SwiftUI

// MARK: - Ce soir : le tirage

struct TonightView: View {
    @Environment(\.azaStyle) private var style
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @EnvironmentObject var prefs: Prefs
    @Local private var draw: Draw?
    @Local private var titles: [String] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Un point de départ tiré du matériel que tu possèdes. Rien n'est retenu : "
                     + "un tirage qui ne dit rien se rejoue.")
                    .foregroundStyle(.secondary)
                if let d = draw {
                    card(d)
                } else {
                    ProgressView()
                }
                titlesBox
                excluded
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Ce soir")
        .toolbar {
            Button { redraw() } label: { Label("Retirer", systemImage: "dice") }
                .keyboardShortcut(.space, modifiers: [])
                .help("Nouveau tirage (espace)")
        }
        .onAppear { if draw == nil { redraw() } }
    }

    func redraw() {
        draw = store.data.draw()
        titles = Titles.propose(5)
    }

    func card(_ d: Draw) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if d.isEmpty {
                Text("Aucune fiche à tirer : active des fiches du catalogue, ou remets-en dans le tirage.")
                    .foregroundStyle(.secondary)
            }
            Text(d.title).azaFont(.title, mono: true)
            gearRow("INSTRUMENT", d.instrument)
            gearRow("TRAITEMENT", d.treatment)
            VStack(alignment: .leading, spacing: 4) {
                Text("CONTRAINTE").azaHeading()
                Text(d.oblique).azaFont(.title3).italic()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("NOM DE PRISE R8").azaHeading()
                Text(d.take.isEmpty ? "— (pas de code catalogue)" : d.take).azaFont(.title2, mono: true)
                    .textSelection(.enabled)
            }
            HStack {
                Button { start(d, live: true) } label: { Label("Démarrer en direct", systemImage: "record.circle") }
                    .buttonStyle(.borderedProminent)
                Button { start(d, live: false) } label: { Label("Créer la séance", systemImage: "plus") }
                Button {
                    nav.print(PrintJob(title: "Feuille d'atelier",
                                       html: Sheets.workshop(gear: [d.instrument, d.treatment].compactMap { $0?.name },
                                                             data: store.data, version: Store.version),
                                       fileName: "atelier_\(Clock.today())"))
                } label: { Label("Feuille d'atelier", systemImage: "printer") }
                Button {
                    nav.quick = QuickRequest(gear: [d.instrument, d.treatment].compactMap { $0?.name })
                } label: { Label("Séance rapide", systemImage: "bolt") }
                Spacer()
            }
            .disabled(d.isEmpty)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 6).fill(prefs.palette?.surface ?? Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(style.accent.opacity(0.5)))
    }

    func gearRow(_ label: String, _ g: GearItem?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).azaHeading()
            if let g {
                HStack(alignment: .firstTextBaseline) {
                    Text(g.name).azaFont(.title2)
                    if g.favorite { Text("★").foregroundStyle(.tint) }
                    Text([g.manufacturer, Vocab.itemLabel(g.type)].filter { !$0.isEmpty }.joined(separator: " · "))
                        .foregroundStyle(.secondary).azaFont(.caption)
                    Spacer()
                    Button("Écarter du tirage") {
                        if let i = store.data.catalogue.firstIndex(where: { $0.id == g.id }) {
                            store.data.catalogue[i].noDraw = true
                            redraw()
                        }
                    }.buttonStyle(.link).help("Ne plus proposer cette fiche (elle reste active)")
                }
                if !g.purpose.isEmpty || !g.intent.isEmpty {
                    Text([g.purpose, g.intent].filter { !$0.isEmpty }.joined(separator: " — "))
                        .foregroundStyle(.secondary).azaFont(.caption)
                }
            } else {
                Text("—").foregroundStyle(.secondary)
            }
        }
    }

    var titlesBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("AUTRES TITRES").azaHeading()
                Button { titles = Titles.propose(5) } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless)
            }
            ForEach(titles, id: \.self) { t in
                HStack {
                    Text(t).azaFont(.body, mono: true).textSelection(.enabled)
                    Spacer()
                    Button("Choisir") { draw?.title = t }.buttonStyle(.link)
                }
            }
        }
    }

    @ViewBuilder var excluded: some View {
        let out = store.data.catalogue.filter(\.noDraw).sorted { $0.name < $1.name }
        if !out.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("ÉCARTÉES DU TIRAGE").azaHeading()
                ForEach(out) { g in
                    HStack {
                        Text(g.name)
                        Text(Vocab.itemLabel(g.type)).foregroundStyle(.secondary).azaFont(.caption)
                        Spacer()
                        Button("Reprendre") {
                            if let i = store.data.catalogue.firstIndex(where: { $0.id == g.id }) {
                                store.data.catalogue[i].noDraw = false
                            }
                        }.buttonStyle(.link)
                    }
                }
            }
        }
    }

    func start(_ d: Draw, live: Bool) {
        if live {
            guard store.data.live == nil || Panels.confirm(
                "Une séance est déjà en cours", "La remplacer par ce tirage ?", ok: "Remplacer") else { return }
            var l = LiveSession()
            if let i = d.instrument { l.machines = [i.name] }
            if let t = d.treatment { l.effects = [t.name] }
            l.oblique = d.oblique
            store.data.live = l
            nav.pane = .live
        } else {
            let id = store.newSession()
            guard let b = store.binding(session: id) else { return }
            b.wrappedValue.title = d.title
            if let i = d.instrument { b.wrappedValue.machines = [i.name] }
            if let t = d.treatment { b.wrappedValue.effects = [t.name] }
            b.wrappedValue.oblique = d.oblique
            b.wrappedValue.audioFile = d.take
            nav.open(session: id)
        }
    }
}

// MARK: - Séance en cours

struct LiveView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @EnvironmentObject var prefs: Prefs
    @Local private var mode = ""
    @Local private var intention = ""
    @Local private var project: Int? = nil

    var body: some View {
        Group {
            if store.data.live != nil {
                running
            } else {
                startForm
            }
        }
        .navigationTitle("Séance en cours")
    }

    var startForm: some View {
        Form {
            Section {
                Picker("Mode", selection: $mode) {
                    Text("—").tag("")
                    ForEach(Vocab.modes, id: \.self) { Text($0).tag($0) }
                }
                Picker("Intention", selection: $intention) {
                    Text("—").tag("")
                    ForEach(Vocab.intentions, id: \.self) { Text($0).tag($0) }
                }
                Picker("Projet", selection: $project) {
                    Text("Aucun").tag(Int?.none)
                    ForEach(store.data.projects) { p in Text(p.title).tag(Int?.some(p.id)) }
                }
                Button {
                    var l = LiveSession()
                    l.mode = mode; l.intention = intention; l.projectId = project
                    l.oblique = store.data.randomOblique() ?? ""
                    store.data.live = l
                } label: { Label("Démarrer", systemImage: "record.circle") }
                    .buttonStyle(.borderedProminent)
            } header: {
                Text("DÉMARRER UNE SÉANCE").azaHeading()
            } footer: {
                Text("Le chrono tourne même si tu quittes l'app : la séance en cours est enregistrée dans le JSON.")
                    .foregroundStyle(.secondary).azaFont(.caption)
            }
        }
        .formStyle(.grouped)
    }

    var live: Binding<LiveSession> {
        Binding(get: { store.data.live ?? LiveSession() }, set: { store.data.live = $0 })
    }

    var running: some View {
        Form {
            Section {
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    let start = live.wrappedValue.startDate ?? ctx.date
                    let s = max(0, Int(ctx.date.timeIntervalSince(start)))
                    HStack(alignment: .firstTextBaseline) {
                        Circle().fill(.red).frame(width: 12, height: 12)
                        Text(String(format: "%02d:%02d:%02d", s / 3600, s / 60 % 60, s % 60))
                            .azaFont(.largeTitle, mono: true).monospacedDigit()
                        Spacer()
                        Text("depuis \(String(live.wrappedValue.startedAt.suffix(8).prefix(5)))").foregroundStyle(.secondary)
                    }
                }
                HStack(alignment: .top) {
                    Text(live.wrappedValue.oblique.isEmpty ? "—" : live.wrappedValue.oblique).italic()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button { live.wrappedValue.oblique = store.data.randomOblique() ?? "" } label: { Image(systemName: "dice") }
                        .help("Tirer une autre stratégie")
                }
            } header: { Text("EN COURS").azaHeading() }

            Section {
                HStack {
                    Picker("Mode", selection: live.mode) {
                        Text("—").tag("")
                        ForEach(Vocab.modes, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Intention", selection: live.intention) {
                        Text("—").tag("")
                        ForEach(Vocab.intentions, id: \.self) { Text($0).tag($0) }
                    }
                }
                ForEach([GearField.machines, .effects, .daws, .synthsIOS, .plugins], id: \.self) { f in
                    GearPicker(field: f, values: binding(for: f))
                }
                MultiLine("Notes en direct", text: live.notes, minHeight: 160)
            } header: { Text("SETUP & NOTES").azaHeading() }

            Section {
                HStack {
                    Button { finish() } label: { Label("Terminer → créer la séance", systemImage: "checkmark.circle") }
                        .buttonStyle(.borderedProminent)
                    Spacer()
                    Button("Abandonner", role: .destructive) {
                        if Panels.confirm("Abandonner la séance en cours ?", "Les notes en direct seront perdues.",
                                          ok: "Abandonner") { store.data.live = nil }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    func binding(for f: GearField) -> Binding<[String]> {
        switch f {
        case .machines: live.machines
        case .effects: live.effects
        case .daws: live.daws
        case .synthsIOS: live.synthsIOS
        default: live.plugins
        }
    }

    func finish() {
        if let id = store.finishLive(prefs: prefs) { nav.open(session: id) }
    }
}

// MARK: - Spark

struct SparkView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var prefs: Prefs
    @Local private var items: [Spark] = []
    @Local private var focus = false
    @Local private var index = 0

    var body: some View {
        Group {
            if focus, !items.isEmpty {
                let s = items[index % items.count]
                VStack(spacing: 18) {
                    Text(s.icon).azaFont(.largeTitle)
                    Text(s.kind.uppercased()).azaHeading()
                    Text(s.text).azaFont(.title, mono: true).multilineTextAlignment(.center).frame(maxWidth: 640)
                    if !s.sub.isEmpty { Text(s.sub).foregroundStyle(.secondary) }
                    Button("Suivante  ␣") { index += 1; if index % items.count == 0 { items = store.data.sparks() } }
                        .keyboardShortcut(.space, modifiers: [])
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
                        ForEach(items) { s in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack { Text(s.icon); Text(s.kind.uppercased()).azaHeading(.caption2) }
                                Text(s.text).azaFont(.title3)
                                if !s.sub.isEmpty { Text(s.sub).foregroundStyle(.secondary).azaFont(.caption) }
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
                            .background(RoundedRectangle(cornerRadius: 6)
                                .fill(prefs.palette?.surface ?? Color(nsColor: .controlBackgroundColor)))
                        }
                    }
                    .padding(20)
                    if store.data.sessions.count < 3 {
                        Text("Avec au moins 3 séances, Spark repère aussi le matériel sous-utilisé.")
                            .foregroundStyle(.secondary).padding(.bottom, 20)
                    }
                }
            }
        }
        .navigationTitle("Spark")
        .toolbar {
            Button { items = store.data.sparks(); index = 0 } label: { Label("Relancer", systemImage: "sparkles") }
            Toggle(isOn: $focus) { Label("Focus", systemImage: "scope") }.help("Une suggestion à la fois")
        }
        .onAppear { if items.isEmpty { items = store.data.sparks() } }
    }
}
