# ROADMAP — Journal de Sessions AZA

> Carte des possibles — pas un backlog, pas de deadlines.
> Mis à jour : 2026-09-08 (après release **v3.18.1**)

---

## ⏸ État du projet

⚠️⚠️ **AZA s'est RECENTRÉ le 2026-08-09** (v3.12.0) : le Prompteur et tout l'axe
Ableton Link sont partis chez D.I.M. Ce n'est pas une perte — c'est la fin d'une
confusion de périmètre. AZA est le **journal** (avant, pendant, après une
session) ; D.I.M est le **séquenceur de performance**. Le Prompteur, outil de
performance, a d'ailleurs engendré D.I.M : il l'a rejoint.

ℹ️ Livré la veille (v3.11.0) puis migré : sync tempo, affichage BPM, quantize
des cues, annonces vocales — tout éprouvé contre un Ableton Live distant avant
le déplacement.

ℹ️ Auparavant, **aucun développement entre le 2026-06-27 et le 2026-08-08** — les
commits de cette période étaient deux licences, deux fichiers Argus, une
convention de session et un correctif. Six semaines de pause, pas d'abandon.

ℹ️ **Le recap automatique a été mort sans que personne le voie.** Corrigé le
2026-07-31 (`qwen3.5:latest` → `qwen3.5:cloud`) : le modèle n'existait pas. Même
cascade que Subwave et Nemesis lors du retrait des modèles Ollama Cloud du
2026-07-15. ⚠️ Réflexe : un appel LLM qui échoue en silence ne se voit jamais
depuis l'interface — c'est le modèle qu'il faut vérifier, pas le code.

---

## ✅ Déjà livré (v1.x → v3.18.1)

| Version | Fonctionnalité |
|---|---|
| v0.3.1 | Flask complet, CRUD sessions, stats Chart.js, export Markdown/Obsidian |
| v0.5.x | Widget Pomodoro, autosave formulaires localStorage, Paramètres (backup/import/reset) |
| v0.6.0 | Suppression sessions, Projets, copie setup, tags cliquables, dark mode |
| v0.7.0 | 6 thèmes terminal, Samples, Morceaux, Wishlist, MiRack, Spark |
| v1.x   | Prompteur Dawless MVP, déploiement Fly.io |
| v2.0.0 | Prompteur complet (transport DAW, horloge, barre LED, auto/manuel, zoom, plein écran, import/export JSON/MD) |
| v2.1.0 | Architecture modulaire Blueprints Flask |
| v2.2.0 | Fabricants catalogue, ajout inline depuis formulaire session (modal AJAX), autosave brouillon pré-session |
| v2.5.0 | Pagination (25/page), lien audio → Finder, export vault Obsidian direct, correctifs Pomodoro/zoom/theme picker |
| v3.0.0-alpha | **Module Patcher** — mind map SVG drag&drop, nœuds typés/colorés, connexions audio/MIDI/CV/USB, import catalogue/session, autosave AJAX ; `app.py` → 116 lignes (`core/init_db.py`) |
| v3.1.0 | Release Patcher complète, `SECRET_KEY` pour flask.session (patcher→session prefill) |
| v3.2.0 | **Module SysEx** — loader DX7 / Volca FM via Web MIDI API + Bank Editor (patch librarian) |
| v3.3.0 | **Recap auto via Ollama** (`qwen3.5`) à la fin d'une session live — narratif style AZA, silencieux si indisponible |
| v3.4.0 | **Dictée vocale live** via Whisper GPU local (`small`, port 9000) — bouton 🎙 Dicter, route `/live/transcribe` |
| v3.5.0 | **Patcher v2 polish** — dupliquer layout, snap-to-grid (`G`), connexions multi-type, minimap (`M`) |
| v3.6.0 | **Responsive complet** (19 templates), **migration Fly.io → Roblab** (systemd/Gunicorn), linter ruff, suite pytest |
| v3.6.1 | **Réécriture recap Ollama** — bouton ✦ Réécrire sur la vue session |
| v3.7.0 | **Module Presets** — carnet de notes par preset/patch (instrument, évocation, idée, influence, ★, tags, session liée) + stats |
| v3.7.1 | **Vue compacte** (`compact.html`) + **heatmap intensités sonores** cliquable sur l'index + smoke tests 18 blueprints |
| v3.7.2 | **Spark contrainte unique** + historique (session Flask, `SEEN_MAX=8`) ; backup DB au démarrage Gunicorn (`wsgi.py`) ; `DIM_PORT` env |
| v3.8.0 | **Catalogue** — saisie rapide multi-lignes (dédup `(type, nom)`), favoris ★ remontés en tête, types dédiés `ipad` et `zynthian`, filtres et sections repliables ; messages flash centralisés dans `base.html` |
| v3.9.0 | **Sessions typées** — `music` / `lore` / `veille` : formulaire conditionnel sans rechargement, sections matériel iPad & Zynthian, filtre et badge par type, **recap Ollama avec un prompt dédié par type** (récit pour le lore, résumé factuel pour la veille) |
| v3.10.0 | **Idées en vrac** — `/inspirations` recadrée, nouveau type `Idée` ; **SPARK pioche dedans en priorité** (pondération ×2 dans le pool focus, badge dédié) |
| v3.11.0 | **Ableton Link** — pair partagé (`core/link_service.py`), `GET /api/link/state`, **affichage BPM + pastille battante** dans la topbar du Prompteur, et **quantize des cues** : l'avance automatique attend le prochain temps fort |
| v3.12.0 | ⚠️ **Le Prompteur QUITTE AZA pour D.I.M** — blueprint `dim/`, 3 templates, table `prompter_scripts` et `core/link_service.py` retirés (**−1 976 lignes**). AZA est le journal, D.I.M le séquenceur de performance : deux outils, deux moments |
| v3.12.1 | **Sauvegarde durcie** — `core/backup.py` unique (le bloc vivait en double dans `app.py` et `wsgi.py`) ; snapshot par l'API SQLite au lieu de `shutil.copy2` ; **saut si la base est inchangée**, sans quoi un crash-loop en `Restart=always` évinçait les 5 backups en cinq relances |
| v3.13.0 | **Carnet d'instrument** — `/catalogue/<id>` : patches favoris repris de `preset_notes` (qui n'avait aucune page où se montrer), associations entre fiches **lues des deux côtés**, remarques horodatées empilées. Tables `gear_pairings` et `gear_notes` |
| v3.13.1 | **Ménage Fly.io** — `fly.toml`, la branche `FLY_APP_NAME` de `wsgi.py` et le dossier vide `dim/` retirés ; README recalé (v3.5.0 → v3.13.1, lien Live vers `sessions.robotariis.com`) |
| v3.14.0 | **Récap à la demande** — `POST /session/<id>/recap` + bouton dans la vue session. Le récap n'était appelé que depuis `/new?from_live=1` : jamais atteint en pratique, `live_session` n'ayant jamais servi. Ollama muet → 502 explicite au lieu d'un succès vide |
| v3.15.0 | **⚡ Vite** — `/vite`, saisie minimale à un champ (contre 45 dans le formulaire complet), dictée Whisper, brouillon auto. Création instantanée : **pas de récap au moment de valider**, il se demande après |
| v3.16.0 | **Carnet ↔ sessions** — la fiche d'un instrument liste les sessions qui le mentionnent, sans saisie (lecture du champ matériel) ; **formulaire complet replié** en 6 sections, état retenu, ouverture forcée si un champ est rempli |
| v3.17.0 | **Puces matériel sur `/vite`** — le matériel se clique au lieu de se taper, trié favoris puis usage récent. Envoie le nom exact du catalogue, ce dont dépend le croisement du carnet : le maillon manquant entre saisie rapide et fiche instrument |
| v3.18.0 | **Fiches matériel** (`/catalogue/fiches`) — vue table éditable : fabricant, à quoi ça sert, comment je compte m'en servir. Deux colonnes ajoutées au catalogue (`purpose`, `intent`), relues sur le carnet d'instrument |
| v3.18.1 | **Impression des fiches** (`/catalogue/fiches/print`) — A4 paysage, groupé par type, suit les filtres de l'écran ; les cases vides sortent réglées pour être remplies au stylo |

---

## 🗺 Plan v3.x

### v3.0 — Workflow live *(priorité maximale)*

> L'axe fondamental : ouvrir l'app *avant* de jouer, pas après.

| Priorité | Idée | Notes |
|---|---|---|
| ✅ ★★★ | ~~**Mode session en cours** — timer live, notes rapides temps réel, bouton "Terminer & sauvegarder"~~ | **Livré** (blueprint `live`) — le chrono tourne pendant que tu joues |
| ✅ ★★★ | ~~**Backup automatique** — copie horodatée `sessions.db` au démarrage, garder 5 derniers~~ | **Livré** (v3.7.2, migré dans `wsgi.py` pour Gunicorn) |
| ✅ ★★☆ | ~~**Recherche full-text étendue** — couvrir comments, patches, recap_claude, lore_link~~ | **Livré** — FTS5 (v3.6.0) puis revert vers recherche Python couvrant 15 champs (FTS5 corrompait la DB via triggers) |
| ✅ ★★☆ | ~~**Vue liste compacte vs cartes** — toggle dense (50 lignes visibles) / détail~~ | **Livré** (v3.7.1, `compact.html`) |
| ★★☆ | **Duplication complète d'une session** — tout copier sauf date/audio | Documenter des variations d'un même morceau (NB : seule la duplication de *layout Patcher* existe à ce jour) |
| ~~★☆☆~~ | ~~**Import métadonnées audio** — lire date/durée via `mutagen`~~ | Abandonné (retiré de la roadmap, commit `7eb79d6`) |

---

### v3.1 — Stats & Analyse

| Priorité | Idée | Notes |
|---|---|---|
| ★★★ | **Heatmap calendrier** — grille jour/semaine style GitHub contributions | Visualiser périodes actives vs creuses (NB : une heatmap *intensités sonores* existe déjà sur l'index depuis v3.7.1 — celle-ci reste à faire, axe calendrier/activité) |
| ★★☆ | **Évolution temporelle** — courbe note moyenne, énergie, mode au fil du temps | Voir si la qualité progresse |
| ★★☆ | **Records & badges** — session la mieux notée, la plus longue, streak consécutif | Gamification légère |
| ★★☆ | **Corrélations** — note vs durée, énergie vs heure de la journée | Comprendre ses propres patterns |
| ★☆☆ | **Stats par projet** — dashboard durée/évolution, enrichir project_detail | Déjà partiellement présent |

---

### v3.2 — Lore AZA

⚠️⚠️ **Cet axe a commencé sans être décidé.** La v3.9.0 a introduit un **type de
session `lore`** avec un prompt Ollama qui écrit du **récit**, et un type
`veille`. C'est le premier pas concret dans cette section, livré alors qu'elle
était donnée pour vierge — le projet a bougé quelque part que sa carte ne
décrivait pas. Les idées ci-dessous sont donc à relire à cette lumière : une
partie a désormais un point d'accroche réel (les sessions typées) au lieu d'être
purement spéculative.


| Priorité | Idée | Notes |
|---|---|---|
| ★★☆ | **Générateur de noms AZA** — titres dans l'esthétique de l'univers | Ex : "SÉQUENCE-09 / MÉMOIRE RÉSIDUELLE / NODE SCAER-7" |
| ★★☆ | **Timeline narrative** — frise chronologique *dans l'univers* (distinct de la date réelle) | Ordonner par ordre lore, pas par date d'enregistrement |
| ★★☆ | **Carte du lore** — canvas interactif SVG/HTML, chaque session occupe un lieu | Visualisation narrative de la B.O. |
| ★☆☆ | **Bestiaire / Glossaire** — entités, lieux, factions liables aux sessions | Enrichir le contexte narratif |
| ★☆☆ | **Citations AZA** — base de citations affichées comme les obliques mais narratives | Ambiance de l'univers dans l'interface |

---

### v3.3 — Spark & Créatif

| Priorité | Idée | Notes |
|---|---|---|
| ✅ ★★★ | ~~**Spark "contrainte unique"** — une seule contrainte radicale, en grand, à suivre jusqu'au bout~~ | **Livré** (v3.7.2) — moins de bruit, plus d'impact |
| ★★☆ | **Challenge du jour** — contrainte fixe générée à minuit, commune à toute la journée | Fil conducteur sur 24h |
| ✅ ★★☆ | ~~**Historique Spark** — suggestions déjà générées, noter celles suivies~~ | **Livré** (v3.7.2) — historique en session Flask, `SEEN_MAX=8` ; reste à faire : *noter* celles suivies |
| ★☆☆ | **Spark ↔ Session** — lier une suggestion Spark à la session qu'elle a inspirée | Traçabilité créative complète — **toujours ouvert** |
| ✅ ★★☆ | ~~**Spark puise dans les idées en vrac**~~ | **Livré** (v3.10.0) — le type `Idée` est pondéré ×2 dans le pool focus, badge dédié. N'était pas sur la carte |

⚠️ **Le « noter celles suivies » reste ouvert**, malgré le ✅ de la ligne
Historique : la v3.7.2 a livré l'historique (`SEEN_MAX=8` en session Flask), pas
la notation. Et il rejoint le **Spark ↔ Session** ci-dessus — les deux décrivent
la même chose vue de deux angles : savoir quelle contrainte a produit quoi.

---

## ✅ Ableton Link — axe CLOS, migré vers D.I.M *(2026-08-08)*

⚠️⚠️ **Tout cet axe a quitté AZA Sessions.** Il n'a pas été abandonné — il a été
livré, éprouvé, puis **déplacé chez D.I.M** avec le Prompteur, le même jour.

**Pourquoi le déplacement.** AZA est le *journal* de session, D.I.M le
*séquenceur de performance* : deux outils, deux moments, qui ne s'utilisent pas
ensemble. Une horloge de performance n'a rien à faire dans un journal. Et
surtout — mesuré, pas supposé — **les deux services tenaient chacun leur pair
Link et apparaissaient comme deux appareils distincts** dans la session de tous
les musiciens présents.

**Ce qui a été livré ici avant de partir** (v3.11.0) : pair Link, `/api/link/state`,
affichage BPM dans la topbar, quantize des cues, annonces vocales, conversion
secondes → mesures au tempo réel.

**Où c'est maintenant :**

| | |
|---|---|
| horloge Link | D.I.M `adapters/sync/link_sync.py` — abstraction à **3 sources** (Link, MIDI clock, OSC) |
| annonces vocales | D.I.M `adapters/web/static/js/performance.js` |
| vue de performance | D.I.M `/performance` — multi-lanes, plus riche que le Prompteur |

⚠️ **Le quantize n'a PAS été porté, et il ne faut pas le recréer.** D.I.M compte
en **mesures** (`duration_bars`), ses changements tombent sur la grille par
construction. Le quantize n'existait ici que parce que le Prompteur comptait en
**secondes** — c'était un pansement sur un modèle temporel inadapté.

ℹ️ Trois leçons gardées, elles valent au-delà de ce projet :

1. **`abletonlink` n'existe pas** sur PyPI. Les bibliothèques réelles sont
   `aalink` et `LinkPython-extern`. Trois noms différents traînaient dans les
   docs des deux projets — vérifier, jamais faire confiance à un `requirements`.
2. **Un commit Link n'est pas fiable en soi** : deux écritures de tempo ont
   échoué en silence avant qu'une troisième passe. Toujours relire après écrire.
3. **`--workers 1` devient une contrainte** dès qu'un processus tient un pair
   Link : chaque instance est un appareil distinct sur le réseau.

---

## 🎨 Interface & UX — Backlog

| Priorité | Idée | Notes |
|---|---|---|
| ★★☆ | **Mode focus** — cacher nav, fond épuré, une seule page visible | Ne pas être distrait pendant la session |
| ★★☆ | **Thème personnalisable** — éditeur couleurs CSS custom, sauvegardé localStorage | Au-delà des 6 thèmes fixes |
| ★☆☆ | **Animations subtiles** — transitions CSS sur cards, Pomodoro, filtres | Peaufinage visuel |

---

## 🛠 Tech & Qualité — Backlog

| Priorité | Idée | Notes |
|---|---|---|
| ✅ ★★☆ | ~~**Tests automatisés** — suite Flask pour routes critiques~~ | **Livré** (v3.6.0/v3.7.1) — pytest, smoke tests des 18 blueprints + DB init/schema |
| ★☆☆ | **Compilation binaire M4** — `.app` macOS natif Apple Silicon via PyInstaller | Lancement sans terminal |
| ★☆☆ | **Mode multi-machines** — sync `sessions.db` réseau local (rsync ou SQLite over LAN) | Mac + iPad dans le même studio |
| ★☆☆ | **QR code vers session** — pointe vers `localhost:5001/session/<id>` | Scanner depuis iPhone en studio |

---

## 💡 Idées en vrac

- **Session fantôme** — marquer une session comme "perdue/ratée" pour garder la trace sans regrets
- **BPM tap tempo** — widget dans le formulaire, ou récupéré depuis Ableton Link directement
- **Couleur d'humeur** — palette 5-6 couleurs symboliques, un clic pour caractériser la session
- **Météo/Contexte** — lieu (bureau/salon/extérieur), état d'esprit en un mot
- **Lecteur audio intégré** — Web Audio API, lecture du fichier directement dans la vue session

---

*Dernière mise à jour : 2026-09-08 — v3.18.1*
*Ce fichier évolue librement — ce n'est pas un backlog, c'est une carte des possibles.*

## Demandes externes (Argus)

<!-- argus:begin -->
- [ ] ⇐ Homelab : Intégration d'une section dédiée aux guides d'installation dans le journal des sessions.
      _pourquoi : Cela permettrait une meilleure cohérence et facilitation de l'accès à ces informations cruciales pour les nouveaux contributeurs._
<!-- argus:end -->
