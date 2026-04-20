# CHANGELOG — Journal de Sessions Robōtariis

> Les versions alpha sont des releases actives en développement continu.
> Chaque version est datée du jour de développement effectif.

---

## v0.8.0-alpha — 2026-04-21

### Ajouts
- **Mode session en cours** (`/live`) — démarrer un chrono avant de jouer, notes libres en temps réel, sélection des machines, auto-save AJAX toutes les 15 s + `sendBeacon` au départ de page
- **Timer live** — affichage `HH:MM:SS` qui repart correctement même après un rechargement
- **Terminer & Documenter** — redirige vers `/new` pré-rempli : durée calculée, machines cochées, mode/intention/oblique de la session, notes libres dans le champ comments
- **Badge ● EN COURS** dans la navigation — visible en clignotant orange sur toutes les pages si une session est active
- **Lien ▶ Live** permanent dans la navigation

---

## v0.7.0-alpha — 2026-04-21

### Ajouts
- **Banques de samples** (`/samples`) — référencer les packs et banques : nom, type, note ★, source
- **Morceaux inspirants** (`/tracks`) — titre, artiste, album, année, tags, notes d'écoute
- **Wishlist matos** (`/wishlist`) — fabricant, nom, type, prix, priorité (Urgent/Bientôt/Un jour/Rêve), toggle Acquis
- **Sources d'inspiration hors musique** (`/inspirations`) — phrases, extraits film, livres, concepts — groupées par type avec codes couleur
- **⬡ MiRack** (`/mirack`) — catalogue des modules du synthé modulaire virtuel : catégorie, toggle maîtrisé/favori, barre de progression globale (%)
- **⚡ Spark** (`/spark`) — générateur créatif personnalisé : analyse la base de sessions pour suggérer machines sous-utilisées, intentions jamais explorées, caractères inexploités, modules MiRack non maîtrisés, inspiration et morceau aléatoires, stratégie Oblique
- **Sélecteur de thèmes** — 6 thèmes inspirés des palettes terminaux : Béton (défaut), Machine (dark), Nord (arctic blue), Solarized Dark, Solarized Light, Gruvbox (warm retro) — dropdown avec swatches colorés, persisté en localStorage
- Navigation restructurée en groupes logiques (sessions / outils / ressources / config)
- 5 nouvelles tables SQLite : `sample_banks`, `inspiring_tracks`, `gear_wishlist`, `inspirations`, `mirack_modules`

---

## v0.6.0-alpha — 2026-04-20

### Ajouts
- **Suppression de session** — bouton « ✕ Supprimer » dans la vue détail, avec confirmation JS, route POST `/session/<id>/delete`
- **Copie de setup** — bouton « ⎘ Copier setup » dans la vue détail, préremplit le formulaire nouvelle session avec le même hardware, logiciels, caractère et influences (`/new?from=<id>`)
- **Vue Projets** — regrouper des sessions sous un projet avec titre, couleur et description (`/projects`)
- **Détail projet** — liste des sessions liées, stats rapides (durée totale, note moyenne)
- **Association session ↔ projet** — select dans les formulaires new et edit, colonne `project_id` en DB
- **Tags cliquables** — clic sur un tag dans la liste des sessions filtre automatiquement par ce tag
- **Thème sombre** — variables CSS dark complètes, toggle ◐ dans le header, persisté en localStorage
- **Lien ◈ Projets** dans la navigation principale

### Corrections
- Noms des artistes/machines enfin visibles dans catalogue et influences : remplacement des styles inline `background:transparent` + `onblur` JS (qui écrasaient le CSS) par des classes CSS dédiées `.inf-name`, `.cat-name`, `.inf-notes`, `.cat-notes`

---

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
- Influences/Catalogue : noms des items maintenant visibles (background explicite sur `input[name="name"]`)
- Notes des items : masquées par défaut, visibles au hover (catalogue + influences)

### Ajouts
- Pomodoro persistant : état sauvegardé dans localStorage, restauré au changement de page (temps écoulé compensé)
- Auto-save formulaires : brouillon sauvegardé automatiquement à chaque modification (new + edit), banner de restauration si données non soumises

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
- `build_mac.sh` : compatibilité Python 3.9, `mkdir -p static`, mode `--onedir`
- Port 5001 par défaut (5000 occupé par AirPlay sur macOS)

---

## v0.4.0 — 2026-04-20

### Ajouts
- Édition d'une session existante — route `/session/<id>/edit` (GET/POST)
- Template `edit.html` — formulaire pré-rempli avec toutes les valeurs existantes
- Bouton « ✎ Éditer » dans la vue détail de session

---

## v0.3.1 — 2026-04-20 — Initial commit

### Ajouts
- Application Flask complète : sessions, catalogue, influences, obliques
- Dashboard statistiques interactif (Chart.js)
- Export Markdown individuel et global (compatible Obsidian)
- Champ `recap_claude` pour coller le résumé de session Claude
- Scripts de lancement Mac (`lancer.command`) et Windows (`lancer.bat`)
- Scripts de compilation binaire PyInstaller (`build_mac.sh`, `build_windows.bat`)
