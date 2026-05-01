import glob
import json
import os
import random
import shutil
import socket
from datetime import datetime

from flask import Flask

from config import get_config
from constants import DEFAULT_OBLIQUE, VERSION
from db import DB_PATH, get_db, init_db

# Se placer dans le dossier du script — évite PermissionError quand lancé via chemin absolu
os.chdir(os.path.dirname(os.path.abspath(__file__)))

app = Flask(__name__)
app.secret_key = os.environ.get("SECRET_KEY", "robotariis-dev-key-change-in-prod")
app.config["TEMPLATES_AUTO_RELOAD"] = True
app.jinja_env.filters["fromjson"] = json.loads

# ── Blueprints ────────────────────────────────────────────────────────────────

from blueprints.sessions  import bp as sessions_bp
from blueprints.projects  import bp as projects_bp
from blueprints.prompter  import bp as prompter_bp
from blueprints.catalogue import bp as catalogue_bp
from blueprints.influences import bp as influences_bp
from blueprints.obliques  import bp as obliques_bp
from blueprints.stats     import bp as stats_bp
from blueprints.settings  import bp as settings_bp
from blueprints.live      import bp as live_bp
from blueprints.misc      import bp as misc_bp

app.register_blueprint(sessions_bp)
app.register_blueprint(projects_bp)
app.register_blueprint(prompter_bp)
app.register_blueprint(catalogue_bp)
app.register_blueprint(influences_bp)
app.register_blueprint(obliques_bp)
app.register_blueprint(stats_bp)
app.register_blueprint(settings_bp)
app.register_blueprint(live_bp)
app.register_blueprint(misc_bp)


# ── Context processor ─────────────────────────────────────────────────────────

@app.context_processor
def inject_globals():
    try:
        conn = get_db()
        live = conn.execute("SELECT id FROM live_session LIMIT 1").fetchone()
        conn.close()
        cfg = get_config()
        return {
            "has_live": live is not None,
            "obsidian_vault": cfg.get("obsidian_vault", ""),
        }
    except Exception:
        return {"has_live": False, "obsidian_vault": ""}


# ── Banner & port ─────────────────────────────────────────────────────────────

def find_free_port(start=5001, attempts=10):
    for port in range(start, start + attempts):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            try:
                s.bind(("0.0.0.0", port))
                return port
            except OSError:
                continue
    raise RuntimeError("Aucun port disponible entre %d et %d" % (start, start + attempts - 1))


def print_banner(port):
    url = f"http://localhost:{port}"

    _R   = "\033[0m"
    _B   = "\033[1m"
    _DIM = "\033[2m"
    _C   = "\033[38;5;208m"
    _C2  = "\033[38;5;166m"
    _GR  = "\033[38;5;71m"
    _W   = "\033[97m"
    _G   = "\033[38;5;240m"

    logo = [
        "  ██████╗  ██████╗ ██████╗  ██████╗ ████████╗ █████╗ ██████╗ ██╗██╗███████╗",
        "  ██╔══██╗██╔═══██╗██╔══██╗██╔═══██╗╚══██╔══╝██╔══██╗██╔══██╗██║██║██╔════╝",
        "  ██████╔╝██║   ██║██████╔╝██║   ██║   ██║   ███████║██████╔╝██║██║███████╗",
        "  ██╔══██╗██║   ██║██╔══██╗██║   ██║   ██║   ██╔══██║██╔══██╗██║██║╚════██║",
        "  ██║  ██║╚██████╔╝██████╔╝╚██████╔╝   ██║   ██║  ██║██║  ██║██║██║███████║",
        "  ╚═╝  ╚═╝ ╚═════╝ ╚═════╝  ╚═════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝╚══════╝",
    ]

    oblique = random.choice(DEFAULT_OBLIQUE)
    sep     = "─" * 72

    print()
    for i, line in enumerate(logo):
        col = _C if i < 3 else _C2
        print(f"{col}{_B}{line}{_R}")
    print()
    print(f"  {_G}Journal de Sessions  ·  {_W}{_B}v{VERSION}{_R}")
    print(f"  {_G}{sep}{_R}")
    print(f"  {_GR}{_B}◉  {url}{_R}")
    print(f"  {_G}Dark Ambient / Industriel  ·  Scaër, Bretagne{_R}")
    print()
    print(f"  {_DIM}∴  {oblique}{_R}")
    print()
    print(f"  {_G}Ctrl+C pour arrêter{_R}")
    print()
    return url


# ── Main ──────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import logging

    port_env = os.environ.get("PORT")
    if port_env:
        port = int(port_env)
    else:
        port = find_free_port(5001)
    url = print_banner(port)
    init_db()

    # Backup automatique (garde les 5 derniers)
    if os.path.exists(DB_PATH):
        backup_dir = os.environ.get("BACKUPS_DIR", os.path.join(os.path.dirname(os.path.abspath(__file__)), "backups"))
        os.makedirs(backup_dir, exist_ok=True)
        existing = sorted(glob.glob(os.path.join(backup_dir, "sessions_*.db")))
        while len(existing) >= 5:
            os.remove(existing.pop(0))
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        dest = os.path.join(backup_dir, f"sessions_{ts}.db")
        shutil.copy2(DB_PATH, dest)

        _R  = "\033[0m"; _DIM = "\033[2m"; _G = "\033[38;5;240m"
        print(f"  {_G}Backup → backups/sessions_{ts}.db{_R}")
        print()

    log = logging.getLogger("werkzeug")
    log.setLevel(logging.ERROR)

    app.run(debug=False, host="0.0.0.0", port=port, use_reloader=False)
