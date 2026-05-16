"""Initialisation et migrations de la base de données AZA."""
import sqlite3
from .db import get_db

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


def init_db(db_path):
    conn = get_db(db_path)

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

    conn.execute("""
        CREATE TABLE IF NOT EXISTS patch_layouts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL DEFAULT 'Patch',
            session_id INTEGER,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS patch_nodes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            layout_id INTEGER NOT NULL,
            label TEXT NOT NULL,
            x REAL DEFAULT 100,
            y REAL DEFAULT 100,
            node_type TEXT DEFAULT 'free',
            color TEXT DEFAULT '#3A3A3A',
            catalogue_id INTEGER,
            note TEXT DEFAULT '',
            FOREIGN KEY (layout_id) REFERENCES patch_layouts(id)
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS patch_connections (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            layout_id INTEGER NOT NULL,
            from_id INTEGER NOT NULL,
            to_id INTEGER NOT NULL,
            label TEXT DEFAULT '',
            signal_type TEXT DEFAULT 'audio',
            note TEXT DEFAULT '',
            FOREIGN KEY (layout_id) REFERENCES patch_layouts(id)
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS sysex_banks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL DEFAULT 'bank',
            format TEXT DEFAULT 'raw',
            size INTEGER DEFAULT 0,
            data BLOB,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    """)

    for migration in [
        "ALTER TABLE sessions ADD COLUMN recap_claude TEXT",
        "ALTER TABLE sessions ADD COLUMN project_id INTEGER",
        "ALTER TABLE sessions ADD COLUMN title TEXT DEFAULT ''",
        "ALTER TABLE patch_nodes ADD COLUMN note TEXT DEFAULT ''",
        "ALTER TABLE patch_connections ADD COLUMN note TEXT DEFAULT ''",
        "ALTER TABLE catalogue ADD COLUMN manufacturer TEXT DEFAULT ''",
    ]:
        try:
            conn.execute(migration)
            conn.commit()
        except Exception:
            pass

    conn.commit()
    conn.close()
