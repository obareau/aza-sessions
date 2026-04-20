# CHANGELOG — Journal de Sessions Robōtariis

> Les versions alpha sont des releases actives en développement continu.

## v0.5.2-alpha — 2026-04-20

### Ajouts
- Filtres et recherche en temps réel sur la liste des sessions (texte libre, mode, note)
- Liaison entre sessions : select dropdown dans les formulaires new/edit, affichage en card dans la vue détail
- Fichier audio : bouton copier-presse-papiers dans la vue détail

---

## v0.5.1-alpha — 2026-04-20

### Ajouts
- Widget Pomodoro flottant (25/5/15 min, barre de progression, style Robōtariis)
- Bannière terminal ANSI + détection automatique du port libre au démarrage
- `os.chdir()` au démarrage — lancement stable depuis n'importe quel chemin

### Corrections
- Champ "notes…" dans le catalogue masqué par défaut (visible au hover)
- build_mac.sh : compatibilité Python 3.9, `mkdir -p static`, mode `--onedir`
- Port 5001 par défaut (5000 occupé par AirPlay sur macOS)

---

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
