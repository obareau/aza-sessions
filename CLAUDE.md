# Journal de Sessions Robōtariis

App Flask + SQLite de reporting de sessions musicales pour Olivier (Scaër, Bretagne).
Fait partie du projet **Robōtariis** — univers de fiction dystopique dont la musique constitue la B.O.

## Version actuelle : v0.3.1

---

## Stack technique

- **Backend :** Python 3 / Flask
- **Base de données :** SQLite — fichier `sessions.db`
- **Frontend :** Jinja2 templates, IBM Plex Mono/Sans, Chart.js (stats interactives)
- **Port :** 5000 (localhost)
- **Lancement :** `python app.py`

---

## Structure du projet

```
app.py                  # Application principale — routes, DB, logique
templates/
  base.html             # Layout commun — nav, bannière oblique, footer
  index.html            # Liste des sessions
  new.html              # Formulaire nouvelle session
  view.html             # Détail session
  stats.html            # Dashboard statistiques Chart.js
  catalogue.html        # Gestion catalogue (machines, effets, DAW, iOS, plugins)
  influences.html       # Gestion influences (artistes, labels)
  obliques.html         # Gestion stratégies Obliques Robōtariis
static/                 # Assets statiques (vide pour l'instant)
requirements.txt        # flask>=3.0.0
lancer.command          # Script lancement Mac (double-clic)
lancer.bat              # Script lancement Windows (double-clic)
build_mac.sh            # Compilation binaire macOS via PyInstaller
build_windows.bat       # Compilation binaire Windows via PyInstaller
CHANGELOG.md            # Historique des versions
sessions.db             # Base de données SQLite — NE PAS COMMITTER
```

---

## Base de données — 4 tables

```sql
sessions    -- Sessions musicales (table principale, 29 champs)
obliques    -- Stratégies créatives éditables (style Oblique Strategies)
catalogue   -- Catalogue matériel : type IN (machine, effet, daw, synth_ios, plugin)
influences  -- Artistes et labels : type IN (artiste, label, autre)
```

---

## Routes

| Route | Méthode | Description |
|---|---|---|
| `/` | GET | Liste sessions |
| `/new` | GET/POST | Formulaire nouvelle session |
| `/session/<id>` | GET | Détail session |
| `/export/<id>` | GET | Export Markdown individuel (Obsidian) |
| `/export/all` | GET | Export Markdown global toutes sessions |
| `/stats` | GET | Dashboard statistiques interactif |
| `/catalogue` | GET/POST | Gestion catalogue |
| `/influences` | GET/POST | Gestion influences |
| `/obliques` | GET/POST | Gestion stratégies |
| `/oblique` | GET | API JSON — stratégie aléatoire |

---

## Champs d'une session (table sessions)

**Contexte :** date, duration_min, mode, intention, energy_level  
**Hardware :** machines, effects  
**Logiciels :** daws, synths_ios, plugins  
**Technique :** patches, signal_routing, microfreak_algo, tempo, tonality  
**Capture :** audio_file, timestamps, linked_session  
**Robōtariis :** influences, lore_link  
**Évaluation :** rating, tags, character, to_rework, release_potential  
**Meta :** oblique, comments, recap_claude, created_at

---

## Règles de développement

### Obligatoires avant tout commit
- Bumper `VERSION` dans `app.py`
- Mettre à jour `CHANGELOG.md`
- Lancer les tests Flask en mode test
- Vérifier que `sessions.db` n'est pas dans le commit (`.gitignore`)

### Conventions code
- Routes groupées par domaine dans `app.py` avec commentaires `# ── NOM ──`
- Fonction `session_to_md(s)` centralisée pour tous les exports Markdown
- Migrations DB via `ALTER TABLE` dans `init_db()` avec `try/except`
- `get_db()` + `conn.row_factory = sqlite3.Row` systématiquement

### Conventions templates
- Héritent tous de `base.html`
- Classes CSS en variables CSS (`var(--accent)`, `var(--mono)` etc.)
- Typographie : IBM Plex Mono pour les labels/codes, IBM Plex Sans pour le corps
- Pas de framework CSS externe — tout en vanilla CSS dans `base.html`

### .gitignore minimum
```
sessions.db
__pycache__/
*.pyc
dist/
build/
*.spec
.DS_Store
```

---

## Roadmap

### v0.4.0 — Prioritaire
- Édition d'une session existante (actuellement lecture seule)
- Filtres et recherche sur la liste (machine, tag, note, date, intention)
- Pagination (au-delà de 50 sessions)

### v0.5.0
- Liaison entre sessions (chaîne de travail sur un même morceau)
- Vue "Projet" — regrouper plusieurs sessions sous un titre
- Lien fichier audio vers Finder/Explorer

### Future
- Synchronisation réseau local multi-machines
- Export direct vers Obsidian via API MCP
- Tags liés aux notes du vault Robōtariis
- Import automatique depuis fichier audio (date, nom)

---

## Contexte projet

Ce projet appartient à l'univers **Robōtariis** — dystopie de fiction personnelle d'Olivier.
Chaque session documentée peut correspondre à un élément du lore (scène, lieu, ambiance de la B.O).
Les **stratégies Obliques Robōtariis** sont inspirées des Oblique Strategies de Brian Eno.
Le style musical visé : Dark Ambient / Industriel — tradition PanSonic, Vromb, Synapscape, labels Hands Productions et Ant-Zen.

Pour le lore complet → voir le vault Obsidian (dossier séparé).

---

*Dernière mise à jour : Avril 2026 — v0.3.1*
