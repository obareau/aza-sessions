// aza-check — auto-test du cœur (JSON, sauvegardes, nom de prise, import SQLite).
// Usage : aza-check <dossier de travail>
import AZACore
import Foundation
import SQLite3

var failures = 0
var passed = 0
func check(_ cond: Bool, _ what: String) {
    if cond { passed += 1 } else { failures += 1; print("✗ \(what)") }
}

let work = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1]
               : NSTemporaryDirectory() + "aza-check")
try? FileManager.default.removeItem(at: work)
try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)

// 1. Aller-retour JSON
var d = Seed.initial()
check(d.obliques.count == 25 && d.influences.count == 16 && d.catalogue.count == 36, "graines")
var s = Session(id: d.nextSessionId(), date: "2026-11-14")
s.machines = ["MicroFreak"]; s.effects = ["Sonicake Smartbox"]; s.rating = 4; s.tags = ["drone", "nuit"]
d.sessions.append(s)
let back = try JSONStorage.decode(JSONStorage.encode(d))
check(back == d, "aller-retour JSON")

// 2. Décodage tolérant : champs absents → valeurs par défaut
let minimal = #"{"sessions":[{"id":7,"date":"2026-01-02"}],"catalogue":[{"id":1,"name":"X"}]}"#
let m = try JSONStorage.decode(Data(minimal.utf8))
check(m.sessions.first?.id == 7 && m.sessions.first?.machines == [] && m.catalogue.first?.active == true,
      "décodage tolérant")

// 3. Sauvegardes : pas de doublon, rétention de 5
let st = JSONStorage(url: work.appendingPathComponent("aza.json"))
try st.save(d)
check(try st.backup() != nil, "première sauvegarde")
check(try st.backup() == nil, "sauvegarde sautée si inchangé")
for i in 0..<7 {
    var dd = d; dd.projects.append(Project(id: i + 1, title: "P\(i)"))
    try st.save(dd)
    try st.backup(now: Date().addingTimeInterval(Double(i + 1)))
}
check(try st.backups().count == 5, "rétention de 5 sauvegardes")
check(try st.load() != nil, "relecture du fichier")

// 4. Nom de prise R8
var t = Seed.initial()
t.catalogue[t.catalogue.firstIndex { $0.name == "MicroFreak" }!].code = "mf"
t.catalogue[t.catalogue.firstIndex { $0.name == "Sonicake Smartbox" }!].code = "SBX"
var a = Session(id: 1, date: "2026-11-14"); a.machines = ["MicroFreak"]; a.effects = ["Sonicake Smartbox"]
check(t.takeName(for: a) == "MFSBX_1", "nom de prise : \(t.takeName(for: a))")
a.audioFile = "MFSBX_1"; t.sessions.append(a)
var b = Session(id: 2, date: "2026-11-14"); b.machines = a.machines; b.effects = a.effects
check(t.takeName(for: b) == "MFSBX_2", "rang du jour")
var c = Session(id: 3, date: "2026-11-15"); c.machines = a.machines; c.effects = a.effects
check(t.takeName(for: c) == "MFSBX_1", "compteur quotidien")
var e = Session(id: 4, date: "2026-11-14"); e.machines = ["Volca Drum"]
check(t.takeName(for: e) == "", "pas de code, pas de nom")

// 5. Markdown
check(t.markdown(a, version: "1").contains("## Machines\nMicroFreak"), "export Markdown")

// 6. Import d'une base Flask (schéma ancien : sans manufacturer/code/no_draw)
let dbPath = work.appendingPathComponent("sessions.db").path
var db: OpaquePointer?
sqlite3_open(dbPath, &db)
let sql = """
CREATE TABLE sessions (id INTEGER PRIMARY KEY, date TEXT NOT NULL, mode TEXT, machines TEXT,
  effects TEXT, rating INTEGER, tags TEXT, to_rework INTEGER DEFAULT 0, project_id INTEGER,
  linked_session INTEGER, title TEXT, character TEXT, comments TEXT);
CREATE TABLE projects (id INTEGER PRIMARY KEY, title TEXT, description TEXT, color TEXT);
CREATE TABLE catalogue (id INTEGER PRIMARY KEY, type TEXT, name TEXT, active INTEGER, favorite INTEGER, notes TEXT);
CREATE TABLE obliques (id INTEGER PRIMARY KEY, text TEXT, active INTEGER);
INSERT INTO sessions VALUES (3,'2025-06-01','Dawless','MicroFreak, NTS-1','',4,'drone,  nuit',1,9,NULL,'Nappe','Drone, Noise','é « ok »');
INSERT INTO sessions VALUES (5,'2025-06-02',NULL,NULL,NULL,NULL,NULL,0,NULL,3,NULL,NULL,NULL);
INSERT INTO projects VALUES (9,'Scaër','desc','#112233');
INSERT INTO catalogue VALUES (1,'machine','MicroFreak',1,1,NULL);
INSERT INTO obliques VALUES (1,'Commence par la fin.',0);
"""
sqlite3_exec(db, sql, nil, nil, nil)
sqlite3_close(db)
let imp = try SQLiteImport.load(path: dbPath)
let s3 = imp.sessions.first { $0.id == 3 }
check(imp.sessions.count == 2, "import : 2 séances")
check(s3?.machines == ["MicroFreak", "NTS-1"] && s3?.tags == ["drone", "nuit"], "import : listes")
check(s3?.toRework == true && s3?.projectId == 9 && s3?.comments == "é « ok »", "import : champs")
check(imp.sessions.first { $0.id == 5 }?.linkedSession == 3, "import : séance liée")
check(imp.projects.first?.color == "#112233" && imp.catalogue.first?.favorite == true, "import : projets, catalogue")
check(imp.obliques.first?.active == false && imp.influences.isEmpty, "import : obliques, table absente")
check(imp.nextSessionId() == 6, "import : identifiants suivants")
check((try? SQLiteImport.load(path: work.appendingPathComponent("aza.json").path)) == nil, "import : refuse un non-SQLite")

// 7. Modules ajoutés
let titles = Titles.propose(5)
check(titles.count == 5 && Set(titles).count == 5, "titres : 5 distincts")
check(!titles.contains { $0.contains("SIGNAL RÉSIDUELLE") }, "titres : accord du genre")

var dr = Seed.initial()
for i in dr.catalogue.indices where !["MicroFreak", "Sonicake Smartbox"].contains(dr.catalogue[i].name) {
    dr.catalogue[i].noDraw = true
}
dr.catalogue[dr.catalogue.firstIndex { $0.name == "MicroFreak" }!].code = "MFR"
let tir = dr.draw()
check(tir.instrument?.name == "MicroFreak" && tir.treatment?.name == "Sonicake Smartbox", "tirage : hors tirage respecté")
check(tir.take == "MFR_1" && !tir.oblique.isEmpty && !tir.title.isEmpty, "tirage : prise, oblique, titre")

let codes = CodeProposer.propose(Seed.initial().catalogue)
let byName = Dictionary(uniqueKeysWithValues: Seed.initial().catalogue.map { ($0.name, $0.id) })
check(codes[byName["MicroFreak"]!] == "MFR", "codes : MicroFreak → \(codes[byName["MicroFreak"]!] ?? "nil")")
check(codes[byName["NTS-1"]!] == "NT1", "codes : NTS-1 → \(codes[byName["NTS-1"]!] ?? "nil")")
check(codes[byName["Zoom R8"]!] == "ZR8", "codes : Zoom R8 → \(codes[byName["Zoom R8"]!] ?? "nil")")
check(Set(codes.values).count == codes.count, "codes : pas de doublon")
var withCode = Seed.initial(); withCode.catalogue[0].code = "XYZ"
check(CodeProposer.propose(withCode.catalogue)[withCode.catalogue[0].id] == nil, "codes : existant intouché")

let ctl = parseControls("-- OSC\nCutoff\n# rien\nFiltre: LP | BP | HP\n\nReso")
check(ctl.map(\.kind) == [.section, .dial, .switch, .dial] && ctl[2].options == ["LP", "BP", "HP"], "façade : déclaration")

var reg = AZAData()
for (i, (date, take)) in [("2026-11-01", "MF_1"), ("2026-11-02", "mf_1"), ("2026-11-03", "NT_1"), ("2026-11-04", "")].enumerated() {
    var s = Session(id: i + 1, date: date); s.audioFile = take; reg.sessions.append(s)
}
let groupsR = reg.takeRegistry()
check(groupsR.count == 2 && groupsR.first { $0.key == "MF_1" }?.duplicate == true, "prises : doublon insensible à la casse")

var stData = AZAData()
let today = Clock.day("2026-11-14")!
for (i, day) in ["2026-11-14", "2026-11-13", "2026-11-12", "2026-11-01", "2026-10-31"].enumerated() {
    var s = Session(id: i + 1, date: day); s.rating = 3; s.energyLevel = 2; s.durationMin = 30 + i; s.machines = ["MicroFreak"]
    stData.sessions.append(s)
}
let sts = stData.stats(today: today)!
check(sts.streak == 3 && sts.maxStreak == 3, "stats : série \(sts.streak) / record \(sts.maxStreak)")
check(sts.totalMinutes == 160 && sts.thisMonth == 4 && !sts.monthlyRating.isEmpty, "stats : totaux et tendances")
check(stData.stats(today: Clock.day("2026-11-16")!)!.streak == 0, "stats : série rompue")

var sp = Seed.initial(); sp.inspirations = [Inspiration(id: 1, content: "Une idée")]
check(sp.sparks().contains { $0.kind == "Idée en vrac" }, "spark : idées en vrac")

var gp = Seed.initial()
gp.gearPairings = [GearPairing(id: 1, gearId: 1, partnerId: 16)]
check(gp.pairings(of: 16).first?.partner.id == 1 && gp.pairings(of: 1).first?.partner.id == 16, "carnet : association des deux côtés")

// 8. Import des tables secondaires
let db2 = work.appendingPathComponent("full.db").path
var h: OpaquePointer?
sqlite3_open(db2, &h)
sqlite3_exec(h, """
CREATE TABLE sessions (id INTEGER PRIMARY KEY, date TEXT NOT NULL);
CREATE TABLE gear_wishlist (id INTEGER PRIMARY KEY, manufacturer TEXT, name TEXT, type TEXT, price REAL, priority TEXT, notes TEXT, url TEXT, acquired INTEGER);
CREATE TABLE preset_notes (id INTEGER PRIMARY KEY, date TEXT, catalogue_id INTEGER, preset_name TEXT, evocation TEXT, song_idea TEXT, influence_id INTEGER, rating INTEGER, tags TEXT, session_id INTEGER, notes TEXT);
CREATE TABLE knob_sheets (id INTEGER PRIMARY KEY, gear_id INTEGER, session_id INTEGER, label TEXT, values_json TEXT, notes TEXT, created_at TEXT, preset_id INTEGER);
CREATE TABLE gear_pairings (id INTEGER PRIMARY KEY, gear_id INTEGER, partner_id INTEGER, note TEXT);
CREATE TABLE live_session (id INTEGER PRIMARY KEY, started_at TEXT, notes_live TEXT, machines TEXT, effects TEXT, daws TEXT, synths_ios TEXT, plugins TEXT, mode TEXT, intention TEXT, oblique TEXT, project_id INTEGER);
INSERT INTO sessions VALUES (1, '2026-01-01');
INSERT INTO gear_wishlist VALUES (1, 'Behringer', 'Wasp', 'Synthétiseur', 129.5, 'Bientôt', NULL, NULL, 0);
INSERT INTO preset_notes VALUES (4, '2026-02-02', 1, 'Brume', 'brouillard', NULL, NULL, 5, NULL, 1, NULL);
INSERT INTO knob_sheets VALUES (2, 1, 1, 'Nappe', '{"Cutoff": 7, "Reso": 0, "Filtre": "LP", "Env": 2.5}', '', '2026-02-02 10:00:00', 4);
INSERT INTO gear_pairings VALUES (1, 1, 2, 'chaud');
INSERT INTO live_session VALUES (1, '2026-11-14 20:00:00', 'ça tourne', 'MicroFreak', '', '', '', '', 'Dawless', '', 'Commence par la fin.', NULL);
""", nil, nil, nil)
sqlite3_close(h)
let full = try SQLiteImport.load(path: db2)
check(full.wishlist.first?.price == 129.5 && full.wishlist.first?.priority == "Bientôt", "import : wishlist")
check(full.presets.first?.presetName == "Brume" && full.presets.first?.rating == 5, "import : presets")
let ks = full.knobSheets.first
check(ks?.values == ["Cutoff": "7", "Reso": "0", "Filtre": "LP", "Env": "2.5"] && ks?.presetId == 4, "import : relevé (0 gardé)")
check(full.gearPairings.first?.note == "chaud", "import : associations")
check(full.live?.machines == ["MicroFreak"] && full.live?.mode == "Dawless", "import : séance en cours")
check(try JSONStorage.decode(JSONStorage.encode(full)) == full, "aller-retour JSON complet")

print(failures == 0 ? "✓ aza-check : \(passed) vérifications OK" : "✗ aza-check : \(failures) échec(s), \(passed) OK")
exit(failures == 0 ? 0 : 1)
