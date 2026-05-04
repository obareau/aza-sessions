# CHANGELOG — Journal de Sessions AZA

> Les versions alpha sont des releases actives en développement continu.
> Chaque version est datée du jour de développement effectif.

---

## v2.2.0 — 2026-05-04 — Fabricants + ajout inline catalogue

### ✨ Nouveautés
- **Colonne `manufacturer`** sur la table `catalogue` (migration automatique `ALTER TABLE`)
- **Ajout inline depuis le formulaire session** — bouton `+ Ajouter` par section (Machines, Effets, DAW, iOS, Plugins) ouvre un modal AJAX ; l'item est injecté et coché immédiatement sans perdre la session en cours — valable sur `new.html` et `edit.html`
- **Classement par fabricant** partout : formulaires new/edit (groupby avec séparateurs), page catalogue (tri + champ éditable en ligne), formulaire vierge (fabricant en texte secondaire)
- **Datalist fabricants** dans le modal — autocomplétion sur les fabricants déjà connus
- **Endpoint JSON** `POST /api/catalogue/add` — `CatalogueEngine.add_inline()`
- **Autosave brouillon** sur `new.html` — sauvegarde silencieuse en `localStorage` à chaque frappe, restauration au chargement avec bandeau "↩ Brouillon restauré", effacement au submit

---

## v2.1.0 — 2026-05-03 — Architecture modulaire (Blueprints)

### ♻️ Refactorisation architecture
- **`core/`** — utilitaires partagés : `db.py` (get_db), `oblique.py` (rand_oblique), `constants.py` (toutes les listes de référence)
- **`sessions/`** — Blueprint complet : index, new, view, edit, delete, form_blank, print, export MD/CSV/Obsidian, settings Obsidian, search
- **`catalogue/`** — Blueprint standalone (GET/POST `/catalogue`)
- **`obliques/`** — Blueprint standalone (`/oblique` JSON + `/obliques` CRUD)
- **`influences/`** — Blueprint standalone (GET/POST `/influences`)
- **`spark/`** — Blueprint standalone (`/spark`, `/spark/focus`)
- **`dim/`** — Blueprint standalone D.I.M Lite (7 routes `/prompter`)
- `app.py` réduit au rôle de launcher + `init_db` + modules non encore extraits

### ✨ Comportement inchangé — zéro régression UI

---

## v2.0.1 — 2026-05-01 — Hotfix UI

### 🐛 Corrections
- **Menu hamburger iPad** — breakpoint relevé de 600px à 1024px : le menu hamburger s'active maintenant sur tous les iPads (portrait et paysage) au lieu d'afficher la nav desktop tronquée
- Liens du drawer agrandis (padding 13px) pour meilleure ergonomie tactile

### ✨ Améliorations
- **Boutons zoom global A+ / A−** ajoutés dans la barre de menu — toujours visibles, plage 70 % à 160 %, persisté en localStorage

---

## v2.0.0 — 2026-05-01 — Release majeure

La version 2.0 marque le passage d'un outil de documentation locale à une
**plateforme de performance Dawless complète**, déployée en production sur Fly.io.

### ⬡ Prompteur Dawless — module complet
- Création, édition, suppression de scripts de set (titre, description, cues)
- Chaque cue : temps `MM:SS`, nom de patch/preset, instruction, couleur (6 niveaux)
- Vue performance plein écran : **trois zones** (précédent / courant / suivant)
- **Topbar claire style DAW** — contraste fort avec la scène noire
- **Transport** : ⏮ Rewind · ⏹ Stop · ▶ Play / ⏸ Pause
- **Horloge grande** (48px) — décompte en mode auto, chrono en mode manuel
- **Barre durée restante** segmentée style LED — se vide de 100 % → 0 %
  - Segments 22px séparés par trait noir
  - Clignotement CSS lent (< 10 s) et rapide (< 5 s)
  - Hauteur réglable (6–80 px, défaut 20 px)
- **Mode auto** — avance automatique entre cues avec décompte ; durée par défaut configurable si pas de minutage
- **Mode manuel** — barre scrub positionnelle, avance au clic / espace / swipe
- Zoom police A+ / A− (variable CSS `--fs`, 40–250 %)
- Plein écran natif (touche F)
- Bouton « ✕ Quitter » avec confirmation — raccourci Q
- Raccourcis clavier complets : Espace · → · ← · A · S · R · F · Q · + · −
- Swipe mobile gauche/droite
- **Export JSON** — format structuré réimportable
- **Export Markdown** — tableau compatible Obsidian
- **Import** — upload `.json` ou `.md`, parsing automatique, redirection vers l'éditeur

### 🏷️ Titres de session
- Champ titre optionnel sur chaque session (ex : *Drone Secteur 7*)
- Affiché dans la liste sous la date, comme titre principal dans la vue détail
- Formulaires new/edit mis à jour

### ☁️ Déploiement cloud Fly.io
- Dockerfile Python 3.11-slim + Gunicorn WSGI
- `wsgi.py` — init DB au démarrage Gunicorn via `app.app_context()`
- Volume persistant `/data` (sessions.db + backups)
- Région CDG (Paris), 256 MB RAM, free tier
- URL publique : **https://aza-sessions.fly.dev/**

### 📱 Mobile
- Menu hamburger fixe en portrait iPhone — nav cachée par défaut, drawer ☰/✕
- Stats : grilles responsives `auto-fill minmax` — plus de scroll horizontal
- `overflow-x: hidden` sur body

### 🐛 Corrections majeures
- Suppression de session — erreur `cannot DELETE from contentless fts5 table` corrigée (drop FTS5 triggers au démarrage)
- Barre de progression — double `requestAnimationFrame` pour reflow garanti
- Restart prompteur — `event.stopPropagation()` pour éviter la propagation du clic

### 📄 Formulaire PDF papier (mode dégradé)
- `/form/blank` — template A4 deux pages imprimable sans JS
- Génération dynamique depuis le catalogue courant (machines, effets, DAW, iOS, plugins, influences, caractères)

---

## v1.3.0-alpha — 2026-05-01

### Ajouts
- Export JSON et Markdown par script prompteur
- Import `.json` / `.md` — parsing automatique, flash message
- Barre durée restante : segments LED, clignotement, hauteur réglable

---

## v1.2.0-alpha — 2026-05-01

### Ajouts
- Titre optionnel sur chaque session
- Prompteur : 3 zones prev/current/next, barre animée, décompte, zoom police

---

## v1.1.0-alpha — 2026-04-25

### Ajouts
- **Prompteur Dawless** (`/prompter`) — scripts de set avec minutage, patch et instructions ; éditeur de cues (temps MM:SS, patch, action, couleur) ; vue performance plein écran

---

## v1.0.1 — 2026-04-25

### Corrections
- Déploiement Fly.io : `wsgi.py` corrigé, `init_db()` dans `app_context()`
- `fly.toml` : `memory = '256mb'`, `dockerfile = "Dockerfile"`

---

## v1.0.0 — 2026-04-25

### Ajouts
- Déploiement Fly.io (Docker + Gunicorn, volume persistant `/data`)
- Navigation mobile hamburger
- Fix horizontal scroll stats page
- Suppression sessions : fix crash FTS5

---

## v0.9.9-alpha — 2026-04-24

### Ajouts
- Formulaire vierge imprimable PDF (`/form/blank`) généré depuis le catalogue

---

## v0.9.8-alpha — 2026-04-23

### Corrections
- Suppression de session : `BEGIN IMMEDIATE` retiré
- FTS5 contentless table : triggers droppés au démarrage via `init_db()`
- `debug=True` activé temporairement pour diagnostic

---

## v0.7.0-alpha — 2026-04-21

### Ajouts
- Samples, Morceaux, Wishlist, Inspirations, MiRack, Spark
- 6 thèmes terminal (Béton, Machine, Nord, Solarized, Gruvbox, Dracula)

---

## v0.6.0-alpha — 2026-04-20

### Ajouts
- Suppression sessions (form POST + confirm)
- Vue Projets — regroupement de sessions sous un titre avec couleur
- Copie setup d'une session existante
- Tags cliquables dans la liste
- Dark mode toggle ◐

---

## v0.5.4-alpha — 2026-04-20

### Ajouts
- Page Paramètres — import DB, backup `.db` horodaté, reset sessions

---

## v0.5.3-alpha — 2026-04-20

### Ajouts
- Widget Pomodoro flottant persistant (25/5/15 min)
- Auto-save formulaires (localStorage)

### Corrections
- Stats Chart.js — fix compatibilité

---

## v0.5.2-alpha — 2026-04-20

### Ajouts
- Filtres et recherche en temps réel (texte libre, mode, note)
- Liaison entre sessions — select dropdown, affichage en card
- Fichier audio — bouton copier presse-papiers

---

## v0.5.1-alpha — 2026-04-20

### Ajouts
- Widget Pomodoro flottant (25/5/15 min, barre de progression)
- Bannière terminal ANSI + détection port libre au démarrage
- `os.chdir()` au démarrage

---

## v0.4.0 — 2026-04-20

### Ajouts
- Édition d'une session existante — route `/session/<id>/edit`
- Template `edit.html` — formulaire pré-rempli

---

## v0.3.1 — 2026-04-20 — Initial commit

### Ajouts
- Application Flask complète : sessions, catalogue, influences, obliques
- Dashboard statistiques interactif (Chart.js)
- Export Markdown individuel et global (compatible Obsidian)
- Champ `recap_claude` pour coller le résumé de session Claude
- Scripts de lancement Mac (`lancer.command`) et Windows (`lancer.bat`)
- Scripts de compilation binaire PyInstaller (`build_mac.sh`, `build_windows.bat`)
