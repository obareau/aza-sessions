"""Point d'entrée WSGI pour Gunicorn.

C'est le chemin réel en production : le service systemd `aza-sessions` lance
`gunicorn wsgi:app`, donc le bloc `__main__` de app.py ne tourne jamais ici.
Tout ce qui doit se produire au démarrage se déclare donc ici, pas là-bas.

DB_PATH vient de l'unité systemd. Il y avait ici une redirection vers /data
quand FLY_APP_NAME était présent — retirée avec fly.toml, le déploiement Fly
étant abandonné.
"""
from app import app, DB_PATH, BACKUPS_DIR
from core.init_db import init_db
from core.backup import backup_db

with app.app_context():
    init_db(DB_PATH)

# Backup au démarrage Gunicorn — même fonction que le bloc __main__ de app.py,
# qui ne tourne pas ici. La logique vivait en double aux deux endroits.
_written = backup_db(DB_PATH, BACKUPS_DIR)
print(f"[backup] {_written}" if _written else "[backup] ignoré — base inchangée", flush=True)

if __name__ == "__main__":
    app.run()
