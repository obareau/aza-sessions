# CHANGELOG — Journal de Sessions AZA

> Les versions alpha sont des releases actives en développement continu.
> Chaque version est datée du jour de développement effectif.

---

## v3.13.1 — 2026-08-29 — Ménage : les restes de Fly.io

### 🧹 Nettoyage
- **`fly.toml` retiré** et **branche `FLY_APP_NAME` supprimée de `wsgi.py`.** Le
  déploiement Fly est abandonné ; ce bloc redirigeait encore `DB_PATH` et
  `BACKUPS_DIR` vers `/data` si la variable apparaissait — un chemin qui
  n'existe pas sur Roblab, donc une base créée ailleurs sans que rien ne le dise.
- **`dim/` supprimé** — dossier vide depuis que le Prompteur est parti chez D.I.M
  (v3.12.0), plus rien ne l'importait.
- `wsgi.py` documente maintenant son rôle : c'est le chemin réel en production,
  le bloc `__main__` de `app.py` ne tourne jamais sous Gunicorn.
- README recalé : v3.5.0 → v3.13.0, lien « Live » vers `sessions.robotariis.com`
  au lieu de l'URL Fly morte, et procédure de déploiement systemd.

ℹ️ Le `Dockerfile` est conservé : il ne servait qu'au build Fly et n'est plus
utilisé, mais il ne gêne pas.

---

## v3.13.0 — 2026-08-29 — Carnet d'instrument

### ✨ Nouveautés
- **Carnet par instrument** `/catalogue/<id>` — le catalogue n'avait qu'une liste,
  aucune page par fiche. Chaque machine, plugin ou effet a désormais la sienne, qui
  rassemble ce qu'on finit par savoir d'un instrument à force de s'en servir.
  - **★ Patches favoris** — repris du module **Presets** (v3.7.0), triés par note.
    Pas de seconde table : la même information n'a qu'un seul endroit où vivre, et
    ça donne enfin une raison de remplir `preset_notes`, restée vide depuis mai.
  - **⇄ Marche bien avec** — associations entre deux fiches du catalogue, avec la
    raison. Une relation et non du texte libre : l'effet nommé une fois reste lié
    même si la fiche est renommée. **L'association se lit des deux côtés** — dire
    « le MicroFreak passe bien dans le NTS-1 » l'affiche aussi sur la fiche du
    NTS-1, sans double saisie (`UNION` sur les deux sens dans `pairings()`).
  - **✎ Remarques d'utilisation** — journal horodaté qui s'empile, pas un champ
    qu'on réécrit : apprendre une machine se fait par couches, et écraser la
    remarque précédente perdrait le chemin parcouru.
- Bouton ◧ sur chaque ligne du catalogue pour ouvrir le carnet.

### ♻️ DB
- `gear_pairings` (gear_id, partner_id, note) et `gear_notes` (gear_id, date, note),
  créées par `init_db` — migration transparente, rien à faire sur une base existante.

### 🛡 Garde-fous
- Association à soi-même refusée ; doublon refusé **dans les deux sens** ; remarque
  vide refusée ; fiche inexistante → redirection vers le catalogue, pas une 500.

---

## v3.12.1 — 2026-08-29 — Durcissement de la sauvegarde automatique

Le backup tournait déjà des deux côtés (bloc `__main__` de `app.py` en local,
bloc inline de `wsgi.py` sous Gunicorn), mais en **double exemplaire** et avec
deux fragilités.

### ♻️ Refactor
- **`core/backup.py`** — une seule implémentation, appelée par `app.py` et `wsgi.py`.
  Les deux blocs inline disparaissent.
- `BACKUPS_DIR` remonte dans `app.config`, au même titre que `DB_PATH` et `CONFIG_PATH`.
- `app.py` : imports `glob`, `shutil`, `datetime` devenus inutiles, retirés.

### 🐛 Correctifs
- **Snapshot via `sqlite3.Connection.backup()` au lieu de `shutil.copy2`.** Sous
  Gunicorn l'app sert déjà des requêtes au moment du boot ; copier le fichier
  pendant une écriture donne une base déchirée. Vérifié : un snapshot pris
  pendant une transaction ouverte non committée rend une base à
  `integrity_check: ok`, sans l'écriture en cours.
- **La rétention ne survivait pas à un crash-loop.** `aza-sessions.service` tourne
  en `Restart=always` : cinq relances rapides suffisaient à évincer les cinq
  backups et à ne garder que des copies de l'état cassé — le filet disparaissait
  au moment précis où il aurait servi. Le snapshot est désormais **sauté si la base
  est inchangée** (SHA-256 contre le dernier backup). Vérifié : trois boots
  consécutifs sur base identique ne produisent qu'un seul fichier.
- Écriture par fichier temporaire puis `os.replace` — un processus tué en cours
  ne laisse plus de backup partiel.
## v3.12.0 — 2026-08-09 — Le Prompteur quitte AZA pour D.I.M

> ⚠️ Entrée ajoutée après coup le 2026-08-29. Cette version était documentée
> dans `ROADMAP.md` mais **absente du CHANGELOG**, et `VERSION` dans `app.py`
> était resté à 3.10.0 — deux releases de retard. C'est ce décalage qui a fait
> numéroter le carnet d'instrument « v3.12.0 » par erreur, sur un numéro déjà pris.
>
> Le détail de ce qui a été déplacé vit dans le ROADMAP (blueprint `dim/`,
> 3 templates, table `prompter_scripts` et `core/link_service.py` retirés,
> −1 976 lignes). Résumé repris ici pour que la suite des versions soit continue,
> **à compléter par Olivier** s'il veut le détail au même niveau que les autres.

- **Le Prompteur et l'axe Ableton Link partent chez D.I.M.** AZA est le journal
  (avant, pendant, après une session) ; D.I.M est le séquenceur de performance.

---

## v3.11.0 — 2026-08-08 — Ableton Link : le Prompteur sur la grille

### ✨ Nouveautés
- **Pair Ableton Link** — `core/link_service.py` tient un pair unique pour le processus ; `GET /api/link/state` renvoie tempo, beat, phase, nombre de pairs et `next_downbeat_s`
- **Affichage tempo dans la topbar du Prompteur** — pastille battant sur le temps, BPM, nombre de pairs. Le widget se cache tant qu'aucun pair n'est vu
- **Quantize des cues** — bouton ⊟ Quantize : l'avance **automatique** attend le prochain temps fort, la barre de temps restant pulse pendant l'attente. État retenu en localStorage

### ⚠️ À savoir
- **`abletonlink` n'existe pas** sur PyPI, malgré ce que la roadmap annonçait — la bibliothèque est **`LinkPython-extern`**, ajoutée en dépendance **optionnelle** : sans elle l'app dégrade en silence
- **Seule l'avance automatique est quantifiée.** Un appui manuel reste instantané — attendre donnerait l'impression d'un bouton cassé
- **Le quantize relit `next_downbeat_s` au moment d'avancer**, jamais la phase extrapolée du widget : celle-ci dérive sans borne et ne sert qu'à l'animation
- **`--workers 1` devient une contrainte** : chaque instance Link apparaît comme un appareil distinct sur le réseau, deux workers dédoubleraient l'app dans la session de tous les musiciens
- Trois échappatoires empêchent tout blocage en set : pas de pair · requête > 400 ms · délai annoncé supérieur à une mesure

### 🧪 Validé contre un Ableton Live distant
Découverte en 2 s, tempo lu (115 BPM), phase exacte, **écriture fonctionnelle** (tempo poussé puis ramené). ⚠️ Deux écritures ont échoué en silence avant qu'une troisième passe — `set_tempo()` relit donc systématiquement et renvoie `ok: False` en cas d'échec.

---

## v3.10.0 — 2026-06-27 — Idées en vrac & SPARK

### ✨ Nouveautés
- **Idées en vrac** — la page `/inspirations` est recadrée en « 💡 Idées en vrac » (titre, nav « Idées en vrac ») ; nouveau type `Idée` (placé en tête de `INSPI_TYPES`) pour distinguer les idées brutes des autres sources
- **SPARK pioche dans les idées** — `SparkEngine.focus()` et `suggestions()` font remonter en priorité les entrées de type `Idée` (pondérées ×2 dans le pool focus), badge « 💡 Idée en vrac » ; la dédup `type|text` et l'historique session `SEEN_MAX=8` restent inchangés

### 🛠 Qualité
- **Tests** — `tests/test_spark_ideas.py` (type Idée, focus la propose, dédup exclut une idée vue, suggestions la fait remonter, page recadrée)

---

## v3.9.0 — 2026-06-27 — Sessions typées : musique / lore / veille & code

### ✨ Nouveautés
- **Type de session** — colonne `session_type` (`music` par défaut / `lore` / `veille`) ; sélecteur en onglets en tête du formulaire `/new` et `/edit`
- **Formulaire conditionnel** — les sections s'affichent selon le type (JS, sans rechargement) : le matériel/technique/capture n'apparaît qu'en mode musique ; lore et veille réutilisent titre, lien (libellé contextuel « Lien lore » / « Lien / Référence »), notes libres, caractère, tags, évaluation — aucune colonne texte superflue
- **Sections matériel iPad & Zynthian** — nouvelles colonnes `sessions.ipad` et `sessions.zynthian`, sections check-grid dédiées (groupées par fabricant), affichées dans la vue et l'export si renseignées
- **Anti-surcharge du formulaire** — barre de filtre matériel : recherche instantanée par nom + bascule « ★ favoris seulement » ; favoris remontés en tête (tri `favorite DESC`) et marqués d'une étoile
- **Filtre & badge par type** — select « Type » dans la recherche `/search` ; badge ✎ Lore / ⚙ Veille sur l'index et la vue session
- **Recap Ollama par type** — prompts dédiés lore (récit) et veille (résumé factuel) en plus du prompt musical

### 🛠 Infra & Qualité
- **`ITEM_TYPES` unifié** — source unique dans `core/constants.py` (suppression du doublon dans `catalogue/engine.py`)
- Migrations `sessions.session_type` / `ipad` / `zynthian` (CREATE + ALTER)
- **Tests** — `tests/test_session_types.py` (colonnes, défaut music, round-trip iPad/Zynthian, filtre recherche, export CSV)

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
