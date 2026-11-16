import AppKit
import AZACore
import SwiftUI
import UniformTypeIdentifiers

/// Vignettes des photos, gardées en mémoire (relire un JPEG à chaque rendu serait lent).
@MainActor
enum Thumbs {
    static let cache = NSCache<NSURL, NSImage>()
    static func image(_ url: URL, max: CGFloat = 480) -> NSImage? {
        if let i = cache.object(forKey: url as NSURL) { return i }
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: max] as CFDictionary) else { return nil }
        let img = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        cache.setObject(img, forKey: url as NSURL)
        return img
    }
}

enum DiaryMode: String, CaseIterable { case feed = "Fil", calendar = "Calendrier", insights = "Aperçu" }
enum DiaryFilter: String, CaseIterable {
    case all = "Toutes", bookmarked = "Signets", photos = "Avec photos", audio = "Avec son"
    case mood = "Avec humeur", linked = "Liées à AZA"
}

struct DiaryView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @EnvironmentObject var prefs: Prefs
    @EnvironmentObject var lore: LoreCache
    @StateObject private var lock = DiaryLock()
    @Local private var mode = DiaryMode.feed
    @Local private var query = ""
    @Local private var filter = DiaryFilter.all
    @Local private var dayFilter: String? = nil
    @Local private var prompts: [DiaryPrompt] = []
    @Local private var showPrompts = true

    var body: some View {
        Group {
            if prefs.diaryLock && !lock.unlocked {
                locked
            } else {
                VStack(spacing: 0) {
                    bar
                    Divider()
                    switch mode {
                    case .feed: feed
                    case .calendar: DiaryCalendar(dayFilter: $dayFilter, open: { mode = .feed; nav.diary = $0 },
                                                  create: { day in mode = .feed; nav.diary = store.newDiaryEntry(day: day) })
                    case .insights: DiaryInsightsView()
                    }
                }
            }
        }
        .navigationTitle("Journal")
        .navigationSubtitle("\(store.data.diary.count) entrée(s)")
        .onReceive(NotificationCenter.default.publisher(for: .azaDiaryMode)) { n in
            if let raw = n.object as? String, let m = DiaryMode(rawValue: raw) { mode = m }
        }
        .onAppear {
            if prompts.isEmpty { refreshPrompts() }
            if prefs.diaryLock && !lock.unlocked { lock.unlock() }
        }
    }

    func refreshPrompts() {
        prompts = Array(store.data.diaryPrompts(lore: lore.quotes.map(\.text)).prefix(8))
    }

    var locked: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.fill").font(.system(size: 40)).foregroundStyle(.tint)
            Text("Journal verrouillé").azaFont(.title2, mono: true)
            if !lock.message.isEmpty { Text(lock.message).foregroundStyle(.secondary) }
            Button("Déverrouiller") { lock.unlock() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var bar: some View {
        HStack(spacing: 10) {
            Picker("", selection: $mode) {
                ForEach(DiaryMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden().frame(width: 280)
            TextField("Rechercher dans le journal…", text: $query).textFieldStyle(.roundedBorder).frame(maxWidth: 300)
            Picker("", selection: $filter) {
                ForEach(DiaryFilter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.labelsHidden().frame(width: 140)
            if let d = dayFilter {
                Button { dayFilter = nil } label: { Label(d, systemImage: "xmark.circle.fill") }.buttonStyle(.borderless)
            }
            Spacer()
            if prefs.diaryLock {
                Button { lock.lock() } label: { Image(systemName: "lock") }.help("Verrouiller le journal")
            }
            Button { nav.diary = store.newDiaryEntry(); mode = .feed } label: { Label("Nouvelle entrée", systemImage: "square.and.pencil") }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("j", modifiers: [.command, .shift])
                .help("Nouvelle entrée (⇧⌘J)")
        }
        .padding(8)
    }

    var entries: [DiaryEntry] {
        store.data.diarySearch(query).filter { e in
            if let d = dayFilter, e.day != d { return false }
            switch filter {
            case .all: return true
            case .bookmarked: return e.bookmarked
            case .photos: return e.attachments.contains { $0.kind == .image }
            case .audio: return e.attachments.contains { $0.kind == .audio }
            case .mood: return e.mood != nil
            case .linked: return e.hasLinks
            }
        }
    }

    var feed: some View {
        HSplitView {
            VStack(spacing: 0) {
                if showPrompts && !prompts.isEmpty { promptStrip; Divider() }
                let list = entries
                if list.isEmpty {
                    VStack(spacing: 8) {
                        Text(store.data.diary.isEmpty ? "Ton journal est vide." : "Aucune entrée ne correspond.")
                            .foregroundStyle(.secondary)
                        if store.data.diary.isEmpty {
                            Text("Choisis une suggestion ci-dessus, ou commence par une page blanche (⇧⌘J).")
                                .foregroundStyle(.tertiary).azaFont(.caption)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: $nav.diary) {
                        let months = list.reduce(into: [String]()) { if $0.last != String($1.date.prefix(7)) { $0.append(String($1.date.prefix(7))) } }
                        ForEach(months, id: \.self) { m in
                            SwiftUI.Section {
                                ForEach(list.filter { $0.date.hasPrefix(m) }) { e in
                                    DiaryCard(entry: e).tag(e.id)
                                        .contextMenu {
                                            Button(e.bookmarked ? "Retirer le signet" : "Ajouter un signet") { toggleBookmark(e.id) }
                                            Button("Supprimer…", role: .destructive) { delete(e) }
                                        }
                                }
                            } header: { Text(monthLabel(m).uppercased()).azaHeading(.caption2) }
                        }
                    }
                }
            }
            .frame(minWidth: 300, idealWidth: 360, maxWidth: 480)

            Group {
                if let id = nav.diary, let i = store.data.diary.firstIndex(where: { $0.id == id }) {
                    DiaryEditor(entry: $store.data.diary[i]).id(id)
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "book.pages").font(.system(size: 36)).foregroundStyle(.tint)
                        Text("Journal").azaFont(.title2, mono: true)
                        Text("Ce que tu vis autour de la musique, de Scaër et du lore — avec photos, sons et humeur.")
                            .foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 360)
                        Button("Nouvelle entrée") { nav.diary = store.newDiaryEntry() }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 520, maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    var promptStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("SUGGESTIONS").azaHeading(.caption2)
                Spacer()
                Button { refreshPrompts() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.borderless)
                Button { showPrompts = false } label: { Image(systemName: "chevron.up") }.buttonStyle(.borderless)
                    .help("Masquer les suggestions")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(prompts) { p in
                        Button { nav.diary = store.newDiaryEntry(prompt: p) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Label(p.kind.uppercased(), systemImage: p.icon).azaFont(.caption2, mono: true).foregroundStyle(.tint)
                                Text(p.text).azaFont(.callout).lineLimit(4).multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                            }
                            .padding(10)
                            .frame(width: 210, height: 108, alignment: .topLeading)
                            .background(RoundedRectangle(cornerRadius: 8).fill(prefs.palette?.surface ?? Color(nsColor: .controlBackgroundColor)))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Écrire à partir de cette suggestion")
                    }
                }
            }
        }
        .padding(8)
    }

    func monthLabel(_ m: String) -> String {
        guard let d = Clock.day(m + "-01") else { return m }
        let f = DateFormatter(); f.locale = Locale(identifier: "fr_FR"); f.dateFormat = "LLLL yyyy"
        return f.string(from: d)
    }

    func toggleBookmark(_ id: Int) {
        if let i = store.data.diary.firstIndex(where: { $0.id == id }) { store.data.diary[i].bookmarked.toggle() }
    }

    func delete(_ e: DiaryEntry) {
        guard Panels.confirm("Supprimer « \(e.displayTitle) » ?",
                             e.attachments.isEmpty ? "" : "Ses \(e.attachments.count) média(s) partent à la corbeille.",
                             ok: "Supprimer") else { return }
        if nav.diary == e.id { nav.diary = nil }
        store.deleteDiaryEntry(e.id)
    }
}

struct DiaryCard: View {
    @EnvironmentObject var store: Store
    let entry: DiaryEntry

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(dayLabel).foregroundStyle(.secondary).azaFont(.caption, mono: true)
                    if let m = entry.mood { Text(DiaryVocab.moodSymbols[m - 1]).foregroundStyle(moodColor(m)) }
                    if entry.bookmarked { Image(systemName: "bookmark.fill").foregroundStyle(.tint).font(.caption) }
                    if entry.attachments.contains(where: { $0.kind == .audio }) { Image(systemName: "waveform").font(.caption) }
                }
                Text(entry.displayTitle).azaFont(.headline).lineLimit(2)
                if !entry.excerpt.isEmpty { Text(entry.excerpt).foregroundStyle(.secondary).azaFont(.callout).lineLimit(3) }
            }
            Spacer(minLength: 0)
            if let img = entry.attachments.first(where: { $0.kind == .image }),
               let ns = Thumbs.image(store.mediaURL(img), max: 160) {
                Image(nsImage: ns).resizable().aspectRatio(contentMode: .fill)
                    .frame(width: 58, height: 58).clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(.vertical, 4)
    }

    var dayLabel: String {
        guard let d = Clock.day(entry.day) else { return entry.day }
        let f = DateFormatter(); f.locale = Locale(identifier: "fr_FR"); f.dateFormat = "EEE d"
        return f.string(from: d) + " · " + String(entry.date.dropFirst(11).prefix(5))
    }
}

func moodColor(_ m: Int) -> Color {
    // Du froid au chaud : bleu-gris → orange AZA.
    let t = Double(m - 1) / 6
    return Color(red: 0.35 + 0.62 * t, green: 0.45 + 0.0 * t, blue: 0.62 - 0.53 * t)
}

// MARK: - Éditeur d'entrée

struct DiaryEditor: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @EnvironmentObject var prefs: Prefs
    @EnvironmentObject var lore: LoreCache
    @Binding var entry: DiaryEntry
    @StateObject private var recorder = DiaryRecorder()
    @StateObject private var player = DiaryPlayer()
    @Local private var dropping = false
    @Local private var status = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                if !entry.prompt.isEmpty {
                    HStack(alignment: .top) {
                        Rectangle().fill(Color.secondary.opacity(0.5)).frame(width: 2)
                        Text(entry.prompt).italic().foregroundStyle(.secondary)
                        Spacer()
                        Button { entry.prompt = "" } label: { Image(systemName: "xmark") }.buttonStyle(.borderless)
                            .foregroundStyle(.tertiary).help("Retirer la suggestion")
                    }
                }
                TextField("Titre", text: $entry.title, prompt: Text(entry.displayTitle == "Entrée du \(entry.day)" ? "Titre" : entry.displayTitle))
                    .textFieldStyle(.plain).azaFont(.title, mono: prefs.monoTitles)
                TextEditor(text: $entry.body)
                    .azaFont(.title3)
                    .lineSpacing(4)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 260)
                    .overlay(alignment: .topLeading) {
                        if entry.body.isEmpty {
                            Text("Écris…").azaFont(.title3).foregroundStyle(.tertiary).padding(.leading, 5).allowsHitTesting(false)
                        }
                    }
                media
                Divider()
                moodSection
                Divider()
                links
                HStack {
                    Text("\(entry.wordCount) mot(s)").foregroundStyle(.tertiary).azaFont(.caption)
                    Spacer()
                    if !status.isEmpty { Text(status).foregroundStyle(.secondary).azaFont(.caption) }
                }
            }
            .padding(24)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .onDrop(of: [.fileURL], isTargeted: $dropping) { providers in
            for p in providers {
                _ = p.loadObject(ofClass: URL.self) { url, _ in
                    if let url { DispatchQueue.main.async { store.attach(url, to: entry.id) } }
                }
            }
            return true
        }
        .overlay {
            if dropping {
                RoundedRectangle(cornerRadius: 10).strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 5]))
                    .foregroundStyle(.tint).padding(8).allowsHitTesting(false)
            }
        }
        .onChange(of: entry.body) { _ in entry.updatedAt = Clock.stamp() }
        .onDisappear { if recorder.recording { recorder.stop() }; player.stop() }
    }

    var date: Binding<Date> {
        Binding(get: { Clock.stampDate(entry.date) ?? Date() }, set: { entry.date = Clock.stamp($0) })
    }

    var header: some View {
        HStack {
            DatePicker("", selection: date, displayedComponents: [.date, .hourAndMinute]).labelsHidden()
            TextField("Lieu", text: $entry.place).frame(maxWidth: 180)
            Spacer()
            Button { entry.bookmarked.toggle() } label: {
                Image(systemName: entry.bookmarked ? "bookmark.fill" : "bookmark")
            }
            .buttonStyle(.borderless).foregroundStyle(.tint).help("Signet")
            Menu {
                Button("Écrire dans le vault Obsidian") {
                    status = store.exportDiaryToVault([entry.id], folder: prefs.obsidianVault)
                }.disabled(prefs.obsidianVault.isEmpty)
                Button("Exporter en Markdown…") {
                    if let url = Panels.save(name: AZAData.diaryFileName(entry), ext: "md") {
                        try? store.data.diaryMarkdown(entry).write(to: url, atomically: true, encoding: .utf8)
                    }
                }
                Divider()
                Button("Supprimer l'entrée…", role: .destructive) {
                    guard Panels.confirm("Supprimer « \(entry.displayTitle) » ?",
                                         entry.attachments.isEmpty ? "" : "Ses médias partent à la corbeille.",
                                         ok: "Supprimer") else { return }
                    let id = entry.id
                    nav.diary = nil
                    store.deleteDiaryEntry(id)
                }
            } label: { Image(systemName: "ellipsis.circle") }
                .menuStyle(.borderlessButton).frame(width: 34)
        }
    }

    // MARK: Médias

    var media: some View {
        VStack(alignment: .leading, spacing: 8) {
            let images = entry.attachments.filter { $0.kind == .image }
            if !images.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                    ForEach(images) { a in
                        let url = store.mediaURL(a)
                        Group {
                            if let img = Thumbs.image(url) {
                                Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Rectangle().fill(Color.secondary.opacity(0.2)).overlay(Image(systemName: "photo"))
                            }
                        }
                        .frame(height: 120).frame(maxWidth: .infinity).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .onTapGesture(count: 2) { NSWorkspace.shared.open(url) }
                        .contextMenu {
                            Button("Ouvrir") { NSWorkspace.shared.open(url) }
                            Button("Afficher dans le Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                            Button("Retirer (corbeille)", role: .destructive) { store.detach(a, from: entry.id) }
                        }
                        .help(a.caption)
                    }
                }
            }
            ForEach(entry.attachments.filter { $0.kind != .image }) { a in
                let url = store.mediaURL(a)
                HStack(spacing: 8) {
                    if a.kind == .audio {
                        Button { player.toggle(a.id, url: url) } label: {
                            Image(systemName: player.playing == a.id ? "stop.circle.fill" : "play.circle.fill").font(.title2)
                        }.buttonStyle(.borderless).foregroundStyle(.tint)
                        if player.playing == a.id { ProgressView(value: player.progress).frame(width: 140) }
                        else { Text(DiaryPlayer.duration(url)).monospacedDigit().foregroundStyle(.secondary) }
                    } else {
                        Image(systemName: "doc").foregroundStyle(.secondary)
                    }
                    TextField(a.kind == .audio ? "Note audio" : a.file, text: caption(a)).textFieldStyle(.plain)
                    Spacer()
                    Button { NSWorkspace.shared.activateFileViewerSelecting([url]) } label: { Image(systemName: "folder") }
                        .buttonStyle(.borderless).help("Afficher dans le Finder")
                    Button { store.detach(a, from: entry.id) } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless).foregroundStyle(.secondary).help("Retirer (le fichier va à la corbeille)")
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(prefs.palette?.surface ?? Color(nsColor: .controlBackgroundColor)))
            }
            HStack(spacing: 10) {
                Button {
                    let p = NSOpenPanel()
                    p.allowsMultipleSelection = true
                    p.allowedContentTypes = [.image, .audio, .movie, .pdf, .item]
                    if p.runModal() == .OK { for u in p.urls { store.attach(u, to: entry.id) } }
                } label: { Label("Photos, fichiers…", systemImage: "photo.on.rectangle") }
                if recorder.recording {
                    Button { recorder.stop() } label: {
                        Label(String(format: "Arrêter  %d:%02d", Int(recorder.elapsed) / 60, Int(recorder.elapsed) % 60),
                              systemImage: "stop.fill")
                    }
                    .buttonStyle(.borderedProminent).tint(.red)
                } else {
                    Button {
                        recorder.start(for: entry.id) { url, id in store.attach(url, to: id, kind: .audio, move: true) }
                    } label: { Label("Enregistrer un son", systemImage: "mic") }
                }
                Text("ou glisse des fichiers ici").foregroundStyle(.tertiary).azaFont(.caption)
            }
            if let e = recorder.error { Label(e, systemImage: "exclamationmark.triangle").foregroundStyle(.orange).azaFont(.caption) }
        }
    }

    func caption(_ a: DiaryAttachment) -> Binding<String> {
        Binding(get: { entry.attachments.first { $0.id == a.id }?.caption ?? "" },
                set: { v in if let i = entry.attachments.firstIndex(where: { $0.id == a.id }) { entry.attachments[i].caption = v } })
    }

    // MARK: État d'esprit

    var moodSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ÉTAT D'ESPRIT").azaHeading(.caption2)
                if let m = entry.mood {
                    Text(DiaryVocab.moods[m - 1]).foregroundStyle(moodColor(m)).azaFont(.callout)
                    Button { entry.mood = nil } label: { Image(systemName: "xmark.circle") }.buttonStyle(.borderless)
                        .foregroundStyle(.tertiary)
                }
            }
            HStack(spacing: 8) {
                ForEach(1...7, id: \.self) { m in
                    Button { entry.mood = m } label: {
                        Circle().fill(moodColor(m).opacity(entry.mood == m ? 1 : 0.28))
                            .overlay(Circle().stroke(entry.mood == m ? Color.primary.opacity(0.6) : .clear, lineWidth: 2))
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain).help(DiaryVocab.moods[m - 1])
                }
            }
            if entry.mood != nil {
                Text("Ce que tu ressens").foregroundStyle(.secondary).azaFont(.caption)
                FlowToggles(options: DiaryVocab.feelings, values: $entry.feelings)
                Text("Ce qui y est lié").foregroundStyle(.secondary).azaFont(.caption)
                FlowToggles(options: DiaryVocab.associations, values: $entry.associations)
            }
        }
    }

    // MARK: Liens vers AZA

    var links: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("LIÉ À").azaHeading(.caption2)
                Menu("Séance") {
                    ForEach(store.data.sessions.sorted { $0.date > $1.date }.prefix(40)) { s in
                        Button("\(s.date) — \(s.displayTitle)") { if !entry.sessionIds.contains(s.id) { entry.sessionIds.append(s.id) } }
                    }
                }.frame(width: 100)
                Menu("Matériel") {
                    ForEach(Vocab.itemTypes, id: \.key) { t in
                        let items = store.data.catalogue.filter { $0.type == t.key && $0.active }
                        if !items.isEmpty {
                            Menu(t.label) {
                                ForEach(items.sorted { $0.name < $1.name }) { g in
                                    Button(g.name) { if !entry.gearIds.contains(g.id) { entry.gearIds.append(g.id) } }
                                }
                            }
                        }
                    }
                }.frame(width: 100)
                Menu("Patch") {
                    ForEach(store.data.patches) { p in
                        Button(p.name) { if !entry.patchIds.contains(p.id) { entry.patchIds.append(p.id) } }
                    }
                }.frame(width: 90).disabled(store.data.patches.isEmpty)
                Menu("Lore") {
                    if !lore.available { Text("Corpus de lore non configuré") }
                    ForEach(LoreReader.sections.filter { lore.count($0.key) > 0 }, id: \.key) { s in
                        Menu(s.name) {
                            ForEach(lore.entries.filter { $0.section == s.key }) { e in
                                Button(e.title) { if !entry.loreTitles.contains(e.title) { entry.loreTitles.append(e.title) } }
                            }
                        }
                    }
                }.frame(width: 80)
            }
            let chips = linkChips
            if !chips.isEmpty {
                FlowChips(chips: chips)
            }
        }
    }

    var linkChips: [LinkChip] {
        var out: [LinkChip] = []
        for id in entry.sessionIds {
            let name = store.data.sessions.first { $0.id == id }?.displayTitle ?? "séance #\(id)"
            out.append(LinkChip(id: "s\(id)", icon: "waveform", label: name, open: { nav.open(session: id) },
                                remove: { entry.sessionIds.removeAll { $0 == id } }))
        }
        for id in entry.gearIds {
            out.append(LinkChip(id: "g\(id)", icon: "pianokeys", label: store.data.gear(id)?.name ?? "fiche #\(id)",
                                open: { nav.open(gear: id) }, remove: { entry.gearIds.removeAll { $0 == id } }))
        }
        for id in entry.patchIds {
            out.append(LinkChip(id: "p\(id)", icon: "point.3.connected.trianglepath.dotted",
                                label: store.data.patches.first { $0.id == id }?.name ?? "patch #\(id)",
                                open: { nav.open(patch: id) }, remove: { entry.patchIds.removeAll { $0 == id } }))
        }
        for t in entry.loreTitles {
            out.append(LinkChip(id: "l\(t)", icon: "book.closed", label: t,
                                open: { nav.pane = .lore }, remove: { entry.loreTitles.removeAll { $0 == t } }))
        }
        return out
    }
}

struct LinkChip: Identifiable {
    let id: String
    let icon: String
    let label: String
    let open: () -> Void
    let remove: () -> Void
}

struct FlowChips: View {
    let chips: [LinkChip]
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(chips) { c in
                HStack(spacing: 4) {
                    Button(action: c.open) { Label(c.label, systemImage: c.icon).lineLimit(1) }.buttonStyle(.link)
                    Button(action: c.remove) { Image(systemName: "xmark") }.buttonStyle(.borderless).foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().stroke(Color.secondary.opacity(0.35)))
            }
        }
    }
}

// MARK: - Calendrier

struct DiaryCalendar: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var prefs: Prefs
    @Binding var dayFilter: String?
    let open: (Int) -> Void
    let create: (String) -> Void
    @Local private var month = Date()

    var body: some View {
        let cal = Self.calendar
        let first = cal.date(from: cal.dateComponents([.year, .month], from: month))!
        let lead = (cal.component(.weekday, from: first) + 5) % 7
        let count = cal.range(of: .day, in: .month, for: first)!.count
        let byDay = Dictionary(grouping: store.data.diary, by: \.day)
        let f = DateFormatter()
        let _ = { f.locale = Locale(identifier: "fr_FR"); f.dateFormat = "LLLL yyyy" }()
        VStack(spacing: 10) {
            HStack {
                Button { month = cal.date(byAdding: .month, value: -1, to: month)! } label: { Image(systemName: "chevron.left") }
                Text(f.string(from: first).capitalized).azaFont(.title2, mono: true).frame(minWidth: 220)
                Button { month = cal.date(byAdding: .month, value: 1, to: month)! } label: { Image(systemName: "chevron.right") }
                Button("Aujourd'hui") { month = Date() }
            }
            .buttonStyle(.borderless)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(["lun", "mar", "mer", "jeu", "ven", "sam", "dim"], id: \.self) {
                    Text($0.uppercased()).foregroundStyle(.secondary).azaFont(.caption2, mono: true)
                }
                ForEach(0..<(lead + count), id: \.self) { i in
                    if i < lead {
                        Color.clear.frame(height: 78)
                    } else {
                        let date = cal.date(byAdding: .day, value: i - lead, to: first)!
                        let key = Clock.day(date)
                        dayCell(key: key, number: i - lead + 1, entries: byDay[key] ?? [],
                                today: key == Clock.today())
                    }
                }
            }
            Text("Clic : voir les entrées du jour · double-clic sur un jour vide : écrire ce jour-là")
                .foregroundStyle(.tertiary).azaFont(.caption)
        }
        .padding(20)
        .frame(maxWidth: 900, maxHeight: .infinity, alignment: .top)
        .frame(maxWidth: .infinity)
    }

    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian); c.firstWeekday = 2; c.locale = Locale(identifier: "fr_FR"); return c
    }

    func dayCell(key: String, number: Int, entries: [DiaryEntry], today: Bool) -> some View {
        let thumb = entries.flatMap(\.attachments).first { $0.kind == .image }.flatMap { Thumbs.image(store.mediaURL($0), max: 200) }
        let mood = entries.compactMap(\.mood).last
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8).fill(prefs.palette?.surface ?? Color(nsColor: .controlBackgroundColor))
            if let t = thumb {
                Image(nsImage: t).resizable().aspectRatio(contentMode: .fill).opacity(0.55)
                    .frame(maxWidth: .infinity, maxHeight: .infinity).clipped().clipShape(RoundedRectangle(cornerRadius: 8))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(number)").azaFont(.callout, mono: true).foregroundStyle(today ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                Spacer()
                HStack(spacing: 3) {
                    ForEach(0..<min(entries.count, 4), id: \.self) { _ in Circle().fill(.tint).frame(width: 6, height: 6) }
                    if let m = mood { Spacer(); Circle().fill(moodColor(m)).frame(width: 9, height: 9) }
                }
            }
            .padding(6)
        }
        .frame(height: 78)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(dayFilter == key ? Color.primary.opacity(0.6) : .clear, lineWidth: 2))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            if entries.count == 1 { open(entries[0].id) } else if entries.isEmpty { create(key) }
        }
        .onTapGesture {
            if entries.count == 1 { open(entries[0].id) } else if !entries.isEmpty { dayFilter = key; open(entries[0].id) }
        }
        .help(entries.isEmpty ? key : entries.map(\.displayTitle).joined(separator: "\n"))
    }
}

// MARK: - Aperçu

struct DiaryInsightsView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var prefs: Prefs

    var body: some View {
        let ins = store.data.diaryInsights()
        let surface = prefs.palette?.surface ?? Color(nsColor: .controlBackgroundColor)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                    tile("\(ins.streak) j", "série en cours", surface)
                    tile("\(ins.longestStreak) j", "plus longue série", surface)
                    tile("\(ins.entriesThisYear)", "entrées cette année", surface)
                    tile("\(ins.wordsThisYear)", "mots cette année", surface)
                    tile("\(ins.daysThisYear)", "jours écrits cette année", surface)
                    tile(ins.moodAverage.map { DiaryVocab.moods[Int($0.rounded()) - 1] } ?? "—", "humeur moyenne", surface)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("JOURS ÉCRITS — 52 SEMAINES").azaHeading()
                    Heatmap(counts: Dictionary(store.data.diary.map { ($0.day, 1) }, uniquingKeysWith: +))
                }
                .padding(14).background(RoundedRectangle(cornerRadius: 6).fill(surface))
                if !ins.feelings.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CE QUE TU RESSENS LE PLUS").azaHeading()
                        ForEach(ins.feelings, id: \.0) { f, n in
                            HStack {
                                Text(f).frame(width: 140, alignment: .leading)
                                GeometryReader { g in
                                    RoundedRectangle(cornerRadius: 3).fill(.tint)
                                        .frame(width: g.size.width * Double(n) / Double(ins.feelings.first!.1))
                                }.frame(height: 10)
                                Text("\(n)").monospacedDigit().foregroundStyle(.secondary).frame(width: 30, alignment: .trailing)
                            }
                        }
                    }
                    .padding(14).background(RoundedRectangle(cornerRadius: 6).fill(surface))
                }
                moodHistory(surface)
            }
            .padding(20)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    func tile(_ v: String, _ l: String, _ surface: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(v).azaFont(.title2, mono: true).foregroundStyle(.tint).lineLimit(1).minimumScaleFactor(0.6)
            Text(l.uppercased()).foregroundStyle(.secondary).azaFont(.caption2, mono: true)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(surface))
    }

    @ViewBuilder func moodHistory(_ surface: Color) -> some View {
        let recent = store.data.diary.filter { $0.mood != nil }.sorted { $0.date < $1.date }.suffix(60)
        if recent.count >= 2 {
            VStack(alignment: .leading, spacing: 6) {
                Text("ÉTAT D'ESPRIT — DERNIÈRES ENTRÉES").azaHeading()
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(Array(recent), id: \.id) { e in
                        RoundedRectangle(cornerRadius: 2).fill(moodColor(e.mood!))
                            .frame(width: 8, height: CGFloat(e.mood!) * 12)
                            .help("\(e.day) — \(DiaryVocab.moods[e.mood! - 1])")
                    }
                }
                .frame(height: 90, alignment: .bottom)
            }
            .padding(14).background(RoundedRectangle(cornerRadius: 6).fill(surface))
        }
    }
}
