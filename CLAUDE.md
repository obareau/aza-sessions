# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Projet

App Flask + SQLite de documentation de sessions musicales pour l'univers de fiction **AZA** (dystopie personnelle d'Olivier — Dark Ambient / Industriel, Scaër, Bretagne). Déployée sur Fly.io à `https://robotariis-sessions.fly.dev/`.

Version actuelle : voir `VERSION` dans `app.py` (actuellement **v3.6.1**).

---

## Commandes

```bash
python app.py          # Lancement local — port auto-détecté à partir de 5001
```

Linter : **ruff** (config dans `ruff.toml`).

```bash
.venv/bin/ruff check .        # vérifier
.venv/bin/ruff check --fix .  # corriger automatiquement
```

Tests : **pytest** (smoke tests routes + DB).

```bash
.venv/bin/pytest tests/ -v    # lancer la suite de tests
```

---

## Architecture

### Vue d'ensemble

`app.py` (116 lignes) est le point d'entrée minimal : il crée l'app Flask, enregistre les 18 blueprints, injecte les globals Jinja2 (`has_live`, `obsidian_vault`) et gère le backup automatique de `sessions.db` au démarrage (5 derniers backups dans `backups/`).

`wsgi.py` est le point d'entrée Gunicorn/Fly.io — il appelle `init_db()` explicitement car `app.py.__main__` ne tourne pas sous Gunicorn.

### Blueprints (pattern uniforme)

Chaque module suit le même pattern :
```
<module>/
  __init__.py    # exporte `bp`
  api.py         # Blueprint Flask + toutes les routes
  engine.py      # classe XxxEngine(db_path) — toute la logique SQL
```

Dans `api.py`, l'accès au moteur se fait via un helper `_engine()` :
```python
def _engine():
    return XxxEngine(current_app.config["DB_PATH"])
```

Les 18 blueprints enregistrés :

| Blueprint | Domaine |
|---|---|
| `sessions` | CRUD sessions + export MD/CSV/Obsidian — **module principal** |
| `live` | Mode session en cours (timer live, notes temps réel) |
| `patcher` | Éditeur de patch SVG drag&drop (nœuds, connexions audio/MIDI/CV) — minimap, snap-to-grid, connexions multi-type, duplication layout |
| `sysex` | Loader SysEx DX7/Volca FM via Web MIDI API, bank editor |
| `spark` | Générateur de contraintes créatives |
| `catalogue` | Catalogue matériel (machine, effet, daw, synth_ios, plugin) |
| `obliques` | Stratégies Obliques AZA (style Brian Eno) |
| `influences` | Artistes et labels de référence |
| `projects` | Regroupement de sessions sous un projet |
| `stats` | Dashboard statistiques Chart.js |
| `samples` | Bibliothèque de sample banks |
| `tracks` | Morceaux inspirants |
| `wishlist` | Liste de matériel désiré |
| `inspirations` | Inspirations diverses (phrases, images, concepts) |
| `mirack` | Catalogue de modules MiRack (iOS) |
| `settings_app` | Paramètres app (backup, import, reset) |
| `about` | Page À propos |
| `dim` | Module audio spécialisé |

### Core

- `core/db.py` — `get_db(db_path)` : connexion SQLite avec `row_factory = sqlite3.Row`
- `core/init_db.py` — `init_db(db_path)` : crée toutes les tables si inexistantes, peuple les données par défaut (obliques, catalogue, influences), applique les migrations via `ALTER TABLE ... ADD COLUMN` dans un `try/except`
- `core/constants.py` — enums partagés : `CHARACTERS`, `MODES`, `INTENTIONS`, `ITEM_TYPES`, `SAMPLE_TYPES`, etc.
- `core/oblique.py` — `rand_oblique(db_path)` : stratégie aléatoire depuis la table `obliques`
- `core/ollama_client.py` — génération du `recap_claude` via `qwen3.5:latest` sur Ollama local (`192.168.1.100`) ; appelé depuis `/new?from_live=1` ; silencieux si indisponible
- `core/whisper_client.py` — transcription audio via Whisper GPU local (port 9000, modèle `small`) ; appelé depuis `/live/transcribe` (POST multipart) ; silencieux si indisponible

### Base de données

15 tables SQLite, toutes créées dans `init_db()`. Tables principales :

- `sessions` — 31 champs dont `recap_claude` (résumé IA généré par Ollama), `project_id` (FK), `title`
- `live_session` — session en cours (0 ou 1 ligne) — supporte dictée vocale Whisper via `/live/transcribe`
- `patch_layouts` / `patch_nodes` / `patch_connections` — module Patcher
- `sysex_banks` — banks SysEx (BLOB SQLite)
- `catalogue`, `influences`, `obliques`, `projects`, `sample_banks`, `inspiring_tracks`, `gear_wishlist`, `inspirations`, `mirack_modules`, `prompter_scripts`

Migrations : toujours via `ALTER TABLE` dans `init_db()` avec `try/except` — pas de système de migration versionné.

### Config

`config.json` (non commité) — stocke `obsidian_vault` (chemin du vault Obsidian local). Créé/lu par `sessions/api.py` via `_get_config()` / `_save_config()`.

### Templates

Tous héritent de `base.html`. Système de thèmes via attribut `data-theme` sur `<html>` (6 thèmes terminal). Variables CSS : `var(--accent)`, `var(--mono)`, `var(--bg)`, etc. — pas de framework CSS externe.

Multi-sélection dans les formulaires : `form.getlist("machines")` → jointure `, ` avant stockage.

### Déploiement — Roblab (serveur bare metal)

- **URL publique** : `https://sessions.robotariis.com` via Cloudflare Tunnel
- **URL locale** : `http://sessions.lan`
- **Service** : `systemd` — `aza-sessions.service`
- **Process** : Gunicorn, port `5001`, 1 worker
- **DB** : `/home/olivier/DEV/aza-sessions/sessions.db`
- **venv** : `/home/olivier/DEV/aza-sessions/.venv`

```bash
# Déployer une mise à jour
cd /home/olivier/DEV/aza-sessions && git pull && sudo systemctl restart aza-sessions

# Logs
journalctl -u aza-sessions -f
```

---

## Règles avant tout commit

1. Bumper `VERSION` dans `app.py`
2. Mettre à jour `CHANGELOG.md`
3. Vérifier que `sessions.db` n'est pas dans le commit (`.gitignore`)
4. Après `git push` : `ssh roblab 'cd /home/olivier/DEV/aza-sessions && git pull && sudo systemctl restart aza-sessions'`

---

## Contexte AZA

Univers de fiction dystopique personnel. Chaque session peut correspondre à un élément du lore (scène, lieu, ambiance de la B.O.). Le champ `lore_link` d'une session pointe vers le vault Obsidian. Les stratégies Obliques AZA sont inspirées des Oblique Strategies de Brian Eno. Style musical : Dark Ambient / Industriel — tradition PanSonic, Vromb, Synapscape, Hands Productions, Ant-Zen.
