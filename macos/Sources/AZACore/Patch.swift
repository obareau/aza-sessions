import Foundation

// Patcher : carte du routing signal entre machines (patcher/engine.py).

public enum PatchVocab {
    public static let nodeColors: [String: String] = [
        "machine": "#D4380D", "effet": "#8B0000", "daw": "#1A3A6B",
        "synth_ios": "#1D5C2E", "plugin": "#4A1A6B", "free": "#3A3A3A",
    ]
    public static let nodeIcons: [String: String] = [
        "machine": "⚙", "effet": "≈", "daw": "▣", "synth_ios": "⊞", "plugin": "◉", "free": "◇",
    ]
    public static let signals = ["audio", "midi", "cv", "usb", "autre"]
    public static let signalColors: [String: String] = [
        "audio": "#D4380D", "midi": "#2563EB", "cv": "#16A34A", "usb": "#9333EA", "autre": "#6B7280",
    ]
    static let mermaidArrows = ["audio": "-->", "midi": "-.->", "cv": "==>", "usb": "--x", "autre": "-->"]

    public static func icon(_ type: String) -> String { nodeIcons[type] ?? "◈" }

    /// Couleur d'un type : connue, sinon teinte déterministe tirée du nom (comme typeColor() en JS).
    public static func color(_ type: String) -> String {
        if let c = nodeColors[type] { return c }
        var h: UInt32 = 0
        for u in type.utf16 { h = (h &* 31 &+ UInt32(u)) & 0xFFFFFF }
        return hslHex(Double(h % 360), 0.45, 0.42)
    }

    static func hslHex(_ h: Double, _ s: Double, _ l: Double) -> String {
        let c = (1 - abs(2 * l - 1)) * s
        let x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = l - c / 2
        let (r, g, b): (Double, Double, Double) = switch h {
        case ..<60: (c, x, 0)
        case ..<120: (x, c, 0)
        case ..<180: (0, c, x)
        case ..<240: (0, x, c)
        case ..<300: (x, 0, c)
        default: (c, 0, x)
        }
        return String(format: "#%02X%02X%02X", Int((r + m) * 255), Int((g + m) * 255), Int((b + m) * 255))
    }
}

public struct PatchNode: Codable, Identifiable, Hashable, Sendable {
    public var id: Int
    public var label: String
    public var x: Double = 100
    public var y: Double = 100
    public var nodeType = "free"
    public var color = "#3A3A3A"
    public var catalogueId: Int?
    public var note = ""
    /// Délié à la main : ne pas le relier automatiquement par son nom.
    public var detached = false

    public init(id: Int, label: String, nodeType: String = "free", x: Double = 100, y: Double = 100) {
        self.id = id; self.label = label; self.nodeType = nodeType; self.x = x; self.y = y
        color = PatchVocab.color(nodeType)
    }
    enum CodingKeys: String, CodingKey { case id, label, x, y, nodeType, color, catalogueId, note, detached }
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        label = c.v(.label, ""); x = c.v(.x, 100); y = c.v(.y, 100); nodeType = c.v(.nodeType, "free")
        color = c.v(.color, PatchVocab.color(nodeType)); catalogueId = c.v(.catalogueId, nil); note = c.v(.note, "")
        detached = c.v(.detached, false)
    }

    /// Taille du nœud, mêmes règles que le canvas web.
    public var width: Double { max(130, Double(label.count) * 7 + 44) }
    public var height: Double { note.trimmingCharacters(in: .whitespaces).isEmpty ? 42 : 58 }
    public var centerX: Double { x + width / 2 }
    public var centerY: Double { y + height / 2 }
}

public struct PatchConnection: Codable, Identifiable, Hashable, Sendable {
    public var id: Int
    public var fromId: Int
    public var toId: Int
    public var label = ""
    public var signalType = "audio"
    public var note = ""

    public init(id: Int, fromId: Int, toId: Int, signalType: String = "audio") {
        self.id = id; self.fromId = fromId; self.toId = toId; self.signalType = signalType
    }
    enum CodingKeys: String, CodingKey { case id, fromId, toId, label, signalType, note }
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        fromId = c.v(.fromId, 0); toId = c.v(.toId, 0); label = c.v(.label, "")
        signalType = c.v(.signalType, "audio"); note = c.v(.note, "")
    }
}

public struct PatchLayout: Codable, Identifiable, Hashable, Sendable {
    public var id: Int
    public var name: String
    public var sessionId: Int?
    public var nodes: [PatchNode] = []
    public var connections: [PatchConnection] = []
    public var createdAt = Clock.stamp()

    public init(id: Int, name: String) { self.id = id; self.name = name }
    enum CodingKeys: String, CodingKey { case id, name, sessionId, nodes, connections, createdAt }
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = c.v(.name, "Patch"); sessionId = c.v(.sessionId, nil)
        nodes = c.v(.nodes, []); connections = c.v(.connections, []); createdAt = c.v(.createdAt, Clock.stamp())
    }

    public func node(_ id: Int) -> PatchNode? { nodes.first { $0.id == id } }

    // MARK: Ajouts

    @discardableResult
    public mutating func addNode(_ label: String, type: String, x: Double, y: Double, catalogueId: Int? = nil) -> Int {
        var n = PatchNode(id: nextId(nodes), label: label, nodeType: type, x: x, y: y)
        n.catalogueId = catalogueId
        nodes.append(n)
        return n.id
    }

    @discardableResult
    public mutating func connect(_ a: Int, _ b: Int, signal: String) -> Int? {
        guard a != b, node(a) != nil, node(b) != nil else { return nil }
        let c = PatchConnection(id: nextId(connections), fromId: a, toId: b, signalType: signal)
        connections.append(c)
        return c.id
    }

    public mutating func removeNode(_ id: Int) {
        nodes.removeAll { $0.id == id }
        connections.removeAll { $0.fromId == id || $0.toId == id }
    }

    /// Une ligne par type de matériel de la séance, comme import_from_session().
    public mutating func importSession(_ s: Session, catalogue: [GearItem]) -> Int {
        let map: [(GearField, String)] = [(.machines, "machine"), (.effects, "effet"), (.daws, "daw"),
                                          (.synthsIOS, "synth_ios"), (.plugins, "plugin")]
        var row = 0, added = 0
        let baseY = (nodes.map { $0.y + $0.height }.max() ?? 0) + (nodes.isEmpty ? 120 : 60)
        for (f, type) in map {
            let items = s[keyPath: f.keyPath]
            guard !items.isEmpty else { continue }
            for (i, name) in items.enumerated() {
                let cat = catalogue.first { $0.name.lowercased() == name.lowercased() && $0.active }
                addNode(name, type: type, x: 120 + Double(i) * 220, y: baseY + Double(row) * 140, catalogueId: cat?.id)
                added += 1
            }
            row += 1
        }
        return added
    }

    // MARK: → séance

    /// Champs de séance déduits du graphe (to_session_fields).
    public func sessionFields() -> (gear: [GearField: [String]], routing: String) {
        var g: [GearField: [String]] = [:]
        let map: [String: GearField] = ["machine": .machines, "effet": .effects, "daw": .daws,
                                        "synth_ios": .synthsIOS, "plugin": .plugins, "ipad": .ipad, "zynthian": .zynthian]
        for n in nodes { if let f = map[n.nodeType] { g[f, default: []].append(n.label) } }
        return (g, routingText())
    }

    /// Texte de routing : jusqu'à 4 chemins sources → puits, les plus longs d'abord.
    public func routingText() -> String {
        guard !nodes.isEmpty else { return "" }
        if connections.isEmpty {
            let order = ["machine", "synth_ios", "plugin", "effet", "daw", "free"]
            var labels: [String] = []
            for t in order { labels += nodes.filter { $0.nodeType == t }.map(\.label) }
            labels += nodes.filter { !order.contains($0.nodeType) }.map(\.label)
            return labels.joined(separator: " → ")
        }
        var adj: [Int: [Int]] = [:], indeg: [Int: Int] = [:]
        for n in nodes { adj[n.id] = []; indeg[n.id] = 0 }
        for c in connections where adj[c.fromId] != nil && indeg[c.toId] != nil {
            adj[c.fromId]!.append(c.toId); indeg[c.toId]! += 1
        }
        var sources = nodes.map(\.id).filter { indeg[$0] == 0 }
        if sources.isEmpty { sources = [nodes[0].id] }
        var paths: [[String]] = []
        func dfs(_ id: Int, _ path: [String], _ seen: Set<Int>) {
            guard !seen.contains(id) else { return }
            let seen = seen.union([id])
            let cur = path + [node(id)?.label ?? "?"]
            let kids = (adj[id] ?? []).filter { !seen.contains($0) }
            if kids.isEmpty { paths.append(cur) } else { for k in kids { dfs(k, cur, seen) } }
        }
        for s in sources { dfs(s, [], []) }
        if paths.isEmpty { return nodes.map(\.label).joined(separator: " → ") }
        var seen = Set<String>(), unique: [[String]] = []
        for p in paths.enumerated().sorted(by: { ($0.element.count, -$0.offset) > ($1.element.count, -$1.offset) }).map(\.element) {
            let k = p.joined(separator: "→")
            if seen.insert(k).inserted { unique.append(p) }
            if unique.count >= 4 { break }
        }
        return unique.map { $0.joined(separator: " → ") }.joined(separator: "\n")
    }

    // MARK: Exports

    public func mermaid(session: Session?) -> String {
        var l = ["# Patch : \(name)"]
        if let s = session { l.append("*Session : \(s.date)" + (s.title.isEmpty ? "" : " — \(s.title)") + "*") }
        l += ["", "```mermaid", "graph LR"]
        for n in nodes {
            var parts = ["\(PatchVocab.icon(n.nodeType)) \(n.label)"]
            if !n.note.isEmpty { parts.append(String(n.note.prefix(30)) + (n.note.count > 30 ? "…" : "")) }
            l.append("    n\(n.id)[\"\(parts.joined(separator: "\\n"))\"]")
        }
        l.append("")
        for c in connections {
            let arrow = PatchVocab.mermaidArrows[c.signalType] ?? "-->"
            l.append("    n\(c.fromId) \(arrow)|\"\(c.label.isEmpty ? c.signalType : c.label)\"| n\(c.toId)")
        }
        l.append("")
        for n in nodes {
            let col = PatchVocab.nodeColors[n.nodeType] ?? "#3A3A3A"
            l.append("    style n\(n.id) fill:\(col)22,stroke:\(col),color:\(col)")
        }
        l.append("```")
        if !nodes.isEmpty {
            l += ["", "## Nœuds", "", "| ID | Nom | Type | Note |", "|----|-----|------|------|"]
            l += nodes.map { "| n\($0.id) | \($0.label) | \($0.nodeType) | \($0.note) |" }
        }
        if !connections.isEmpty {
            l += ["", "## Connexions", "", "| De | Vers | Signal | Label |", "|----|------|--------|-------|"]
            l += connections.map {
                "| \(node($0.fromId)?.label ?? "\($0.fromId)") | \(node($0.toId)?.label ?? "\($0.toId)") | \($0.signalType) | \($0.label) |"
            }
        }
        return l.joined(separator: "\n")
    }

    /// Format portable de l'app web (from_index / to_index) : échange entre instances.
    public func portableJSON() throws -> Data {
        let index = Dictionary(uniqueKeysWithValues: nodes.enumerated().map { ($0.element.id, $0.offset) })
        let obj: [String: Any] = [
            "version": "1.0", "aza_patcher": true, "name": name,
            "exported_at": ISO8601DateFormatter().string(from: Date()),
            "nodes": nodes.map { n -> [String: Any] in
                ["label": n.label, "x": Int(n.x.rounded()), "y": Int(n.y.rounded()), "node_type": n.nodeType,
                 "color": n.color, "note": n.note, "catalogue_id": n.catalogueId as Any? ?? NSNull()]
            },
            "connections": connections.compactMap { c -> [String: Any]? in
                guard let fi = index[c.fromId], let ti = index[c.toId] else { return nil }
                return ["from_index": fi, "to_index": ti, "from_label": nodes[fi].label, "to_label": nodes[ti].label,
                        "label": c.label, "signal_type": c.signalType, "note": c.note]
            },
        ]
        return try JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys])
    }

    public static func fromPortable(_ data: Data, id: Int) throws -> PatchLayout {
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SQLiteImport.Failure(description: "Ce fichier n'est pas un patch AZA.")
        }
        var p = PatchLayout(id: id, name: obj["name"] as? String ?? "Patch importé")
        for (i, n) in ((obj["nodes"] as? [[String: Any]]) ?? []).enumerated() {
            var node = PatchNode(id: i + 1, label: n["label"] as? String ?? "?",
                                 nodeType: n["node_type"] as? String ?? "free",
                                 x: (n["x"] as? NSNumber)?.doubleValue ?? Double(100 + i * 20),
                                 y: (n["y"] as? NSNumber)?.doubleValue ?? 100)
            if let c = n["color"] as? String, !c.isEmpty { node.color = c }
            node.note = n["note"] as? String ?? ""
            node.catalogueId = (n["catalogue_id"] as? NSNumber)?.intValue
            p.nodes.append(node)
        }
        for c in (obj["connections"] as? [[String: Any]]) ?? [] {
            guard let fi = (c["from_index"] as? NSNumber)?.intValue, let ti = (c["to_index"] as? NSNumber)?.intValue,
                  p.nodes.indices.contains(fi), p.nodes.indices.contains(ti) else { continue }
            var x = PatchConnection(id: nextId(p.connections), fromId: p.nodes[fi].id, toId: p.nodes[ti].id,
                                    signalType: c["signal_type"] as? String ?? "audio")
            x.label = c["label"] as? String ?? ""; x.note = c["note"] as? String ?? ""
            p.connections.append(x)
        }
        return p
    }

    /// Copie avec de nouveaux identifiants (duplicate_layout).
    public func duplicated(id: Int) -> PatchLayout {
        var p = self
        p.id = id; p.name = name + " (copie)"; p.createdAt = Clock.stamp()
        return p
    }
}

// MARK: - Géométrie partagée (canvas, minimap, SVG)

public struct CablePath: Sendable {
    public var x0, y0, c1x, c1y, c2x, c2y, x1, y1: Double
    public var midX: Double, midY: Double

    /// Point de la courbe en t ∈ [0, 1].
    public func point(_ t: Double) -> (Double, Double) {
        let u = 1 - t
        let a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t
        return (a * x0 + b * c1x + c * c2x + d * x1, a * y0 + b * c1y + c * c2y + d * y1)
    }

    /// Distance minimale (échantillonnée) d'un point à la courbe.
    public func distance(to px: Double, _ py: Double) -> Double {
        (0...40).map { i -> Double in
            let (x, y) = point(Double(i) / 40)
            return hypot(x - px, y - py)
        }.min() ?? .infinity
    }
}

public extension PatchLayout {
    /// Bézier centre → centre, câbles parallèles écartés de 16 px (comme renderConn()).
    func cable(_ c: PatchConnection) -> CablePath? {
        guard let f = node(c.fromId), let t = node(c.toId) else { return nil }
        let parallels = connections.filter { $0.fromId == c.fromId && $0.toId == c.toId }
        let idx = Double(parallels.firstIndex { $0.id == c.id } ?? 0)
        let offset = (idx - Double(parallels.count - 1) / 2) * 16
        let dx = t.centerX - f.centerX, dy = t.centerY - f.centerY
        let len = max(hypot(dx, dy), 1)
        let px = -dy / len * offset, py = dx / len * offset
        let cdx = dx * 0.5
        return CablePath(x0: f.centerX, y0: f.centerY,
                         c1x: f.centerX + cdx + px, c1y: f.centerY + py,
                         c2x: t.centerX - cdx + px, c2y: t.centerY + py,
                         x1: t.centerX, y1: t.centerY,
                         midX: (f.centerX + t.centerX) / 2 + px * 0.5, midY: (f.centerY + t.centerY) / 2 + py * 0.5)
    }

    /// Point d'arrivée du câble sur le bord du nœud cible (pour que la flèche reste visible).
    func cableEnd(_ c: PatchConnection, _ p: CablePath) -> (Double, Double, Double) {
        guard let t = node(c.toId) else { return (p.x1, p.y1, 0) }
        var lo = 0.5, hi = 1.0
        func inside(_ x: Double, _ y: Double) -> Bool {
            x >= t.x && x <= t.x + t.width && y >= t.y && y <= t.y + t.height
        }
        for _ in 0..<20 {
            let m = (lo + hi) / 2
            let (x, y) = p.point(m)
            if inside(x, y) { hi = m } else { lo = m }
        }
        let (ex, ey) = p.point(lo)
        let (bx, by) = p.point(max(0, lo - 0.02))
        return (ex, ey, atan2(ey - by, ex - bx))
    }

    var bounds: (minX: Double, minY: Double, maxX: Double, maxY: Double) {
        guard !nodes.isEmpty else { return (0, 0, 800, 500) }
        return (nodes.map(\.x).min()!, nodes.map(\.y).min()!,
                nodes.map { $0.x + $0.width }.max()!, nodes.map { $0.y + $0.height }.max()!)
    }

    /// SVG autonome (export), couleurs résolues.
    func svg(dark: Bool = false) -> String {
        let b = bounds, pad = 40.0
        let w = b.maxX - b.minX + pad * 2, h = b.maxY - b.minY + pad * 2
        let bg = dark ? "#111210" : "#F4F1EC", surface = dark ? "#1F1E1C" : "#FFFFFF", muted = dark ? "#857F78" : "#666666"
        func esc(_ s: String) -> String {
            s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
        }
        func f(_ v: Double) -> String { String(format: "%.1f", v) }
        var o = ["<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\(f(w))\" height=\"\(f(h))\" "
                 + "viewBox=\"\(f(b.minX - pad)) \(f(b.minY - pad)) \(f(w)) \(f(h))\" font-family=\"Menlo, monospace\">",
                 "<rect x=\"\(f(b.minX - pad))\" y=\"\(f(b.minY - pad))\" width=\"\(f(w))\" height=\"\(f(h))\" fill=\"\(bg)\"/>",
                 "<defs>"]
        for (sig, col) in PatchVocab.signalColors.sorted(by: { $0.key < $1.key }) {
            o.append("<marker id=\"arrow-\(sig)\" viewBox=\"0 0 10 10\" refX=\"9\" refY=\"5\" markerWidth=\"7\" markerHeight=\"7\" orient=\"auto\"><path d=\"M0,0 L10,5 L0,10 z\" fill=\"\(col)\"/></marker>")
        }
        o.append("</defs>")
        for c in connections {
            guard let p = cable(c) else { continue }
            let (ex, ey, _) = cableEnd(c, p)
            let col = PatchVocab.signalColors[c.signalType] ?? "#888888"
            o.append("<path d=\"M \(f(p.x0)) \(f(p.y0)) C \(f(p.c1x)) \(f(p.c1y)), \(f(p.c2x)) \(f(p.c2y)), \(f(ex)) \(f(ey))\" "
                     + "stroke=\"\(col)\" stroke-width=\"1.5\" fill=\"none\" marker-end=\"url(#arrow-\(c.signalType))\"/>")
            if !c.label.isEmpty {
                o.append("<text x=\"\(f(p.midX))\" y=\"\(f(p.midY - 10))\" text-anchor=\"middle\" font-size=\"9\" fill=\"\(col)\">\(esc(c.label))</text>")
            }
        }
        for n in nodes {
            o.append("<g transform=\"translate(\(f(n.x)),\(f(n.y)))\">")
            o.append("<rect width=\"\(f(n.width))\" height=\"\(f(n.height))\" rx=\"3\" fill=\"\(surface)\" stroke=\"\(n.color)\" stroke-width=\"1.5\"/>")
            o.append("<text x=\"10\" y=\"18\" font-size=\"13\" fill=\"\(n.color)\" font-family=\"sans-serif\">\(PatchVocab.icon(n.nodeType))</text>")
            o.append("<text x=\"\(f(n.width / 2))\" y=\"18\" text-anchor=\"middle\" font-size=\"11\" font-weight=\"600\" fill=\"\(n.color)\">\(esc(n.label))</text>")
            o.append("<text x=\"\(f(n.width / 2))\" y=\"31\" text-anchor=\"middle\" font-size=\"9\" fill=\"\(muted)\">\(esc(n.nodeType))</text>")
            if !n.note.isEmpty {
                let note = n.note.count > 26 ? String(n.note.prefix(26)) + "…" : n.note
                o.append("<text x=\"\(f(n.width / 2))\" y=\"49\" text-anchor=\"middle\" font-size=\"9\" font-style=\"italic\" fill=\"\(muted)\">\(esc(note))</text>")
            }
            o.append("</g>")
        }
        o.append("</svg>")
        return o.joined(separator: "\n")
    }
}

// MARK: - Lien vivant patcher ↔ catalogue

public extension AZAData {
    /// Aligne les nœuds de tous les patches sur le catalogue. Rend `true` si quelque chose a bougé.
    ///
    /// - Un nœud lié prend le nom et le type de sa fiche : renommer ou reclasser une
    ///   machine se voit partout. Sa couleur suit le type, sauf si elle a été choisie à la main.
    /// - Une fiche supprimée délie le nœud sans l'effacer : le câblage reste lisible.
    /// - Un nœud libre qui porte exactement le nom d'une fiche (une seule) s'y lie :
    ///   c'est le cas des patches importés du web, souvent sans `catalogue_id`.
    @discardableResult
    mutating func syncPatches() -> Bool {
        guard !patches.isEmpty else { return false }
        let byId = Dictionary(uniqueKeysWithValues: catalogue.map { ($0.id, $0) })
        var byName: [String: GearItem?] = [:]
        for g in catalogue {
            let k = g.name.trimmingCharacters(in: .whitespaces).lowercased()
            byName[k] = byName[k] == nil ? g : .some(nil)   // homonymes : ambigu, pas de lien
        }
        var changed = false
        for p in patches.indices {
            for i in patches[p].nodes.indices {
                var n = patches[p].nodes[i]
                if let cid = n.catalogueId {
                    if let g = byId[cid] {
                        if n.label != g.name { n.label = g.name }
                        if n.nodeType != g.type {
                            if n.color.uppercased() == PatchVocab.color(n.nodeType).uppercased() { n.color = PatchVocab.color(g.type) }
                            n.nodeType = g.type
                        }
                    } else {
                        n.catalogueId = nil
                    }
                } else if !n.detached, let match = byName[n.label.trimmingCharacters(in: .whitespaces).lowercased()], let g = match {
                    n.catalogueId = g.id
                    if n.nodeType == "free" { n.nodeType = g.type; n.color = PatchVocab.color(g.type) }
                }
                if n != patches[p].nodes[i] { patches[p].nodes[i] = n; changed = true }
            }
        }
        return changed
    }

    /// Patches où figure une fiche, pour le lien retour depuis le catalogue.
    func patches(using gearId: Int) -> [PatchLayout] {
        patches.filter { $0.nodes.contains { $0.catalogueId == gearId } }
    }
}
