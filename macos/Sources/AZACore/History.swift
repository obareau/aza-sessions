import Foundation

// Annuler / rétablir, et comparaison d'une sauvegarde avec l'état actuel.

public extension AZAData {
    /// Parties du document, avec leur nom affichable — pour nommer une annulation
    /// (« Annuler — journal ») et résumer ce qu'une sauvegarde changerait.
    static func changedParts(_ a: AZAData, _ b: AZAData) -> [String] {
        var out: [String] = []
        if a.sessions != b.sessions { out.append("séances") }
        if a.diary != b.diary { out.append("journal") }
        if a.catalogue != b.catalogue { out.append("catalogue") }
        if a.patches != b.patches { out.append("patcher") }
        if a.projects != b.projects { out.append("projets") }
        if a.presets != b.presets { out.append("presets") }
        if a.knobSheets != b.knobSheets { out.append("façades") }
        if a.gearNotes != b.gearNotes || a.gearPairings != b.gearPairings { out.append("carnet d'instrument") }
        if a.influences != b.influences { out.append("influences") }
        if a.obliques != b.obliques { out.append("stratégies") }
        if a.sysexBanks != b.sysexBanks { out.append("SysEx") }
        if a.live != b.live { out.append("séance en cours") }
        if a.wishlist != b.wishlist || a.tracks != b.tracks || a.inspirations != b.inspirations
            || a.samples != b.samples || a.mirack != b.mirack { out.append("références") }
        return out
    }
}

/// Pile d'annulation du document entier. Les tableaux Swift étant partagés
/// tant qu'on ne les modifie pas, garder 100 états ne coûte presque rien.
public struct EditHistory: Sendable {
    public struct Step: Sendable {
        public let state: AZAData
        public let label: String
        public let at: Date
    }

    public private(set) var undoStack: [Step] = []
    public private(set) var redoStack: [Step] = []
    public var limit = 100
    /// Deux modifications de la même partie à moins de ce délai ne font qu'une
    /// étape : une phrase tapée s'annule d'un coup, pas lettre par lettre.
    public var coalesce: TimeInterval = 1.5

    public init() {}

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }
    public var undoLabel: String? { undoStack.last?.label }
    public var redoLabel: String? { redoStack.last?.label }

    /// À appeler à chaque modification locale, avec l'état d'avant.
    public mutating func record(before: AZAData, after: AZAData, at now: Date = Date()) {
        let label = AZAData.changedParts(before, after).first ?? "modification"
        redoStack.removeAll()
        if let last = undoStack.last, last.label == label, now.timeIntervalSince(last.at) < coalesce {
            // Même geste qui continue : on garde l'état d'avant le premier coup, on prolonge la fenêtre.
            undoStack[undoStack.count - 1] = Step(state: last.state, label: label, at: now)
            return
        }
        undoStack.append(Step(state: before, label: label, at: now))
        if undoStack.count > limit { undoStack.removeFirst(undoStack.count - limit) }
    }

    /// Rend l'état à rétablir, et garde `current` pour « Rétablir ».
    public mutating func undo(current: AZAData) -> AZAData? {
        guard let step = undoStack.popLast() else { return nil }
        redoStack.append(Step(state: current, label: step.label, at: Date()))
        return step.state
    }

    public mutating func redo(current: AZAData) -> AZAData? {
        guard let step = redoStack.popLast() else { return nil }
        undoStack.append(Step(state: current, label: step.label, at: .distantPast))
        return step.state
    }

    public mutating func clear() { undoStack.removeAll(); redoStack.removeAll() }
}

// MARK: - Comparer une sauvegarde à l'état actuel

public struct CollectionDiff: Sendable, Equatable {
    public var name: String
    /// Dans la sauvegarde, plus dans l'état actuel (supprimés depuis).
    public var onlyInBackup: [Int] = []
    /// Dans l'état actuel, pas dans la sauvegarde (créés depuis).
    public var onlyInCurrent: [Int] = []
    /// Présents des deux côtés mais différents.
    public var changed: [Int] = []
    public var isEmpty: Bool { onlyInBackup.isEmpty && onlyInCurrent.isEmpty && changed.isEmpty }
}

public struct BackupDiff: Sendable {
    public var parts: [CollectionDiff]
    public var otherChanges: [String]
    public var isEmpty: Bool { parts.allSatisfy(\.isEmpty) && otherChanges.isEmpty }
}

public extension AZAData {
    private static func diff<T: Identifiable & Equatable>(_ name: String, _ backup: [T], _ current: [T]) -> CollectionDiff where T.ID == Int {
        let b = Dictionary(backup.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let c = Dictionary(current.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var d = CollectionDiff(name: name)
        d.onlyInBackup = b.keys.filter { c[$0] == nil }.sorted()
        d.onlyInCurrent = c.keys.filter { b[$0] == nil }.sorted()
        d.changed = b.keys.filter { c[$0] != nil && c[$0]! != b[$0]! }.sorted()
        return d
    }

    /// Ce qui distingue `backup` de cet état (self = état actuel).
    func diff(fromBackup backup: AZAData) -> BackupDiff {
        let parts = [
            Self.diff("Séances", backup.sessions, sessions),
            Self.diff("Journal", backup.diary, diary),
            Self.diff("Catalogue", backup.catalogue, catalogue),
            Self.diff("Patches", backup.patches, patches),
            Self.diff("Projets", backup.projects, projects),
            Self.diff("Presets", backup.presets, presets),
            Self.diff("Relevés de façade", backup.knobSheets, knobSheets),
        ]
        var others: [String] = []
        let covered = Set(["séances", "journal", "catalogue", "patcher", "projets", "presets", "façades"])
        for p in AZAData.changedParts(backup, self) where !covered.contains(p) { others.append(p) }
        return BackupDiff(parts: parts, otherChanges: others)
    }

    /// Reprend des séances et des entrées de journal d'une sauvegarde, sans toucher au reste.
    /// Une séance supprimée revient avec son identifiant ; une séance modifiée depuis revient
    /// en plus de la version actuelle (nouvel identifiant), pour ne rien écraser.
    mutating func recover(sessions ids: [Int], diary diaryIds: [Int], from backup: AZAData) -> Int {
        var n = 0
        for id in ids {
            guard var s = backup.sessions.first(where: { $0.id == id }) else { continue }
            if sessions.contains(where: { $0.id == id }) {
                s.id = nextSessionId(); s.title = (s.title.isEmpty ? s.displayTitle : s.title) + " (restaurée)"
                s.linkedSession = id
            }
            sessions.append(s); n += 1
        }
        for id in diaryIds {
            guard var e = backup.diary.first(where: { $0.id == id }) else { continue }
            if diary.contains(where: { $0.id == id }) {
                e.id = nextId(diary); e.title = e.displayTitle + " (restaurée)"
            }
            diary.append(e); n += 1
        }
        return n
    }
}
