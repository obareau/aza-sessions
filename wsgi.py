"""Point d'entrée WSGI pour Gunicorn / Fly.io."""
import os

# En production, la DB et les backups vivent dans /data (volume persistant Fly)
if os.environ.get("FLY_APP_NAME"):
    os.environ.setdefault("DB_PATH", "/data/sessions.db")
    os.environ.setdefault("BACKUPS_DIR", "/data/backups")

from app import app, init_db  # noqa: E402

# Initialise la DB (crée les tables si elles n'existent pas)
# Indispensable avec Gunicorn — le bloc __main__ de app.py ne tourne pas
with app.app_context():
    init_db()

if __name__ == "__main__":
    app.run()
