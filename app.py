import os, json, random, socket, glob, shutil, logging
from datetime import datetime
from flask import Flask
from core.db import get_db as _get_db
from core.init_db import init_db, DEFAULT_OBLIQUE

# Se placer dans le dossier du script — évite PermissionError quand lancé via chemin absolu
os.chdir(os.path.dirname(os.path.abspath(__file__)))

app = Flask(__name__)
app.config["TEMPLATES_AUTO_RELOAD"] = True
app.jinja_env.filters['fromjson'] = json.loads
app.secret_key = os.environ.get("SECRET_KEY", "aza-sessions-local-dev")

VERSION     = "3.4.0"
DB_PATH     = os.environ.get("DB_PATH",     os.path.join(os.path.dirname(__file__), "sessions.db"))
CONFIG_PATH = os.environ.get("CONFIG_PATH", os.path.join(os.path.dirname(__file__), "config.json"))
app.config.update(DB_PATH=DB_PATH, VERSION=VERSION, CONFIG_PATH=CONFIG_PATH)

# ── BLUEPRINTS ────────────────────────────────────────────────────────────────
from sessions     import bp as sessions_bp;     app.register_blueprint(sessions_bp)
from spark        import bp as spark_bp;        app.register_blueprint(spark_bp)
from dim          import bp as dim_bp;          app.register_blueprint(dim_bp)
from catalogue    import bp as catalogue_bp;    app.register_blueprint(catalogue_bp)
from obliques     import bp as obliques_bp;     app.register_blueprint(obliques_bp)
from influences   import bp as influences_bp;   app.register_blueprint(influences_bp)
from stats        import bp as stats_bp;        app.register_blueprint(stats_bp)
from live         import bp as live_bp;         app.register_blueprint(live_bp)
from projects     import bp as projects_bp;     app.register_blueprint(projects_bp)
from settings_app import bp as settings_app_bp; app.register_blueprint(settings_app_bp)
from samples      import bp as samples_bp;      app.register_blueprint(samples_bp)
from tracks       import bp as tracks_bp;       app.register_blueprint(tracks_bp)
from wishlist     import bp as wishlist_bp;     app.register_blueprint(wishlist_bp)
from inspirations import bp as inspirations_bp; app.register_blueprint(inspirations_bp)
from mirack       import bp as mirack_bp;       app.register_blueprint(mirack_bp)
from about        import bp as about_bp;        app.register_blueprint(about_bp)
from patcher      import bp as patcher_bp;      app.register_blueprint(patcher_bp)
from sysex        import bp as sysex_bp;        app.register_blueprint(sysex_bp)


# ── CONTEXT PROCESSOR ────────────────────────────────────────────────────────

def _get_config():
    if os.path.exists(CONFIG_PATH):
        try:
            with open(CONFIG_PATH, encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {}


@app.context_processor
def inject_globals():
    try:
        conn = _get_db(DB_PATH)
        live = conn.execute("SELECT id FROM live_session LIMIT 1").fetchone()
        conn.close()
        return {"has_live": live is not None,
                "obsidian_vault": _get_config().get("obsidian_vault", "")}
    except Exception:
        return {"has_live": False, "obsidian_vault": ""}


# ── BANNER ────────────────────────────────────────────────────────────────────

def _find_free_port(start=5001, attempts=10):
    for port in range(start, start + attempts):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            try:
                s.bind(("0.0.0.0", port))
                return port
            except OSError:
                continue
    raise RuntimeError(f"Aucun port disponible entre {start} et {start+attempts-1}")


def _print_banner(port):
    R="\033[0m"; B="\033[1m"; DIM="\033[2m"
    C="\033[38;5;208m"; C2="\033[38;5;166m"; GR="\033[38;5;71m"
    W="\033[97m"; G="\033[38;5;240m"
    logo = [
        "  ██████╗  ██████╗ ██████╗  ██████╗ ████████╗ █████╗ ██████╗ ██╗██╗███████╗",
        "  ██╔══██╗██╔═══██╗██╔══██╗██╔═══██╗╚══██╔══╝██╔══██╗██╔══██╗██║██║██╔════╝",
        "  ██████╔╝██║   ██║██████╔╝██║   ██║   ██║   ███████║██████╔╝██║██║███████╗",
        "  ██╔══██╗██║   ██║██╔══██╗██║   ██║   ██║   ██╔══██║██╔══██╗██║██║╚════██║",
        "  ██║  ██║╚██████╔╝██████╔╝╚██████╔╝   ██║   ██║  ██║██║  ██║██║██║███████║",
        "  ╚═╝  ╚═╝ ╚═════╝ ╚═════╝  ╚═════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝╚══════╝",
    ]
    print()
    for i, line in enumerate(logo):
        print(f"{C if i<3 else C2}{B}{line}{R}")
    print(f"\n  {G}Journal de Sessions  ·  {W}{B}v{VERSION}{R}")
    print(f"  {G}{'─'*72}{R}")
    print(f"  {GR}{B}◉  http://localhost:{port}{R}")
    print(f"  {G}Dark Ambient / Industriel  ·  Scaër, Bretagne{R}\n")
    print(f"  {DIM}∴  {random.choice(DEFAULT_OBLIQUE)}{R}\n")
    print(f"  {G}Ctrl+C pour arrêter{R}\n")


# ── MAIN ───────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 0)) or _find_free_port(5001)
    _print_banner(port)
    init_db(DB_PATH)

    if os.path.exists(DB_PATH):
        backup_dir = os.environ.get("BACKUPS_DIR", os.path.join(os.path.dirname(os.path.abspath(__file__)), "backups"))
        os.makedirs(backup_dir, exist_ok=True)
        existing = sorted(glob.glob(os.path.join(backup_dir, "sessions_*.db")))
        while len(existing) >= 5:
            os.remove(existing.pop(0))
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        shutil.copy2(DB_PATH, os.path.join(backup_dir, f"sessions_{ts}.db"))
        print(f"  \033[38;5;240mBackup → backups/sessions_{ts}.db\033[0m\n")

    logging.getLogger("werkzeug").setLevel(logging.ERROR)
    app.run(debug=False, host="0.0.0.0", port=port, use_reloader=False)
