import Foundation

// Fiches imprimables (print.html, recall.html, atelier.html, form_blank.html,
// catalogue_fiches_print.html), produites en HTML autonome : l'app les montre,
// les imprime ou les enregistre en PDF. Mise en page papier, indépendante du thème.

public enum Sheets {
    static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }

    static let css = """
    *,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
    :root{--ink:#0E0D0B;--mid:#3A3733;--soft:#6B6560;--faint:#A09A94;--rule:#C8C2B8;--alt:#EFECE6;--accent:#B82E08;--accent2:#2D4A6B;
      --mono:"IBM Plex Mono","IBMPlexMono",Menlo,monospace;--sans:"IBM Plex Sans","IBMPlexSans",-apple-system,Helvetica,sans-serif}
    html,body{background:#fff;color:var(--ink);font-family:var(--sans);font-size:11px;line-height:1.55;-webkit-print-color-adjust:exact;print-color-adjust:exact}
    @page{size:A4;margin:14mm 16mm}
    .page{max-width:178mm;margin:0 auto}
    .doc-header{display:flex;justify-content:space-between;align-items:flex-start;padding-bottom:8px;border-bottom:2px solid var(--ink);margin-bottom:14px}
    .brand{font-family:var(--mono);font-size:8px;font-weight:700;text-transform:uppercase;letter-spacing:.18em;color:var(--soft)}
    .brand strong{display:block;font-size:13px;color:var(--ink);letter-spacing:.04em;margin-top:2px}
    .meta{font-family:var(--mono);font-size:8.5px;color:var(--soft);text-align:right;line-height:1.8}
    h1{font-family:var(--mono);font-size:20px;font-weight:700;letter-spacing:-.02em;margin-bottom:3px}
    .sub{font-family:var(--mono);font-size:10px;color:var(--soft);margin-bottom:12px;display:flex;gap:10px;flex-wrap:wrap;align-items:center}
    .pill{font-family:var(--mono);font-size:8px;font-weight:700;text-transform:uppercase;letter-spacing:.08em;padding:1px 6px;border:1px solid currentColor;border-radius:2px}
    .acc{color:var(--accent)}
    .head{font-family:var(--mono);font-size:8.5px;font-weight:700;text-transform:uppercase;letter-spacing:.14em;color:var(--accent);margin:14px 0 6px;padding-bottom:3px;border-bottom:1px solid var(--rule)}
    .grid{display:grid;grid-template-columns:1fr 1fr;border:1px solid var(--rule);margin-bottom:10px}
    .cell{padding:6px 10px;border-bottom:1px solid var(--rule);border-right:1px solid var(--rule);break-inside:avoid}
    .cell:nth-child(2n){border-right:none}
    .cell.full{grid-column:1/-1;border-right:none}
    .lbl{font-family:var(--mono);font-size:7.5px;text-transform:uppercase;letter-spacing:.12em;color:var(--faint);font-weight:700;margin-bottom:2px}
    .val{font-family:var(--mono);font-size:10.5px;white-space:pre-wrap}
    .empty{color:var(--faint)}
    .quote{font-family:var(--mono);font-style:italic;border-left:2px solid var(--accent);padding:4px 10px;margin:8px 0}
    .foot{margin-top:18px;padding-top:6px;border-top:1px solid var(--rule);display:flex;justify-content:space-between;font-family:var(--mono);font-size:7.5px;color:var(--faint)}
    .step{display:flex;gap:12px;align-items:flex-start;padding:8px 0;border-bottom:1px solid var(--rule);break-inside:avoid}
    .num{font-family:var(--mono);font-size:10px;font-weight:700;color:#fff;background:var(--accent);width:20px;height:20px;border-radius:50%;display:flex;align-items:center;justify-content:center;flex-shrink:0}
    .role{font-family:var(--mono);font-size:8px;text-transform:uppercase;letter-spacing:.12em;color:var(--soft)}
    .name{font-family:var(--mono);font-size:12px;font-weight:600}
    dl.facts{display:grid;grid-template-columns:120px 1fr;gap:4px 12px;font-family:var(--mono);font-size:10.5px}
    dl.facts dt{color:var(--soft)} dl.facts dd{white-space:pre-wrap}
    .sheets{display:grid;grid-template-columns:1fr 1fr;gap:10px}
    .sheet{border:1px solid var(--rule);border-radius:2px;padding:8px;break-inside:avoid}
    .ctl{display:flex;align-items:center;gap:8px;font-family:var(--mono);font-size:9px;margin-bottom:2px}
    .ctl .n{color:var(--soft);min-width:90px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
    .bar{flex:1;height:5px;border:1px solid var(--rule);border-radius:3px;overflow:hidden}
    .bar span{display:block;height:100%;background:var(--accent)}
    .blank{display:inline-block;min-width:110px;border-bottom:1px solid var(--rule);height:14px}
    .line{display:flex;align-items:center;gap:12px;padding:6px 0;border-bottom:1px dotted var(--rule);break-inside:avoid}
    .line .n{font-family:var(--mono);font-size:10px;min-width:120px}
    .gauge{flex:1;height:12px;border:1px solid var(--rule);border-radius:2px;background:repeating-linear-gradient(to right,var(--rule) 0 1px,transparent 1px 10%)}
    .wl{border-bottom:1px solid var(--rule);height:20px}
    .sec{font-family:var(--mono);font-size:8.5px;text-transform:uppercase;letter-spacing:.12em;color:var(--accent2);margin:10px 0 4px}
    .opts{display:flex;flex-wrap:wrap;gap:4px}
    .opt{font-family:var(--mono);font-size:8.5px;padding:2px 7px;border:1px solid var(--rule);border-radius:10px}
    .chkcols{display:grid;grid-template-columns:repeat(3,1fr);gap:2px 14px;align-items:start}
    .chkblock{break-inside:avoid;margin-bottom:8px}
    .chkblock .t{font-family:var(--mono);font-size:7px;font-weight:700;text-transform:uppercase;letter-spacing:.16em;color:var(--soft);border-bottom:1px solid var(--rule);margin-bottom:3px;padding-bottom:1px}
    .chk{display:flex;align-items:center;gap:5px;font-family:var(--mono);font-size:8.5px;line-height:1.7}
    .box{display:inline-block;width:8px;height:8px;border:1px solid var(--mid);flex-shrink:0}
    .circles span{display:inline-block;width:15px;height:15px;border:1px solid var(--mid);border-radius:50%;text-align:center;font-size:8px;line-height:13px;margin-right:2px;color:var(--faint)}
    .routing{border:1px solid var(--rule);height:44px;font-family:var(--mono);font-size:10px;color:var(--faint);padding:6px 10px;letter-spacing:.4em}
    table{width:100%;border-collapse:collapse;margin-bottom:10px}
    th{font-family:var(--mono);font-size:7.5px;text-transform:uppercase;letter-spacing:.12em;color:var(--soft);text-align:left;border-bottom:1.5px solid var(--ink);padding:3px 6px}
    td{font-family:var(--mono);font-size:9.5px;border-bottom:1px solid var(--rule);padding:5px 6px;vertical-align:top}
    tr{break-inside:avoid}
    .star{color:var(--accent)}
    """

    static func page(_ title: String, _ body: String, landscape: Bool = false) -> String {
        """
        <!DOCTYPE html><html lang="fr"><head><meta charset="utf-8"><title>\(esc(title))</title>
        <style>\(css)\(landscape ? "@page{size:A4 landscape}.page{max-width:265mm}" : "")</style></head>
        <body><div class="page">\(body)</div></body></html>
        """
    }

    static func header(_ kicker: String, meta: [String]) -> String {
        """
        <div class="doc-header"><div class="brand">\(esc(kicker))<strong>AZA</strong></div>
        <div class="meta">\(meta.map(esc).joined(separator: "<br>"))</div></div>
        """
    }

    static func footer(_ version: String) -> String {
        "<div class=\"foot\"><span>Journal de Sessions AZA · v\(esc(version))</span><span>\(Clock.today())</span></div>"
    }

    static func cell(_ label: String, _ value: String, full: Bool = false) -> String {
        let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return "<div class=\"cell\(full ? " full" : "")\"><div class=\"lbl\">\(esc(label))</div>"
            + "<div class=\"val\(v.isEmpty ? " empty" : "")\">\(v.isEmpty ? "—" : esc(v))</div></div>"
    }

    // MARK: Fiche de séance

    public static func session(_ s: Session, data d: AZAData, version: String) -> String {
        let project = d.project(s.projectId)
        var sub = ["<span>\(esc(s.date))</span>", "<span class=\"pill\">\(esc(Vocab.sessionTypeLabel(s.sessionType)))</span>"]
        if !s.mode.isEmpty { sub.append("<span class=\"pill\">\(esc(s.mode))</span>") }
        if !s.intention.isEmpty { sub.append("<span class=\"pill acc\">\(esc(s.intention))</span>") }
        if let m = s.durationMin { sub.append("<span>\(m) min</span>") }
        if let r = s.rating, r > 0 { sub.append("<span class=\"acc\">\(String(repeating: "★", count: r))</span>") }
        if let e = s.energyLevel, e > 0 { sub.append("<span>\(String(repeating: "⚡", count: e))</span>") }
        if let p = project { sub.append("<span>Projet : \(esc(p.title))</span>") }
        var flags: [String] = []
        if s.toRework { flags.append("À retravailler") }
        if s.releasePotential { flags.append("Potentiel release") }
        let list = { (a: [String]) in a.joined(separator: ", ") }
        var b = header("Journal de Sessions — Fiche de séance", meta: ["Séance #\(s.id)", "v\(version)"])
        b += "<h1>\(esc(s.displayTitle))</h1><div class=\"sub\">\(sub.joined())</div>"
        b += "<div class=\"head\">∙ Matériel</div><div class=\"grid\">"
        for f in GearField.allCases where !s[keyPath: f.keyPath].isEmpty || [.machines, .effects].contains(f) {
            b += cell(f.label, list(s[keyPath: f.keyPath]))
        }
        if GearField.allCases.filter({ !s[keyPath: $0.keyPath].isEmpty || [.machines, .effects].contains($0) }).count % 2 == 1 {
            b += cell("", "")
        }
        b += "</div><div class=\"head\">∙ Son</div><div class=\"grid\">"
        b += cell("Tempo", s.tempo) + cell("Tonalité", s.tonality)
        b += cell("Algo MicroFreak", s.microfreakAlgo) + cell("Caractère", list(s.character))
        b += cell("Patches / presets", s.patches, full: true) + cell("Signal routing", s.signalRouting, full: true)
        b += "</div><div class=\"head\">∙ Enregistrement & contexte</div><div class=\"grid\">"
        b += cell("Fichier audio / prise", s.audioFile) + cell("Timestamps", s.timestamps)
        b += cell("Tags", list(s.tags)) + cell("Influences", list(s.influences))
        b += cell("Lien lore", s.loreLink) + cell("Statut", flags.joined(separator: " · "))
        b += "</div>"
        if !s.oblique.isEmpty { b += "<div class=\"head\">∙ Stratégie AZA</div><div class=\"quote\">\(esc(s.oblique))</div>" }
        b += "<div class=\"head\">∙ Notes libres</div><div class=\"val\">\(s.comments.isEmpty ? "<span class=\"empty\">—</span>" : esc(s.comments))</div>"
        if !s.recapClaude.isEmpty { b += "<div class=\"head\">∙ Récap</div><div class=\"val\">\(esc(s.recapClaude))</div>" }
        b += footer(version)
        return page("Session \(s.date) — AZA", b)
    }

    // MARK: Fiche de rappel — la chaîne dans l'ordre du signal

    public static func recall(_ s: Session, data d: AZAData, version: String) -> String {
        let order: [(GearField, String)] = [(.machines, "instrument"), (.synthsIOS, "instrument"), (.ipad, "instrument"),
                                            (.zynthian, "instrument"), (.effects, "traitement"), (.plugins, "traitement"),
                                            (.daws, "hôte")]
        var b = header("Journal de Sessions — Fiche de rappel", meta: [s.date, "Séance #\(s.id)", "v\(version)"])
        b += "<h1>⟲ \(esc(s.displayTitle))</h1><div class=\"sub\"><span>\(esc(s.date))</span>"
            + (s.mode.isEmpty ? "" : "<span class=\"pill\">\(esc(s.mode))</span>") + "</div>"
        b += "<div class=\"head\">∙ La chaîne, dans l'ordre du signal</div>"
        var n = 0
        for (f, role) in order {
            for name in s[keyPath: f.keyPath] {
                n += 1
                let g = d.catalogue.first { $0.name == name }
                let meta = [role, g?.manufacturer ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
                b += "<div class=\"step\"><div class=\"num\">\(n)</div><div><div class=\"name\">\(esc(name))"
                    + ((g?.code.isEmpty ?? true) ? "" : " <span class=\"role\">· \(esc(g!.code))</span>")
                    + "</div><div class=\"role\">\(esc(meta))</div></div></div>"
            }
        }
        if n == 0 { b += "<p class=\"empty\">Aucun matériel noté sur cette séance — il n'y a rien à rappeler.</p>" }
        if !s.audioFile.isEmpty {
            b += "<div class=\"step\"><div class=\"num\" style=\"background:var(--accent2)\">▪</div><div><div class=\"name\">"
                + "\(esc(s.audioFile))</div><div class=\"role\">prise Zoom R8</div></div></div>"
        }
        let facts: [(String, String)] = [("Tempo", s.tempo.isEmpty ? "" : s.tempo + " BPM"), ("Tonalité", s.tonality),
                                         ("Algo MicroFreak", s.microfreakAlgo), ("Patches", s.patches), ("Routing", s.signalRouting)]
            .filter { !$0.1.isEmpty }
        if !facts.isEmpty {
            b += "<div class=\"head\">∙ Réglages notés</div><dl class=\"facts\">"
                + facts.map { "<dt>\(esc($0.0))</dt><dd>\(esc($0.1))</dd>" }.joined() + "</dl>"
        }
        b += "<div class=\"head\">◉ Façades relevées</div>"
        let sheets = d.knobSheets.filter { $0.sessionId == s.id }
        if sheets.isEmpty {
            b += "<p class=\"empty\">Aucune façade relevée pour cette séance.</p>"
        } else {
            b += "<div class=\"sheets\">"
            for sh in sheets {
                let g = d.gear(sh.gearId)
                b += "<div class=\"sheet\"><div class=\"name acc\">\(esc(g?.name ?? "?"))</div>"
                    + "<div class=\"role\" style=\"margin-bottom:6px\">\(esc(sh.label.isEmpty ? "sans nom" : sh.label))</div>"
                b += knobRows(controls: parseControls(g?.controls ?? ""), values: sh.values)
                if !sh.notes.isEmpty { b += "<div class=\"role\" style=\"margin-top:6px;text-transform:none\">\(esc(sh.notes))</div>" }
                b += "</div>"
            }
            b += "</div>"
        }
        if !s.comments.isEmpty { b += "<div class=\"head\">∙ Ce qui s'est passé</div><div class=\"val\">\(esc(s.comments))</div>" }
        b += footer(version)
        return page("Rappel — \(s.displayTitle) — AZA", b)
    }

    static func knobRows(controls: [Control], values: [String: String]) -> String {
        var out = ""
        let declared = controls.filter { $0.kind != .section }.map(\.name)
        let extra = values.keys.filter { !declared.contains($0) }.sorted().map { Control(kind: .dial, name: $0, options: []) }
        for c in controls.filter({ $0.kind != .section }) + extra {
            let v = values[c.name]
            out += "<div class=\"ctl\"><span class=\"n\">\(esc(c.name))</span>"
            if c.kind == .switch || (v != nil && Double(v!) == nil) {
                out += "<span>\(esc(v ?? "—"))</span>"
            } else if let v, let x = Double(v) {
                out += "<span class=\"bar\"><span style=\"width:\(Int((min(10, max(0, x)) * 10).rounded()))%\"></span></span>"
                    + "<span style=\"min-width:18px;text-align:right\">\(esc(v))</span>"
            } else {
                out += "<span style=\"flex:1;opacity:.45\">— pas relevé</span>"
            }
            out += "</div>"
        }
        return out
    }

    // MARK: Feuille d'atelier — à imprimer avant de jouer

    public static func workshop(gear names: [String], data d: AZAData, version: String) -> String {
        var probe = Session(id: -1, date: Clock.today())
        probe.machines = names
        let take = d.takeName(for: probe)
        // Le rang se note à la main : seul le préfixe est imprimé (« MFR_ »).
        let takePrefix = take.lastIndex(of: "_").map { String(take[...$0]) } ?? ""
        var b = header("Journal de Sessions — Feuille d'atelier", meta: ["À remplir au stylo", "v\(version)"])
        b += "<div class=\"sub\" style=\"gap:22px;margin:4px 0 14px\">"
            + "<span><span class=\"lbl\">Date</span><span class=\"blank\"></span></span>"
            + "<span><span class=\"lbl\">Prise R8</span>"
            + (takePrefix.isEmpty ? "<span class=\"blank\"></span>" : "<b>\(esc(takePrefix))</b><span class=\"blank\" style=\"min-width:24px\"></span>")
            + "</span><span><span class=\"lbl\">Titre</span><span class=\"blank\" style=\"min-width:160px\"></span></span>"
            + "<span><span class=\"lbl\">Durée</span><span class=\"blank\" style=\"min-width:50px\"></span></span></div>"
        if names.isEmpty {
            b += "<p class=\"empty\">Aucun matériel choisi.</p>"
        } else {
            let chain = names.map { n -> String in
                let c = d.catalogue.first { $0.name == n }?.code ?? ""
                return esc(n) + (c.isEmpty ? "" : " (\(esc(c)))")
            }
            b += "<div class=\"lbl\">Chaîne</div><div class=\"name\" style=\"margin-bottom:6px\">\(chain.joined(separator: " → ")) → R8</div>"
            for n in names {
                let g = d.catalogue.first { $0.name == n }
                b += "<div style=\"margin-top:14px;break-inside:avoid\"><div class=\"name\">\(esc(n))"
                    + ((g?.manufacturer.isEmpty ?? true) ? "" : " <span class=\"role\">· \(esc(g!.manufacturer))</span>") + "</div>"
                let ctl = parseControls(g?.controls ?? "")
                if ctl.isEmpty {
                    // Commandes non déclarées : des lignes vides valent mieux que rien.
                    for _ in 0..<6 {
                        b += "<div class=\"line\"><span class=\"n\" style=\"border-bottom:1px solid var(--rule)\">&nbsp;</span><span class=\"gauge\"></span></div>"
                    }
                } else {
                    for c in ctl {
                        switch c.kind {
                        case .section: b += "<div class=\"sec\">\(esc(c.name))</div>"
                        case .switch:
                            b += "<div class=\"line\"><span class=\"n\">\(esc(c.name))</span><span class=\"role\" style=\"text-transform:none\">"
                                + c.options.map { "◻ " + esc($0) }.joined(separator: "&nbsp;&nbsp;&nbsp;") + "</span></div>"
                        case .dial: b += "<div class=\"line\"><span class=\"n\">\(esc(c.name))</span><span class=\"gauge\"></span></div>"
                        }
                    }
                }
                b += "</div>"
            }
        }
        b += "<div class=\"head\" style=\"margin-top:20px\">∙ Ce qui s'est passé</div>" + String(repeating: "<div class=\"wl\"></div>", count: 6)
        b += footer(version)
        return page("Feuille d'atelier — AZA", b)
    }

    // MARK: Formulaire vierge (terrain)

    public static func blankForm(data d: AZAData, version: String) -> String {
        func opts(_ xs: [String], extra: Bool = false) -> String {
            "<div class=\"opts\">" + xs.map { "<span class=\"opt\">\(esc($0))</span>" }.joined()
                + (extra ? "<span class=\"opt\" style=\"min-width:60px;border-style:dashed\">&nbsp;</span>" : "") + "</div>"
        }
        func blocks(_ title: String, _ items: [String], size: Int) -> String {
            guard !items.isEmpty else { return "" }
            let chunks = stride(from: 0, to: items.count, by: size).map { Array(items[$0..<min($0 + size, items.count)]) }
            return chunks.enumerated().map { i, chunk in
                "<div class=\"chkblock\"><div class=\"t\">\(esc(title))\(chunks.count > 1 ? " \(i + 1)/\(chunks.count)" : "")</div>"
                    + chunk.map { "<div class=\"chk\"><span class=\"box\"></span>\(esc($0))</div>" }.joined()
                    + (i == chunks.count - 1 ? "<div class=\"chk\"><span class=\"box\"></span><span class=\"blank\" style=\"min-width:70px;height:10px\"></span></div>" : "")
                    + "</div>"
            }.joined()
        }
        var b = header("Journal de Sessions — Formulaire terrain", meta: ["Date ________", "Durée ____ min", "v\(version)"])
        b += "<div class=\"head\">∙ Contexte</div><div class=\"grid\" style=\"grid-template-columns:1fr 1fr 1fr;border:none\">"
            + "<div><div class=\"lbl\">Mode</div>\(opts(Vocab.modes))</div>"
            + "<div><div class=\"lbl\">Intention</div>\(opts(Vocab.intentions))</div>"
            + "<div><div class=\"lbl\">Note</div><div class=\"circles\">\(String(repeating: "<span>★</span>", count: 5))</div>"
            + "<div class=\"lbl\" style=\"margin-top:4px\">Énergie</div><div class=\"circles\">\(String(repeating: "<span>⚡</span>", count: 3))</div>"
            + "<div class=\"chk\" style=\"margin-top:4px\"><span class=\"box\"></span>À retravailler&nbsp;&nbsp;<span class=\"box\"></span>Release</div></div></div>"
        b += "<div class=\"head\">∙ Matériel &amp; logiciels</div><div class=\"chkcols\">"
        for t in Vocab.itemTypes {
            b += blocks(t.label, d.catalogue.filter { $0.type == t.key && $0.active }.map(\.name).sorted(), size: 16)
        }
        b += "</div><div class=\"head\">∙ Caractère sonore</div>\(opts(Vocab.characters, extra: true))"
        b += "<div class=\"head\">∙ Technique</div><div class=\"grid\" style=\"border:none;gap:6px 18px\">"
        for l in ["Algo MicroFreak", "Tempo", "Tonalité / mode", "Patches / presets"] {
            b += "<div><div class=\"lbl\">\(l)</div><div class=\"wl\"></div></div>"
        }
        b += "</div><div class=\"lbl\">Signal routing</div><div class=\"routing\">→ → →</div>"
        b += "<div class=\"head\">∙ Influences</div><div class=\"chkcols\">"
            + blocks("Influences", d.influences.filter(\.active).map(\.name).sorted(), size: 20) + "</div>"
        b += "<div class=\"head\">∙ Enregistrement</div><div class=\"grid\" style=\"border:none;gap:6px 18px\">"
            + "<div><div class=\"lbl\">Fichier / prise</div><div class=\"wl\"></div></div>"
            + "<div><div class=\"lbl\">Timestamps</div><div class=\"wl\"></div></div></div>"
        if let o = d.randomOblique() { b += "<div class=\"head\">∙ Stratégie AZA</div><div class=\"quote\">\(esc(o))</div>" }
        b += "<div class=\"head\">∙ Notes libres</div>" + String(repeating: "<div class=\"wl\"></div>", count: 8)
        b += footer(version)
        return page("Formulaire terrain — AZA", b)
    }

    // MARK: Fiches matériel (A4 paysage)

    public static func catalogue(_ items: [GearItem], filter: String, version: String) -> String {
        var b = header("Journal de Sessions", meta: ["Fiches matériel", "v\(version)", Clock.today()])
        b += "<h1>Fiches matériel</h1><div class=\"sub\">\(items.count) fiche(s) — fabricant, fonction, usage prévu"
            + (filter.isEmpty ? "" : " · filtre : \(esc(filter))") + "</div>"
        let types = Vocab.itemTypes.map(\.key) + Set(items.map(\.type)).subtracting(Vocab.itemTypes.map(\.key)).sorted()
        for t in types {
            let rows = items.filter { $0.type == t }
                .sorted { ($0.manufacturer.lowercased(), $0.name.lowercased()) < ($1.manufacturer.lowercased(), $1.name.lowercased()) }
            guard !rows.isEmpty else { continue }
            b += "<div class=\"head\">\(esc(Vocab.itemLabel(t))) — \(rows.count)</div><table><thead><tr>"
                + "<th style=\"width:16%\">Fabricant</th><th style=\"width:20%\">Nom</th><th style=\"width:6%\">Code</th>"
                + "<th>À quoi ça sert</th><th>Comment je m'en sers</th></tr></thead><tbody>"
            for r in rows {
                let blank = "<span class=\"blank\" style=\"width:100%\"></span>"
                b += "<tr><td>\(esc(r.manufacturer.isEmpty ? "—" : r.manufacturer))</td><td><b>\(esc(r.name))</b>"
                    + (r.favorite ? " <span class=\"star\">★</span>" : "") + (r.active ? "" : " <span class=\"empty\">(inactif)</span>")
                    + "</td><td>\(esc(r.code))</td><td>\(r.purpose.isEmpty ? blank : esc(r.purpose))</td>"
                    + "<td>\(r.intent.isEmpty ? blank : esc(r.intent))</td></tr>"
            }
            b += "</tbody></table>"
        }
        b += footer(version)
        return page("Fiches matériel — AZA", b, landscape: true)
    }
}
