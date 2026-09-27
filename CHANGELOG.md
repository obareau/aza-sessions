# CHANGELOG — Journal de Sessions AZA

> Les versions alpha sont des releases actives en développement continu.
> Chaque version est datée du jour de développement effectif.

---

## v3.24.1 — 2026-09-27 — Retrait de n8n

### 🧹 Nettoyage
- **`core/n8n_client.py` supprimé.** Le module postait des notifications ntfy et
  des générations Ollama à un webhook n8n — et **n'avait aucun appelant**. Ses
  deux fonctions avalaient les erreurs en retournant `False`, donc rien n'aurait
  signalé qu'elles ne marchaient plus.
- **n8n est décommissionné** (2026-09-27) : son conteneur repartait en crash-loop
  à chaque boot depuis juin (`data/` appartenait à root, il n'a jamais rien pu
  persister), alors qu'il était marqué « désactivé » depuis le 2026-07-14.
- `/api/stats/summary` reste, mais sa docstring dit la vérité : elle a été écrite
  pour le digest n8n, qui n'existe plus. Sans consommateur d'ici quelque temps,
  la supprimer.

---

## v3.24.0 — 2026-09-27 — Le lore entre dans le journal sans y déménager

### ✨ Nouveauté — blueprint `lore` (19ᵉ module)
- **`/lore`** — les **190 entrées** du corpus Robōtariis par section (Personnages,
  Factions, Entités, Institutions, Culture, Concepts, Lieux, Temps, Langages),
  avec recherche sur titre, description et tags.
- **`/lore/timeline`** — les **56 événements** de la chronologie, groupés par ère,
  dans l'ordre du fichier. An 0 = 2413 grégorien.
- **`/lore/citations`** — **208 extraits** tirés des blocs de citation du corpus.
  Ses mots : aucune citation n'est écrite par l'app.
- **Le champ « lien avec le lore » se complète depuis le corpus** (`<datalist>`
  natif alimenté par `GET /api/lore/entrees`). C'est ce qui rendra la carte
  possible : sans liens réels, elle n'aurait rien à placer.
- Entrée `◈ Lore` dans le menu Ressources. Chemin du corpus réglable, défaut
  `~/robotariis/PUBLICATIONS-QUARTZ`.

### 📐 Décision d'architecture — **Obsidian reste la référence, AZA lit**
- **Aucune entité de lore n'est stockée en base.** Pas de table `lore_places`, pas
  de CRUD, pas de double saisie. Les dupliquer garantirait deux vérités qui
  divergeraient à la première correction faite d'un seul côté.
- **AZA ne rend pas le Markdown** et n'ajoute donc aucune dépendance : le corpus
  est déjà lisible dans Obsidian et publié sur robotariis.com. Chaque carte porte
  l'en-tête (titre, description, tags) et renvoie au texte complet. Le frontmatter
  est lu à la main — le corpus n'a que des scalaires et des listes inline, PyYAML
  aurait coûté une dépendance pour six lignes.
- **Pas de vault, pas de page** : chaque vue le dit et propose de régler le
  chemin, au lieu de laisser croire que le lore a disparu.

### 🐛 Correctif trouvé en chemin
- **La barre verticale d'un wikilink est le séparateur de cellule Markdown.**
  `| An 0 | 2413 | Fondation du [[cgu|C.G.U.]] |` se découpait en quatre colonnes.
  Les wikilinks sont désormais résolus **avant** le découpage. Trouvé par le test,
  pas à l'œil.

### ⛔ Écarté
- **Le canvas SVG de la carte du lore.** Les sessions ne référencent aucun lieu
  (`lore_link` vide partout) : la carte n'aurait rien à placer. L'amorce est
  livrée, l'item rouvrira quand des sessions porteront des lieux.
- **La demande externe du Homelab** (« section guides d'installation ») — motivée
  par « les nouveaux contributeurs », qu'AZA n'a pas. Raison consignée sous le
  bloc Argus du ROADMAP, case laissée décochée.

### 🧪 Tests
- `tests/test_lore.py` — 11 cas sur un **faux corpus construit par le test** :
  dépendre du vrai vault ferait échouer la suite le jour où un fichier de fiction
  est renommé, ce qui n'est pas une régression. Couvre l'absence de corpus, les
  sous-dossiers (Factions/Majeures), la description de secours, l'ordre de la
  frise et l'exclusion des définitions.

---

## v3.23.0 — 2026-09-27 — L'interface se tait, et se règle

### ✨ Nouveauté
- **Mode focus** — touche `f`, ou le bouton `✕ focus` pour sortir (`Esc` aussi).
  Header, navigation, bandeau de stratégie et pied de page disparaissent ; le
  contenu ne bouge pas d'un pixel. Persisté : on l'allume avant de jouer, pas à
  chaque page.
- **Thème personnalisable** — cinq pastilles dans le sélecteur de thème (fond,
  texte, bordure, accent, accent 2). Les **onze autres variables se dérivent**
  en `color-mix()` : demander seize couleurs aurait surtout permis de les rendre
  incohérentes entre elles.
- Le réglage perso reste visible dans le menu même sous un thème fixe, et un
  `localStorage` corrompu retombe sur le Béton au lieu d'un écran illisible.

### 🧪 Tests
- **`tests/test_base_js.py` + `tests/js/base_theme_focus.mjs`** — premier test du
  JS de l'app. Ces deux fonctionnalités vivent entièrement dans le navigateur :
  aucune route, aucune table, donc rien que pytest n'atteignait. Le harnais
  exécute sous Node le JS *réellement servi par la page*, contre un faux DOM
  minimal, et vérifie ce qui casse en silence — quelle classe est posée, quelle
  variable inline est retirée, ce qui est persisté. Sauté si Node est absent.

---

## v3.22.0 — 2026-09-27 — Ce que les sessions disent au bout d'un an

### ✨ Nouveauté
- **Évolution par mois sur `/stats`.** Note moyenne (/5) et énergie moyenne (/3)
  sur deux axes distincts — sur un seul, l'énergie s'écrasait en bas du graphe.
  Un mois sans note est **absent** de la courbe, pas à zéro : zéro voudrait dire
  « mauvais », alors que ça veut dire « pas renseigné ».
- **Corrélations.** Nuage note × durée, et énergie moyenne par heure de la
  journée — de quoi voir si les bonnes séances sont les longues, et à quelle
  heure on joue vraiment.
- **Rien ne s'affiche sous 5 sessions renseignées** (`MIN_POINTS`). Une moyenne
  sur trois séances n'est pas une tendance, c'est trois séances ; la page est
  plus courte plutôt que menteuse.

### 🐛 Correctif
- **`/api/stats/summary` renvoyait `top_machine: null` et `this_month: 0` depuis
  toujours.** La route lisait `top_machine` à la racine alors qu'il vit sous
  `records`, et `this_month` n'était jamais calculé. Le digest n8n annonçait donc
  du vide sans se plaindre.

### 📝 Note
- **« Records & badges » était déjà livré** : `/stats` porte la carte Records et
  les KPI de streak. L'item a été coché sans ligne de code — comme la heatmap la
  veille. Vérifier la page avant de rouvrir un item de cette section.

### 🧪 Tests
- `tests/test_stats_evolution.py` — surtout le **seuil** : sous `MIN_POINTS`, les
  quatre blocs doivent rester vides. Plus les cas tordus : date sans heure, durée
  manquante, mois non noté.

---

## v3.21.0 — 2026-09-27 — Nommer la séance dans l'univers

### ✨ Nouveauté
- **Générateur de titres AZA.** Un bouton `⟳ titre AZA` à côté du champ *Titre*
  sur `/vite`, `/new` et l'édition : un clic remplit le champ d'un titre dans
  l'esthétique de l'univers (`MÉMOIRE RÉSIDUELLE`, `NODE KERGLAZ-7`,
  `CDX-34 / BALISE SOUTERRAINE`, `A.99 — FRACTURE`). Le champ reste éditable —
  la proposition amorce, elle n'impose rien.
- Le vocabulaire vient du **glossaire de Robōtariis** (le codex, le C.G.U., le
  calendrier `CAL_RECT` qui démarre à l'an 0, Scaër), pas d'une banque de mots
  de science-fiction générique.
- Nouvelle route `GET /api/noms-aza` et module `core/lore_names.py` — pur, sans
  état, sans base : rien n'est enregistré.

### 🧪 Tests
- `tests/test_lore_names.py` — le contrat (nombre, unicité, registre, accord du
  genre, route), pas le tirage : le hasard est la fonctionnalité.

### 📝 Note
- Les noms sont **séparés par genre** : le premier tirage sortait
  « SIGNAL RÉSIDUELLE ». L'accord ne se dérive pas depuis le mot
  (BASSE/BAS, ANCIENNE/ANCIEN), il est écrit dans deux listes parallèles.

---

## v3.20.0 — 2026-09-27 — Le nom se voit avant d'exister

### ✨ Nouveauté
- **Aperçu du nom de prise en direct sur `/vite`.** On clique les puces, le nom
  s'affiche sous elles — avant d'enregistrer quoi que ce soit. C'est l'outil
  d'aide au nommage : on compose la chaîne, on lit le nom, on le reporte sur
  le R8.
- **Il dit aussi ce qui manque.** Un appareil sélectionné sans code au catalogue
  n'apparaît pas dans le nom ; l'encart le nomme (`sans code : Digitakt`)
  plutôt que de laisser chercher. Idem quand le préfixe a été rogné à
  8 caractères.
- Nouvelle route `POST /api/nom-de-prise` — elle ne crée rien, elle calcule.

### ⚠️ Pourquoi le calcul reste côté serveur
Le nom dépend des codes du catalogue **et** des prises déjà enregistrées ce
jour-là. Le recalculer en JavaScript aurait fait deux vérités pour un seul nom,
qui divergeraient au premier changement de règle.

### ⚠️ Une collision reste possible, et elle n'est pas corrigée ici
Le manuel du R8 dit qu'un projet **ne peut pas porter le nom d'un autre
projet**. Or le compteur repart chaque jour : `MF_1` lundi et `MF_1` mardi
entrent en collision dès que les deux coexistent sur la carte. Trois sorties
possibles — vider la carte entre deux jours, passer le compteur en « Nième
usage de cette chaîne » (unique par construction), ou inscrire la date dans le
nom. À trancher.

---

## v3.19.2 — 2026-09-27 — Le R8 aurait refusé nos noms

### 🐛 Correctif
Vérification faite dans le manuel du Zoom R8 (p. 94), un nom de **projet** :
**8 caractères maximum**, et **A-Z, 0-9 et `_` uniquement**.

- **Le tiret est interdit.** Le `MFMG5-1` livré en v3.19.0 aurait été refusé
  par la machine. Le séparateur devient `_` → **`MFMG5_1`**.
- **Plafond à 8 caractères**, appliqué. Si la chaîne déborde, **c'est le
  préfixe qu'on rogne, jamais le rang** : deux prises du même après-midi
  portant le même nom seraient pires qu'un nom tronqué.
- **Les codes sont assainis à la lecture** — minuscules, espaces et tirets
  retirés. Un `m-f 5` saisi dans les fiches devient `MF5`, plutôt que d'aller
  jusqu'à la machine sous une forme qu'elle refuse.

ℹ️ Les noms de **fichier** audio du R8, eux, tolèrent 219 caractères et le
tiret. C'est le nom de **projet** qu'AZA fabrique, parce que c'est celui qu'on
lit à l'écran de la machine.

⚠️ **À trois appareils, le préfixe est rogné** : `MFDTMG_1` au lieu de
`MFDTMG5_1`. Des codes de deux caractères laissent de la place ; des codes de
trois n'en laissent plus au-delà de deux appareils.

### ✅ Tests
2 ajoutés (contraintes de la machine, assainissement d'un code mal saisi), les
6 existants recalés sur `_`. Suite : **95 passants**.

---

## v3.19.1 — 2026-09-27 — Les fiches dans le menu

### ✨ Nouveauté
- **Catalogue → ▤ Fiches matériel** dans la barre de navigation. La vue table
  n'était atteignable que par un bouton depuis `/catalogue` — un détour pour
  une page qu'on ouvre maintenant à chaque achat, ne serait-ce que pour coder
  le nouveau matériel.

Le bouton sur `/catalogue` reste : il sert quand on y est déjà.

---

## v3.19.0 — 2026-09-27 — Le nom de prise se fabrique tout seul

### ✨ Nouveautés
- **Colonne `Code` dans les fiches matériel** — `MF` pour le MicroFreak, `MG5`
  pour la MS-50G. Six caractères, saisis une fois, mis en majuscules.
- **`/vite` nomme la prise** à partir du matériel coché : `MFMG5-1`. Le nom
  s'écrit dans `audio_file`, celui qu'on reporte sur le Zoom R8.
- **Le compteur repart chaque jour** — c'est le rythme d'un enregistreur de
  studio, où l'on refait la même chaîne trois fois dans l'après-midi.

### ⚠️ Pourquoi générer plutôt que saisir
Le R8 nomme ses prises `FOLDER01`, ce qui ne dit rien six mois plus tard. Et
le champ libre ne vaut pas mieux : `signal_routing` porte déjà « Microfrek »,
une faute qu'aucun croisement ne rattrapera jamais. Les codes viennent du
catalogue, donc le nom est reconstituable et ne peut pas diverger.

### 🔧 Détails qui comptent
- **L'ordre suit le signal, pas l'alphabet** : machine, puis effet, puis iOS,
  puis plugin. Alphabétiser aurait mis la pédale avant le synthé.
- **Un matériel sans code est ignoré** plutôt que de se voir inventer une
  abréviation — mieux vaut un nom court qu'un nom faux.
- **Aucun code du tout = aucun nom.** Une session sans matériel codé se crée
  quand même ; la saisie rapide ne doit jamais se bloquer.

### ✅ Tests
8 ajoutés (ordre du signal, compteur quotidien, matériel sans code, doublon de
code, et deux de bout en bout sur `/vite`). Suite : **93 passants**.

---

## v3.18.3 — 2026-09-27 — Deux échecs, deux messages

### 🐛 Correctif
- **`add_fiche` renvoyait `None` pour trois causes différentes** — type manquant,
  nom manquant, doublon. L'appelant ne pouvait pas les distinguer, d'où un
  message qui avouait son ignorance : « Type et nom sont requis, et ce nom
  existe **peut-être** déjà ». Qui saisissait un doublon lisait un texte parlant
  de champs manquants, et réciproquement.
- La saisie incomplète lève désormais `ValueError`, le doublon garde `None`.
  Deux sorties pour deux causes — elles ne se corrigent pas pareil.

### ✅ Tests
Le test existant est recalé sur le nouveau contrat, et un test de route vérifie
ce qui était réellement cassé : **le message**. Il affirme aussi les négatifs —
un doublon ne doit jamais parler de champs requis, une saisie vide ne doit
jamais parler de doublon. Suite : **85 passants**.

---

## v3.18.2 — 2026-09-08 — Ajouter du matériel sans quitter la table

### ✨ Nouveautés
- **Formulaire d'ajout en tête de `/catalogue/fiches`** — type, fabricant, nom,
  et les deux champs de la fiche d'un coup. Plus besoin de créer l'élément sur
  `/catalogue` puis de revenir le décrire ici : l'aller-retour était la seule
  raison de quitter la table.
- Le type se choisit dans une **datalist** alimentée par les types déjà
  présents en base *et* les types par défaut — comme sur `/catalogue`.
- **Doublon refusé** sur le couple (type, nom), avec message : le carnet croise
  les sessions par comparaison exacte du nom, deux fiches homonymes le
  rendraient ambigu.

### 🔧 Détail
Les deux formulaires de la page — l'ajout et l'enregistrement de la table —
postent sur la même route, distingués par un champ `action`. Les imbriquer
aurait donné du HTML invalide ; une seconde route aurait éclaté en deux
endroits ce qui se lit comme une seule page.

### ✅ Tests
3 tests ajoutés (création + normalisation du type, refus des doublons, non-
confusion entre ajout et enregistrement). Suite : **84 passants**.

---

## v3.18.1 — 2026-09-08 — Les fiches sur papier

### ✨ Nouveautés
- **`/catalogue/fiches/print`** — tirage **A4 paysage** de la vue table, groupé
  par type, en-tête de colonnes répété à chaque page, pas de ligne coupée en
  deux entre deux feuilles. Même mise en page « papier » que l'impression de
  session (v1.x) : IBM Plex, encre sur crème, en-tête et pied de document.
- **Le tirage suit les filtres de l'écran** (`?q=`, `?type=`, `?todo=1`) — le
  bouton ⎙ construit l'URL depuis les filtres actifs. Imprimer, c'est imprimer
  ce qu'on regarde.
- **Les cases vides sortent réglées**, deux lignes pointillées par cellule :
  c'est tout l'intérêt d'imprimer des fiches incomplètes — les remplir au stylo
  pendant une session, les ressaisir après.
- Cliquer ⎙ avec des modifications non enregistrées **prévient** : la page
  d'impression relit la base et ignorerait ce qui est tapé.

### ✅ Tests
2 tests ajoutés (rendu papier, respect des filtres). Suite : **81 passants**.

---

## v3.18.0 — 2026-09-08 — Fiches matériel : ce que c'est, ce que j'en fais

### ✨ Nouveautés
- **Vue table `/catalogue/fiches`** — une ligne par machine, effet, plugin ou
  synthé iOS, avec **fabricant**, **à quoi ça sert** et **comment je compte
  m'en servir**. Éditable en place : les trois colonnes sont des champs, la
  table entière s'enregistre d'un bouton (ou `Ctrl/Cmd+S`).
- Filtres : recherche libre (nom, fabricant, **et** le texte des deux nouveaux
  champs), filtre par type, et **« à compléter seulement »** — utile quand 39
  fiches sur 39 attendent encore leur description.
- Les lignes modifiées se signalent avant l'enregistrement, et quitter la page
  sans enregistrer demande confirmation.
- Le **carnet d'instrument** (`/catalogue/<id>`) relit les deux champs en tête
  de fiche, et renvoie vers la vue table quand ils sont vides.

### 🗃 Base
- `catalogue` gagne `purpose` et `intent` (migration `ALTER TABLE`, valeurs
  vides par défaut). **Pas de table séparée** : ce sont des propriétés de la
  machine, pas des événements datés comme les remarques du carnet — une
  seconde table aurait imposé un JOIN pour lire deux colonnes.

### ⚠️ Pourquoi deux champs et pas un
« À quoi ça sert » est objectif et se recopie d'une notice ; « comment je m'en
sers » est une décision — le rôle qu'on assigne à la machine dans ses propres
sessions. Les fondre en un seul champ aurait laissé la seconde question sans
réponse, celle qui rend le catalogue utile au moment de choisir quoi brancher.

### 🔧 Détail
- La table se soumet entière, mais le moteur n'écrit **que les lignes
  modifiées** — filtrer l'affichage ne perd donc rien de ce qui a été saisi
  avant de filtrer.

### ✅ Tests
5 tests ajoutés (colonnes, écriture sélective, ids invalides, routes GET/POST,
relecture depuis le carnet). Suite complète : **79 tests passants**.

---

## v3.17.0 — 2026-08-29 — Puces matériel sur /vite : la boucle se ferme

### ✨ Nouveautés
- **Le matériel se choisit d'un clic** sur `/vite` — puces issues du catalogue,
  au lieu d'un champ à taper. Favoris (★) d'abord, puis ce qui a servi le plus
  récemment, puis l'alphabet ; les 10 premières sont visibles, le reste tient
  dans un repli.
- Le tri par usage évite d'avoir à marquer des favoris à la main pour que la
  liste devienne utile : **elle le devient en s'en servant**.
- Chaque type alimente **sa** colonne de session (`machine` → `machines`,
  `effet` → `effects`, `plugin` / `plugin_ios` → `plugins`,
  `synth_ios` → `synths_ios`). Un champ libre subsiste pour le hors-catalogue,
  fusionné dans `machines`.

### ⚠️ Pourquoi ça compte plus que le confort
Le carnet d'instrument (v3.16.0) croise les sessions par **comparaison exacte**.
Un nom tapé à la main — « microfreak », « Micro Freak » — ne serait jamais
remonté sur la fiche. Les puces envoient le nom tel qu'il figure au catalogue,
ce qui rend le lien fiable au lieu d'aléatoire. **C'était le maillon manquant**
entre la saisie rapide et le carnet : sans lui, la fiche ne se remplissait que
si on orthographiait juste.

Vérifié de bout en bout : une session créée depuis `/vite` avec la puce
MicroFreak apparaît immédiatement sur `/catalogue/1`.

---

## v3.16.0 — 2026-08-29 — Le carnet lit les sessions, le formulaire se replie

### ✨ Le carnet d'instrument se remplit tout seul
- **« ♪ Sessions où elle a joué »** sur `/catalogue/<id>` — la fiche liste les
  sessions qui la mentionnent, **sans aucune saisie supplémentaire** :
  l'information était déjà dans le champ matériel des sessions, elle n'avait
  simplement nulle part où se lire depuis la machine. La fiche du MicroFreak
  affiche désormais « Drone Dark Ambient ★★★ » sans qu'on ait rien tapé.
- ⚠️ Filtrage en deux temps — `LIKE` large en SQL, puis comparaison **exacte**
  élément par élément en Python. Le `LIKE` seul confondrait « Volca Drum » et
  « Volca Kick » dès qu'on chercherait « Volca », et ferait correspondre tout
  nom court contenu dans un autre. Deux tests verrouillent ce piège.
- Les sept colonnes matériel sont balayées (`machines`, `effects`, `daws`,
  `synths_ios`, `plugins`, `ipad`, `zynthian`) : une fiche citée comme effet est
  trouvée comme une citée comme machine.

### 🧩 Le formulaire complet ne fait plus mur
- **Six sections repliées par défaut** — Caractère sonore, Technique, Capture,
  Influences, Univers AZA, Projet. Contexte et Évaluation restent ouverts.
- L'état d'ouverture est **retenu par section** : le formulaire s'adapte à la
  façon dont on s'en sert.
- ⚠️ **Une section contenant un champ déjà rempli s'ouvre d'office** — brouillon
  restauré, duplication de session. Cacher une valeur saisie serait pire que le
  mur de 45 champs.
- Repli au clavier aussi (`Enter` / `Espace`, `aria-expanded`).

---

## v3.15.2 — 2026-08-29 — Retrait de la dictée sur /vite

### 🧹 Retiré
- **Bouton 🎙 et transcription supprimés de `/vite`.** Décision d'usage : le
  clavier est préféré, la dictée ne servait pas. La saisie minimale garde donc
  une seule zone de texte et rien d'autre — ce qui était le but.

ℹ️ `/live` conserve son bouton micro, et `core/whisper_client.py` comme
`/live/transcribe` restent en place pour lui. Le conteneur Docker `whisper`
installé plus tôt dans la journée n'a donc plus qu'un seul appelant, lui-même
inutilisé (`live_session` : 0 ligne).

---

## v3.15.1 — 2026-08-29 — La dictée dit enfin pourquoi elle ne marche pas

### 🐛 Correctif
`getUserMedia` n'existe **que dans un contexte sécurisé** — https, ou localhost.
Servie en http sur l'IP Tailscale (`http://100.64.201.127:5001`),
`navigator.mediaDevices` est `undefined` : le bouton 🎙 de `/vite` tombait dans
son `catch` et affichait **« micro refusé »**, accusant le navigateur d'un refus
qui n'avait jamais eu lieu. Sur `live.html`, un `return` silencieux laissait un
bouton inerte sans explication.

Les deux détectent maintenant le contexte : bouton désactivé, libellé explicite,
et sur `/vite` un lien direct vers la même page en `https://sessions.robotariis.com`
— où la dictée fonctionne réellement.

ℹ️ Rien à changer côté serveur : le tunnel Cloudflare sert déjà l'app en https.
C'est l'accès par l'IP en clair qui empêche le micro, pas l'application.

---

## v3.15.0 — 2026-08-29 — ⚡ Vite : saisie minimale

### ✨ Nouveautés
- **`/vite`** — une page, une zone de texte. Le formulaire complet compte
  **45 champs** ; celui-ci n'en demande qu'un, et deux facultatifs (titre,
  machines). La date est automatique, le type vaut `music` par défaut.
- **Dictée intégrée** — bouton 🎙 branché sur `/live/transcribe` (Whisper), qui
  n'était jusqu'ici accessible que depuis le module `live`. Parler coûte moins
  que taper.
- **Brouillon sauvegardé à chaque frappe** dans `localStorage`, restauré au
  retour, effacé à l'enregistrement. Aucun bouton à presser pour ça.
- Entrée « ⚡ Vite » en tête du menu Sessions.

### ⚠️ Choix de conception
**La création ne génère aucun récap.** Attendre ~5 s au moment de valider
annulerait l'intérêt d'une saisie rapide. Le récap se demande ensuite depuis la
vue de la session (v3.14.0), en un bouton — ou jamais. Un test verrouille ce
comportement.

`SessionsEngine.create()` renvoie désormais l'id créé (il ne renvoyait rien),
sans quoi on ne saurait pas vers quelle session rediriger.

---

## v3.14.0 — 2026-08-29 — Le récap enfin atteignable

### 🐛 Le fond du problème
Le récap Ollama n'était appelé qu'à **un seul endroit** : `sessions/api.py`, dans
la branche `/new?from_live=1`. Une session saisie normalement n'en recevait donc
jamais — et comme le module `live` n'a jamais servi (`live_session` : 0 ligne),
la fonctionnalité n'a **en pratique jamais tourné**. Les deux sessions de la base
ont `recap_claude` vide.

Vérifié le 2026-08-29 : le moteur fonctionne (`qwen3.5:cloud` répond en ~5 s,
~790 caractères dans la voix de l'univers). Ce n'était pas cassé, c'était
inaccessible.

### ✨ Nouveautés
- **`POST /session/<id>/recap`** — génère ou régénère le récap d'une session
  existante, l'écrit en base et le renvoie.
- **Bouton dans la vue session** — « ∙ Générer » quand le récap est absent,
  « ↻ Régénérer » sinon. Appel AJAX avec le toast déjà utilisé pour l'export
  Obsidian ; la carte Récap s'affiche désormais **même vide**, sinon le bouton
  n'aurait eu nulle part où vivre.
- **`SessionsEngine.set_recap()`** — écrit la seule colonne `recap_claude`
  plutôt que de repasser par `update()`, qui relirait et réécrirait les 31
  colonnes pour n'en changer qu'une.

### 🛡 Échec bruyant
Un Ollama muet renvoie désormais **502 avec un message**, jamais un succès vide.
C'est le point qui avait coûté des semaines : un appel LLM qui échoue en silence
ne se voit pas depuis l'interface. Couvert par un test dédié.

ℹ️ Appel synchrone assumé (~5 s) : le service tourne en `--workers 1`, donc l'app
est bloquée pendant la génération. Une file d'attente serait disproportionnée ici.

---

## v3.13.1 — 2026-08-29 — Ménage : les restes de Fly.io

### 🧹 Nettoyage
- **`fly.toml` retiré** et **branche `FLY_APP_NAME` supprimée de `wsgi.py`.** Le
  déploiement Fly est abandonné ; ce bloc redirigeait encore `DB_PATH` et
  `BACKUPS_DIR` vers `/data` si la variable apparaissait — un chemin qui
  n'existe pas sur Roblab, donc une base créée ailleurs sans que rien ne le dise.
- **`dim/` supprimé** — dossier vide depuis que le Prompteur est parti chez D.I.M
  (v3.12.0), plus rien ne l'importait.
- `wsgi.py` documente maintenant son rôle : c'est le chemin réel en production,
  le bloc `__main__` de `app.py` ne tourne jamais sous Gunicorn.
- README recalé : v3.5.0 → v3.13.0, lien « Live » vers `sessions.robotariis.com`
  au lieu de l'URL Fly morte, et procédure de déploiement systemd.

ℹ️ Le `Dockerfile` est conservé : il ne servait qu'au build Fly et n'est plus
utilisé, mais il ne gêne pas.

---

## v3.13.0 — 2026-08-29 — Carnet d'instrument

### ✨ Nouveautés
- **Carnet par instrument** `/catalogue/<id>` — le catalogue n'avait qu'une liste,
  aucune page par fiche. Chaque machine, plugin ou effet a désormais la sienne, qui
  rassemble ce qu'on finit par savoir d'un instrument à force de s'en servir.
  - **★ Patches favoris** — repris du module **Presets** (v3.7.0), triés par note.
    Pas de seconde table : la même information n'a qu'un seul endroit où vivre, et
    ça donne enfin une raison de remplir `preset_notes`, restée vide depuis mai.
  - **⇄ Marche bien avec** — associations entre deux fiches du catalogue, avec la
    raison. Une relation et non du texte libre : l'effet nommé une fois reste lié
    même si la fiche est renommée. **L'association se lit des deux côtés** — dire
    « le MicroFreak passe bien dans le NTS-1 » l'affiche aussi sur la fiche du
    NTS-1, sans double saisie (`UNION` sur les deux sens dans `pairings()`).
  - **✎ Remarques d'utilisation** — journal horodaté qui s'empile, pas un champ
    qu'on réécrit : apprendre une machine se fait par couches, et écraser la
    remarque précédente perdrait le chemin parcouru.
- Bouton ◧ sur chaque ligne du catalogue pour ouvrir le carnet.

### ♻️ DB
- `gear_pairings` (gear_id, partner_id, note) et `gear_notes` (gear_id, date, note),
  créées par `init_db` — migration transparente, rien à faire sur une base existante.

### 🛡 Garde-fous
- Association à soi-même refusée ; doublon refusé **dans les deux sens** ; remarque
  vide refusée ; fiche inexistante → redirection vers le catalogue, pas une 500.

---

## v3.12.1 — 2026-08-29 — Durcissement de la sauvegarde automatique

Le backup tournait déjà des deux côtés (bloc `__main__` de `app.py` en local,
bloc inline de `wsgi.py` sous Gunicorn), mais en **double exemplaire** et avec
deux fragilités.

### ♻️ Refactor
- **`core/backup.py`** — une seule implémentation, appelée par `app.py` et `wsgi.py`.
  Les deux blocs inline disparaissent.
- `BACKUPS_DIR` remonte dans `app.config`, au même titre que `DB_PATH` et `CONFIG_PATH`.
- `app.py` : imports `glob`, `shutil`, `datetime` devenus inutiles, retirés.

### 🐛 Correctifs
- **Snapshot via `sqlite3.Connection.backup()` au lieu de `shutil.copy2`.** Sous
  Gunicorn l'app sert déjà des requêtes au moment du boot ; copier le fichier
  pendant une écriture donne une base déchirée. Vérifié : un snapshot pris
  pendant une transaction ouverte non committée rend une base à
  `integrity_check: ok`, sans l'écriture en cours.
- **La rétention ne survivait pas à un crash-loop.** `aza-sessions.service` tourne
  en `Restart=always` : cinq relances rapides suffisaient à évincer les cinq
  backups et à ne garder que des copies de l'état cassé — le filet disparaissait
  au moment précis où il aurait servi. Le snapshot est désormais **sauté si la base
  est inchangée** (SHA-256 contre le dernier backup). Vérifié : trois boots
  consécutifs sur base identique ne produisent qu'un seul fichier.
- Écriture par fichier temporaire puis `os.replace` — un processus tué en cours
  ne laisse plus de backup partiel.
## v3.12.0 — 2026-08-09 — Le Prompteur quitte AZA pour D.I.M

> ⚠️ Entrée ajoutée après coup le 2026-08-29. Cette version était documentée
> dans `ROADMAP.md` mais **absente du CHANGELOG**, et `VERSION` dans `app.py`
> était resté à 3.10.0 — deux releases de retard. C'est ce décalage qui a fait
> numéroter le carnet d'instrument « v3.12.0 » par erreur, sur un numéro déjà pris.
>
> Le détail de ce qui a été déplacé vit dans le ROADMAP (blueprint `dim/`,
> 3 templates, table `prompter_scripts` et `core/link_service.py` retirés,
> −1 976 lignes). Résumé repris ici pour que la suite des versions soit continue,
> **à compléter par Olivier** s'il veut le détail au même niveau que les autres.

- **Le Prompteur et l'axe Ableton Link partent chez D.I.M.** AZA est le journal
  (avant, pendant, après une session) ; D.I.M est le séquenceur de performance.

---

## v3.11.0 — 2026-08-08 — Ableton Link : le Prompteur sur la grille

### ✨ Nouveautés
- **Pair Ableton Link** — `core/link_service.py` tient un pair unique pour le processus ; `GET /api/link/state` renvoie tempo, beat, phase, nombre de pairs et `next_downbeat_s`
- **Affichage tempo dans la topbar du Prompteur** — pastille battant sur le temps, BPM, nombre de pairs. Le widget se cache tant qu'aucun pair n'est vu
- **Quantize des cues** — bouton ⊟ Quantize : l'avance **automatique** attend le prochain temps fort, la barre de temps restant pulse pendant l'attente. État retenu en localStorage

### ⚠️ À savoir
- **`abletonlink` n'existe pas** sur PyPI, malgré ce que la roadmap annonçait — la bibliothèque est **`LinkPython-extern`**, ajoutée en dépendance **optionnelle** : sans elle l'app dégrade en silence
- **Seule l'avance automatique est quantifiée.** Un appui manuel reste instantané — attendre donnerait l'impression d'un bouton cassé
- **Le quantize relit `next_downbeat_s` au moment d'avancer**, jamais la phase extrapolée du widget : celle-ci dérive sans borne et ne sert qu'à l'animation
- **`--workers 1` devient une contrainte** : chaque instance Link apparaît comme un appareil distinct sur le réseau, deux workers dédoubleraient l'app dans la session de tous les musiciens
- Trois échappatoires empêchent tout blocage en set : pas de pair · requête > 400 ms · délai annoncé supérieur à une mesure

### 🧪 Validé contre un Ableton Live distant
Découverte en 2 s, tempo lu (115 BPM), phase exacte, **écriture fonctionnelle** (tempo poussé puis ramené). ⚠️ Deux écritures ont échoué en silence avant qu'une troisième passe — `set_tempo()` relit donc systématiquement et renvoie `ok: False` en cas d'échec.

---

## v3.10.0 — 2026-06-27 — Idées en vrac & SPARK

### ✨ Nouveautés
- **Idées en vrac** — la page `/inspirations` est recadrée en « 💡 Idées en vrac » (titre, nav « Idées en vrac ») ; nouveau type `Idée` (placé en tête de `INSPI_TYPES`) pour distinguer les idées brutes des autres sources
- **SPARK pioche dans les idées** — `SparkEngine.focus()` et `suggestions()` font remonter en priorité les entrées de type `Idée` (pondérées ×2 dans le pool focus), badge « 💡 Idée en vrac » ; la dédup `type|text` et l'historique session `SEEN_MAX=8` restent inchangés

### 🛠 Qualité
- **Tests** — `tests/test_spark_ideas.py` (type Idée, focus la propose, dédup exclut une idée vue, suggestions la fait remonter, page recadrée)

---

## v3.9.0 — 2026-06-27 — Sessions typées : musique / lore / veille & code

### ✨ Nouveautés
- **Type de session** — colonne `session_type` (`music` par défaut / `lore` / `veille`) ; sélecteur en onglets en tête du formulaire `/new` et `/edit`
- **Formulaire conditionnel** — les sections s'affichent selon le type (JS, sans rechargement) : le matériel/technique/capture n'apparaît qu'en mode musique ; lore et veille réutilisent titre, lien (libellé contextuel « Lien lore » / « Lien / Référence »), notes libres, caractère, tags, évaluation — aucune colonne texte superflue
- **Sections matériel iPad & Zynthian** — nouvelles colonnes `sessions.ipad` et `sessions.zynthian`, sections check-grid dédiées (groupées par fabricant), affichées dans la vue et l'export si renseignées
- **Anti-surcharge du formulaire** — barre de filtre matériel : recherche instantanée par nom + bascule « ★ favoris seulement » ; favoris remontés en tête (tri `favorite DESC`) et marqués d'une étoile
- **Filtre & badge par type** — select « Type » dans la recherche `/search` ; badge ✎ Lore / ⚙ Veille sur l'index et la vue session
- **Recap Ollama par type** — prompts dédiés lore (récit) et veille (résumé factuel) en plus du prompt musical

### 🛠 Infra & Qualité
- **`ITEM_TYPES` unifié** — source unique dans `core/constants.py` (suppression du doublon dans `catalogue/engine.py`)
- Migrations `sessions.session_type` / `ipad` / `zynthian` (CREATE + ALTER)
- **Tests** — `tests/test_session_types.py` (colonnes, défaut music, round-trip iPad/Zynthian, filtre recherche, export CSV)

---

## v3.8.0 — 2026-06-27 — Catalogue : saisie rapide, favoris & types dédiés

### ✨ Nouveautés
- **Saisie rapide multi-lignes** — bloc « ⊞ Saisie rapide » sur `/catalogue` : on choisit le type une fois puis on saisit plusieurs items (fabricant / nom / notes) d'un coup ; bouton « + Ligne », `Entrée` dans le champ nom ajoute une ligne ; insertion transactionnelle avec dédup `(type, nom)` et message `N ajoutés / M doublons ignorés`
- **Favoris catalogue** — étoile ★/☆ par item, remontés en tête de chaque type (tri `favorite DESC`) ; filtre « ★ favoris seulement »
- **Types dédiés** — `ipad` (Apps iPad) et `zynthian` (Zynthian / Raspberry Pi) ajoutés à `ITEM_TYPES` (type toujours libre)
- **Filtres & sections repliables** — recherche instantanée (nom/fabricant), filtre par type, sections `<details>` repliables pour désengorger la page

### 🛠 Infra & Qualité
- **Messages flash globaux** — rendu centralisé dans `base.html` (bénéficie aussi au module DIM)
- **Tests** — `tests/test_catalogue.py` (favoris, types dédiés, `add_bulk` + dédup, routes bulk/favorite)
- Migration `catalogue.favorite` (CREATE + ALTER)

---

## v3.7.2 — 2026-06-03 — Spark : contrainte unique + fix DIM

### ✨ Nouveautés
- **Spark contrainte unique** — historique en session Flask pour éviter les répétitions ; limite `SEEN_MAX = 8`, réutilisation après épuisement du pool
- **Port DIM configurable** via variable d'environnement `DIM_PORT` (défaut 5002, ajusté au port réel du service DIM)

### 🐛 Corrections
- **backup DB au démarrage Gunicorn** — le code sous `__main__` ne tourne pas en WSGI ; migration dans `wsgi.py`
- **retire sessions.db du tracking git** — fichier ignoré mais encore suivi ; suppression de l'index git

---

## v3.7.1 — 2026-05-23 — Vue compacte + tests

### ✨ Nouveautés
- **Vue compacte sessions** — grille alternée `compact.html` : ligne date+temps à gauche, titre/commentaire à droite, icônes machines, tags, lien Lore cliquable
- **Heatmap cliquable** sur l'index — cartographie des intensités sonores par session (rouge/vert/bleu selon le niveau de bruit signalé), survol affiche la date, clic va directement à la session

### 🛠 Qualité
- **Smoke tests** — couvre toutes les 18 routes blueprints (Flask client factory)

---

## v3.7.0 — 2026-05-16 — Carnet de Presets

### ✨ Nouveautés
- **Module Presets** — carnet de notes par preset/patch : instrument lié (catalogue), nom du preset, ce qu'il évoque, idée de morceau, influence rappelée, note ★, tags, session liée, notes libres
- **Stats presets** — par instrument/plugin : nombre de presets notés, moyenne ★, top presets mieux notés
- **Filtres presets** — par instrument et recherche textuelle (nom, évocation, idée, tags, influence)

---

## v3.6.1 — 2026-05-16 — Réécriture recap Ollama

### ✨ Nouveautés
- **Bouton ✦ Réécrire** sur la vue session — envoie le `recap_claude` à Ollama (`qwen3.5`, t=0.3) pour correction orthographique et reformulation ; conserve le style, la longueur et l'atmosphère AZA ; silencieux si Ollama indisponible

---

## v3.6.0 — 2026-05-16 — Responsive + FTS5 + Infra Roblab

### ✨ Nouveautés
- **Recherche full-text SQLite FTS5** — 15 champs indexés (title, machines, effects, daws, synths_ios, plugins, patches, tags, comments, influences, recap_claude, lore_link, signal_routing, oblique, intention) ; triggers INSERT/UPDATE/DELETE pour sync automatique ; fallback Python si indisponible ; tri par pertinence
- **Responsive complet** — 19 templates adaptés mobile/tablette/PC ; grids fixes → responsive ; touch targets 44px ; prompteur et vue live utilisables au pouce

### 🛠 Infra & Qualité
- **Migration Fly.io → Roblab** — service `aza-sessions.service` (Gunicorn port 5001) ; `sessions.lan` + `sessions.robotariis.com` via Cloudflare Tunnel
- **Linter ruff** — `ruff.toml`, zéro erreur
- **Suite pytest** — 15 tests (smoke routes + DB init/schema)

### 🐛 Corrections
- **Export SVG/PDF patcher** — reset du transform `g-root` avant export → viewBox correctement centré sur le contenu
- **Migration `manufacturer`** — colonne manquante dans `init_db()` causant un crash sur DB fraîche
- **Apostrophe Jinja2** — `about.html` template syntax error sur `d'ensemble`

---

## v3.5.0 — 2026-05-10 — Patcher v2 : polish & puissance

### ✨ Nouveautés
- **Dupliquer un layout** — bouton `⎘ Dupliquer` dans la liste ; copie complète nœuds + connexions (mapping IDs), ouvre directement la copie nommée `[nom] (copie)`
- **Snap-to-grid** — toggle `⊞ Grid` (toolbar + touche `G`) ; grille de points 20px visible quand actif ; snapping mouse + touch ; état persisté en localStorage
- **Connexions multi-type simultanées** — plusieurs câbles entre la même paire de nœuds (ex: audio + MIDI) s'écartent perpendiculairement (±16px par index) ; chaque câble conserve sa couleur et sa flèche
- **Minimap** — overlay bas-gauche 180×110px ; nœuds colorés par type, connexions filaires par signal, rectangle viewport accent ; clic → centre la vue principale ; toggle `⊟ Map` (toolbar + touche `M`) ; état persisté en localStorage

---

## v3.4.0 — 2026-05-10 — Dictée vocale live via Whisper local

### ✨ Nouveautés
- **Bouton 🎙 Dicter** dans la page session live — enregistre via `MediaRecorder`, transcrit via Whisper GPU local et insère le texte dans les notes live
- Route `/live/transcribe` (POST multipart) → `core/whisper_client.py` → Whisper `small` (GPU, RTX 3060, port 9000)
- Modèle upgradé `base` → `small` pour une meilleure précision sur le français
- Silencieux si Whisper indisponible (fallback erreur inline)

---

## v3.3.0 — 2026-05-10 — Recap session auto via Ollama (LLM local)

### ✨ Nouveautés
- **Génération automatique de `recap_claude`** à la fin d'une session live
  - À l'ouverture de `/new?from_live=1`, le champ *Récap session* est pré-rempli par `qwen3.5:latest` (Ollama, `192.168.1.100`)
  - Le récap est narratif, à la première personne, dans le style AZA (Dark Ambient / Industriel, Scaër)
  - Le client `core/ollama_client.py` est réutilisable pour les futures intégrations LLM local
  - Silencieux en cas d'indisponibilité du serveur (fallback champ vide)
  - `notes_live` désormais incluses dans le prefill pour enrichir le contexte du prompt

---

## v3.2.0 — 2026-05-09 — Module SysEx Loader & Bank Editor

### ✨ Nouveautés
- **Module ⎍ SysEx** `/sysex` — loader DX7 / Volca FM via Web MIDI API (Chrome)
  - Détection automatique des interfaces MIDI (`requestMIDIAccess({sysex:true})`)
  - Chargement `.syx` par glisser-déposer ou file picker
  - Preview des 32 noms de patches parsés depuis le bulk dump DX7 packed (128 bytes/voix)
  - Canal MIDI 1-16 réglable — byte `0n` réécrit dans le header avant envoi
  - Test connexion : phrase C3→E3→G3→C4→E4→G4→C5→G4→C4 (arpège majeur, 3 octaves)
  - Librairie de banks : save / load / download / delete (BLOB SQLite, table `sysex_banks`)
- **⎍ Bank Editor** `/sysex/editor` — patch librarian custom bank
  - Deux colonnes : Source (bank chargée) | Custom Bank (32 slots)
  - `[+]` par patch ou `[+ Tous]` pour alimenter la custom bank
  - Swapper la source sans perdre la custom bank en cours
  - Réordonnancement ↑ ↓ ✕ par slot
  - Slots vides comblés par une init voice (OP1 actif, silence)
  - Export `.syx` client-side (assemblage bulk DX7 + checksum 2's complement en JS)
  - Envoi direct via Web MIDI depuis l'éditeur
  - Sauvegarde dans la librairie existante

### ♻️ DB
- Migration `CREATE TABLE IF NOT EXISTS sysex_banks` (name, format, size, data BLOB)

---

## v3.1.0 — 2026-05-09 — Release Patcher complète

Clôture du cycle v3.0.x-alpha. Stabilisation et complétion du module Patcher.

### ✨ Nouveautés
- **Patcher → Session** — bouton `→ Session` dans la toolbar du Patcher : pré-remplit le formulaire Nouvelle Session avec les nœuds par type (machines, effets, DAW, iOS, plugins) et génère automatiquement le champ `signal_routing` depuis le graphe de connexions (DFS source → feuilles, format `A → B → C`, max 4 chemins)
- **Mode Navigation / Édition** (mobile) — toggle `✎ Éditer` / `⊙ Naviguer` : en mode Navigation la page défile normalement, en mode Édition le canvas capte tous les gestes tactiles. Bouton flottant `↑ Menu` pour sortir du mode Édition sans chercher le bandeau
- **Centrage automatique** du canvas au chargement — `centerContent()` cale le layout dans le viewport (pan + zoom ajustés)
- **Pinch-to-zoom** mobile sur le canvas — 2 doigts, ancré sur le milieu des touches

### 🐛 Corrections
- **`SECRET_KEY` manquant** — `flask.session` crashait en production Fly.io (500 sur `→ Session` et tout redirect avec prefill via session). Ajout de `app.secret_key = os.environ.get("SECRET_KEY", "aza-sessions-local-dev")`
- Export JSON portabilité — connexions sérialisées avec `from_index` / `to_index` (numéro dans la liste des nœuds, sans dépendance aux IDs DB)

---

## v3.0.1-alpha — 2026-05-09 — Patcher : import/export JSON + types dynamiques

### ✨ Nouveautés
- **Export JSON** (`⬇ Export ▾ → { } JSON`) — sérialise nœuds + connexions avec `from_index`/`to_index` (portable, sans dépendance aux IDs DB)
- **Import JSON** — formulaire dans la liste des patches ; crée un nouveau layout complet depuis un `.json` exporté
- **Export Mermaid .md** — `graph LR` avec flèches typées et tables nœuds/connexions
- **Export SVG** — standalone avec CSS vars résolus et polices Google Fonts embarquées
- **Export PDF** — via `window.print()` paysage
- **Types custom** dans le catalogue (`synth_android`, `fx_android`, etc.) — le patcher suit automatiquement (couleur par hash, icône générique `◈`)
- **Icônes par type** et **note courte** affichées dans chaque nœud du canvas
- **Barre de propriétés inline** — label, type, note éditables en bas de canvas sans popup

### 🐛 Corrections / migrations
- Migration `ALTER TABLE patch_nodes ADD COLUMN note TEXT DEFAULT ''`
- Migration `ALTER TABLE patch_connections ADD COLUMN note TEXT DEFAULT ''`

---

## v3.0.0-alpha — 2026-05-09 — Module Patcher + finalisation architecture

### ✨ Nouveautés
- **Module Patcher** `/patcher` — mind map SVG interactif pour documenter le patching
  - Nœuds drag & drop : machines, effets, DAW, iOS, plugins (couleurs par type)
  - Connexions courbes avec flèches typées : audio (orange), MIDI (bleu), CV (vert), USB (violet)
  - Import auto depuis une session liée ou depuis tout le catalogue actif (AJAX)
  - Mode connexion (touche `C`), double-clic édition label, `Del` suppression
  - Autosave AJAX 1,5 s, rename inline, layouts nommés et multiples
  - Lien `⬡ Patcher` depuis chaque vue session
  - Tables `patch_layouts`, `patch_nodes`, `patch_connections`

### ♻️ Architecture
- **`app.py` 116 lignes** — `init_db()` + données par défaut déplacés dans `core/init_db.py`
- **`wsgi.py`** corrigé : `init_db(DB_PATH)` après extraction dans `core/`
- **`fly.toml`** : `dockerfile = "Dockerfile"` explicite (fix deploy Fly.io)
- **`.gitignore`** : ajout `backups/` et `config.json`
- **`.dockerignore`** : ajout `.claude/` — exclut les git worktrees du build context Fly.io

---

## v2.5.0 — 2026-05-05 — Release finale v2.x

Version de stabilisation et de complétude du cycle v2. Clôture le roadmap avant la v3.

### ✨ Nouveautés
- **Pagination liste sessions** — 25 sessions par page, server-side (LIMIT/OFFSET SQLite) ; barre prev/next + numéros avec ellipsis ; compatible avec la recherche ; subtitle affiche le total et la page courante
- **Révéler dans Finder** — bouton `⌕` dans la vue session : ouvre Finder et sélectionne le fichier audio (`open -R <chemin>`) ; route `GET /session/<id>/reveal`
- **Export direct vers vault Obsidian** — bouton `⬡ Vault` (AJAX `POST /session/<id>/obsidian`) : écrit le Markdown dans le dossier vault configuré ; toast succès/erreur 3 s
- **Configuration vault** dans les Paramètres — champ chemin absolu, sauvegardé dans `config.json`

### 🐛 Corrections
- **Widget Pomodoro restauré** — classe CSS `.pomo { position:fixed; … }` perdue lors d'une refacto ; réinjectée
- **Zoom A+ / A−** fonctionnel — l'implémentation `document.documentElement.style.fontSize` n'affectait que les unités `rem` (CSS entièrement en `px`) ; remplacé par `document.body.style.zoom`
- **Theme picker** toujours accessible mobile/tablette — déplacé hors de la `<nav>` (drawer hamburger) dans la barre header ; `position:fixed` sur le dropdown pour éviter le clipping `overflow`
- **Suppression du double `#theme-dropdown`** — IDs dupliqués entre l'ancien picker (dans nav) et le nouveau (dans header)

---

## v2.4.0 — 2026-05-09 — Refactorisation complète en Blueprints

### ♻️ Extraction des modules restants
- **`projects/`** — Blueprint 5 routes : liste, new, view, edit, delete (+ détachement sessions)
- **`settings_app/`** — Blueprint 4 routes : settings, backup, import DB, reset sessions
- **`samples/`** — Blueprint CRUD sample banks
- **`tracks/`** — Blueprint CRUD morceaux inspirants
- **`wishlist/`** — Blueprint CRUD wishlist matériel (+ toggle acquired)
- **`inspirations/`** — Blueprint CRUD inspirations
- **`mirack/`** — Blueprint CRUD modules MiRack (+ toggle mastered/favorite)
- **`about/`** — Blueprint route `/about`
- **`stats/`** + **`live/`** — extraits en v2.1.x
- `app.py` réduit à ~260 lignes (launcher + init_db + context processor + banner)
- Tous les `url_for` dans les templates namespaced (`projects.list_projects`, `settings_app.settings`, etc.)
- `core/constants.py` enrichi : SAMPLE_TYPES, MIRACK_CATS, WISHLIST_TYPES, WISHLIST_PRIOS, INSPI_TYPES

### ✨ Comportement inchangé — zéro régression UI (16/16 routes OK)

---

## v2.2.0 — 2026-05-04 — Fabricants + ajout inline catalogue

### ✨ Nouveautés
- **Colonne `manufacturer`** sur la table `catalogue` (migration automatique `ALTER TABLE`)
- **Ajout inline depuis le formulaire session** — bouton `+ Ajouter` par section (Machines, Effets, DAW, iOS, Plugins) ouvre un modal AJAX ; l'item est injecté et coché immédiatement sans perdre la session en cours — valable sur `new.html` et `edit.html`
- **Classement par fabricant** partout : formulaires new/edit (groupby avec séparateurs), page catalogue (tri + champ éditable en ligne), formulaire vierge (fabricant en texte secondaire)
- **Datalist fabricants** dans le modal — autocomplétion sur les fabricants déjà connus
- **Endpoint JSON** `POST /api/catalogue/add` — `CatalogueEngine.add_inline()`
- **Autosave brouillon** sur `new.html` — sauvegarde silencieuse en `localStorage` à chaque frappe, restauration au chargement avec bandeau "↩ Brouillon restauré", effacement au submit

---

## v2.1.0 — 2026-05-03 — Architecture modulaire (Blueprints)

### ♻️ Refactorisation architecture
- **`core/`** — utilitaires partagés : `db.py` (get_db), `oblique.py` (rand_oblique), `constants.py` (toutes les listes de référence)
- **`sessions/`** — Blueprint complet : index, new, view, edit, delete, form_blank, print, export MD/CSV/Obsidian, settings Obsidian, search
- **`catalogue/`** — Blueprint standalone (GET/POST `/catalogue`)
- **`obliques/`** — Blueprint standalone (`/oblique` JSON + `/obliques` CRUD)
- **`influences/`** — Blueprint standalone (GET/POST `/influences`)
- **`spark/`** — Blueprint standalone (`/spark`, `/spark/focus`)
- **`dim/`** — Blueprint standalone D.I.M Lite (7 routes `/prompter`)
- `app.py` réduit au rôle de launcher + `init_db` + modules non encore extraits

### ✨ Comportement inchangé — zéro régression UI

---

## v2.0.1 — 2026-05-01 — Hotfix UI

### 🐛 Corrections
- **Menu hamburger iPad** — breakpoint relevé de 600px à 1024px : le menu hamburger s'active maintenant sur tous les iPads (portrait et paysage) au lieu d'afficher la nav desktop tronquée
- Liens du drawer agrandis (padding 13px) pour meilleure ergonomie tactile

### ✨ Améliorations
- **Boutons zoom global A+ / A−** ajoutés dans la barre de menu — toujours visibles, plage 70 % à 160 %, persisté en localStorage

---

## v2.0.0 — 2026-05-01 — Release majeure

La version 2.0 marque le passage d'un outil de documentation locale à une
**plateforme de performance Dawless complète**, déployée en production sur Fly.io.

### ⬡ Prompteur Dawless — module complet
- Création, édition, suppression de scripts de set (titre, description, cues)
- Chaque cue : temps `MM:SS`, nom de patch/preset, instruction, couleur (6 niveaux)
- Vue performance plein écran : **trois zones** (précédent / courant / suivant)
- **Topbar claire style DAW** — contraste fort avec la scène noire
- **Transport** : ⏮ Rewind · ⏹ Stop · ▶ Play / ⏸ Pause
- **Horloge grande** (48px) — décompte en mode auto, chrono en mode manuel
- **Barre durée restante** segmentée style LED — se vide de 100 % → 0 %
  - Segments 22px séparés par trait noir
  - Clignotement CSS lent (< 10 s) et rapide (< 5 s)
  - Hauteur réglable (6–80 px, défaut 20 px)
- **Mode auto** — avance automatique entre cues avec décompte ; durée par défaut configurable si pas de minutage
- **Mode manuel** — barre scrub positionnelle, avance au clic / espace / swipe
- Zoom police A+ / A− (variable CSS `--fs`, 40–250 %)
- Plein écran natif (touche F)
- Bouton « ✕ Quitter » avec confirmation — raccourci Q
- Raccourcis clavier complets : Espace · → · ← · A · S · R · F · Q · + · −
- Swipe mobile gauche/droite
- **Export JSON** — format structuré réimportable
- **Export Markdown** — tableau compatible Obsidian
- **Import** — upload `.json` ou `.md`, parsing automatique, redirection vers l'éditeur

### 🏷️ Titres de session
- Champ titre optionnel sur chaque session (ex : *Drone Secteur 7*)
- Affiché dans la liste sous la date, comme titre principal dans la vue détail
- Formulaires new/edit mis à jour

### ☁️ Déploiement cloud Fly.io
- Dockerfile Python 3.11-slim + Gunicorn WSGI
- `wsgi.py` — init DB au démarrage Gunicorn via `app.app_context()`
- Volume persistant `/data` (sessions.db + backups)
- Région CDG (Paris), 256 MB RAM, free tier
- URL publique : **https://aza-sessions.fly.dev/**

### 📱 Mobile
- Menu hamburger fixe en portrait iPhone — nav cachée par défaut, drawer ☰/✕
- Stats : grilles responsives `auto-fill minmax` — plus de scroll horizontal
- `overflow-x: hidden` sur body

### 🐛 Corrections majeures
- Suppression de session — erreur `cannot DELETE from contentless fts5 table` corrigée (drop FTS5 triggers au démarrage)
- Barre de progression — double `requestAnimationFrame` pour reflow garanti
- Restart prompteur — `event.stopPropagation()` pour éviter la propagation du clic

### 📄 Formulaire PDF papier (mode dégradé)
- `/form/blank` — template A4 deux pages imprimable sans JS
- Génération dynamique depuis le catalogue courant (machines, effets, DAW, iOS, plugins, influences, caractères)

---

## v1.3.0-alpha — 2026-05-01

### Ajouts
- Export JSON et Markdown par script prompteur
- Import `.json` / `.md` — parsing automatique, flash message
- Barre durée restante : segments LED, clignotement, hauteur réglable

---

## v1.2.0-alpha — 2026-05-01

### Ajouts
- Titre optionnel sur chaque session
- Prompteur : 3 zones prev/current/next, barre animée, décompte, zoom police

---

## v1.1.0-alpha — 2026-04-25

### Ajouts
- **Prompteur Dawless** (`/prompter`) — scripts de set avec minutage, patch et instructions ; éditeur de cues (temps MM:SS, patch, action, couleur) ; vue performance plein écran

---

## v1.0.1 — 2026-04-25

### Corrections
- Déploiement Fly.io : `wsgi.py` corrigé, `init_db()` dans `app_context()`
- `fly.toml` : `memory = '256mb'`, `dockerfile = "Dockerfile"`

---

## v1.0.0 — 2026-04-25

### Ajouts
- Déploiement Fly.io (Docker + Gunicorn, volume persistant `/data`)
- Navigation mobile hamburger
- Fix horizontal scroll stats page
- Suppression sessions : fix crash FTS5

---

## v0.9.9-alpha — 2026-04-24

### Ajouts
- Formulaire vierge imprimable PDF (`/form/blank`) généré depuis le catalogue

---

## v0.9.8-alpha — 2026-04-23

### Corrections
- Suppression de session : `BEGIN IMMEDIATE` retiré
- FTS5 contentless table : triggers droppés au démarrage via `init_db()`
- `debug=True` activé temporairement pour diagnostic

---

## v0.7.0-alpha — 2026-04-21

### Ajouts
- Samples, Morceaux, Wishlist, Inspirations, MiRack, Spark
- 6 thèmes terminal (Béton, Machine, Nord, Solarized, Gruvbox, Dracula)

---

## v0.6.0-alpha — 2026-04-20

### Ajouts
- Suppression sessions (form POST + confirm)
- Vue Projets — regroupement de sessions sous un titre avec couleur
- Copie setup d'une session existante
- Tags cliquables dans la liste
- Dark mode toggle ◐

---

## v0.5.4-alpha — 2026-04-20

### Ajouts
- Page Paramètres — import DB, backup `.db` horodaté, reset sessions

---

## v0.5.3-alpha — 2026-04-20

### Ajouts
- Widget Pomodoro flottant persistant (25/5/15 min)
- Auto-save formulaires (localStorage)

### Corrections
- Stats Chart.js — fix compatibilité

---

## v0.5.2-alpha — 2026-04-20

### Ajouts
- Filtres et recherche en temps réel (texte libre, mode, note)
- Liaison entre sessions — select dropdown, affichage en card
- Fichier audio — bouton copier presse-papiers

---

## v0.5.1-alpha — 2026-04-20

### Ajouts
- Widget Pomodoro flottant (25/5/15 min, barre de progression)
- Bannière terminal ANSI + détection port libre au démarrage
- `os.chdir()` au démarrage

---

## v0.4.0 — 2026-04-20

### Ajouts
- Édition d'une session existante — route `/session/<id>/edit`
- Template `edit.html` — formulaire pré-rempli

---

## v0.3.1 — 2026-04-20 — Initial commit

### Ajouts
- Application Flask complète : sessions, catalogue, influences, obliques
- Dashboard statistiques interactif (Chart.js)
- Export Markdown individuel et global (compatible Obsidian)
- Champ `recap_claude` pour coller le résumé de session Claude
- Scripts de lancement Mac (`lancer.command`) et Windows (`lancer.bat`)
- Scripts de compilation binaire PyInstaller (`build_mac.sh`, `build_windows.bat`)
