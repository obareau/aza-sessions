import AppKit
import AZACore
import SwiftUI

/// Minuteur Pomodoro (widget de l'app web) : 25 / 5 / 15 min, son à la fin.
@MainActor
final class Pomodoro: ObservableObject {
    @Published private(set) var total = 25 * 60
    @Published private(set) var left = 25 * 60
    @Published private(set) var running = false
    @Published private(set) var label = "Focus"
    private var timer: Timer?
    private var endAt: Date?

    var display: String { String(format: "%02d:%02d", left / 60, left % 60) }
    var fraction: Double { total == 0 ? 0 : Double(left) / Double(total) }

    func set(_ minutes: Int, _ label: String) {
        stop()
        total = minutes * 60; left = total; self.label = label
    }

    func toggle() { running ? stop() : start() }

    func reset() { stop(); left = total }

    private func start() {
        guard left > 0 else { reset(); return }
        running = true
        endAt = Date().addingTimeInterval(TimeInterval(left))
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func stop() {
        timer?.invalidate(); timer = nil; running = false; endAt = nil
    }

    private func tick() {
        guard let end = endAt else { return }
        left = max(0, Int(end.timeIntervalSinceNow.rounded(.up)))
        if left == 0 {
            stop()
            NSSound(named: "Glass")?.play()
            NSApp.requestUserAttention(.informationalRequest)
        }
    }
}

struct PomodoroWidget: View {
    @EnvironmentObject var pomo: Pomodoro
    @Local private var open = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Button { open.toggle() } label: {
                    HStack(spacing: 6) {
                        Text(pomo.display).azaFont(.title3, mono: true).monospacedDigit()
                            .foregroundStyle(pomo.running ? (pomo.label == "Focus" ? Color.accentColor : .green) : .primary)
                        Text(pomo.label.uppercased()).foregroundStyle(.secondary).azaFont(.caption2, mono: true)
                    }
                }.buttonStyle(.plain).help("Pomodoro")
                Spacer()
                Button { pomo.toggle() } label: { Image(systemName: pomo.running ? "pause.fill" : "play.fill") }
                    .buttonStyle(.borderless)
                Button { pomo.reset() } label: { Image(systemName: "arrow.counterclockwise") }.buttonStyle(.borderless)
            }
            GeometryReader { g in
                Rectangle().fill(Color.accentColor.opacity(0.7)).frame(width: g.size.width * pomo.fraction)
            }
            .frame(height: 2)
            if open {
                HStack(spacing: 6) {
                    ForEach([(25, "Focus"), (5, "Pause"), (15, "Longue")], id: \.0) { m, l in
                        Button("\(m)") { pomo.set(m, l) }.controlSize(.small).help("\(m) min — \(l)")
                    }
                }
            }
        }
    }
}

/// Bandeau « ∴ Stratégie » en tête de chaque écran.
struct ObliqueBanner: View {
    @EnvironmentObject var store: Store
    @Local private var text: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            Text("∴ STRATÉGIE").azaHeading(.caption2)
            Text(text ?? "").italic().lineLimit(1).truncationMode(.tail).azaFont(.callout, mono: true)
            Spacer()
            Button("Autre") { text = store.data.randomOblique() }.buttonStyle(.link).azaFont(.caption)
        }
        .padding(.horizontal, 12).padding(.vertical, 5)
        .background(Color.accentColor.opacity(0.06))
        .onAppear { if text == nil { text = store.data.randomOblique() } }
    }
}

enum AboutPanel {
    @MainActor static func show() {
        let credits = NSMutableAttributedString()
        let body: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor]
        let mono: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
                                                   .foregroundColor: NSColor.secondaryLabelColor]
        credits.append(NSAttributedString(string: "Journal de sessions musicales de l'univers AZA — dystopie Dark Ambient / Industriel, Scaër.\n\n", attributes: body))
        credits.append(NSAttributedString(string: "Carnet de bord, patcher, façades, SysEx DX7, lore lu depuis le vault Obsidian. "
            + "Toutes les données tiennent dans un fichier JSON.\n\n", attributes: body))
        credits.append(NSAttributedString(string: "La machine ne ment pas. Elle déforme.\n", attributes: mono))
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "AZA — Journal de Sessions",
            .applicationVersion: Store.version,
            .credits: credits,
            NSApplication.AboutPanelOptionKey(rawValue: "Copyright"): "Robōtariis · Dark Umbrae",
        ])
        NSApp.activate(ignoringOtherApps: true)
    }
}
