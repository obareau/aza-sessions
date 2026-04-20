# Journal de Sessions Robōtariis

Application locale de documentation des sessions musicales pour le projet **Robōtariis** — univers de fiction dystopique dont la musique constitue la bande originale.

Style visé : Dark Ambient / Industriel — tradition PanSonic, Vromb, Synapscape, labels Hands Productions et Ant-Zen.

**Version actuelle : v0.4.0**

---

## Stack

- **Backend :** Python 3 / Flask
- **Base de données :** SQLite (`sessions.db`)
- **Frontend :** Jinja2, CSS vanilla, Chart.js
- **Typo :** IBM Plex Mono / IBM Plex Sans

---

## Lancement

**Mac — double-clic :**
```
lancer.command
```

**Windows — double-clic :**
```
lancer.bat
```

**Ligne de commande :**
```bash
pip install -r requirements.txt
python app.py
```

Ouvre ensuite [http://localhost:5000](http://localhost:5000)

**Compiler un binaire :**
```bash
./build_mac.sh        # macOS
build_windows.bat     # Windows
```

---

## Fonctionnalités

- **Sessions** — créer, consulter, éditer, exporter en Markdown (Obsidian)
- **Catalogue** — gérer le matériel (machines, effets, DAW, synthés iOS, plugins)
- **Influences** — artistes et labels de référence
- **Stratégies Obliques Robōtariis** — inspiration créative aléatoire (style Oblique Strategies)
- **Statistiques** — dashboard interactif Chart.js : machines, influences, notes, énergie, timeline...

---

## Structure

```
app.py              # Application principale
templates/          # Vues Jinja2
static/             # Assets statiques
requirements.txt    # Dépendances Python
CHANGELOG.md        # Historique des versions
sessions.db         # Base de données (non versionné)
```

---

## Backup

Copier `sessions.db` suffit. Ce fichier n'est pas versionné (`.gitignore`).

---

## Roadmap

### v0.4.x — En cours
- Filtres et recherche (machine, tag, note, date, intention)
- Pagination (au-delà de 50 sessions)

### v0.5.0
- Liaison entre sessions (chaîne de travail sur un même morceau)
- Vue "Projet" — regrouper des sessions sous un titre

---

*Projet personnel — Olivier, Scaër, Bretagne*
