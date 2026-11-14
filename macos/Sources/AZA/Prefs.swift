import AppKit
import AZACore
import SwiftUI

/// Palette d'un thème — mêmes valeurs que les variables CSS de base.html.
struct Theme: Equatable {
    var bg: Color
    var bgAlt: Color
    var surface: Color
    var border: Color
    var text: Color
    var muted: Color
    var accent: Color
    var accent2: Color
    var dark: Bool
}

enum ThemeKey: String, CaseIterable, Identifiable {
    case system, beton, machine, nord, solarizedDark, solarizedLight, gruvbox, custom
    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "Système"
        case .beton: "Béton"
        case .machine: "Machine"
        case .nord: "Nord"
        case .solarizedDark: "Solarized Dark"
        case .solarizedLight: "Solarized Light"
        case .gruvbox: "Gruvbox"
        case .custom: "Personnalisé"
        }
    }

    /// nil pour « Système » : couleurs natives de macOS.
    var palette: Theme? {
        func t(_ bg: String, _ alt: String, _ sf: String, _ bd: String, _ tx: String, _ mu: String,
               _ ac: String, _ a2: String, _ dark: Bool) -> Theme {
            Theme(bg: Color(hex: bg), bgAlt: Color(hex: alt), surface: Color(hex: sf), border: Color(hex: bd),
                  text: Color(hex: tx), muted: Color(hex: mu), accent: Color(hex: ac), accent2: Color(hex: a2), dark: dark)
        }
        switch self {
        case .system, .custom: return nil
        case .beton: return t("#F4F1EC", "#EDEAE3", "#FFFFFF", "#C8C2B8", "#1A1814", "#6B6560", "#D4380D", "#2D4A6B", false)
        case .machine: return t("#111210", "#1A1917", "#1F1E1C", "#2E2C29", "#E8E4DC", "#857F78", "#E84B1A", "#4D7DB5", true)
        case .nord: return t("#2E3440", "#3B4252", "#434C5E", "#4C566A", "#ECEFF4", "#9099AA", "#BF616A", "#81A1C1", true)
        case .solarizedDark: return t("#002B36", "#073642", "#073642", "#115060", "#93A1A1", "#657B83", "#DC322F", "#268BD2", true)
        case .solarizedLight: return t("#FDF6E3", "#EEE8D5", "#FDF6E3", "#D3CBBA", "#586E75", "#93A1A1", "#DC322F", "#268BD2", false)
        case .gruvbox: return t("#282828", "#3C3836", "#32302F", "#504945", "#EBDBB2", "#A89984", "#FB4934", "#83A598", true)
        }
    }
}

enum FontFamily: String, CaseIterable, Identifiable {
    case system, mono, menlo, plex
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: "Système (SF Pro)"
        case .mono: "SF Mono"
        case .menlo: "Menlo"
        case .plex: "IBM Plex Mono"
        }
    }
    var available: Bool {
        self != .plex || NSFont(name: "IBMPlexMono", size: 12) != nil || NSFont(name: "IBM Plex Mono", size: 12) != nil
    }
}

/// Rôles typographiques ; la taille réelle = base × échelle choisie.
enum TextRole {
    case largeTitle, title, title2, title3, headline, body, callout, caption, caption2
    var base: CGFloat {
        switch self {
        case .largeTitle: 26
        case .title: 22
        case .title2: 17
        case .title3: 15
        case .headline, .body: 13
        case .callout: 12
        case .caption: 11
        case .caption2: 10
        }
    }
    var weight: Font.Weight { self == .headline ? .semibold : .regular }
}

/// Réglages de l'interface, gardés dans les préférences macOS (UserDefaults),
/// pas dans le JSON : ce sont des goûts de poste, pas des données.
@MainActor
final class Prefs: ObservableObject {
    private let ud = UserDefaults.standard

    @Published var scale: Double { didSet { ud.set(scale, forKey: "fontScale") } }
    @Published var theme: ThemeKey { didSet { ud.set(theme.rawValue, forKey: "theme") } }
    @Published var family: FontFamily { didSet { ud.set(family.rawValue, forKey: "fontFamily") } }
    @Published var monoTitles: Bool { didSet { ud.set(monoTitles, forKey: "monoTitles") } }
    @Published var customBg: String { didSet { ud.set(customBg, forKey: "customBg") } }
    @Published var customText: String { didSet { ud.set(customText, forKey: "customText") } }
    @Published var customAccent: String { didSet { ud.set(customAccent, forKey: "customAccent") } }
    @Published var customBorder: String { didSet { ud.set(customBorder, forKey: "customBorder") } }
    @Published var compact: Bool { didSet { ud.set(compact, forKey: "compact") } }
    @Published var obsidianVault: String { didSet { ud.set(obsidianVault, forKey: "obsidianVault") } }
    @Published var ollamaURL: String { didSet { ud.set(ollamaURL, forKey: "ollamaURL") } }
    @Published var ollamaModel: String { didSet { ud.set(ollamaModel, forKey: "ollamaModel") } }
    @Published var recapAfterLive: Bool { didSet { ud.set(recapAfterLive, forKey: "recapAfterLive") } }
    @Published var obliqueBanner: Bool { didSet { ud.set(obliqueBanner, forKey: "obliqueBanner") } }
    /// Taille propre au menu latéral : la barre latérale macOS impose sa propre
    /// taille de texte et ne suit pas d'elle-même la taille générale.
    @Published var sidebarScale: Double { didSet { ud.set(sidebarScale, forKey: "sidebarScale") } }

    init() {
        let s = ud.double(forKey: "fontScale")
        scale = s == 0 ? 1.0 : s
        theme = ThemeKey(rawValue: ud.string(forKey: "theme") ?? "") ?? .system
        family = FontFamily(rawValue: ud.string(forKey: "fontFamily") ?? "") ?? .system
        monoTitles = ud.object(forKey: "monoTitles") as? Bool ?? true
        customBg = ud.string(forKey: "customBg") ?? "#111210"
        customText = ud.string(forKey: "customText") ?? "#E8E4DC"
        customAccent = ud.string(forKey: "customAccent") ?? "#F97316"
        customBorder = ud.string(forKey: "customBorder") ?? "#2E2C29"
        compact = ud.bool(forKey: "compact")
        obsidianVault = ud.string(forKey: "obsidianVault") ?? ""
        ollamaURL = ud.string(forKey: "ollamaURL") ?? Recap.defaultURL
        ollamaModel = ud.string(forKey: "ollamaModel") ?? Recap.defaultModel
        recapAfterLive = ud.object(forKey: "recapAfterLive") as? Bool ?? true
        obliqueBanner = ud.object(forKey: "obliqueBanner") as? Bool ?? true
        let sb = ud.double(forKey: "sidebarScale")
        sidebarScale = sb == 0 ? 1.0 : sb
    }

    var palette: Theme? {
        if theme == .custom {
            let bg = NSColor(Color(hex: customBg)).usingColorSpace(.sRGB)
            let lum = bg.map { 0.299 * $0.redComponent + 0.587 * $0.greenComponent + 0.114 * $0.blueComponent } ?? 0
            let dark = lum < 0.5
            let mix = { (a: String, b: String, t: Double) -> Color in Color(hex: a).mixed(with: Color(hex: b), t) }
            return Theme(bg: Color(hex: customBg), bgAlt: mix(customBg, customText, 0.07),
                         surface: mix(customBg, dark ? "#FFFFFF" : "#000000", 0.05), border: Color(hex: customBorder),
                         text: Color(hex: customText), muted: mix(customText, customBg, 0.42),
                         accent: Color(hex: customAccent), accent2: Color(hex: customAccent), dark: dark)
        }
        return theme.palette
    }

    var accent: Color { palette?.accent ?? azaOrange }

    var style: AZAStyle {
        AZAStyle(scale: scale, family: family, monoTitles: monoTitles, accent: accent, palette: palette)
    }

    func font(_ role: TextRole, mono: Bool = false) -> Font { style.font(role, mono: mono) }

    /// Police du menu latéral : taille de base × réglage du menu (indépendant de la taille générale).
    func sidebarFont(_ role: TextRole, mono: Bool = false) -> Font {
        var s = style
        s.scale = sidebarScale
        return s.font(role, mono: mono)
    }

    func reset() {
        scale = 1.0; sidebarScale = 1.0; theme = .system; family = .system; monoTitles = true; compact = false
        customBg = "#111210"; customText = "#E8E4DC"; customAccent = "#F97316"; customBorder = "#2E2C29"
    }
}

extension Color {
    func mixed(with other: Color, _ t: Double) -> Color {
        let a = NSColor(self).usingColorSpace(.sRGB) ?? .black
        let b = NSColor(other).usingColorSpace(.sRGB) ?? .black
        return Color(red: a.redComponent + (b.redComponent - a.redComponent) * t,
                     green: a.greenComponent + (b.greenComponent - a.greenComponent) * t,
                     blue: a.blueComponent + (b.blueComponent - a.blueComponent) * t)
    }
}

// MARK: - Application aux vues

/// Instantané des réglages, transmis par l'environnement SwiftUI.
///
/// Les modificateurs ne lisent PAS `Prefs` en EnvironmentObject : certains
/// rendus (annotations de Swift Charts, ImageRenderer, fenêtres annexes) n'en
/// héritent pas, et un EnvironmentObject manquant fait planter l'app. Une valeur
/// d'environnement absente retombe simplement sur le style par défaut.
struct AZAStyle: Equatable {
    var scale: Double = 1
    var family: FontFamily = .system
    var monoTitles = true
    var accent: Color = azaOrange
    var palette: Theme? = nil

    func font(_ role: TextRole, mono: Bool = false) -> Font {
        let size = (role.base * scale).rounded()
        let fam: FontFamily = mono && family == .system ? .mono : family
        switch fam {
        case .system: return .system(size: size, weight: role.weight)
        case .mono: return .system(size: size, weight: role.weight, design: .monospaced)
        case .menlo: return .custom("Menlo", size: size).weight(role.weight)
        case .plex:
            let name = NSFont(name: "IBMPlexMono", size: size) != nil ? "IBMPlexMono" : "IBM Plex Mono"
            return .custom(name, size: size).weight(role.weight)
        }
    }
}

private struct AZAStyleKey: EnvironmentKey { static let defaultValue = AZAStyle() }

extension EnvironmentValues {
    var azaStyle: AZAStyle {
        get { self[AZAStyleKey.self] }
        set { self[AZAStyleKey.self] = newValue }
    }
}

struct AZAFont: ViewModifier {
    @Environment(\.azaStyle) var style
    let role: TextRole
    let mono: Bool
    func body(content: Content) -> some View { content.font(style.font(role, mono: mono)) }
}

/// Titre de section / en-tête : monospace si l'option est cochée.
struct AZAHeading: ViewModifier {
    @Environment(\.azaStyle) var style
    let role: TextRole
    func body(content: Content) -> some View {
        content.font(style.font(role, mono: style.monoTitles)).foregroundStyle(style.accent)
    }
}

/// Fond d'une liste ou d'un formulaire selon le thème.
struct AZASurface: ViewModifier {
    @Environment(\.azaStyle) var style
    var alt = false
    func body(content: Content) -> some View {
        if let p = style.palette {
            content.scrollContentBackground(.hidden).background(alt ? p.bgAlt : p.bg)
        } else {
            content
        }
    }
}

/// Racine : police, couleurs, schéma clair/sombre.
struct AZARoot: ViewModifier {
    @EnvironmentObject var prefs: Prefs
    func body(content: Content) -> some View {
        let p = prefs.palette
        content
            .environment(\.azaStyle, prefs.style)
            .font(prefs.font(.body))
            .tint(prefs.accent)
            .foregroundStyle(p?.text ?? Color.primary)
            .background(p?.bg ?? Color.clear)
            .preferredColorScheme(p.map { $0.dark ? .dark : .light })
            .controlSize(prefs.compact ? .small : .regular)
            .environment(\.defaultMinListRowHeight, prefs.compact ? 18 : 24)
    }
}

extension View {
    func azaFont(_ role: TextRole = .body, mono: Bool = false) -> some View { modifier(AZAFont(role: role, mono: mono)) }
    func azaHeading(_ role: TextRole = .caption) -> some View { modifier(AZAHeading(role: role)) }
    func azaSurface(alt: Bool = false) -> some View { modifier(AZASurface(alt: alt)) }
    func azaRoot() -> some View { modifier(AZARoot()) }
}

// MARK: - Fenêtre de réglages

struct SettingsView: View {
    @EnvironmentObject var prefs: Prefs
    @EnvironmentObject var store: Store
    @EnvironmentObject var lore: LoreCache

    var body: some View {
        TabView {
            appearance.tabItem { Label("Apparence", systemImage: "paintpalette") }
            data.tabItem { Label("Données", systemImage: "externaldrive") }
            integrations.tabItem { Label("Obsidian & IA", systemImage: "sparkles") }
        }
        .frame(width: 560, height: 520)
        .azaRoot()
    }

    var appearance: some View {
        Form {
            Section {
                HStack {
                    Slider(value: $prefs.scale, in: 0.8...1.8, step: 0.05) { Text("Taille du texte") }
                    Text("\(Int((prefs.scale * 100).rounded())) %").monospacedDigit().frame(width: 52, alignment: .trailing)
                }
                HStack {
                    Slider(value: $prefs.sidebarScale, in: 0.8...1.8, step: 0.05) { Text("Taille du menu latéral") }
                    Text("\(Int((prefs.sidebarScale * 100).rounded())) %").monospacedDigit().frame(width: 52, alignment: .trailing)
                }
                HStack(spacing: 6) {
                    ForEach([0.9, 1.0, 1.15, 1.3, 1.5], id: \.self) { v in
                        Button("\(Int(v * 100)) %") { prefs.scale = v }.controlSize(.small)
                    }
                    Spacer()
                    Text("⌘+ / ⌘− / ⌘0").foregroundStyle(.secondary).azaFont(.caption)
                }
                Picker("Police", selection: $prefs.family) {
                    ForEach(FontFamily.allCases.filter(\.available)) { Text($0.label).tag($0) }
                }
                Toggle("Titres en monospace", isOn: $prefs.monoTitles)
                Toggle("Interface compacte", isOn: $prefs.compact)
                Toggle("Bandeau de stratégie oblique", isOn: $prefs.obliqueBanner)
            } header: { Text("Texte").azaHeading() }

            Section {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                    ForEach(ThemeKey.allCases) { k in swatch(k) }
                }
                if prefs.theme == .custom {
                    HStack {
                        colorField("Fond", $prefs.customBg)
                        colorField("Texte", $prefs.customText)
                        colorField("Accent", $prefs.customAccent)
                        colorField("Bordure", $prefs.customBorder)
                    }
                }
            } header: { Text("Thème").azaHeading() }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SÉANCE #12").azaHeading()
                    Text("MÉMOIRE RÉSIDUELLE").azaFont(.title3, mono: true)
                    Text("MicroFreak · Sonicake Smartbox — 2026-11-14").foregroundStyle(.secondary).azaFont(.caption)
                    Text("La machine ne ment pas. Elle déforme.")
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 4).fill(prefs.palette?.surface ?? Color(nsColor: .textBackgroundColor)))
                Button("Réinitialiser l'apparence") { prefs.reset() }
            } header: { Text("Aperçu").azaHeading() }
        }
        .formStyle(.grouped)
        .azaSurface()
    }

    func swatch(_ k: ThemeKey) -> some View {
        let p = k == .custom ? prefs.palette ?? ThemeKey.machine.palette! : k.palette
        return Button { prefs.theme = k } label: {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(p?.bg ?? Color(nsColor: .windowBackgroundColor))
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(p?.accent ?? azaOrange, lineWidth: 2))
                    .frame(width: 26, height: 16)
                Text(k.label).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 4)
                .stroke(prefs.theme == k ? prefs.accent : Color.secondary.opacity(0.3), lineWidth: prefs.theme == k ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    func colorField(_ label: String, _ hex: Binding<String>) -> some View {
        ColorPicker(label, selection: Binding(get: { Color(hex: hex.wrappedValue) }, set: { hex.wrappedValue = $0.hex }),
                    supportsOpacity: false)
    }

    @Local private var testing = false
    @Local private var testResult = ""

    var integrations: some View {
        Form {
            Section {
                LabeledContent("Dossier") {
                    Text(prefs.obsidianVault.isEmpty ? "non configuré" : prefs.obsidianVault)
                        .textSelection(.enabled).azaFont(.caption, mono: true)
                }
                HStack {
                    Button("Choisir…") {
                        let p = NSOpenPanel()
                        p.canChooseDirectories = true; p.canChooseFiles = false; p.canCreateDirectories = true
                        p.message = "Dossier du vault où écrire les séances (ex. …/Journal/Sessions)"
                        if p.runModal() == .OK, let u = p.url { prefs.obsidianVault = u.path }
                    }
                    if !prefs.obsidianVault.isEmpty {
                        Button("Ouvrir") { NSWorkspace.shared.open(URL(fileURLWithPath: prefs.obsidianVault)) }
                        Button("Retirer") { prefs.obsidianVault = "" }
                    }
                }
                Text("« → Obsidian » sur une séance y écrit session_AAAAMMJJ_id.md (même format que l'export Markdown).")
                    .foregroundStyle(.secondary).azaFont(.caption)
            } header: { Text("Vault Obsidian").azaHeading() }

            Section {
                TextField("Serveur Ollama", text: $prefs.ollamaURL)
                TextField("Modèle", text: $prefs.ollamaModel)
                Toggle("Générer le récap en terminant une séance en cours", isOn: $prefs.recapAfterLive)
                HStack {
                    Button("Tester la connexion") { test() }.disabled(testing)
                    if testing { ProgressView().controlSize(.small) }
                    Text(testResult).foregroundStyle(.secondary).azaFont(.caption).textSelection(.enabled)
                }
                Text("Les données de la séance (matériel, mode, notes) sont envoyées à ce serveur pour rédiger le récap. "
                     + "Un échec est toujours affiché : un récap qui ne vient pas sans rien dire ne se voit jamais.")
                    .foregroundStyle(.secondary).azaFont(.caption)
            } header: { Text("Récap IA (Ollama)").azaHeading() }
        }
        .formStyle(.grouped)
        .azaSurface()
    }

    func test() {
        testing = true; testResult = ""
        let base = prefs.ollamaURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard let url = URL(string: base + "/api/tags") else { testing = false; testResult = "✗ URL invalide"; return }
        let model = prefs.ollamaModel
        Task {
            do {
                var r = URLRequest(url: url, timeoutInterval: 6)
                r.httpMethod = "GET"
                let (data, resp) = try await URLSession.shared.data(for: r)
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                let names = ((try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["models"] as? [[String: Any]] ?? [])
                    .compactMap { $0["name"] as? String }
                testResult = code != 200 ? "✗ HTTP \(code)"
                    : names.contains(model) ? "✓ serveur joignable, modèle « \(model) » présent"
                    : "⚠ serveur joignable, mais « \(model) » n'est pas dans ses modèles (\(names.count))"
            } catch {
                testResult = "✗ \(error.localizedDescription)"
            }
            testing = false
        }
    }

    var data: some View {
        Form {
            Section {
                LabeledContent("Fichier") {
                    Text(store.storage.url.path).textSelection(.enabled).azaFont(.caption, mono: true)
                }
                HStack {
                    Button("Afficher dans le Finder") { store.revealFile() }
                    Button("Utiliser un autre fichier…") {
                        if let url = Panels.save(name: "aza-sessions.json", ext: "json") { store.switchTo(url: url) }
                    }
                    Button("Revenir à l'emplacement par défaut") { store.switchTo(url: JSONStorage.defaultURL) }
                        .disabled(store.storage.url == JSONStorage.defaultURL)
                }
                Text("Si le fichier choisi existe, il est ouvert ; sinon les données actuelles y sont écrites. "
                     + "Un dossier iCloud Drive ou synchronisé fonctionne.")
                    .foregroundStyle(.secondary).azaFont(.caption)
            } header: { Text("Fichier JSON").azaHeading() }

            Section {
                LabeledContent("Dossier") {
                    Text(lore.reader.root.path).textSelection(.enabled).azaFont(.caption, mono: true)
                }
                HStack {
                    Button("Choisir…") { lore.chooseFolder() }
                    Button("Relire") { lore.reload() }
                    Spacer()
                    Text(lore.available ? "✓ \(lore.entries.count) entrées" : "✗ aucun dossier Lore/")
                        .foregroundStyle(lore.available ? Color.secondary : Color.orange)
                }
                Text("Le lore reste dans le vault Obsidian : AZA le lit, sans rien copier dans le JSON.")
                    .foregroundStyle(.secondary).azaFont(.caption)
            } header: { Text("Corpus de lore").azaHeading() }

            Section {
                LabeledContent("Sauvegardes") { Text("\((try? store.storage.backups().count) ?? 0) / 5") }
                Button("Faire une sauvegarde maintenant") { store.backupNow() }
                Button("Supprimer toutes les séances…", role: .destructive) {
                    guard Panels.confirm("Supprimer les \(store.data.sessions.count) séances ?",
                                         "Une sauvegarde datée du JSON est faite avant. Le catalogue, les patches, presets "
                                         + "et le reste sont conservés ; leurs liens vers des séances sont retirés.",
                                         ok: "Tout supprimer") else { return }
                    store.resetSessions()
                }
                .disabled(store.data.sessions.isEmpty)
                Text("Une copie datée est prise à chaque ouverture et avant chaque import ; "
                     + "les 5 plus récentes sont gardées dans le dossier backups/.")
                    .foregroundStyle(.secondary).azaFont(.caption)
            } header: { Text("Sauvegardes").azaHeading() }

            Section {
                let d = store.data
                LabeledContent("Séances", value: "\(d.sessions.count)")
                LabeledContent("Fiches catalogue", value: "\(d.catalogue.count)")
                LabeledContent("Presets", value: "\(d.presets.count)")
                LabeledContent("Relevés de façade", value: "\(d.knobSheets.count)")
            } header: { Text("Contenu").azaHeading() }
        }
        .formStyle(.grouped)
        .azaSurface()
    }
}
