import AZACore
import SwiftUI

/// Gabarit liste + fiche, partagé par les petits modules (morceaux, samples…).
struct MasterDetail<Item: Identifiable & Equatable, Row: View, Editor: View>: View where Item.ID == Int {
    let title: String
    @Binding var items: [Item]
    let sort: (Item, Item) -> Bool
    let matches: (Item, String) -> Bool
    let make: (Int) -> Item
    let row: (Item) -> Row
    let editor: (Binding<Item>) -> Editor
    var deleteLabel: (Item) -> String = { _ in "cet élément" }
    var filters: AnyView? = nil
    var include: (Item) -> Bool = { _ in true }

    @Local private var selection: Int? = nil
    @Local private var query = ""

    var body: some View {
        HSplitView {
            VStack(spacing: 6) {
                TextField("Rechercher…", text: $query).textFieldStyle(.roundedBorder)
                if let filters { filters }
                List(items.filter { include($0) && (query.isEmpty || matches($0, query.lowercased())) }.sorted(by: sort),
                     selection: $selection) { it in
                    row(it).tag(it.id)
                        .contextMenu { Button("Supprimer…", role: .destructive) { delete(it.id) } }
                }
            }
            .padding(.top, 8)
            .frame(minWidth: 260, idealWidth: 320, maxWidth: 460)

            Group {
                if let id = selection, let i = items.firstIndex(where: { $0.id == id }) {
                    editor($items[i]).id(id)
                } else {
                    Text("Rien de sélectionné").foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }.frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(title)
        .navigationSubtitle("\(items.count)")
        .toolbar {
            Button {
                let it = make(nextId(items))
                items.append(it)
                selection = it.id
            } label: { Label("Ajouter", systemImage: "plus") }
            Button { if let id = selection { delete(id) } } label: { Label("Supprimer", systemImage: "trash") }
                .disabled(selection == nil)
        }
    }

    func delete(_ id: Int) {
        guard let it = items.first(where: { $0.id == id }),
              Panels.confirm("Supprimer \(deleteLabel(it)) ?", "", ok: "Supprimer") else { return }
        if selection == id { selection = nil }
        items.removeAll { $0.id == id }
    }
}

func has(_ q: String, _ fields: String...) -> Bool {
    fields.contains { $0.lowercased().contains(q) }
}

struct OpenURLButton: View {
    let url: String
    var body: some View {
        if let u = URL(string: url.trimmingCharacters(in: .whitespaces)), u.scheme?.hasPrefix("http") == true {
            Link(destination: u) { Image(systemName: "arrow.up.right.square") }.help(url)
        }
    }
}

// MARK: - Morceaux inspirants

struct TracksView: View {
    @EnvironmentObject var store: Store
    var body: some View {
        MasterDetail(
            title: "Morceaux", items: $store.data.tracks,
            sort: { ($0.artist.lowercased(), $0.title.lowercased()) < ($1.artist.lowercased(), $1.title.lowercased()) },
            matches: { has($1, $0.title, $0.artist, $0.album, $0.tags, $0.notes) },
            make: { InspiringTrack(id: $0, title: "Nouveau morceau") },
            row: { t in
                VStack(alignment: .leading) {
                    Text(t.title)
                    Text([t.artist, t.album, t.year].filter { !$0.isEmpty }.joined(separator: " · "))
                        .foregroundStyle(.secondary).azaFont(.caption)
                }
            },
            editor: { $t in
                Form {
                    TextField("Titre", text: $t.title)
                    TextField("Artiste", text: $t.artist)
                    HStack { TextField("Album", text: $t.album); TextField("Année", text: $t.year).frame(width: 120) }
                    TextField("Tags", text: $t.tags)
                    HStack { TextField("Lien", text: $t.url); OpenURLButton(url: t.url) }
                    MultiLine("Notes", text: $t.notes, minHeight: 120)
                }.formStyle(.grouped)
            },
            deleteLabel: { "« \($0.title) »" })
    }
}

// MARK: - Inspirations

struct InspirationsView: View {
    @EnvironmentObject var store: Store
    @Local private var type = ""
    var body: some View {
        MasterDetail(
            title: "Inspirations", items: $store.data.inspirations,
            sort: { $0.id > $1.id },
            matches: { has($1, $0.content, $0.source, $0.notes, $0.type) },
            make: { [type] id in var i = Inspiration(id: id, content: "Nouvelle inspiration"); if !type.isEmpty { i.type = type }; return i },
            row: { i in
                VStack(alignment: .leading) {
                    Text(i.content).lineLimit(2)
                    Text([i.type, i.source].filter { !$0.isEmpty }.joined(separator: " · "))
                        .foregroundStyle(.secondary).azaFont(.caption)
                }
            },
            editor: { $i in
                Form {
                    Picker("Type", selection: $i.type) {
                        ForEach(Vocab.inspiTypes, id: \.self) { Text($0).tag($0) }
                        if !Vocab.inspiTypes.contains(i.type) { Text(i.type).tag(i.type) }
                    }
                    MultiLine("Contenu", text: $i.content, minHeight: 90)
                    TextField("Source", text: $i.source)
                    MultiLine("Notes", text: $i.notes)
                }.formStyle(.grouped)
            },
            deleteLabel: { _ in "cette inspiration" },
            filters: AnyView(Picker("", selection: $type) {
                Text("Tous types").tag("")
                ForEach(Vocab.inspiTypes, id: \.self) { Text($0).tag($0) }
            }.labelsHidden()),
            include: { [type] in type.isEmpty || $0.type == type })
    }
}

// MARK: - Samples

struct SamplesView: View {
    @EnvironmentObject var store: Store
    var body: some View {
        MasterDetail(
            title: "Samples", items: $store.data.samples,
            sort: { $0.name.lowercased() < $1.name.lowercased() },
            matches: { has($1, $0.name, $0.type, $0.source, $0.notes) },
            make: { SampleBank(id: $0, name: "Nouvelle banque") },
            row: { s in
                HStack {
                    VStack(alignment: .leading) {
                        Text(s.name)
                        Text([s.type, s.source].filter { !$0.isEmpty }.joined(separator: " · "))
                            .foregroundStyle(.secondary).azaFont(.caption)
                    }
                    Spacer()
                    if let r = s.rating, r > 0 { Text(String(repeating: "★", count: r)).foregroundStyle(.tint).azaFont(.caption) }
                }
            },
            editor: { $s in
                Form {
                    TextField("Nom", text: $s.name)
                    Picker("Type", selection: $s.type) {
                        Text("—").tag("")
                        ForEach(Vocab.sampleTypes, id: \.self) { Text($0).tag($0) }
                        if !s.type.isEmpty && !Vocab.sampleTypes.contains(s.type) { Text(s.type).tag(s.type) }
                    }
                    LabeledContent("Note") { Dots(value: $s.rating, symbol: "★") }
                    TextField("Source", text: $s.source)
                    MultiLine("Notes", text: $s.notes, minHeight: 120)
                }.formStyle(.grouped)
            },
            deleteLabel: { "« \($0.name) »" })
    }
}

// MARK: - MiRack

struct MiRackView: View {
    @EnvironmentObject var store: Store
    @Local private var onlyTodo = false
    var body: some View {
        let done = store.data.mirack.filter(\.mastered).count
        MasterDetail(
            title: "MiRack", items: $store.data.mirack,
            sort: { ($0.category, $0.name.lowercased()) < ($1.category, $1.name.lowercased()) },
            matches: { has($1, $0.name, $0.category, $0.notes) },
            make: { MiRackModule(id: $0, name: "Nouveau module") },
            row: { m in
                HStack {
                    Image(systemName: m.mastered ? "checkmark.circle.fill" : "circle").foregroundStyle(.tint)
                    VStack(alignment: .leading) {
                        Text(m.name)
                        if !m.category.isEmpty { Text(m.category).foregroundStyle(.secondary).azaFont(.caption) }
                    }
                    Spacer()
                    if m.favorite { Text("★").foregroundStyle(.tint) }
                }
            },
            editor: { $m in
                Form {
                    TextField("Nom", text: $m.name)
                    Picker("Catégorie", selection: $m.category) {
                        Text("—").tag("")
                        ForEach(Vocab.mirackCats, id: \.self) { Text($0).tag($0) }
                        if !m.category.isEmpty && !Vocab.mirackCats.contains(m.category) { Text(m.category).tag(m.category) }
                    }
                    Toggle("Maîtrisé", isOn: $m.mastered)
                    Toggle("Favori", isOn: $m.favorite)
                    MultiLine("Notes", text: $m.notes, minHeight: 140)
                }.formStyle(.grouped)
            },
            deleteLabel: { "« \($0.name) »" },
            filters: AnyView(HStack {
                Toggle("À maîtriser seulement", isOn: $onlyTodo)
                Spacer()
                Text("\(done)/\(store.data.mirack.count) maîtrisés").foregroundStyle(.secondary).azaFont(.caption)
            }),
            include: { [onlyTodo] in !onlyTodo || !$0.mastered })
    }
}

// MARK: - Wishlist

struct WishlistView: View {
    @EnvironmentObject var store: Store
    @Local private var showAcquired = false
    var body: some View {
        let open = store.data.wishlist.filter { !$0.acquired }
        let total = open.compactMap(\.price).reduce(0, +)
        MasterDetail(
            title: "Wishlist", items: $store.data.wishlist,
            sort: {
                let p = Vocab.wishlistPrios
                return (p.firstIndex(of: $0.priority) ?? 9, $0.name.lowercased()) < (p.firstIndex(of: $1.priority) ?? 9, $1.name.lowercased())
            },
            matches: { has($1, $0.name, $0.manufacturer, $0.type, $0.notes) },
            make: { WishItem(id: $0, name: "Nouvel objet") },
            row: { w in
                HStack {
                    VStack(alignment: .leading) {
                        Text([w.manufacturer, w.name].filter { !$0.isEmpty }.joined(separator: " ")).strikethrough(w.acquired)
                        Text([w.priority, w.type].filter { !$0.isEmpty }.joined(separator: " · "))
                            .foregroundStyle(.secondary).azaFont(.caption)
                    }
                    Spacer()
                    if let p = w.price { Text(p.formatted(.currency(code: "EUR"))).monospacedDigit().azaFont(.caption) }
                }
            },
            editor: { $w in
                Form {
                    TextField("Nom", text: $w.name)
                    TextField("Fabricant", text: $w.manufacturer)
                    Picker("Type", selection: $w.type) {
                        Text("—").tag("")
                        ForEach(Vocab.wishlistTypes, id: \.self) { Text($0).tag($0) }
                        if !w.type.isEmpty && !Vocab.wishlistTypes.contains(w.type) { Text(w.type).tag(w.type) }
                    }
                    Picker("Priorité", selection: $w.priority) {
                        ForEach(Vocab.wishlistPrios, id: \.self) { Text($0).tag($0) }
                    }.pickerStyle(.segmented)
                    TextField("Prix (€)", value: $w.price, format: .number)
                    HStack { TextField("Lien", text: $w.url); OpenURLButton(url: w.url) }
                    Toggle("Acquis", isOn: $w.acquired)
                    if w.acquired {
                        Button("Ajouter au catalogue") { addToCatalogue(w) }
                            .disabled(store.data.catalogue.contains { $0.name == w.name })
                    }
                    MultiLine("Notes", text: $w.notes, minHeight: 100)
                }.formStyle(.grouped)
            },
            deleteLabel: { "« \($0.name) »" },
            filters: AnyView(HStack {
                Toggle("Voir les acquis", isOn: $showAcquired)
                Spacer()
                Text("Reste : \(total.formatted(.currency(code: "EUR")))").foregroundStyle(.secondary).azaFont(.caption)
            }),
            include: { [showAcquired] in showAcquired || !$0.acquired })
    }

    func addToCatalogue(_ w: WishItem) {
        let type: String
        switch w.type {
        case "Effet hardware": type = "effet"
        case "DAW/Logiciel": type = "daw"
        default: type = "machine"
        }
        var g = GearItem(id: store.data.nextGearId(), type: type, name: w.name)
        g.manufacturer = w.manufacturer
        store.data.catalogue.append(g)
    }
}
