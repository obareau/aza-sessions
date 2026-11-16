import Foundation

// Journal personnel — l'équivalent de l'app Journal d'Apple, dans l'univers AZA.
//
// Les textes, humeurs et liens vivent dans le JSON ; les médias (photos, sons)
// sont des fichiers dans `journal-media/`, à côté du JSON : les mettre en base64
// ferait gonfler le fichier et ralentirait chaque sauvegarde.

public enum DiaryVocab {
    /// Échelle d'état d'esprit en 7 crans, comme « State of Mind ».
    public static let moods = ["Très désagréable", "Désagréable", "Plutôt désagréable", "Neutre",
                               "Plutôt agréable", "Agréable", "Très agréable"]
    public static let moodSymbols = ["◼︎", "◾︎", "▪︎", "◇", "▫︎", "◽︎", "◻︎"]
    public static let feelings = ["Calme", "Concentré", "Inspiré", "Curieux", "Euphorique", "Reconnaissant",
                                  "Fatigué", "Mélancolique", "Inquiet", "Frustré", "Vide", "Submergé"]
    public static let associations = ["Musique", "Lore", "Matériel", "Écriture", "Travail", "Santé",
                                      "Famille", "Amis", "Nature", "Sommeil", "Scaër", "Actualité"]
}

public struct DiaryAttachment: Codable, Identifiable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable { case image, audio, file }
    public var id: String
    public var kind: Kind
    /// Nom du fichier dans `journal-media/`.
    public var file: String
    public var caption = ""

    public init(id: String = UUID().uuidString, kind: Kind, file: String) {
        self.id = id; self.kind = kind; self.file = file
    }
    enum CodingKeys: String, CodingKey { case id, kind, file, caption }
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = c.v(.id, UUID().uuidString); kind = c.v(.kind, .file); file = c.v(.file, ""); caption = c.v(.caption, "")
    }

    public static func kind(forExtension ext: String) -> Kind {
        let e = ext.lowercased()
        if ["jpg", "jpeg", "png", "heic", "heif", "gif", "tiff", "tif", "webp", "bmp"].contains(e) { return .image }
        if ["m4a", "mp3", "wav", "aif", "aiff", "caf", "flac", "aac", "ogg"].contains(e) { return .audio }
        return .file
    }
}

public struct DiaryEntry: Codable, Identifiable, Hashable, Sendable {
    public var id: Int
    /// « AAAA-MM-JJ HH:MM:SS » — la date de l'entrée, modifiable (on écrit souvent après coup).
    public var date: String
    public var title = ""
    public var body = ""
    /// 1 (très désagréable) … 7 (très agréable) ; nil = non renseigné.
    public var mood: Int?
    public var feelings: [String] = []
    public var associations: [String] = []
    public var place = ""
    public var bookmarked = false
    /// La suggestion d'écriture d'où vient l'entrée, gardée en exergue.
    public var prompt = ""
    public var attachments: [DiaryAttachment] = []
    public var sessionIds: [Int] = []
    public var gearIds: [Int] = []
    public var patchIds: [Int] = []
    public var loreTitles: [String] = []
    public var updatedAt = Clock.stamp()

    public init(id: Int, date: String = Clock.stamp()) { self.id = id; self.date = date }

    enum CodingKeys: String, CodingKey {
        case id, date, title, body, mood, feelings, associations, place, bookmarked, prompt, attachments
        case sessionIds, gearIds, patchIds, loreTitles, updatedAt
    }
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        date = c.v(.date, Clock.stamp()); title = c.v(.title, ""); body = c.v(.body, ""); mood = c.v(.mood, nil)
        feelings = c.v(.feelings, []); associations = c.v(.associations, []); place = c.v(.place, "")
        bookmarked = c.v(.bookmarked, false); prompt = c.v(.prompt, ""); attachments = c.v(.attachments, [])
        sessionIds = c.v(.sessionIds, []); gearIds = c.v(.gearIds, []); patchIds = c.v(.patchIds, [])
        loreTitles = c.v(.loreTitles, []); updatedAt = c.v(.updatedAt, Clock.stamp())
    }

    public var day: String { String(date.prefix(10)) }
    public var wordCount: Int { body.split { $0.isWhitespace || $0.isNewline }.count }

    /// Titre affiché : le titre, sinon la première ligne du texte, sinon la date.
    public var displayTitle: String {
        if !title.trimmingCharacters(in: .whitespaces).isEmpty { return title }
        if let line = body.split(separator: "\n").first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            let t = line.trimmingCharacters(in: CharacterSet(charactersIn: "#*> ").union(.whitespaces))
            return t.count > 60 ? String(t.prefix(60)) + "…" : t
        }
        return "Entrée du \(day)"
    }

    /// Le texte sans sa première ligne quand elle sert déjà de titre — pour l'aperçu.
    public var excerpt: String {
        var lines = body.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        if title.trimmingCharacters(in: .whitespaces).isEmpty, !lines.isEmpty { lines.removeFirst() }
        let t = lines.joined(separator: " ").replacingOccurrences(of: #"[#*_>`]"#, with: "", options: .regularExpression)
        return t.count > 220 ? String(t.prefix(220)) + "…" : t
    }

    public var hasLinks: Bool { !sessionIds.isEmpty || !gearIds.isEmpty || !patchIds.isEmpty || !loreTitles.isEmpty }
}

// MARK: - Suggestions d'écriture (les « réflexions » et « moments » de Journal)

public struct DiaryPrompt: Identifiable, Hashable, Sendable {
    public var id: String { kind + "|" + text }
    public let kind: String
    public let icon: String
    public let text: String
    /// Ce que l'entrée créée reprend : séance, fiche, patch liés.
    public var sessionId: Int?
    public var gearId: Int?
    public var patchId: Int?
    public var lore: String?
}

public extension AZAData {
    static let reflections = [
        "Quel son t'a surpris cette semaine ?",
        "Qu'est-ce qui t'empêche de jouer en ce moment ?",
        "Décris l'endroit où tu joues, tel qu'il est ce soir.",
        "Quelle machine aimerais-tu comprendre mieux, et pourquoi ?",
        "Quel morceau t'a accompagné aujourd'hui ?",
        "Qu'as-tu abandonné en cours de route, et qu'en reste-t-il ?",
        "Si la Rectitude écoutait ta dernière séance, qu'entendrait-elle ?",
        "Qu'est-ce qui t'a donné envie de créer aujourd'hui ?",
        "Raconte un silence que tu as remarqué.",
        "De quoi as-tu besoin pour la prochaine séance ?",
        "Quel détail de Scaër aimerais-tu garder en mémoire ?",
        "Pour quoi es-tu reconnaissant aujourd'hui ?",
    ]

    /// Suggestions tirées de ce que tu as fait récemment et de l'univers AZA.
    func diaryPrompts(today: Date = Date(), lore: [String] = []) -> [DiaryPrompt] {
        var out: [DiaryPrompt] = []
        let cal = Calendar(identifier: .gregorian)
        let weekAgo = Clock.day(cal.date(byAdding: .day, value: -7, to: today)!)
        let written = Set(diary.flatMap(\.sessionIds))
        // Moments : les séances récentes dont on n'a pas encore parlé.
        for s in sessions.filter({ $0.date >= weekAgo && !written.contains($0.id) })
            .sorted(by: { $0.date > $1.date }).prefix(3) {
            out.append(DiaryPrompt(kind: "Séance récente", icon: "waveform",
                                   text: "Qu'as-tu retenu de « \(s.displayTitle) » (\(s.date)) ?", sessionId: s.id))
        }
        if let p = presets.filter({ $0.date >= weekAgo }).sorted(by: { $0.date > $1.date }).first {
            out.append(DiaryPrompt(kind: "Preset noté", icon: "slider.horizontal.3",
                                   text: "« \(p.presetName) » : qu'évoque ce son pour toi ?", gearId: p.catalogueId))
        }
        if let g = catalogue.filter({ $0.active && $0.favorite }).randomElement() {
            out.append(DiaryPrompt(kind: "Instrument", icon: "pianokeys",
                                   text: "Ta relation avec \(g.name), aujourd'hui.", gearId: g.id))
        }
        if let p = patches.max(by: { $0.createdAt < $1.createdAt }) {
            out.append(DiaryPrompt(kind: "Patch", icon: "point.3.connected.trianglepath.dotted",
                                   text: "Pourquoi cette chaîne, « \(p.name) » ?", patchId: p.id))
        }
        if let o = randomOblique() {
            out.append(DiaryPrompt(kind: "Stratégie oblique", icon: "suit.diamond", text: o))
        }
        if let i = inspirations.randomElement() {
            out.append(DiaryPrompt(kind: "Inspiration", icon: "lightbulb", text: "« \(i.content) » — et toi ?"))
        }
        if let q = lore.randomElement() {
            out.append(DiaryPrompt(kind: "Lore", icon: "book.closed", text: q, lore: q))
        }
        for r in Self.reflections.shuffled().prefix(3) {
            out.append(DiaryPrompt(kind: "Réflexion", icon: "sparkles", text: r))
        }
        return out
    }

    // MARK: Aperçu (« Insights »)

    struct DiaryInsights: Sendable {
        public var streak = 0
        public var longestStreak = 0
        public var entriesThisYear = 0
        public var wordsThisYear = 0
        public var daysThisYear = 0
        public var moodAverage: Double?
        public var feelings: [(String, Int)] = []
    }

    func diaryInsights(today: Date = Date()) -> DiaryInsights {
        var ins = DiaryInsights()
        let cal = Calendar(identifier: .gregorian)
        let days = Set(diary.map(\.day))
        let start = cal.startOfDay(for: today)
        var d = days.contains(Clock.day(start)) ? start : cal.date(byAdding: .day, value: -1, to: start)!
        while days.contains(Clock.day(d)) { ins.streak += 1; d = cal.date(byAdding: .day, value: -1, to: d)! }
        var run = 0, prev: Date?
        for day in days.sorted().compactMap({ Clock.day($0) }) {
            if let p = prev, cal.dateComponents([.day], from: p, to: day).day == 1 { run += 1 } else { run = 1 }
            ins.longestStreak = max(ins.longestStreak, run); prev = day
        }
        let year = String(Clock.day(today).prefix(4))
        let thisYear = diary.filter { $0.date.hasPrefix(year) }
        ins.entriesThisYear = thisYear.count
        ins.wordsThisYear = thisYear.map(\.wordCount).reduce(0, +)
        ins.daysThisYear = Set(thisYear.map(\.day)).count
        let moods = diary.compactMap(\.mood)
        ins.moodAverage = moods.isEmpty ? nil : Double(moods.reduce(0, +)) / Double(moods.count)
        ins.feelings = Dictionary(diary.flatMap(\.feelings).map { ($0, 1) }, uniquingKeysWith: +)
            .sorted { ($0.value, $1.key) > ($1.value, $0.key) }.prefix(6).map { ($0.key, $0.value) }
        return ins
    }

    // MARK: Recherche

    func diarySearch(_ q: String) -> [DiaryEntry] {
        let q = q.trimmingCharacters(in: .whitespaces).lowercased()
        let sorted = diary.sorted { ($0.date, $0.id) > ($1.date, $1.id) }
        guard !q.isEmpty else { return sorted }
        return sorted.filter { e in
            var hay = [e.title, e.body, e.place, e.prompt] + e.feelings + e.associations + e.loreTitles
            hay += e.sessionIds.compactMap { id in sessions.first { $0.id == id }?.displayTitle }
            hay += e.gearIds.compactMap { gear($0)?.name }
            return hay.joined(separator: " ").lowercased().contains(q)
        }
    }

    // MARK: Export Markdown (Obsidian)

    func diaryMarkdown(_ e: DiaryEntry) -> String {
        var fm = ["---", "date: \(e.date)"]
        if let m = e.mood { fm.append("humeur: \(m)  # \(DiaryVocab.moods[max(0, min(6, m - 1))])") }
        if !e.feelings.isEmpty { fm.append("ressentis: [\(e.feelings.joined(separator: ", "))]") }
        if !e.associations.isEmpty { fm.append("tags: [\(e.associations.map { $0.lowercased() }.joined(separator: ", "))]") }
        if !e.place.isEmpty { fm.append("lieu: \(e.place)") }
        if e.bookmarked { fm.append("signet: true") }
        fm.append("---")
        var out = fm.joined(separator: "\n") + "\n\n# \(e.displayTitle)\n\n"
        if !e.prompt.isEmpty { out += "> \(e.prompt)\n\n" }
        out += e.body + "\n"
        let links = e.sessionIds.compactMap { id in sessions.first { $0.id == id }.map { "- Séance : [[\(AZAData.obsidianFileName($0).dropLast(3))|\($0.displayTitle)]]" } }
            + e.gearIds.compactMap { gear($0).map { "- Matériel : \($0.name)" } }
            + e.patchIds.compactMap { id in patches.first { $0.id == id }.map { "- Patch : \($0.name)" } }
            + e.loreTitles.map { "- Lore : [[\($0)]]" }
        if !links.isEmpty { out += "\n## Liens\n" + links.joined(separator: "\n") + "\n" }
        if !e.attachments.isEmpty {
            out += "\n## Médias\n" + e.attachments.map { "- ![[\($0.file)]]" + ($0.caption.isEmpty ? "" : " — \($0.caption)") }.joined(separator: "\n") + "\n"
        }
        return out
    }

    static func diaryFileName(_ e: DiaryEntry) -> String {
        "journal_\(e.day.replacingOccurrences(of: "-", with: ""))_\(e.id).md"
    }
}
