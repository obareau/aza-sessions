import Foundation

/// Où l'app range ses affaires.
///
/// La base et ses sauvegardes JSON sont volontairement dans DEUX dossiers
/// différents : `~/Library/Application Support` pour la base (jamais dans
/// iCloud — SQLite et la synchro de fichiers ne font pas bon ménage),
/// `~/Documents` pour les sauvegardes (vues par Time Machine, et par iCloud
/// si « Bureau et Documents » est activé). Perdre un dossier ne doit pas
/// emporter la base ET ses copies.
enum Paths {
    static let appName = "AZA Sessions"

    enum Key {
        static let backupDirectory = "BackupDirectory"
        static let serverPort = "ServerPort"
        static let pageZoom = "PageZoom"
    }

    static let defaultPort = 47017

    private static var fm: FileManager { FileManager.default }

    static var dataDirectory: URL {
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent(appName, isDirectory: true)
    }

    static var defaultBackupDirectory: URL {
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(appName, isDirectory: true)
            .appendingPathComponent("Sauvegardes", isDirectory: true)
    }

    /// Réglable : menu Fichier → « Choisir le dossier des sauvegardes… », ou
    /// `defaults write com.robotariis.aza-sessions BackupDirectory /chemin`.
    static var backupDirectory: URL {
        if let custom = UserDefaults.standard.string(forKey: Key.backupDirectory), !custom.isEmpty {
            return URL(fileURLWithPath: (custom as NSString).expandingTildeInPath, isDirectory: true)
        }
        return defaultBackupDirectory
    }

    static var logDirectory: URL {
        let lib = fm.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return lib.appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent(appName, isDirectory: true)
    }

    static var serverLog: URL { logDirectory.appendingPathComponent("serveur.log") }
    static var appLog: URL { logDirectory.appendingPathComponent("app.log") }

    static var serverExecutable: URL? {
        Bundle.main.resourceURL?
            .appendingPathComponent("aza-server", isDirectory: true)
            .appendingPathComponent("aza-server")
    }

    static var preferredPort: Int {
        let saved = UserDefaults.standard.integer(forKey: Key.serverPort)
        return saved > 0 ? saved : defaultPort
    }

    static func ensureDirectory(_ url: URL) {
        try? fm.createDirectory(at: url, withIntermediateDirectories: true)
    }
}

/// Journal de l'app elle-même (le serveur a le sien). Sert au diagnostic, et
/// à la CI qui y lit « page chargée » pour savoir que la fenêtre affiche bien
/// AZA — pas seulement que le serveur répond.
enum AppLog {
    private static let queue = DispatchQueue(label: "aza.applog")
    private static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    static func write(_ message: String) {
        let line = "\(stamp.string(from: Date())) \(message)\n"
        queue.async {
            Paths.ensureDirectory(Paths.logDirectory)
            let url = Paths.appLog
            if let handle = try? FileHandle(forWritingTo: url) {
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: Data(line.utf8))
                try? handle.close()
            } else {
                try? Data(line.utf8).write(to: url)
            }
        }
    }
}
