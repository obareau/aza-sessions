# CHANGELOG — Journal de Sessions AZA

> Les versions alpha sont des releases actives en développement continu.
> Chaque version est datée du jour de développement effectif.

---

## v3.8.0 — 2026-06-27 — Catalogue : saisie rapide, favoris & types dédiés

### ✨ Nouveautés
- **Saisie rapide multi-lignes** — bloc « ⊞ Saisie rapide » sur `/catalogue` : on choisit le type une fois puis on saisit plusieurs items (fabricant / nom / notes) d'un coup ; bouton « + Ligne », `Entrée` dans le champ nom ajoute une ligne ; insertion transactionnelle avec dédup `(type, nom)` et message `N ajoutés / M doublons ignorés`
- **Favoris catalogue** — étoile ★/☆ par item, remontés en tête de chaque type (tri `favorite DESC`) ; filtre « ★ favoris seulement »
- **Types dédiés** — `ipad` (Apps iPad) et `zynthian` (Zynthian / Raspberry Pi) ajoutés à `ITEM_TYPES` (type toujours libre)
- **Filtres & sections repliables** — recherche instantanée (nom/fabricant), filtre par type, sections `<details>` repliables pour désengorger la page

### 🛠 Infra & Qualité
- **Messages flash globaux** — rendu centralisé dans `base.html` (bénéficie aussi au module DIM)
- **Tests** — `tests/test_catalogue.py` (favoris, types dédiés, `add_bulk` + dédup, routes bulk/favorite)
- Migration `catalogue.favorite` (CREATE + ALTER)

---

## v3.7.2 — 2026-06-03 — Spark : contrainte unique + fix DIM

### ✨ Nouveautés
- **Spark contrainte unique** — historique en session Flask pour éviter les répétitions ; limite `SEEN_MAX = 8`, réutilisation après épuisement du pool
- **Port DIM configurable** via variable d'environnement `DIM_PORT` (défaut 5002, ajusté au port réel du service DIM)

### 🐛 Corrections
- **backup DB au démarrage Gunicorn** — le code sous `__main__` ne tourne pas en WSGI ; migration dans `wsgi.py`
- **retire sessions.db du tracking git** — fichier ignoré mais encore suivi ; suppression de l'index git

---

## v3.7.1 — 2026-05-23 — Vue compacte + tests

### ✨ Nouveautés
- **Vue compacte sessions** — grille alternée `compact.html` : ligne date+temps à gauche, titre/commentaire à droite, icônes machines, tags, lien Lore cliquable
- **Heatmap cliquable** sur l'index — cartographie des intensités sonores par session (rouge/vert/bleu selon le niveau de bruit signalé), survol affiche la date, clic va directement à la session

### 🛠 Qualité
- **Smoke tests** — couvre toutes les 18 routes blueprints (Flask client factory)

---

## v3.7.0 — 2026-05-16 — Carnet de Presets

### ✨ Nouveautés
- **Module Presets** — carnet de notes par preset/patch : instrument lié (catalogue), nom du preset, ce qu'il évoque, idée de morceau, influence rappelée, note ★, tags, session liée, notes libres
- **Stats presets** — par instrument/plugin : nombre de presets notés, moyenne ★, top presets mieux notés
- **Filtres presets** — par instrument et recherche textuelle (nom, évocation, idée, tags, influence)

---

## v3.6.1 — 2026-05-16 — Réécriture recap Ollama

### ✨ Nouveautés
- **Bouton ✦ Réécrire** sur la vue session — envoie le `recap_claude` à Ollama (`qwen3.5`, t=0.3) pour correction orthographique et reformulation ; conserve le style, la longueur et l'atmosphère AZA ; silencieux si Ollama indisponible

---

## v3.6.0 — 2026-05-16 — Responsive + FTS5 + Infra Roblab

### ✨ Nouveautés
- **Recherche full-text SQLite FTS5** — 15 champs indexés (title, machines, effects, daws, synths_ios, plugins, patches, tags, comments, influences, recap_claude, lore_link, signal_routing, oblique, intention) ; triggers INSERT/UPDATE/DELETE pour sync automatique ; fallback Python si indisponible ; tri par pertinence
- **Responsive complet** — 19 templates adaptés mobile/tablette/PC ; grids fixes → responsive ; touch targets 44px ; prompteur et vue live utilisables au pouce

### 🛠 Infra & Qualité
- **Migration Fly.io → Roblab** — service `aza-sessions.service` (Gunicorn port 5001) ; `sessions.lan` + `sessions.robotariis.com` via Cloudflare Tunnel
- **Linter ruff** — `ruff.toml`, zéro erreur
- **Suite pytest** — 15 tests (smoke routes + DB init/schema)

### 🐛 Corrections
- **Export SVG/PDF patcher** — reset du transform `g-root` avant export → viewBox correctement centré sur le contenu
- **Migration `manufacturer`** — colonne manquante dans `init_db()` causant un crash sur DB fraîche
- **Apostrophe Jinja2** — `about.html` template syntax error sur `d'ensemble`

---

## v3.5.0 — 2026-05-10 — Patcher v2 : polish & puissance

### ✨ Nouveautés
- **Dupliquer un layout** — bouton `⎘ Dupliquer` dans la liste ; copie complète nœuds + connexions (mapping IDs), ouvre directement la copie nommée `[nom] (copie)`
- **Snap-to-grid** — toggle `⊞ Grid` (toolbar + touche `G`) ; grille de points 20px visible quand actif ; snapping mouse + touch ; état persisté en localStorage
- **Connexions multi-type simultanées** — plusieurs câbles entre la même paire de nœuds (ex: audio + MIDI) s'écartent perpendiculairement (±16px par index) ; chaque câble conserve sa couleur et sa flèche
- **Minimap** — overlay bas-gauche 180×110px ; nœuds colorés par type, connexions filaires par signal, rectangle viewport accent ; clic → centre la vue principale ; toggle `⊟ Map` (toolbar + touche `M`) ; état persisté en localStorage

---

## v3.4.0 — 2026-05-10 — Dictée vocale live via Whisper local

### ✨ Nouveautés
- **Bouton 🎙 Dicter** dans la page session live — enregistre via `MediaRecorder`, transcrit via Whisper GPU local et insère le texte dans les notes live
- Route `/live/transcribe` (POST multipart) → `core/whisper_client.py` → Whisper `small` (GPU, RTX 3060, port 9000)
- Modèle upgradé `base` → `small` pour une meilleure précision sur le français
- Silencieux si Whisper indisponible (fallback erreur inline)

---

## v3.3.0 — 2026-05-10 — Recap session auto via Ollama (LLM local)

### ✨ Nouveautés
- **Génération automatique de `recap_claude`** à la fin d'une session live
  - À l'ouverture de `/new?from_live=1`, le champ *Récap session* est pré-rempli par `qwen3.5:latest` (Ollama, `192.168.1.100`)
  - Le récap est narratif, à la première personne, dans le style AZA (Dark Ambient / Industriel, Scaër)
  - Le client `core/ollama_client.py` est réutilisable pour les futures intégrations LLM local
  - Silencieux en cas d'indisponibilité du serveur (fallback champ vide)
  - `notes_live` désormais incluses dans le prefill pour enrichir le contexte du prompt

---

## v3.2.0 — 2026-05-09 — Module SysEx Loader & Bank Editor

### ✨ Nouveautés
- **Module ⎍ SysEx** `/sysex` — loader DX7 / Volca FM via Web MIDI API (Chrome)
  - Détection automatique des interfaces MIDI (`requestMIDIAccess({sysex:true})`)
  - Chargement `.syx` par glisser-déposer ou file picker
  - Preview des 32 noms de patches parsés depuis le bulk dump DX7 packed (128 bytes/voix)
  - Canal MIDI 1-16 réglable — byte `0n` réécrit dans le header avant envoi
  - Test connexion : phrase C3→E3→G3→C4→E4→G4→C5→G4→C4 (arpège majeur, 3 octaves)
  - Librairie de banks : save / load / download / delete (BLOB SQLite, table `sysex_banks`)
- **⎍ Bank Editor** `/sysex/editor` — patch librarian custom bank
  - Deux colonnes : Source (bank chargée) | Custom Bank (32 slots)
  - `[+]` par patch ou `[+ Tous]` pour alimenter la custom bank
  - Swapper la source sans perdre la custom bank en cours
  - Réordonnancement ↑ ↓ ✕ par slot
  - Slots vides comblés par une init voice (OP1 actif, silence)
  - Export `.syx` client-side (assemblage bulk DX7 + checksum 2's complement en JS)
  - Envoi direct via Web MIDI depuis l'éditeur
  - Sauvegarde dans la librairie existante

### ♻️ DB
- Migration `CREATE TABLE IF NOT EXISTS sysex_banks` (name, format, size, data BLOB)

---

## v3.1.0 — 2026-05-09 — Release Patcher complète

Clôture du cycle v3.0.x-alpha. Stabilisation et complétion du module Patcher.

### ✨ Nouveautés
- **Patcher → Session** — bouton `→ Session` dans la toolbar du Patcher : pré-remplit le formulaire Nouvelle Session avec les nœuds par type (machines, effets, DAW, iOS, plugins) et génère automatiquement le champ `signal_routing` depuis le graphe de connexions (DFS source → feuilles, format `A → B → C`, max 4 chemins)
- **Mode Navigation / Édition** (mobile) — toggle `✎ Éditer` / `⊙ Naviguer` : en mode Navigation la page défile normalement, en mode Édition le canvas capte tous les gestes tactiles. Bouton flottant `↑ Menu` pour sortir du mode Édition sans chercher le bandeau
- **Centrage automatique** du canvas au chargement — `centerContent()` cale le layout dans le viewport (pan + zoom ajustés)
- **Pinch-to-zoom** mobile sur le canvas — 2 doigts, ancré sur le milieu des touches

### 🐛 Corrections
- **`SECRET_KEY` manquant** — `flask.session` crashait en production Fly.io (500 sur `→ Session` et tout redirect avec prefill via session). Ajout de `app.secret_key = os.environ.get("SECRET_KEY", "aza-sessions-local-dev")`
- Export JSON portabilité — connexions sérialisées avec `from_index` / `to_index` (numéro dans la liste des nœuds, sans dépendance aux IDs DB)

---

## v3.0.1-alpha — 2026-05-09 — Patcher : import/export JSON + types dynamiques

### ✨ Nouveautés
- **Export JSON** (`⬇ Export ▾ → { } JSON`) — sérialise nœuds + connexions avec `from_index`/`to_index` (portable, sans dépendance aux IDs DB)
- **Import JSON** — formulaire dans la liste des patches ; crée un nouveau layout complet depuis un `.json` exporté
- **Export Mermaid .md** — `graph LR` avec flèches typées et tables nœuds/connexions
- **Export SVG** — standalone avec CSS vars résolus et polices Google Fonts embarquées
- **Export PDF** — via `window.print()` paysage
- **Types custom** dans le catalogue (`synth_android`, `fx_android`, etc.) — le patcher suit automatiquement (couleur par hash, icône générique `◈`)
- **Icônes par type** et **note courte** affichées dans chaque nœud du canvas
- **Barre de propriétés inline** — label, type, note éditables en bas de canvas sans popup

### 🐛 Corrections / migrations
- Migration `ALTER TABLE patch_nodes ADD COLUMN note TEXT DEFAULT ''`
- Migration `ALTER TABLE patch_connections ADD COLUMN note TEXT DEFAULT ''`

---

## v3.0.0-alpha — 2026-05-09 — Module Patcher + finalisation architecture

### ✨ Nouveautés
- **Module Patcher** `/patcher` — mind map SVG interactif pour documenter le patching
  - Nœuds drag & drop : machines, effets, DAW, iOS, plugins (couleurs par type)
  - Connexions courbes avec flèches typées : audio (orange), MIDI (bleu), CV (vert), USB (violet)
  - Import auto depuis une session liée ou depuis tout le catalogue actif (AJAX)
  - Mode connexion (touche `C`), double-clic édition label, `Del` suppression
  - Autosave AJAX 1,5 s, rename inline, layouts nommés et multiples
  - Lien `⬡ Patcher` depuis chaque vue session
  - Tables `patch_layouts`, `patch_nodes`, `patch_connections`

### ♻️ Architecture
- **`app.py` 116 lignes** — `init_db()` + données par défaut déplacés dans `core/init_db.py`
- **`wsgi.py`** corrigé : `init_db(DB_PATH)` après extraction dans `core/`
- **`fly.toml`** : `dockerfile = "Dockerfile"` explicite (fix deploy Fly.io)
- **`.gitignore`** : ajout `backups/` et `config.json`
- **`.dockerignore`** : ajout `.claude/` — exclut les git worktrees du build context Fly.io

---

## v2.5.0 — 2026-05-05 — Release finale v2.x

Version de stabilisation et de complétude du cycle v2. Clôture le roadmap avant la v3.

### ✨ Nouveautés
- **Pagination liste sessions** — 25 sessions par page, server-side (LIMIT/OFFSET SQLite) ; barre prev/next + numéros avec ellipsis ; compatible avec la recherche ; subtitle affiche le total et la page courante
- **Révéler dans Finder** — bouton `⌕` dans la vue session : ouvre Finder et sélectionne le fichier audio (`open -R <chemin>`) ; route `GET /session/<id>/reveal`
- **Export direct vers vault Obsidian** — bouton `⬡ Vault` (AJAX `POST /session/<id>/obsidian`) : écrit le Markdown dans le dossier vault configuré ; toast succès/erreur 3 s
- **Configuration vault** dans les Paramètres — champ chemin absolu, sauvegardé dans `config.json`

### 🐛 Corrections
- **Widget Pomodoro restauré** — classe CSS `.pomo { position:fixed; … }` perdue lors d'une refacto ; réinjectée
- **Zoom A+ / A−** fonctionnel — l'implémentation `document.documentElement.style.fontSize` n'affectait que les unités `rem` (CSS entièrement en `px`) ; remplacé par `document.body.style.zoom`
- **Theme picker** toujours accessible mobile/tablette — déplacé hors de la `<nav>` (drawer hamburger) dans la barre header ; `position:fixed` sur le dropdown pour éviter le clipping `overflow`
- **Suppression du double `#theme-dropdown`** — IDs dupliqués entre l'ancien picker (dans nav) et le nouveau (dans header)

---

## v2.4.0 — 2026-05-09 — Refactorisation complète en Blueprints

### ♻️ Extraction des modules restants
- **`projects/`** — Blueprint 5 routes : liste, new, view, edit, delete (+ détachement sessions)
- **`settings_app/`** — Blueprint 4 routes : settings, backup, import DB, reset sessions
- **`samples/`** — Blueprint CRUD sample banks
- **`tracks/`** — Blueprint CRUD morceaux inspirants
- **`wishlist/`** — Blueprint CRUD wishlist matériel (+ toggle acquired)
- **`inspirations/`** — Blueprint CRUD inspirations
- **`mirack/`** — Blueprint CRUD modules MiRack (+ toggle mastered/favorite)
- **`about/`** — Blueprint route `/about`
- **`stats/`** + **`live/`** — extraits en v2.1.x
- `app.py` réduit à ~260 lignes (launcher + init_db + context processor + banner)
- Tous les `url_for` dans les templates namespaced (`projects.list_projects`, `settings_app.settings`, etc.)
- `core/constants.py` enrichi : SAMPLE_TYPES, MIRACK_CATS, WISHLIST_TYPES, WISHLIST_PRIOS, INSPI_TYPES

### ✨ Comportement inchangé — zéro régression UI (16/16 routes OK)

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
