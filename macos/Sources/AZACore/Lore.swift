import Foundation

// Lecture du corpus de lore (lore/engine.py).
//
// Décision du 2026-09-27, gardée telle quelle : aucune entité n'est stockée
// dans AZA. Le vault Obsidian est la seule référence ; l'app lit l'en-tête
// (titre, description, tags) et renvoie au texte complet. Pas de vault, pas
// de page — chaque vue le dit plutôt que de faire croire que le lore a disparu.

public struct LoreEntry: Identifiable, Hashable, Sendable {
    public var id: String { section + "/" + slug }
    public let section: String
    public let sectionName: String
    /// Sous-dossier éventuel (« Majeures »), pour ne pas confondre une faction mineure avec une majeure.
    public let subsection: String
    /// Relatif au dossier de section, sans « .md ».
    public let slug: String
    public let title: String
    public let description: String
    public let tags: [String]
    public let date: String
    public let path: URL
}

public struct LoreEvent: Hashable, Sendable {
    public let era: String
    public let date: String
    public let gregorian: String
    public let event: String
}

public struct LoreQuote: Hashable, Sendable {
    public let text: String
    public let source: String
    public let entryID: String
}

public struct LoreReader: Sendable {
    /// Nom du dossier → étiquette ; ordre du `Lore/index.md` du vault.
    public static let sections: [(key: String, name: String)] = [
        ("Personnages", "Personnages"), ("Factions", "Factions"), ("Entites", "Entités"),
        ("Institutions", "Institutions"), ("Culture", "Culture"), ("Concepts", "Concepts"),
        ("Lieux", "Lieux"), ("Temps", "Temps"), ("Langages", "Langages"),
    ]
    public static let defaultRoot = "~/robotariis/PUBLICATIONS-QUARTZ"
    static let quoteRange = 40...320

    public let root: URL

    public init(path: String) {
        root = URL(fileURLWithPath: ((path.isEmpty ? Self.defaultRoot : path) as NSString).expandingTildeInPath)
    }

    var loreDir: URL { root.appendingPathComponent("Lore", isDirectory: true) }

    public var available: Bool {
        var dir: ObjCBool = false
        return FileManager.default.fileExists(atPath: loreDir.path, isDirectory: &dir) && dir.boolValue
    }

    // MARK: Texte

    /// Frontmatter YAML minimal : scalaires et listes inline (`tags: [a, b]`).
    static func frontmatter(_ text: String) -> ([String: Any], String) {
        guard text.hasPrefix("---"), let end = text.range(of: "\n---", range: text.index(text.startIndex, offsetBy: 3)..<text.endIndex) else {
            return ([:], text)
        }
        var meta: [String: Any] = [:]
        for line in text[text.index(text.startIndex, offsetBy: 3)..<end.lowerBound].split(separator: "\n") {
            guard let colon = line.firstIndex(of: ":"), !line.trimmingCharacters(in: .whitespaces).hasPrefix("#") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces)
            let val = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            if val.hasPrefix("[") && val.hasSuffix("]") {
                meta[key] = val.dropFirst().dropLast().split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            } else {
                meta[key] = val
            }
        }
        let bodyStart = text.index(end.lowerBound, offsetBy: 4, limitedBy: text.endIndex) ?? text.endIndex
        return (meta, String(text[bodyStart...]))
    }

    /// `[[cible|libellé]]` → `libellé`, `[[cible]]` → `cible`. Avant tout découpage de tableau :
    /// la barre d'un wikilink est aussi le séparateur de cellule.
    static func wikilinks(_ s: String) -> String {
        s.replacingOccurrences(of: #"\[\[([^\]|]+)\|([^\]]+)\]\]"#, with: "$2", options: .regularExpression)
            .replacingOccurrences(of: #"\[\[([^\]]+)\]\]"#, with: "$1", options: .regularExpression)
    }

    static func clean(_ s: String) -> String {
        wikilinks(s)
            .replacingOccurrences(of: #"\[([^\]]+)\]\([^)]+\)"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"[*_`]{1,3}"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    static func firstParagraph(_ body: String) -> String {
        for raw in body.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || ["#", "|", ">", "-", "*", "!"].contains(where: { line.hasPrefix($0) }) { continue }
            let t = clean(line)
            if t.count > 25 { return String(t.prefix(300)) }
        }
        return ""
    }

    // MARK: Entrées

    func read(section: String, slug: String) -> LoreEntry? {
        let url = loreDir.appendingPathComponent(section).appendingPathComponent(slug + ".md")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let (meta, body) = Self.frontmatter(text)
        var title = meta["title"] as? String ?? ""
        if title.isEmpty, let h = body.split(separator: "\n").first(where: { $0.hasPrefix("# ") }) {
            title = Self.clean(String(h.dropFirst(2)))
        }
        if title.isEmpty {
            title = (slug as NSString).lastPathComponent.replacingOccurrences(of: "-", with: " ").capitalized
        }
        let desc = (meta["description"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? Self.firstParagraph(body)
        return LoreEntry(section: section,
                         sectionName: Self.sections.first { $0.key == section }?.name ?? section,
                         subsection: (slug as NSString).deletingLastPathComponent.replacingOccurrences(of: "/", with: " / "),
                         slug: slug, title: title, description: desc,
                         tags: meta["tags"] as? [String] ?? [], date: meta["date"] as? String ?? "", path: url)
    }

    /// Entrées d'une section, sous-dossiers compris (les Factions sont rangées en Majeures / Mineures…).
    public func entries(_ section: String) -> [LoreEntry] {
        guard available, Self.sections.contains(where: { $0.key == section }) else { return [] }
        let base = loreDir.appendingPathComponent(section, isDirectory: true)
        guard let e = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else { return [] }
        var slugs: [String] = []
        // /tmp ↔ /private/tmp, ~ via un lien… : comparer des chemins résolus des deux côtés.
        let prefix = base.resolvingSymlinksInPath().path + "/"
        for case let url as URL in e where url.pathExtension == "md" {
            let name = url.deletingPathExtension().lastPathComponent
            guard name != "index", !name.hasPrefix("._") else { continue }
            let full = url.resolvingSymlinksInPath().path
            if full.hasPrefix(prefix) { slugs.append(String(full.dropFirst(prefix.count).dropLast(3))) }
        }
        return slugs.sorted().compactMap { read(section: section, slug: $0) }
            .sorted { $0.title.lowercased() < $1.title.lowercased() }
    }

    public func all() -> [LoreEntry] { Self.sections.flatMap { entries($0.key) } }

    public static func search(_ entries: [LoreEntry], _ q: String) -> [LoreEntry] {
        let q = q.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        return entries.filter {
            $0.title.lowercased().contains(q) || $0.description.lowercased().contains(q)
                || $0.tags.contains { $0.lowercased().contains(q) }
        }
    }

    // MARK: Chronologie — l'ordre du fichier EST l'ordre narratif

    public func timeline() -> [LoreEvent] {
        let url = loreDir.appendingPathComponent("Temps/timeline.md")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        let (_, body) = Self.frontmatter(text)
        var out: [LoreEvent] = [], era = ""
        for raw in body.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: CharacterSet(charactersIn: " \t\r"))
            if line.hasPrefix("#") {
                era = Self.clean(String(line.drop { $0 == "#" || $0 == " " })); continue
            }
            guard line.hasPrefix("|") else { continue }
            let cells = Self.wikilinks(line).trimmingCharacters(in: CharacterSet(charactersIn: "|"))
                .components(separatedBy: "|").map(Self.clean)
            guard cells.count >= 3 else { continue }
            let first = cells[0]
            if first.lowercased() == "date" || first.isEmpty || Set(first).isSubset(of: ["-", ":"]) { continue }
            out.append(LoreEvent(era: era, date: first, gregorian: cells[1], event: cells[2]))
        }
        return out
    }

    // MARK: Citations — ses mots, pas une notice

    public func quotes(in entries: [LoreEntry]? = nil) -> [LoreQuote] {
        guard available else { return [] }
        var out: [LoreQuote] = [], seen = Set<String>()
        for e in entries ?? all() {
            guard let text = try? String(contentsOf: e.path, encoding: .utf8) else { continue }
            for line in text.components(separatedBy: "\n") where line.hasPrefix("> ") {
                let t = Self.clean(String(line.dropFirst(2)))
                guard !t.hasPrefix("Définition"), Self.quoteRange.contains(t.count), seen.insert(t).inserted else { continue }
                out.append(LoreQuote(text: t, source: e.title, entryID: e.id))
            }
        }
        return out
    }
}
