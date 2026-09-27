# Graph Report - aza-sessions  (2026-09-27)

## Corpus Check
- 79 files · ~70,413 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 760 nodes · 1251 edges · 68 communities (57 shown, 11 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `b6f1c67c`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 23|Community 23]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 25|Community 25]]
- [[_COMMUNITY_Community 26|Community 26]]
- [[_COMMUNITY_Community 27|Community 27]]
- [[_COMMUNITY_Community 28|Community 28]]
- [[_COMMUNITY_Community 29|Community 29]]
- [[_COMMUNITY_Community 30|Community 30]]
- [[_COMMUNITY_Community 31|Community 31]]
- [[_COMMUNITY_Community 32|Community 32]]
- [[_COMMUNITY_Community 33|Community 33]]
- [[_COMMUNITY_Community 34|Community 34]]
- [[_COMMUNITY_Community 35|Community 35]]
- [[_COMMUNITY_Community 36|Community 36]]
- [[_COMMUNITY_Community 37|Community 37]]
- [[_COMMUNITY_Community 38|Community 38]]
- [[_COMMUNITY_Community 39|Community 39]]
- [[_COMMUNITY_Community 40|Community 40]]
- [[_COMMUNITY_Community 41|Community 41]]
- [[_COMMUNITY_Community 42|Community 42]]
- [[_COMMUNITY_Community 43|Community 43]]
- [[_COMMUNITY_Community 44|Community 44]]
- [[_COMMUNITY_Community 45|Community 45]]
- [[_COMMUNITY_Community 46|Community 46]]
- [[_COMMUNITY_Community 47|Community 47]]
- [[_COMMUNITY_Community 48|Community 48]]
- [[_COMMUNITY_Community 49|Community 49]]
- [[_COMMUNITY_Community 50|Community 50]]
- [[_COMMUNITY_Community 51|Community 51]]
- [[_COMMUNITY_Community 52|Community 52]]
- [[_COMMUNITY_Community 53|Community 53]]
- [[_COMMUNITY_Community 54|Community 54]]
- [[_COMMUNITY_Community 55|Community 55]]
- [[_COMMUNITY_Community 56|Community 56]]
- [[_COMMUNITY_Community 57|Community 57]]
- [[_COMMUNITY_Community 58|Community 58]]
- [[_COMMUNITY_Community 59|Community 59]]
- [[_COMMUNITY_Community 60|Community 60]]
- [[_COMMUNITY_Community 61|Community 61]]
- [[_COMMUNITY_Community 62|Community 62]]
- [[_COMMUNITY_Community 63|Community 63]]
- [[_COMMUNITY_Community 64|Community 64]]
- [[_COMMUNITY_Community 65|Community 65]]

## God Nodes (most connected - your core abstractions)
1. `get_db()` - 82 edges
2. `CHANGELOG — Journal de Sessions AZA` - 51 edges
3. `CatalogueEngine` - 35 edges
4. `SessionsEngine` - 35 edges
5. `GearNotebookEngine` - 28 edges
6. `rand_oblique()` - 27 edges
7. `PatcherEngine` - 20 edges
8. `_engine()` - 17 edges
9. `_engine()` - 13 edges
10. `_version()` - 13 edges

## Surprising Connections (you probably didn't know these)
- `sid()` --calls--> `get_db()`  [EXTRACTED]
  tests/test_session_recap.py → core/db.py
- `manage_catalogue()` --calls--> `rand_oblique()`  [EXTRACTED]
  catalogue/api.py → core/oblique.py
- `fiches()` --calls--> `rand_oblique()`  [EXTRACTED]
  catalogue/api.py → core/oblique.py
- `gear_notebook()` --calls--> `rand_oblique()`  [EXTRACTED]
  catalogue/api.py → core/oblique.py
- `quick_session()` --calls--> `CatalogueEngine`  [EXTRACTED]
  sessions/api.py → catalogue/engine.py

## Import Cycles
- None detected.

## Communities (68 total, 11 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.06
Nodes (33): get_db(), rand_oblique(), _engine(), manage_influences(), InfluencesEngine, _engine(), get_oblique(), manage_obliques() (+25 more)

### Community 1 - "Community 1"
Cohesion: 0.06
Nodes (37): Écrit le seul champ recap_claude — pas un update() complet.          Passer par, session_to_md(), SessionsEngine, _cleanup(), Tests de la saisie minimale — /vite., Le champ libre complète les puces au lieu de les écraser., Sans puce cochée, le champ libre suffit — pas de virgule en tête., La page s'ouvre et ne demande qu'une chose. (+29 more)

### Community 2 - "Community 2"
Cohesion: 0.13
Nodes (30): generate_recap(), review_diff(), delete_session(), edit_session(), _engine(), export_all(), export_csv(), export_obsidian() (+22 more)

### Community 3 - "Community 3"
Cohesion: 0.06
Nodes (33): Tests Phase 1 — catalogue : favoris, types dédiés, saisie rapide multi-lignes., purpose et intent doivent exister sur catalogue après init_db()., La colonne favorite doit exister sur catalogue après init_db()., update_fiches renseigne les trois champs et ignore les lignes inchangées., Un id inexistant ou illisible ne fait pas échouer l'enregistrement., GET /catalogue/fiches affiche la table, POST enregistre les lignes., Les deux champs se relisent depuis le carnet de la fiche., Les types dédiés ipad et zynthian doivent être déclarés. (+25 more)

### Community 4 - "Community 4"
Cohesion: 0.07
Nodes (28): Ajouts, Ajouts, Ajouts, Ajouts, Ajouts, Ajouts, Ajouts, Ajouts (+20 more)

### Community 5 - "Community 5"
Cohesion: 0.10
Nodes (20): _get_config(), health(), inject_globals(), Sonde de santé — décision d'écosystème `health-endpoint` (Argus).      ⚠️ Vérifi, backup_db(), Sauvegarde automatique de la base — appelée au démarrage, local ET Gunicorn., Copie cohérente via l'API backup de SQLite.      Pas un shutil.copy2 : sous Guni, Snapshot horodaté de db_path dans backups_dir, rétention des `keep` derniers. (+12 more)

### Community 6 - "Community 6"
Cohesion: 0.12
Nodes (9): CatalogueEngine, Toutes les fiches, à plat, pour la vue table.          À plat et non groupé : la, Crée une fiche complète depuis la vue table.          Retourne l'id créé, ou Non, Retourne tous les items groupés par type — types libres inclus., Enregistre la table d'un coup. rows = [{id, manufacturer, purpose, intent}]., Retourne tous les types distincts présents dans la DB (pour datalist)., Les sessions où cette fiche a joué.          Rien à saisir : l'information est d, Ajout rapide inline — retourne le dict du nouvel item ou None si doublon. (+1 more)

### Community 7 - "Community 7"
Cohesion: 0.12
Nodes (9): PatcherEngine, Importe les machines/FX/DAW/iOS/plugins d'une session comme nœuds., Importe tous les items actifs du catalogue comme nœuds., Sauvegarde complète nœuds + connexions depuis le front (JSON).         Gère les, Retourne tous les types distincts présents dans la table catalogue., Retourne tous les items actifs du catalogue, groupés par type., Génère les champs de session (machines, effects, daws…) depuis un layout., Calcule le texte de routing signal depuis le graphe de connexions. (+1 more)

### Community 8 - "Community 8"
Cohesion: 0.08
Nodes (23): gear(), Tests du carnet d'instrument — patches, associations, remarques., La page du carnet répond 200 et porte ses trois sections., Une fiche inexistante redirige vers le catalogue, pas une 500., La fiche retrouve les sessions qui la mentionnent — sans saisie., Deux fiches catalogue distinctes, propres à chaque test., Une fiche citée en effet, pas en machine, est trouvée quand même., gear_pairings et gear_notes doivent exister après init_db(). (+15 more)

### Community 9 - "Community 9"
Cohesion: 0.16
Nodes (10): transcribe(), _engine(), live(), live_abandon(), live_finish(), live_save(), live_start(), live_transcribe() (+2 more)

### Community 10 - "Community 10"
Cohesion: 0.10
Nodes (12): GearNotebookEngine, Carnet par instrument — ce qu'on apprend d'une machine à force de s'en servir., Patches notés pour cette machine, les mieux notés d'abord., Associations, vues des DEUX côtés.          Une association est stockée une fois, Retourne True si ajoutée, False si doublon ou association à soi-même., Fiches associables — tout le catalogue actif sauf soi-même., La liste des fiches associables ne se propose pas elle-même., « NBTestSynth » ne doit pas remonter sur « NBTestSynthesizer ».      Un LIKE seu (+4 more)

### Community 11 - "Community 11"
Cohesion: 0.10
Nodes (20): Base de données, Catalogue & Références, Ce que c'est, Démarrage rapide, Déploiement Fly.io, Ergonomie, Fonctionnalités, Journal de Sessions AZA (+12 more)

### Community 12 - "Community 12"
Cohesion: 0.21
Nodes (9): _catalogue_and_influences(), _engine(), preset_create(), preset_delete(), preset_edit(), presets_list(), presets_stats(), _version() (+1 more)

### Community 13 - "Community 13"
Cohesion: 0.18
Nodes (17): _engine(), patcher_delete(), patcher_duplicate(), patcher_export_mermaid(), patcher_import(), patcher_import_json(), patcher_list(), patcher_new() (+9 more)

### Community 14 - "Community 14"
Cohesion: 0.19
Nodes (8): delete_project(), edit_project(), _engine(), list_projects(), new_project(), _version(), view_project(), ProjectsEngine

### Community 15 - "Community 15"
Cohesion: 0.17
Nodes (8): _engine(), settings(), settings_backup(), settings_import(), settings_reset_sessions(), _version(), Merge sessions from tmp_path into main DB. Returns (imported, skipped, total, er, SettingsEngine

### Community 16 - "Community 16"
Cohesion: 0.18
Nodes (9): _engine(), spark(), spark_focus(), SparkEngine, _add_idea(), Tests Phase 3 — idées en vrac (type 'Idée') et intégration SPARK., test_focus_can_return_idea(), test_focus_dedup_excludes_seen_idea() (+1 more)

### Community 17 - "Community 17"
Cohesion: 0.13
Nodes (13): Architecture, Base de données, Blueprints (pattern uniforme), Commandes, Config, Contexte AZA, Core, Déploiement — Roblab (serveur bare metal) (+5 more)

### Community 18 - "Community 18"
Cohesion: 0.22
Nodes (4): _engine(), manage_mirack(), _version(), MirackEngine

### Community 19 - "Community 19"
Cohesion: 0.14
Nodes (13): ✅ Ableton Link — axe CLOS, migré vers D.I.M *(2026-08-08)*, Demandes externes (Argus), ✅ Déjà livré (v1.x → v3.18.2), 💡 Idées en vrac, 🎨 Interface & UX — Backlog, 🗺 Plan v3.x, ROADMAP — Journal de Sessions AZA, 🛠 Tech & Qualité — Backlog (+5 more)

### Community 20 - "Community 20"
Cohesion: 0.23
Nodes (4): _engine(), manage_wishlist(), _version(), WishlistEngine

### Community 21 - "Community 21"
Cohesion: 0.23
Nodes (11): api_catalogue_add(), _engine(), fiches(), fiches_print(), gear_notebook(), manage_catalogue(), _notebook(), Version papier de la vue table — A4 paysage, groupée par type.      Reprend les (+3 more)

### Community 22 - "Community 22"
Cohesion: 0.24
Nodes (4): _engine(), manage_inspirations(), _version(), InspirationsEngine

### Community 23 - "Community 23"
Cohesion: 0.24
Nodes (4): _engine(), manage_samples(), _version(), SamplesEngine

### Community 24 - "Community 24"
Cohesion: 0.24
Nodes (4): _engine(), manage_tracks(), _version(), TracksEngine

### Community 25 - "Community 25"
Cohesion: 0.29
Nodes (10): _db(), SysEx Loader — envoi SysEx DX7/Volca FM via Web MIDI API., Retourne les bytes SysEx en JSON pour envoi MIDI côté client., sysex_data(), sysex_delete(), sysex_download(), sysex_editor(), sysex_index() (+2 more)

### Community 26 - "Community 26"
Cohesion: 0.20
Nodes (9): Smoke tests — vérifie que les routes principales répondent sans crasher., Chaque route doit répondre 200 ou 302 (redirect) — pas de 500., La page d'accueil doit contenir le mot 'session' (insensible à la casse)., Le formulaire /new doit contenir un champ date., La page /about doit contenir 'AZA' ou 'about' (insensible à la casse)., test_about_html(), test_index_html(), test_new_form_html() (+1 more)

### Community 28 - "Community 28"
Cohesion: 0.29
Nodes (7): 🐛 Corrections majeures, ☁️ Déploiement cloud Fly.io, 📄 Formulaire PDF papier (mode dégradé), 📱 Mobile, ⬡ Prompteur Dawless — module complet, 🏷️ Titres de session, v2.0.0 — 2026-05-01 — Release majeure

### Community 29 - "Community 29"
Cohesion: 0.33
Nodes (3): _invert(), Matériel proposé en un clic sur la saisie rapide.          Ordre : favoris d'abo, Clé de tri décroissante sur une date ISO, sans reverse global.

### Community 30 - "Community 30"
Cohesion: 0.33
Nodes (6): 🗃 Base, 🔧 Détail, ✨ Nouveautés, ⚠️ Pourquoi deux champs et pas un, ✅ Tests, v3.18.0 — 2026-09-08 — Fiches matériel : ce que c'est, ce que j'en fais

### Community 31 - "Community 31"
Cohesion: 0.47
Nodes (5): notify(), ollama_async(), _post(), Envoie une notification ntfy via n8n., Lance une génération Ollama en arrière-plan — résultat envoyé via ntfy.

### Community 32 - "Community 32"
Cohesion: 0.50
Nodes (4): 🐛 Corrections, 🛠 Infra & Qualité, ✨ Nouveautés, v3.6.0 — 2026-05-16 — Responsive + FTS5 + Infra Roblab

### Community 33 - "Community 33"
Cohesion: 0.50
Nodes (4): ♻️ DB, 🛡 Garde-fous, ✨ Nouveautés, v3.13.0 — 2026-08-29 — Carnet d'instrument

### Community 34 - "Community 34"
Cohesion: 0.50
Nodes (4): 🔧 Détail, ✨ Nouveautés, ✅ Tests, v3.18.2 — 2026-09-08 — Ajouter du matériel sans quitter la table

### Community 35 - "Community 35"
Cohesion: 0.50
Nodes (4): 🐛 Le fond du problème, ✨ Nouveautés, v3.14.0 — 2026-08-29 — Le récap enfin atteignable, 🛡 Échec bruyant

### Community 36 - "Community 36"
Cohesion: 0.50
Nodes (4): ✨ Nouveautés, v3.11.0 — 2026-08-08 — Ableton Link : le Prompteur sur la grille, 🧪 Validé contre un Ableton Live distant, ⚠️ À savoir

### Community 37 - "Community 37"
Cohesion: 0.67
Nodes (3): Ajouts, Corrections, v0.5.3-alpha — 2026-04-20

### Community 38 - "Community 38"
Cohesion: 0.67
Nodes (3): ✨ Améliorations, 🐛 Corrections, v2.0.1 — 2026-05-01 — Hotfix UI

### Community 39 - "Community 39"
Cohesion: 0.67
Nodes (3): ♻️ Architecture, ✨ Nouveautés, v3.0.0-alpha — 2026-05-09 — Module Patcher + finalisation architecture

### Community 40 - "Community 40"
Cohesion: 0.67
Nodes (3): ⚠️ Choix de conception, ✨ Nouveautés, v3.15.0 — 2026-08-29 — ⚡ Vite : saisie minimale

### Community 41 - "Community 41"
Cohesion: 0.67
Nodes (3): ✨ Comportement inchangé — zéro régression UI, ♻️ Refactorisation architecture, v2.1.0 — 2026-05-03 — Architecture modulaire (Blueprints)

### Community 42 - "Community 42"
Cohesion: 0.67
Nodes (3): ✨ Comportement inchangé — zéro régression UI (16/16 routes OK), ♻️ Extraction des modules restants, v2.4.0 — 2026-05-09 — Refactorisation complète en Blueprints

### Community 43 - "Community 43"
Cohesion: 0.67
Nodes (3): 🐛 Correctifs, ♻️ Refactor, v3.12.1 — 2026-08-29 — Durcissement de la sauvegarde automatique

### Community 44 - "Community 44"
Cohesion: 0.67
Nodes (3): 🐛 Corrections, ✨ Nouveautés, v3.7.2 — 2026-06-03 — Spark : contrainte unique + fix DIM

### Community 45 - "Community 45"
Cohesion: 0.67
Nodes (3): 🐛 Corrections, ✨ Nouveautés, v3.1.0 — 2026-05-09 — Release Patcher complète

### Community 46 - "Community 46"
Cohesion: 0.67
Nodes (3): 🐛 Corrections, ✨ Nouveautés, v2.5.0 — 2026-05-05 — Release finale v2.x

### Community 47 - "Community 47"
Cohesion: 0.67
Nodes (3): 🐛 Corrections / migrations, ✨ Nouveautés, v3.0.1-alpha — 2026-05-09 — Patcher : import/export JSON + types dynamiques

### Community 48 - "Community 48"
Cohesion: 0.67
Nodes (3): ♻️ DB, ✨ Nouveautés, v3.2.0 — 2026-05-09 — Module SysEx Loader & Bank Editor

### Community 49 - "Community 49"
Cohesion: 0.67
Nodes (3): 🛠 Infra & Qualité, ✨ Nouveautés, v3.9.0 — 2026-06-27 — Sessions typées : musique / lore / veille & code

### Community 50 - "Community 50"
Cohesion: 0.67
Nodes (3): 🛠 Infra & Qualité, ✨ Nouveautés, v3.8.0 — 2026-06-27 — Catalogue : saisie rapide, favoris & types dédiés

### Community 51 - "Community 51"
Cohesion: 0.67
Nodes (3): ✨ Le carnet d'instrument se remplit tout seul, 🧩 Le formulaire complet ne fait plus mur, v3.16.0 — 2026-08-29 — Le carnet lit les sessions, le formulaire se replie

### Community 52 - "Community 52"
Cohesion: 0.67
Nodes (3): ✨ Nouveautés, ✅ Tests, v3.18.1 — 2026-09-08 — Les fiches sur papier

### Community 53 - "Community 53"
Cohesion: 0.67
Nodes (3): ✨ Nouveautés, 🛠 Qualité, v3.10.0 — 2026-06-27 — Idées en vrac & SPARK

### Community 54 - "Community 54"
Cohesion: 0.67
Nodes (3): ✨ Nouveautés, 🛠 Qualité, v3.7.1 — 2026-05-23 — Vue compacte + tests

### Community 55 - "Community 55"
Cohesion: 0.67
Nodes (3): ✨ Nouveautés, ⚠️ Pourquoi ça compte plus que le confort, v3.17.0 — 2026-08-29 — Puces matériel sur /vite : la boucle se ferme

## Knowledge Gaps
- **128 isolated node(s):** `✨ Nouveautés`, `🔧 Détail`, `✅ Tests`, `✨ Nouveautés`, `✅ Tests` (+123 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **11 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `get_db()` connect `Community 0` to `Community 1`, `Community 2`, `Community 3`, `Community 5`, `Community 6`, `Community 7`, `Community 8`, `Community 9`, `Community 10`, `Community 12`, `Community 14`, `Community 15`, `Community 16`, `Community 18`, `Community 20`, `Community 22`, `Community 23`, `Community 24`, `Community 25`, `Community 27`, `Community 29`?**
  _High betweenness centrality (0.355) - this node is a cross-community bridge._
- **Why does `rand_oblique()` connect `Community 0` to `Community 2`, `Community 21`?**
  _High betweenness centrality (0.041) - this node is a cross-community bridge._
- **Why does `CHANGELOG — Journal de Sessions AZA` connect `Community 4` to `Community 28`, `Community 30`, `Community 32`, `Community 33`, `Community 34`, `Community 35`, `Community 36`, `Community 37`, `Community 38`, `Community 39`, `Community 40`, `Community 41`, `Community 42`, `Community 43`, `Community 44`, `Community 45`, `Community 46`, `Community 47`, `Community 48`, `Community 49`, `Community 50`, `Community 51`, `Community 52`, `Community 53`, `Community 54`, `Community 55`, `Community 56`, `Community 57`, `Community 58`, `Community 59`, `Community 60`, `Community 61`, `Community 62`, `Community 63`, `Community 64`, `Community 65`?**
  _High betweenness centrality (0.032) - this node is a cross-community bridge._
- **What connects `Sonde de santé — décision d'écosystème `health-endpoint` (Argus).      ⚠️ Vérifi`, `Vue table — fabricant, à quoi ça sert, comment je compte m'en servir.      La ta`, `Version papier de la vue table — A4 paysage, groupée par type.      Reprend les` to the rest of the system?**
  _242 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.0563165905631659 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.05807622504537205 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.1349206349206349 - nodes in this community are weakly interconnected._