// aza-check — auto-test du cœur (JSON, sauvegardes, nom de prise, import SQLite).
// Usage : aza-check <dossier de travail>
import AZACore
import CoreGraphics
import ImageIO
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

// `aza-check --demo <fichier.json>` : jeu de données de démonstration (captures d'écran, essais).
if CommandLine.arguments.count > 2, CommandLine.arguments[1] == "--demo" {
    var d = Seed.initial()
    func gid(_ n: String) -> Int { d.catalogue.first { $0.name == n }!.id }
    func setGear(_ n: String, maker: String, code: String, fav: Bool = false, purpose: String = "", intent: String = "", controls: String = "") {
        let i = d.catalogue.firstIndex { $0.name == n }!
        d.catalogue[i].manufacturer = maker; d.catalogue[i].code = code; d.catalogue[i].favorite = fav
        d.catalogue[i].purpose = purpose; d.catalogue[i].intent = intent; d.catalogue[i].controls = controls
    }
    setGear("MicroFreak", maker: "Arturia", code: "MFR", fav: true, purpose: "Synthé hybride, source principale",
            intent: "Nappes Karplus, textures granulaires",
            controls: "-- OSCILLATEUR\nType: BasicW | Karplus | Texturer | Harmo\nWave\nTimbre\nShape\n-- FILTRE\nCutoff\nResonance\n-- ENVELOPPE\nAttack\nDecay\nSustain")
    setGear("NTS-1", maker: "Korg", code: "NT1", fav: true, purpose: "Petit synthé + effets", intent: "Basses, reverb longue")
    setGear("Volca Drum", maker: "Korg", code: "VDR", purpose: "Percussions FM / modélisation")
    setGear("Sonicake Smartbox", maker: "Sonicake", code: "SBX", purpose: "Multi-effet guitare", intent: "Saturation, delay sale")
    setGear("Korg Pandora PX Mini", maker: "Korg", code: "KPX")
    setGear("Zoom R8", maker: "Zoom", code: "ZR8", purpose: "Enregistreur 8 pistes")
    setGear("Ableton Live", maker: "Ableton", code: "ABL")
    setGear("Tera Pro", maker: "Synthetic Bits", code: "TER")
    d.projects = [Project(id: 1, title: "B.O. Scaër"), Project(id: 2, title: "Relais 3")]
    d.projects[0].color = "#D4380D"; d.projects[0].description = "Bande originale des nuits de Scaër."
    d.projects[1].color = "#2D4A6B"; d.projects[1].description = "Transmissions du relais nord."
    let titles = ["MÉMOIRE RÉSIDUELLE", "NODE SCAER-7", "CORROSION LENTE", "A.212 — SIGNAL", "STRATE SOUTERRAINE",
                  "VEILLE MÉCANIQUE", "CDX-14 / CENDRE NOCTURNE", "RUMEUR CONTINUE", "RELIQUE-08", "BALISE TARDIVE",
                  "SOMMEIL CONFORME", "NODE KERGLAZ-3", "LATENCE BASSE", "INVENTAIRE MUET"]
    let setups: [([String], [String], [String])] = [
        (["MicroFreak"], ["Sonicake Smartbox"], []), (["NTS-1", "Volca Drum"], [], ["Ableton Live"]),
        (["MicroFreak", "NTS-1"], ["Korg Pandora PX Mini"], []), (["Volca Drum"], ["Sonicake Smartbox"], ["Ableton Live"]),
    ]
    let modes = ["Dawless", "Hybride", "Dawless", "Full DAW"], intents = ["B.O AZA", "Exploration", "Jam", "B.O AZA"]
    let chars = [["Drone", "Ambient"], ["Rythmique", "Industriel"], ["Texturé", "Drone"], ["Noise", "Percussif"]]
    let notes = ["Une nappe qui dérive sur vingt minutes, le Karplus en boucle derrière la saturation.",
                 "Le Volca tient la pulsation, la basse du NTS-1 vient la contredire. Garder le passage à 12:40.",
                 "Moins de sources, plus de profondeur : deux voix seulement, et beaucoup de silence.",
                 "Session courte, énergie haute. Le delay sale de la Smartbox fait tout le travail."]
    let cal = Calendar(identifier: .gregorian)
    var day = Clock.day("2026-11-14")!
    for i in 0..<titles.count {
        var s = Session(id: i + 1, date: Clock.day(day))
        let k = i % 4
        s.title = titles[i]; s.machines = setups[k].0; s.effects = setups[k].1; s.daws = setups[k].2
        s.mode = modes[k]; s.intention = intents[k]; s.character = chars[k]; s.comments = notes[k]
        s.durationMin = [45, 30, 75, 20][k] + i; s.rating = [5, 4, 3, 4, 5, 2][i % 6]; s.energyLevel = [2, 3, 1, 3][k]
        s.projectId = i % 3 == 2 ? nil : (i % 2) + 1; s.tempo = ["", "92", "", "128"][k]; s.tonality = ["Ré mineur", "", "La", ""][k]
        s.oblique = d.obliques[i % d.obliques.count].text; s.tags = [["nuit"], ["live", "rythme"], ["drone"], ["sale"]][k]
        s.influences = [["Lustmord"], ["Vromb", "Converter"], ["Alva Noto"], ["Synapscape"]][k]
        s.releasePotential = i % 5 == 0; s.toRework = i % 4 == 1
        s.signalRouting = s.machines.joined(separator: " + ") + (s.effects.isEmpty ? "" : " → " + s.effects.joined()) + " → Zoom R8"
        s.audioFile = d.takeName(for: s)
        if i == 0 { s.recapClaude = "La nappe s'est levée avant moi. J'ai laissé le Karplus tourner dans la saturation jusqu'à ce que le souffle devienne une architecture. Rien n'a été décidé : la machine a déformé, j'ai seulement écouté." }
        d.sessions.append(s)
        day = cal.date(byAdding: .day, value: -[1, 2, 1, 3][k], to: day)!
    }
    var p = PatchLayout(id: 1, name: "Studio — chaîne Scaër")
    let a = p.addNode("MicroFreak", type: "machine", x: 80, y: 80, catalogueId: gid("MicroFreak"))
    let b = p.addNode("NTS-1", type: "machine", x: 80, y: 260, catalogueId: gid("NTS-1"))
    let c = p.addNode("Volca Drum", type: "machine", x: 80, y: 420, catalogueId: gid("Volca Drum"))
    let e = p.addNode("Sonicake Smartbox", type: "effet", x: 380, y: 120, catalogueId: gid("Sonicake Smartbox"))
    let f = p.addNode("Behringer Uphoria 1820", type: "machine", x: 680, y: 260, catalogueId: gid("Behringer Uphoria 1820"))
    let g = p.addNode("Ableton Live", type: "daw", x: 960, y: 260, catalogueId: gid("Ableton Live"))
    let h = p.addNode("Zoom R8", type: "machine", x: 960, y: 80, catalogueId: gid("Zoom R8"))
    let lp = p.addNode("Launchpad Pro mk3", type: "machine", x: 680, y: 460, catalogueId: gid("Launchpad Pro mk3"))
    p.nodes[0].note = "algo Karplus"
    p.connect(a, e, signal: "audio"); p.connect(e, f, signal: "audio"); p.connect(b, f, signal: "audio")
    p.connect(c, f, signal: "audio"); p.connect(f, g, signal: "usb"); p.connect(e, h, signal: "audio")
    p.connect(lp, g, signal: "midi"); p.connect(g, c, signal: "midi"); p.connect(g, b, signal: "midi"); p.connect(a, b, signal: "cv")
    p.connections[0].label = "stéréo"
    p.sessionId = 1
    d.patches = [p]
    var pn = PresetNote(id: 1, date: "2026-11-10", presetName: "Brume portuaire"); pn.catalogueId = gid("MicroFreak")
    pn.rating = 5; pn.evocation = "Un quai dans le brouillard, des chaînes au loin"; pn.sessionId = 1
    var pn2 = PresetNote(id: 2, date: "2026-11-02", presetName: "Grès 04"); pn2.catalogueId = gid("NTS-1"); pn2.rating = 4
    d.presets = [pn, pn2]
    var ks = KnobSheet(id: 1, gearId: gid("MicroFreak")); ks.sessionId = 1; ks.presetId = 1; ks.label = "Brume portuaire"
    ks.values = ["Type": "Karplus", "Wave": "6.5", "Timbre": "3", "Cutoff": "4.5", "Resonance": "7", "Attack": "8", "Decay": "6"]
    d.knobSheets = [ks]
    d.gearNotes = [GearNote(id: 1, gearId: gid("MicroFreak"), date: "2026-11-08", note: "Le Karplus aime une résonance haute et un cutoff à mi-course.")]
    d.gearPairings = [{ var x = GearPairing(id: 1, gearId: gid("MicroFreak"), partnerId: gid("Sonicake Smartbox")); x.note = "saturation + delay sale"; return x }()]
    d.tracks = [InspiringTrack(id: 1, title: "The Last Light"), InspiringTrack(id: 2, title: "Xerrox Phaenomenon")]
    d.tracks[0].artist = "Lustmord"; d.tracks[1].artist = "Alva Noto"
    d.inspirations = [Inspiration(id: 1, content: "Une ville qui respire par ses relais"), Inspiration(id: 2, content: "Le silence comme instrument")]
    d.mirack = [MiRackModule(id: 1, name: "Plaits"), MiRackModule(id: 2, name: "Clouds")]
    d.mirack[0].category = "Oscillateur"; d.mirack[0].mastered = true; d.mirack[1].category = "Effet"
    d.wishlist = [WishItem(id: 1, name: "Wasp"), WishItem(id: 2, name: "Digitone")]
    d.wishlist[0].manufacturer = "Behringer"; d.wishlist[0].price = 129; d.wishlist[0].priority = "Bientôt"
    d.wishlist[1].manufacturer = "Elektron"; d.wishlist[1].price = 749; d.wishlist[1].priority = "Rêve"
    let url = URL(fileURLWithPath: CommandLine.arguments[2])
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    // Journal de démo : images dithérées (charte Robōtariis) et une note audio synthétique.
    let media = url.deletingLastPathComponent().appendingPathComponent("journal-media")
    try FileManager.default.createDirectory(at: media, withIntermediateDirectories: true)
    func demoImage(_ name: String, seed: Int) throws {
        let w = 320, h = 220
        var px = [UInt8](repeating: 0, count: w * h * 4)
        let bayer: [[Double]] = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
        for y in 0..<h { for x in 0..<w {
            let fx = Double(x) / Double(w), fy = Double(y) / Double(h)
            let v = 0.5 + 0.5 * sin(fx * 6.0 + Double(seed)) * cos(fy * 4.0 + Double(seed) * 0.7) - fy * 0.35
            let on = v > (bayer[y % 4][x % 4] + 0.5) / 16
            let i = (y * w + x) * 4
            px[i] = on ? 0xF9 : 0x11; px[i + 1] = on ? 0x73 : 0x12; px[i + 2] = on ? 0x16 : 0x10; px[i + 3] = 255
        } }
        let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let dest = CGImageDestinationCreateWithURL(media.appendingPathComponent(name) as CFURL, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
        CGImageDestinationFinalize(dest)
    }
    try demoImage("demo-quai.png", seed: 1); try demoImage("demo-relais.png", seed: 4); try demoImage("demo-friche.png", seed: 7)
    // 2 s de drone (WAV 16 bits mono)
    var wav = Data(); let sr = 22050, n = sr * 2
    func le<T: FixedWidthInteger>(_ v: T) { withUnsafeBytes(of: v.littleEndian) { wav.append(contentsOf: $0) } }
    wav.append(contentsOf: Array("RIFF".utf8)); le(UInt32(36 + n * 2)); wav.append(contentsOf: Array("WAVEfmt ".utf8))
    le(UInt32(16)); le(UInt16(1)); le(UInt16(1)); le(UInt32(sr)); le(UInt32(sr * 2)); le(UInt16(2)); le(UInt16(16))
    wav.append(contentsOf: Array("data".utf8)); le(UInt32(n * 2))
    for i in 0..<n {
        let t = Double(i) / Double(sr)
        let v = 0.3 * sin(2 * .pi * 55 * t) + 0.15 * sin(2 * .pi * 82.4 * t) * sin(.pi * t / 2)
        le(Int16(max(-1, min(1, v)) * 30000))
    }
    try wav.write(to: media.appendingPathComponent("demo-drone.wav"))
    func entry(_ id: Int, _ date: String, _ title: String, _ body: String, mood: Int?, feelings: [String], assoc: [String],
               images: [String] = [], audio: Bool = false, session: Int? = nil, bookmark: Bool = false, prompt: String = "") -> DiaryEntry {
        var e = DiaryEntry(id: id, date: date)
        e.title = title; e.body = body; e.mood = mood; e.feelings = feelings; e.associations = assoc
        e.bookmarked = bookmark; e.prompt = prompt; e.place = "Scaër"
        e.attachments = images.map { DiaryAttachment(kind: .image, file: $0) }
        if audio { var a = DiaryAttachment(kind: .audio, file: "demo-drone.wav"); a.caption = "Le drone du quai, enregistré au téléphone"; e.attachments.append(a) }
        if let s = session { e.sessionIds = [s] }
        return e
    }
    d.diary = [
        entry(1, "2026-11-14 23:40:00", "Le quai, après la séance",
              "La nappe tenait encore dans ma tête en sortant. Le brouillard sur le quai avait exactement la texture du Karplus saturé.\n\nJe veux retrouver ce grain demain : résonance haute, cutoff à mi-course, et rien d'autre.",
              mood: 6, feelings: ["Inspiré", "Calme"], assoc: ["Musique", "Scaër"], images: ["demo-quai.png"], audio: true,
              session: 1, bookmark: true, prompt: "Qu'as-tu retenu de « MÉMOIRE RÉSIDUELLE » (2026-11-14) ?"),
        entry(2, "2026-11-13 19:05:00", "", "Journée lourde. Pas touché aux machines, mais j'ai relu les notes du Relais 3 et une scène s'est dessinée : la tour qui émet seule, la nuit, pour personne.",
              mood: 3, feelings: ["Fatigué", "Curieux"], assoc: ["Lore", "Travail"], images: ["demo-relais.png"]),
        entry(3, "2026-11-11 22:15:00", "Corrosion lente", "Trois prises, aucune bonne, mais la troisième avait un accident de 40 secondes qui vaut la soirée.",
              mood: 5, feelings: ["Concentré"], assoc: ["Musique"], session: 3),
        entry(4, "2026-11-09 16:30:00", "Friche ouest", "Marche jusqu'à la friche. Les tôles qui battent au vent : un séquenceur sans horloge.",
              mood: 6, feelings: ["Reconnaissant", "Curieux"], assoc: ["Nature", "Scaër"], images: ["demo-friche.png"]),
        entry(5, "2026-11-08 21:00:00", "", "Commence par la fin. Alors j'ai commencé par le silence final, et remonté jusqu'au premier son.",
              mood: 4, feelings: ["Calme"], assoc: ["Musique"], prompt: "Commence par la fin."),
    ]
    try JSONStorage(url: url).save(d)
    print("✓ démo : \(d.sessions.count) séances, \(d.patches.count) patch → \(url.path)")
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

// 13. Patcher lié au catalogue
var lk = Seed.initial()
let mfG = lk.catalogue.first { $0.name == "MicroFreak" }!
let ntsG = lk.catalogue.first { $0.name == "NTS-1" }!
var lp = PatchLayout(id: 1, name: "lié")
let n1 = lp.addNode(mfG.name, type: mfG.type, x: 0, y: 0, catalogueId: mfG.id)
let n2 = lp.addNode("NTS-1", type: "free", x: 300, y: 0)            // libre, même nom qu'une fiche
let n3 = lp.addNode("Pédale maison", type: "free", x: 600, y: 0)
let n4 = lp.addNode(ntsG.name, type: "machine", x: 0, y: 200, catalogueId: ntsG.id)
lp.nodes[3].color = "#123456"                                       // couleur choisie à la main
lk.patches = [lp]
check(lk.syncPatches() && lk.patches[0].node(n2)?.catalogueId == ntsG.id && lk.patches[0].node(n2)?.nodeType == "machine",
      "lien : nœud libre relié par son nom")
check(lk.patches[0].node(n3)?.catalogueId == nil, "lien : nom inconnu reste libre")
check(!lk.syncPatches(), "lien : synchro idempotente")
let mfI = lk.catalogue.firstIndex { $0.id == mfG.id }!
lk.catalogue[mfI].name = "MicroFreak MK2"; lk.catalogue[mfI].type = "synth_ios"
lk.syncPatches()
check(lk.patches[0].node(n1)?.label == "MicroFreak MK2" && lk.patches[0].node(n1)?.nodeType == "synth_ios"
      && lk.patches[0].node(n1)?.color == PatchVocab.color("synth_ios"), "lien : renommage et type suivis, couleur de type")
let ntsI = lk.catalogue.firstIndex { $0.id == ntsG.id }!
lk.catalogue[ntsI].type = "effet"; lk.syncPatches()
check(lk.patches[0].node(n4)?.color == "#123456" && lk.patches[0].node(n4)?.nodeType == "effet", "lien : couleur manuelle gardée")
lk.catalogue.remove(at: ntsI); lk.syncPatches()
check(lk.patches[0].node(n4)?.catalogueId == nil && lk.patches[0].node(n4)?.label == "NTS-1", "lien : fiche supprimée → nœud délié, gardé")
lk.patches[0].nodes[0].catalogueId = nil; lk.patches[0].nodes[0].detached = true; lk.patches[0].nodes[0].label = "Ableton Live"
lk.syncPatches()
check(lk.patches[0].nodes[0].catalogueId == nil, "lien : nœud délié à la main jamais relié d'office")
check(lk.patches(using: lk.catalogue.first { $0.name == "MicroFreak MK2" }?.id ?? -1).isEmpty
      && lk.patches(using: lk.catalogue.first { $0.name == "Ableton Live" }!.id).isEmpty, "lien : patches d'une fiche")

// 14. Récap, CSV, vault
var rs = Session(id: 8, date: "2026-11-14"); rs.machines = ["MicroFreak"]; rs.comments = "nappe, souffle"; rs.durationMin = 40
let pr = Recap.prompt(for: rs)
check(pr.contains("Machines : MicroFreak") && pr.contains("Notes live : nappe, souffle") && pr.contains("Effets : —")
      && !pr.contains("{"), "récap : prompt musique complet")
rs.sessionType = "veille"
check(Recap.prompt(for: rs).hasSuffix("Résumé :"), "récap : prompt veille")
let rq = Recap.request(for: rs, baseURL: "http://192.168.1.100:11434/", model: "m")
check(rq?.url?.absoluteString == "http://192.168.1.100:11434/api/generate" && rq?.httpMethod == "POST", "récap : requête")
check(Recap.request(for: rs, baseURL: "pas une url", model: "m") == nil, "récap : URL invalide refusée")
check((try? Recap.parse(Data(#"{"response":"  Le drone tenait.  "}"#.utf8), status: 200).get()) == "Le drone tenait.", "récap : réponse")
if case .failure(let e) = Recap.parse(Data(#"{"error":"model 'x' not found"}"#.utf8), status: 404) {
    check(e.message.contains("404") && e.message.contains("not found"), "récap : erreur lisible (modèle absent)")
} else { check(false, "récap : erreur lisible (modèle absent)") }
if case .failure = Recap.parse(Data(#"{"response":""}"#.utf8), status: 200) { check(true, "") } else { check(false, "récap : vide = erreur") }
var cd = AZAData(); var cs = Session(id: 1, date: "2026-11-14"); cs.comments = "ligne 1\n« ok », \"cité\""; cs.machines = ["A", "B"]
cd.sessions = [cs]
let csv = cd.csv()
check(csv.hasPrefix("\u{FEFF}id,session_type") && csv.contains("\"A, B\"") && csv.contains("\"ligne 1\n« ok », \"\"cité\"\"\""), "csv : échappement")
let vdir = work.appendingPathComponent("vault-export/Sessions")
check((try? cd.exportToVault(cs, folder: vdir, version: "t")) == "session_20261114_1.md"
      && FileManager.default.fileExists(atPath: vdir.appendingPathComponent("session_20261114_1.md").path), "vault : fichier écrit")

// 15. Journal
var jd = Seed.initial()
var je = DiaryEntry(id: 1, date: "2026-11-14 22:00:00"); je.body = "Première ligne\nLa suite du texte ici."
check(je.displayTitle == "Première ligne" && je.excerpt == "La suite du texte ici." && je.wordCount == 7, "journal : titre et extrait")
je.title = "Nuit"; check(je.displayTitle == "Nuit" && je.excerpt.hasPrefix("Première"), "journal : titre saisi")
jd.diary = [je, DiaryEntry(id: 2, date: "2026-11-13 10:00:00"), DiaryEntry(id: 3, date: "2026-11-12 10:00:00"),
            DiaryEntry(id: 4, date: "2026-11-05 10:00:00")]
jd.diary[1].mood = 6; jd.diary[2].mood = 2; jd.diary[1].feelings = ["Calme"]; jd.diary[2].feelings = ["Calme", "Fatigué"]
let jins = jd.diaryInsights(today: Clock.day("2026-11-14")!)
check(jins.streak == 3 && jins.longestStreak == 3 && jins.entriesThisYear == 4 && jins.moodAverage == 4
      && jins.feelings.first?.0 == "Calme", "journal : aperçu (série, humeur, ressentis)")
check(jd.diaryInsights(today: Clock.day("2026-11-15")!).streak == 3 && jd.diaryInsights(today: Clock.day("2026-11-16")!).streak == 0,
      "journal : série tolère « pas encore écrit aujourd'hui »")
check(jd.diarySearch("suite").map(\.id) == [1] && jd.diarySearch("CALME").count == 2 && jd.diarySearch("").first?.id == 1,
      "journal : recherche")
var js = Session(id: 9, date: "2026-11-13"); js.title = "NODE SCAER-7"; jd.sessions = [js]
let jp = jd.diaryPrompts(today: Clock.day("2026-11-14")!, lore: ["Une citation du lore."])
check(jp.contains { $0.sessionId == 9 } && jp.contains { $0.kind == "Lore" } && jp.contains { $0.kind == "Réflexion" },
      "journal : suggestions (séance récente, lore, réflexions)")
jd.diary[0].sessionIds = [9]
check(!jd.diaryPrompts(today: Clock.day("2026-11-14")!).contains { $0.sessionId == 9 }, "journal : pas de suggestion pour une séance déjà racontée")
jd.diary[0].mood = 6; jd.diary[0].attachments = [DiaryAttachment(kind: .image, file: "x.png")]
let jmd = jd.diaryMarkdown(jd.diary[0])
check(jmd.hasPrefix("---\ndate: 2026-11-14 22:00:00") && jmd.contains("humeur: 6") && jmd.contains("![[x.png]]")
      && jmd.contains("NODE SCAER-7"), "journal : export Markdown (frontmatter, médias, liens)")
check(DiaryAttachment.kind(forExtension: "HEIC") == .image && DiaryAttachment.kind(forExtension: "m4a") == .audio, "journal : type de média")
check(try JSONStorage.decode(JSONStorage.encode(jd)) == jd, "journal : aller-retour JSON")
check(try JSONStorage.decode(Data(#"{"diary":[{"id":3}]}"#.utf8)).diary.first?.feelings == [], "journal : décodage tolérant")

// 16. Synchro / sauvegarde iCloud Drive (dossiers temporaires, pas le vrai iCloud)
let syncRoot = work.appendingPathComponent("sync")
let local = syncRoot.appendingPathComponent("local/aza-sessions.json")
let cloud = syncRoot.appendingPathComponent("cloud/AZA Sessions/aza-sessions.json")
try FileManager.default.createDirectory(at: local.deletingLastPathComponent().appendingPathComponent("journal-media"), withIntermediateDirectories: true)
try Data("{\"format\":1}".utf8).write(to: local)
try Data("img".utf8).write(to: local.deletingLastPathComponent().appendingPathComponent("journal-media/a.png"))
try DataFolder.copy(json: local, to: cloud, overwriteJSON: false)
check(FileManager.default.fileExists(atPath: cloud.path)
      && FileManager.default.fileExists(atPath: cloud.deletingLastPathComponent().appendingPathComponent("journal-media/a.png").path),
      "icloud : copie JSON + médias")
try Data("autre mac".utf8).write(to: cloud)
try DataFolder.copy(json: local, to: cloud, overwriteJSON: false)
check((try? String(contentsOf: cloud, encoding: .utf8)) == "autre mac", "icloud : JSON existant non écrasé (useExisting)")
try DataFolder.copy(json: local, to: cloud, overwriteJSON: true)
check((try? String(contentsOf: cloud, encoding: .utf8)) == "{\"format\":1}", "icloud : JSON remplacé si demandé")
let evicted = syncRoot.appendingPathComponent("cloud/AZA Sessions/x.json")
try Data().write(to: CloudDrive.placeholder(for: evicted))
check(CloudDrive.isEvicted(evicted) && !CloudDrive.isEvicted(cloud) && CloudDrive.placeholder(for: evicted).lastPathComponent == ".x.json.icloud",
      "icloud : fichier déchargé détecté")
for n in ["aza-sessions 2.json", "aza-sessions 3.json", "aza-sessions-notes.json", "aza-sessions 2.txt"] {
    try Data().write(to: cloud.deletingLastPathComponent().appendingPathComponent(n))
}
check(CloudDrive.conflictCopies(of: cloud).map(\.lastPathComponent) == ["aza-sessions 2.json", "aza-sessions 3.json"], "icloud : copies de conflit")
check(FileFingerprint(data: Data("a".utf8)) != FileFingerprint(data: Data("b".utf8))
      && FileFingerprint.of(cloud) == FileFingerprint(data: (try? Data(contentsOf: cloud)) ?? Data()), "icloud : empreinte")
let bdir = syncRoot.appendingPathComponent("backups-cloud")
let media = local.deletingLastPathComponent().appendingPathComponent("journal-media")
let r1 = try CloudBackup.run(json: local, media: media, into: bdir, now: Clock.day("2026-11-10")!)
let r2 = try CloudBackup.run(json: local, media: media, into: bdir, now: Clock.day("2026-11-11")!)
check(r1.file?.lastPathComponent == "aza-sessions-2026-11-10.json" && r1.mediaCopied == 1 && r2.file == nil && r2.mediaCopied == 0,
      "icloud : sauvegarde du jour, rien si inchangé")
for day in 12...20 {
    try Data("v\(day)".utf8).write(to: local)
    _ = try CloudBackup.run(json: local, media: media, into: bdir, keep: 5, now: Clock.day("2026-11-\(day)")!)
}
check(CloudBackup.list(bdir).count == 5 && CloudBackup.list(bdir).first?.lastPathComponent == "aza-sessions-2026-11-20.json",
      "icloud : rétention des sauvegardes")

// 17. Annuler / historique
var z_hist = EditHistory()
var z_h0 = Seed.initial(); var z_h1 = z_h0; z_h1.sessions.append(Session(id: 1, date: "2026-11-17"))
let z_t0 = Date(timeIntervalSince1970: 1000)
z_hist.record(before: z_h0, after: z_h1, at: z_t0)
var z_h2 = z_h1; z_h2.sessions[0].title = "A"
z_hist.record(before: z_h1, after: z_h2, at: z_t0.addingTimeInterval(0.5))        // même geste : regroupé
var z_h3 = z_h2; z_h3.diary.append(DiaryEntry(id: 1))
z_hist.record(before: z_h2, after: z_h3, at: z_t0.addingTimeInterval(0.8))        // autre partie : nouvelle étape
check(z_hist.undoStack.count == 2 && z_hist.undoLabel == "journal", "annuler : regroupement et libellé")
let z_u1 = z_hist.undo(current: z_h3)
check(z_u1 == z_h2 && z_hist.undoLabel == "séances" && z_hist.redoLabel == "journal", "annuler : retour d'une étape")
let z_u2 = z_hist.undo(current: z_u1!)
check(z_u2 == z_h0 && !z_hist.canUndo, "annuler : le geste regroupé s'annule d'un coup")
check(z_hist.redo(current: z_u2!) == z_h2 && z_hist.redo(current: z_h2) == z_h3 && !z_hist.canRedo, "rétablir")
z_hist.record(before: z_h3, after: z_h0, at: z_t0.addingTimeInterval(10))
check(!z_hist.canRedo, "annuler : une nouvelle modification efface « rétablir »")
var z_lim = EditHistory(); z_lim.limit = 3
for i in 0..<6 { var x = z_h0; x.obliques.removeLast(i); z_lim.record(before: z_h0, after: x, at: z_t0.addingTimeInterval(Double(i) * 10)) }
check(z_lim.undoStack.count == 3, "annuler : limite de la pile")

var z_bk = Seed.initial()
var z_sA = Session(id: 1, date: "2026-11-01"); z_sA.title = "Gardée"
var z_sB = Session(id: 2, date: "2026-11-02"); z_sB.title = "Supprimée depuis"
var z_sC = Session(id: 3, date: "2026-11-03"); z_sC.title = "Avant modif"
z_bk.sessions = [z_sA, z_sB, z_sC]; z_bk.diary = [DiaryEntry(id: 4)]
var z_now = z_bk; z_now.sessions.removeAll { $0.id == 2 }; z_now.sessions[1].title = "Après modif"
z_now.sessions.append(Session(id: 9, date: "2026-11-17")); z_now.diary = []; z_now.obliques.removeLast()
let z_df = z_now.diff(fromBackup: z_bk)
let z_ds = z_df.parts.first { $0.name == "Séances" }!
check(z_ds.onlyInBackup == [2] && z_ds.onlyInCurrent == [9] && z_ds.changed == [3]
      && z_df.parts.first { $0.name == "Journal" }!.onlyInBackup == [4] && z_df.otherChanges == ["stratégies"], "historique : différences")
check(z_bk.diff(fromBackup: z_bk).isEmpty, "historique : identique")
var z_rec = z_now
check(z_rec.recover(sessions: [2, 3], diary: [4], from: z_bk) == 3, "historique : récupération")
check(z_rec.sessions.contains { $0.id == 2 && $0.title == "Supprimée depuis" }
      && z_rec.sessions.contains { $0.title == "Avant modif (restaurée)" && $0.id != 3 && $0.linkedSession == 3 }
      && z_rec.sessions.first { $0.id == 3 }?.title == "Après modif" && z_rec.diary.count == 1,
      "historique : supprimée revient, modifiée revient à côté")

// 18. Recherche globale
var gs = Seed.initial()
var gs1 = Session(id: 1, date: "2026-11-10"); gs1.title = "MÉMOIRE RÉSIDUELLE"; gs1.machines = ["MicroFreak"]
gs1.comments = "Une longue nappe sur le quai de Scaër, le Karplus saturé derrière."
var gs2 = Session(id: 2, date: "2026-11-12"); gs2.title = "Corrosion lente"; gs2.machines = ["NTS-1"]
gs.sessions = [gs1, gs2]
var gse = DiaryEntry(id: 1, date: "2026-11-13 20:00:00"); gse.body = "Retour du quai, brouillard épais.\nLa mémoire des machines."
gs.diary = [gse]
check(gs.globalSearch("scaer").first?.kind == .session, "recherche : sans accents (Scaër)")
check(gs.globalSearch("MEMOIRE").first?.ref == "1" && gs.globalSearch("MEMOIRE").first?.kind == .session,
      "recherche : le titre passe avant le texte")
check(Set(gs.globalSearch("quai").map(\.kind)) == [.session, .diary], "recherche : séances et journal")
check(gs.globalSearch("quai karplus").map(\.kind) == [.session], "recherche : tous les mots requis")
check(gs.globalSearch("microfreak").contains { $0.kind == .gear && $0.title == "MicroFreak" }
      && gs.globalSearch("microfreak").first?.kind == .gear, "recherche : fiche catalogue en tête sur son nom")
check(gs.globalSearch("   ").isEmpty && gs.globalSearch("zzzz").isEmpty, "recherche : vide / rien")
let snip = SearchText.snippet(String(repeating: "abc ", count: 60) + "le mot Karplus ici " + String(repeating: "xyz ", count: 60), terms: ["karplus"])
check(snip.hasPrefix("…") && snip.contains("Karplus") && snip.hasSuffix("…") && snip.count < 130, "recherche : extrait autour du mot")
check(gs.globalSearch("strategie").isEmpty == false || gs.globalSearch("machine").contains { $0.kind == .oblique }, "recherche : stratégies obliques")

print(failures == 0 ? "✓ aza-check : \(passed) vérifications OK" : "✗ aza-check : \(failures) échec(s), \(passed) OK")
exit(failures == 0 ? 0 : 1)
