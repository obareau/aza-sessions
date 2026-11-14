import Foundation

@MainActor
protocol ServerProcessDelegate: AnyObject {
    func serverDidBecomeReady(port: Int, firstLaunch: Bool)
    /// Le serveur n'a jamais été prêt (binaire absent, base verrouillée…).
    func serverDidFailToStart(message: String)
    /// Le serveur était prêt et s'est arrêté sans qu'on le lui demande.
    func serverDidStopUnexpectedly(status: Int32)
}

/// Le serveur Python embarqué (`Contents/Resources/aza-server/aza-server`).
///
/// Contrat : voir `macos/server_main.py`. On lit `AZA-READY port=N first=0|1`
/// sur la sortie standard ; on l'arrête par SIGTERM, ce qui déclenche la
/// dernière sauvegarde JSON avant sa sortie.
///
/// ⚠️ L'arrêt (`stopAndWait`) ne dépend PAS du fil principal. À la fermeture,
/// AppKit appelle `applicationShouldTerminate` depuis un bloc de la file
/// principale (le gestionnaire de SIGTERM, par exemple) : tout ce qui serait
/// renvoyé à `DispatchQueue.main` attendrait la fin de ce bloc — qui attendrait
/// le serveur. Vu en CI : serveur arrêté, app bloquée pour toujours. On attend
/// donc la fin de la sortie standard du serveur, lue sur une file à part.
@MainActor
final class ServerProcess {
    weak var delegate: ServerProcessDelegate?

    private(set) var port: Int?
    private var process: Process?
    private var stdoutClosed: DispatchSemaphore?
    private var buffer = Data()
    private var lastError: String?
    private let log = ServerLog()

    var isRunning: Bool { process != nil }

    func start() {
        guard let exe = Paths.serverExecutable,
              FileManager.default.isExecutableFile(atPath: exe.path) else {
            delegate?.serverDidFailToStart(message: "Le serveur embarqué est introuvable dans l'app.")
            return
        }
        port = nil
        lastError = nil
        buffer.removeAll()
        log.open()

        let backupDir = Paths.backupDirectory
        Paths.ensureDirectory(Paths.dataDirectory)
        Paths.ensureDirectory(backupDir)

        let p = Process()
        p.executableURL = exe
        p.arguments = [
            "--data-dir", Paths.dataDirectory.path,
            "--backup-dir", backupDir.path,
            "--port", String(Paths.preferredPort),
            "--parent-pid", String(getpid()),
        ]
        var env = ProcessInfo.processInfo.environment
        env["PYTHONUNBUFFERED"] = "1"
        env["PYTHONUTF8"] = "1"
        env["PYTHONDONTWRITEBYTECODE"] = "1"
        p.environment = env

        let out = Pipe()
        let err = Pipe()
        p.standardOutput = out
        p.standardError = err

        // Les gestionnaires tournent sur une file de FileHandle : ils écrivent
        // le journal eux-mêmes, et ne passent au fil principal que pour lire
        // les lignes du contrat (AZA-READY, AZA-ERROR).
        let log = self.log
        let closed = DispatchSemaphore(value: 0)
        stdoutClosed = closed
        out.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                closed.signal()
                return
            }
            log.write(data)
            DispatchQueue.main.async { self?.consume(data) }
        }
        err.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty { handle.readabilityHandler = nil; return }
            log.write(data)
        }
        p.terminationHandler = { [weak self] proc in
            let status = proc.terminationStatus
            DispatchQueue.main.async { self?.didTerminate(proc, status: status) }
        }

        do {
            try p.run()
            process = p
            log.write("— lancement \(exe.path) (sauvegardes → \(backupDir.path))\n")
        } catch {
            delegate?.serverDidFailToStart(message: "Lancement impossible : \(error.localizedDescription)")
        }
    }

    /// SIGTERM, puis attente de la fin du serveur (sa sortie standard se ferme
    /// quand il quitte) ; SIGKILL au bout de `timeout`. Bloque le fil appelant,
    /// au plus quelques secondes : c'est voulu, l'app est en train de fermer.
    func stopAndWait(timeout: TimeInterval = 8) {
        guard let p = process else { return }
        process = nil  // sa notification de fin, quand elle viendra, sera ignorée
        port = nil
        let pid = p.processIdentifier
        log.write("— arrêt demandé (SIGTERM)\n")
        p.terminate()
        if stdoutClosed?.wait(timeout: .now() + timeout) == .timedOut {
            log.write("— pas de réponse en \(Int(timeout)) s : arrêt forcé (SIGKILL)\n")
            kill(pid, SIGKILL)
            _ = stdoutClosed?.wait(timeout: .now() + 2)
        }
        stdoutClosed = nil
        log.write("— serveur arrêté\n")
        log.close()
    }

    /// Les dernières lignes du journal, pour les messages d'erreur.
    func logTail(lines: Int = 25) -> String {
        guard let data = try? Data(contentsOf: Paths.serverLog),
              let text = String(data: data.suffix(16_000), encoding: .utf8) else { return "" }
        return text.split(separator: "\n", omittingEmptySubsequences: false)
            .suffix(lines).joined(separator: "\n")
    }

    // MARK: - Interne

    private func consume(_ data: Data) {
        buffer.append(data)
        while let nl = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer[buffer.startIndex..<nl]
            buffer.removeSubrange(buffer.startIndex...nl)
            guard let line = String(data: lineData, encoding: .utf8) else { continue }
            handle(line: line.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private func handle(line: String) {
        if line.hasPrefix("AZA-READY") {
            var fields: [String: String] = [:]
            for part in line.split(separator: " ").dropFirst() {
                let kv = part.split(separator: "=", maxSplits: 1)
                if kv.count == 2 { fields[String(kv[0])] = String(kv[1]) }
            }
            guard let portText = fields["port"], let port = Int(portText) else { return }
            self.port = port
            // Retenir le port : le stockage local des pages (brouillons de
            // /vite…) est rangé par origine http://127.0.0.1:PORT.
            UserDefaults.standard.set(port, forKey: Paths.Key.serverPort)
            delegate?.serverDidBecomeReady(port: port, firstLaunch: fields["first"] == "1")
        } else if line.hasPrefix("AZA-ERROR") {
            let rest = line.dropFirst("AZA-ERROR".count).trimmingCharacters(in: .whitespaces)
            lastError = rest
        }
    }

    /// Fin NON demandée (plantage, base verrouillée…). Une fin demandée passe
    /// par `stopAndWait`, qui a déjà oublié ce processus.
    private func didTerminate(_ proc: Process, status: Int32) {
        guard proc === process else { return }
        process = nil
        // La sortie standard peut encore arriver APRÈS la notification de fin
        // (tampons du tube) : sans ce délai, le motif d'un échec (`AZA-ERROR …`)
        // serait perdu et l'erreur affichée deviendrait générique.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.finish(status: status)
        }
    }

    private func finish(status: Int32) {
        log.write("— serveur arrêté (code \(status))\n")
        log.close()
        if port == nil {
            delegate?.serverDidFailToStart(message: Self.explain(lastError, status: status))
        } else {
            port = nil
            delegate?.serverDidStopUnexpectedly(status: status)
        }
    }

    private static func explain(_ error: String?, status: Int32) -> String {
        guard let error = error else {
            return "Le serveur s'est arrêté au démarrage (code \(status))."
        }
        if error.hasPrefix("deja-ouvert") {
            return "Une autre copie d'AZA Sessions utilise déjà la base. Ferme-la d'abord."
        }
        return error
    }
}

/// Journal du serveur, écrit depuis n'importe quel fil (file série).
final class ServerLog: @unchecked Sendable {
    private let queue = DispatchQueue(label: "aza.serverlog")
    private var handle: FileHandle?

    func open() {
        queue.sync {
            try? handle?.close()
            Paths.ensureDirectory(Paths.logDirectory)
            let url = Paths.serverLog
            let fm = FileManager.default
            // Rotation simple : au-delà de 2 Mo, l'ancien journal devient serveur.log.1
            if let size = (try? fm.attributesOfItem(atPath: url.path))?[.size] as? NSNumber,
               size.intValue > 2_000_000 {
                let old = url.appendingPathExtension("1")
                try? fm.removeItem(at: old)
                try? fm.moveItem(at: url, to: old)
            }
            if !fm.fileExists(atPath: url.path) {
                fm.createFile(atPath: url.path, contents: nil)
            }
            handle = try? FileHandle(forWritingTo: url)
            _ = try? handle?.seekToEnd()
        }
    }

    func write(_ text: String) { write(Data(text.utf8)) }

    /// `write(contentsOf:)` et non `write(_:)` : l'ancienne méthode lève une
    /// exception Objective-C (donc plante l'app) quand le disque est plein.
    func write(_ data: Data) {
        queue.sync { try? handle?.write(contentsOf: data) }
    }

    func close() {
        queue.sync {
            try? handle?.close()
            handle = nil
        }
    }
}
