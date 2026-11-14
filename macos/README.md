# AZA — app macOS native

Journal de Sessions AZA en SwiftUI, sans serveur. Les données vivent dans un seul
fichier JSON : `~/Documents/AZA Sessions/aza-sessions.json` (5 sauvegardes datées
dans `backups/` à côté, prises à l'ouverture et avant chaque import).

```bash
bash macos/build_app.sh            # → macos/build/AZA.app (universel, signé ad-hoc)
bash macos/build_app.sh --install  # copie aussi dans ~/Applications
```

Construit avec les seuls Command Line Tools : pas de `@State` (macro SwiftUI
indisponible sans Xcode), l'état local passe par `@Local` (`Sources/AZA/Local.swift`).

- `Sources/AZACore` — modèle, stockage JSON, nom de prise R8, export Markdown, import `sessions.db`
- `Sources/AZA` — l'app : Séances, Projets, Catalogue, Influences, Stratégies obliques
- `Sources/aza-check` — auto-test, lancé par `build_app.sh`

Reprendre les données de l'app Flask : **Fichier › Importer une base sessions.db…**
(lecture seule de la base ; le JSON courant est sauvegardé avant d'être remplacé).

Non portés : patcher, SysEx, live, presets / façades, carnet d'instrument,
samples, morceaux, wishlist, inspirations, MiRack, stats, lore.
