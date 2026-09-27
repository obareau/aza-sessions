# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Projet

App Flask + SQLite de documentation de sessions musicales pour l'univers de fiction **AZA** (dystopie personnelle d'Olivier — Dark Ambient / Industriel, Scaër, Bretagne).

⚠️ **Plus sur Fly.io** — déploiement bare metal sur Roblab, voir « Déploiement » plus bas. `fly.toml` et la branche `FLY_APP_NAME` de `wsgi.py` ont été retirés le 2026-08-29. Le `Dockerfile` subsiste : il ne servait qu'au build Fly et n'est plus utilisé, mais il n'a rien de nuisible.

Version actuelle : voir `VERSION` dans `app.py` (**v3.25.0**).

⚠️ **`VERSION` a déjà pris deux releases de retard** (resté à 3.10.0 alors que le ROADMAP documentait v3.11.0 et v3.12.0), ce qui a fait attribuer un numéro déjà pris à une nouvelle feature le 2026-08-29. Avant de bumper, croiser `app.py`, `CHANGELOG.md` **et** `ROADMAP.md` — les trois divergent facilement.

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

`app.py` (144 lignes) est le point d'entrée minimal : il crée l'app Flask, enregistre les 19 blueprints et injecte les globals Jinja2 (`has_live`, `obsidian_vault`).

`wsgi.py` est le point d'entrée Gunicorn — il appelle `init_db()` **et** `backup_db()` explicitement, car `app.py.__main__` ne tourne pas sous Gunicorn. C'est le chemin réel en production ; le bloc `__main__` ne sert qu'au lancement local.

La sauvegarde vit dans `core/backup.py`, appelée des deux côtés (5 derniers backups dans `backups/`). Elle **saute le snapshot si la base est inchangée** : le service tourne en `Restart=always`, et sans ce saut un crash-loop éviderait la rétention en cinq relances.

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

Les 19 blueprints enregistrés :

| Blueprint | Domaine |
|---|---|
| `sessions` | CRUD sessions + export MD/CSV/Obsidian — **module principal** |
| `live` | Mode session en cours (timer live, notes temps réel) |
| `patcher` | Éditeur de patch SVG drag&drop (nœuds, connexions audio/MIDI/CV) — minimap, snap-to-grid, connexions multi-type, duplication layout |
| `sysex` | Loader SysEx DX7/Volca FM via Web MIDI API, bank editor |
| `spark` | Générateur de contraintes créatives |
| `catalogue` | Catalogue matériel (machine, effet, daw, synth_ios, plugin) + **carnet par fiche** (`/catalogue/<id>`) : patches, associations, remarques + **vue table éditable** (`/catalogue/fiches`) : fabricant, `purpose`, `intent`, imprimable A4 paysage (`/catalogue/fiches/print`) |
| `presets` | Carnet de notes par preset/patch — alimente les « patches favoris » du carnet d'instrument |
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
| `lore` | **Lecture** du corpus Robōtariis (`/lore`, `/lore/timeline`, `/lore/citations`) — aucune table, voir « Lore » plus bas |

### Core

- `core/db.py` — `get_db(db_path)` : connexion SQLite avec `row_factory = sqlite3.Row`
- `core/init_db.py` — `init_db(db_path)` : crée toutes les tables si inexistantes, peuple les données par défaut (obliques, catalogue, influences), applique les migrations via `ALTER TABLE ... ADD COLUMN` dans un `try/except`
- `core/constants.py` — enums partagés : `CHARACTERS`, `MODES`, `INTENTIONS`, `ITEM_TYPES`, `SAMPLE_TYPES`, etc.
- `core/oblique.py` — `rand_oblique(db_path)` : stratégie aléatoire depuis la table `obliques`
- `core/ollama_client.py` — génération du `recap_claude` via **`qwen3.5:cloud`** (`OLLAMA_MODEL`) sur `192.168.1.100` ; second modèle `qwen2.5-coder:7b` (`CODER_MODEL`) ; appelé depuis `/new?from_live=1` ; **silencieux si indisponible**
  ⚠️ Ce silence a déjà coûté : le recap est resté mort sans que personne le voie, parce que le modèle configuré (`qwen3.5:latest`) n'existait pas. Corrigé le 2026-07-31. Réflexe — un appel LLM qui échoue sans bruit ne se verra jamais depuis l'interface : vérifier le **modèle** avant de chercher un bug dans le code.
⛔ **La dictée vocale a été retirée en v3.25.0** (2026-09-27), sur décision
d'Olivier : « ça n'a jamais marché whisper dans aza ». `core/whisper_client.py`,
la route `/live/transcribe` et le bouton 🎙 de `/live` sont supprimés.

Ne pas la reproposer sans qu'il en reparle. Pour mémoire, si la question revient :
elle exigeait **https** (`getUserMedia` n'existe qu'en contexte sécurisé) alors
que Caddy ne sert `sessions.lan` qu'en HTTP — le bouton était donc grisé au
studio, et seul `https://sessions.robotariis.com` y donnait accès. Le conteneur
`whisper` a par ailleurs disparu de la machine. Une note antérieure prétendait la
chaîne « vérifiée de bout en bout » : seul le chemin serveur → Whisper l'avait
été, jamais celui du navigateur. **« Le service répond » ne veut pas dire « la
fonctionnalité marche » — vérifier par le chemin que l'usager emprunte.**

### Base de données

19 tables SQLite, toutes créées dans `init_db()`. Tables principales :

- `sessions` — 31 champs dont `recap_claude` (résumé IA généré par Ollama), `project_id` (FK), `title`
- `live_session` — session en cours (0 ou 1 ligne)
- `patch_layouts` / `patch_nodes` / `patch_connections` — module Patcher
- `sysex_banks` — banks SysEx (BLOB SQLite)
- `catalogue`, `influences`, `obliques`, `projects`, `sample_banks`, `inspiring_tracks`, `gear_wishlist`, `inspirations`, `mirack_modules`
- `preset_notes` — carnet de presets (module `presets`)
- `gear_pairings` / `gear_notes` — carnet d'instrument. Une association est stockée **une fois** mais lue des deux côtés (`UNION` dans `GearNotebookEngine.pairings`) : la noter depuis une fiche l'affiche aussi sur l'autre.

⚠️ `prompter_scripts` **n'existe plus** — partie chez D.I.M en v3.12.0, avec le blueprint `dim/` (dossier résiduel supprimé le 2026-08-29).

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

⚠️ **Éditer un template suffit à casser le site en production, avant même le
`git pull`.** Jinja relit les templates depuis le disque à chaque requête,
alors que Gunicorn garde le code Python chargé à son dernier démarrage. Ajouter
dans un template un `url_for()` vers une route qui n'existe pas encore dans le
processus vivant lève un `BuildError` — donc une 500 — sur une page qui
marchait la seconde d'avant. Arrivé le 2026-09-08 sur `/catalogue` (bouton vers
`catalogue.fiches`). Réflexe : **une modif template + route va toujours par
paire avec un `systemctl restart`**, et le checkout de dev EST la production —
il n'y a pas de copie de travail séparée.

---

## Nom de prise Zoom R8 — décisions arrêtées

`CatalogueEngine.take_name()` fabrique le nom depuis les codes du catalogue :
`MFMG5_1` pour MicroFreak + MS-50G, première prise du jour.

⚠️ **Contraintes de la machine, vérifiées au manuel (p. 94)** : un nom de
**projet** fait **8 caractères au plus** et n'accepte que **A-Z, 0-9 et `_`**.
Le tiret est refusé — un `MFMG5-1` ne rentrerait pas dans le R8. (Les noms de
**fichier** audio, eux, tolèrent 219 caractères et le tiret ; ce n'est pas ce
qu'AZA nomme.) Au-delà de 8, **c'est le préfixe qu'on rogne, jamais le rang** :
deux prises du même après-midi au même nom seraient pires qu'un nom tronqué.

✅ **Compteur quotidien, et la collision inter-jours est ACCEPTÉE**
(décidé le 2026-09-27). Le R8 refuse deux projets de même nom, et `MF_1`
revient chaque jour — mais la carte SD est **vidée régulièrement sur un PC**,
donc deux journées ne coexistent jamais dessus. Le R8 sert à capturer des
essais, des nappes, parfois une jam ; sa gestion de fichiers ne vaut pas qu'on
torde le nommage pour elle.

⛔ **Ne pas « corriger » ce point.** Les deux alternatives ont été pesées et
écartées : compter les usages d'une chaîne (`MFMG5_7`) ajoute un chiffre sans
service rendu ici, et inscrire la date (`MF0927_1`) mange l'espace des codes
dès le deuxième appareil.

ℹ️ **Des codes de deux caractères** laissent la place à trois appareils dans
les 8 caractères ; des codes de trois s'arrêtent à deux appareils.

---

## Lore — Obsidian est la référence, AZA lit

✅ **Décidé le 2026-09-27 : aucune entité de lore n'est stockée dans AZA.** Les
lieux, factions, entités, personnages et la chronologie vivent dans le vault
Obsidian (`~/robotariis/PUBLICATIONS-QUARTZ/Lore/`, chemin réglable via la clé
`lore_path` de `config.json`), validés là-bas et publiés sur robotariis.com. Le
blueprint `lore/` les **lit** à chaque requête.

⛔ **Ne pas créer de tables `lore_places` / `lore_entities` / `lore_quotes`**, ni
de CRUD de lore, ni d'import « pour aller plus vite ». L'alternative a été pesée
et écartée : deux copies divergent dès la première correction faite d'un seul
côté, et c'est le vault qui a raison.

ℹ️ **AZA ne rend pas le Markdown, volontairement** — donc aucune dépendance de
rendu à ajouter. Le corpus est déjà lisible dans Obsidian et sur le site ; ce qui
manquait au journal, c'était de *pointer* vers le lore. Les cartes affichent
l'en-tête et renvoient au texte publié. Le frontmatter est lu à la main : le
corpus n'a que des scalaires et des listes inline.

⚠️ **La barre verticale d'un wikilink est aussi le séparateur de cellule
Markdown.** `[[cgu|C.G.U.]]` dans un tableau doit être résolu **avant** le
découpage des cellules, sinon la ligne gagne une colonne fantôme
(`lore/engine.py`, `_wikilinks()`).

---

## Règles avant tout commit

1. Bumper `VERSION` dans `app.py`
2. Mettre à jour `CHANGELOG.md`
3. Vérifier que `sessions.db` n'est pas dans le commit (`.gitignore`)
4. Après `git push` : `ssh roblab 'cd /home/olivier/DEV/aza-sessions && git pull && sudo systemctl restart aza-sessions'`

---

## Contexte AZA

Univers de fiction dystopique personnel. Chaque session peut correspondre à un élément du lore (scène, lieu, ambiance de la B.O.). Le champ `lore_link` d'une session pointe vers le vault Obsidian. Les stratégies Obliques AZA sont inspirées des Oblique Strategies de Brian Eno. Style musical : Dark Ambient / Industriel — tradition PanSonic, Vromb, Synapscape, Hands Productions, Ant-Zen.

<!-- argus:convention-session -->
## Session de travail — convention d'écosystème

**En ouvrant ce projet**, lire `ROADMAP.md` avant toute chose : il porte ce
qui reste à faire, ce qui est en cours, et — sous « Demandes externes
(Argus) » — ce que d'autres projets attendent d'ici. Commencer sans l'avoir lu
revient à redécouvrir ou refaire.

**Avant de finir**, le mettre à jour dans le même commit que le code :

- cocher `- [x]` ce qui est fait, y compris dans le bloc des demandes externes
  (cocher une demande suffit à la marquer résolue, Argus le voit au scan) ;
- ajouter ce qui a été découvert en chemin, même mal formulé — une ligne
  imprécise vaut mieux qu'un savoir perdu ;
- retirer ou requalifier ce qui n'a plus de sens.

Un roadmap qui ne suit pas le code ment deux fois : il fait croire qu'il reste
à faire ce qui est fait, et il perd ce qui a été appris. Toute la progression
mesurée par [Argus](http://argus.lan) en dépend.

⚠️ Le bloc entre `<!-- argus:begin -->` et `<!-- argus:end -->` du ROADMAP
appartient à Argus, qui le régénère depuis sa base. On y coche des cases, on
n'y écrit pas à la main.
<!-- argus:convention-session:end -->
