import Foundation

// MARK: - Récap IA (core/ollama_client.py)
//
// ⚠️ Leçon de l'app web : un appel LLM qui échoue sans bruit ne se voit jamais
// depuis l'interface (le récap est resté mort des semaines avec un modèle
// inexistant). Ici chaque échec remonte un message lisible.

public enum Recap {
    public static let defaultURL = "http://192.168.1.100:11434"
    public static let defaultModel = "qwen3.5:cloud"

    static let music = """
    Tu es un archiviste de l'univers AZA — une dystopie sonore Dark Ambient / Industriel, Scaër, Bretagne.
    Rédige un récit de session en français, entre 80 et 150 mots, à la première personne, dans un style sombre, concis et atmosphérique.
    Ne mentionne pas de prix, de marques commerciales de manière promotionnelle, ni de termes techniques comme "BPM" ou "plugin".
    Intègre naturellement les éléments fournis sans les lister.

    Données de session :
    - Durée : {duration_min} min
    - Mode : {mode}
    - Intention : {intention}
    - Machines : {machines}
    - Effets : {effects}
    - DAW : {daws}
    - Synthés iOS : {synths_ios}
    - Plugins : {plugins}
    - Stratégie oblique : {oblique}
    - Notes live : {notes_live}

    Récit :
    """

    static let lore = """
    Tu es un archiviste de l'univers AZA — une dystopie Dark Ambient / Industriel, Scaër, Bretagne.
    Rédige un court récit de session d'écriture du lore, en français, entre 80 et 150 mots, à la première personne,
    dans un style sombre et atmosphérique. Synthétise ce qui a été écrit/exploré sans tout lister.

    Données de session :
    - Durée : {duration_min} min
    - Intention : {intention}
    - Stratégie oblique : {oblique}
    - Notes : {notes_live}

    Récit :
    """

    static let veille = """
    Tu es l'assistant d'Olivier, qui documente une session de veille technologique / codage d'outils
    pour son écosystème créatif AZA. Rédige un résumé factuel en français, entre 60 et 120 mots, à la première personne,
    clair et concret. Mentionne les pistes explorées et ce qui reste à faire, sans jargon promotionnel.

    Données de session :
    - Durée : {duration_min} min
    - Intention : {intention}
    - Notes : {notes_live}

    Résumé :
    """

    /// Prompt selon le type de séance. Les notes libres servent de « notes live » :
    /// dans l'app web, une séance saisie à la main n'en transmettait aucune.
    public static func prompt(for s: Session) -> String {
        let template = s.sessionType == "lore" ? lore : s.sessionType == "veille" ? veille : music
        func or(_ v: String) -> String { v.isEmpty ? "—" : v }
        func list(_ v: [String]) -> String { v.isEmpty ? "—" : v.joined(separator: ", ") }
        let values: [String: String] = [
            "duration_min": s.durationMin.map(String.init) ?? "?", "mode": or(s.mode), "intention": or(s.intention),
            "machines": list(s.machines), "effects": list(s.effects), "daws": list(s.daws),
            "synths_ios": list(s.synthsIOS), "plugins": list(s.plugins), "oblique": or(s.oblique),
            "notes_live": or(s.comments),
        ]
        var out = template
        for (k, v) in values { out = out.replacingOccurrences(of: "{\(k)}", with: v) }
        return out
    }

    public static func request(for s: Session, baseURL: String, model: String, timeout: TimeInterval = 60) -> URLRequest? {
        let base = baseURL.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: base + "/api/generate"), url.scheme?.hasPrefix("http") == true else { return nil }
        var r = URLRequest(url: url, timeoutInterval: timeout)
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["model": model, "prompt": prompt(for: s), "stream": false,
                                   "options": ["temperature": 0.8], "think": false]
        r.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return r
    }

    /// Texte du récap, ou une erreur lisible (modèle absent, réponse vide…).
    public static func parse(_ data: Data, status: Int) -> Result<String, RecapError> {
        let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        if status != 200 {
            let msg = obj?["error"] as? String ?? String(data: data, encoding: .utf8) ?? ""
            return .failure(RecapError(message: "Ollama a répondu \(status) : \(msg.prefix(200))"))
        }
        let text = (obj?["response"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? .failure(RecapError(message: "Ollama a renvoyé une réponse vide — vérifier le modèle.")) : .success(text)
    }
}

public struct RecapError: Error, CustomStringConvertible, Sendable {
    public let message: String
    public var description: String { message }
}

// MARK: - CSV (export_csv) et vault Obsidian (export_obsidian)

public extension AZAData {
    static let csvColumns = ["id", "session_type", "date", "duration_min", "mode", "intention", "energy_level", "machines",
                             "effects", "daws", "synths_ios", "ipad", "zynthian", "plugins", "patches", "audio_file",
                             "timestamps", "rating", "tags", "character", "lore_link", "to_rework", "release_potential",
                             "tempo", "tonality", "signal_routing", "microfreak_algo", "influences", "oblique", "comments",
                             "recap_claude", "project_title"]

    /// CSV des séances (mêmes colonnes que l'app web), BOM UTF-8 pour Excel / Numbers.
    func csv() -> String {
        func q(_ s: String) -> String {
            s.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" })
                ? "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : s
        }
        func n(_ i: Int?) -> String { i.map(String.init) ?? "" }
        let j = { (a: [String]) in a.joined(separator: ", ") }
        var lines = [Self.csvColumns.joined(separator: ",")]
        for s in sessions.sorted(by: { ($0.date, $0.id) > ($1.date, $1.id) }) {
            let row = [String(s.id), s.sessionType, s.date, n(s.durationMin), s.mode, s.intention, n(s.energyLevel),
                       j(s.machines), j(s.effects), j(s.daws), j(s.synthsIOS), j(s.ipad), j(s.zynthian), j(s.plugins),
                       s.patches, s.audioFile, s.timestamps, n(s.rating), j(s.tags), j(s.character), s.loreLink,
                       s.toRework ? "1" : "0", s.releasePotential ? "1" : "0", s.tempo, s.tonality, s.signalRouting,
                       s.microfreakAlgo, j(s.influences), s.oblique, s.comments, s.recapClaude, project(s.projectId)?.title ?? ""]
            lines.append(row.map(q).joined(separator: ","))
        }
        return "\u{FEFF}" + lines.joined(separator: "\r\n") + "\r\n"
    }

    /// Nom de fichier dans le vault, comme l'app web : `session_AAAAMMJJ_<id>.md`.
    static func obsidianFileName(_ s: Session) -> String {
        "session_\(s.date.prefix(10).replacingOccurrences(of: "-", with: ""))_\(s.id).md"
    }

    /// Écrit la séance dans le dossier du vault (créé si besoin). Rend le nom du fichier.
    func exportToVault(_ s: Session, folder: URL, version: String) throws -> String {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = Self.obsidianFileName(s)
        try markdown(s, version: version).write(to: folder.appendingPathComponent(name), atomically: true, encoding: .utf8)
        return name
    }
}
