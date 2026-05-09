from flask import Flask
import sqlite3
import os
import random
import json
import socket
import tempfile
from datetime import datetime

# Se placer dans le dossier du script — évite PermissionError quand lancé via chemin absolu
os.chdir(os.path.dirname(os.path.abspath(__file__)))

app = Flask(__name__)
app.config["TEMPLATES_AUTO_RELOAD"] = True
app.jinja_env.filters['fromjson'] = json.loads
VERSION = "2.5.0"
DB_PATH      = os.environ.get("DB_PATH",      os.path.join(os.path.dirname(__file__), "sessions.db"))
CONFIG_PATH  = os.environ.get("CONFIG_PATH",  os.path.join(os.path.dirname(__file__), "config.json"))
app.config["DB_PATH"]     = DB_PATH
app.config["VERSION"]     = VERSION
app.config["CONFIG_PATH"] = CONFIG_PATH

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


# ── DB ────────────────────────────────────────────────────────────────────────

from core.db import get_db as _core_get_db

def get_db():
    return _core_get_db(DB_PATH)


def get_config():
    if os.path.exists(CONFIG_PATH):
        try:
            with open(CONFIG_PATH, encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {}


# ── CONTEXT PROCESSOR ────────────────────────────────────────────────────────

@app.context_processor
def inject_globals():
    """Injecte has_live + obsidian_vault dans tous les templates."""
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


# ── DONNÉES PAR DÉFAUT (pour init_db) ────────────────────────────────────────

DEFAULT_OBLIQUE = [
    "La machine ne ment pas. Elle déforme.",
    "Supprime une fréquence. Laisse le silence parler.",
    "Joue comme si les circuits étaient fatigués.",
    "Le bruit est une information que tu n'as pas encore comprise.",
    "Répète jusqu'à ce que la répétition devienne quelque chose d'autre.",
    "Inverse le signal. Écoute ce qui était caché.",
    "Les AZA ne rêvent pas. Ils calculent l'absence.",
    "Retire un élément. Que reste-t-il ?",
    "Le glitch n'est pas une erreur. C'est une vérité accidentelle.",
    "Joue plus lentement que tu ne le penses nécessaire.",
    "Distords jusqu'à l'os. Puis encore un peu.",
    "Qu'est-ce que cette machine voudrait dire si elle pouvait ?",
    "Le silence entre les sons est aussi une composition.",
    "Enregistre d'abord. Écoute après.",
    "La mémoire des machines ne s'efface jamais vraiment.",
    "Travaille avec ce que tu as, pas avec ce que tu voudrais avoir.",
    "Un seul paramètre. Pousse-le à l'extrême.",
    "Les AZA parlent en fréquences que les humains ont oublié d'entendre.",
    "Ce qui semble cassé est peut-être parfait.",
    "Ferme les yeux. Écoute ce que le setup dit sans toi.",
    "La contrainte est une forme de liberté.",
    "Commence par la fin.",
    "Le drone est une prière que la machine adresse au vide.",
    "Moins de sources. Plus de profondeur.",
    "Ce pattern que tu répètes depuis une heure — c'est peut-être ça, le morceau.",
]

DEFAULT_ITEMS = {
    "machine": [
        "MicroFreak", "NTS-1", "Volca Drum", "Volca Kick",
        "Launchpad Pro mk3", "MacBook Intel (instrument)",
        "Mac M4", "iPad/iPhone", "PC Windows",
        "Zoom R8", "Zoom H4n", "BCD 3000",
        "Behringer Uphoria 1820", "Audient ID4 mk2", "CME WIDI Pro",
    ],
    "effet": [
        "NTS-1 (effets)", "Sonicake Smartbox", "Korg Pandora PX Mini",
        "Zoom R8 (effets)", "Zoom H4n (effets)",
    ],
    "daw": ["Ableton Live", "Logic Pro", "MainStage"],
    "synth_ios": [
        "Tera Pro", "MiRack", "Condukt", "Stepolyarp",
        "Peach", "Seqnd", "Blue Arp", "LK for Live",
    ],
    "plugin": [
        "Kilohearts Suite", "Baby Audio Tekno", "VCV Rack",
        "Arturia MiniFreak V", "Arturia Analog Lab",
    ],
}

DEFAULT_INFLUENCES = [
    "PanSonic", "Vromb", "Synapscape", "P·A·L", "Converter",
    "Raison d'Être", "Lustmord", "Alva Noto", "Fennesz",
    "Monolake", "Actress", "Esplendor Geométrico", "Noisex",
    "Hands Productions", "Ant-Zen", "Culture of Violence",
]


def init_db():
    conn = get_db()

    conn.execute("""
        CREATE TABLE IF NOT EXISTS sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            duration_min INTEGER,
            mode TEXT,
            intention TEXT,
            energy_level INTEGER,
            machines TEXT,
            effects TEXT,
            daws TEXT,
            synths_ios TEXT,
            plugins TEXT,
            patches TEXT,
            audio_file TEXT,
            timestamps TEXT,
            rating INTEGER,
            tags TEXT,
            character TEXT,
            lore_link TEXT,
            to_rework INTEGER DEFAULT 0,
            release_potential INTEGER DEFAULT 0,
            tempo TEXT,
            tonality TEXT,
            signal_routing TEXT,
            microfreak_algo TEXT,
            linked_session INTEGER,
            influences TEXT,
            oblique TEXT,
            comments TEXT,
            recap_claude TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            project_id INTEGER
        )
    """)

    # Nettoyage FTS5
    try:
        conn.executescript("""
            DROP TRIGGER IF EXISTS sessions_ai;
            DROP TRIGGER IF EXISTS sessions_ad;
            DROP TRIGGER IF EXISTS sessions_au;
            DROP TABLE IF EXISTS sessions_fts;
        """)
    except sqlite3.OperationalError:
        pass

    conn.execute("""
        CREATE TABLE IF NOT EXISTS obliques (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            text TEXT NOT NULL,
            active INTEGER DEFAULT 1,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS catalogue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            name TEXT NOT NULL,
            active INTEGER DEFAULT 1,
            notes TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    """)
    try:
        conn.execute("ALTER TABLE catalogue ADD COLUMN manufacturer TEXT DEFAULT ''")
    except Exception:
        pass

    conn.execute("""
        CREATE TABLE IF NOT EXISTS influences (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            type TEXT DEFAULT 'artiste',
            active INTEGER DEFAULT 1,
            notes TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    """)

    if conn.execute("SELECT COUNT(*) FROM obliques").fetchone()[0] == 0:
        for t in DEFAULT_OBLIQUE:
            conn.execute("INSERT INTO obliques (text) VALUES (?)", (t,))

    if conn.execute("SELECT COUNT(*) FROM catalogue").fetchone()[0] == 0:
        for typ, items in DEFAULT_ITEMS.items():
            for name in items:
                conn.execute("INSERT INTO catalogue (type, name) VALUES (?,?)", (typ, name))

    if conn.execute("SELECT COUNT(*) FROM influences").fetchone()[0] == 0:
        for name in DEFAULT_INFLUENCES:
            conn.execute("INSERT INTO influences (name) VALUES (?)", (name,))

    conn.execute("""
        CREATE TABLE IF NOT EXISTS projects (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            description TEXT,
            color TEXT DEFAULT '#D4380D',
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS sample_banks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            type TEXT,
            rating INTEGER,
            source TEXT,
            notes TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS inspiring_tracks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            artist TEXT,
            album TEXT,
            year TEXT,
            tags TEXT,
            notes TEXT,
            url TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS gear_wishlist (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            manufacturer TEXT,
            name TEXT NOT NULL,
            type TEXT,
            price REAL,
            priority TEXT DEFAULT 'Un jour',
            notes TEXT,
            url TEXT,
            acquired INTEGER DEFAULT 0,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS inspirations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT,
            content TEXT NOT NULL,
            source TEXT,
            notes TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS mirack_modules (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            category TEXT,
            mastered INTEGER DEFAULT 0,
            favorite INTEGER DEFAULT 0,
            notes TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS prompter_scripts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            description TEXT DEFAULT '',
            cues TEXT DEFAULT '[]',
            created_at TEXT DEFAULT (datetime('now'))
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS live_session (
            id INTEGER PRIMARY KEY,
            started_at TEXT NOT NULL,
            notes_live TEXT DEFAULT '',
            machines TEXT DEFAULT '',
            effects TEXT DEFAULT '',
            daws TEXT DEFAULT '',
            synths_ios TEXT DEFAULT '',
            plugins TEXT DEFAULT '',
            mode TEXT DEFAULT '',
            intention TEXT DEFAULT '',
            oblique TEXT DEFAULT '',
            project_id INTEGER
        )
    """)

    for migration in [
        "ALTER TABLE sessions ADD COLUMN recap_claude TEXT",
        "ALTER TABLE sessions ADD COLUMN project_id INTEGER",
        "ALTER TABLE sessions ADD COLUMN title TEXT DEFAULT ''",
    ]:
        try:
            conn.execute(migration)
            conn.commit()
        except Exception:
            pass

    conn.commit()
    conn.close()


# ── BANNER & PORT ─────────────────────────────────────────────────────────────

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
    _R = "\033[0m"; _B = "\033[1m"; _DIM = "\033[2m"
    _C = "\033[38;5;208m"; _C2 = "\033[38;5;166m"
    _GR = "\033[38;5;71m"; _W = "\033[97m"; _G = "\033[38;5;240m"

    logo = [
        "  ██████╗  ██████╗ ██████╗  ██████╗ ████████╗ █████╗ ██████╗ ██╗██╗███████╗",
        "  ██╔══██╗██╔═══██╗██╔══██╗██╔═══██╗╚══██╔══╝██╔══██╗██╔══██╗██║██║██╔════╝",
        "  ██████╔╝██║   ██║██████╔╝██║   ██║   ██║   ███████║██████╔╝██║██║███████╗",
        "  ██╔══██╗██║   ██║██╔══██╗██║   ██║   ██║   ██╔══██║██╔══██╗██║██║╚════██║",
        "  ██║  ██║╚██████╔╝██████╔╝╚██████╔╝   ██║   ██║  ██║██║  ██║██║██║███████║",
        "  ╚═╝  ╚═╝ ╚═════╝ ╚═════╝  ╚═════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝╚══════╝",
    ]

    oblique = random.choice(DEFAULT_OBLIQUE)
    sep = "─" * 72
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


# ── MAIN ───────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import logging, shutil, glob
    port_env = os.environ.get("PORT")
    port = int(port_env) if port_env else find_free_port(5001)
    url = print_banner(port)
    init_db()

    if os.path.exists(DB_PATH):
        backup_dir = os.environ.get("BACKUPS_DIR", os.path.join(os.path.dirname(os.path.abspath(__file__)), "backups"))
        os.makedirs(backup_dir, exist_ok=True)
        existing = sorted(glob.glob(os.path.join(backup_dir, "sessions_*.db")))
        while len(existing) >= 5:
            os.remove(existing.pop(0))
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        dest = os.path.join(backup_dir, f"sessions_{ts}.db")
        shutil.copy2(DB_PATH, dest)
        _R = "\033[0m"; _DIM = "\033[2m"; _G = "\033[38;5;240m"
        print(f"  {_G}Backup → backups/sessions_{ts}.db{_R}")
        print()

    log = logging.getLogger("werkzeug")
    log.setLevel(logging.ERROR)
    app.run(debug=False, host="0.0.0.0", port=port, use_reloader=False)
