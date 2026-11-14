import Foundation

public extension AZAData {
    func nextSessionId() -> Int { (sessions.map(\.id).max() ?? 0) + 1 }
    func nextProjectId() -> Int { (projects.map(\.id).max() ?? 0) + 1 }
    func nextGearId() -> Int { (catalogue.map(\.id).max() ?? 0) + 1 }
    func nextInfluenceId() -> Int { (influences.map(\.id).max() ?? 0) + 1 }
    func nextObliqueId() -> Int { (obliques.map(\.id).max() ?? 0) + 1 }

    func project(_ id: Int?) -> Project? {
        guard let id else { return nil }
        return projects.first { $0.id == id }
    }

    func randomOblique() -> String? {
        obliques.filter(\.active).randomElement()?.text
    }

    // MARK: Nom de prise Zoom R8 — même règle que CatalogueEngine.take_name()

    static let takeMax = 8
    static let takeSep = "_"
    static let codeOrder: [GearField] = [.machines, .effects, .synthsIOS, .plugins]

    /// Codes catalogue des noms donnés, dans l'ordre, sans doublon.
    /// Un nom sans code est ignoré : on n'invente pas d'abréviation.
    func codes(for names: [String]) -> [String] {
        var byName: [String: String] = [:]
        for g in catalogue {
            let c = String(g.code.uppercased().unicodeScalars.filter {
                ("A"..."Z").contains($0) || ("0"..."9").contains($0) || $0 == "_"
            }.map(Character.init))
            if !c.isEmpty { byName[g.name] = c }
        }
        var out: [String] = []
        for n in names.map({ $0.trimmingCharacters(in: .whitespaces) }) where !n.isEmpty {
            if let c = byName[n], !out.contains(c) { out.append(c) }
        }
        return out
    }

    /// « MFMG5_1 » : codes concaténés + rang du jour. Au-delà de 8 caractères
    /// on rogne le préfixe, jamais le rang. Compteur quotidien (collision
    /// inter-jours acceptée — décision du 2026-09-27).
    func takeName(for s: Session) -> String {
        let names = Self.codeOrder.flatMap { s[keyPath: $0.keyPath] }
        let prefix = codes(for: names).joined()
        guard !prefix.isEmpty else { return "" }
        let probe = String(prefix.prefix(Self.takeMax))
        let already = sessions.filter {
            $0.id != s.id && $0.date.prefix(10) == s.date.prefix(10) && $0.audioFile.hasPrefix(probe)
        }.count
        let suffix = "\(Self.takeSep)\(already + 1)"
        let room = max(1, Self.takeMax - suffix.count)
        return String(prefix.prefix(room)) + suffix
    }

    // MARK: Export Markdown (format de session_to_md, compatible Obsidian)

    func markdown(_ s: Session, version: String) -> String {
        func or(_ v: String) -> String { v.isEmpty ? "—" : v }
        func list(_ v: [String]) -> String { v.isEmpty ? "—" : v.joined(separator: ", ") }
        let projectLine = project(s.projectId).map { "\n**Projet:** \($0.title)" } ?? ""
        return """
        # Session \(s.date)

        **Type:** \(Vocab.sessionTypeLabel(s.sessionType))
        **Mode:** \(or(s.mode))
        **Intention:** \(or(s.intention))
        **Durée:** \(s.durationMin.map(String.init) ?? "—") min
        **Énergie:** \(String(repeating: "⚡", count: s.energyLevel ?? 0))
        **Note:** \(String(repeating: "★", count: s.rating ?? 0))\(projectLine)

        ## Machines
        \(list(s.machines))

        ## Effets hardware
        \(list(s.effects))

        ## DAW
        \(list(s.daws))

        ## Synthés iOS
        \(list(s.synthsIOS))

        ## Apps iPad
        \(list(s.ipad))

        ## Zynthian / Raspberry Pi
        \(list(s.zynthian))

        ## Plugins
        \(list(s.plugins))

        ## Signal routing
        \(or(s.signalRouting))

        ## Algo MicroFreak
        \(or(s.microfreakAlgo))

        ## Patches / Presets
        \(or(s.patches))

        ## Caractère sonore
        \(list(s.character))

        ## Timestamps intéressants
        \(or(s.timestamps))

        ## Fichier audio
        \(or(s.audioFile))

        ## Tags
        \(list(s.tags))

        ## Influences
        \(list(s.influences))

        ## Lien lore AZA
        \(or(s.loreLink))

        ## Stratégie AZA
        > \(or(s.oblique))

        ## Notes libres
        \(or(s.comments))

        ## Récap session Claude
        \(or(s.recapClaude))

        ---
        *À retravailler: \(s.toRework ? "Oui" : "Non") | Potentiel release: \(s.releasePotential ? "Oui" : "Non")*
        *Journal de Sessions AZA v\(version)*

        """
    }
}

/// « a, b , c » → ["a", "b", "c"] — les champs multi-valeurs de la base Flask.
public func splitList(_ s: String?) -> [String] {
    (s ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
}
