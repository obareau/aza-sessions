import AppKit
import Combine
import AZACore
import SwiftUI

/// AZA dans la barre de menus : séance en cours, pomodoro, tirage, une pensée pour le journal.
/// Tout ce qu'on fait debout devant les machines, sans ouvrir la fenêtre.
struct MenuBarPanel: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @EnvironmentObject var prefs: Prefs
    @Local private var draw: Draw? = nil
    @Local private var thought = ""
    @Local private var liveNote = ""
    @Local private var flash = ""

    var surface: Color { prefs.palette?.surface ?? Color(nsColor: .controlBackgroundColor) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("AZA").azaHeading(.headline)
                Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide))).foregroundStyle(.secondary).azaFont(.caption)
                Spacer()
                Button { show(.sessions) } label: { Image(systemName: "macwindow") }.buttonStyle(.borderless).help("Ouvrir AZA")
            }
            live
            card { PomodoroWidget() }
            tonight
            journal
            footer
        }
        .padding(12)
        .frame(width: 340)
        .onAppear { if draw == nil { draw = store.data.draw() } }
    }

    func card<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        c().padding(10).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(surface))
    }

    /// Montre la fenêtre principale (la rouvre si elle a été fermée).
    func show(_ pane: Pane? = nil) {
        if let p = pane { nav.pane = p }
        NSApp.activate(ignoringOtherApps: true)
        if let w = NSApp.windows.first(where: { $0.identifier?.rawValue.hasPrefix("main") == true && $0.isVisible }) {
            w.makeKeyAndOrderFront(nil)
        } else {
            StatusBar.shared.openMain?()
        }
        StatusBar.shared.close()
    }

    var live: some View {
        card {
            if let l = store.data.live {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Circle().fill(.red).frame(width: 9, height: 9)
                        TimelineView(.periodic(from: .now, by: 1)) { ctx in
                            let s = max(0, Int(ctx.date.timeIntervalSince(l.startDate ?? ctx.date)))
                            Text(String(format: "%02d:%02d:%02d", s / 3600, s / 60 % 60, s % 60))
                                .azaFont(.title2, mono: true).monospacedDigit()
                        }
                        Spacer()
                        Text("EN COURS").azaHeading(.caption2)
                    }
                    if !l.oblique.isEmpty { Text(l.oblique).italic().foregroundStyle(.secondary).azaFont(.caption).lineLimit(2) }
                    HStack {
                        TextField("Note rapide…", text: $liveNote).onSubmit(addLiveNote)
                        Button("Noter", action: addLiveNote).disabled(liveNote.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    HStack {
                        Button("Terminer → séance") {
                            if let id = store.finishLive(prefs: prefs) { nav.session = id; show(.sessions) }
                        }.buttonStyle(.borderedProminent)
                        Button("Ouvrir") { show(.live) }
                    }
                }
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pas de séance en cours").azaFont(.callout)
                        Text("Le chrono continue même si tu quittes AZA.").foregroundStyle(.secondary).azaFont(.caption2)
                    }
                    Spacer()
                    Button { store.startLive() } label: { Label("Démarrer", systemImage: "record.circle") }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    func addLiveNote() {
        let t = liveNote.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, store.data.live != nil else { return }
        let stamp = String(Clock.stamp().suffix(8).prefix(5))
        let prev = store.data.live!.notes
        store.data.live!.notes = (prev.isEmpty ? "" : prev + "\n") + "[\(stamp)] " + t
        liveNote = ""
    }

    var tonight: some View {
        card {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("CE SOIR").azaHeading(.caption2)
                    Spacer()
                    Button { draw = store.data.draw() } label: { Image(systemName: "dice") }.buttonStyle(.borderless)
                        .help("Retirer")
                }
                if let d = draw, !d.isEmpty {
                    Text([d.instrument?.name, d.treatment?.name].compactMap { $0 }.joined(separator: " → ")).azaFont(.callout)
                    Text(d.oblique).italic().foregroundStyle(.secondary).azaFont(.caption).lineLimit(2)
                    HStack {
                        Text(d.take.isEmpty ? "" : "prise \(d.take)").foregroundStyle(.secondary).azaFont(.caption2, mono: true)
                        Spacer()
                        Button("Séance rapide") {
                            nav.quick = QuickRequest(gear: [d.instrument, d.treatment].compactMap { $0?.name })
                            show()
                        }.buttonStyle(.link).azaFont(.caption)
                    }
                } else {
                    Text("Rien à tirer : active des fiches du catalogue.").foregroundStyle(.secondary).azaFont(.caption)
                }
            }
        }
    }

    var journal: some View {
        card {
            VStack(alignment: .leading, spacing: 6) {
                Text("JOURNAL").azaHeading(.caption2)
                TextField("Une pensée, un son, une idée…", text: $thought, axis: .vertical).lineLimit(2...5)
                HStack {
                    Button("Ajouter au journal") {
                        let id = store.newDiaryEntry()
                        if let i = store.data.diary.firstIndex(where: { $0.id == id }) {
                            store.data.diary[i].body = thought.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        thought = ""; flash = "✓ Ajouté"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { flash = "" }
                    }
                    .disabled(thought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .keyboardShortcut(.return, modifiers: .command)
                    Text(flash).foregroundStyle(.secondary).azaFont(.caption)
                    Spacer()
                    Button("Ouvrir") { nav.diary = store.data.diary.max { $0.date < $1.date }?.id; show(.diary) }.buttonStyle(.link)
                }
            }
        }
    }

    var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: store.inCloud ? "checkmark.icloud" : (UserDefaults.standard.bool(forKey: "cloudBackup") ? "icloud.and.arrow.up" : "internaldrive"))
                .foregroundStyle(.secondary)
            Text(store.inCloud ? "Synchronisé par iCloud Drive"
                 : store.lastCloudBackup.map { "Sauvegarde iCloud : \($0.formatted(date: .omitted, time: .shortened))" }
                 ?? "Données sur ce Mac").foregroundStyle(.secondary).azaFont(.caption2)
            Spacer()
            Button("Quitter") { NSApp.terminate(nil) }.buttonStyle(.link).azaFont(.caption)
        }
    }
}

/// AZA dans la barre de menus, version AppKit (NSStatusItem + popover).
/// La scène SwiftUI `MenuBarExtra` faisait déborder la pile au lancement : le
/// type complet de l'app devenait trop profond pour le décodeur de Swift.
@MainActor
final class StatusBar: NSObject {
    static let shared = StatusBar()
    private var item: NSStatusItem?
    private let popover = NSPopover()
    private var timer: Timer?
    private var bag: [Any] = []
    private weak var store: Store?
    private weak var prefs: Prefs?
    var openMain: (() -> Void)?

    func install(store: Store, nav: Nav, prefs: Prefs, pomo: Pomodoro, openMain: @escaping () -> Void) {
        self.openMain = openMain
        guard self.store == nil else { return }
        self.store = store; self.prefs = prefs
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MenuBarPanel()
            .azaRoot()
            .environmentObject(store).environmentObject(nav).environmentObject(prefs).environmentObject(pomo))
        bag.append(prefs.$menuBar.sink { [weak self] on in DispatchQueue.main.async { self?.setVisible(on) } })
        bag.append(store.$data.map { $0.live != nil }.removeDuplicates().sink { [weak self] _ in
            DispatchQueue.main.async { self?.refresh() }
        })
        timer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    private func setVisible(_ on: Bool) {
        if on, item == nil {
            let i = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            i.button?.target = self
            i.button?.action = #selector(toggle)
            item = i
            refresh()
        } else if !on, let i = item {
            NSStatusBar.system.removeStatusItem(i)
            item = nil
        }
    }

    /// Icône seule, ou point rouge + chrono pendant une séance en cours.
    func refresh() {
        guard let b = item?.button else { return }
        if let start = store?.data.live?.startDate {
            let m = max(0, Int(Date().timeIntervalSince(start) / 60))
            b.image = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "Séance en cours")
            b.title = String(format: " %d:%02d", m / 60, m % 60)
            b.imagePosition = .imageLeading
        } else {
            b.image = NSImage(systemSymbolName: "waveform.circle", accessibilityDescription: "AZA")
            b.title = ""
        }
    }

    @objc private func toggle() {
        guard let b = item?.button else { return }
        if popover.isShown { popover.performClose(nil) }
        else {
            popover.show(relativeTo: b.bounds, of: b, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func close() { popover.performClose(nil) }
}
