# Journal de Sessions AZA

> Application de documentation et de performance musicale pour le projet **AZA** —
> univers de fiction dystopique dont les sessions de création constituent la bande originale.

**App macOS** · [Télécharger](https://github.com/obareau/aza-sessions/releases/latest) · [Code de l'app](macos/) · [App web (historique)](#application-web-flask--historique)

![AZA — le Journal](macos/docs/screenshots/journal.png)

---

## App native macOS

Le journal tourne désormais en **app native macOS (SwiftUI)**, sans serveur : toutes les données
tiennent dans **un seul fichier JSON** (`~/Documents/AZA Sessions/aza-sessions.json`), sauvegardé à
chaque modification, avec 5 copies datées. Toutes les fonctions de l'app web Flask ont été portées.

### Installer

1. Télécharger **`AZA-macos-vX.Y.Z.dmg`** depuis les [releases](https://github.com/obareau/aza-sessions/releases/latest)
   et glisser AZA dans Applications.
2. Au premier lancement : **clic droit → Ouvrir** (app signée ad-hoc, non notariée).

macOS 13 Ventura ou plus récent · binaire universel (Apple Silicon et Intel).
Pour reprendre une base de l'app web : **Fichier › Importer une base sessions.db…**

### iCloud Drive : synchro et sauvegarde (nouveau en 1.9)

Dans **Réglages › Données › iCloud Drive** :
- **Synchroniser avec iCloud Drive** : le JSON, les photos et sons du journal et les sauvegardes passent dans
  `iCloud Drive/AZA Sessions`, et tous tes Mac travaillent sur les mêmes données. AZA recharge ce qu'un autre
  Mac a écrit, ne réécrit jamais un fichier qu'elle n'a pas modifié, et en cas de collision garde les deux
  versions (`backups/conflit-…`).
- **Sauvegarde quotidienne dans iCloud Drive** : même sans synchro, une copie datée du JSON par jour
  (30 gardées) et les médias du journal partent dans `iCloud Drive/AZA Sessions — Sauvegardes`. Une sauvegarde
  hors du Mac, sans rien payer de plus que ton iCloud.

Pas de CloudKit : il faudrait un compte développeur Apple. AZA s'appuie sur iCloud Drive, que macOS synchronise
lui-même ; un fichier déchargé par « Optimiser le stockage » est retéléchargé avant d'être lu.

### Annuler, historique, barre de menus (nouveau en 1.10)

- **Annuler / Rétablir** (⌘Z / ⇧⌘Z) sur tout : séances, journal, patcher, catalogue… Une phrase tapée
  s'annule d'un coup, et le menu dit ce qui sera annulé (« Annuler — journal »).
- **Historique et restauration** (⇧⌘Y) : les sauvegardes de ce Mac (à l'ouverture et toutes les heures,
  12 gardées), les copies de conflit et les sauvegardes d'iCloud Drive. Pour chacune, ce qui a changé depuis ;
  **restaurer tout**, ou **récupérer une séance ou une entrée de journal** sans toucher au reste.
- **AZA dans la barre de menus** : chrono de la séance en cours (avec notes rapides et « Terminer → séance »),
  pomodoro, tirage du soir, une pensée à ajouter au journal. Fermer la fenêtre ne quitte plus AZA.

| | |
|---|---|
| ![Historique et restauration](macos/docs/screenshots/history.png) | ![Barre de menus](macos/docs/screenshots/menubar.png) |
| **Historique** — ce qui a changé depuis une sauvegarde, récupération à la pièce | **Barre de menus** — séance en cours, pomodoro, tirage, journal |

### Journal (nouveau en 1.8)

Un journal personnel dans l'esprit de l'app Journal d'Apple — qui n'existe pas sur macOS 13 —, mais relié
à l'univers AZA. Il est dans le groupe **Écrire** du menu, et **⇧⌘J** ouvre une nouvelle entrée depuis n'importe où.

- **Entrées** datées : date, heure et lieu modifiables après coup, titre facultatif (sinon la première ligne
  fait titre), signets, compteur de mots.
- **Photos et notes audio** : bouton, glisser-déposer, ou **enregistrement au micro**. Double-clic pour
  ouvrir une photo, lecture et légende pour chaque son.
- **État d'esprit** : 7 crans de « très désagréable » à « très agréable », puis ce que tu ressens
  (Calme, Inspiré, Fatigué…) et ce qui y est lié (Musique, Lore, Scaër…).
- **Suggestions d'écriture** tirées de ce que tu fais : les séances de la semaine pas encore racontées,
  ton dernier preset, un instrument favori, ton dernier patch, une stratégie oblique, une citation du lore,
  une inspiration, et des questions de réflexion. L'entrée garde la suggestion en exergue et se relie à la
  séance ou au matériel concerné.
- **Calendrier** du mois, avec les photos et l'humeur de chaque jour ; double-clic sur un jour vide pour
  écrire ce jour-là.
- **Aperçu** : série en cours et record, entrées, mots et jours écrits dans l'année, humeur moyenne,
  ressentis les plus fréquents, carte des jours écrits.
- **Recherche** et **filtres** : signets, avec photos, avec son, avec humeur, liées à AZA.
- **Liens** vers des séances, du matériel, un patch ou une page du lore, ouvrables d'un clic.
- **Export** Markdown, ou écriture directe dans le vault Obsidian (dossier `Journal/`, médias compris).
- **Verrou Touch ID** (ou mot de passe du Mac), refermé quand AZA passe à l'arrière-plan, et **rappel
  quotidien** à l'heure choisie : Réglages › Journal.

| | |
|---|---|
| ![Journal — fil et éditeur](macos/docs/screenshots/journal.png) | ![Journal — calendrier](macos/docs/screenshots/journal-calendar.png) |
| **Fil et éditeur** — suggestions, entrées, photo, note audio, état d'esprit | **Calendrier** — les jours écrits, avec leurs photos et leur humeur |
| ![Journal — aperçu](macos/docs/screenshots/journal-insights.png) | ![Journal — thème Béton](macos/docs/screenshots/journal-beton.png) |
| **Aperçu** — séries, mots écrits, ressentis, humeur | Le même journal en thème **Béton** |

Les photos et les sons sont des fichiers dans `journal-media/`, à côté du JSON. Les sauvegardes datées ne
couvrent que le JSON : garde ce dossier avec lui (Time Machine, iCloud…).

### En images

| | |
|---|---|
| ![Séances](macos/docs/screenshots/sessions.png) | ![Thème Béton](macos/docs/screenshots/sessions-beton.png) |
| **Séances** — tous les champs, filtres, nom de prise Zoom R8 | Les **6 thèmes** de l'app web (ici Béton) + un thème personnalisé |
| ![Patcher lié au catalogue](macos/docs/screenshots/patcher.png) | ![Ce soir — le tirage](macos/docs/screenshots/tonight.png) |
| **Patcher** — câbles audio / MIDI / CV / USB, minimap, lié en direct au catalogue | **Ce soir** — un instrument, un traitement, une contrainte, un titre, un nom de prise |
| ![Statistiques](macos/docs/screenshots/stats.png) | ![Catalogue](macos/docs/screenshots/catalogue.png) |
| **Statistiques** — séries, activité de l'année, tendances | **Catalogue** — fiche, carnet d'instrument, façade, codes de prise |
| ![Réglages](macos/docs/screenshots/settings.png) | |
| **Réglages** — taille du texte et du menu latéral, police, thème | |

### Ce qu'elle fait

- **Écrire** : journal personnel (photos, sons, état d'esprit, suggestions, calendrier, aperçu, verrou Touch ID, rappel).
- **Jouer** : Ce soir (tirage), séance En cours avec chrono, Spark, séance rapide (⇧⌘N).
- **Séances** : séances (tous les champs, nom de prise Zoom R8, titres dans l'esthétique AZA, filtres),
  projets, registre des prises, statistiques.
- **Matériel** : catalogue (carnet d'instrument, façade, proposition de codes), **patcher**, relevés de
  façade, presets, **SysEx DX7 / Volca FM** via CoreMIDI, wishlist.
- **Références** : lore (lu depuis le vault Obsidian, rien n'est copié), influences, stratégies
  obliques, morceaux, inspirations, samples, MiRack.
- **Sorties** : fiches imprimables A4 (séance, rappel, feuille d'atelier, formulaire terrain, fiches
  matériel) en impression ou PDF ; export Markdown, CSV, JSON ; écriture dans le vault Obsidian.
- **Récap IA** via Ollama (serveur et modèle réglables ; les échecs sont toujours affichés).
- Annuler / rétablir (⌘Z), historique et restauration (⇧⌘Y), AZA dans la barre de menus.
- Pomodoro, bandeau de stratégie oblique, aide clavier (⌘/), taille du texte et du menu latéral réglables.

### Nouveautés

| Version | Ce qui arrive |
|---|---|
| **1.10.0** | **Annuler / Rétablir** partout, **historique et restauration** des sauvegardes (tout ou à la pièce), **AZA dans la barre de menus**. Sauvegardes locales toutes les heures. |
| **1.9.0** | **iCloud Drive** : synchro entre Mac et sauvegarde quotidienne hors du Mac. L'app ne réécrit plus un fichier inchangé (à l'ouverture comme à la fermeture). |
| **1.8.0** | **Journal** : entrées avec photos et sons, état d'esprit, suggestions AZA, calendrier, aperçu, verrou Touch ID, rappel quotidien. Puces à la couleur du thème. |
| **1.7.2** | Graphiques et calendrier d'activité à la couleur du thème ; patcher bien cadré à l'ouverture, minimap visible, nœuds lisibles en thème sombre. |
| **1.7.1** | Fin du portage de l'app web : **récap IA** (Ollama), **export vers le vault Obsidian**, **séance rapide** (⇧⌘N), export CSV, propositions de titres, filtres de séances, pomodoro, bandeau de stratégie, aide clavier, **taille du menu latéral**. |
| **1.6.0** | **Patcher lié en direct au catalogue** : renommer ou reclasser une fiche se répercute dans tous les patches ; panneau catalogue dans le patcher. |
| **1.5** | Fiches imprimables A4 (séance, rappel, atelier, formulaire, matériel) en impression ou PDF. |
| **1.0 – 1.4** | App native, sauvegarde JSON, import `sessions.db`, réglages et thèmes, patcher, SysEx DX7 / Volca FM, lecture du lore. |

Détail de chaque version : [releases](https://github.com/obareau/aza-sessions/releases).

### Construire depuis les sources

```bash
bash macos/build_app.sh            # → macos/build/AZA.app (avec les seuls Command Line Tools)
bash macos/build_app.sh --install  # copie aussi dans ~/Applications
```

Détails techniques : [`macos/README.md`](macos/README.md).

---

## Application web (Flask) — historique

> L'app web ci-dessous reste dans le dépôt pour mémoire. **Version : v3.15.1** ·
> [Changelog](CHANGELOG.md) · [Live →](https://sessions.robotariis.com)

### Ce que c'est

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

Pour le déploiement :

```bash
# Sur Roblab (bare metal, systemd + Gunicorn — plus de Fly.io depuis 2026)
git pull && sudo systemctl restart aza-sessions
# → https://sessions.robotariis.com
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
wsgi.py                     # Point d'entrée Gunicorn — init_db + backup au démarrage
Dockerfile                  # Résiduel : servait au build Fly.io, plus utilisé
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
