# CHANGELOG — Journal de Sessions Robōtariis

> Les versions alpha sont des releases actives en développement continu.
> Chaque version est datée du jour de développement effectif.

---

## v0.9.3-alpha — 2026-04-23

### Ajouts
- **Responsive Design** — Adaptation complète pour mobiles et tablettes avec media queries, layouts adaptatifs, et optimisation tactile

---

## v0.9.2-alpha — 2026-04-23

### Corrections
- **Export Markdown** — retourne désormais un fichier valide même sans sessions (au lieu d'une erreur 404)
- **Recherche sessions** — inclut désormais le nom du projet dans les termes recherchables

---

## v0.9.1-alpha — 2026-04-23

### Corrections
- **Bug Jinja2 dans formulaire nouvelle session** — syntaxe ternaire imbriquée invalide dans `templates/new.html` (lignes 18, 48, 282, 310) causant une erreur 500 ; corrigé en normalisant la syntaxe des conditions multiples
- **Export Markdown** — retourne désormais un fichier valide même sans sessions (au lieu d'une erreur 404)
- **Recherche sessions** — inclut désormais le nom du projet dans les termes recherchables

---

## v0.9.0-alpha — 2026-04-21

### Ajouts
- **Backup automatique** — copie horodatée de `sessions.db` dans `backups/` à chaque lancement, garde les 5 derniers, chemin affiché dans le terminal
- **Spark — Mode contrainte unique** (`/spark/focus`) — une seule suggestion affichée en grand, centrée, minimaliste ; bouton "▶ Démarrer avec ça" qui lance directement le Live ; accessible depuis Spark via "⊙ Contrainte unique"
- **Records & badges** dans les Stats — carte avec : meilleure session (★ cliquable), session la plus longue (lien), temps de création total cumulé en heures, machine la plus utilisée
- **MiRack — notes inline** — icône ✎ au survol de chaque module ; clic → champ texte inline ; Entrée/✓ sauvegarde, Échap/✕ annule

---

## v0.8.3-alpha — 2026-04-21

### Ajouts
- **Export PDF** — route `/session/<id>/print` — page A4 autonome (sans base.html), stylée pour l'impression
- Design carnet de bord : en-tête Robōtariis, grille infos techniques, sections patches/notes/oblique/audio, footer signé
- Barre d'actions en haut (écran uniquement) : bouton « ↓ Imprimer / PDF » + lien retour
- Compatible `Cmd+P` / `Ctrl+P` → « Enregistrer en PDF » dans le navigateur (zéro dépendance Python)
- Support `?auto=1` pour déclencher l'impression automatiquement au chargement
- Bouton **↓ PDF** dans la vue détail de session (ouvre dans un nouvel onglet)

---

## v0.8.2-alpha — 2026-04-21

### Ajouts
- **Heatmap calendrier** dans les Stats — grille 53 semaines × 7 jours style GitHub contributions, rendu en JS pur (sans lib supplémentaire)
- 5 niveaux d'intensité couleur basés sur la variable CSS `--accent` du thème actif (compatible tous les thèmes)
- Labels mois en haut des colonnes, labels jours L/M/J/D à gauche
- Tooltip au survol : jour, date ISO, nombre de sessions
- Compteur « X jours avec session sur 52 semaines »
- **Streak actuel** et **record streak** dans les KPIs (calculés en Python côté serveur)

---

## v0.8.1-alpha — 2026-04-21

### Ajouts
- **Raccourcis clavier globaux** — actifs sur toutes les pages, ignorés si focus dans un champ texte
  - `n` → Nouvelle session
  - `l` → Session en cours (Live)
  - `g` `h` → Accueil (liste sessions)
  - `g` `s` → Statistiques
  - `g` `p` → ⚡ Spark
  - `/` → Focus sur la recherche (ou redirect vers l'accueil)
  - `j` / `k` → Session suivante / précédente dans la liste visible
  - `Enter` → Ouvrir la session sélectionnée
  - `Esc` → Fermer l'overlay ou désélectionner
  - `?` → Afficher / masquer l'aide des raccourcis
- **Overlay aide** (`?`) — panel centré avec la liste de tous les raccourcis, style terminal
- **Sélection j/k** — highlight `.kbd-focus` sur la session active, scroll automatique dans la vue

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
