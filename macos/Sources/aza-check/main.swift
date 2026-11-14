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

print(failures == 0 ? "✓ aza-check : \(passed) vérifications OK" : "✗ aza-check : \(failures) échec(s), \(passed) OK")
exit(failures == 0 ? 0 : 1)
