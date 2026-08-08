# ROADMAP — Journal de Sessions AZA

> Carte des possibles — pas un backlog, pas de deadlines.
> Mis à jour : 2026-08-08 (après release **v3.10.0**)

---

## ⏸ État du projet

⚠️ **Aucun développement depuis le 2026-06-27.** Les commits postérieurs sont
deux licences, deux fichiers Argus, une convention de session et un correctif —
zéro fonctionnalité. Le projet n'est pas mort, il est en pause.

ℹ️ **Le recap automatique a été mort sans que personne le voie.** Corrigé le
2026-07-31 (`qwen3.5:latest` → `qwen3.5:cloud`) : le modèle n'existait pas. Même
cascade que Subwave et Nemesis lors du retrait des modèles Ollama Cloud du
2026-07-15. ⚠️ Réflexe : un appel LLM qui échoue en silence ne se voit jamais
depuis l'interface — c'est le modèle qu'il faut vérifier, pas le code.

---

## ✅ Déjà livré (v1.x → v3.10.0)

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

## 🔗 Ableton Link — Axe performance live *(nouveau)*

> **Contexte :** Ableton Link synchronise tempo et beat-phase entre applications via réseau local (UDP multicast). Couplé au Prompteur Dawless, il ouvre un axe de communication musicien → in-ear monitors (IEM) : cues de changement de patch, clicks de tempo, instructions texte en retour d'oreille.

### Pourquoi c'est pertinent

- Le Prompteur gère déjà les cues avec minutage
- Ableton Link donne le tempo partagé et la position dans la mesure
- Les retours oreilles des musiciens peuvent recevoir des **clicks synchronisés** + **annonces vocales de cue** (TTS)
- Aucun hardware MIDI nécessaire — tout passe par le réseau local Wi-Fi

### Idées à explorer

| Priorité | Idée | Notes |
|---|---|---|
| ★★★ | **Sync tempo Ableton Link** — le Prompteur s'accroche à la grille Link (tempo, beat phase) | ⚠️ **`abletonlink` N'EXISTE PAS** sur PyPI. Utiliser **`LinkPython-extern`** (1.3.0, wheels fournies) — **testé le 2026-08-08 sur Roblab, Python 3.14.4 : installation, import et découverte OK**. Alternative asyncio : `aalink` (0.2.3) |
| ★☆☆ | **Click IEM via réseau** — click audio synchronisé dans les retours d'oreille | ⚠️⚠️ **Irréalisable tel qu'écrit — rétrogradé de ★★★.** AirPlay a ~2 s de latence, et un navigateur ne peut pas parler Link (multicast UDP). Un click *streamé* ne sera jamais en phase. La seule voie : un client natif sur l'iPhone tenant **son propre pair Link** et générant le click **localement** — le click n'est pas transporté, il est reproduit en phase. Chantier à part entière |
| ★★☆ | **Annonces vocales de cue** — TTS au changement de cue dans le Prompteur ("Patch Drone — 32 mesures") | Web Speech API côté client ou `pyttsx3` côté serveur |
| ★★☆ | **Affichage tempo live** — BPM courant Link affiché dans la topbar du Prompteur | Feedback visuel de la sync |
| ★★☆ | **Quantize changement de cue** — l'avance automatique attend le prochain temps fort Link | Changements toujours musicaux, jamais au milieu d'une mesure |
| ★☆☆ | **Multi-musiciens** — plusieurs instances de l'app sur le même réseau, toutes sync Link | Chaque musicien voit les cues sur son propre appareil |
| ★☆☆ | **Export set vers Ableton Live** — générer une piste MIDI marker depuis les cues du Prompteur | Automatiser les marqueurs de scène dans Live |

### Ce que le terrain dit — vérifié le 2026-08-08

⚠️⚠️ **Ton matériel ne parle PAS Link.** MicroFreak, NTS-1, Volca Drum, Volca
Kick : horloge MIDI ou sync analogique. Link ne les synchronisera jamais
directement — il faudrait un pont Link→MIDI clock, chantier absent de cette
carte. Dans un setup nommé *Dawless*, c'est l'angle mort du plan.

✅ **Mais les pairs existent déjà**, et le catalogue les contient : **Ableton
Live**, plus 8 synthés iOS dont `MiRack`, `Tera Pro`, `Peach`, `Seqnd`,
`Blue Arp` et `LK for Live` — la plupart parlent Link nativement. **L'iPad est
le hub.** Le cas d'usage est réel, pas spéculatif.

⚠️ **Un navigateur ne peut pas parler Link** (multicast UDP). L'architecture est
donc forcément : Flask tient le pair Link et pousse vers le navigateur en
WebSocket/SSE. Parfait pour l'affichage du tempo et la **quantification des
cues** ; insuffisant pour une précision à l'échantillon.

✅ **Traversée du LAN PROUVÉE** (2026-08-08). Ableton Live lancé sur le Mac Mini
avec Link activé : **Roblab le découvre en 2 s** et lit son tempo réel —
**115.00 BPM**, celui de Live, pas les 120 de notre valeur par défaut. Le
multicast passe donc entre les deux machines sans rien configurer.

✅ **Et la phase avance correctement**, ce qui est le point qui compte pour
quantifier les cues. Relevé sur 5 s à 115 BPM (une mesure = 2,087 s) :

| t | beat | phase/4 | prochain temps fort |
|---|---|---|---|
| 0,0 s | 3,86 | 3,86 | 0,07 s |
| 0,7 s | 5,20 | 1,20 | 1,46 s |
| 1,4 s | 6,55 | 2,55 | 0,76 s |
| 2,1 s | 7,89 | 3,89 | 0,06 s |

Le beat progresse de ~1,34 par 0,7 s — exactement 115 BPM. **`phaseAtTime` donne
directement le délai jusqu'au prochain temps fort** : c'est tout ce qu'il faut
pour qu'un changement de cue n'arrive jamais au milieu d'une mesure.

ℹ️ Reste non testé : **écrire** vers Link (imposer un tempo depuis le Prompteur
via `commitAppSessionState`). Non essayé délibérément — ça aurait changé le tempo
de la session Live en cours.

**Ordre conseillé** — 1. affichage tempo + quantize des cues (aucune contrainte
de latence, brique prouvée) · 2. annonces vocales via Web Speech API (indépendant
de Link, gain immédiat) · 3. le click IEM en dernier, repensé.

### Piste technique

```
App Flask (Prompteur)
    ↓ LinkPython-extern  (⚠️ PAS `abletonlink`, qui n'existe pas)
    → sync tempo/beat avec Ableton Live / tout app Link sur le réseau

    ↓ WebSocket / SSE  (le navigateur ne parle PAS Link)
    → tempo + phase poussés au client, pour l'affichage et le quantize

    ⚠️ PAS de click streamé : AirPlay ~2 s de latence.
    → app iPhone tenant SON pair Link, click généré localement

    ↓ Web Speech API
    → speechSynthesis.speak("Patch suivant : DRONE 9")
```

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

*Dernière mise à jour : 2026-08-08 — v3.10.0*
*Ce fichier évolue librement — ce n'est pas un backlog, c'est une carte des possibles.*

## Demandes externes (Argus)

<!-- argus:begin -->
- [ ] ⇐ D.I.M : Un format de métadonnées standardisé dans les comptes-rendus de session pour lier explicitement les moments narratifs aux identifiants de sections D.I.M.
      _pourquoi : Cela permettrait d'automatiser le chargement du bon roadbook musical au début de chaque séance sans intervention manuelle, réduisant les erreurs de contexte._
- [ ] ⇐ Homelab : Intégration d'une section dédiée aux guides d'installation dans le journal des sessions.
      _pourquoi : Cela permettrait une meilleure cohérence et facilitation de l'accès à ces informations cruciales pour les nouveaux contributeurs._
- [ ] ⚑ Intégration avec D.I.M
      _pourquoi : L'intégration deAZA Sessions avec D.I.M pourrait permettre d'automatiser la création de morceaux basés sur les sessions documentées, en utilisant les informations contenues dans les fichiers de session._
- [ ] ⇐ Argus : [health-endpoint] Tout service HTTP expose GET /health répondant 200.
      _pourquoi : Un watchdog ne peut pas surveiller ce qu'il ne peut pas interroger. Sans sonde uniforme, chaque service invente la sienne — ou n'en a aucune, et tombe sans que personne le voie (OpenClaw bloqué 12 h en « active (running) », Navidrome mort 10 h derrière un stream qui continuait de sortir)._
<!-- argus:end -->
