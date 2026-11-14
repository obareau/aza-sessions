import Foundation

// Modules secondaires de l'ancien AZA : mêmes tables, mêmes champs,
// en JSON. Décodage tolérant comme dans Models.swift.

public extension Vocab {
    static let sampleTypes = ["Drums", "Percussions", "Basses", "Synthés", "Textures",
                              "Field recordings", "Loops", "Effets", "Voix", "Autre"]
    static let mirackCats = ["Oscillateur", "Filtre", "LFO", "Enveloppe", "Séquenceur",
                             "Effet", "Utilitaire", "Mixer", "Aléatoire", "Autre"]
    static let wishlistTypes = ["Synthétiseur", "Effet hardware", "DAW/Logiciel", "Contrôleur",
                                "Interface audio", "Câbles/Accessoires", "Autre"]
    static let wishlistPrios = ["Urgent", "Bientôt", "Un jour", "Rêve"]
    static let inspiTypes = ["Idée", "Phrase", "Extrait film", "Livre", "Image/Photo",
                             "Architecture", "Concept", "Autre"]
}

public struct WishItem: Codable, Identifiable, Hashable, Sendable {
    public var id: Int
    public var manufacturer = ""
    public var name: String
    public var type = ""
    public var price: Double?
    public var priority = "Un jour"
    public var notes = ""
    public var url = ""
    public var acquired = false
    public var createdAt = Clock.stamp()

    public init(id: Int, name: String) { self.id = id; self.name = name }
    enum CodingKeys: String, CodingKey { case id, manufacturer, name, type, price, priority, notes, url, acquired, createdAt }
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        manufacturer = c.v(.manufacturer, ""); name = c.v(.name, ""); type = c.v(.type, "")
        price = c.v(.price, nil); priority = c.v(.priority, "Un jour"); notes = c.v(.notes, "")
        url = c.v(.url, ""); acquired = c.v(.acquired, false); createdAt = c.v(.createdAt, Clock.stamp())
    }
}

public struct SampleBank: Codable, Identifiable, Hashable, Sendable {
    public var id: Int
    public var name: String
    public var type = ""
    public var rating: Int?
    public var source = ""
    public var notes = ""
    public var createdAt = Clock.stamp()

    public init(id: Int, name: String) { self.id = id; self.name = name }
    enum CodingKeys: String, CodingKey { case id, name, type, rating, source, notes, createdAt }
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = c.v(.name, ""); type = c.v(.type, ""); rating = c.v(.rating, nil)
        source = c.v(.source, ""); notes = c.v(.notes, ""); createdAt = c.v(.createdAt, Clock.stamp())
    }
}

public struct InspiringTrack: Codable, Identifiable, Hashable, Sendable {
    public var id: Int
    public var title: String
    public var artist = ""
    public var album = ""
    public var year = ""
    public var tags = ""
    public var notes = ""
    public var url = ""
    public var createdAt = Clock.stamp()

    public init(id: Int, title: String) { self.id = id; self.title = title }
    enum CodingKeys: String, CodingKey { case id, title, artist, album, year, tags, notes, url, createdAt }
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        title = c.v(.title, ""); artist = c.v(.artist, ""); album = c.v(.album, ""); year = c.v(.year, "")
        tags = c.v(.tags, ""); notes = c.v(.notes, ""); url = c.v(.url, "")
        createdAt = c.v(.createdAt, Clock.stamp())
    }
}

public struct Inspiration: Codable, Identifiable, Hashable, Sendable {
    public var id: Int
    public var type = "Idée"
    public var content: String
    public var source = ""
    public var notes = ""
    public var createdAt = Clock.stamp()

    public init(id: Int, content: String) { self.id = id; self.content = content }
    enum CodingKeys: String, CodingKey { case id, type, content, source, notes, createdAt }
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        type = c.v(.type, "Idée"); content = c.v(.content, ""); source = c.v(.source, "")
        notes = c.v(.notes, ""); createdAt = c.v(.createdAt, Clock.stamp())
    }
}

public struct MiRackModule: Codable, Identifiable, Hashable, Sendable {
    public var id: Int
    public var name: String
    public var category = ""
    public var mastered = false
    public var favorite = false
    public var notes = ""

    public init(id: Int, name: String) { self.id = id; self.name = name }
    enum CodingKeys: String, CodingKey { case id, name, category, mastered, favorite, notes }
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = c.v(.name, ""); category = c.v(.category, ""); mastered = c.v(.mastered, false)
        favorite = c.v(.favorite, false); notes = c.v(.notes, "")
    }
}

/// Carnet de presets : un patch remarqué sur une machine.
public struct PresetNote: Codable, Identifiable, Hashable, Sendable {
    public var id: Int
    public var date: String
    public var catalogueId: Int?
    public var presetName: String
    public var evocation = ""
    public var songIdea = ""
    public var influenceId: Int?
    public var rating: Int?
    public var tags = ""
    public var sessionId: Int?
    public var notes = ""

    public init(id: Int, date: String, presetName: String) {
        self.id = id; self.date = date; self.presetName = presetName
    }
    enum CodingKeys: String, CodingKey {
        case id, date, catalogueId, presetName, evocation, songIdea, influenceId, rating, tags, sessionId, notes
    }
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        date = c.v(.date, Clock.today()); catalogueId = c.v(.catalogueId, nil)
        presetName = c.v(.presetName, ""); evocation = c.v(.evocation, ""); songIdea = c.v(.songIdea, "")
        influenceId = c.v(.influenceId, nil); rating = c.v(.rating, nil); tags = c.v(.tags, "")
        sessionId = c.v(.sessionId, nil); notes = c.v(.notes, "")
    }
}

/// Carnet d'instrument : association stockée une fois, lue des deux côtés.
public struct GearPairing: Codable, Identifiable, Hashable, Sendable {
    public var id: Int
    public var gearId: Int
    public var partnerId: Int
    public var note = ""

    public init(id: Int, gearId: Int, partnerId: Int) { self.id = id; self.gearId = gearId; self.partnerId = partnerId }
    enum CodingKeys: String, CodingKey { case id, gearId, partnerId, note }
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        gearId = c.v(.gearId, 0); partnerId = c.v(.partnerId, 0); note = c.v(.note, "")
    }
}

/// Carnet d'instrument : remarques empilées dans le temps (un journal, pas un champ).
public struct GearNote: Codable, Identifiable, Hashable, Sendable {
    public var id: Int
    public var gearId: Int
    public var date: String
    public var note: String

    public init(id: Int, gearId: Int, date: String, note: String) {
        self.id = id; self.gearId = gearId; self.date = date; self.note = note
    }
    enum CodingKeys: String, CodingKey { case id, gearId, date, note }
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        gearId = c.v(.gearId, 0); date = c.v(.date, Clock.today()); note = c.v(.note, "")
    }
}

/// Relevé de façade. ⚠️ Une commande absente de `values` n'a pas été lue ;
/// ce n'est pas « à zéro ». Ne jamais remplir les trous par défaut.
public struct KnobSheet: Codable, Identifiable, Hashable, Sendable {
    public var id: Int
    public var gearId: Int
    public var sessionId: Int?
    public var presetId: Int?
    public var label = ""
    public var values: [String: String] = [:]
    public var notes = ""
    public var createdAt = Clock.stamp()

    public init(id: Int, gearId: Int) { self.id = id; self.gearId = gearId }
    enum CodingKeys: String, CodingKey { case id, gearId, sessionId, presetId, label, values, notes, createdAt }
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        gearId = c.v(.gearId, 0); sessionId = c.v(.sessionId, nil); presetId = c.v(.presetId, nil)
        label = c.v(.label, ""); values = c.v(.values, [:]); notes = c.v(.notes, "")
        createdAt = c.v(.createdAt, Clock.stamp())
    }
}

/// Séance en cours (0 ou 1).
public struct LiveSession: Codable, Hashable, Sendable {
    public var startedAt: String
    public var notes = ""
    public var machines: [String] = []
    public var effects: [String] = []
    public var daws: [String] = []
    public var synthsIOS: [String] = []
    public var plugins: [String] = []
    public var mode = ""
    public var intention = ""
    public var oblique = ""
    public var projectId: Int?

    public init(startedAt: String = Clock.stamp()) { self.startedAt = startedAt }
    enum CodingKeys: String, CodingKey {
        case startedAt, notes, machines, effects, daws, synthsIOS, plugins, mode, intention, oblique, projectId
    }
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        startedAt = c.v(.startedAt, Clock.stamp()); notes = c.v(.notes, "")
        machines = c.v(.machines, []); effects = c.v(.effects, []); daws = c.v(.daws, [])
        synthsIOS = c.v(.synthsIOS, []); plugins = c.v(.plugins, [])
        mode = c.v(.mode, ""); intention = c.v(.intention, ""); oblique = c.v(.oblique, "")
        projectId = c.v(.projectId, nil)
    }

    public var startDate: Date? { Clock.stampFormat.date(from: startedAt) }
}

// MARK: - Déclaration de façade (catalogue.controls)

public struct Control: Hashable, Sendable {
    public enum Kind: String, Sendable { case section, dial, `switch` }
    public var kind: Kind
    public var name: String
    public var options: [String]
}

/// `-- TITRE` = section, `Nom` = potard 0–10, `Nom: A | B | C` = sélecteur, `#` = commentaire.
public func parseControls(_ text: String) -> [Control] {
    var out: [Control] = []
    for raw in text.split(whereSeparator: \.isNewline) {
        let line = raw.trimmingCharacters(in: .whitespaces)
        if line.isEmpty || line.hasPrefix("#") { continue }
        if line.hasPrefix("--") {
            let t = line.drop { $0 == "-" }.trimmingCharacters(in: .whitespaces)
            if !t.isEmpty { out.append(Control(kind: .section, name: t, options: [])) }
            continue
        }
        if let colon = line.firstIndex(of: ":") {
            let name = line[..<colon].trimmingCharacters(in: .whitespaces)
            let opts = line[line.index(after: colon)...].split(separator: "|")
                .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            if !name.isEmpty && !opts.isEmpty {
                out.append(Control(kind: .switch, name: name, options: opts)); continue
            }
        }
        out.append(Control(kind: .dial, name: line, options: []))
    }
    return out
}
