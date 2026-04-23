# Journal de Sessions Robōtariis

> Application locale de documentation des sessions musicales pour le projet **Robōtariis** — univers de fiction dystopique dont la musique constitue la bande originale.

**Version actuelle : v0.9.7-alpha**

---

## À propos

**Journal de Sessions Robōtariis** est un outil personnel de reporting musical — une sorte de carnet de bord numérique pour documenter chaque session de création sonore en temps réel.

L'application est pensée pour un usage **100 % local** : pas de cloud, pas de compte, pas de connexion requise. Les données restent dans un fichier SQLite sur ta machine.

### Le projet Robōtariis

Robōtariis est un univers de fiction dystopique personnel — les sessions documentées ici constituent la bande originale de cet univers. Chaque enregistrement peut correspondre à une scène, un lieu, une ambiance particulière du lore.

Style musical visé : **Dark Ambient / Industriel** — dans la tradition de PanSonic, Vromb, Synapscape, avec une affinité pour les labels Hands Productions et Ant-Zen.

Les **Stratégies Obliques Robōtariis** — inspirées des *Oblique Strategies* de Brian Eno — apparaissent aléatoirement pour guider et contraindre la création.

---

## Stack technique

| Composant | Technologie |
|---|---|
| Backend | Python 3 / Flask |
| Base de données | SQLite (`sessions.db`) |
| Templates | Jinja2 |
| CSS | Vanilla — zéro framework |
| Graphiques | Chart.js |
| Typographie | IBM Plex Mono / IBM Plex Sans |

---

## Lancement

**Installation des dépendances :**
```bash
pip install -r requirements.txt
```

**Lancement de l'application :**
```bash
python3 app.py
```

L'application détecte automatiquement un port libre à partir de 5001 et affiche l'URL complète dans le terminal (exemple : `http://localhost:5001`).

**Remarque :** L'application fonctionne uniquement en local sur votre machine. Ouvrez l'URL affichée dans votre navigateur web pour accéder à l'interface.

---

## Fonctionnalités

### Sessions
- Créer, consulter, éditer, supprimer une session
- Copier le setup d'une session existante pour en créer une nouvelle
- Liaison entre sessions (session parente/enfant)
- Export Markdown individuel ou global (compatible Obsidian)

### Organisation
- **Projets** — regrouper plusieurs sessions sous un titre, avec couleur et description
- **Tags** — libres, cliquables dans la liste pour filtrer
- **Filtres** — recherche texte, mode, note en temps réel

### Catalogue & Références
- **Catalogue** — gérer le matériel : machines hardware, effets, DAW, synthés iOS, plugins VST/AU
- **Influences** — artistes et labels de référence par session
- **Stratégies Obliques Robōtariis** — inspiration créative aléatoire (style Oblique Strategies)

### Statistiques
- Dashboard interactif Chart.js : machines, influences, notes, énergie, modes, timeline mensuelle
- Taux de sessions à retravailler / potentiel release

### Paramètres
- **Backup** — télécharger la base courante en `.db` horodaté
- **Import** — fusionner une ancienne base SQLite (doublons ignorés)
- **Reset** — vider les sessions (conserve catalogue, influences, obliques)

### Interface
- **Thème sombre** — toggle ◐ dans le header, persisté entre les pages
- **Widget Pomodoro** — chronomètre flottant (25/5/15 min), persistant entre les pages
- **Auto-save** — brouillon sauvegardé automatiquement dans le navigateur, restaurable

---

## Structure du projet

```
app.py                      # Application principale — routes, DB, logique
templates/
  base.html                 # Layout commun — nav, CSS, Pomodoro, dark mode
  index.html                # Liste des sessions (filtres, tags cliquables)
  new.html                  # Formulaire nouvelle session (prefill depuis existante)
  edit.html                 # Édition session
  view.html                 # Détail session
  stats.html                # Dashboard statistiques Chart.js
  catalogue.html            # Gestion catalogue matériel
  influences.html           # Gestion influences
  obliques.html             # Gestion stratégies Obliques
  settings.html             # Paramètres — import/backup/reset DB
  projects.html             # Liste des projets
  project_detail.html       # Détail projet — sessions liées
static/                     # Assets statiques
requirements.txt            # flask>=3.0.0
CHANGELOG.md                # Historique des versions
sessions.db                 # Base de données SQLite — NON VERSIONNÉ
```

---

## Base de données

Quatre tables SQLite :

| Table | Description |
|---|---|
| `sessions` | Sessions musicales — table principale (30+ champs) |
| `projects` | Projets — regroupement de sessions |
| `catalogue` | Matériel : machine, effet, daw, synth_ios, plugin |
| `influences` | Artistes et labels : artiste, label, autre |
| `obliques` | Stratégies créatives éditables |

La base est migrée automatiquement au démarrage — les anciennes versions sont compatibles.

---

## Backup & Migration

```bash
# Backup manuel
cp sessions.db sessions_backup_$(date +%Y%m%d).db

# Ou depuis l'interface : Paramètres → ↓ Télécharger la base
```

Pour importer une ancienne base : **Paramètres → Importer une ancienne base** — la fusion est intelligente (doublons ignorés, colonnes manquantes gérées).

---

## Roadmap

### v0.7.0 — À venir
- Export direct vers vault Obsidian
- Vue calendrier des sessions
- Pagination sur la liste (au-delà de 50 sessions)
- Recherche par plage de dates

### Future
- Synchronisation réseau local multi-machines
- Import automatique depuis métadonnées fichier audio
- Tags liés aux notes du vault Robōtariis

---

## Historique rapide

| Version | Date | Highlights |
|---|---|---|
| v0.6.0-alpha | 2026-04-20 | Suppression, projets, copie setup, tags cliquables, dark mode |
| v0.5.4-alpha | 2026-04-20 | Page Paramètres — import DB, backup, reset |
| v0.5.3-alpha | 2026-04-20 | Fix stats, Pomodoro persistant, auto-save formulaires |
| v0.5.2-alpha | 2026-04-20 | Filtres sessions, liaison entre sessions |
| v0.5.1-alpha | 2026-04-20 | Widget Pomodoro, bannière terminal, port auto |
| v0.4.0 | 2026-04-20 | Édition de sessions |
| v0.3.1 | 2026-04-20 | Initial — Flask complet, stats, export Markdown |

→ Voir [CHANGELOG.md](CHANGELOG.md) pour le détail complet.

---

*Projet personnel — Olivier, Scaër, Bretagne — 2026*
