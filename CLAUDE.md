# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Projet

App Flask + SQLite de documentation de sessions musicales pour l'univers de fiction **AZA** (dystopie personnelle d'Olivier — Dark Ambient / Industriel, Scaër, Bretagne).

⚠️⚠️ **Roblab n'existe plus (2026-11-14).** AZA est une **app Mac native** —
`macos/`, voir « App Mac » plus bas. La base vit sur le Mac. Plus de serveur,
plus de Gunicorn ni de systemd, plus d'URL publique : `wsgi.py`, `Dockerfile`
et gunicorn sont retirés (v4.0.0). Fly.io avait déjà été abandonné le 2026-08-29.

Version actuelle : voir `VERSION` dans `app.py` (**v4.0.0**).

⚠️ **`VERSION` a déjà pris deux releases de retard** (resté à 3.10.0 alors que le ROADMAP documentait v3.11.0 et v3.12.0), ce qui a fait attribuer un numéro déjà pris à une nouvelle feature le 2026-08-29. Avant de bumper, croiser `app.py`, `CHANGELOG.md` **et** `ROADMAP.md` — les trois divergent facilement.

---

## Commandes

```bash
python app.py          # Développement — 127.0.0.1, port auto-détecté à partir de 5001
macos/build.sh         # Sur un Mac : construit AZA Sessions.app + .dmg (voir « App Mac »)
python macos/server_main.py --selftest   # visite toutes les pages dans un dossier jetable
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

`app.py` est le point d'entrée minimal : il crée l'app Flask, enregistre les 20 blueprints, crée la veille de sauvegarde (`app.extensions["aza_journal"]`) et injecte les globals Jinja2 (`has_live`, `obsidian_vault`, `backup_error`).

`demarrer_sauvegardes()` (dans `app.py`) fait `init_db()`, la copie SQLite de démarrage, une sauvegarde JSON, puis lance la veille. Elle est appelée par le bloc `__main__` **et** par `macos/server_main.py` — jamais à l'import, que les tests font.

`macos/server_main.py` est le chemin réel d'usage : le serveur embarqué dans l'app Mac (contrat stdout/SIGTERM décrit en tête du fichier).

Deux sauvegardes, qui ne se remplacent pas :
- `core/backup.py` — copie **SQLite** au démarrage, 5 gardées, à côté de la base. Saute si la base est inchangée.
- `core/journal.py` — copie **JSON** complète **à chaque modification**, dans un dossier séparé. C'est elle qui protège l'historique ; voir « Sauvegardes » plus bas.

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

Les 20 blueprints enregistrés :

| Blueprint | Domaine |
|---|---|
| `sessions` | CRUD sessions + export MD/CSV/Obsidian — **module principal** |
| `live` | Mode session en cours (timer live, notes temps réel) |
| `patcher` | Éditeur de patch SVG drag&drop (nœuds, connexions audio/MIDI/CV) — minimap, snap-to-grid, connexions multi-type, duplication layout |
| `sysex` | Loader SysEx DX7/Volca FM via Web MIDI API, bank editor |
| `spark` | Générateur de contraintes créatives |
| `catalogue` | + **façades** (`/facades`, `/catalogue/<id>/facade`) : déclaration des commandes d'un instrument et relevés de positions. Catalogue matériel (machine, effet, daw, synth_ios, plugin) + **carnet par fiche** (`/catalogue/<id>`) : patches, associations, remarques + **vue table éditable** (`/catalogue/fiches`) : fabricant, `purpose`, `intent`, imprimable A4 paysage (`/catalogue/fiches/print`) |
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
| `takes` | Registre des noms de prise saisis (`/prises`) — groupe les `audio_file` des séances et signale les noms réutilisés. **Ne lit aucun fichier** |
| `lore` | **Lecture** du corpus Robōtariis (`/lore`, `/lore/timeline`, `/lore/citations`) — aucune table, voir « Lore » plus bas |

### Core

- `core/db.py` — `get_db(db_path)` : connexion SQLite avec `row_factory = sqlite3.Row` ; `ro_uri(db_path)` : URI lecture seule **encodée** (un `#` brut dans le chemin fait ouvrir un autre fichier)
- `core/journal.py` — sauvegarde JSON : `dump_db`, `restore`, `load_file` (`.json` ou `.db`), rétention `keep_set`, veille `Journal`
- `core/init_db.py` — `init_db(db_path)` : crée toutes les tables si inexistantes, peuple les données par défaut (obliques, catalogue, influences), applique les migrations via `ALTER TABLE ... ADD COLUMN` dans un `try/except`
- `core/constants.py` — enums partagés : `CHARACTERS`, `MODES`, `INTENTIONS`, `ITEM_TYPES`, `SAMPLE_TYPES`, etc.
- `core/oblique.py` — `rand_oblique(db_path)` : stratégie aléatoire depuis la table `obliques`
- `core/ollama_client.py` — génération du `recap_claude` via **`qwen3.5:cloud`** (`OLLAMA_MODEL`) sur `192.168.1.100` ; second modèle `qwen2.5-coder:7b` (`CODER_MODEL`) ; appelé depuis `/new?from_live=1` ; **silencieux si indisponible**
  ⚠️ **À vérifier depuis la fin de Roblab** : l'adresse est en dur, et rien ne dit que la machine `192.168.1.100` existe encore.
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

- `knob_sheets` — relevés de positions de potards, par instrument. `values_json` est un objet JSON `{commande: valeur}`, et la déclaration des commandes vit dans `catalogue.controls` (texte, une par ligne).
  ℹ️ Un relevé se rattache à un patch du carnet (`preset_notes.id` dans
  `knob_sheets.preset_id`) : sur une machine sans mémoire, la façade **est** le
  patch — ne pas en faire une seconde liste parallèle.
  ⚠️ **« Pas relevé » n'est pas « à zéro ».** Une commande absente du JSON n'a pas été lue sur la façade ; un `0` stocké est un vrai réglage. Le curseur HTML perd son attribut `name` tant qu'on n'y a pas touché — sans quoi il enverrait 0 et inventerait un réglage. Ne pas « corriger » ça en mettant une valeur par défaut.

⚠️ `prompter_scripts` **n'existe plus** — partie chez D.I.M en v3.12.0, avec le blueprint `dim/` (dossier résiduel supprimé le 2026-08-29).

Migrations : toujours via `ALTER TABLE` dans `init_db()` avec `try/except` — pas de système de migration versionné.

### Config

`config.json` (non commité) — stocke `obsidian_vault` (chemin du vault Obsidian local). Créé/lu par `sessions/api.py` via `_get_config()` / `_save_config()`.

### Templates

Tous héritent de `base.html`. Système de thèmes via attribut `data-theme` sur `<html>` (6 thèmes terminal). Variables CSS : `var(--accent)`, `var(--mono)`, `var(--bg)`, etc. — pas de framework CSS externe.

Multi-sélection dans les formulaires : `form.getlist("machines")` → jointure `, ` avant stockage.

### App Mac — `macos/`

- **App** : `AZA Sessions.app` — Swift (AppKit + WKWebView, `macos/AZASessions/`) qui
  lance le serveur AZA figé par PyInstaller (`Contents/Resources/aza-server/`).
- **Cible** : macOS 12 Monterey et suivants, **Intel ET Apple Silicon** (binaire
  universel). Le MacBook Intel « instrument » plafonne à Monterey.
- **Données** :

| | |
|---|---|
| base | `~/Library/Application Support/AZA Sessions/sessions.db` (+ `config.json`, `copies-sqlite/`) |
| sauvegardes JSON | `~/Documents/AZA Sessions/Sauvegardes/` — réglable (menu Fichier, ou `defaults write com.robotariis.aza-sessions BackupDirectory …`) |
| journaux | `~/Library/Logs/AZA Sessions/` (`serveur.log`, `app.log`) |

- **Build** : `macos/build.sh` sur un Mac, avec le **Python de python.org**
  (universal2). Il vérifie chaque binaire (`scripts/verifier_binaires.py`), lance le
  `--selftest` du binaire figé, produit `.dmg` et `.zip` dans `macos/dist/`.
- **CI** (`.github/workflows/app-mac.yml`) : build sur Apple Silicon, selftest x86_64
  sous Rosetta, puis **lancement réel** de l'app (`scripts/essai_lancement.sh`) sur
  Apple Silicon et sur un runner Intel. Un tag `vX.Y.Z` publie le `.dmg` en release.
- **Non signée** par un compte développeur : au premier lancement,
  `xattr -dr com.apple.quarantine "/Applications/AZA Sessions.app"` (voir `macos/LISEZMOI.txt`).

⚠️ **Le port est FIXE (47017) et retenu.** Le `localStorage` — brouillons de `/vite`,
thème, sections repliées — est rangé par origine `http://127.0.0.1:PORT`. Un port tiré
au hasard à chaque lancement effacerait les brouillons à chaque ouverture.

⚠️ **WKWebView ne fait rien de ce qu'un navigateur offre d'office** : `confirm()`
renvoie `false` (aucun bouton « Supprimer » ne marche), `<input type=file>` ne s'ouvre
pas, les pièces jointes ne se téléchargent pas, `window.print()` est muet. Tout est
branché dans `BrowserWindowController.swift` et `ScriptBridge`. Une nouvelle page qui
use d'une API navigateur se vérifie **dans l'app**, pas dans Chrome.

⚠️ **À la fermeture, rien ne doit attendre la file principale.** AppKit peut appeler
`applicationShouldTerminate` depuis un bloc de `DispatchQueue.main` (le gestionnaire de
SIGTERM) : un `.terminateLater` dont la réponse repasse par cette file n'arrive jamais.
Vu en CI le 2026-11-14 — serveur arrêté, app bloquée pour toujours. D'où
`ServerProcess.stopAndWait()`, synchrone, qui attend la fermeture de la sortie standard
du serveur (lue sur une file à part) et écrit son journal hors du fil principal.

⚠️ **Web MIDI n'existe pas dans WebKit** : le SysEx ne peut pas envoyer depuis l'app.
Menu Aller → « Ouvrir dans le navigateur » (⇧⌘O) ouvre la page dans le navigateur par
défaut (Chrome a Web MIDI), sur le même serveur local.

⚠️ **Python de Homebrew = app cassée ailleurs.** Il ne contient qu'une architecture et
exige la version de macOS qui l'a compilé. `build.sh` refuse un Python non universel ;
pip installe MarkupSafe pour la seule architecture courante, `build.sh` le remplace par
la roue universelle.

ℹ️ Dans l'app, les templates sont **figés dans le bundle** : modifier un template ne
change rien tant qu'on n'a pas reconstruit. (L'ancien piège « éditer un template casse
la prod avant le `git pull` » a disparu avec Roblab.)

⚠️ **Un `<script>` posé dans `{% block title %}` ne tourne jamais** — il finit
dans le `<title>`. Arrivé le 2026-09-28 sur `catalogue_detail.html` : le JS des
potards n'a jamais été exécuté, et les tests Python ne l'ont pas vu parce qu'ils
postent le formulaire sans exécuter la page. Réflexe : **du JS non trivial laisse
un harnais Node derrière lui** (`tests/js/`, branché sur pytest), qui exécute le
script réellement servi par la page.

ℹ️ **Template relu à chaud, Python non** — vrai en développement (`python app.py`,
`TEMPLATES_AUTO_RELOAD`) : un `url_for()` vers une route pas encore chargée lève un
`BuildError`, donc une 500. C'était un piège de production du temps de Roblab
(2026-09-08, `/catalogue`) ; dans l'app figée il n'existe plus. Une modif template +
route se teste après avoir relancé le serveur.

---

## Sauvegardes — décisions arrêtées

✅ **Décidé le 2026-11-14**, après des pertes d'historique répétées : la base est
copiée en **JSON complet à chaque modification** (`core/journal.py`), dans un dossier
**séparé** de la base (`~/Documents/AZA Sessions/Sauvegardes` dans l'app).

⛔ **Ne pas affaiblir ces points**, chacun répond à une façon de perdre des données :

- **La veille lit `PRAGMA data_version`**, pas les routes HTTP. Une route qui écrirait
  en GET, ou une écriture faite hors Flask, serait sinon invisible.
- **Restaurer réécrit la base EN PLACE** par l'API backup de SQLite. Jamais
  `os.replace` sur `sessions.db` : une connexion ouverte continuerait d'écrire dans
  l'ancien fichier, et ses écritures disparaîtraient.
- **Pas de destruction sans filet** : restaurer, fusionner, vider écrivent d'abord une
  copie étiquetée (`avant-…`) que la rétention n'efface jamais, et **s'annulent** si
  elle échoue (`settings_app/api.py`, `_filet`).
- **Un échec de sauvegarde se voit** : bandeau sur toutes les pages
  (`backup_error`). Une sauvegarde qui échoue en silence ne vaut rien — même leçon
  que le récap Ollama.
- **Une colonne inconnue est refusée**, pas ignorée : restaurer la sauvegarde d'une
  version plus récente dans une plus ancienne perdrait des données sans le dire. La
  case « ignorer » existe, cochée en connaissance de cause.
- **La base ne va pas dans iCloud** — SQLite et la synchro de fichiers ne font pas bon
  ménage. Les sauvegardes JSON, elles, peuvent.

ℹ️ Le format est documenté en tête de `core/journal.py`. Un JSON corrigé à la main est
accepté si on retire sa ligne `"sha256"` ; sinon l'empreinte refuse un fichier abîmé.

ℹ️ Les tables qui ont existé puis disparu (`prompter_scripts`, `sessions_fts*`) sont
dans `OBSOLETE_TABLES` : une vieille base se restaure sans elles, sans bloquer.

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

ℹ️ `⚡ Proposer les codes manquants` (vue fiches, `/api/codes-proposes`) dérive
un code de chaque nom. La route **ne touche pas la base** : elle remplit les
cases, l'enregistrement du formulaire tranche. Un code déjà posé est intouchable.

✅ **Codes de 3 lettres, décidé le 2026-09-29** — « MFR » se relit six mois plus
tard, « MF » se devine. Le R8 laisse **6 caractères aux codes** (8 moins le
suffixe `_1`) : deux codes de 3 tiennent exactement, trois n'entrent pas. Les
propositions savent produire 2, 3 ou 4 lettres ; à 4, un nom à deux appareils est
rogné — c'est assumé, et l'aperçu de `/vite` le signale (`tronque`).

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

## Prises audio — saisie manuelle, pas de scan

⛔ **Ne pas proposer de scan de dossier, d'import de carte SD ni d'upload de
fichier audio.** Olivier saisit ses noms de prise **à la main** dans le champ
`audio_file` d'une séance (dit le 2026-09-28 : « je les rentre à la main »).

Une version qui dépouillait un dossier de vidage de carte a été livrée puis
retirée le jour même (v3.28.0 → v3.29.0) : elle attendait un dossier qui
n'existerait jamais. `/prises` ne fait donc que **relire les noms saisis** et
signaler ceux qui reviennent.

ℹ️ Le générateur de nom du catalogue (`take_name`) reste la bonne aide : il
*propose* le nom, c'est la frappe qui l'inscrit.

---

## Avant de jouer / après avoir joué

Trois pages se répondent, et il ne faut pas les confondre :

| Page | Quand | Quoi |
|---|---|---|
| `/ce-soir` | **avant** | tirage : instrument + traitement + oblique + titre + nom de prise |
| `/atelier` | **pendant** | feuille **vierge** à imprimer, potards en jauges à noircir au stylo |
| `/session/<id>/rappel` | **après** | la chaîne et les façades **relevées**, pour rejouer |

ℹ️ `catalogue.no_draw` écarte une fiche du **tirage** sans la désactiver : une
carte son ou un contrôleur reste utilisable en séance. Ne pas remplacer ça par
une heuristique sur les noms ou les types — le catalogue range tout en `machine`,
et c'est le geste de l'usager qui tranche.

ℹ️ `/vite` accepte `?gear=Nom1,Nom2` et `?title=` — c'est ce qui permet d'ouvrir
une séance depuis n'importe où. Une présélection d'URL **prime sur le brouillon
localStorage** : elle traduit un geste qu'on vient de faire.

⚠️ Le constat de fond (2026-09-29) : 20 modules pour 3 séances en base. Avant
d'ajouter une fonctionnalité, se demander si elle produit quelque chose **dès la
première séance** ou si elle suppose un historique qui n'existe pas.

---

## Règles avant tout commit

1. Bumper `VERSION` dans `app.py`
2. Mettre à jour `CHANGELOG.md`
3. Vérifier que `sessions.db` n'est pas dans le commit (`.gitignore`)
4. Pour mettre l'app à jour sur le Mac : `macos/build.sh`, ou pousser un tag `vX.Y.Z` (la CI publie le `.dmg`). Plus de Roblab à redémarrer.

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
