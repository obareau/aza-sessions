"""Point d'entrée WSGI pour Gunicorn / Fly.io."""
import os, glob, shutil
from datetime import datetime

if os.environ.get("FLY_APP_NAME"):
    os.environ.setdefault("DB_PATH", "/data/sessions.db")
    os.environ.setdefault("BACKUPS_DIR", "/data/backups")

from app import app, DB_PATH  # noqa: E402
from core.init_db import init_db

with app.app_context():
    init_db(DB_PATH)

# Backup au démarrage Gunicorn (5 derniers conservés)
if os.path.exists(DB_PATH):
    backup_dir = os.environ.get("BACKUPS_DIR", os.path.join(os.path.dirname(os.path.abspath(__file__)), "backups"))
    os.makedirs(backup_dir, exist_ok=True)
    existing = sorted(glob.glob(os.path.join(backup_dir, "sessions_*.db")))
    while len(existing) >= 5:
        os.remove(existing.pop(0))
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    shutil.copy2(DB_PATH, os.path.join(backup_dir, f"sessions_{ts}.db"))

if __name__ == "__main__":
    app.run()
