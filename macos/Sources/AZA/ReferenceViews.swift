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
                    Text(p.title).azaFont(.body, mono: true)
                    Spacer()
                    Text("\(store.data.sessions.filter { $0.projectId == p.id }.count)")
                        .foregroundStyle(.secondary).azaFont(.caption)
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
                    .azaFont(.title2, mono: true)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(drawn == nil ? .secondary : .primary)
                    .frame(maxWidth: 640, minHeight: 70)
                Button { drawn = store.data.randomOblique() } label: {
                    Label("Tirer", systemImage: "dice")
                }.keyboardShortcut(.space, modifiers: [])
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(Color.accentColor.opacity(0.08))

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
