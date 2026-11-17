import AZACore
import SwiftUI

/// Séance rapide (/vite) : un texte, et c'est tout.
///
/// Le formulaire complet compte une quarantaine de champs : trop quand la
/// fatigue tombe d'un coup. Seul le texte est obligatoire, la date est celle du
/// jour, la création est instantanée (pas de récap à attendre) ; le reste se
/// complète plus tard — ou jamais.
struct QuickSessionSheet: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @EnvironmentObject var prefs: Prefs
    var preselection: [String] = []
    let close: () -> Void

    @Local private var text = ""
    @Local private var title = ""
    @Local private var type = "music"
    @Local private var chosen: Set<String> = []
    @Local private var extra = ""
    @Local private var titles: [String] = Titles.propose(5)
    @Local private var ready = false

    static let fields: [GearField] = [.machines, .effects, .synthsIOS, .plugins]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SÉANCE RAPIDE").azaHeading(.headline)
                Spacer()
                Picker("", selection: $type) {
                    ForEach(Vocab.sessionTypes, id: \.key) { Text($0.label).tag($0.key) }
                }.labelsHidden().frame(width: 170)
            }
            TextEditor(text: $text)
                .azaFont(.body, mono: true)
                .frame(minHeight: 140)
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color(nsColor: .textBackgroundColor)))
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Ce qui s'est passé…").foregroundStyle(.tertiary).padding(8).allowsHitTesting(false)
                    }
                }
            HStack {
                TextField("Titre (facultatif)", text: $title)
                Menu {
                    ForEach(titles, id: \.self) { t in Button(t) { title = t } }
                    Divider()
                    Button("Autres propositions") { titles = Titles.propose(5) }
                } label: { Image(systemName: "wand.and.stars") }
                    .menuStyle(.borderlessButton).frame(width: 36)
            }
            if type == "music" {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Self.fields, id: \.self) { f in
                            let items = store.data.catalogue.filter { $0.type == f.catalogueType && $0.active }
                                .sorted { ($0.favorite ? 0 : 1, $0.name.lowercased()) < ($1.favorite ? 0 : 1, $1.name.lowercased()) }
                            if !items.isEmpty {
                                Text(f.label.uppercased()).foregroundStyle(.secondary).azaFont(.caption2, mono: true)
                                FlowToggles(options: items.map(\.name), values: Binding(
                                    get: { items.map(\.name).filter(chosen.contains) },
                                    set: { new in
                                        for n in items.map(\.name) { chosen.remove(n) }
                                        chosen.formUnion(new)
                                    }))
                            }
                        }
                    }
                }
                .frame(maxHeight: 220)
                TextField("Autre matériel (hors catalogue, séparé par des virgules)", text: $extra)
                let take = previewTake
                Text(take.isEmpty ? "Nom de prise : — (aucune fiche choisie n'a de code)" : "Nom de prise : \(take)")
                    .foregroundStyle(.secondary).azaFont(.caption, mono: true)
            }
            HStack {
                Text("Le reste se complète plus tard.").foregroundStyle(.secondary).azaFont(.caption)
                Spacer()
                Button("Annuler", action: close).keyboardShortcut(.cancelAction)
                Button("Enregistrer") { save() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 620)
        .onAppear { if !ready { chosen = Set(preselection); ready = true } }
    }

    var draft: Session {
        var s = Session(id: store.data.nextSessionId(), date: Clock.today())
        s.sessionType = type
        s.title = title.trimmingCharacters(in: .whitespaces)
        s.comments = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if type == "music" {
            for f in Self.fields {
                let names = store.data.catalogue.filter { $0.type == f.catalogueType && chosen.contains($0.name) }.map(\.name)
                s[keyPath: f.keyPath] = names
            }
            s.machines += splitList(extra)
            // Une fiche choisie par preselection mais d'un type non listé reste dans machines.
            let known = Set(Self.fields.flatMap { s[keyPath: $0.keyPath] })
            s.machines += chosen.filter { !known.contains($0) }.sorted()
        }
        return s
    }

    var previewTake: String { store.data.takeName(for: draft) }

    func save() {
        var s = draft
        s.audioFile = store.data.takeName(for: s)
        store.data.sessions.append(s)
        close()
        nav.open(session: s.id)
    }
}

/// Aide des raccourcis clavier (le « ? » de l'app web).
struct ShortcutsHelp: View {
    let close: () -> Void
    static let groups: [(String, [(String, String)])] = [
        ("Séances", [("Nouvelle séance", "⌘N"), ("Séance rapide", "⇧⌘N"), ("Copier le setup", "⌘D"),
                     ("Séance en cours", "⇧⌘L"), ("Ce soir — tirage", "⇧⌘T"), ("Enregistrer maintenant", "⌘S")]),
        ("Navigation", [("Rechercher partout", "⌘K"), ("Historique et restauration", "⇧⌘Y"), ("Annuler / rétablir", "⌘Z / ⇧⌘Z"), ("Patcher", "⇧⌘P"), ("Mode focus (masquer la barre latérale)", "⌃⌘S"),
                        ("Réglages", "⌘,"), ("Afficher le fichier JSON", "⇧⌘R"), ("Exporter en JSON", "⇧⌘E")]),
        ("Texte", [("Agrandir / réduire", "⌘+ / ⌘−"), ("Taille réelle", "⌘0")]),
        ("Patcher", [("Basculer déplacer / câbler", "C"), ("Grille magnétique", "G"), ("Minimap", "M"),
                     ("Panneau catalogue", "K"), ("Tout afficher", "F"), ("Supprimer la sélection", "⌘⌫"),
                     ("Annuler la sélection", "Échap")]),
        ("Ce soir · Spark · Obliques", [("Nouveau tirage / suivante", "Espace")]),
        ("Impression", [("Imprimer depuis l'aperçu", "⌘P")]),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("⌨ RACCOURCIS CLAVIER").azaHeading(.headline)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Self.groups, id: \.0) { g in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(g.0.uppercased()).foregroundStyle(.secondary).azaFont(.caption2, mono: true)
                            ForEach(g.1, id: \.0) { row in
                                HStack {
                                    Text(row.0)
                                    Spacer()
                                    Text(row.1).azaFont(.body, mono: true)
                                        .padding(.horizontal, 6).padding(.vertical, 1)
                                        .background(RoundedRectangle(cornerRadius: 3).stroke(Color.secondary.opacity(0.5)))
                                }
                            }
                        }
                    }
                }
            }
            HStack { Spacer(); Button("Fermer", action: close).keyboardShortcut(.cancelAction) }
        }
        .padding(18)
        .frame(width: 460, height: 560)
    }
}
