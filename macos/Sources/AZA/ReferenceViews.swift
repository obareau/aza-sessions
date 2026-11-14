import AZACore
import SwiftUI

// MARK: - Projets

struct ProjectsView: View {
    @EnvironmentObject var store: Store
    var openSession: (Int) -> Void
    @Local private var selection: Int?

    var body: some View {
        HSplitView {
            List(store.data.projects.sorted { $0.title.localizedCompare($1.title) == .orderedAscending },
                 selection: $selection) { p in
                HStack {
                    Circle().fill(Color(hex: p.color)).frame(width: 10, height: 10)
                    Text(p.title).font(.system(.body, design: .monospaced))
                    Spacer()
                    Text("\(store.data.sessions.filter { $0.projectId == p.id }.count)")
                        .foregroundStyle(.secondary).font(.caption)
                }.tag(p.id)
            }
            .frame(minWidth: 240, idealWidth: 280, maxWidth: 400)

            Group {
                if let id = selection, let i = store.data.projects.firstIndex(where: { $0.id == id }) {
                    ProjectEditor(project: $store.data.projects[i], openSession: openSession).id(id)
                } else {
                    Text("Aucun projet sélectionné").foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }.frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Projets")
        .toolbar {
            Button {
                let p = Project(id: store.data.nextProjectId(), title: "Nouveau projet")
                store.data.projects.append(p)
                selection = p.id
            } label: { Label("Nouveau", systemImage: "plus") }
            Button {
                guard let id = selection, let p = store.data.projects.first(where: { $0.id == id }),
                      Panels.confirm("Supprimer le projet « \(p.title) » ?",
                                     "Les séances sont conservées, sans projet.", ok: "Supprimer") else { return }
                selection = nil
                store.data.projects.removeAll { $0.id == id }
                for i in store.data.sessions.indices where store.data.sessions[i].projectId == id {
                    store.data.sessions[i].projectId = nil
                }
            } label: { Label("Supprimer", systemImage: "trash") }.disabled(selection == nil)
        }
    }
}

struct ProjectEditor: View {
    @EnvironmentObject var store: Store
    @Binding var project: Project
    var openSession: (Int) -> Void

    var body: some View {
        Form {
            TextField("Titre", text: $project.title)
            ColorPicker("Couleur", selection: Binding(get: { Color(hex: project.color) },
                                                      set: { project.color = $0.hex }),
                        supportsOpacity: false)
            MultiLine("Description", text: $project.description, minHeight: 90)
            Section("Séances") {
                let list = store.data.sessions.filter { $0.projectId == project.id }.sorted { $0.date > $1.date }
                if list.isEmpty { Text("Aucune séance").foregroundStyle(.secondary) }
                ForEach(list) { s in
                    Button { openSession(s.id) } label: { SessionRow(session: s) }.buttonStyle(.plain)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Catalogue

struct CatalogueView: View {
    @EnvironmentObject var store: Store
    @Local private var type = "machine"
    @Local private var selection: Int?
    @Local private var query = ""

    var items: [GearItem] {
        store.data.catalogue
            .filter { $0.type == type }
            .filter { query.isEmpty || "\($0.manufacturer) \($0.name) \($0.code)".localizedCaseInsensitiveContains(query) }
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
                }.labelsHidden()
                TextField("Rechercher…", text: $query).textFieldStyle(.roundedBorder)
                List(items, selection: $selection) { g in
                    HStack {
                        Text(g.favorite ? "★" : " ").foregroundStyle(azaOrange)
                        VStack(alignment: .leading) {
                            Text(g.name).font(.system(.body, design: .monospaced))
                                .foregroundStyle(g.active ? .primary : .secondary)
                                .strikethrough(!g.active)
                            if !g.manufacturer.isEmpty {
                                Text(g.manufacturer).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if !g.code.isEmpty {
                            Text(g.code).font(.system(.caption, design: .monospaced))
                                .padding(.horizontal, 4)
                                .background(RoundedRectangle(cornerRadius: 3).stroke(.secondary))
                        }
                    }.tag(g.id)
                }
            }
            .padding(.top, 8)
            .frame(minWidth: 280, idealWidth: 320, maxWidth: 440)

            Group {
                if let id = selection, let i = store.data.catalogue.firstIndex(where: { $0.id == id }) {
                    GearEditor(item: $store.data.catalogue[i], types: types).id(id)
                } else {
                    Text("Aucune fiche sélectionnée").foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }.frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Catalogue")
        .onChange(of: type) { _ in selection = nil }
        .toolbar {
            Button {
                let g = GearItem(id: store.data.nextGearId(), type: type, name: "Nouvelle fiche")
                store.data.catalogue.append(g)
                selection = g.id
            } label: { Label("Nouvelle", systemImage: "plus") }
            Button {
                guard let id = selection, let g = store.data.catalogue.first(where: { $0.id == id }),
                      Panels.confirm("Supprimer « \(g.name) » ?",
                                     "Les séances gardent le nom ; pour la garder hors des listes, " +
                                     "la désactiver suffit.", ok: "Supprimer") else { return }
                selection = nil
                store.data.catalogue.removeAll { $0.id == id }
            } label: { Label("Supprimer", systemImage: "trash") }.disabled(selection == nil)
        }
    }
}

struct GearEditor: View {
    @EnvironmentObject var store: Store
    @Binding var item: GearItem
    let types: [(key: String, label: String)]
    @Local private var originalName = ""

    var usage: [Session] {
        store.data.sessions.filter { $0.allGear.contains(item.name) }.sorted { $0.date > $1.date }
    }

    var body: some View {
        Form {
            Section {
                TextField("Nom", text: $item.name)
                    .onAppear { originalName = item.name }
                    .onSubmit(renameEverywhere)
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
                MultiLine("Commandes de façade (une par ligne)", text: $item.controls)
            }
            Section("Utilisée dans \(usage.count) séance(s)") {
                ForEach(usage.prefix(30)) { s in
                    Text("\(s.date) — \(s.displayTitle)").font(.system(.caption, design: .monospaced))
                }
            }
        }
        .formStyle(.grouped)
        .onDisappear(perform: renameEverywhere)
    }

    /// Le carnet croise les séances par nom exact : renommer la fiche renomme
    /// aussi le nom dans les séances, sinon elles perdraient le lien.
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

// MARK: - Influences

struct InfluencesView: View {
    @EnvironmentObject var store: Store
    @Local private var newName = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Nouvelle influence (artiste, label…)", text: $newName).onSubmit(add)
                Button("Ajouter", action: add).disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }.padding(10)
            List {
                ForEach($store.data.influences) { $i in
                    HStack {
                        Toggle("", isOn: $i.active).labelsHidden().help("Proposée dans les séances")
                        TextField("Nom", text: $i.name).frame(minWidth: 160)
                        TextField("Type", text: $i.type).frame(width: 100)
                        TextField("Notes", text: $i.notes)
                        Text("\(store.data.sessions.filter { $0.influences.contains(i.name) }.count)")
                            .foregroundStyle(.secondary).frame(width: 36, alignment: .trailing)
                            .help("Séances qui la citent")
                    }
                }
                .onDelete { store.data.influences.remove(atOffsets: $0) }
            }
        }
        .navigationTitle("Influences")
    }

    func add() {
        let n = newName.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty, !store.data.influences.contains(where: { $0.name == n }) else { return }
        store.data.influences.append(Influence(id: store.data.nextInfluenceId(), name: n))
        newName = ""
    }
}

// MARK: - Stratégies obliques

struct ObliquesView: View {
    @EnvironmentObject var store: Store
    @Local private var drawn: String?
    @Local private var newText = ""

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                Text(drawn ?? "Tirer une stratégie")
                    .font(.system(.title2, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(drawn == nil ? .secondary : .primary)
                    .frame(maxWidth: 640, minHeight: 70)
                Button { drawn = store.data.randomOblique() } label: {
                    Label("Tirer", systemImage: "dice")
                }.keyboardShortcut(.space, modifiers: [])
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(azaOrange.opacity(0.08))

            HStack {
                TextField("Nouvelle stratégie…", text: $newText).onSubmit(add)
                Button("Ajouter", action: add).disabled(newText.trimmingCharacters(in: .whitespaces).isEmpty)
            }.padding(10)

            List {
                ForEach($store.data.obliques) { $o in
                    HStack {
                        Toggle("", isOn: $o.active).labelsHidden()
                        TextField("", text: $o.text).foregroundStyle(o.active ? .primary : .secondary)
                    }
                }
                .onDelete { store.data.obliques.remove(atOffsets: $0) }
            }
        }
        .navigationTitle("Stratégies obliques")
    }

    func add() {
        let t = newText.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        store.data.obliques.append(Oblique(id: store.data.nextObliqueId(), text: t))
        newText = ""
    }
}
