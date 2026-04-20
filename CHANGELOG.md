# CHANGELOG — Journal de Sessions Robōtariis

> Les versions alpha sont des releases actives en développement continu.

## v0.6.0-alpha — 2026-04-20

### Ajouts
- Suppression de session : bouton « ✕ Supprimer » dans la vue détail, avec confirmation
- Copie de setup : bouton « ⎘ Copier setup » — préremplit le formulaire nouvelle session avec le même hardware/logiciels/caractère/influences
- Vue Projets (`/projects`) : regrouper des sessions sous un titre de projet, avec couleur, description, comptage de sessions
- Vue détail projet : liste des sessions du projet, stats rapides (durée totale, note moyenne)
- Association de sessions à un projet (select dans new/edit)
- Tags cliquables dans la liste des sessions — filtre automatique par tag au clic
- Thème sombre : toggle ◐ dans le header, persisté en localStorage
- Lien « ◈ Projets » dans la navigation

## v0.5.4-alpha — 2026-04-20

### Ajouts
- Page Paramètres (`/settings`) accessible depuis la nav
- Import de base SQLite : upload d'un ancien `sessions.db`, fusion intelligente (doublons ignorés, colonnes manquantes gérées)
- Backup : téléchargement de la base courante en `.db` horodaté
- Reset sessions : vide toutes les sessions (conserve catalogue, influences, obliques)

---

## v0.5.3-alpha — 2026-04-20

### Corrections
- Stats : fix crash JS `doughnut(cChars/cModes)` appelé sans data — bloquait le rendu des graphiques énergie, notes et caractère
- Influences/Catalogue : noms des items maintenant visibles (background explicite sur input[name="name"])
- Notes des items : masquées par défaut, visibles au hover (catalogue + influences)

### Ajouts
- Pomodoro persistant : état sauvegardé dans localStorage, restauré au changement de page (temps écoulé compensé)
- Auto-save formulaires : brouillon sauvegardé automatiquement toutes les modifications (new + edit), banner de restauration si données non soumises

### Roadmap future
- Reset base de données (remettre à zéro sans données)
- Import de base SQLite existante

---

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
