import Foundation
import SQLite3

/// Import d'une base `sessions.db` de l'app Flask vers le modèle JSON.
/// Lecture seule : la base n'est jamais modifiée. Les colonnes absentes
/// (bases anciennes, avant migrations) prennent leur valeur par défaut.
public enum SQLiteImport {
    public struct Failure: Error, CustomStringConvertible {
        public let description: String
    }

    typealias Row = [String: String?]

    public static func load(path: String) throws -> AZAData {
        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            defer { sqlite3_close(db) }
            throw Failure(description: "Impossible d'ouvrir \(path)")
        }
        defer { sqlite3_close(db) }

        let tables = Set(try rows(db, "SELECT name FROM sqlite_master WHERE type='table'")
            .compactMap { $0["name"] ?? nil })
        guard tables.contains("sessions") else {
            throw Failure(description: "Ce fichier n'est pas une base AZA (pas de table sessions).")
        }

        var d = AZAData()
        for r in try rows(db, "SELECT * FROM sessions ORDER BY id") {
            guard let id = int(r["id"]) else { continue }
            var s = Session(id: id, date: str(r["date"]).isEmpty ? Clock.today() : str(r["date"]),
                            createdAt: str(r["created_at"]).isEmpty ? Clock.stamp() : str(r["created_at"]))
            s.title = str(r["title"])
            s.sessionType = str(r["session_type"]).isEmpty ? "music" : str(r["session_type"])
            s.durationMin = int(r["duration_min"])
            s.mode = str(r["mode"]); s.intention = str(r["intention"])
            s.energyLevel = int(r["energy_level"])
            s.machines = splitList(str(r["machines"])); s.effects = splitList(str(r["effects"]))
            s.daws = splitList(str(r["daws"])); s.synthsIOS = splitList(str(r["synths_ios"]))
            s.ipad = splitList(str(r["ipad"])); s.zynthian = splitList(str(r["zynthian"]))
            s.plugins = splitList(str(r["plugins"]))
            s.patches = str(r["patches"]); s.audioFile = str(r["audio_file"])
            s.timestamps = str(r["timestamps"]); s.rating = int(r["rating"])
            s.tags = splitList(str(r["tags"])); s.character = splitList(str(r["character"]))
            s.loreLink = str(r["lore_link"])
            s.toRework = (int(r["to_rework"]) ?? 0) != 0
            s.releasePotential = (int(r["release_potential"]) ?? 0) != 0
            s.tempo = str(r["tempo"]); s.tonality = str(r["tonality"])
            s.signalRouting = str(r["signal_routing"]); s.microfreakAlgo = str(r["microfreak_algo"])
            s.linkedSession = int(r["linked_session"])
            s.influences = splitList(str(r["influences"]))
            s.oblique = str(r["oblique"]); s.comments = str(r["comments"])
            s.recapClaude = str(r["recap_claude"]); s.projectId = int(r["project_id"])
            d.sessions.append(s)
        }
        if tables.contains("projects") {
            for r in try rows(db, "SELECT * FROM projects ORDER BY id") {
                guard let id = int(r["id"]) else { continue }
                var p = Project(id: id, title: str(r["title"]))
                p.description = str(r["description"])
                if !str(r["color"]).isEmpty { p.color = str(r["color"]) }
                if !str(r["created_at"]).isEmpty { p.createdAt = str(r["created_at"]) }
                d.projects.append(p)
            }
        }
        if tables.contains("catalogue") {
            for r in try rows(db, "SELECT * FROM catalogue ORDER BY id") {
                guard let id = int(r["id"]) else { continue }
                var g = GearItem(id: id, type: str(r["type"]), name: str(r["name"]))
                g.manufacturer = str(r["manufacturer"]); g.code = str(r["code"])
                g.purpose = str(r["purpose"]); g.intent = str(r["intent"])
                g.notes = str(r["notes"]); g.controls = str(r["controls"])
                g.active = (int(r["active"]) ?? 1) != 0
                g.favorite = (int(r["favorite"]) ?? 0) != 0
                g.noDraw = (int(r["no_draw"]) ?? 0) != 0
                if !str(r["created_at"]).isEmpty { g.createdAt = str(r["created_at"]) }
                d.catalogue.append(g)
            }
        }
        if tables.contains("influences") {
            for r in try rows(db, "SELECT * FROM influences ORDER BY id") {
                guard let id = int(r["id"]) else { continue }
                var i = Influence(id: id, name: str(r["name"]))
                if !str(r["type"]).isEmpty { i.type = str(r["type"]) }
                i.active = (int(r["active"]) ?? 1) != 0
                i.notes = str(r["notes"])
                d.influences.append(i)
            }
        }
        if tables.contains("obliques") {
            for r in try rows(db, "SELECT * FROM obliques ORDER BY id") {
                guard let id = int(r["id"]) else { continue }
                var o = Oblique(id: id, text: str(r["text"]))
                o.active = (int(r["active"]) ?? 1) != 0
                d.obliques.append(o)
            }
        }
        try importSecondary(db, tables, into: &d)
        return d
    }

    static func each(_ db: OpaquePointer?, _ tables: Set<String>, _ table: String,
                     _ body: (Int, Row) -> Void) throws {
        guard tables.contains(table) else { return }
        for r in try rows(db, "SELECT * FROM \(table) ORDER BY id") {
            if let id = int(r["id"]) { body(id, r) }
        }
    }

    static func bool(_ v: String??, _ def: Int = 0) -> Bool { (int(v) ?? def) != 0 }
    static func double(_ v: String??) -> Double? { (v ?? nil).flatMap(Double.init) }

    static func importSecondary(_ db: OpaquePointer?, _ t: Set<String>, into d: inout AZAData) throws {
        try each(db, t, "gear_wishlist") { id, r in
            var w = WishItem(id: id, name: str(r["name"]))
            w.manufacturer = str(r["manufacturer"]); w.type = str(r["type"]); w.price = double(r["price"])
            if !str(r["priority"]).isEmpty { w.priority = str(r["priority"]) }
            w.notes = str(r["notes"]); w.url = str(r["url"]); w.acquired = bool(r["acquired"])
            d.wishlist.append(w)
        }
        try each(db, t, "sample_banks") { id, r in
            var s = SampleBank(id: id, name: str(r["name"]))
            s.type = str(r["type"]); s.rating = int(r["rating"]); s.source = str(r["source"]); s.notes = str(r["notes"])
            d.samples.append(s)
        }
        try each(db, t, "inspiring_tracks") { id, r in
            var x = InspiringTrack(id: id, title: str(r["title"]))
            x.artist = str(r["artist"]); x.album = str(r["album"]); x.year = str(r["year"])
            x.tags = str(r["tags"]); x.notes = str(r["notes"]); x.url = str(r["url"])
            d.tracks.append(x)
        }
        try each(db, t, "inspirations") { id, r in
            var x = Inspiration(id: id, content: str(r["content"]))
            if !str(r["type"]).isEmpty { x.type = str(r["type"]) }
            x.source = str(r["source"]); x.notes = str(r["notes"])
            d.inspirations.append(x)
        }
        try each(db, t, "mirack_modules") { id, r in
            var m = MiRackModule(id: id, name: str(r["name"]))
            m.category = str(r["category"]); m.mastered = bool(r["mastered"]); m.favorite = bool(r["favorite"])
            m.notes = str(r["notes"])
            d.mirack.append(m)
        }
        try each(db, t, "preset_notes") { id, r in
            var p = PresetNote(id: id, date: str(r["date"]).isEmpty ? Clock.today() : str(r["date"]),
                               presetName: str(r["preset_name"]))
            p.catalogueId = int(r["catalogue_id"]); p.evocation = str(r["evocation"]); p.songIdea = str(r["song_idea"])
            p.influenceId = int(r["influence_id"]); p.rating = int(r["rating"]); p.tags = str(r["tags"])
            p.sessionId = int(r["session_id"]); p.notes = str(r["notes"])
            d.presets.append(p)
        }
        try each(db, t, "gear_pairings") { id, r in
            guard let g = int(r["gear_id"]), let p = int(r["partner_id"]) else { return }
            var x = GearPairing(id: id, gearId: g, partnerId: p)
            x.note = str(r["note"])
            d.gearPairings.append(x)
        }
        try each(db, t, "gear_notes") { id, r in
            guard let g = int(r["gear_id"]) else { return }
            d.gearNotes.append(GearNote(id: id, gearId: g, date: str(r["date"]), note: str(r["note"])))
        }
        try each(db, t, "knob_sheets") { id, r in
            guard let g = int(r["gear_id"]) else { return }
            var k = KnobSheet(id: id, gearId: g)
            k.sessionId = int(r["session_id"]); k.presetId = int(r["preset_id"])
            k.label = str(r["label"]); k.notes = str(r["notes"])
            if !str(r["created_at"]).isEmpty { k.createdAt = str(r["created_at"]) }
            // values_json : {commande: valeur} — nombres ou textes, gardés en texte.
            if let obj = try? JSONSerialization.jsonObject(with: Data(str(r["values_json"]).utf8)) as? [String: Any] {
                for (key, v) in obj {
                    let s: String
                    if let n = v as? NSNumber {
                        s = n.doubleValue.rounded() == n.doubleValue ? String(n.intValue) : n.stringValue
                    } else { s = "\(v)" }
                    if !s.isEmpty { k.values[key] = s }
                }
            }
            d.knobSheets.append(k)
        }
        if t.contains("live_session"), let r = try rows(db, "SELECT * FROM live_session LIMIT 1").first {
            var l = LiveSession(startedAt: str(r["started_at"]).isEmpty ? Clock.stamp() : str(r["started_at"]))
            l.notes = str(r["notes_live"]); l.machines = splitList(str(r["machines"]))
            l.effects = splitList(str(r["effects"])); l.daws = splitList(str(r["daws"]))
            l.synthsIOS = splitList(str(r["synths_ios"])); l.plugins = splitList(str(r["plugins"]))
            l.mode = str(r["mode"]); l.intention = str(r["intention"]); l.oblique = str(r["oblique"])
            l.projectId = int(r["project_id"])
            d.live = l
        }
    }

    static func str(_ v: String??) -> String { (v ?? nil) ?? "" }
    static func int(_ v: String??) -> Int? {
        guard let s = v ?? nil else { return nil }
        if let i = Int(s) { return i }
        if let f = Double(s) { return Int(f) }
        return nil
    }

    static func rows(_ db: OpaquePointer?, _ sql: String) throws -> [Row] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw Failure(description: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        var out: [Row] = []
        let n = sqlite3_column_count(stmt)
        while sqlite3_step(stmt) == SQLITE_ROW {
            var r: Row = [:]
            for i in 0..<n {
                let name = String(cString: sqlite3_column_name(stmt, i))
                if sqlite3_column_type(stmt, i) == SQLITE_NULL {
                    r[name] = .some(nil)
                } else if let t = sqlite3_column_text(stmt, i) {
                    r[name] = String(cString: t)
                }
            }
            out.append(r)
        }
        return out
    }
}
