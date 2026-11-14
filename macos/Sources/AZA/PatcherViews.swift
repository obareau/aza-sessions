import AppKit
import AZACore
import SwiftUI

// MARK: - Liste des patches

struct PatcherView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    var selection: Int? {
        get { nav.patch }
        nonmutating set { nav.patch = newValue }
    }

    var body: some View {
        HSplitView {
            List(store.data.patches.sorted { $0.createdAt > $1.createdAt }, selection: $nav.patch) { p in
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.name).azaFont(.body, mono: true)
                    let s = store.data.sessions.first { $0.id == p.sessionId }
                    Text(["\(p.nodes.count) nœuds · \(p.connections.count) câbles", s.map { "⟶ \($0.date)" } ?? ""]
                        .filter { !$0.isEmpty }.joined(separator: "  "))
                        .foregroundStyle(.secondary).azaFont(.caption)
                }
                .tag(p.id)
                .contextMenu {
                    Button("Dupliquer") { duplicate(p) }
                    Button("Supprimer…", role: .destructive) { delete(p) }
                }
            }
            .frame(minWidth: 200, idealWidth: 230, maxWidth: 320)

            Group {
                if let id = selection, let i = store.data.patches.firstIndex(where: { $0.id == id }) {
                    PatchEditor(layout: $store.data.patches[i]).id(id)
                } else {
                    VStack(spacing: 10) {
                        Text("⬡ Patcher").azaFont(.title, mono: true)
                        Text("Carte du routing signal entre machines, effets, DAW et apps.").foregroundStyle(.secondary)
                        Button("Nouveau patch") { create() }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 600, maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Patcher")
        .toolbar {
            Button { create() } label: { Label("Nouveau", systemImage: "plus") }
            Button {
                guard let url = Panels.open(types: ["json"]) else { return }
                do {
                    let p = try PatchLayout.fromPortable(Data(contentsOf: url), id: nextId(store.data.patches))
                    store.data.patches.append(p)
                    selection = p.id
                } catch { store.lastError = "Import du patch impossible : \(error)" }
            } label: { Label("Importer", systemImage: "square.and.arrow.down") }.help("Importer un patch .json (format AZA)")
            Button { if let p = current { duplicate(p) } } label: { Label("Dupliquer", systemImage: "plus.square.on.square") }
                .disabled(current == nil)
            Button { if let p = current { delete(p) } } label: { Label("Supprimer", systemImage: "trash") }
                .disabled(current == nil)
        }
    }

    var current: PatchLayout? { store.data.patches.first { $0.id == selection } }

    func create() {
        let p = PatchLayout(id: nextId(store.data.patches), name: "Patch \(Clock.today())")
        store.data.patches.append(p)
        selection = p.id
    }

    func duplicate(_ p: PatchLayout) {
        let c = p.duplicated(id: nextId(store.data.patches))
        store.data.patches.append(c)
        selection = c.id
    }

    func delete(_ p: PatchLayout) {
        guard Panels.confirm("Supprimer le patch « \(p.name) » ?", "Nœuds et câbles compris.", ok: "Supprimer") else { return }
        if selection == p.id { selection = nil }
        store.data.patches.removeAll { $0.id == p.id }
    }
}

// MARK: - Éditeur

enum PatchSelection: Equatable { case node(Int), cable(Int) }

struct PatchEditor: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @EnvironmentObject var prefs: Prefs
    @Binding var layout: PatchLayout

    @Local private var zoom: CGFloat = 1
    @Local private var pan: CGSize = .zero
    @Local private var panStart: CGSize? = nil
    @Local private var zoomStart: CGFloat? = nil
    @Local private var dragStart: [Int: CGPoint] = [:]
    @Local private var selected: PatchSelection? = nil
    @Local private var cableMode = false
    @Local private var cableFrom: Int? = nil
    @Local private var signal = "audio"
    @Local private var viewSize: CGSize = .zero
    @Local private var didFit = false
    /// Tant que l'utilisateur n'a ni déplacé ni zoomé, la vue se recadre quand la fenêtre change de taille.
    @Local private var userAdjusted = false

    var snap: Bool { UserDefaults.standard.bool(forKey: "patchSnap") }
    @Local private var grid = UserDefaults.standard.bool(forKey: "patchSnap")
    @Local private var minimap = UserDefaults.standard.object(forKey: "patchMinimap") as? Bool ?? true
    @Local private var showCatalogue = UserDefaults.standard.object(forKey: "patchCatalogue") as? Bool ?? true
    @Local private var catQuery = ""
    @Local private var showInactive = false

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            HStack(spacing: 0) {
                GeometryReader { geo in
                    // Le canvas est bien plus grand que la vue : on le borne à la taille
                    // visible, sinon la minimap se cale sur son coin hors champ.
                    canvas
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                        .clipped()
                        .overlay(alignment: .bottomTrailing) {
                            if minimap && !layout.nodes.isEmpty { minimapView.padding(10) }
                        }
                    .onAppear { viewSize = geo.size; if !didFit { fit(); didFit = true } }
                    .onChange(of: geo.size) { viewSize = $0; if !userAdjusted { fit() } }
                }
                if showCatalogue {
                    Divider()
                    cataloguePanel.frame(width: 250)
                }
            }
            Divider()
            properties
        }
        .background(shortcuts)
    }

    // MARK: Barre du haut

    var topBar: some View {
        HStack(spacing: 8) {
            TextField("Nom du patch", text: $layout.name).textFieldStyle(.roundedBorder).frame(maxWidth: 240)
            Picker("", selection: $cableMode) {
                Label("Déplacer", systemImage: "hand.point.up.left").tag(false)
                Label("Câbler", systemImage: "cable.connector").tag(true)
            }
            .pickerStyle(.segmented).labelsHidden().frame(width: 190)
            .help("C : basculer. En mode câble, clique la source puis la destination.")
            .onChange(of: cableMode) { _ in cableFrom = nil }
            Menu {
                ForEach(PatchVocab.signals, id: \.self) { s in
                    Button { signal = s; cableMode = true } label: { Text(s) }
                }
            } label: {
                HStack(spacing: 4) {
                    Circle().fill(Color(hex: PatchVocab.signalColors[signal] ?? "#888")).frame(width: 9, height: 9)
                    Text(signal)
                }
            }
            .frame(width: 90).help("Type de signal des nouveaux câbles")

            addMenu
            Spacer()
            Toggle(isOn: Binding(get: { showCatalogue }, set: { showCatalogue = $0; UserDefaults.standard.set($0, forKey: "patchCatalogue") })) {
                Image(systemName: "sidebar.right")
            }.toggleStyle(.button).help("Panneau catalogue (K)")
            Toggle(isOn: Binding(get: { grid }, set: { grid = $0; UserDefaults.standard.set($0, forKey: "patchSnap") })) {
                Image(systemName: "grid")
            }.toggleStyle(.button).help("Grille magnétique 20 px (G)")
            Toggle(isOn: Binding(get: { minimap }, set: { minimap = $0; UserDefaults.standard.set($0, forKey: "patchMinimap") })) {
                Image(systemName: "map")
            }.toggleStyle(.button).help("Minimap (M)")
            Button { zoomBy(1 / 1.2) } label: { Image(systemName: "minus.magnifyingglass") }
            Text("\(Int(zoom * 100)) %").monospacedDigit().frame(width: 44).azaFont(.caption)
            Button { zoomBy(1.2) } label: { Image(systemName: "plus.magnifyingglass") }
            Button { fit() } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }.help("Tout afficher (F)")
            exportMenu
            Button { toSession() } label: { Label("→ Séance", systemImage: "arrow.right.doc.on.clipboard") }
                .disabled(layout.nodes.isEmpty)
                .help("Créer une séance avec ce matériel et ce routing")
        }
        .buttonStyle(.bordered)
        .padding(8)
    }

    var addMenu: some View {
        Menu {
            Button("Nœud libre") { add("Nœud", type: "free") }
            Divider()
            let groups = Dictionary(grouping: store.data.catalogue.filter(\.active), by: \.type)
            ForEach(groups.keys.sorted { Vocab.itemLabel($0) < Vocab.itemLabel($1) }, id: \.self) { t in
                Menu(Vocab.itemLabel(t)) {
                    ForEach(groups[t]!.sorted { $0.name.lowercased() < $1.name.lowercased() }) { g in
                        Button(g.name) { add(g.name, type: g.type, catalogueId: g.id) }
                    }
                }
            }
            Divider()
            Menu("Depuis une séance") {
                ForEach(store.data.sessions.sorted { $0.date > $1.date }.prefix(40)) { s in
                    Button("\(s.date) — \(s.displayTitle)") {
                        _ = layout.importSession(s, catalogue: store.data.catalogue)
                        if layout.sessionId == nil { layout.sessionId = s.id }
                        fit()
                    }
                }
            }
        } label: { Label("Ajouter", systemImage: "plus.circle") }
            .frame(width: 110)
    }

    var exportMenu: some View {
        Menu {
            Button("Mermaid (.md)…") {
                let s = store.data.sessions.first { $0.id == layout.sessionId }
                save(layout.mermaid(session: s), name: "patch-\(slug).md", ext: "md")
            }
            Button("SVG…") { save(layout.svg(dark: prefs.palette?.dark ?? false), name: "patch-\(slug).svg", ext: "svg") }
            Button("PNG…") { exportPNG() }
            Button("JSON portable…") {
                if let url = Panels.save(name: "patch-\(slug).json", ext: "json") {
                    do { try layout.portableJSON().write(to: url) } catch { store.lastError = "\(error)" }
                }
            }
            Divider()
            Button("Copier le routing") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(layout.routingText(), forType: .string)
            }
        } label: { Label("Exporter", systemImage: "square.and.arrow.up") }
            .frame(width: 110)
    }

    var slug: String { layout.name.lowercased().replacingOccurrences(of: " ", with: "-").replacingOccurrences(of: "/", with: "-") }

    func save(_ text: String, name: String, ext: String) {
        guard let url = Panels.save(name: name, ext: ext) else { return }
        do { try text.write(to: url, atomically: true, encoding: .utf8) } catch { store.lastError = "\(error)" }
    }

    func exportPNG() {
        guard let url = Panels.save(name: "patch-\(slug).png", ext: "png") else { return }
        let b = layout.bounds
        let content = PatchStatic(layout: layout, surface: prefs.palette?.surface ?? .white,
                                  background: prefs.palette?.bg ?? Color(hex: "#F4F1EC"), muted: .gray)
            .frame(width: b.maxX - b.minX + 80, height: b.maxY - b.minY + 80)
        let r = ImageRenderer(content: content)
        r.scale = 2
        guard let img = r.nsImage, let tiff = img.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
            store.lastError = "Rendu PNG impossible"; return
        }
        do { try png.write(to: url) } catch { store.lastError = "\(error)" }
    }

    // MARK: Canvas

    var contentSize: CGSize {
        let b = layout.bounds
        return CGSize(width: max(2400, b.maxX + 600), height: max(1600, b.maxY + 600))
    }

    var canvas: some View {
        let surface = prefs.palette?.surface ?? Color(nsColor: .textBackgroundColor)
        return ZStack(alignment: .topLeading) {
            // Fond : grille + câbles
            Canvas { ctx, size in
                if grid {
                    var p = Path()
                    stride(from: 0.0, through: size.width, by: 20).forEach { x in
                        p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    stride(from: 0.0, through: size.height, by: 20).forEach { y in
                        p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    ctx.stroke(p, with: .color(.secondary.opacity(0.10)), lineWidth: 0.5)
                }
                drawCables(ctx)
            }
            .frame(width: contentSize.width, height: contentSize.height)
            .contentShape(Rectangle())
            .gesture(SpatialTapGesture().onEnded { tapBackground($0.location) })

            ForEach(layout.nodes) { n in
                NodeView(node: n, surface: surface,
                         selected: selected == .node(n.id), armed: cableFrom == n.id,
                         armColor: Color(hex: PatchVocab.signalColors[signal] ?? "#888"),
                         linked: n.catalogueId != nil,
                         inactive: store.data.gear(n.catalogueId).map { !$0.active } ?? false)
                    .offset(x: n.x, y: n.y)
                    .gesture(nodeDrag(n))
                    .simultaneousGesture(TapGesture().onEnded { tapNode(n.id) })
            }
        }
        .frame(width: contentSize.width, height: contentSize.height, alignment: .topLeading)
        .coordinateSpace(name: "patch")
        .scaleEffect(zoom, anchor: .topLeading)
        .offset(pan)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .gesture(panGesture)
        .simultaneousGesture(MagnificationGesture()
            .onChanged { v in
                userAdjusted = true
                if zoomStart == nil { zoomStart = zoom }
                zoom = min(3, max(0.2, (zoomStart ?? 1) * v))
            }
            .onEnded { _ in zoomStart = nil })
    }

    func drawCables(_ ctx: GraphicsContext) {
        for c in layout.connections {
            guard let p = layout.cable(c) else { continue }
            let col = Color(hex: PatchVocab.signalColors[c.signalType] ?? "#888888")
            let (ex, ey, angle) = layout.cableEnd(c, p)
            var path = Path()
            path.move(to: CGPoint(x: p.x0, y: p.y0))
            path.addCurve(to: CGPoint(x: ex, y: ey), control1: CGPoint(x: p.c1x, y: p.c1y), control2: CGPoint(x: p.c2x, y: p.c2y))
            let sel = selected == .cable(c.id)
            ctx.stroke(path, with: .color(col), style: StrokeStyle(lineWidth: sel ? 3 : 1.5,
                                                                  dash: c.signalType == "midi" ? [5, 3] : []))
            // Flèche
            var head = Path()
            let s = 9.0
            head.move(to: CGPoint(x: ex, y: ey))
            head.addLine(to: CGPoint(x: ex - s * cos(angle - 0.4), y: ey - s * sin(angle - 0.4)))
            head.addLine(to: CGPoint(x: ex - s * cos(angle + 0.4), y: ey - s * sin(angle + 0.4)))
            head.closeSubpath()
            ctx.fill(head, with: .color(col))
            let text = c.label.isEmpty ? (c.note.isEmpty ? "" : "📝") : c.label
            if !text.isEmpty {
                ctx.draw(Text(text).font(.system(size: 9, design: .monospaced)).foregroundColor(col),
                         at: CGPoint(x: p.midX, y: p.midY - 10))
            }
        }
    }

    func nodeDrag(_ n: PatchNode) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named("patch"))
            .onChanged { v in
                guard !cableMode else { return }
                if dragStart[n.id] == nil { dragStart[n.id] = CGPoint(x: n.x, y: n.y); selected = .node(n.id) }
                guard let s = dragStart[n.id], let i = layout.nodes.firstIndex(where: { $0.id == n.id }) else { return }
                var x = max(0, s.x + v.translation.width), y = max(0, s.y + v.translation.height)
                if grid { x = (x / 20).rounded() * 20; y = (y / 20).rounded() * 20 }
                layout.nodes[i].x = x
                layout.nodes[i].y = y
            }
            .onEnded { _ in dragStart[n.id] = nil }
    }

    var panGesture: some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { v in
                userAdjusted = true
                if panStart == nil { panStart = pan }
                pan = CGSize(width: (panStart?.width ?? 0) + v.translation.width,
                             height: (panStart?.height ?? 0) + v.translation.height)
            }
            .onEnded { _ in panStart = nil }
    }

    func tapNode(_ id: Int) {
        if cableMode {
            if let from = cableFrom {
                if from != id, let cid = layout.connect(from, id, signal: signal) { selected = .cable(cid) }
                cableFrom = nil
            } else {
                cableFrom = id
            }
        } else {
            selected = .node(id)
        }
    }

    func tapBackground(_ p: CGPoint) {
        cableFrom = nil
        let hit = layout.connections.compactMap { c -> (Int, Double)? in
            guard let path = layout.cable(c) else { return nil }
            return (c.id, path.distance(to: p.x, p.y))
        }.min { $0.1 < $1.1 }
        if let hit, hit.1 < 8 { selected = .cable(hit.0) } else { selected = nil }
    }

    // MARK: Vue

    func add(_ label: String, type: String, catalogueId: Int? = nil) {
        let cx = (viewSize.width / 2 - pan.width) / zoom - 65
        let cy = (viewSize.height / 2 - pan.height) / zoom - 21
        // Première place libre en tournant autour du centre de la vue : ajouter
        // un type entier depuis le catalogue ne doit pas empiler les nœuds.
        let w = max(130, Double(label.count) * 7 + 44), h = 42.0
        func free(_ x: Double, _ y: Double) -> Bool {
            !layout.nodes.contains { n in
                x < n.x + n.width + 20 && x + w + 20 > n.x && y < n.y + n.height + 20 && y + h + 20 > n.y
            }
        }
        var x = max(0, cx), y = max(0, cy)
        search: for ring in 0..<12 {
            for dy in -ring...ring {
                for dx in -ring...ring where abs(dx) == ring || abs(dy) == ring {
                    let px = max(0, cx + Double(dx) * 180), py = max(0, cy + Double(dy) * 70)
                    if free(px, py) { x = px; y = py; break search }
                }
            }
        }
        if grid { x = (x / 20).rounded() * 20; y = (y / 20).rounded() * 20 }
        let id = layout.addNode(label, type: type, x: x, y: y, catalogueId: catalogueId)
        selected = .node(id)
    }

    func zoomBy(_ k: CGFloat) {
        userAdjusted = true
        let c = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        let nz = min(3, max(0.2, zoom * k))
        // Garder le centre de la vue fixe.
        pan = CGSize(width: c.x - (c.x - pan.width) * nz / zoom, height: c.y - (c.y - pan.height) * nz / zoom)
        zoom = nz
    }

    func fit() {
        guard !layout.nodes.isEmpty, viewSize.width > 0 else { zoom = 1; pan = .zero; return }
        let b = layout.bounds
        let w = b.maxX - b.minX + 80, h = b.maxY - b.minY + 80
        zoom = min(1.5, max(0.2, min(viewSize.width / w, viewSize.height / h)))
        pan = CGSize(width: -(b.minX - 40) * zoom + (viewSize.width - w * zoom) / 2,
                     height: -(b.minY - 40) * zoom + (viewSize.height - h * zoom) / 2)
    }

    var minimapView: some View {
        let b = layout.bounds
        let w = max(1, b.maxX - b.minX + 80), h = max(1, b.maxY - b.minY + 80)
        let mw = 180.0, mh = 110.0
        let s = min(mw / w, mh / h)
        return Canvas { ctx, _ in
            func m(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: (x - b.minX + 40) * s, y: (y - b.minY + 40) * s) }
            for c in layout.connections {
                guard let f = layout.node(c.fromId), let t = layout.node(c.toId) else { continue }
                var p = Path(); p.move(to: m(f.centerX, f.centerY)); p.addLine(to: m(t.centerX, t.centerY))
                ctx.stroke(p, with: .color(Color(hex: PatchVocab.signalColors[c.signalType] ?? "#888").opacity(0.7)), lineWidth: 1)
            }
            for n in layout.nodes {
                let o = m(n.x, n.y)
                ctx.fill(Path(CGRect(x: o.x, y: o.y, width: max(3, n.width * s), height: max(2, n.height * s))),
                         with: .color(Color(hex: n.color)))
            }
            // Fenêtre visible
            let vx = -pan.width / zoom, vy = -pan.height / zoom
            let vo = m(vx, vy)
            ctx.stroke(Path(CGRect(x: vo.x, y: vo.y, width: viewSize.width / zoom * s, height: viewSize.height / zoom * s)),
                       with: .color(.accentColor), lineWidth: 1)
        }
        .frame(width: mw, height: mh)
        .background(RoundedRectangle(cornerRadius: 4).fill(.regularMaterial))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.4)))
        .gesture(SpatialTapGesture().onEnded { e in
            // Centrer la vue sur le point cliqué.
            let x = e.location.x / s + b.minX - 40, y = e.location.y / s + b.minY - 40
            pan = CGSize(width: viewSize.width / 2 - x * zoom, height: viewSize.height / 2 - y * zoom)
        })
        .help("Clic : centrer la vue ici")
    }

    // MARK: Panneau catalogue — toujours le catalogue du moment

    var catalogueTypes: [String] {
        let present = Set(store.data.catalogue.map(\.type))
        let known = Vocab.itemTypes.map(\.key).filter(present.contains)
        return known + present.subtracting(known).sorted()
    }

    var cataloguePanel: some View {
        let q = catQuery.trimmingCharacters(in: .whitespaces).lowercased()
        let counts = Dictionary(layout.nodes.compactMap(\.catalogueId).map { ($0, 1) }, uniquingKeysWith: +)
        let items = store.data.catalogue.filter { (showInactive || $0.active)
            && (q.isEmpty || "\($0.name) \($0.manufacturer) \($0.code)".lowercased().contains(q)) }
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("CATALOGUE").azaHeading()
                Spacer()
                Button { nav.pane = .catalogue } label: {
                    Image(systemName: "arrow.up.right.square")
                }.buttonStyle(.borderless).help("Ouvrir le catalogue")
            }
            TextField("Filtrer…", text: $catQuery).textFieldStyle(.roundedBorder)
            Toggle("Fiches inactives", isOn: $showInactive).azaFont(.caption)
            List {
                ForEach(catalogueTypes, id: \.self) { t in
                    let group = items.filter { $0.type == t }
                        .sorted { ($0.manufacturer.lowercased(), $0.name.lowercased()) < ($1.manufacturer.lowercased(), $1.name.lowercased()) }
                    if !group.isEmpty {
                        SwiftUI.Section {
                            ForEach(group) { g in
                                Button { add(g.name, type: g.type, catalogueId: g.id) } label: {
                                    HStack(spacing: 6) {
                                        Text(PatchVocab.icon(g.type)).foregroundStyle(Color(hex: PatchVocab.color(g.type)))
                                        VStack(alignment: .leading, spacing: 0) {
                                            Text(g.name).lineLimit(1).foregroundStyle(g.active ? .primary : .secondary)
                                            if !g.manufacturer.isEmpty {
                                                Text(g.manufacturer).foregroundStyle(.secondary).azaFont(.caption2)
                                            }
                                        }
                                        Spacer()
                                        if let n = counts[g.id] {
                                            Text(n > 1 ? "✓×\(n)" : "✓").foregroundStyle(.tint).azaFont(.caption)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .help(counts[g.id] == nil ? "Ajouter au patch" : "Déjà dans le patch — clic pour un autre exemplaire")
                            }
                        } header: {
                            HStack {
                                Text(Vocab.itemLabel(t).uppercased()).azaFont(.caption2, mono: true)
                                Spacer()
                                Button("+ tout") {
                                    for g in group where counts[g.id] == nil { add(g.name, type: g.type, catalogueId: g.id) }
                                }
                                .buttonStyle(.borderless).azaFont(.caption2)
                                .disabled(group.allSatisfy { counts[$0.id] != nil })
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            Text("Les nœuds liés suivent leur fiche : nom, type, ajout ou suppression se répercutent ici.")
                .foregroundStyle(.secondary).azaFont(.caption2)
        }
        .padding(8)
    }

    // MARK: Propriétés

    var nodeTypes: [String] {
        let base = ["machine", "effet", "daw", "synth_ios", "plugin", "free"]
        let extra = Set(store.data.catalogue.map(\.type) + layout.nodes.map(\.nodeType)).subtracting(base).sorted()
        return base + extra
    }

    @ViewBuilder var properties: some View {
        HStack(spacing: 10) {
            switch selected {
            case .node(let id):
                if let i = layout.nodes.firstIndex(where: { $0.id == id }) {
                    let linked = store.data.gear(layout.nodes[i].catalogueId)
                    Text(PatchVocab.icon(layout.nodes[i].nodeType)).foregroundStyle(Color(hex: layout.nodes[i].color))
                    if let g = linked {
                        // Nom et type viennent de la fiche : on les change dans le catalogue.
                        HStack(spacing: 4) {
                            Image(systemName: "link").foregroundStyle(.tint)
                            Text(g.name).azaFont(.body, mono: true).lineLimit(1)
                            Text("· \(Vocab.itemLabel(g.type))").foregroundStyle(.secondary).azaFont(.caption)
                            if !g.active { Text("inactive").foregroundStyle(.orange).azaFont(.caption) }
                        }
                        .frame(minWidth: 180, alignment: .leading)
                        .help("Lié au catalogue : renomme ou reclasse la fiche, le patch suit")
                    } else {
                        TextField("Label", text: $layout.nodes[i].label).frame(width: 180)
                        Picker("Type", selection: Binding(get: { layout.nodes[i].nodeType }, set: {
                            layout.nodes[i].nodeType = $0; layout.nodes[i].color = PatchVocab.color($0)
                        })) {
                            ForEach(nodeTypes, id: \.self) { Text($0).tag($0) }
                        }.frame(width: 170)
                        Menu("Lier…") {
                            ForEach(store.data.catalogue.sorted { $0.name.lowercased() < $1.name.lowercased() }) { g in
                                Button(g.name) {
                                    layout.nodes[i].catalogueId = g.id
                                    layout.nodes[i].detached = false
                                }
                            }
                        }
                        .frame(width: 80)
                        .help("Rattacher ce nœud à une fiche du catalogue")
                    }
                    ColorPicker("", selection: Binding(get: { Color(hex: layout.nodes[i].color) },
                                                       set: { layout.nodes[i].color = $0.hex }), supportsOpacity: false)
                        .labelsHidden()
                    TextField("Note courte", text: $layout.nodes[i].note)
                    if let g = linked {
                        Button("Fiche →") { nav.open(gear: g.id) }.buttonStyle(.link)
                        Button("Délier") {
                            layout.nodes[i].catalogueId = nil
                            layout.nodes[i].detached = true
                        }
                        .buttonStyle(.link)
                        .help("Garder le nœud tel quel, sans suivre la fiche")
                    }
                    Button(role: .destructive) { layout.removeNode(id); selected = nil } label: { Image(systemName: "trash") }
                }
            case .cable(let id):
                if let i = layout.connections.firstIndex(where: { $0.id == id }) {
                    let c = layout.connections[i]
                    Text("\(layout.node(c.fromId)?.label ?? "?") → \(layout.node(c.toId)?.label ?? "?")")
                        .azaFont(.caption, mono: true).lineLimit(1)
                    Picker("Signal", selection: $layout.connections[i].signalType) {
                        ForEach(PatchVocab.signals, id: \.self) { Text($0).tag($0) }
                    }.frame(width: 140)
                    TextField("Label", text: $layout.connections[i].label).frame(width: 140)
                    TextField("Note", text: $layout.connections[i].note)
                    Button { let f = c.fromId; layout.connections[i].fromId = c.toId; layout.connections[i].toId = f } label: {
                        Image(systemName: "arrow.left.arrow.right")
                    }.help("Inverser le sens")
                    Button(role: .destructive) { layout.connections.remove(at: i); selected = nil } label: { Image(systemName: "trash") }
                }
            case nil:
                Text(cableMode
                     ? (cableFrom == nil ? "Mode câble : clique la source…" : "…puis la destination (Échap pour annuler).")
                     : "Clique un nœud ou un câble pour l'éditer · glisse le fond pour te déplacer · pincer pour zoomer")
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("Séance liée", selection: $layout.sessionId) {
                    Text("—").tag(Int?.none)
                    ForEach(store.data.sessions.sorted { $0.date > $1.date }.prefix(80)) { s in
                        Text("\(s.date) — \(s.displayTitle)").tag(Int?.some(s.id))
                    }
                }.frame(width: 280)
                if let sid = layout.sessionId { Button("Ouvrir →") { nav.open(session: sid) }.buttonStyle(.link) }
            }
        }
        .padding(8)
        .frame(minHeight: 40)
    }

    /// Raccourcis clavier, comme dans le patcher web.
    var shortcuts: some View {
        Group {
            Button("") { grid.toggle(); UserDefaults.standard.set(grid, forKey: "patchSnap") }.keyboardShortcut("g", modifiers: [])
            Button("") { minimap.toggle(); UserDefaults.standard.set(minimap, forKey: "patchMinimap") }.keyboardShortcut("m", modifiers: [])
            Button("") { cableMode.toggle() }.keyboardShortcut("c", modifiers: [])
            Button("") { showCatalogue.toggle(); UserDefaults.standard.set(showCatalogue, forKey: "patchCatalogue") }
                .keyboardShortcut("k", modifiers: [])
            Button("") { fit() }.keyboardShortcut("f", modifiers: [])
            Button("") { cableFrom = nil; selected = nil }.keyboardShortcut(.escape, modifiers: [])
            Button("") { deleteSelection() }.keyboardShortcut(.delete, modifiers: [.command])
        }
        .opacity(0).frame(width: 0, height: 0).allowsHitTesting(false)
    }

    func deleteSelection() {
        switch selected {
        case .node(let id): layout.removeNode(id)
        case .cable(let id): layout.connections.removeAll { $0.id == id }
        case nil: return
        }
        selected = nil
    }

    func toSession() {
        let f = layout.sessionFields()
        var s = Session(id: store.data.nextSessionId(), date: Clock.today())
        for (field, names) in f.gear { s[keyPath: field.keyPath] = names }
        s.signalRouting = f.routing
        s.oblique = store.data.randomOblique() ?? ""
        s.audioFile = store.data.takeName(for: s)
        store.data.sessions.append(s)
        if layout.sessionId == nil { layout.sessionId = s.id }
        nav.open(session: s.id)
    }
}

struct NodeView: View {
    let node: PatchNode
    let surface: Color
    let selected: Bool
    let armed: Bool
    let armColor: Color
    var linked = false
    var inactive = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        // Les couleurs de type (rouge sombre, bleu nuit…) viennent du patcher web, pensé
        // sur fond clair : sur fond sombre on les éclaircit pour que le texte reste lisible.
        let base = Color(hex: node.color)
        let col = scheme == .dark ? base.mixed(with: .white, 0.45) : base
        VStack(spacing: 1) {
            ZStack {
                Text(node.label).font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(col)
                    .lineLimit(1)
                HStack {
                    Text(PatchVocab.icon(node.nodeType)).font(.system(size: 13)).foregroundStyle(col)
                    Spacer()
                }
            }
            Text(node.nodeType).font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
            if !node.note.trimmingCharacters(in: .whitespaces).isEmpty {
                Rectangle().fill(col.opacity(0.3)).frame(height: 0.5).padding(.horizontal, 2)
                Text(node.note.count > 26 ? String(node.note.prefix(26)) + "…" : node.note)
                    .font(.system(size: 9, design: .monospaced)).italic().foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .frame(width: node.width, height: node.height)
        .background(RoundedRectangle(cornerRadius: 3).fill(armed ? col.opacity(0.13) : (selected ? col.opacity(0.10) : surface)))
        .overlay(RoundedRectangle(cornerRadius: 3)
            .stroke(armed ? armColor : col, style: StrokeStyle(lineWidth: selected || armed ? 2.5 : 1.5, dash: armed ? [5, 3] : [])))
        .overlay(alignment: .topTrailing) {
            if linked {
                Image(systemName: "link").font(.system(size: 7)).foregroundStyle(col.opacity(0.7)).padding(3)
            }
        }
        .opacity(inactive ? 0.45 : 1)
        .contentShape(Rectangle())
        .help(inactive ? "Fiche inactive dans le catalogue" : node.note)
    }
}

/// Rendu fixe du patch (export PNG).
struct PatchStatic: View {
    let layout: PatchLayout
    let surface: Color
    let background: Color
    let muted: Color

    var body: some View {
        let b = layout.bounds
        ZStack(alignment: .topLeading) {
            background
            Canvas { ctx, _ in
                ctx.translateBy(x: -b.minX + 40, y: -b.minY + 40)
                for c in layout.connections {
                    guard let p = layout.cable(c) else { continue }
                    let (ex, ey, a) = layout.cableEnd(c, p)
                    let col = Color(hex: PatchVocab.signalColors[c.signalType] ?? "#888")
                    var path = Path()
                    path.move(to: CGPoint(x: p.x0, y: p.y0))
                    path.addCurve(to: CGPoint(x: ex, y: ey), control1: CGPoint(x: p.c1x, y: p.c1y), control2: CGPoint(x: p.c2x, y: p.c2y))
                    ctx.stroke(path, with: .color(col), lineWidth: 1.5)
                    var h = Path()
                    h.move(to: CGPoint(x: ex, y: ey))
                    h.addLine(to: CGPoint(x: ex - 9 * cos(a - 0.4), y: ey - 9 * sin(a - 0.4)))
                    h.addLine(to: CGPoint(x: ex - 9 * cos(a + 0.4), y: ey - 9 * sin(a + 0.4)))
                    ctx.fill(h, with: .color(col))
                    if !c.label.isEmpty {
                        ctx.draw(Text(c.label).font(.system(size: 9, design: .monospaced)).foregroundColor(col),
                                 at: CGPoint(x: p.midX, y: p.midY - 10))
                    }
                }
            }
            ForEach(layout.nodes) { n in
                NodeView(node: n, surface: surface, selected: false, armed: false, armColor: .clear)
                    .offset(x: n.x - b.minX + 40, y: n.y - b.minY + 40)
            }
        }
    }
}
