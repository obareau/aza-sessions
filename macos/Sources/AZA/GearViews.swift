import AZACore
import SwiftUI

// MARK: - Catalogue

struct CatalogueView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @Local private var type = "machine"
    @Local private var query = ""
    @Local private var proposal: [Int: String]? = nil

    var items: [GearItem] {
        store.data.catalogue
            .filter { query.isEmpty ? $0.type == type
                : "\($0.manufacturer) \($0.name) \($0.code)".localizedCaseInsensitiveContains(query) }
            .sorted { ($0.manufacturer.lowercased(), $0.name.lowercased()) < ($1.manufacturer.lowercased(), $1.name.lowercased()) }
    }

    var types: [(key: String, label: String)] {
        let known = Set(Vocab.itemTypes.map(\.key))
        let custom = Set(store.data.catalogue.map(\.type)).subtracting(known).sorted()
        return Vocab.itemTypes + custom.map { ($0, $0) }
    }

    var body: some View {
        HSplitView {
            VStack(spacing: 6) {
                Picker("", selection: $type) {
                    ForEach(types, id: \.key) { t in
                        Text("\(t.label) (\(store.data.catalogue.filter { $0.type == t.key }.count))").tag(t.key)
                    }
                }.labelsHidden().disabled(!query.isEmpty)
                TextField("Rechercher dans tout le catalogue…", text: $query).textFieldStyle(.roundedBorder)
                List(items, selection: $nav.gear) { g in
                    HStack {
                        Text(g.favorite ? "★" : " ").foregroundStyle(.tint)
                        VStack(alignment: .leading) {
                            Text(g.name).azaFont(.body, mono: true)
                                .foregroundStyle(g.active ? .primary : .secondary)
                                .strikethrough(!g.active)
                            let sub = [g.manufacturer, query.isEmpty ? "" : Vocab.itemLabel(g.type)].filter { !$0.isEmpty }
                            if !sub.isEmpty { Text(sub.joined(separator: " · ")).foregroundStyle(.secondary).azaFont(.caption) }
                        }
                        Spacer()
                        if g.noDraw { Image(systemName: "dice").foregroundStyle(.secondary).help("Hors tirage") }
                        if !g.code.isEmpty {
                            Text(g.code).azaFont(.caption, mono: true)
                                .padding(.horizontal, 4)
                                .background(RoundedRectangle(cornerRadius: 3).stroke(.secondary))
                        }
                    }.tag(g.id)
                }
            }
            .padding(.top, 8)
            .frame(minWidth: 280, idealWidth: 320, maxWidth: 440)

            Group {
                if let id = nav.gear, let i = store.data.catalogue.firstIndex(where: { $0.id == id }) {
                    GearEditor(item: $store.data.catalogue[i], types: types).id(id)
                } else {
                    Text("Aucune fiche sélectionnée").foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }.frame(minWidth: 460, maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Catalogue")
        .onChange(of: type) { t in
            if let g = store.data.gear(nav.gear), g.type != t { nav.gear = nil }
        }
        .onAppear { if let g = store.data.gear(nav.gear) { type = g.type } }
        .toolbar {
            Button {
                let g = GearItem(id: store.data.nextGearId(), type: type, name: "Nouvelle fiche")
                store.data.catalogue.append(g)
                nav.gear = g.id
            } label: { Label("Nouvelle", systemImage: "plus") }
            Menu {
                Button("Fiches matériel — \(Vocab.itemLabel(type))") {
                    nav.print(PrintJob(title: "Fiches matériel",
                                       html: Sheets.catalogue(store.data.catalogue.filter { $0.type == type },
                                                              filter: Vocab.itemLabel(type), version: Store.version),
                                       landscape: true, fileName: "fiches_\(type)"))
                }
                Button("Fiches matériel — tout le catalogue") {
                    nav.print(PrintJob(title: "Fiches matériel",
                                       html: Sheets.catalogue(store.data.catalogue, filter: "", version: Store.version),
                                       landscape: true, fileName: "fiches_materiel"))
                }
                Button("Séance rapide avec cette fiche") {
                    if let g = store.data.gear(nav.gear) { nav.quick = QuickRequest(gear: [g.name]) }
                }.disabled(nav.gear == nil)
                Button("Feuille d'atelier — cette fiche") {
                    if let g = store.data.gear(nav.gear) {
                        nav.print(PrintJob(title: "Feuille d'atelier",
                                           html: Sheets.workshop(gear: [g.name], data: store.data, version: Store.version),
                                           fileName: "atelier_\(g.name)"))
                    }
                }.disabled(nav.gear == nil)
            } label: { Label("Imprimer", systemImage: "printer") }
            Button { proposal = CodeProposer.propose(store.data.catalogue) } label: {
                Label("Proposer les codes", systemImage: "textformat.abc")
            }.help("Proposer un code de prise aux fiches actives qui n'en ont pas")
            Button {
                guard let id = nav.gear, let g = store.data.gear(id),
                      Panels.confirm("Supprimer « \(g.name) » ?",
                                     "Les séances gardent le nom ; pour la garder hors des listes, la désactiver suffit. "
                                     + "Ses associations, remarques et relevés de façade sont supprimés.", ok: "Supprimer") else { return }
                nav.gear = nil
                store.data.catalogue.removeAll { $0.id == id }
                store.data.gearPairings.removeAll { $0.gearId == id || $0.partnerId == id }
                store.data.gearNotes.removeAll { $0.gearId == id }
                store.data.knobSheets.removeAll { $0.gearId == id }
            } label: { Label("Supprimer", systemImage: "trash") }.disabled(nav.gear == nil)
        }
        .sheet(isPresented: Binding(get: { proposal != nil }, set: { if !$0 { proposal = nil } })) {
            CodeProposalSheet(proposal: proposal ?? [:]) { proposal = nil }
        }
    }
}

struct CodeProposalSheet: View {
    @EnvironmentObject var store: Store
    let proposal: [Int: String]
    let close: () -> Void
    @Local private var accepted: Set<Int> = []
    @Local private var ready = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CODES PROPOSÉS").azaHeading(.headline)
            Text("Les codes existants ne sont jamais touchés : ils sont peut-être déjà inscrits sur des prises.")
                .foregroundStyle(.secondary).azaFont(.caption)
            if proposal.isEmpty {
                Text("Toutes les fiches actives ont déjà un code.").padding(.vertical)
            } else {
                List(proposal.sorted { $0.value < $1.value }, id: \.key) { id, code in
                    Toggle(isOn: Binding(get: { accepted.contains(id) },
                                         set: { if $0 { accepted.insert(id) } else { accepted.remove(id) } })) {
                        HStack {
                            Text(code).azaFont(.body, mono: true).frame(width: 50, alignment: .leading)
                            Text(store.data.gear(id)?.name ?? "?")
                        }
                    }
                }
                .frame(minHeight: 260)
            }
            HStack {
                Spacer()
                Button("Annuler", action: close).keyboardShortcut(.cancelAction)
                Button("Appliquer (\(accepted.count))") {
                    for id in accepted {
                        if let i = store.data.catalogue.firstIndex(where: { $0.id == id }) {
                            store.data.catalogue[i].code = proposal[id] ?? ""
                        }
                    }
                    close()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(accepted.isEmpty)
            }
        }
        .padding(18)
        .frame(width: 440)
        .onAppear { if !ready { accepted = Set(proposal.keys); ready = true } }
    }
}

struct GearEditor: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @Binding var item: GearItem
    let types: [(key: String, label: String)]
    @Local private var tab = 0
    @Local private var originalName = ""

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                Text("Fiche").tag(0)
                Text("Carnet").tag(1)
                Text("Façade").tag(2)
            }
            .pickerStyle(.segmented).labelsHidden().padding(10)
            switch tab {
            case 1: GearNotebook(gear: item)
            case 2: FacadeEditor(gear: $item)
            default: fiche
            }
        }
        .onAppear { originalName = item.name }
        .onDisappear(perform: renameEverywhere)
    }

    var usage: [Session] {
        store.data.sessions.filter { $0.allGear.contains(item.name) }.sorted { $0.date > $1.date }
    }

    var fiche: some View {
        Form {
            Section {
                TextField("Nom", text: $item.name).onSubmit(renameEverywhere)
                TextField("Fabricant", text: $item.manufacturer)
                Picker("Type", selection: $item.type) {
                    ForEach(types, id: \.key) { Text($0.label).tag($0.key) }
                }
                TextField("Code prise (A-Z, 0-9)", text: Binding(
                    get: { item.code },
                    set: { item.code = String($0.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }.prefix(4)) }))
                HStack {
                    Toggle("Active", isOn: $item.active)
                    Toggle("Favorite", isOn: $item.favorite)
                    Toggle("Hors tirage", isOn: $item.noDraw)
                }
            }
            Section {
                TextField("Rôle (purpose)", text: $item.purpose)
                TextField("Intention", text: $item.intent)
                MultiLine("Notes", text: $item.notes, minHeight: 80)
            }
            Section {
                ForEach(usage.prefix(40)) { s in
                    Button { nav.open(session: s.id) } label: {
                        Text("\(s.date) — \(s.displayTitle)").azaFont(.caption, mono: true)
                    }.buttonStyle(.plain)
                }
            } header: { Text("UTILISÉE DANS \(usage.count) SÉANCE(S)").azaHeading() }
            let patches = store.data.patches(using: item.id)
            if !patches.isEmpty {
                Section {
                    ForEach(patches) { p in
                        Button { nav.open(patch: p.id) } label: {
                            Text("⬡ \(p.name)").azaFont(.caption, mono: true)
                        }.buttonStyle(.plain)
                    }
                } header: { Text("DANS \(patches.count) PATCH(ES)").azaHeading() }
            }
        }
        .formStyle(.grouped)
    }

    /// Les séances citent le matériel par nom exact : renommer la fiche
    /// renomme aussi le nom dans les séances, sinon elles perdraient le lien.
    func renameEverywhere() {
        let new = item.name.trimmingCharacters(in: .whitespaces)
        guard !originalName.isEmpty, !new.isEmpty, new != originalName else { return }
        for i in store.data.sessions.indices {
            for f in GearField.allCases {
                store.data.sessions[i][keyPath: f.keyPath] = store.data.sessions[i][keyPath: f.keyPath]
                    .map { $0 == originalName ? new : $0 }
            }
        }
        originalName = new
    }
}

// MARK: - Carnet d'instrument

struct GearNotebook: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    let gear: GearItem
    @Local private var newNote = ""
    @Local private var partner: Int? = nil
    @Local private var pairNote = ""

    var body: some View {
        Form {
            Section {
                let notes = store.data.gearNotes.filter { $0.gearId == gear.id }.sorted { ($0.date, $0.id) > ($1.date, $1.id) }
                HStack(alignment: .top) {
                    TextField("Nouvelle remarque…", text: $newNote, axis: .vertical).lineLimit(1...5)
                    Button("Noter") {
                        let t = newNote.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !t.isEmpty else { return }
                        store.data.gearNotes.append(GearNote(id: nextId(store.data.gearNotes), gearId: gear.id,
                                                             date: Clock.today(), note: t))
                        newNote = ""
                    }
                }
                ForEach(notes) { n in
                    HStack(alignment: .top) {
                        Text(n.date).foregroundStyle(.secondary).azaFont(.caption, mono: true)
                        Text(n.note).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                        Button { store.data.gearNotes.removeAll { $0.id == n.id } } label: { Image(systemName: "xmark") }
                            .buttonStyle(.borderless).foregroundStyle(.secondary)
                    }
                }
            } header: { Text("REMARQUES").azaHeading() } footer: {
                Text("Un journal, pas un champ : apprendre une machine se fait par couches.")
                    .foregroundStyle(.secondary).azaFont(.caption)
            }

            Section {
                let pairs = store.data.pairings(of: gear.id)
                ForEach(pairs, id: \.pairing.id) { p in
                    HStack {
                        Button(p.partner.name) { nav.open(gear: p.partner.id) }.buttonStyle(.link)
                        Text(Vocab.itemLabel(p.partner.type)).foregroundStyle(.secondary).azaFont(.caption)
                        Text(p.pairing.note).frame(maxWidth: .infinity, alignment: .leading)
                        Button { store.data.gearPairings.removeAll { $0.id == p.pairing.id } } label: { Image(systemName: "xmark") }
                            .buttonStyle(.borderless).foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Picker("Avec", selection: $partner) {
                        Text("—").tag(Int?.none)
                        ForEach(store.data.catalogue.filter { $0.active && $0.id != gear.id }
                            .sorted { $0.name.lowercased() < $1.name.lowercased() }) { g in
                            Text(g.name).tag(Int?.some(g.id))
                        }
                    }
                    TextField("pourquoi ça marche", text: $pairNote)
                    Button("Associer") {
                        guard let p = partner else { return }
                        var x = GearPairing(id: nextId(store.data.gearPairings), gearId: gear.id, partnerId: p)
                        x.note = pairNote
                        store.data.gearPairings.append(x)
                        partner = nil; pairNote = ""
                    }.disabled(partner == nil)
                }
            } header: { Text("ÇA MARCHE BIEN AVEC").azaHeading() } footer: {
                Text("Une association notée ici apparaît aussi sur l'autre fiche.").foregroundStyle(.secondary).azaFont(.caption)
            }

            Section {
                let presets = store.data.presets.filter { $0.catalogueId == gear.id }
                    .sorted { (($0.rating ?? 0), $0.date) > (($1.rating ?? 0), $1.date) }
                if presets.isEmpty { Text("Aucun preset noté.").foregroundStyle(.secondary) }
                ForEach(presets.prefix(15)) { p in
                    HStack {
                        Text(p.presetName).azaFont(.body, mono: true)
                        if let r = p.rating, r > 0 { Text(String(repeating: "★", count: r)).foregroundStyle(.tint) }
                        Text(p.evocation).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            } header: { Text("PATCHES FAVORIS").azaHeading() }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Façades et relevés

struct FacadesView: View {
    @EnvironmentObject var store: Store
    @Local private var selection: Int? = nil

    var body: some View {
        let gear = store.data.catalogue.filter(\.active).sorted {
            (!parseControls($0.controls).isEmpty ? 0 : 1, $0.name.lowercased())
                < (!parseControls($1.controls).isEmpty ? 0 : 1, $1.name.lowercased())
        }
        HSplitView {
            List(gear, selection: $selection) { g in
                HStack {
                    Text(g.name)
                    Spacer()
                    let n = store.data.knobSheets.filter { $0.gearId == g.id }.count
                    if n > 0 { Text("\(n)").foregroundStyle(.secondary).azaFont(.caption) }
                    if parseControls(g.controls).isEmpty { Text("à déclarer").foregroundStyle(.secondary).azaFont(.caption2) }
                }.tag(g.id)
            }
            .frame(minWidth: 240, idealWidth: 280, maxWidth: 380)
            Group {
                if let id = selection, let i = store.data.catalogue.firstIndex(where: { $0.id == id }) {
                    FacadeEditor(gear: $store.data.catalogue[i]).id(id)
                } else {
                    Text("Choisis un instrument : sur une machine sans mémoire, le relevé de façade est la seule trace d'un son.")
                        .foregroundStyle(.secondary).multilineTextAlignment(.center).padding(40)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }.frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Façades")
    }
}

struct FacadeEditor: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @Binding var gear: GearItem
    @Local private var editingDecl = false
    @Local private var draft = KnobSheet(id: 0, gearId: 0)
    @Local private var drafting = false

    var controls: [Control] { parseControls(gear.controls) }
    var sheets: [KnobSheet] { store.data.knobSheets.filter { $0.gearId == gear.id }.sorted { $0.createdAt > $1.createdAt } }

    var body: some View {
        Form {
            Section {
                if editingDecl || controls.isEmpty {
                    MultiLine("Une commande par ligne", text: $gear.controls, minHeight: 150)
                    Text("-- TITRE = section · Cutoff = potard 0–10 · Filtre: LP | BP | HP = sélecteur · # = commentaire")
                        .foregroundStyle(.secondary).azaFont(.caption, mono: true)
                    if !controls.isEmpty { Button("Terminé") { editingDecl = false } }
                } else {
                    Text(controls.filter { $0.kind != .section }.map(\.name).joined(separator: " · "))
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Modifier la déclaration") { editingDecl = true }
                        Button("Feuille d'atelier") {
                            nav.print(PrintJob(title: "Feuille d'atelier",
                                               html: Sheets.workshop(gear: [gear.name], data: store.data, version: Store.version),
                                               fileName: "atelier_\(gear.name)"))
                        }
                    }
                }
            } header: { Text("FAÇADE — \(gear.name.uppercased())").azaHeading() }

            if !controls.isEmpty {
                Section {
                    if drafting {
                        SheetForm(sheet: $draft, controls: controls, gearId: gear.id)
                        HStack {
                            Button("Annuler") { drafting = false }
                            Spacer()
                            Button("Enregistrer le relevé") {
                                var s = draft
                                s.id = nextId(store.data.knobSheets); s.gearId = gear.id; s.createdAt = Clock.stamp()
                                store.data.knobSheets.append(s)
                                drafting = false
                            }.buttonStyle(.borderedProminent).disabled(draft.values.isEmpty)
                        }
                    } else {
                        Button { draft = KnobSheet(id: 0, gearId: gear.id); drafting = true } label: {
                            Label("Nouveau relevé", systemImage: "plus")
                        }
                    }
                } header: { Text("RELEVER").azaHeading() } footer: {
                    Text("Une commande laissée vide n'a pas été lue : elle n'est pas enregistrée (« pas relevé » n'est pas « à zéro »).")
                        .foregroundStyle(.secondary).azaFont(.caption)
                }
            }

            Section {
                if sheets.isEmpty { Text("Aucun relevé.").foregroundStyle(.secondary) }
                ForEach(sheets) { s in SheetCard(sheet: s, controls: controls) }
            } header: { Text("RELEVÉS (\(sheets.count))").azaHeading() }
        }
        .formStyle(.grouped)
    }
}

/// Saisie d'un relevé. Un potard non touché reste absent des valeurs.
struct SheetForm: View {
    @EnvironmentObject var store: Store
    @Binding var sheet: KnobSheet
    let controls: [Control]
    let gearId: Int

    var body: some View {
        TextField("Nom du son / du relevé", text: $sheet.label)
        HStack {
            Picker("Séance", selection: $sheet.sessionId) {
                Text("—").tag(Int?.none)
                ForEach(store.data.sessions.sorted { $0.date > $1.date }.prefix(60)) { s in
                    Text("\(s.date) — \(s.displayTitle)").tag(Int?.some(s.id))
                }
            }
            Picker("Patch", selection: $sheet.presetId) {
                Text("—").tag(Int?.none)
                ForEach(store.data.presets.filter { $0.catalogueId == gearId }) { p in Text(p.presetName).tag(Int?.some(p.id)) }
            }
        }
        ForEach(Array(controls.enumerated()), id: \.offset) { _, c in
            switch c.kind {
            case .section:
                Text(c.name.uppercased()).azaHeading(.caption2).padding(.top, 4)
            case .dial:
                HStack {
                    Text(c.name).frame(width: 140, alignment: .leading)
                    Slider(value: Binding(get: { Double(sheet.values[c.name] ?? "") ?? 0 },
                                          set: { sheet.values[c.name] = fmt($0) }), in: 0...10, step: 0.5)
                        .opacity(sheet.values[c.name] == nil ? 0.35 : 1)
                    Text(sheet.values[c.name] ?? "—").monospacedDigit().frame(width: 34, alignment: .trailing)
                    Button { sheet.values[c.name] = nil } label: { Image(systemName: "xmark.circle") }
                        .buttonStyle(.borderless).foregroundStyle(.secondary)
                        .opacity(sheet.values[c.name] == nil ? 0 : 1)
                }
            case .switch:
                Picker(c.name, selection: Binding(get: { sheet.values[c.name] ?? "" },
                                                  set: { sheet.values[c.name] = $0.isEmpty ? nil : $0 })) {
                    Text("—").tag("")
                    ForEach(c.options, id: \.self) { Text($0).tag($0) }
                }
            }
        }
        TextField("Notes", text: $sheet.notes, axis: .vertical)
    }

    func fmt(_ v: Double) -> String { v.rounded() == v ? String(Int(v)) : String(format: "%.1f", v) }
}

struct SheetCard: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    let sheet: KnobSheet
    let controls: [Control]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(sheet.label.isEmpty ? "Relevé du \(sheet.createdAt.prefix(10))" : sheet.label).azaFont(.headline)
                Text(String(sheet.createdAt.prefix(10))).foregroundStyle(.secondary).azaFont(.caption, mono: true)
                Spacer()
                if let sid = sheet.sessionId, let s = store.data.sessions.first(where: { $0.id == sid }) {
                    Button("→ \(s.displayTitle)") { nav.open(session: s.id) }.buttonStyle(.link)
                }
                Button {
                    if Panels.confirm("Supprimer ce relevé ?", "", ok: "Supprimer") {
                        store.data.knobSheets.removeAll { $0.id == sheet.id }
                    }
                } label: { Image(systemName: "trash") }.buttonStyle(.borderless).foregroundStyle(.secondary)
            }
            if let pid = sheet.presetId, let p = store.data.presets.first(where: { $0.id == pid }) {
                Text("Patch : \(p.presetName)").foregroundStyle(.secondary).azaFont(.caption)
            }
            let known = controls.filter { $0.kind != .section }.map(\.name)
            let names = known.filter { sheet.values[$0] != nil } + sheet.values.keys.filter { !known.contains($0) }.sorted()
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 6)], alignment: .leading, spacing: 4) {
                ForEach(names, id: \.self) { n in
                    HStack(spacing: 4) {
                        Text(n).foregroundStyle(.secondary).lineLimit(1)
                        Text(sheet.values[n] ?? "").azaFont(.body, mono: true).foregroundStyle(.tint)
                    }.azaFont(.caption)
                }
            }
            if !sheet.notes.isEmpty { Text(sheet.notes).azaFont(.caption) }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Presets

struct PresetsView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var prefs: Prefs
    @Local private var gearFilter: Int? = nil
    @Local private var showStats = false

    var body: some View {
        Group {
            if showStats { stats } else { list }
        }
        .toolbar {
            Toggle(isOn: $showStats) { Label("Stats", systemImage: "chart.bar") }.help("Statistiques par machine")
        }
    }

    var list: some View {
        MasterDetail(
            title: "Presets", items: $store.data.presets,
            sort: { ($0.date, $0.id) > ($1.date, $1.id) },
            matches: { [store] p, q in
                has(q, p.presetName, p.evocation, p.songIdea, p.tags, p.notes,
                    store.data.gear(p.catalogueId)?.name ?? "",
                    store.data.influences.first { $0.id == p.influenceId }?.name ?? "")
            },
            make: { [gearFilter] id in var p = PresetNote(id: id, date: Clock.today(), presetName: "Nouveau preset"); p.catalogueId = gearFilter; return p },
            row: { p in
                HStack {
                    VStack(alignment: .leading) {
                        Text(p.presetName).azaFont(.body, mono: true)
                        Text([store.data.gear(p.catalogueId)?.name ?? "", p.date].filter { !$0.isEmpty }.joined(separator: " · "))
                            .foregroundStyle(.secondary).azaFont(.caption)
                    }
                    Spacer()
                    if let r = p.rating, r > 0 { Text(String(repeating: "★", count: r)).foregroundStyle(.tint).azaFont(.caption) }
                }
            },
            editor: { $p in PresetEditor(preset: $p) },
            deleteLabel: { "« \($0.presetName) »" },
            filters: AnyView(Picker("", selection: $gearFilter) {
                Text("Toutes les machines").tag(Int?.none)
                ForEach(store.data.catalogue.filter { g in store.data.presets.contains { $0.catalogueId == g.id } }
                    .sorted { $0.name < $1.name }) { g in Text(g.name).tag(Int?.some(g.id)) }
            }.labelsHidden()),
            include: { [gearFilter] in gearFilter == nil || $0.catalogueId == gearFilter })
    }

    var stats: some View {
        let byGear = Dictionary(grouping: store.data.presets, by: \.catalogueId)
            .map { (gear: store.data.gear($0.key)?.name ?? "Sans machine", notes: $0.value) }
            .sorted { $0.notes.count > $1.notes.count }
        let top = store.data.presets.filter { ($0.rating ?? 0) > 0 }
            .sorted { (($0.rating ?? 0), $0.date) > (($1.rating ?? 0), $1.date) }.prefix(10)
        return List {
            SwiftUI.Section {
                ForEach(byGear, id: \.gear) { g in
                    let rated = g.notes.compactMap(\.rating).filter { $0 > 0 }
                    HStack {
                        Text(g.gear).frame(width: 200, alignment: .leading)
                        Text("\(g.notes.count) preset(s)").frame(width: 100, alignment: .leading)
                        Text(rated.isEmpty ? "—" : String(format: "★ %.1f", Double(rated.reduce(0, +)) / Double(rated.count)))
                            .foregroundStyle(.tint).frame(width: 70, alignment: .leading)
                        Text("dernier : \(g.notes.map(\.date).max() ?? "")").foregroundStyle(.secondary).azaFont(.caption)
                    }
                }
            } header: { Text("PAR MACHINE").azaHeading() }
            SwiftUI.Section {
                ForEach(Array(top)) { p in
                    HStack {
                        Text(String(repeating: "★", count: p.rating ?? 0)).foregroundStyle(.tint).frame(width: 70, alignment: .leading)
                        Text(p.presetName).azaFont(.body, mono: true)
                        Text(store.data.gear(p.catalogueId)?.name ?? "").foregroundStyle(.secondary)
                    }
                }
            } header: { Text("MEILLEURS PRESETS").azaHeading() }
        }
        .navigationTitle("Presets — statistiques")
    }
}

struct PresetEditor: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @Binding var preset: PresetNote

    var body: some View {
        Form {
            Section {
                TextField("Nom du preset / patch", text: $preset.presetName)
                DatePicker("Date", selection: Binding(get: { Clock.day(preset.date) ?? Date() },
                                                      set: { preset.date = Clock.day($0) }), displayedComponents: .date)
                Picker("Machine", selection: $preset.catalogueId) {
                    Text("—").tag(Int?.none)
                    ForEach(store.data.catalogue.filter { $0.active || $0.id == preset.catalogueId }
                        .sorted { $0.name.lowercased() < $1.name.lowercased() }) { g in Text(g.name).tag(Int?.some(g.id)) }
                }
                LabeledContent("Note") { Dots(value: $preset.rating, symbol: "★") }
            }
            Section {
                TextField("Évocation", text: $preset.evocation, axis: .vertical)
                TextField("Idée de morceau", text: $preset.songIdea, axis: .vertical)
                Picker("Influence", selection: $preset.influenceId) {
                    Text("—").tag(Int?.none)
                    ForEach(store.data.influences.sorted { $0.name < $1.name }) { i in Text(i.name).tag(Int?.some(i.id)) }
                }
                TextField("Tags", text: $preset.tags)
                Picker("Séance", selection: $preset.sessionId) {
                    Text("—").tag(Int?.none)
                    ForEach(store.data.sessions.sorted { $0.date > $1.date }) { s in
                        Text("\(s.date) — \(s.displayTitle)").tag(Int?.some(s.id))
                    }
                }
                if let sid = preset.sessionId {
                    Button("Ouvrir la séance →") { nav.open(session: sid) }.buttonStyle(.link)
                }
                MultiLine("Notes", text: $preset.notes, minHeight: 100)
            }
            let sheets = store.data.knobSheets.filter { $0.presetId == preset.id }
            if !sheets.isEmpty, let g = store.data.gear(preset.catalogueId) {
                Section {
                    ForEach(sheets) { s in SheetCard(sheet: s, controls: parseControls(g.controls)) }
                } header: { Text("RELEVÉS DE FAÇADE").azaHeading() }
            }
        }
        .formStyle(.grouped)
    }
}
