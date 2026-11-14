import AZACore
import CoreMIDI
import SwiftUI
import UniformTypeIdentifiers

struct SysexView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var midi: MIDIManager
    @Local private var tab = 0

    var body: some View {
        VStack(spacing: 0) {
            MIDIBar()
            Divider()
            Picker("", selection: $tab) {
                Text("Loader").tag(0)
                Text("Éditeur de banque").tag(1)
            }
            .pickerStyle(.segmented).labelsHidden().frame(width: 320).padding(8)
            if tab == 0 { SysexLoader() } else { BankEditor() }
        }
        .navigationTitle("SysEx")
        .navigationSubtitle("DX7 · Volca FM")
    }
}

/// Sortie, canal, test, journal et progression — commun aux deux onglets.
struct MIDIBar: View {
    @EnvironmentObject var midi: MIDIManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Picker("Sortie MIDI", selection: $midi.selected) {
                    Text("— Choisir une sortie —").tag(MIDIUniqueID?.none)
                    ForEach(midi.outputs) { o in Text(o.name).tag(MIDIUniqueID?.some(o.id)) }
                }
                .frame(maxWidth: 360)
                Button { midi.refresh() } label: { Image(systemName: "arrow.clockwise") }.help("Rafraîchir les sorties")
                Stepper("Canal \(midi.channel)", value: $midi.channel, in: 1...16).frame(width: 130)
                Button { midi.test() } label: { Label("Tester", systemImage: "music.note") }
                    .disabled(midi.current == nil)
                    .help("Arpège C3 → C5 sur le canal choisi")
                Spacer()
            }
            HStack {
                Text("› " + midi.log).foregroundStyle(.secondary).azaFont(.caption, mono: true).lineLimit(1)
                if let p = midi.progress { ProgressView(value: p).frame(width: 200) }
            }
        }
        .padding(10)
    }
}

// MARK: - Loader

struct SysexLoader: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var midi: MIDIManager
    @EnvironmentObject var prefs: Prefs
    @Local private var bytes: [UInt8]? = nil
    @Local private var fileName = ""
    @Local private var saveName = ""
    @Local private var dropping = false

    var body: some View {
        HSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    dropZone
                    if let b = bytes { fileInfo(b) }
                }
                .padding(14)
            }
            .frame(minWidth: 420, maxWidth: .infinity)
            library.frame(minWidth: 300, idealWidth: 360, maxWidth: 480)
        }
    }

    var dropZone: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.and.arrow.down").font(.system(size: 26)).foregroundStyle(.tint)
            Text("Dépose un fichier .syx ici").azaFont(.headline)
            Button("Choisir un fichier…") {
                if let url = Panels.open(types: ["syx", "mid", "bin"]) { load(url) }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(RoundedRectangle(cornerRadius: 6)
            .strokeBorder(dropping ? Color.accentColor : Color.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
        .onDrop(of: [.fileURL], isTargeted: $dropping) { providers in
            guard let p = providers.first else { return false }
            _ = p.loadObject(ofClass: URL.self) { url, _ in
                if let url { DispatchQueue.main.async { load(url) } }
            }
            return true
        }
    }

    func load(_ url: URL) {
        do {
            let d = try Data(contentsOf: url)
            guard d.count <= 1_000_000 else { store.lastError = "Fichier trop gros pour un SysEx (\(d.count) octets)."; return }
            bytes = [UInt8](d)
            fileName = url.lastPathComponent
            saveName = url.deletingPathExtension().lastPathComponent
        } catch { store.lastError = "Lecture impossible : \(error.localizedDescription)" }
    }

    func fileInfo(_ b: [UInt8]) -> some View {
        let names = DX7.patchNames(b)
        let surface = prefs.palette?.surface ?? Color(nsColor: .controlBackgroundColor)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(fileName).azaFont(.headline, mono: true)
                Text("\(b.count) octets").foregroundStyle(.secondary)
                Text(DX7.formatLabel(Data(b))).foregroundStyle(.tint)
                if DX7.isBulk(b) && !DX7.bulkChecksumOK(b) {
                    Label("checksum incorrect", systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                        .help("Le synthé risque de refuser ce fichier")
                }
            }
            if !names.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 4)], alignment: .leading, spacing: 4) {
                    ForEach(Array(names.enumerated()), id: \.offset) { i, n in
                        Text(String(format: "%02d  ", i + 1) + (n.isEmpty ? "—" : n))
                            .azaFont(.caption, mono: true).lineLimit(1)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 2).fill(surface))
                    }
                }
            }
            HStack {
                Button {
                    midi.sendSysex(b, label: fileName)
                } label: { Label("Envoyer", systemImage: "paperplane") }
                    .buttonStyle(.borderedProminent)
                    .disabled(midi.current == nil || midi.busy)
                Spacer()
                TextField("Nom dans la librairie", text: $saveName).frame(width: 200)
                Button("Sauvegarder") {
                    let bank = SysexBank(id: nextId(store.data.sysexBanks),
                                         name: saveName.isEmpty ? "bank" : saveName, data: Data(b))
                    store.data.sysexBanks.append(bank)
                }
            }
        }
    }

    var library: some View {
        List {
            SwiftUI.Section {
                if store.data.sysexBanks.isEmpty { Text("Aucune banque.").foregroundStyle(.secondary) }
                ForEach(store.data.sysexBanks.sorted { $0.createdAt > $1.createdAt }) { bank in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(bank.name).azaFont(.body, mono: true)
                        Text("\(bank.format) · \(bank.size) o · \(String(bank.createdAt.prefix(10)))")
                            .foregroundStyle(.secondary).azaFont(.caption)
                        HStack(spacing: 10) {
                            Button("Charger") { bytes = [UInt8](bank.data); fileName = bank.name; saveName = bank.name }
                            Button("Envoyer") { midi.sendSysex([UInt8](bank.data), label: bank.name) }
                                .disabled(midi.current == nil || midi.busy)
                            Button(".syx…") {
                                if let url = Panels.save(name: bank.name.replacingOccurrences(of: " ", with: "_") + ".syx", ext: "syx") {
                                    do { try bank.data.write(to: url) } catch { store.lastError = "\(error)" }
                                }
                            }
                            Button("Supprimer", role: .destructive) {
                                if Panels.confirm("Supprimer « \(bank.name) » ?", "", ok: "Supprimer") {
                                    store.data.sysexBanks.removeAll { $0.id == bank.id }
                                }
                            }
                        }
                        .buttonStyle(.link).azaFont(.caption)
                    }
                    .padding(.vertical, 2)
                }
            } header: { Text("LIBRAIRIE").azaHeading() }
        }
    }
}

// MARK: - Éditeur de banque

struct BankEditor: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var midi: MIDIManager
    @Local private var source: [DX7Voice] = []
    @Local private var sourceLabel = ""
    @Local private var bank: [DX7Voice?] = Array(repeating: nil, count: 32)
    @Local private var bankName = "Banque custom"

    var body: some View {
        HSplitView {
            sourcePane.frame(minWidth: 280, idealWidth: 340, maxWidth: 460)
            bankPane.frame(minWidth: 380, maxWidth: .infinity)
        }
    }

    var bulkBanks: [SysexBank] { store.data.sysexBanks.filter { DX7.isBulk([UInt8]($0.data)) } }

    var sourcePane: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SOURCE").azaHeading()
            HStack {
                Menu("Depuis la librairie") {
                    if bulkBanks.isEmpty { Text("Aucun bulk 32 voix") }
                    ForEach(bulkBanks) { b in Button(b.name) { setSource([UInt8](b.data), b.name) } }
                }
                Button("Fichier…") {
                    if let url = Panels.open(types: ["syx"]), let d = try? Data(contentsOf: url) {
                        setSource([UInt8](d), url.lastPathComponent)
                    }
                }
            }
            if !sourceLabel.isEmpty {
                HStack {
                    Text(sourceLabel).foregroundStyle(.secondary).lineLimit(1)
                    Spacer()
                    Button("+ Tous") {
                        for v in source { if let i = bank.firstIndex(where: { $0 == nil }) { bank[i] = v } }
                    }.disabled(!bank.contains { $0 == nil })
                }
            }
            List(Array(source.enumerated()), id: \.offset) { i, v in
                HStack {
                    Text(String(format: "%02d", i + 1)).foregroundStyle(.secondary).azaFont(.caption, mono: true)
                    Text(v.name.isEmpty ? "—" : v.name).azaFont(.body, mono: true)
                    Spacer()
                    Button { if let s = bank.firstIndex(where: { $0 == nil }) { bank[s] = v } } label: {
                        Image(systemName: "plus.circle")
                    }.buttonStyle(.borderless).disabled(!bank.contains { $0 == nil })
                }
            }
        }
        .padding(10)
    }

    func setSource(_ b: [UInt8], _ label: String) {
        guard let v = DX7.voices(b) else {
            store.lastError = "Format non reconnu — il faut un bulk DX7 32 voix (4104 octets)."
            return
        }
        source = v; sourceLabel = label
    }

    var bankPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("BANQUE (\(bank.compactMap { $0 }.count)/32)").azaHeading()
                TextField("Nom", text: $bankName).frame(width: 200)
                Spacer()
                Button("Vider") {
                    if Panels.confirm("Vider la banque ?", "", ok: "Vider") { bank = Array(repeating: nil, count: 32) }
                }
            }
            List {
                ForEach(0..<32, id: \.self) { i in
                    HStack(spacing: 6) {
                        Text(String(format: "%02d", i + 1)).foregroundStyle(.secondary).azaFont(.caption, mono: true)
                        if bank[i] != nil {
                            TextField("", text: Binding(get: { bank[i]?.name ?? "" },
                                                        set: { bank[i]?.name = $0 }))
                                .azaFont(.body, mono: true).frame(maxWidth: 160)
                                .help("10 caractères ASCII au plus")
                        } else {
                            Text("INIT VOICE").foregroundStyle(.tertiary).azaFont(.body, mono: true)
                        }
                        Spacer()
                        Button { move(i, -1) } label: { Image(systemName: "chevron.up") }.disabled(i == 0)
                        Button { move(i, 1) } label: { Image(systemName: "chevron.down") }.disabled(i == 31)
                        Button { bank[i] = nil } label: { Image(systemName: "xmark") }.disabled(bank[i] == nil)
                    }
                    .buttonStyle(.borderless)
                }
            }
            HStack {
                Button { midi.sendSysex(DX7.buildBulk(bank, channel: midi.channel - 1), label: bankName) } label: {
                    Label("Envoyer", systemImage: "paperplane")
                }
                .buttonStyle(.borderedProminent)
                .disabled(midi.current == nil || midi.busy || bank.allSatisfy { $0 == nil })
                Button("Exporter .syx…") {
                    if let url = Panels.save(name: bankName.replacingOccurrences(of: " ", with: "_") + ".syx", ext: "syx") {
                        do { try Data(DX7.buildBulk(bank, channel: midi.channel - 1)).write(to: url) }
                        catch { store.lastError = "\(error)" }
                    }
                }
                Button("Sauvegarder dans la librairie") {
                    store.data.sysexBanks.append(SysexBank(id: nextId(store.data.sysexBanks), name: bankName,
                                                           data: Data(DX7.buildBulk(bank))))
                }
                Spacer()
                Text("Les cases vides partent en INIT VOICE.").foregroundStyle(.secondary).azaFont(.caption)
            }
            .disabled(bank.allSatisfy { $0 == nil })
        }
        .padding(10)
    }

    func move(_ i: Int, _ d: Int) {
        let j = i + d
        guard bank.indices.contains(j) else { return }
        bank.swapAt(i, j)
    }
}
