import Foundation

// SysEx DX7 / Volca FM (sysex/api.py + sysex.html + sysex_editor.html).

/// Banque SysEx stockée dans la librairie (le JSON l'encode en base64).
public struct SysexBank: Codable, Identifiable, Hashable, Sendable {
    public var id: Int
    public var name: String
    public var format: String
    public var data: Data
    public var createdAt = Clock.stamp()

    public var size: Int { data.count }

    public init(id: Int, name: String, data: Data) {
        self.id = id; self.name = name; self.data = data
        format = DX7.formatLabel(data)
    }
    enum CodingKeys: String, CodingKey { case id, name, format, data, createdAt }
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = c.v(.name, "bank"); data = c.v(.data, Data())
        format = c.v(.format, DX7.formatLabel(data)); createdAt = c.v(.createdAt, Clock.stamp())
    }
}

/// Une voix DX7 au format « packed » 128 octets (celui des bulk dumps).
public struct DX7Voice: Hashable, Sendable {
    public var bytes: [UInt8]

    public init(bytes: [UInt8]) {
        precondition(bytes.count == 128)
        self.bytes = bytes
    }

    /// Nom : octets 118–127, ASCII imprimable.
    public var name: String {
        get {
            String(bytes[118..<128].map { b -> Character in
                let c = b & 0x7F
                return (32..<127).contains(c) ? Character(UnicodeScalar(c)) : " "
            }).replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
        }
        set {
            let ascii = newValue.folding(options: .diacriticInsensitive, locale: nil).unicodeScalars
                .map { $0.isASCII && (32..<127).contains($0.value) ? UInt8($0.value) : 0x20 }
            for i in 0..<10 { bytes[118 + i] = i < ascii.count ? ascii[i] : 0x20 }
        }
    }

    /// Voix initiale DX7 (INIT VOICE), au format packed.
    ///
    /// ⚠️ L'éditeur web écrivait 1 dans l'octet 15 (= fréquence *fixe*, coarse 0)
    /// et 0 dans l'octet 12 (= detune −7). Ici : ratio 1.00, detune centré,
    /// osc key sync et LFO sync activés, PMS 3 — les valeurs d'un vrai INIT.
    public static var initVoice: DX7Voice {
        var v = [UInt8](repeating: 0, count: 128)
        for op in 0..<6 {
            let b = op * 17
            for i in 0..<4 { v[b + i] = 99 }          // EG rates R1–R4
            for i in 4..<7 { v[b + i] = 99 }          // EG levels L1–L3
            v[b + 7] = 0                              // L4
            v[b + 12] = 7 << 3                        // detune centré (7), rate scaling 0
            v[b + 14] = op == 5 ? 99 : 0              // OP1 (stocké en dernier) seul audible
            v[b + 15] = 1 << 1                        // coarse 1, mode ratio
        }
        for i in 102..<106 { v[i] = 99 }              // pitch EG rates
        for i in 106..<110 { v[i] = 50 }              // pitch EG levels
        v[110] = 0                                    // algorithme 1
        v[111] = 1 << 3                               // osc key sync, feedback 0
        v[112] = 35                                   // LFO speed
        v[116] = (3 << 4) | 1                         // PMS 3, triangle, LFO sync
        v[117] = 24                                   // transpose C3
        var voice = DX7Voice(bytes: v)
        voice.name = "INIT VOICE"
        return voice
    }
}

public enum DX7 {
    public static let bulkSize = 4104
    public static let singleSize = 163

    public static func isBulk(_ d: [UInt8]) -> Bool {
        d.count == bulkSize && d[0] == 0xF0 && d[1] == 0x43 && d[3] == 0x09
    }
    public static func isSingle(_ d: [UInt8]) -> Bool {
        d.count == singleSize && d[0] == 0xF0 && d[1] == 0x43
    }

    public static func formatLabel(_ data: Data) -> String {
        let b = [UInt8](data)
        if isBulk(b) { return "DX7 · 32-voice bulk" }
        if isSingle(b) { return "DX7 · single voice" }
        if b.first == 0xF0 { return "SysEx générique (\(b.count) octets)" }
        return "raw (\(b.count) octets)"
    }

    /// Les 32 voix d'un bulk dump, ou nil si ce n'en est pas un.
    public static func voices(_ d: [UInt8]) -> [DX7Voice]? {
        guard isBulk(d) else { return nil }
        return (0..<32).map { DX7Voice(bytes: Array(d[(6 + $0 * 128)..<(6 + $0 * 128 + 128)])) }
    }

    /// Noms affichables d'un fichier (bulk : 32 ; single : 1 ; sinon vide).
    public static func patchNames(_ d: [UInt8]) -> [String] {
        if let v = voices(d) { return v.map(\.name) }
        if isSingle(d) {
            return [String(d[151..<161].map { b -> Character in
                let c = b & 0x7F
                return (32..<127).contains(c) ? Character(UnicodeScalar(c)) : " "
            }).trimmingCharacters(in: .whitespaces)]
        }
        return []
    }

    /// Checksum Yamaha : complément à 2 de la somme des données, sur 7 bits.
    public static func checksum<S: Sequence>(_ data: S) -> UInt8 where S.Element == UInt8 {
        UInt8(truncatingIfNeeded: -data.reduce(0) { $0 + Int($1) }) & 0x7F
    }

    /// Bulk dump 32 voix. Les cases vides reçoivent INIT VOICE.
    public static func buildBulk(_ slots: [DX7Voice?], channel: Int = 0) -> [UInt8] {
        var data: [UInt8] = []
        data.reserveCapacity(4096)
        for i in 0..<32 { data += (i < slots.count ? slots[i] : nil)?.bytes ?? DX7Voice.initVoice.bytes }
        return [0xF0, 0x43, UInt8(channel & 0x0F), 0x09, 0x20, 0x00] + data + [checksum(data), 0xF7]
    }

    /// Réécrit le canal dans l'en-tête d'un message Yamaha (octet 2, quartet bas).
    public static func withChannel(_ d: [UInt8], _ channel: Int) -> [UInt8] {
        guard d.count > 2, d[0] == 0xF0, d[1] == 0x43 else { return d }
        var out = d
        out[2] = (out[2] & 0xF0) | UInt8(channel & 0x0F)
        return out
    }

    /// Vérifie le checksum d'un bulk : utile pour repérer un fichier abîmé avant envoi.
    public static func bulkChecksumOK(_ d: [UInt8]) -> Bool {
        isBulk(d) && checksum(d[6..<4102]) == d[4102]
    }

    /// Phrase de test du loader web : arpège montant C3 → C5 puis retour.
    public static let testPhrase: [(note: UInt8, velocity: UInt8)] = [
        (48, 90), (52, 80), (55, 85), (60, 95), (64, 80), (67, 85), (72, 100), (67, 70), (60, 90),
    ]
}
