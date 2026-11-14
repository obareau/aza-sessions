import Foundation

/// Lecture / écriture du fichier JSON, avec la même politique de sauvegarde
/// que `core/backup.py` : 5 copies datées, et pas de copie si rien n'a changé
/// depuis la dernière (sinon des ouvertures répétées évideraient la rétention).
public struct JSONStorage: Sendable {
    public let url: URL
    public var backupCount = 5

    public init(url: URL) { self.url = url }

    public static var defaultURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("AZA Sessions", isDirectory: true)
            .appendingPathComponent("aza-sessions.json")
    }

    public var backupDir: URL {
        url.deletingLastPathComponent().appendingPathComponent("backups", isDirectory: true)
    }

    public static func encode(_ data: AZAData) throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try enc.encode(data)
    }

    public static func decode(_ raw: Data) throws -> AZAData {
        try JSONDecoder().decode(AZAData.self, from: raw)
    }

    /// `nil` si le fichier n'existe pas encore.
    public func load() throws -> AZAData? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try Self.decode(Data(contentsOf: url))
    }

    /// Écriture atomique : un plantage en cours d'écriture laisse l'ancien fichier intact.
    public func save(_ data: AZAData) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try Self.encode(data).write(to: url, options: .atomic)
    }

    /// Copie datée du fichier courant. Retourne l'URL créée, ou nil si sautée.
    @discardableResult
    public func backup(now: Date = Date()) throws -> URL? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return nil }
        try fm.createDirectory(at: backupDir, withIntermediateDirectories: true)
        let current = try Data(contentsOf: url)
        let existing = try backups()
        if let last = existing.first, (try? Data(contentsOf: last)) == current { return nil }

        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmmss"
        var dest = backupDir.appendingPathComponent("aza-sessions-\(f.string(from: now)).json")
        var n = 2
        while fm.fileExists(atPath: dest.path) {
            dest = backupDir.appendingPathComponent("aza-sessions-\(f.string(from: now))-\(n).json")
            n += 1
        }
        try current.write(to: dest, options: .atomic)
        for old in try backups().dropFirst(backupCount) { try? fm.removeItem(at: old) }
        return dest
    }

    /// Sauvegardes, la plus récente d'abord.
    public func backups() throws -> [URL] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: backupDir.path) else { return [] }
        return try fm.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("aza-sessions-") && $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }
}

public enum Seed {
    public static let obliques = [
        "La machine ne ment pas. Elle déforme.",
        "Supprime une fréquence. Laisse le silence parler.",
        "Joue comme si les circuits étaient fatigués.",
        "Le bruit est une information que tu n'as pas encore comprise.",
        "Répète jusqu'à ce que la répétition devienne quelque chose d'autre.",
        "Inverse le signal. Écoute ce qui était caché.",
        "Les AZA ne rêvent pas. Ils calculent l'absence.",
        "Retire un élément. Que reste-t-il ?",
        "Le glitch n'est pas une erreur. C'est une vérité accidentelle.",
        "Joue plus lentement que tu ne le penses nécessaire.",
        "Distords jusqu'à l'os. Puis encore un peu.",
        "Qu'est-ce que cette machine voudrait dire si elle pouvait ?",
        "Le silence entre les sons est aussi une composition.",
        "Enregistre d'abord. Écoute après.",
        "La mémoire des machines ne s'efface jamais vraiment.",
        "Travaille avec ce que tu as, pas avec ce que tu voudrais avoir.",
        "Un seul paramètre. Pousse-le à l'extrême.",
        "Les AZA parlent en fréquences que les humains ont oublié d'entendre.",
        "Ce qui semble cassé est peut-être parfait.",
        "Ferme les yeux. Écoute ce que le setup dit sans toi.",
        "La contrainte est une forme de liberté.",
        "Commence par la fin.",
        "Le drone est une prière que la machine adresse au vide.",
        "Moins de sources. Plus de profondeur.",
        "Ce pattern que tu répètes depuis une heure — c'est peut-être ça, le morceau.",
    ]

    public static let items: [(String, [String])] = [
        ("machine", ["MicroFreak", "NTS-1", "Volca Drum", "Volca Kick", "Launchpad Pro mk3",
                     "MacBook Intel (instrument)", "Mac M4", "iPad/iPhone", "PC Windows",
                     "Zoom R8", "Zoom H4n", "BCD 3000", "Behringer Uphoria 1820",
                     "Audient ID4 mk2", "CME WIDI Pro"]),
        ("effet", ["NTS-1 (effets)", "Sonicake Smartbox", "Korg Pandora PX Mini",
                   "Zoom R8 (effets)", "Zoom H4n (effets)"]),
        ("daw", ["Ableton Live", "Logic Pro", "MainStage"]),
        ("synth_ios", ["Tera Pro", "MiRack", "Condukt", "Stepolyarp", "Peach", "Seqnd",
                       "Blue Arp", "LK for Live"]),
        ("plugin", ["Kilohearts Suite", "Baby Audio Tekno", "VCV Rack",
                    "Arturia MiniFreak V", "Arturia Analog Lab"]),
    ]

    public static let influences = [
        "PanSonic", "Vromb", "Synapscape", "P·A·L", "Converter", "Raison d'Être", "Lustmord",
        "Alva Noto", "Fennesz", "Monolake", "Actress", "Esplendor Geométrico", "Noisex",
        "Hands Productions", "Ant-Zen", "Culture of Violence",
    ]

    public static func initial() -> AZAData {
        var d = AZAData()
        d.obliques = obliques.enumerated().map { Oblique(id: $0.offset + 1, text: $0.element) }
        var id = 1
        for (type, names) in items {
            for n in names { d.catalogue.append(GearItem(id: id, type: type, name: n)); id += 1 }
        }
        d.influences = influences.enumerated().map { Influence(id: $0.offset + 1, name: $0.element) }
        return d
    }
}
