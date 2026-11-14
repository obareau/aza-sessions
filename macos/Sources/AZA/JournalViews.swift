import AZACore
import Charts
import SwiftUI

// MARK: - Registre des prises

struct TakesView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav

    var body: some View {
        let groups = store.data.takeRegistry()
        let without = store.data.sessions.filter { $0.audioFile.trimmingCharacters(in: .whitespaces).isEmpty }
            .sorted { $0.date > $1.date }.prefix(50)
        List {
            SwiftUI.Section {
                if groups.isEmpty { Text("Aucune prise nommée.").foregroundStyle(.secondary) }
                ForEach(groups) { g in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(g.name).azaFont(.headline, mono: true).textSelection(.enabled)
                            if g.duplicate {
                                Text("×\(g.sessions.count) — nom réutilisé").azaFont(.caption)
                                    .padding(.horizontal, 5).background(Capsule().fill(Color.orange.opacity(0.25)))
                            }
                        }
                        ForEach(g.sessions) { s in
                            Button { nav.open(session: s.id) } label: {
                                Text("\(s.date) — \(s.displayTitle)").foregroundStyle(.secondary).azaFont(.caption)
                            }.buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            } header: { Text("PRISES (\(groups.count))").azaHeading() } footer: {
                Text("Le compteur du R8 repart chaque jour : un même nom sur deux jours est attendu (carte vidée entre-temps).")
                    .foregroundStyle(.secondary).azaFont(.caption)
            }
            SwiftUI.Section {
                ForEach(Array(without)) { s in
                    Button { nav.open(session: s.id) } label: {
                        Text("\(s.date) — \(s.displayTitle)")
                    }.buttonStyle(.plain)
                }
            } header: { Text("SÉANCES SANS PRISE").azaHeading() }
        }
        .navigationTitle("Prises")
    }
}

// MARK: - Statistiques

struct StatsView: View {
    @Environment(\.azaStyle) private var style
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @EnvironmentObject var prefs: Prefs

    var body: some View {
        Group {
            if let st = store.data.stats() {
                ScrollView { content(st).padding(20) }
            } else {
                Text("Pas encore de séance.").foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Statistiques")
    }

    var surface: Color { prefs.palette?.surface ?? Color(nsColor: .controlBackgroundColor) }

    func tile(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).azaFont(.title, mono: true).foregroundStyle(.tint)
            Text(label.uppercased()).foregroundStyle(.secondary).azaFont(.caption2, mono: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(surface))
    }

    func block<C: View>(_ title: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).azaHeading()
            c()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(surface))
    }

    func bars(_ items: [(String, Int)]) -> some View {
        // Charts dessine ses annotations dans un rendu à part, sans les
        // EnvironmentObject de l'app : la police doit y entrer comme une valeur.
        let font = prefs.font(.caption2)
        let accent = style.accent
        return Chart(Array(items.enumerated()), id: \.offset) { _, it in
            BarMark(x: .value("n", it.1), y: .value("nom", it.0))
                .foregroundStyle(accent)
                .annotation(position: .trailing) { Text("\(it.1)").font(font) }
        }
        .chartXAxis(.hidden)
        .frame(height: CGFloat(max(1, items.count)) * 22 + 10)
    }

    @ViewBuilder func content(_ st: Stats) -> some View {
        let accent = style.accent
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                tile("\(st.total)", "séances")
                tile(String(format: "%.1f h", Double(st.totalMinutes) / 60), "jouées")
                tile("\(st.avgDuration) min", "durée moyenne")
                tile("\(st.thisMonth)", "ce mois-ci")
                tile("\(st.streak) j", "série en cours")
                tile("\(st.maxStreak) j", "record de série")
                tile("\(st.releaseCount)", "potentiel release")
                tile("\(st.reworkCount)", "à retravailler")
            }

            HStack(alignment: .top, spacing: 14) {
                if let b = st.best {
                    block("Meilleure séance") {
                        Button { nav.open(session: b.id) } label: {
                            Text("\(b.displayTitle) — \(String(repeating: "★", count: b.rating ?? 0))")
                        }.buttonStyle(.link)
                    }
                }
                if let l = st.longest, (l.durationMin ?? 0) > 0 {
                    block("Plus longue") {
                        Button { nav.open(session: l.id) } label: { Text("\(l.displayTitle) — \(l.durationMin ?? 0) min") }
                            .buttonStyle(.link)
                    }
                }
            }

            block("Activité — 52 semaines") { Heatmap(counts: st.heatmap) }

            block("Séances par mois") {
                Chart(st.monthly, id: \.0) { m in
                    BarMark(x: .value("mois", m.0), y: .value("séances", m.1)).foregroundStyle(accent)
                }
                .frame(height: 180)
            }

            if !st.monthlyRating.isEmpty || !st.monthlyEnergy.isEmpty {
                block("Évolution (moyennes mensuelles)") {
                    Chart {
                        ForEach(st.monthlyRating, id: \.0) { m in
                            LineMark(x: .value("mois", m.0), y: .value("valeur", m.1), series: .value("série", "Note"))
                                .foregroundStyle(by: .value("série", "Note ★"))
                                .symbol(.circle)
                        }
                        ForEach(st.monthlyEnergy, id: \.0) { m in
                            LineMark(x: .value("mois", m.0), y: .value("valeur", m.1), series: .value("série", "Énergie"))
                                .foregroundStyle(by: .value("série", "Énergie ⚡"))
                                .symbol(.square)
                        }
                    }
                    .chartYScale(domain: 0...5)
                    .chartForegroundStyleScale(["Note ★": accent, "Énergie ⚡": Color.green])
                    .frame(height: 180)
                }
            }

            if !st.durationRating.isEmpty {
                block("Durée × note") {
                    Chart(Array(st.durationRating.enumerated()), id: \.offset) { _, p in
                        PointMark(x: .value("minutes", p.0), y: .value("note", p.1)).foregroundStyle(accent)
                    }
                    .chartYScale(domain: 0...5)
                    .frame(height: 180)
                }
            }

            HStack(alignment: .top, spacing: 14) {
                block("Notes") { bars(st.ratingDist.map { (String(repeating: "★", count: $0.0), $0.1) }) }
                block("Énergie") { bars(st.energyDist.map { (String(repeating: "⚡", count: $0.0), $0.1) }) }
            }
            HStack(alignment: .top, spacing: 14) {
                if !st.modes.isEmpty { block("Modes") { bars(st.modes) } }
                if !st.intentions.isEmpty { block("Intentions") { bars(st.intentions) } }
            }
            if !st.projects.isEmpty { block("Projets") { bars(st.projects) } }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 14)], spacing: 14) {
                ForEach(st.top, id: \.label) { t in block(t.label) { bars(t.items) } }
            }
            if st.monthlyRating.isEmpty {
                Text("Les courbes d'évolution apparaissent à partir de \(Stats.minPoints) séances notées.")
                    .foregroundStyle(.secondary).azaFont(.caption)
            }
        }
    }
}

/// Calendrier d'activité façon « contributions » : 53 colonnes de 7 jours.
struct Heatmap: View {
    @Environment(\.azaStyle) private var style
    let counts: [String: Int]

    var body: some View {
        let cal = Calendar(identifier: .iso8601)
        let today = cal.startOfDay(for: Date())
        let weekday = (cal.component(.weekday, from: today) + 5) % 7  // lundi = 0
        let start = cal.date(byAdding: .day, value: -(52 * 7 + weekday), to: today)!
        let maxC = max(1, counts.values.max() ?? 1)
        let accent = style.accent
        Canvas { ctx, size in
            let cell = min(size.width / 53, size.height / 7)
            for w in 0..<53 {
                for d in 0..<7 {
                    guard let day = cal.date(byAdding: .day, value: w * 7 + d, to: start), day <= today else { continue }
                    let n = counts[Clock.day(day)] ?? 0
                    let rect = CGRect(x: CGFloat(w) * cell, y: CGFloat(d) * cell, width: cell - 2, height: cell - 2)
                    let color = n == 0 ? Color.secondary.opacity(0.15)
                        : accent.opacity(0.35 + 0.65 * Double(n) / Double(maxC))
                    ctx.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(color))
                }
            }
        }
        .frame(height: 98)
        .frame(maxWidth: 760)
    }
}
