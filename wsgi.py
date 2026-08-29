"""Point d'entrée WSGI pour Gunicorn / Fly.io."""
import os

if os.environ.get("FLY_APP_NAME"):
    os.environ.setdefault("DB_PATH", "/data/sessions.db")
    os.environ.setdefault("BACKUPS_DIR", "/data/backups")

from app import app, DB_PATH, BACKUPS_DIR  # noqa: E402
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
