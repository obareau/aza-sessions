# ROADMAP — Journal de Sessions AZA

> Carte des possibles — pas un backlog, pas de deadlines.
> Mis à jour : 2026-09-27 (après release **v3.20.0**)

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

## ✅ Déjà livré (v1.x → v3.20.0)

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
| v3.18.2 | **Ajout de matériel depuis la vue table** — type, fabricant, nom et les deux champs de la fiche d'un coup, sans repasser par `/catalogue` ; doublon (type, nom) refusé |
| v3.18.3 | **Deux échecs, deux messages** — `add_fiche` renvoyait `None` pour trois causes (type manquant, nom manquant, doublon) ; la saisie incomplète lève désormais `ValueError`, le doublon garde `None` |
| v3.19.0 | **Nom de prise Zoom R8 généré** — colonne `code` au catalogue, `/vite` fabrique `MFMG5_1` depuis le matériel coché. Ordre du signal et non alphabétique ; compteur quotidien |
| v3.19.1 | **Fiches matériel dans le menu** Catalogue — la vue table n'était atteignable que par un bouton |
| v3.19.2 | **Contraintes réelles du R8 appliquées** (manuel p. 94) — 8 caractères max, `A-Z 0-9 _` seulement, tiret refusé. Le préfixe est rogné, jamais le rang ; les codes sont assainis à la lecture |
| v3.20.0 | **Aperçu du nom de prise en direct** sur `/vite` — et il nomme ce qui manque : matériel sans code, préfixe rogné. Route `POST /api/nom-de-prise` |

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
| ✅ | ~~**Dépouillement des prises R8**~~ — livré en **v3.28.0** | N'était pas sur la carte. `/prises` rapproche le dossier de vidage de la carte SD et le journal : orphelines, réclamées-absentes, rattachées. Ferme la boucle ouverte par le générateur de nom, que plus personne ne relisait |
| ✅ | ~~**Fiche de rappel**~~ — livrée en **v3.27.0** | N'était pas sur la carte. `/session/<id>/rappel` : la chaîne dans l'ordre du signal, les réglages, les façades relevées. Imprimable pour être posée à côté du clavier |
| ✅ | ~~**Relevés de potards**~~ — livré en **v3.26.0** | N'était pas sur la carte. Déclarer les commandes d'un instrument, relever leurs positions par son gardé. Motivé par le Behringer WASP Deluxe : un analo sans mémoire ne se retrouve que par sa façade. « Pas relevé » reste distinct de « à zéro » |
| ✅ | ~~**Duplication complète d'une session**~~ — **existait déjà**, constaté le 2026-09-28 | `/new?from=<id>` pré-remplit toute la séance, et la vue séance porte le bouton `⎘ Copier setup` depuis longtemps. La note « seule la duplication de layout Patcher existe » était fausse. Vérifier la page avant de rouvrir un item |
| ~~★☆☆~~ | ~~**Import métadonnées audio** — lire date/durée via `mutagen`~~ | Abandonné (retiré de la roadmap, commit `7eb79d6`) |

---

### v3.1 — Stats & Analyse

| Priorité | Idée | Notes |
|---|---|---|
| ✅ ★★★ | ~~**Heatmap calendrier** — grille jour/semaine style GitHub contributions~~ | **Déjà livrée**, constaté le 2026-09-27 : `/stats` porte la grille 53 semaines avec étiquettes de mois, légende, infobulle, et `compute()` renvoie `heatmap`, `streak` et `max_streak`. La note « reste à faire » visait la heatmap *sonore* de l'index et a fait croire l'inverse — vérifier la page avant de rouvrir un item |
| ✅ | ~~**Évolution temporelle**~~ — livré en **v3.22.0** | Carte « Évolution — moyennes par mois » sur `/stats` : note /5 et énergie /3 sur deux axes. Le **mode** n'y est pas — une moyenne de catégories n'a pas de sens ; sa répartition est déjà au doughnut |
| ✅ | ~~**Records & badges**~~ — **déjà livré**, constaté le 2026-09-27 | `/stats` porte la carte « Records » (meilleure session, plus longue, heures cumulées, machine la plus utilisée) et les KPI streak / record streak. Rien à ajouter : vérifier la page avant de rouvrir l'item |
| ✅ | ~~**Corrélations**~~ — livré en **v3.22.0** | Nuage note × durée + énergie moyenne par heure sur `/stats`. Nuage brut, **pas** de droite de régression ni de coefficient : l'échantillon ne les porterait pas. Les deux blocs restent cachés sous `MIN_POINTS = 5` |
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
| ✅ | ~~**Générateur de noms AZA**~~ — livré en **v3.21.0** | Bouton `⟳ titre AZA` sur `/vite`, `/new`, `/edit` · `core/lore_names.py` + `GET /api/noms-aza` · vocabulaire tiré du glossaire de Robōtariis |
| ✅ | ~~**Timeline narrative**~~ — livrée en **v3.24.0** | `/lore/timeline` lit `Lore/Temps/timeline.md` du vault : 56 événements, groupés par ère, **dans l'ordre du fichier**. Rien n'est trié — interpréter « Pré-An 0 (−168) » ou « An 50 (1 Ordium) » pour les ranger reviendrait à réécrire le canon |
| ⚠️ | **Carte du lore** — *partiellement* livré en v3.24.0 | `/lore/section/Lieux` donne les 27 lieux lus dans le vault. Le **canvas SVG où chaque session occupe un lieu est écarté pour l'instant** : les sessions ne référencent aucun lieu (`lore_link` vide sur les 3 existantes), la carte n'aurait rien à placer. L'amorce est faite — le champ `lore_link` se complète maintenant depuis le corpus. À rouvrir quand des sessions porteront des lieux |
| ✅ | ~~**Bestiaire / Glossaire**~~ — livré en **v3.24.0** | `/lore` expose les 190 entrées du corpus par section (Personnages, Factions, Entités, Institutions, Culture, Concepts, Lieux, Temps, Langages) avec recherche. **Aucune table AZA** : Obsidian reste la référence, décision du 2026-09-27 |
| ✅ | ~~**Citations AZA**~~ — livré en **v3.24.0** | 208 extraits tirés des blocs `>` du corpus — **ses mots, pas des citations inventées**. `/lore/citations` les liste, une est tirée en tête des vues lore, `GET /api/citation` les expose. Les « Définition — » sont écartées : elles expliquent l'univers au lieu de le faire entendre. ⚠️ Le bandeau des obliques n'est **pas** touché — c'est un autre mécanisme, le remplacer n'a pas été demandé |

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
| ✅ | ~~**Mode focus**~~ — livré en **v3.23.0** | Touche `f` (ou `Esc` pour sortir), persisté en localStorage. Cache header, nav, bandeau oblique et pied ; le contenu ne bouge pas de place. Bouton `✕ focus` en haut à droite — sans lui, un mode sans nav serait un piège au doigt |
| ✅ | ~~**Thème personnalisable**~~ — livré en **v3.23.0** | 5 pastilles dans le sélecteur de thème (fond, texte, bordure, 2 accents) ; les 11 autres variables se **dérivent** en `color-mix()`. Régler 16 couleurs à la main n'aurait servi qu'à les rendre incohérentes |
| ★☆☆ | **Animations subtiles** — transitions CSS sur cards, Pomodoro, filtres | Peaufinage visuel |

---

## 🛠 Tech & Qualité — Backlog

| Priorité | Idée | Notes |
|---|---|---|
| ✅ ★★☆ | ~~**Tests automatisés** — suite Flask pour routes critiques~~ | **Livré** (v3.6.0/v3.7.1) — pytest, smoke tests des 18 blueprints + DB init/schema |
| ★☆☆ | **Compilation binaire M4** — `.app` macOS natif Apple Silicon via PyInstaller | Lancement sans terminal |
| ★☆☆ | **Mode multi-machines** — sync `sessions.db` réseau local (rsync ou SQLite over LAN) | Mac + iPad dans le même studio |
| ★☆☆ | **QR code vers session** — pointe vers `localhost:5001/session/<id>` | Scanner depuis iPhone en studio |
| ⛔ ★☆☆ | ~~**Factoriser les 16 `_get_db()` identiques**~~ — une classe de base pour les 15 moteurs | **Écarté le 2026-09-27.** Trouvé par graphify (degré 26 sur `._get_db()`). Trois lignes triviales dupliquées quinze fois ne valent pas une hiérarchie de classes — le gain n'existera que le jour où le mode de connexion changera |

---

## 💡 Idées en vrac

- **Session fantôme** — marquer une session comme "perdue/ratée" pour garder la trace sans regrets
- **BPM tap tempo** — widget dans le formulaire, ou récupéré depuis Ableton Link directement
- **Couleur d'humeur** — palette 5-6 couleurs symboliques, un clic pour caractériser la session
- **Météo/Contexte** — lieu (bureau/salon/extérieur), état d'esprit en un mot
- **Lecteur audio intégré** — Web Audio API, lecture du fichier directement dans la vue session

---

*Dernière mise à jour : 2026-09-27 — v3.20.0*
*Ce fichier évolue librement — ce n'est pas un backlog, c'est une carte des possibles.*

## Demandes externes (Argus)

<!-- argus:begin -->
- [ ] ⇐ Homelab : Intégration d'une section dédiée aux guides d'installation dans le journal des sessions.
      _pourquoi : Cela permettrait une meilleure cohérence et facilitation de l'accès à ces informations cruciales pour les nouveaux contributeurs._
<!-- argus:end -->

**Réponse à la demande Homelab (2026-09-27) — écartée, case laissée décochée.**
Le motif avancé est « faciliter l'accès pour les nouveaux contributeurs ». AZA
est le journal musical personnel d'une seule personne : il n'a pas de
contributeurs, et n'est pas un site de documentation. Les guides d'installation
ont déjà leur domicile — le dépôt `homelab-install` — et les recopier ici
créerait une seconde vérité à maintenir, exactement ce qu'on vient d'éviter pour
le lore. Si le besoin réel est « retrouver les guides depuis n'importe où », il
se règle côté Homelab ou Homepage, pas en ajoutant une section au journal.
