import Foundation

// Recherche globale (⌘K) : une seule saisie pour tout AZA.
// Insensible aux accents et à la casse ; plusieurs mots = tous doivent figurer.

public struct SearchHit: Identifiable, Hashable, Sendable {
    public enum Kind: String, Sendable, CaseIterable {
        case session = "Séance", diary = "Journal", gear = "Catalogue", patch = "Patch", project = "Projet"
        case preset = "Preset", knob = "Relevé", lore = "Lore", influence = "Influence", oblique = "Stratégie"
        case track = "Morceau", inspiration = "Inspiration", sample = "Samples", mirack = "MiRack"
        case wish = "Wishlist", sysex = "SysEx"
    }
    public var id: String { "\(kind.rawValue)|\(ref)" }
    public let kind: Kind
    /// Identifiant de l'élément (ou titre pour le lore).
    public let ref: String
    public let title: String
    public let subtitle: String
    /// Passage du texte autour de ce qui a été trouvé.
    public let snippet: String
    public let score: Int
    public let date: String

    public var intRef: Int? { Int(ref) }

    public init(kind: Kind, ref: String, title: String, subtitle: String, snippet: String, score: Int, date: String) {
        self.kind = kind; self.ref = ref; self.title = title; self.subtitle = subtitle
        self.snippet = snippet; self.score = score; self.date = date
    }
}

public enum SearchText {
    /// Minuscules, sans accents ni ligatures typographiques : « Scaër » ≈ « scaer ».
    public static func fold(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: Locale(identifier: "fr_FR"))
            .replacingOccurrences(of: "œ", with: "oe").replacingOccurrences(of: "æ", with: "ae")
    }

    public static func terms(_ q: String) -> [String] {
        fold(q).split { $0.isWhitespace }.map(String.init).filter { !$0.isEmpty }
    }

    /// Extrait d'environ `width` caractères autour du premier terme trouvé dans `text`.
    public static func snippet(_ text: String, terms: [String], width: Int = 110) -> String {
        let flat = text.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        let folded = fold(flat)
        guard let t = terms.first(where: { folded.contains($0) }), let r = folded.range(of: t) else {
            return flat.count > width ? String(flat.prefix(width)) + "…" : flat
        }
        // fold() garde la longueur pour le français courant : on réutilise la position.
        let pos = folded.distance(from: folded.startIndex, to: r.lowerBound)
        var start = max(0, pos - width / 3)
        let chars = Array(flat)
        // Commencer sur un début de mot, pas au milieu.
        if start > 0 { while start < pos, chars[start - 1] != " " { start += 1 } }
        guard start < chars.count else { return String(flat.prefix(width)) }
        let end = min(chars.count, start + width)
        return (start > 0 ? "…" : "") + String(chars[start..<end]).trimmingCharacters(in: .whitespaces) + (end < chars.count ? "…" : "")
    }
}

public extension AZAData {
    /// Résultats triés par pertinence puis par date. `lore` : entrées du vault déjà lues.
    func globalSearch(_ query: String, lore: [LoreEntry] = [], limit: Int = 60) -> [SearchHit] {
        let terms = SearchText.terms(query)
        guard !terms.isEmpty else { return [] }
        var hits: [SearchHit] = []

        /// Score : tous les termes doivent figurer quelque part ; le titre compte plus.
        func consider(_ kind: SearchHit.Kind, _ ref: String, title: String, subtitle: String,
                      fields: [String], body: String = "", date: String = "") {
            let t = SearchText.fold(title)
            let rest = SearchText.fold((fields + [body]).joined(separator: " \u{1F} "))
            var score = 0
            for term in terms {
                if t.hasPrefix(term) { score += 30 }
                else if t.split(separator: " ").contains(where: { $0.hasPrefix(term) }) { score += 20 }
                else if t.contains(term) { score += 12 }
                else if rest.contains(term) { score += 4 }
                else { return }
            }
            if t == terms.joined(separator: " ") { score += 40 }
            let snip = body.isEmpty ? "" : SearchText.snippet(body, terms: terms)
            hits.append(SearchHit(kind: kind, ref: ref, title: title.isEmpty ? "—" : title, subtitle: subtitle,
                                  snippet: snip, score: score, date: date))
        }

        for s in sessions {
            consider(.session, String(s.id), title: s.displayTitle,
                     subtitle: [s.date, s.mode, project(s.projectId)?.title ?? ""].filter { !$0.isEmpty }.joined(separator: " · "),
                     fields: [s.date, s.mode, s.intention, s.audioFile, s.tempo, s.tonality, s.patches, s.signalRouting,
                              s.loreLink, s.oblique, s.microfreakAlgo] + s.allGear + s.tags + s.influences + s.character,
                     body: [s.comments, s.recapClaude].filter { !$0.isEmpty }.joined(separator: " — "), date: s.date)
        }
        for e in diary {
            consider(.diary, String(e.id), title: e.displayTitle,
                     subtitle: [e.day, e.place, e.mood.map { DiaryVocab.moods[max(0, min(6, $0 - 1))] } ?? ""]
                        .filter { !$0.isEmpty }.joined(separator: " · "),
                     fields: [e.place, e.prompt] + e.feelings + e.associations + e.loreTitles
                        + e.attachments.map(\.caption) + e.gearIds.compactMap { gear($0)?.name },
                     body: e.body, date: e.date)
        }
        for g in catalogue {
            consider(.gear, String(g.id), title: g.name,
                     subtitle: [g.manufacturer, Vocab.itemLabel(g.type), g.code].filter { !$0.isEmpty }.joined(separator: " · "),
                     fields: [g.manufacturer, g.code, g.type, g.purpose, g.intent, g.controls]
                        + gearNotes.filter { $0.gearId == g.id }.map(\.note),
                     body: g.notes)
        }
        for p in patches {
            consider(.patch, String(p.id), title: p.name, subtitle: "\(p.nodes.count) nœuds · \(p.connections.count) câbles",
                     fields: p.nodes.map(\.label) + p.nodes.map(\.note) + p.connections.map(\.label), date: p.createdAt)
        }
        for p in projects {
            consider(.project, String(p.id), title: p.title, subtitle: "\(sessions.filter { $0.projectId == p.id }.count) séance(s)",
                     fields: [], body: p.description)
        }
        for p in presets {
            consider(.preset, String(p.id), title: p.presetName,
                     subtitle: [gear(p.catalogueId)?.name ?? "", p.date].filter { !$0.isEmpty }.joined(separator: " · "),
                     fields: [p.evocation, p.songIdea, p.tags, gear(p.catalogueId)?.name ?? ""], body: p.notes, date: p.date)
        }
        for k in knobSheets {
            consider(.knob, String(k.id), title: k.label.isEmpty ? "Relevé du \(k.createdAt.prefix(10))" : k.label,
                     subtitle: gear(k.gearId)?.name ?? "", fields: Array(k.values.keys) + [gear(k.gearId)?.name ?? ""],
                     body: k.notes, date: k.createdAt)
        }
        for e in lore {
            consider(.lore, e.title, title: e.title, subtitle: [e.sectionName, e.subsection].filter { !$0.isEmpty }.joined(separator: " / "),
                     fields: e.tags, body: e.description)
        }
        for i in influences { consider(.influence, String(i.id), title: i.name, subtitle: i.type, fields: [], body: i.notes) }
        for o in obliques { consider(.oblique, String(o.id), title: o.text, subtitle: o.active ? "" : "inactive", fields: []) }
        for t in tracks {
            consider(.track, String(t.id), title: t.title, subtitle: [t.artist, t.album, t.year].filter { !$0.isEmpty }.joined(separator: " · "),
                     fields: [t.artist, t.album, t.tags], body: t.notes)
        }
        for i in inspirations { consider(.inspiration, String(i.id), title: i.content, subtitle: [i.type, i.source].filter { !$0.isEmpty }.joined(separator: " · "), fields: [i.source], body: i.notes) }
        for s in samples { consider(.sample, String(s.id), title: s.name, subtitle: s.type, fields: [s.source], body: s.notes) }
        for m in mirack { consider(.mirack, String(m.id), title: m.name, subtitle: m.category, fields: [], body: m.notes) }
        for w in wishlist {
            consider(.wish, String(w.id), title: [w.manufacturer, w.name].filter { !$0.isEmpty }.joined(separator: " "),
                     subtitle: w.priority, fields: [w.type], body: w.notes)
        }
        for b in sysexBanks { consider(.sysex, String(b.id), title: b.name, subtitle: b.format, fields: DX7.patchNames([UInt8](b.data))) }

        return Array(hits.sorted { ($0.score, $0.date) > ($1.score, $1.date) }.prefix(limit))
    }
}
