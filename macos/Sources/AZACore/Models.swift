import Foundation

// Le fichier JSON est la seule source de vérité de l'app native.
// Décodage tolérant : un champ absent prend sa valeur par défaut, pour qu'un
// fichier écrit par une version plus ancienne (ou à la main) s'ouvre toujours.

extension KeyedDecodingContainer {
    func v<T: Decodable>(_ key: Key, _ fallback: T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? fallback
    }
}

public enum Vocab {
    public static let characters = ["Drone", "Rythmique", "Texturé", "Mélodique", "Noise",
                                    "Ambient", "Industriel", "Génératif", "Percussif"]
    public static let modes = ["Dawless", "Hybride", "Full DAW", "iOS seul", "MiRack seul"]
    public static let intentions = ["Exploration", "B.O AZA", "Exercice technique",
                                    "Défouloir", "Jam", "Post-prod"]
    /// Types de fiche catalogue, dans l'ordre d'affichage.
    public static let itemTypes: [(key: String, label: String)] = [
        ("machine", "Hardware / Machines"), ("effet", "Effets Hardware"), ("daw", "DAW"),
        ("synth_ios", "Synthés iOS"), ("ipad", "Apps iPad"),
        ("zynthian", "Zynthian / Raspberry Pi"), ("plugin", "Plugins VST/AU"),
    ]
    public static let sessionTypes: [(key: String, label: String)] = [
        ("music", "Musique"), ("lore", "Écriture lore"), ("veille", "Veille & code"),
    ]
    public static func itemLabel(_ key: String) -> String {
        itemTypes.first { $0.key == key }?.label ?? key
    }
    public static func sessionTypeLabel(_ key: String) -> String {
        sessionTypes.first { $0.key == key }?.label ?? key
    }
}

/// Champ de séance qui reçoit des fiches catalogue d'un type donné.
public enum GearField: String, CaseIterable, Sendable {
    case machines, effects, daws, synthsIOS, ipad, zynthian, plugins

    public var catalogueType: String {
        switch self {
        case .machines: "machine"
        case .effects: "effet"
        case .daws: "daw"
        case .synthsIOS: "synth_ios"
        case .ipad: "ipad"
        case .zynthian: "zynthian"
        case .plugins: "plugin"
        }
    }
    public var label: String { Vocab.itemLabel(catalogueType) }
    public var keyPath: WritableKeyPath<Session, [String]> {
        switch self {
        case .machines: \.machines
        case .effects: \.effects
        case .daws: \.daws
        case .synthsIOS: \.synthsIOS
        case .ipad: \.ipad
        case .zynthian: \.zynthian
        case .plugins: \.plugins
        }
    }
}

public struct Session: Codable, Identifiable, Hashable, Sendable {
    public var id: Int
    public var title = ""
    public var sessionType = "music"
    /// « AAAA-MM-JJ », comme dans la base Flask.
    public var date: String
    public var durationMin: Int?
    public var mode = ""
    public var intention = ""
    public var energyLevel: Int?
    public var machines: [String] = []
    public var effects: [String] = []
    public var daws: [String] = []
    public var synthsIOS: [String] = []
    public var ipad: [String] = []
    public var zynthian: [String] = []
    public var plugins: [String] = []
    public var patches = ""
    public var audioFile = ""
    public var timestamps = ""
    public var rating: Int?
    public var tags: [String] = []
    public var character: [String] = []
    public var loreLink = ""
    public var toRework = false
    public var releasePotential = false
    public var tempo = ""
    public var tonality = ""
    public var signalRouting = ""
    public var microfreakAlgo = ""
    public var linkedSession: Int?
    public var influences: [String] = []
    public var oblique = ""
    public var comments = ""
    public var recapClaude = ""
    public var projectId: Int?
    public var createdAt: String

    public init(id: Int, date: String, createdAt: String = Clock.stamp()) {
        self.id = id
        self.date = date
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, title, sessionType, date, durationMin, mode, intention, energyLevel
        case machines, effects, daws, synthsIOS, ipad, zynthian, plugins, patches, audioFile
        case timestamps, rating, tags, character, loreLink, toRework, releasePotential
        case tempo, tonality, signalRouting, microfreakAlgo, linkedSession, influences
        case oblique, comments, recapClaude, projectId, createdAt
    }

    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        date = c.v(.date, Clock.today())
        createdAt = c.v(.createdAt, Clock.stamp())
        title = c.v(.title, ""); sessionType = c.v(.sessionType, "music")
        durationMin = c.v(.durationMin, nil); mode = c.v(.mode, ""); intention = c.v(.intention, "")
        energyLevel = c.v(.energyLevel, nil)
        machines = c.v(.machines, []); effects = c.v(.effects, []); daws = c.v(.daws, [])
        synthsIOS = c.v(.synthsIOS, []); ipad = c.v(.ipad, []); zynthian = c.v(.zynthian, [])
        plugins = c.v(.plugins, []); patches = c.v(.patches, ""); audioFile = c.v(.audioFile, "")
        timestamps = c.v(.timestamps, ""); rating = c.v(.rating, nil); tags = c.v(.tags, [])
        character = c.v(.character, []); loreLink = c.v(.loreLink, "")
        toRework = c.v(.toRework, false); releasePotential = c.v(.releasePotential, false)
        tempo = c.v(.tempo, ""); tonality = c.v(.tonality, ""); signalRouting = c.v(.signalRouting, "")
        microfreakAlgo = c.v(.microfreakAlgo, ""); linkedSession = c.v(.linkedSession, nil)
        influences = c.v(.influences, []); oblique = c.v(.oblique, ""); comments = c.v(.comments, "")
        recapClaude = c.v(.recapClaude, ""); projectId = c.v(.projectId, nil)
    }

    /// Titre affiché : le titre saisi, sinon la date et le mode.
    public var displayTitle: String {
        if !title.trimmingCharacters(in: .whitespaces).isEmpty { return title }
        return [date, mode].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    public var allGear: [String] {
        GearField.allCases.flatMap { self[keyPath: $0.keyPath] }
    }
}

public struct Project: Codable, Identifiable, Hashable, Sendable {
    public var id: Int
    public var title: String
    public var description = ""
    public var color = "#D4380D"
    public var createdAt = Clock.stamp()

    public init(id: Int, title: String) { self.id = id; self.title = title }

    enum CodingKeys: String, CodingKey { case id, title, description, color, createdAt }
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        title = c.v(.title, ""); description = c.v(.description, "")
        color = c.v(.color, "#D4380D"); createdAt = c.v(.createdAt, Clock.stamp())
    }
}

public struct GearItem: Codable, Identifiable, Hashable, Sendable {
    public var id: Int
    public var type: String
    public var name: String
    public var manufacturer = ""
    /// Code court (A-Z, 0-9) pour le nom de prise Zoom R8.
    public var code = ""
    public var purpose = ""
    public var intent = ""
    public var notes = ""
    public var controls = ""
    public var active = true
    public var favorite = false
    /// Écartée du tirage sans être désactivée.
    public var noDraw = false
    public var createdAt = Clock.stamp()

    public init(id: Int, type: String, name: String) {
        self.id = id; self.type = type; self.name = name
    }

    enum CodingKeys: String, CodingKey {
        case id, type, name, manufacturer, code, purpose, intent, notes, controls
        case active, favorite, noDraw, createdAt
    }
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        type = c.v(.type, "machine"); name = c.v(.name, "")
        manufacturer = c.v(.manufacturer, ""); code = c.v(.code, ""); purpose = c.v(.purpose, "")
        intent = c.v(.intent, ""); notes = c.v(.notes, ""); controls = c.v(.controls, "")
        active = c.v(.active, true); favorite = c.v(.favorite, false); noDraw = c.v(.noDraw, false)
        createdAt = c.v(.createdAt, Clock.stamp())
    }
}

public struct Influence: Codable, Identifiable, Hashable, Sendable {
    public var id: Int
    public var name: String
    public var type = "artiste"
    public var active = true
    public var notes = ""

    public init(id: Int, name: String) { self.id = id; self.name = name }

    enum CodingKeys: String, CodingKey { case id, name, type, active, notes }
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = c.v(.name, ""); type = c.v(.type, "artiste")
        active = c.v(.active, true); notes = c.v(.notes, "")
    }
}

public struct Oblique: Codable, Identifiable, Hashable, Sendable {
    public var id: Int
    public var text: String
    public var active = true

    public init(id: Int, text: String) { self.id = id; self.text = text }

    enum CodingKeys: String, CodingKey { case id, text, active }
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        text = c.v(.text, ""); active = c.v(.active, true)
    }
}

/// Le document entier — c'est ce qui est écrit dans le fichier JSON.
public struct AZAData: Codable, Equatable, Sendable {
    public static let currentFormat = 1

    public var format = AZAData.currentFormat
    public var sessions: [Session] = []
    public var projects: [Project] = []
    public var catalogue: [GearItem] = []
    public var influences: [Influence] = []
    public var obliques: [Oblique] = []
    public var wishlist: [WishItem] = []
    public var samples: [SampleBank] = []
    public var tracks: [InspiringTrack] = []
    public var inspirations: [Inspiration] = []
    public var mirack: [MiRackModule] = []
    public var presets: [PresetNote] = []
    public var gearPairings: [GearPairing] = []
    public var gearNotes: [GearNote] = []
    public var knobSheets: [KnobSheet] = []
    public var live: LiveSession?
    public var patches: [PatchLayout] = []

    public init() {}

    enum CodingKeys: String, CodingKey {
        case format, sessions, projects, catalogue, influences, obliques
        case wishlist, samples, tracks, inspirations, mirack, presets, gearPairings, gearNotes, knobSheets, live, patches
    }
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        format = c.v(.format, 1)
        sessions = try c.decodeIfPresent([Session].self, forKey: .sessions) ?? []
        projects = try c.decodeIfPresent([Project].self, forKey: .projects) ?? []
        catalogue = try c.decodeIfPresent([GearItem].self, forKey: .catalogue) ?? []
        influences = try c.decodeIfPresent([Influence].self, forKey: .influences) ?? []
        obliques = try c.decodeIfPresent([Oblique].self, forKey: .obliques) ?? []
        wishlist = try c.decodeIfPresent([WishItem].self, forKey: .wishlist) ?? []
        samples = try c.decodeIfPresent([SampleBank].self, forKey: .samples) ?? []
        tracks = try c.decodeIfPresent([InspiringTrack].self, forKey: .tracks) ?? []
        inspirations = try c.decodeIfPresent([Inspiration].self, forKey: .inspirations) ?? []
        mirack = try c.decodeIfPresent([MiRackModule].self, forKey: .mirack) ?? []
        presets = try c.decodeIfPresent([PresetNote].self, forKey: .presets) ?? []
        gearPairings = try c.decodeIfPresent([GearPairing].self, forKey: .gearPairings) ?? []
        gearNotes = try c.decodeIfPresent([GearNote].self, forKey: .gearNotes) ?? []
        knobSheets = try c.decodeIfPresent([KnobSheet].self, forKey: .knobSheets) ?? []
        live = try c.decodeIfPresent(LiveSession.self, forKey: .live)
        patches = try c.decodeIfPresent([PatchLayout].self, forKey: .patches) ?? []
    }
}

public enum Clock {
    static let dayFormat: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    static let stampFormat: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()
    public static func today() -> String { dayFormat.string(from: Date()) }
    public static func stamp() -> String { stampFormat.string(from: Date()) }
    public static func day(_ s: String) -> Date? { dayFormat.date(from: String(s.prefix(10))) }
    public static func day(_ d: Date) -> String { dayFormat.string(from: d) }
}
