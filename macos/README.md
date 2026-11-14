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
- `Sources/AZA` — l'app :
  - Jouer : Ce soir (tirage instrument + traitement + contrainte + titre + prise), séance En cours (chrono), Spark
  - Journal : Séances, Projets, Prises (registre des noms R8), Statistiques
  - Matériel : Catalogue (fiche, carnet d'instrument, façade ; proposition de codes), Façades & relevés, Presets, Wishlist
  - Références : Influences, Stratégies obliques, Morceaux, Inspirations, Samples, MiRack
- Réglages (⌘,) : taille du texte (⌘+ / ⌘− / ⌘0), police, thèmes de l'app web
  (Béton, Machine, Nord, Solarized, Gruvbox, personnalisé), interface compacte, emplacement du fichier JSON
- `Sources/aza-check` — auto-test, lancé par `build_app.sh`

Reprendre les données de l'app Flask : **Fichier › Importer une base sessions.db…**
(lecture seule de la base ; le JSON courant est sauvegardé avant d'être remplacé).

Non portés : patcher, SysEx (Web MIDI → CoreMIDI), lore, fiche de rappel / feuille
d'atelier imprimables, export vers le vault Obsidian, récap IA (Ollama).
