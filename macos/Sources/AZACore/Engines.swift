import Foundation

public func nextId<T: Identifiable>(_ items: [T]) -> Int where T.ID == Int {
    (items.map(\.id).max() ?? 0) + 1
}

// MARK: - Titres dans l'esthétique d'AZA (core/lore_names.py)

public enum Titles {
    static let nomsF = ["MÉMOIRE", "SÉQUENCE", "VEILLE", "CORROSION", "CONSIGNE", "ARCHIVE", "STRATE",
                        "LATENCE", "DÉRIVE", "RELIQUE", "CENDRE", "BALISE", "RUMEUR", "POUSSIÈRE",
                        "FRACTURE", "ORNIÈRE"]
    static let nomsM = ["FRAGMENT", "RÉSIDU", "SIGNAL", "PROTOCOLE", "SILENCE", "CIRCUIT", "INVENTAIRE", "SOMMEIL"]
    static var noms: [String] { nomsF + nomsM }
    static let adjF = ["RÉSIDUELLE", "LENTE", "MÉCANIQUE", "OUBLIÉE", "CONTINUE", "BASSE", "PROVISOIRE",
                       "SOUTERRAINE", "CONFORME", "DIFFÉRÉE", "MUETTE", "ANCIENNE", "SATURÉE",
                       "ADMINISTRATIVE", "INTERDITE", "TARDIVE", "RÉTIVE", "SCELLÉE", "NOCTURNE", "MINÉRALE"]
    static let adjM = ["RÉSIDUEL", "LENT", "MÉCANIQUE", "OUBLIÉ", "CONTINU", "BAS", "PROVISOIRE",
                       "SOUTERRAIN", "CONFORME", "DIFFÉRÉ", "MUET", "ANCIEN", "SATURÉ", "ADMINISTRATIF",
                       "INTERDIT", "TARDIF", "RÉTIF", "SCELLÉ", "NOCTURNE", "MINÉRAL"]
    static let lieux = ["SCAER", "KERGLAZ", "ROSPORDEN", "BASE-12", "SECTEUR-NORD", "RELAIS-3",
                        "FRICHE-OUEST", "HANGAR-9", "TOUR-SUD", "LIGNE-4"]
    static let codes = ["CDX", "CGU", "RBT", "CAL", "A0", "CLU", "ARX", "OBS"]

    static func objet<G: RandomNumberGenerator>(_ r: inout G) -> String {
        let fem = Double.random(in: 0..<1, using: &r) < Double(nomsF.count) / Double(noms.count)
        let nom = (fem ? nomsF : nomsM).randomElement(using: &r)!
        let i = Int.random(in: 0..<adjF.count, using: &r)
        return "\(nom) \((fem ? adjF : adjM)[i])"
    }

    public static func propose(_ n: Int = 5) -> [String] {
        var g = SystemRandomNumberGenerator()
        return propose(n, using: &g)
    }

    public static func propose<G: RandomNumberGenerator>(_ n: Int, using r: inout G) -> [String] {
        let n = max(1, min(n, 20))
        var motifs = [0, 1, 2, 3, 4]
        motifs.shuffle(using: &r)
        var out: [String] = []
        for i in 0..<(n * 12) where out.count < n {
            let t: String
            switch motifs[i % motifs.count] {
            case 0: t = objet(&r)
            case 1: t = "\(noms.randomElement(using: &r)!)-\(String(format: "%02d", Int.random(in: 1..<100, using: &r)))"
            case 2: t = "NODE \(lieux.randomElement(using: &r)!)-\(Int.random(in: 1..<20, using: &r))"
            case 3: t = "\(codes.randomElement(using: &r)!)-\(String(format: "%02d", Int.random(in: 1..<100, using: &r))) / \(objet(&r))"
            default: t = "A.\(Int.random(in: 1..<400, using: &r)) — \(noms.randomElement(using: &r)!)"
            }
            if !out.contains(t) { out.append(t) }
        }
        return out
    }
}

// MARK: - Tirage du soir (core/tirage.py)

public struct Draw: Sendable {
    public var instrument: GearItem?
    public var treatment: GearItem?
    public var oblique: String
    public var title: String
    public var take: String
    public var isEmpty: Bool { instrument == nil && treatment == nil }
}

public extension AZAData {
    static let drawInstruments: Set<String> = ["machine", "synth_ios", "app_ios", "ipad", "zynthian"]
    static let drawTreatments: Set<String> = ["effet", "plugin", "plugin_ios"]

    /// Un instrument, un traitement, une contrainte, un titre, un nom de prise.
    /// Les favoris sont tirés deux fois plus souvent.
    func draw() -> Draw {
        func pick(_ types: Set<String>) -> GearItem? {
            let pool = catalogue.filter { $0.active && !$0.noDraw && types.contains($0.type) }
            return (pool + pool.filter(\.favorite)).randomElement()
        }
        let i = pick(Self.drawInstruments), t = pick(Self.drawTreatments)
        var s = Session(id: -1, date: Clock.today())
        if let i { s.machines = [i.name] }
        if let t { s.effects = [t.name] }
        return Draw(instrument: i, treatment: t, oblique: randomOblique() ?? "",
                    title: Titles.propose(1).first ?? "", take: takeName(for: s))
    }

    // MARK: Registre des prises (takes/engine.py)

    struct TakeGroup: Identifiable, Sendable {
        public var id: String { key }
        public let key: String
        public let name: String
        public let sessions: [Session]
        public var duplicate: Bool { sessions.count > 1 }
    }

    /// Prises nommées groupées par nom normalisé (casse), la plus récente d'abord.
    func takeRegistry() -> [TakeGroup] {
        let named = sessions.filter { !$0.audioFile.trimmingCharacters(in: .whitespaces).isEmpty }
            .sorted { $0.date > $1.date }
        var order: [String] = []
        var groups: [String: [Session]] = [:]
        for s in named {
            let k = s.audioFile.trimmingCharacters(in: .whitespaces).uppercased()
            if groups[k] == nil { order.append(k) }
            groups[k, default: []].append(s)
        }
        return order.map { TakeGroup(key: $0, name: groups[$0]![0].audioFile.trimmingCharacters(in: .whitespaces),
                                     sessions: groups[$0]!) }
            .sorted { $0.sessions[0].date > $1.sessions[0].date }
    }

    // MARK: Carnet d'instrument

    /// Associations d'une fiche, lues des deux côtés.
    func pairings(of gearId: Int) -> [(pairing: GearPairing, partner: GearItem)] {
        gearPairings.compactMap { p in
            let other = p.gearId == gearId ? p.partnerId : (p.partnerId == gearId ? p.gearId : nil)
            guard let other, let g = catalogue.first(where: { $0.id == other }) else { return nil }
            return (p, g)
        }
    }

    func gear(_ id: Int?) -> GearItem? {
        guard let id else { return nil }
        return catalogue.first { $0.id == id }
    }
}

// MARK: - Proposition de codes catalogue (CatalogueEngine.propose_codes)

public enum CodeProposer {
    static let vowels = Set("AEIOUY")

    static func words(_ name: String) -> [String] {
        var s = name.folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
        // Majuscules internes et frontière lettre/chiffre : MicroFreak → MICRO FREAK
        var out = ""
        var prev: Character?
        for ch in s {
            if let p = prev {
                if (p.isLowercase && ch.isUppercase) || (p.isLetter && ch.isNumber) { out.append(" ") }
            }
            out.append(ch); prev = ch
        }
        s = out.uppercased()
        return s.split { !($0.isASCII && ($0.isLetter || $0.isNumber)) }.map(String.init)
    }

    public static func candidates(_ name: String, size: Int = 3) -> [String] {
        let ws = words(name)
        guard !ws.isEmpty else { return [] }
        let digits = ws.joined().filter(\.isNumber)
        let letters = ws.filter { !$0.allSatisfy(\.isNumber) }

        func grow(_ base: String, _ sources: [String]) -> String {
            var out = base
            for pass in 0..<2 {
                for w in sources {
                    for ch in w.dropFirst() {
                        if out.count >= size { return out }
                        if pass == 0 ? (ch.isLetter && !vowels.contains(ch)) : ch.isLetter { out.append(ch) }
                    }
                }
            }
            return out
        }
        let initials = String(letters.compactMap(\.first))
        let lastFirst = Array(letters.suffix(1) + letters.dropLast())
        var out: [String] = []
        if let d = digits.first {
            out.append(String(grow(String(initials.prefix(size - 1)), lastFirst).prefix(size - 1)) + String(d))
        }
        out.append(grow(String(initials.prefix(size)), lastFirst))
        out.append(grow(String(initials.prefix(1)), letters))
        if letters.count >= 2 {
            out.append(grow(String([letters[0].first!, letters[1].first!]), Array(letters.dropFirst())))
        }
        for w in letters.dropFirst() { out.append(grow(String(initials.prefix(1)) + String(w.first!), [w])) }
        for ch in (letters.first?.dropFirst() ?? "") { out.append(grow(String(initials.prefix(1)) + String(ch), letters)) }
        for d in "23456789" {
            let head = String(grow(String(initials.prefix(1)), letters).prefix(size - 1))
            out.append((head.isEmpty ? "X" : head) + String(d))
        }
        var seen = Set<String>(), clean: [String] = []
        for c in out {
            let c2 = String(c.filter { $0.isASCII && ($0.isLetter || $0.isNumber) })
            if c2.count == size && seen.insert(c2).inserted { clean.append(c2) }
        }
        return clean
    }

    /// `{id: code}` pour chaque fiche active sans code. Les codes existants sont intouchables.
    public static func propose(_ catalogue: [GearItem], size: Int = 3) -> [Int: String] {
        let prio = ["machine": 0, "effet": 1, "synth_ios": 2, "plugin": 3]
        let rows = catalogue.filter(\.active).sorted {
            (prio[$0.type] ?? 9, $0.name.lowercased()) < (prio[$1.type] ?? 9, $1.name.lowercased())
        }
        var taken = Set(rows.map { $0.code.trimmingCharacters(in: .whitespaces).uppercased() }.filter { !$0.isEmpty })
        var out: [Int: String] = [:]
        for g in rows where g.code.trimmingCharacters(in: .whitespaces).isEmpty {
            if let c = candidates(g.name, size: size).first(where: { !taken.contains($0) }) {
                taken.insert(c); out[g.id] = c
            }
        }
        return out
    }
}

// MARK: - Spark (spark/engine.py)

public struct Spark: Identifiable, Hashable, Sendable {
    public var id: String { kind + "|" + text }
    public let icon: String
    public let kind: String
    public let text: String
    public let sub: String
}

public extension AZAData {
    private func usage(_ kp: KeyPath<Session, [String]>) -> [String: Int] {
        var c: [String: Int] = [:]
        for s in sessions { for x in s[keyPath: kp] { c[x, default: 0] += 1 } }
        return c
    }

    func sparks() -> [Spark] {
        let total = sessions.count
        var out: [Spark] = []
        func pl(_ n: Int) -> String { n > 1 ? "s" : "" }
        if total >= 3 {
            let threshold = max(1, Double(total) * 0.25)
            for (kp, icon, kind) in [(\Session.machines, "⚙", "Machine sous-utilisée"),
                                     (\Session.effects, "~", "Effet hardware oublié"),
                                     (\Session.synthsIOS, "📱", "Synthé iOS à explorer")] {
                let u = usage(kp)
                if let pick = u.filter({ Double($0.value) < threshold }).keys.randomElement() {
                    out.append(Spark(icon: icon, kind: kind, text: pick,
                                     sub: "Utilisé\(kp == \Session.machines ? "e" : "") dans \(u[pick]!) session\(pl(u[pick]!)) sur \(total)"))
                }
            }
            let usedI = Set(sessions.map(\.intention))
            if let i = Vocab.intentions.filter({ !usedI.contains($0) }).randomElement() {
                out.append(Spark(icon: "◎", kind: "Intention jamais explorée", text: i,
                                 sub: "Tu n'as jamais enregistré de session avec cette intention"))
            }
            let usedC = Set(sessions.flatMap(\.character))
            if let c = Vocab.characters.filter({ !usedC.contains($0) }).randomElement() {
                out.append(Spark(icon: "◈", kind: "Caractère sonore inexploré", text: c,
                                 sub: "Aucune session avec ce caractère dans ta base"))
            }
        }
        for m in mirack.filter({ !$0.mastered }).shuffled().prefix(2) {
            out.append(Spark(icon: "⬡", kind: "Module MiRack à maîtriser", text: m.name,
                             sub: m.category.isEmpty ? "Module non classifié" : m.category))
        }
        for i in inspirations.filter({ $0.type == "Idée" }).shuffled().prefix(2) {
            out.append(Spark(icon: "💡", kind: "Idée en vrac", text: i.content,
                             sub: i.source.isEmpty ? "Pioche dans tes idées" : i.source))
        }
        if let i = inspirations.filter({ $0.type != "Idée" }).randomElement() {
            out.append(Spark(icon: "∴", kind: "Inspiration — \(i.type)", text: "« \(i.content) »", sub: i.source))
        }
        if let t = tracks.randomElement() {
            out.append(Spark(icon: "♪", kind: "Réécoute ce morceau",
                             text: t.title + (t.artist.isEmpty ? "" : " — \(t.artist)"),
                             sub: t.notes.isEmpty ? t.tags : t.notes))
        }
        if let o = randomOblique() {
            out.append(Spark(icon: "∴", kind: "Stratégie AZA", text: o, sub: "Laisse la machine te guider"))
        }
        return out.shuffled()
    }
}

// MARK: - Statistiques (stats/engine.py)

public struct Stats: Sendable {
    /// En dessous, pas de tendance : une moyenne sur trois points n'en est pas une.
    public static let minPoints = 5

    public var total = 0, totalMinutes = 0, avgDuration = 0, thisMonth = 0
    public var releaseCount = 0, reworkCount = 0, streak = 0, maxStreak = 0
    public var monthly: [(String, Int)] = []
    public var monthlyRating: [(String, Double)] = []
    public var monthlyEnergy: [(String, Double)] = []
    public var ratingDist: [(Int, Int)] = []
    public var energyDist: [(Int, Int)] = []
    public var top: [(label: String, items: [(String, Int)])] = []
    public var modes: [(String, Int)] = []
    public var intentions: [(String, Int)] = []
    public var projects: [(String, Int)] = []
    public var heatmap: [String: Int] = [:]
    public var durationRating: [(Int, Int)] = []
    public var best: Session?
    public var longest: Session?
}

public extension AZAData {
    func stats(today: Date = Date()) -> Stats? {
        guard !sessions.isEmpty else { return nil }
        var st = Stats()
        st.total = sessions.count
        func counts(_ kp: KeyPath<Session, [String]>) -> [(String, Int)] {
            usage(kp).sorted { ($0.value, $1.key) > ($1.value, $0.key) }.prefix(15).map { ($0.key, $0.value) }
        }
        func tally(_ xs: [String]) -> [(String, Int)] {
            Dictionary(xs.filter { !$0.isEmpty }.map { ($0, 1) }, uniquingKeysWith: +)
                .sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
        }
        let durations = sessions.compactMap(\.durationMin).filter { $0 > 0 }
        st.totalMinutes = durations.reduce(0, +)
        st.avgDuration = durations.isEmpty ? 0 : Int((Double(st.totalMinutes) / Double(durations.count)).rounded())
        st.releaseCount = sessions.filter(\.releasePotential).count
        st.reworkCount = sessions.filter(\.toRework).count
        st.ratingDist = (1...5).map { r in (r, sessions.filter { $0.rating == r }.count) }
        st.energyDist = (1...3).map { e in (e, sessions.filter { $0.energyLevel == e }.count) }
        let months = Dictionary(sessions.map { (String($0.date.prefix(7)), 1) }, uniquingKeysWith: +)
        st.monthly = months.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
        st.thisMonth = months[String(Clock.day(today).prefix(7))] ?? 0

        func avgByMonth(_ f: (Session) -> Int?) -> [(String, Double)] {
            var by: [String: [Int]] = [:]
            for s in sessions { if let v = f(s), v > 0 { by[String(s.date.prefix(7)), default: []].append(v) } }
            return by.sorted { $0.key < $1.key }
                .map { ($0.key, (Double($0.value.reduce(0, +)) / Double($0.value.count) * 100).rounded() / 100) }
        }
        if sessions.filter({ ($0.rating ?? 0) > 0 }).count >= Stats.minPoints { st.monthlyRating = avgByMonth(\.rating) }
        if sessions.filter({ ($0.energyLevel ?? 0) > 0 }).count >= Stats.minPoints { st.monthlyEnergy = avgByMonth(\.energyLevel) }
        let cloud = sessions.compactMap { s -> (Int, Int)? in
            guard let d = s.durationMin, d > 0, let r = s.rating, r > 0 else { return nil }
            return (d, r)
        }
        if cloud.count >= Stats.minPoints { st.durationRating = cloud }

        st.top = [("Machines", counts(\.machines)), ("Effets", counts(\.effects)), ("DAW", counts(\.daws)),
                  ("Synthés iOS", counts(\.synthsIOS)), ("Plugins", counts(\.plugins)),
                  ("Influences", counts(\.influences)), ("Caractère", counts(\.character))]
            .filter { !$0.1.isEmpty }.map { (label: $0.0, items: $0.1) }
        st.modes = tally(sessions.map(\.mode))
        st.intentions = tally(sessions.map(\.intention))
        st.projects = projects.map { p in (p.title, sessions.filter { $0.projectId == p.id }.count) }
            .filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }

        for s in sessions { st.heatmap[String(s.date.prefix(10)), default: 0] += 1 }
        // Série en cours : jours consécutifs joués, la série pouvant finir
        // aujourd'hui ou hier (la séance du jour n'est peut-être pas encore faite).
        // Record : plus longue série sur l'année écoulée.
        let cal = Calendar(identifier: .gregorian)
        let start = cal.startOfDay(for: today)
        func played(_ d: Date) -> Bool { (st.heatmap[Clock.day(d)] ?? 0) > 0 }
        var d = played(start) ? start : cal.date(byAdding: .day, value: -1, to: start)!
        while played(d) { st.streak += 1; d = cal.date(byAdding: .day, value: -1, to: d)! }
        var cur = 0
        for back in 0...366 {
            let day = cal.date(byAdding: .day, value: -back, to: start)!
            if played(day) { cur += 1; st.maxStreak = max(st.maxStreak, cur) } else { cur = 0 }
        }
        st.best = sessions.max { ($0.rating ?? 0, $0.durationMin ?? 0) < ($1.rating ?? 0, $1.durationMin ?? 0) }
        st.longest = sessions.max { ($0.durationMin ?? 0) < ($1.durationMin ?? 0) }
        return st
    }
}
