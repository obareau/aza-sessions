import CryptoKit
import Foundation

// Synchro et sauvegarde par iCloud Drive.
//
// AZA est signée ad hoc : pas de CloudKit ni de conteneur iCloud (il faudrait un
// compte développeur Apple). On s'appuie donc sur iCloud Drive comme dossier
// synchronisé par macOS — `~/Library/Mobile Documents/com~apple~CloudDocs`.

public enum CloudDrive {
    public static var root: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
    }

    public static var available: Bool {
        var dir: ObjCBool = false
        return FileManager.default.fileExists(atPath: root.path, isDirectory: &dir) && dir.boolValue
    }

    /// Dossier des données synchronisées.
    public static var dataFolder: URL { root.appendingPathComponent("AZA Sessions", isDirectory: true) }
    /// Dossier des sauvegardes quotidiennes (mode « sauvegarde seule »).
    public static var backupFolder: URL { root.appendingPathComponent("AZA Sessions — Sauvegardes", isDirectory: true) }

    public static func contains(_ url: URL) -> Bool {
        url.standardizedFileURL.path.hasPrefix(root.standardizedFileURL.path)
    }

    /// iCloud remplace un fichier non téléchargé par `.nom.icloud` (« Optimiser le stockage »).
    public static func placeholder(for url: URL) -> URL {
        url.deletingLastPathComponent().appendingPathComponent("." + url.lastPathComponent + ".icloud")
    }

    public static func isEvicted(_ url: URL) -> Bool {
        !FileManager.default.fileExists(atPath: url.path)
            && FileManager.default.fileExists(atPath: placeholder(for: url).path)
    }

    /// Copies de conflit créées par iCloud (« aza-sessions 2.json », etc.).
    public static func conflictCopies(of url: URL) -> [URL] {
        let base = url.deletingPathExtension().lastPathComponent
        let dir = url.deletingLastPathComponent()
        let items = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return items.filter {
            let n = $0.deletingPathExtension().lastPathComponent
            return $0.pathExtension == url.pathExtension && n != base && n.hasPrefix(base + " ")
                && n.dropFirst(base.count + 1).allSatisfy(\.isNumber)
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}

/// Empreinte d'un fichier, pour savoir si quelqu'un d'autre (un autre Mac) l'a modifié.
public struct FileFingerprint: Equatable, Sendable {
    public let digest: String

    public init(data: Data) { digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }

    public static func of(_ url: URL) -> FileFingerprint? {
        (try? Data(contentsOf: url)).map(FileFingerprint.init(data:))
    }
}

public enum DataFolder {
    public static let mediaName = "journal-media"

    /// Copie le JSON, les médias du journal et les sauvegardes d'un dossier vers un autre.
    /// Les médias et sauvegardes sont fusionnés (jamais écrasés) ; le JSON n'est remplacé
    /// que si `overwriteJSON`.
    public static func copy(json src: URL, to dst: URL, overwriteJSON: Bool) throws {
        let fm = FileManager.default
        let srcDir = src.deletingLastPathComponent(), dstDir = dst.deletingLastPathComponent()
        try fm.createDirectory(at: dstDir, withIntermediateDirectories: true)
        if fm.fileExists(atPath: src.path) && (overwriteJSON || !fm.fileExists(atPath: dst.path)) {
            let data = try Data(contentsOf: src)
            try data.write(to: dst, options: .atomic)
        }
        for sub in [mediaName, "backups"] {
            let a = srcDir.appendingPathComponent(sub), b = dstDir.appendingPathComponent(sub)
            guard let items = try? fm.contentsOfDirectory(at: a, includingPropertiesForKeys: nil) else { continue }
            try fm.createDirectory(at: b, withIntermediateDirectories: true)
            for f in items where !fm.fileExists(atPath: b.appendingPathComponent(f.lastPathComponent).path) {
                try fm.copyItem(at: f, to: b.appendingPathComponent(f.lastPathComponent))
            }
        }
    }
}

/// Sauvegarde quotidienne hors du Mac : un JSON par jour (30 gardés) et un miroir des médias.
public enum CloudBackup {
    public static let keepDays = 30

    public struct Result: Sendable {
        public let file: URL?
        public let mediaCopied: Int
    }

    public static func run(json: URL, media: URL, into dest: URL, keep: Int = keepDays, now: Date = Date()) throws -> Result {
        let fm = FileManager.default
        try fm.createDirectory(at: dest, withIntermediateDirectories: true)
        let current = try Data(contentsOf: json)
        var written: URL?
        // Rien de neuf depuis la dernière copie : on ne crée pas de doublon.
        if let last = list(dest).first, (try? Data(contentsOf: last)) == current {
            written = nil
        } else {
            let target = dest.appendingPathComponent("aza-sessions-\(Clock.day(now)).json")
            try current.write(to: target, options: .atomic)
            written = target
        }
        for old in list(dest).dropFirst(keep) { try? fm.removeItem(at: old) }
        var copied = 0
        if let items = try? fm.contentsOfDirectory(at: media, includingPropertiesForKeys: nil) {
            let mirror = dest.appendingPathComponent(DataFolder.mediaName)
            try fm.createDirectory(at: mirror, withIntermediateDirectories: true)
            for f in items where !fm.fileExists(atPath: mirror.appendingPathComponent(f.lastPathComponent).path) {
                try fm.copyItem(at: f, to: mirror.appendingPathComponent(f.lastPathComponent))
                copied += 1
            }
        }
        return Result(file: written, mediaCopied: copied)
    }

    /// Sauvegardes, la plus récente d'abord.
    public static func list(_ dest: URL) -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(at: dest, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.lastPathComponent.hasPrefix("aza-sessions-") && $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }
}
