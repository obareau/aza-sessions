# Journal de Sessions AZA

> Application de documentation et de performance musicale pour le projet **AZA** —
> univers de fiction dystopique dont les sessions de création constituent la bande originale.

**Version : v3.1.0** · [Changelog](CHANGELOG.md) · [Live →](https://robotariis-sessions.fly.dev/)

---

## Ce que c'est

**Journal de Sessions AZA** est un outil personnel en trois parties :

1. **Carnet de bord musical** — documente chaque session de création (machines, patches, tempo,
   influences, notes, rating) et les organise en projets.

2. **⬡ Patcher** — mind map SVG interactif pour visualiser et documenter le routing signal
   entre machines hardware, effets, DAW, iOS et plugins.

3. **Prompteur Dawless** — scripts de set avec minutage, noms de patch et instructions.
   Vue performance plein écran avec transport DAW, horloge décompte, barre LED, avance auto.

L'application tourne **localement** (`python app.py`) ou en **cloud** sur Fly.io.

---

## Démarrage rapide

```bash
pip install -r requirements.txt
python app.py
# → http://localhost:5000
```

Pour le déploiement cloud :

```bash
fly deploy   # depuis le dossier du projet
# → https://robotariis-sessions.fly.dev/
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

### ⬡ Patcher — v3.1
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
| Hébergement | Fly.io (Docker + Gunicorn) ou local |
| Templates | Jinja2 |
| CSS | Vanilla — zéro framework externe |
| Graphiques | Chart.js |
| Patcher | SVG — Bézier, markers, drag & drop vanilla JS |
| Typographie | IBM Plex Mono / IBM Plex Sans |
| Thèmes | Béton · Machine · Nord · Solarized · Gruvbox · Dracula |

---

## Structure du projet

```
app.py                      # Launcher — init_db, blueprints
wsgi.py                     # Point d'entrée Gunicorn (Fly.io)
Dockerfile / fly.toml       # Build + config Fly.io (région CDG, 256 MB)
core/
  db.py                     # get_db() partagé
  init_db.py                # init_db(db_path) + migrations ALTER TABLE
  oblique.py / constants.py
sessions/                   # Blueprint sessions — CRUD, exports, search
catalogue/                  # Blueprint catalogue matériel
patcher/                    # Blueprint ⬡ Patcher
  engine.py                 # PatcherEngine — save, import session/catalogue, export
  api.py                    # Routes : view, save, import JSON, export Mermaid
obliques/ influences/ spark/ dim/
templates/
  patcher_list.html         # Liste layouts + form import JSON
  patcher_view.html         # Canvas SVG interactif complet
  prompter_play.html        # Vue performance plein écran
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
| `prompter_scripts` | Scripts prompteur — JSON cues |
| `patch_layouts` | Layouts patcher — nom, session liée |
| `patch_nodes` | Nœuds — label, position, type, couleur, note |
| `patch_connections` | Connexions — from/to, signal_type, label, note |
| `catalogue` | Matériel + types libres |
| `influences` | Artistes et labels |
| `obliques` | Stratégies créatives |

Les migrations sont automatiques via `ALTER TABLE … ADD COLUMN` dans `init_db()`.

---

## Déploiement Fly.io

```bash
fly launch                          # première fois — crée l'app + volume
fly deploy                          # mise à jour
fly logs --app robotariis-sessions  # logs
```

La base SQLite vit dans un volume persistant monté sur `/data`.

---

## Roadmap

### v3.2.x — Patcher : polish & puissance
- Connexions multi-type simultanées (audio + MIDI sur le même câble)
- Snap-to-grid optionnel
- Dupliquer un layout
- Minimap / vue d'ensemble sur les grands patches

### v3.3.x — Sessions : enrichissement
- Import métadonnées depuis un fichier audio (date, durée automatiques)
- Lecteur audio intégré (Web Audio API, waveform)
- BPM / tonalité dans les filtres de recherche

### v3.4.x — Vue Projet & Timeline
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
