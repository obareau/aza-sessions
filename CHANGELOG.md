# CHANGELOG — Journal de Sessions Robōtariis

## v0.4.0 — 2026-04-20

### Ajouts
- Édition d'une session existante — route `/session/<id>/edit` (GET/POST)
- Template `edit.html` — formulaire pré-rempli avec toutes les valeurs existantes
- Bouton "✎ Éditer" dans la vue détail de session

---

## v0.3.1 — Initial commit

### Ajouts
- Application Flask complète : sessions, catalogue, influences, obliques
- Dashboard statistiques interactif (Chart.js)
- Export Markdown individuel et global (compatible Obsidian)
- Champ `recap_claude` pour coller le résumé de session Claude
- Scripts de lancement Mac (`lancer.command`) et Windows (`lancer.bat`)
- Scripts de compilation binaire PyInstaller (`build_mac.sh`, `build_windows.bat`)
