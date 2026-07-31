# ROADMAP — Journal de Sessions AZA

> Carte des possibles — pas un backlog, pas de deadlines.
> Mis à jour : 2026-06-27 (après release v3.7.2)

---

## ✅ Déjà livré (v1.x → v3.7.2)

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
| ★☆☆ | **Spark ↔ Session** — lier une suggestion Spark à la session qu'elle a inspirée | Traçabilité créative complète |

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
| ★★★ | **Sync tempo Ableton Link** — le Prompteur s'accroche à la grille Link (tempo, beat phase) | Librairie Python : `abletonlink` (bindings CPython du SDK officiel) |
| ★★★ | **Click IEM via réseau** — générer un click audio synced (Web Audio API ou serveur audio) streamé vers iPhone/iPad en retour d'oreille | Le musicien entend le click dans ses IEMs, synchronisé avec le set |
| ★★☆ | **Annonces vocales de cue** — TTS au changement de cue dans le Prompteur ("Patch Drone — 32 mesures") | Web Speech API côté client ou `pyttsx3` côté serveur |
| ★★☆ | **Affichage tempo live** — BPM courant Link affiché dans la topbar du Prompteur | Feedback visuel de la sync |
| ★★☆ | **Quantize changement de cue** — l'avance automatique attend le prochain temps fort Link | Changements toujours musicaux, jamais au milieu d'une mesure |
| ★☆☆ | **Multi-musiciens** — plusieurs instances de l'app sur le même réseau, toutes sync Link | Chaque musicien voit les cues sur son propre appareil |
| ★☆☆ | **Export set vers Ableton Live** — générer une piste MIDI marker depuis les cues du Prompteur | Automatiser les marqueurs de scène dans Live |

### Piste technique

```
App Flask (Prompteur)
    ↓ abletonlink (Python SDK)
    → sync tempo/beat avec Ableton Live / tout app Link sur le réseau

    ↓ Web Audio API (côté client)
    → AudioContext oscillator click, tempo = Link.bpm
    → StreamedToIEM via AirPlay / réseau local / app iPhone dédiée

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

*Dernière mise à jour : 2026-06-27 — v3.7.2*
*Ce fichier évolue librement — ce n'est pas un backlog, c'est une carte des possibles.*

## Demandes externes (Argus)

<!-- argus:begin -->
- [ ] ⇐ Homelab : Intégration d'une section dédiée aux guides d'installation dans le journal des sessions.
      _pourquoi : Cela permettrait une meilleure cohérence et facilitation de l'accès à ces informations cruciales pour les nouveaux contributeurs._
- [ ] ⚑ Intégration avec D.I.M
      _pourquoi : L'intégration deAZA Sessions avec D.I.M pourrait permettre d'automatiser la création de morceaux basés sur les sessions documentées, en utilisant les informations contenues dans les fichiers de session._
- [ ] ⇐ Argus : [health-endpoint] Tout service HTTP expose GET /health répondant 200.
      _pourquoi : Un watchdog ne peut pas surveiller ce qu'il ne peut pas interroger. Sans sonde uniforme, chaque service invente la sienne — ou n'en a aucune, et tombe sans que personne le voie (OpenClaw bloqué 12 h en « active (running) », Navidrome mort 10 h derrière un stream qui continuait de sortir)._
<!-- argus:end -->
