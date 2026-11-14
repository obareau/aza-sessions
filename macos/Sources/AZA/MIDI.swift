import AZACore
import CoreMIDI
import Foundation

/// Sorties MIDI et envoi SysEx via CoreMIDI.
///
/// L'envoi SysEx passe par `MIDISendSysex`, qui cadence lui-même les octets :
/// une interface DIN à 31,25 kbaud met ~1,3 s pour un bulk de 4104 octets, et
/// tout pousser d'un bloc ferait déborder certains pilotes USB-MIDI.
@MainActor
final class MIDIManager: ObservableObject {
    struct Output: Identifiable, Hashable {
        let id: MIDIUniqueID
        let name: String
        let endpoint: MIDIEndpointRef
    }

    @Published private(set) var outputs: [Output] = []
    @Published var selected: MIDIUniqueID? {
        didSet { UserDefaults.standard.set(selected.map { Int($0) }, forKey: "midiOutput") }
    }
    @Published var channel: Int {
        didSet { UserDefaults.standard.set(channel, forKey: "midiChannel") }
    }
    @Published private(set) var progress: Double?
    @Published private(set) var log = "MIDI non initialisé"
    @Published private(set) var ready = false

    private var client = MIDIClientRef()
    private var port = MIDIPortRef()
    private var timer: Timer?

    init() {
        channel = max(1, min(16, UserDefaults.standard.integer(forKey: "midiChannel") == 0
                                  ? 1 : UserDefaults.standard.integer(forKey: "midiChannel")))
        if let s = UserDefaults.standard.object(forKey: "midiOutput") as? Int { selected = MIDIUniqueID(s) }
        let st = MIDIClientCreateWithBlock("AZA" as CFString, &client) { [weak self] _ in
            DispatchQueue.main.async { self?.refresh() }
        }
        guard st == noErr, MIDIOutputPortCreate(client, "AZA out" as CFString, &port) == noErr else {
            log = "✗ CoreMIDI indisponible (\(st))"
            return
        }
        ready = true
        refresh()
    }

    func refresh() {
        outputs = (0..<MIDIGetNumberOfDestinations()).compactMap { i in
            let e = MIDIGetDestination(i)
            guard e != 0 else { return nil }
            var uid: MIDIUniqueID = 0
            MIDIObjectGetIntegerProperty(e, kMIDIPropertyUniqueID, &uid)
            var cf: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(e, kMIDIPropertyDisplayName, &cf)
            let name = (cf?.takeRetainedValue() as String?) ?? "Sortie \(i + 1)"
            return Output(id: uid, name: name, endpoint: e)
        }
        if let s = selected, !outputs.contains(where: { $0.id == s }) { selected = nil }
        if selected == nil, outputs.count == 1 { selected = outputs[0].id }
        if ready { log = "MIDI prêt · \(outputs.count) sortie(s)" }
    }

    var current: Output? { outputs.first { $0.id == selected } }
    var busy: Bool { progress != nil }

    /// Message court (notes) — un seul paquet.
    private func sendShort(_ bytes: [UInt8], to e: MIDIEndpointRef) {
        var buffer = [UInt8](repeating: 0, count: 256)
        buffer.withUnsafeMutableBytes { raw in
            let list = raw.baseAddress!.assumingMemoryBound(to: MIDIPacketList.self)
            let pkt = MIDIPacketListInit(list)
            _ = MIDIPacketListAdd(list, 256, pkt, 0, bytes.count, bytes)
            MIDISend(port, e, list)
        }
    }

    /// Arpège C3 → C5 pour vérifier sortie et canal à l'oreille.
    func test() {
        guard let out = current else { return }
        let ch = UInt8((channel - 1) & 0x0F)
        for (i, n) in DX7.testPhrase.enumerated() {
            let t = Double(i) * 0.13
            DispatchQueue.main.asyncAfter(deadline: .now() + t) { [weak self] in
                self?.sendShort([0x90 | ch, n.note, n.velocity], to: out.endpoint)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + t + 0.11) { [weak self] in
                self?.sendShort([0x80 | ch, n.note, 0], to: out.endpoint)
            }
        }
        log = "♪ Test sur canal \(channel) → \(out.name)"
    }

    /// Envoie un SysEx (canal réécrit pour les messages Yamaha). `done` reçoit le message final.
    func sendSysex(_ raw: [UInt8], label: String, done: ((String) -> Void)? = nil) {
        guard let out = current else { log = "⚠ Aucune sortie MIDI choisie"; return }
        guard !busy else { return }
        guard raw.first == 0xF0, raw.last == 0xF7 else {
            log = "✗ Ce n'est pas un message SysEx complet (F0 … F7)"
            done?(log); return
        }
        let bytes = DX7.withChannel(raw, channel - 1)
        let count = bytes.count
        let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
        buf.initialize(from: bytes, count: count)
        let req = UnsafeMutablePointer<MIDISysexSendRequest>.allocate(capacity: 1)
        req.initialize(to: MIDISysexSendRequest(destination: out.endpoint, data: UnsafePointer(buf),
                                                bytesToSend: UInt32(count), complete: false,
                                                reserved: (0, 0, 0), completionProc: { _ in },
                                                completionRefCon: nil))
        let st = MIDISendSysex(req)
        guard st == noErr else {
            req.deallocate(); buf.deallocate()
            log = "✗ Erreur CoreMIDI \(st)"
            done?(log); return
        }
        progress = 0
        log = "Envoi → \(out.name) (canal \(channel), \(count) octets)"
        let started = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] t in
            MainActor.assumeIsolated {
                guard let self else { t.invalidate(); return }
                let left = Double(req.pointee.bytesToSend)
                self.progress = 1 - left / Double(count)
                // Garde-fou : un pilote qui ne termine jamais ne bloque pas l'app.
                let timedOut = Date().timeIntervalSince(started) > 30
                if req.pointee.complete.boolValue || timedOut {
                    t.invalidate()
                    if timedOut && !req.pointee.complete.boolValue {
                        req.pointee.complete = true
                        self.log = "✗ Envoi interrompu (délai dépassé)"
                    } else {
                        self.log = "✓ \(label) envoyé → \(out.name), canal \(self.channel)"
                    }
                    // Laisser CoreMIDI relâcher la requête avant de libérer la mémoire.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { req.deallocate(); buf.deallocate() }
                    self.progress = nil
                    done?(self.log)
                }
            }
        }
    }
}
