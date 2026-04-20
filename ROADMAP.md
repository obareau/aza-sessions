# ROADMAP — Journal de Sessions Robōtariis

> Idées, améliorations et fonctionnalités futures.
> Mise à jour au fil du développement — pas de promesses, pas de deadlines.
> Priorité indicative : ★★★ = vite / ★★☆ = bientôt / ★☆☆ = un jour

---

## 🎛 Sessions & Workflow

| Priorité | Idée | Notes |
|---|---|---|
| ★★★ | **Mode session en cours** — timer live qui tourne, notes rapides en temps réel, bouton "Terminer & sauvegarder" | Le workflow naturel : ouvrir l'app *avant* de jouer, pas après |
| ★★★ | **Brouillon pré-session** — remplir machines/intention *avant* de démarrer, horodatage automatique au lancement | Évite d'oublier les détails techniques après coup |
| ★★☆ | **Comparaison de deux sessions** — vue côte à côte pour repérer les patterns | Utile pour comprendre pourquoi une session a mieux marché |
| ★★☆ | **Duplication complète d'une session** — différent de "copier le setup", copie tout sauf date/audio | Pour documenter des variations d'un même morceau |
| ★☆☆ | **Pagination** sur la liste si > 50 sessions | Pas urgent, mais nécessaire à terme |
| ★☆☆ | **Import metadata audio** — lire date/durée depuis le fichier audio via `mutagen` | Plus précis que la saisie manuelle |

---

## 📊 Stats & Analyse

| Priorité | Idée | Notes |
|---|---|---|
| ★★★ | **Heatmap calendrier** — grille jour/semaine des sessions, style GitHub contributions | Visualiser les périodes actives vs creuses |
| ★★☆ | **Évolution temporelle** — courbe de la note moyenne, de l'énergie, du mode au fil du temps | Voir si la qualité progresse |
| ★★☆ | **Records & badges** — session la mieux notée, la plus longue, streak de jours consécutifs | Petit côté gamification sans en abuser |
| ★★☆ | **Corrélations** — note vs durée, énergie vs heure de la journée | Comprendre ses propres patterns créatifs |
| ★☆☆ | **Stats par projet** — dashboard complet sur la durée/évolution d'un projet | Déjà partiellement dans project_detail, à enrichir |

---

## ⚡ Spark (générateur créatif)

| Priorité | Idée | Notes |
|---|---|---|
| ★★★ | **Spark "contrainte unique"** — mode focus : une seule contrainte radicale, affichée en grand, à suivre jusqu'au bout | Moins de bruit, plus d'impact |
| ★★☆ | **Challenge du jour** — une contrainte fixe générée à minuit, commune à toute la journée | Crée un fil conducteur sur 24h |
| ★★☆ | **Historique Spark** — voir les suggestions déjà générées, noter celles qu'on a suivies | Éviter les répétitions, tracer l'influence sur les sessions |
| ★☆☆ | **Spark ↔ Session** — lier une suggestion Spark à la session qu'elle a inspirée | Traçabilité créative complète |

---

## 🌌 Lore Robōtariis

| Priorité | Idée | Notes |
|---|---|---|
| ★★☆ | **Carte du lore** — canvas interactif (SVG ou canvas HTML) où chaque session occupe un lieu dans l'univers | Visualisation narrative de la B.O. |
| ★★☆ | **Timeline narrative** — frise chronologique *dans l'univers* (distinct de la date réelle de session) | Ordonner les sessions par ordre lore, pas par date d'enregistrement |
| ★★☆ | **Générateur de noms Robōtariis** — titres de sessions dans l'esthétique de l'univers | Ex: "SÉQUENCE-09 / MÉMOIRE RÉSIDUELLE / NODE SCAER-7" |
| ★☆☆ | **Bestiaire / Glossaire** — entités, lieux, factions de l'univers, liables aux sessions | Enrichir le contexte narratif |

---

## 🎵 MiRack & Modules

| Priorité | Idée | Notes |
|---|---|---|
| ★★☆ | **Notes par module** — texte libre sur chaque module (tips, patches découverts, liens vidéo) | Carnet de bord du modulaire virtuel |
| ★★☆ | **Patches sauvegardés** — documenter des configurations de patch intéressantes avec schéma texte | Éviter de perdre une découverte |
| ★☆☆ | **Export liste modules** — Markdown/CSV de la collection pour Obsidian | Sync avec le vault |
| ★☆☆ | **Catégories personnalisables** — ajouter/renommer les catégories MiRack | Adapter à l'évolution de la collection |

---

## 🔗 Export & Intégrations

| Priorité | Idée | Notes |
|---|---|---|
| ★★★ | **Export PDF** — une session formatée comme une page de carnet de bord, style zine industriel | Archivage physique / partage |
| ★★☆ | **Export Obsidian direct** — copier les .md générés dans un chemin configurable du vault | Configurable dans Paramètres |
| ★★☆ | **Export CSV global** — toutes les sessions en tableau, importable dans Numbers/Excel | Analyse externe |
| ★☆☆ | **QR code vers une session** — afficher un QR pointant vers `localhost:5001/session/<id>` | Scanner depuis iPhone en studio |

---

## 🎨 Interface & UX

| Priorité | Idée | Notes |
|---|---|---|
| ★★★ | **Raccourcis clavier** — `n` nouvelle session, `s` stats, `j/k` naviguer la liste, `/` recherche | Fluidité pour un outil qu'on ouvre souvent |
| ★★☆ | **Mode focus** — cacher la navigation, une seule page visible, fond épuré | Pour ne pas être distrait pendant la session |
| ★★☆ | **Thème personnalisable** — éditeur de couleurs CSS custom, sauvegardé en localStorage | Aller plus loin que les 6 thèmes prédéfinis |
| ★★☆ | **Vue liste compacte vs cartes** — toggle entre mode dense (beaucoup de sessions visibles) et mode cartes | Selon l'usage : survol rapide ou consultation détaillée |
| ★☆☆ | **Animations subtiles** — transitions CSS sur les cards, le Pomodoro, les filtres | Peaufinage visuel |
| ★☆☆ | **Responsive mobile** — rendre l'app utilisable sur iPhone/iPad (saisie rapide en studio) | Complexe mais utile si l'iPad est dans le setup |

---

## 🛠 Tech & Qualité

| Priorité | Idée | Notes |
|---|---|---|
| ★★☆ | **Backup automatique** — copie horodatée de `sessions.db` au démarrage (garder les 5 derniers) | Filet de sécurité automatique |
| ★★☆ | **Recherche full-text** — chercher dans tous les champs texte (comments, recap_claude, patches…) | La recherche actuelle ne couvre pas tout |
| ★☆☆ | **Tests automatisés** — suite de tests Flask pour les routes critiques | Éviter les régressions lors des ajouts |
| ★☆☆ | **Compilation binaire M4** — `.app` macOS natif Apple Silicon via PyInstaller | Lancement sans terminal, sans Python installé |
| ★☆☆ | **Mode multi-machines** — sync `sessions.db` via réseau local (rsync ou SQLite over LAN) | Si usage Mac + iPad dans le même studio |

---

## 💡 Idées en vrac (à affiner)

- **"Session fantôme"** — marquer une session comme "perdue" (pas enregistrée, ratée) pour garder la trace sans regrets
- **Météo/Contexte** — heure de début, lieu (bureau / salon / extérieur), état d'esprit en un mot
- **Citations Robōtariis** — base de citations de l'univers, affichées dans l'interface (comme les obliques mais narratives)
- **BPM tap tempo** — widget simple dans le formulaire de session
- **Couleur d'humeur** — palette de 5-6 couleurs symboliques pour caractériser une session en un clic

---

*Dernière mise à jour : 2026-04-21*
*Ce fichier évolue librement — ce n'est pas un backlog, c'est une carte des possibles.*
