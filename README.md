# 🤖 Journal de Sessions Robōtariis v0.3.0

## Lancement
```bash
pip install -r requirements.txt
python app.py
```
→ http://localhost:5000

- **Mac** : double-clic `lancer.command`
- **Windows** : double-clic `lancer.bat`
- **Binaire Mac** : `./build_mac.sh`
- **Binaire Windows** : `build_windows.bat`

## Nouveautés v0.3.0
- **Catalogue éditable** : Hardware, Effets, DAW, Synthés iOS, Plugins VST/AU — tout en base de données, ajouter/éditer/désactiver/supprimer
- **Influences éditables** : Artistes, Labels, Autres — associables à chaque session
- **Dashboard stats interactif** : graphiques Chart.js pour machines, effets, DAW, synthés iOS, plugins, influences, ratings, énergie, timeline mensuelle
- Séparation claire des catégories logicielles en 3 types

## Migration depuis v0.2.0
Copie ton fichier `sessions.db` dans le nouveau dossier. Les nouvelles tables (catalogue, influences) seront créées automatiquement au premier lancement.

## Backup
SQLite — copier `sessions.db` suffit.
