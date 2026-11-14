// aza-check — auto-test du cœur (JSON, sauvegardes, nom de prise, import SQLite).
// Usage : aza-check <dossier de travail>
import AZACore
import Foundation
import SQLite3

// `aza-check --sheets <dossier>` : écrit les 5 fiches d'exemple (aperçu / contrôle PDF).
if CommandLine.arguments.count > 2, CommandLine.arguments[1] == "--sheets" {
    let dir = CommandLine.arguments[2]
    var d = Seed.initial()
    d.catalogue[0].controls = "-- OSCILLATEUR\nCutoff\nReso\nFiltre: LP | BP | HP"
    d.catalogue[0].code = "MFR"
    var s = Session(id: 1, date: "2026-11-14")
    s.title = "MÉMOIRE RÉSIDUELLE"; s.machines = ["MicroFreak"]; s.effects = ["Sonicake Smartbox"]
    s.comments = String(repeating: "Une nappe longue qui dérive. ", count: 40); s.rating = 4; s.audioFile = "MFR_1"
    s.oblique = "Commence par la fin."
    d.sessions = [s]
    var k = KnobSheet(id: 1, gearId: d.catalogue[0].id); k.sessionId = 1; k.values = ["Cutoff": "7", "Filtre": "LP"]
    d.knobSheets = [k]
    let pages = ["session": Sheets.session(s, data: d, version: "dev"), "recall": Sheets.recall(s, data: d, version: "dev"),
                 "atelier": Sheets.workshop(gear: ["MicroFreak", "Volca Drum"], data: d, version: "dev"),
                 "blank": Sheets.blankForm(data: d, version: "dev"), "catalogue": Sheets.catalogue(d.catalogue, filter: "", version: "dev")]
    for (n, html) in pages { try html.write(toFile: dir + "/" + n + ".html", atomically: true, encoding: .utf8) }
    print("✓ 5 fiches écrites dans \(dir)")
    exit(0)
}

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

// 9. Patcher
var pl = PatchLayout(id: 1, name: "Studio")
let mf = pl.addNode("MicroFreak", type: "machine", x: 100, y: 100)
let sb = pl.addNode("Smartbox", type: "effet", x: 400, y: 100)
let ab = pl.addNode("Ableton Live", type: "daw", x: 700, y: 100)
let nt = pl.addNode("NTS-1", type: "machine", x: 100, y: 300)
pl.connect(mf, sb, signal: "audio"); pl.connect(sb, ab, signal: "audio"); pl.connect(nt, ab, signal: "midi")
check(pl.connect(mf, mf, signal: "audio") == nil, "patch : pas de câble sur soi-même")
check(pl.routingText() == "MicroFreak → Smartbox → Ableton Live\nNTS-1 → Ableton Live", "patch : routing\n\(pl.routingText())")
let fields = pl.sessionFields()
check(fields.gear[.machines] == ["MicroFreak", "NTS-1"] && fields.gear[.daws] == ["Ableton Live"], "patch : → séance")
var lone = PatchLayout(id: 2, name: "x")
lone.addNode("Ableton Live", type: "daw", x: 0, y: 0); lone.addNode("MicroFreak", type: "machine", x: 0, y: 0)
check(lone.routingText() == "MicroFreak → Ableton Live", "patch : routing sans câble, ordre des types")
let back2 = try PatchLayout.fromPortable(pl.portableJSON(), id: 9)
check(back2.nodes.map(\.label) == pl.nodes.map(\.label) && back2.connections.count == 3
      && back2.routingText() == pl.routingText(), "patch : JSON portable aller-retour")
let md = pl.mermaid(session: nil)
check(md.contains("graph LR") && md.contains("n4 -.->|\"midi\"| n3"), "patch : Mermaid")
check(pl.svg().contains("marker-end=\"url(#arrow-midi)\""), "patch : SVG")
var par = pl; par.connect(mf, sb, signal: "midi")
let c1 = par.cable(par.connections[0])!, c2 = par.cable(par.connections.last!)!
check(abs(c1.c1y - c2.c1y) > 10, "patch : câbles parallèles écartés")
check(c1.distance(to: c1.midX, c1.midY) < 3, "patch : clic sur un câble")
var withSession = PatchLayout(id: 3, name: "s")
var src = Session(id: 1, date: "2026-11-14"); src.machines = ["MicroFreak", "NTS-1"]; src.effects = ["Sonicake Smartbox"]
check(withSession.importSession(src, catalogue: Seed.initial().catalogue) == 3
      && withSession.nodes.first?.catalogueId != nil, "patch : import depuis une séance")

let db3 = work.appendingPathComponent("patch.db").path
var h3: OpaquePointer?
sqlite3_open(db3, &h3)
sqlite3_exec(h3, """
CREATE TABLE sessions (id INTEGER PRIMARY KEY, date TEXT NOT NULL);
CREATE TABLE patch_layouts (id INTEGER PRIMARY KEY, name TEXT, session_id INTEGER, created_at TEXT);
CREATE TABLE patch_nodes (id INTEGER PRIMARY KEY, layout_id INTEGER, label TEXT, x REAL, y REAL, node_type TEXT, color TEXT, catalogue_id INTEGER, note TEXT);
CREATE TABLE patch_connections (id INTEGER PRIMARY KEY, layout_id INTEGER, from_id INTEGER, to_id INTEGER, label TEXT, signal_type TEXT, note TEXT);
INSERT INTO patch_layouts VALUES (5, 'Live set', NULL, '2026-03-03 10:00:00');
INSERT INTO patch_nodes VALUES (11, 5, 'MicroFreak', 120, 80, 'machine', '#D4380D', NULL, 'algo Karplus');
INSERT INTO patch_nodes VALUES (12, 5, 'Wasp', 400, 80, 'synth_android', '', NULL, '');
INSERT INTO patch_connections VALUES (7, 5, 11, 12, 'clock', 'midi', '');
""", nil, nil, nil)
sqlite3_close(h3)
let pimp = try SQLiteImport.load(path: db3)
let lay = pimp.patches.first
check(lay?.name == "Live set" && lay?.nodes.count == 2 && lay?.connections.first?.fromId == 11, "import : patch")
check(lay?.nodes.last?.color.hasPrefix("#") == true && lay?.nodes.first?.note == "algo Karplus", "import : nœuds, type custom coloré")

// 10. SysEx DX7
var v1 = DX7Voice.initVoice
check(v1.name == "INIT VOICE" && v1.bytes[15] == 2 && v1.bytes[12] == 56, "sysex : INIT VOICE (ratio 1, detune centré)")
v1.name = "Brümé ÉTÉ trop long"
check(v1.name == "Brume ETE", "sysex : nom ASCII 10 car. (\(v1.name))")
var slots = [DX7Voice?](repeating: nil, count: 32); slots[3] = v1
let bulk = DX7.buildBulk(slots, channel: 2)
check(bulk.count == 4104 && bulk[0] == 0xF0 && bulk[2] == 2 && bulk[3] == 0x09 && bulk.last == 0xF7, "sysex : bulk 4104 octets")
check(DX7.bulkChecksumOK(bulk), "sysex : checksum")
var broken = bulk; broken[100] ^= 0x01
check(!DX7.bulkChecksumOK(broken), "sysex : checksum faux détecté")
check(DX7.patchNames(bulk)[3] == "Brume ETE" && DX7.patchNames(bulk)[0] == "INIT VOICE", "sysex : noms des 32 voix")
check(DX7.withChannel(bulk, 15)[2] == 15 && DX7.withChannel([0xF0, 0x41, 0x10, 0xF7], 5)[2] == 0x10, "sysex : canal Yamaha seulement")
check(DX7.voices(bulk)?.count == 32 && DX7.voices([0xF0, 0xF7]) == nil, "sysex : découpage du bulk")
check(DX7.checksum([0x7F, 0x01]) == 0x00 && DX7.checksum([0x01]) == 0x7F, "sysex : complément à 2 sur 7 bits")
check(SysexBank(id: 1, name: "b", data: Data(bulk)).format == "DX7 · 32-voice bulk", "sysex : format")

let db4 = work.appendingPathComponent("sysex.db").path
var h4: OpaquePointer?
sqlite3_open(db4, &h4)
sqlite3_exec(h4, "CREATE TABLE sessions (id INTEGER PRIMARY KEY, date TEXT NOT NULL); CREATE TABLE sysex_banks (id INTEGER PRIMARY KEY, name TEXT, format TEXT, size INTEGER, data BLOB, created_at TEXT);", nil, nil, nil)
var stmt4: OpaquePointer?
sqlite3_prepare_v2(h4, "INSERT INTO sysex_banks VALUES (3, 'Rom1A', 'x', 4104, ?, '2026-01-01 00:00:00')", -1, &stmt4, nil)
let blobData = Data(bulk)
blobData.withUnsafeBytes { _ = sqlite3_bind_blob(stmt4, 1, $0.baseAddress, Int32(blobData.count), nil) }
sqlite3_step(stmt4); sqlite3_finalize(stmt4); sqlite3_close(h4)
let simp = try SQLiteImport.load(path: db4)
check(simp.sysexBanks.first?.data == blobData && simp.sysexBanks.first?.name == "Rom1A", "import : banque SysEx (BLOB avec octets nuls)")
check(try JSONStorage.decode(JSONStorage.encode(simp)) == simp, "sysex : aller-retour JSON (base64)")

// 11. Lore (vault factice)
let vault = work.appendingPathComponent("vault")
func put(_ rel: String, _ text: String) throws {
    let u = vault.appendingPathComponent(rel)
    try FileManager.default.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
    try text.write(to: u, atomically: true, encoding: .utf8)
}
try put("Lore/Factions/index.md", "# Sommaire")
try put("Lore/Factions/Majeures/cgu-rectitude.md", """
---
title: "C.G.U. de la Rectitude"
tags: [faction, administration]
---
# Ignoré

> La conformité n'est pas une option, c'est un climat que l'on respire chaque matin.
> Définition : organe central de la Rectitude, chargé de tout.
> Trop court.
""")
try put("Lore/Lieux/scaer.md", """
# Scaër

Une ville de **granit** reliée au [[relais-3|Relais 3]] par la ligne quatre, toujours humide.
""")
try put("Lore/Temps/timeline.md", """
---
title: Chronologie
---
## Ère zéro
| Date | Grégorien | Événement |
|------|-----------|-----------|
| An 0 | 2413 | Fondation du [[cgu|C.G.U.]] |
## Ère des relais
| A.12 | 2425 | Mise en service du [[relais-3]] |
""")
let lore = LoreReader(path: vault.path)
check(lore.available && !LoreReader(path: work.appendingPathComponent("rien").path).available, "lore : disponibilité")
let fac = lore.entries("Factions")
check(fac.count == 1 && fac[0].title == "C.G.U. de la Rectitude" && fac[0].subsection == "Majeures"
      && fac[0].tags == ["faction", "administration"], "lore : frontmatter, sous-dossier, index ignoré")
let lieux = lore.entries("Lieux")
check(lieux.first?.title == "Scaër" && lieux.first?.description == "Une ville de granit reliée au Relais 3 par la ligne quatre, toujours humide.",
      "lore : titre # et premier paragraphe nettoyé")
let tl = lore.timeline()
check(tl.count == 2 && tl[0].event == "Fondation du C.G.U." && tl[0].era == "Ère zéro" && tl[1].era == "Ère des relais",
      "lore : chronologie (wikilink à barre dans un tableau)")
let qs = lore.quotes()
check(qs.count == 1 && qs[0].source == "C.G.U. de la Rectitude", "lore : citations (définitions et trop courtes écartées)")
check(LoreReader.search(lore.all(), "granit").count == 1 && LoreReader.search(lore.all(), "ADMINISTRATION").count == 1, "lore : recherche")

// 12. Fiches imprimables
var shd = Seed.initial()
let mfIdx = shd.catalogue.firstIndex { $0.name == "MicroFreak" }!
shd.catalogue[mfIdx].code = "MFR"; shd.catalogue[mfIdx].controls = "-- OSC\nCutoff\nFiltre: LP | BP"
var shs = Session(id: 3, date: "2026-11-14"); shs.machines = ["MicroFreak"]; shs.effects = ["Sonicake Smartbox"]
shs.comments = "<b>pas du HTML</b>"; shs.audioFile = "MFR_1"
shd.sessions = [shs]
var shk = KnobSheet(id: 1, gearId: shd.catalogue[mfIdx].id); shk.sessionId = 3; shk.values = ["Cutoff": "7", "Filtre": "LP"]
shd.knobSheets = [shk]
let rec = Sheets.recall(shs, data: shd, version: "t")
check(rec.contains("&lt;b&gt;pas du HTML") && !rec.contains("<b>pas du HTML"), "fiches : texte échappé")
check(rec.range(of: "MicroFreak")!.lowerBound < rec.range(of: "Sonicake Smartbox")!.lowerBound
      && rec.contains("width:70%") && rec.contains("pas relevé") == false, "fiches : rappel (ordre du signal, façade)")
let ws = Sheets.workshop(gear: ["MicroFreak", "Volca Drum"], data: shd, version: "t")
check(ws.contains("<b>MFR_</b>") && ws.contains("◻ LP") && ws.components(separatedBy: "class=\"gauge\"").count - 1 == 7,
      "fiches : atelier (préfixe de prise, sélecteur, jauges + lignes vides)")
check(Sheets.blankForm(data: shd, version: "t").contains("Behringer Uphoria 1820"), "fiches : formulaire vierge")
check(Sheets.catalogue(shd.catalogue, filter: "", version: "t").contains("A4 landscape"), "fiches : catalogue en paysage")

print(failures == 0 ? "✓ aza-check : \(passed) vérifications OK" : "✗ aza-check : \(failures) échec(s), \(passed) OK")
exit(failures == 0 ? 0 : 1)
