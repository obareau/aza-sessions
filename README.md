# Journal de Sessions AZA

> Application de documentation et de performance musicale pour le projet **AZA** —
> univers de fiction dystopique dont les sessions de création constituent la bande originale.

**Version : v2.5.0** · [Changelog](CHANGELOG.md)

---

## Ce que c'est

**Journal de Sessions AZA** est un outil personnel en deux parties :

1. **Carnet de bord musical** — documente chaque session de création (machines, patches, tempo,
   influences, notes, rating) et les organise en projets.

2. **Prompteur Dawless** — scripts de set avec minutage, noms de patch et instructions.
   Vue performance plein écran avec transport DAW (Play/Stop/Rewind), horloge décompte,
   barre de progression segmentée style LED, avance automatique entre cues.

L'application tourne **localement** (`python app.py`) ou en **cloud** sur Fly.io.

---

## Démarrage rapide

```bash
pip install -r requirements.txt
python app.py
# → http://localhost:5001
```

Pour le déploiement cloud :

```bash
fly deploy   # depuis le dossier du projet
# → https://aza-sessions.fly.dev/
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
| Export PDF | Formulaire vierge A4 imprimable (mode dégradé papier) |

### Organisation
| Fonction | Description |
|---|---|
| Projets | Regrouper plusieurs sessions avec couleur et description |
| Tags | Libres, cliquables pour filtrer |
| Filtres temps réel | Texte, mode, note |
| Statistiques | Dashboard Chart.js — machines, influences, timeline mensuelle |

### ⬡ Prompteur Dawless
| Fonction | Description |
|---|---|
| Scripts de set | Titre, description, cues (temps · patch · action · couleur) |
| Vue performance | Trois zones prev/current/next, plein écran |
| Transport DAW | ⏮ Rewind · ⏹ Stop · ▶ Play/Pause |
| Horloge | 48px — décompte cue en auto, chrono en manuel |
| Barre LED | Segments 22px, clignotement (<10s / <5s), hauteur réglable |
| Mode auto | Avance automatique — durée depuis minutage ou valeur par défaut |
| Mode manuel | Barre scrub, clic / Espace / swipe mobile |
| Zoom police | A+ / A− (40–250 %) |
| Import / Export | JSON structuré + Markdown compatible Obsidian |

### Catalogue & Références
- Machines hardware, effets, DAW, synthés iOS, plugins VST/AU — **classés par fabricant**
- **Ajout inline depuis le formulaire** — modal AJAX, sans quitter la session en cours
- Influences (artistes, labels)
- **Stratégies Obliques AZA** — contraintes créatives aléatoires, style Brian Eno

### Ergonomie
- **Autosave brouillon** — le formulaire nouvelle session se sauvegarde en continu, restauré si on revient sans avoir soumis
- Zoom global A+ / A− — persisté en localStorage
- Menu hamburger sur iPad et mobile

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
| Typographie | IBM Plex Mono / IBM Plex Sans |
| Thèmes | Béton · Machine · Nord · Solarized · Gruvbox · Dracula |

---

## Structure du projet

```
app.py                      # Launcher — init_db, blueprints, modules non encore extraits
wsgi.py                     # Point d'entrée Gunicorn (Fly.io)
Dockerfile                  # Build Docker Python 3.11-slim
fly.toml                    # Config Fly.io (région CDG, 256 MB)
core/
  db.py                     # get_db() partagé
  oblique.py                # rand_oblique() partagé
  constants.py              # listes de référence (MODES, INTENTIONS, etc.)
sessions/                   # Blueprint sessions — CRUD, exports, search, settings
catalogue/                  # Blueprint catalogue matériel
obliques/                   # Blueprint stratégies obliques
influences/                 # Blueprint influences
spark/                      # Blueprint moteur de suggestions
dim/                        # Blueprint D.I.M Lite — prompteur Dawless
templates/
  base.html                 # Layout commun — nav, CSS, Pomodoro, dark mode
  index.html                # Liste des sessions
  new.html / edit.html      # Formulaires session
  view.html                 # Détail session
  stats.html                # Dashboard statistiques
  prompter_list.html        # Liste des scripts prompteur
  prompter_edit.html        # Éditeur de cues
  prompter_play.html        # Vue performance plein écran
  form_blank.html           # Formulaire PDF vierge
  catalogue.html / projects.html / settings.html / about.html
requirements.txt            # flask>=3.0.0
CHANGELOG.md                # Historique complet des versions
sessions.db                 # Base SQLite — NON VERSIONNÉ
```

---

## Base de données

| Table | Description |
|---|---|
| `sessions` | Sessions musicales — table principale (30+ champs) |
| `projects` | Projets — regroupement de sessions |
| `prompter_scripts` | Scripts prompteur — JSON cues |
| `catalogue` | Matériel : machine, effet, daw, synth_ios, plugin |
| `influences` | Artistes et labels |
| `obliques` | Stratégies créatives |

Les migrations sont automatiques au démarrage via `ALTER TABLE … ADD COLUMN` dans `init_db()`.

---

## Déploiement Fly.io

```bash
# Première fois
fly launch          # crée l'app et le volume

# Mises à jour
fly deploy          # rebuild Docker + rolling deploy

# Logs
fly logs --app aza-sessions
```

La base SQLite est stockée dans un volume persistant monté sur `/data`.
`wsgi.py` appelle `init_db()` dans `app.app_context()` avant que Gunicorn ne démarre.

---

## Roadmap v2.x — Complété ✓

| Fonctionnalité | Version |
|---|---|
| Pagination liste sessions | v2.5.0 |
| Lien fichier audio → Finder | v2.5.0 |
| Export direct → vault Obsidian | v2.5.0 |

## Roadmap v3

- Import automatique depuis métadonnées fichier audio
- Lecteur audio intégré (Web Audio API)
- Timeline visuelle des sessions par projet
- Synchronisation multi-machines (réseau local)

---

*Projet personnel — Olivier, Scaër, Bretagne — 2026*  
*La machine ne ment pas. Elle déforme.*
