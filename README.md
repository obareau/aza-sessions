# Journal de Sessions AZA

> Application de documentation et de performance musicale pour le projet **AZA** —
> univers de fiction dystopique dont les sessions de création constituent la bande originale.

**Version : v4.0.0** · [Changelog](CHANGELOG.md) · App Mac native — macOS 12+, Intel et Apple Silicon

---

## Ce que c'est

**Journal de Sessions AZA** est un outil personnel en trois parties :

1. **Carnet de bord musical** — documente chaque session de création (machines, patches, tempo,
   influences, notes, rating) et les organise en projets.

2. **⬡ Patcher** — mind map SVG interactif pour visualiser et documenter le routing signal
   entre machines hardware, effets, DAW, iOS et plugins.

3. ~~**Prompteur Dawless**~~ — parti chez **D.I.M** en v3.12.0 ; sa section ci-dessous est historique.

Depuis la v4.0.0, AZA est une **app Mac native** : la base vit sur le Mac, et une
**sauvegarde JSON complète est écrite à chaque modification**. Plus de serveur
(Roblab n'existe plus, Fly.io avant lui).

---

## Installer l'app Mac

1. Récupérer `AZA-Sessions-<version>.dmg` : onglet **Releases** du dépôt (versions
   taguées), ou l'artefact `AZA-Sessions-macOS` du dernier run **App Mac** dans
   l'onglet Actions. Ou la construire : `macos/build.sh` (voir plus bas).
2. Glisser **AZA Sessions** dans Applications.
3. L'app n'est pas signée par un compte développeur Apple — une fois :

   ```bash
   xattr -dr com.apple.quarantine "/Applications/AZA Sessions.app"
   ```

4. Premier lancement : base neuve. Une ancienne `sessions.db` ou une sauvegarde
   `.json` se restaure **entière** dans Fichier → Sauvegardes et restauration….

| Où | Quoi |
|---|---|
| `~/Library/Application Support/AZA Sessions/` | la base (`sessions.db`) |
| `~/Documents/AZA Sessions/Sauvegardes/` | une sauvegarde JSON par modification — réglable (Fichier → Choisir le dossier des sauvegardes…) |
| `~/Library/Logs/AZA Sessions/` | journaux de l'app et du serveur |

Raccourcis : ⌘N séance rapide · ⇧⌘N séance complète · **⌘S sauvegarder** · ⌘P imprimer ·
⌘1…6 Ce soir / Atelier / Stats / Catalogue / Prises / Lore · ⇧⌘O ouvrir dans le
navigateur (le SysEx a besoin de Web MIDI, que l'app n'a pas).

## Développement

```bash
pip install -r requirements.txt
python app.py                 # → http://127.0.0.1:5001
python -m pytest tests/ -q
```

Construire l'app (sur un Mac, avec le Python **universal2 de python.org** et les
outils Xcode) :

```bash
macos/build.sh                # → macos/dist/AZA Sessions.app, .dmg, .zip
```

---

## Fonctionnalités

### Sessions musicales
| Fonction | Description |
|---|---|
| Créer / Éditer / Supprimer | Formulaire complet avec titre, date, durée |
| Copier setup | Nouvelle session pré-remplie depuis une existante |
| Liaison sessions | Chaîne de travail sur un même morceau |
| Export Markdown | Compatible Obsidian — individuel ou global |
| Export PDF | Formulaire vierge A4 imprimable |
| Export → vault Obsidian | Push direct via chemin configuré |

### Organisation
| Fonction | Description |
|---|---|
| Projets | Regrouper plusieurs sessions avec couleur et description |
| Tags | Libres, cliquables pour filtrer |
| Filtres temps réel | Texte, mode, note |
| Statistiques | Dashboard Chart.js — machines, influences, timeline mensuelle |

### ⬡ Patcher — v3.5
| Fonction | Description |
|---|---|
| Canvas SVG interactif | Nœuds drag & drop, connexions Bézier avec flèches typées |
| Types de nœuds | machine · effet · daw · synth_ios · plugin · free + **types custom** |
| Types de signal | audio (orange) · midi (bleu) · cv (vert) · usb (violet) · autre |
| Icônes + note courte | Affichées dans chaque nœud sur le canvas |
| Barre de propriétés | Label, type, signal, note — éditables en bas, sélection simple clic |
| Panneau catalogue | Picker latéral — ajouter depuis le catalogue en un clic |
| Import depuis session | Crée automatiquement les nœuds depuis une session liée |
| **Export → Session** | Bouton `→ Session` : pré-remplit le formulaire session + signal_routing depuis le graphe |
| Types custom | synth_android, fx_android, etc. — couleur auto par hash, icône ◈ |
| Autosave | AJAX 1,5 s |
| Mode Nav / Édition | Toggle mobile : navigation page ou édition canvas (pinch-to-zoom, pan 1 doigt) |
| Export Mermaid | `.md` avec `graph LR`, flèches typées, tables nœuds/connexions |
| Export SVG | Standalone, CSS vars résolus, polices embarquées |
| Export PDF | Via `window.print()` paysage |
| Export / Import JSON | Format portable `from_index/to_index` — échange entre instances |
| **Dupliquer un layout** | Copie nœuds + connexions en un clic depuis la liste |
| **Snap-to-grid** | Grille 20 px optionnelle — touche `G`, persistée en localStorage |
| **Connexions multi-type** | Plusieurs câbles entre les mêmes nœuds — offset perpendiculaire automatique |
| **Minimap** | Vue d'ensemble 180×110 px — touche `M`, clic pour naviguer |

### ⎍ SysEx Loader & Bank Editor — v3.2

| Fonction | Description |
|---|---|
| Loader | Charger un `.syx` DX7/Volca FM par glisser-déposer ou file picker |
| Détection MIDI | `navigator.requestMIDIAccess({sysex:true})` — liste toutes les sorties |
| Test connexion | Phrase C3→C5 (arpège majeur 3 octaves) pour confirmation sonore |
| Preview patches | Noms des 32 patches parsés depuis le bulk dump DX7 (packed 128 bytes) |
| Canal MIDI | Réglable 1-16, byte `0n` réécrit dans le header SysEx avant envoi |
| Envoi | `output.send(bytes)` + toast confirmation |
| Librairie | Sauvegarder / charger / télécharger / supprimer des banks (BLOB SQLite) |
| **Bank Editor** | Assembler une bank custom depuis plusieurs sources |
| Source → Custom | `[+]` par patch ou `[+ Tous]` — swapper la source sans perdre la bank |
| Réordonnancement | ↑ ↓ ✕ par slot — 32 slots, vides comblés par init voice |
| Export .syx | Build bulk dump DX7 client-side + checksum 2's complement |
| Envoi direct | Web MIDI depuis l'éditeur sans passer par le loader |

### ⬡ Prompteur Dawless
| Fonction | Description |
|---|---|
| Scripts de set | Titre, description, cues (temps · patch · action · couleur) |
| Vue performance | Trois zones prev/current/next, plein écran |
| Transport DAW | ⏮ Rewind · ⏹ Stop · ▶ Play/Pause |
| Horloge | 48px — décompte cue (auto) ou chrono global (manuel) |
| Barre LED | Segments 22px, clignotement <10s/<5s, hauteur réglable |
| Mode auto / manuel | Avance automatique ou scrub barre / Espace / swipe |
| Zoom police | A+ / A− (40–250 %) |
| Import / Export | JSON structuré + Markdown Obsidian |

### Catalogue & Références
- Machines hardware, effets, DAW, synthés iOS, plugins — **classés par fabricant**
- **Types libres** (`synth_android`, `fx_android`…) — le patcher suit automatiquement
- **Ajout inline** depuis le formulaire session — modal AJAX sans perdre le contexte
- Influences (artistes, labels)
- **Stratégies Obliques AZA** — contraintes créatives aléatoires, style Brian Eno

### Ergonomie
- **Autosave brouillon** — formulaire nouvelle session restauré si on revient
- Zoom global A+ / A− — persisté en localStorage
- Menu hamburger sur mobile/iPad
- 6 thèmes : Béton · Machine · Nord · Solarized · Gruvbox · Dracula

---

## Stack technique

| Composant | Technologie |
|---|---|
| Backend | Python 3 / Flask |
| Base de données | SQLite (`sessions.db`) |
| App | Swift (AppKit + WKWebView) + serveur Flask figé par PyInstaller, universel macOS 12+ |
| Sauvegarde | JSON complet à chaque modification, SHA-256, rétention par paliers (`core/journal.py`) |
| Templates | Jinja2 |
| CSS | Vanilla — zéro framework externe |
| Graphiques | Chart.js |
| Patcher | SVG — Bézier, markers, drag & drop vanilla JS |
| Typographie | IBM Plex Mono / IBM Plex Sans |
| Thèmes | Béton · Machine · Nord · Solarized · Gruvbox · Dracula |

---

## Structure du projet

```
app.py                      # Launcher — blueprints, demarrer_sauvegardes()
macos/
  AZASessions/*.swift       # L'app : fenêtre, menus, serveur, impression, téléchargements
  server_main.py            # Serveur embarqué (contrat avec l'app, --selftest)
  build.sh                  # Build universel → .app, .dmg, .zip
  scripts/                  # vérification des binaires, essai de lancement, icône
core/
  db.py                     # get_db() partagé, ro_uri()
  journal.py                # Sauvegarde JSON : export, veille, rétention, restauration
  backup.py                 # Copie SQLite au démarrage
  init_db.py                # init_db(db_path) + migrations ALTER TABLE
  oblique.py / constants.py
sessions/                   # Blueprint sessions — CRUD, exports, search
catalogue/                  # Blueprint catalogue matériel
patcher/                    # Blueprint ⬡ Patcher
  engine.py                 # PatcherEngine — save, import session/catalogue, export
  api.py                    # Routes : view, save, import JSON, export Mermaid
obliques/ influences/ spark/ lore/ takes/ …
templates/
  patcher_list.html         # Liste layouts + form import JSON
  patcher_view.html         # Canvas SVG interactif complet
  ...
CHANGELOG.md
sessions.db                 # NON VERSIONNÉ
```

---

## Base de données

| Table | Description |
|---|---|
| `sessions` | Sessions musicales — table principale (30+ champs) |
| `projects` | Projets — regroupement de sessions |
| `patch_layouts` | Layouts patcher — nom, session liée |
| `patch_nodes` | Nœuds — label, position, type, couleur, note |
| `patch_connections` | Connexions — from/to, signal_type, label, note |
| `catalogue` | Matériel + types libres |
| `influences` | Artistes et labels |
| `obliques` | Stratégies créatives |

Les migrations sont automatiques via `ALTER TABLE … ADD COLUMN` dans `init_db()`.

---

## Sauvegardes

- **À chaque modification** (quelques secondes après la dernière saisie) et à la
  fermeture : copie JSON complète de toutes les tables, lisible dans un éditeur,
  vérifiée par empreinte SHA-256.
- **Gardées** : tout ce qui a moins de 48 h, une par jour sur 60 jours, une par mois
  au-delà — et toujours les 20 dernières.
- **Restaurer** (Paramètres) : un `.json` ou une vieille `sessions.db`, ou une
  sauvegarde de la liste en un clic. L'état courant est d'abord copié
  (`avant-restauration`) ; si cette copie échoue, rien n'est touché.
- **Si la sauvegarde échoue**, un bandeau le dit sur toutes les pages.

Fly.io (jusqu'en 2026-08) puis Roblab (jusqu'en 2026-11) ont hébergé AZA ; ni l'un ni
l'autre n'existe plus.

---

## Roadmap

### v3.3.x — Patcher : polish & puissance
- Connexions multi-type simultanées (audio + MIDI sur le même câble)
- Snap-to-grid optionnel
- Dupliquer un layout
- Minimap / vue d'ensemble sur les grands patches

### v3.4.x — Sessions : enrichissement
- Lecteur audio intégré (Web Audio API, waveform)
- BPM / tonalité dans les filtres de recherche

### v3.5.x — Vue Projet & Timeline
- Timeline visuelle des sessions par projet (Chart.js ou SVG)
- Page projet dédiée — durée totale, statut WIP / released
- Lien patch ↔ plusieurs sessions (relation 1-n)

### v4.x — Intégrations
- Export direct vers Obsidian via plugin AZA (WebSocket ou dossier watch)
- API REST légère pour scripting externe (Shortcuts iOS, mobile)
- PWA / offline-first

---

*Projet personnel — Olivier, Scaër, Bretagne — 2026*  
*La machine ne ment pas. Elle déforme.*
