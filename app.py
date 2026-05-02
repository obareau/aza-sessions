from flask import Flask, render_template, request, redirect, url_for, jsonify, Response, flash
import sqlite3
import os
import random
import json
import socket
import tempfile
from datetime import datetime
from collections import Counter

# Se placer dans le dossier du script — évite PermissionError quand lancé via chemin absolu
os.chdir(os.path.dirname(os.path.abspath(__file__)))

app = Flask(__name__)
app.config["TEMPLATES_AUTO_RELOAD"] = True
app.jinja_env.filters['fromjson'] = json.loads
VERSION = "2.0.1"
DB_PATH      = os.environ.get("DB_PATH",      os.path.join(os.path.dirname(__file__), "sessions.db"))
CONFIG_PATH  = os.environ.get("CONFIG_PATH",  os.path.join(os.path.dirname(__file__), "config.json"))


def get_config():
    if os.path.exists(CONFIG_PATH):
        try:
            with open(CONFIG_PATH, encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {}


def save_config(data):
    with open(CONFIG_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

# ── DONNÉES PAR DÉFAUT ────────────────────────────────────────────────────────

DEFAULT_OBLIQUE = [
    "La machine ne ment pas. Elle déforme.",
    "Supprime une fréquence. Laisse le silence parler.",
    "Joue comme si les circuits étaient fatigués.",
    "Le bruit est une information que tu n'as pas encore comprise.",
    "Répète jusqu'à ce que la répétition devienne quelque chose d'autre.",
    "Inverse le signal. Écoute ce qui était caché.",
    "Les Robōtariis ne rêvent pas. Ils calculent l'absence.",
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
    "Les Robōtariis parlent en fréquences que les humains ont oublié d'entendre.",
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
    "daw": [
        "Ableton Live", "Logic Pro", "MainStage",
    ],
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

CHARACTERS = ["Drone","Rythmique","Texturé","Mélodique","Noise","Ambient","Industriel","Génératif","Percussif"]
MODES = ["Dawless","Hybride","Full DAW","iOS seul","MiRack seul"]
INTENTIONS = ["Exploration","B.O Robōtariis","Exercice technique","Défouloir","Jam","Post-prod"]

ITEM_TYPES = {
    "machine": "Hardware / Machines",
    "effet": "Effets Hardware",
    "daw": "DAW",
    "synth_ios": "Synthés iOS",
    "plugin": "Plugins VST/AU",
}

SAMPLE_TYPES    = ["Drums","Percussions","Basses","Synthés","Textures","Field recordings","Loops","Effets","Voix","Autre"]
MIRACK_CATS     = ["Oscillateur","Filtre","LFO","Enveloppe","Séquenceur","Effet","Utilitaire","Mixer","Aléatoire","Autre"]
WISHLIST_TYPES  = ["Synthétiseur","Effet hardware","DAW/Logiciel","Contrôleur","Interface audio","Câbles/Accessoires","Autre"]
WISHLIST_PRIOS  = ["Urgent","Bientôt","Un jour","Rêve"]
INSPI_TYPES     = ["Phrase","Extrait film","Livre","Image/Photo","Architecture","Concept","Autre"]

# ── DB ────────────────────────────────────────────────────────────────────────

def get_db():
    conn = sqlite3.connect(DB_PATH, timeout=10.0)
    conn.row_factory = sqlite3.Row
    return conn


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

    # Nettoyage FTS5 — table et triggers supprimés (causaient des erreurs sur DELETE/UPDATE)
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

    # Peupler obliques
    if conn.execute("SELECT COUNT(*) FROM obliques").fetchone()[0] == 0:
        for t in DEFAULT_OBLIQUE:
            conn.execute("INSERT INTO obliques (text) VALUES (?)", (t,))

    # Peupler catalogue
    if conn.execute("SELECT COUNT(*) FROM catalogue").fetchone()[0] == 0:
        for typ, items in DEFAULT_ITEMS.items():
            for name in items:
                conn.execute(
                    "INSERT INTO catalogue (type, name) VALUES (?,?)", (typ, name)
                )

    # Peupler influences
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

    # Migrations
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


# ── HELPERS ───────────────────────────────────────────────────────────────────

def rand_oblique():
    conn = get_db()
    rows = conn.execute(
        "SELECT text FROM obliques WHERE active=1"
    ).fetchall()
    conn.close()
    if not rows:
        return "La machine ne ment pas. Elle déforme."
    return random.choice(rows)["text"]


def get_catalogue():
    conn = get_db()
    rows = conn.execute(
        "SELECT * FROM catalogue WHERE active=1 ORDER BY type, name"
    ).fetchall()
    conn.close()
    result = {k: [] for k in ITEM_TYPES}
    for r in rows:
        if r["type"] in result:
            result[r["type"]].append(dict(r))
    return result


def get_influences_active():
    conn = get_db()
    rows = conn.execute(
        "SELECT * FROM influences WHERE active=1 ORDER BY name"
    ).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def session_to_md(s):
    project_line = f"\n**Projet:** {s['project_title']}" if s['project_title'] else ""
    return f"""# Session {s['date']}

**Mode:** {s['mode'] or '—'}
**Intention:** {s['intention'] or '—'}
**Durée:** {s['duration_min'] or '—'} min
**Énergie:** {'⚡' * (s['energy_level'] or 0)}
**Note:** {'★' * (s['rating'] or 0)}{project_line}

## Machines
{s['machines'] or '—'}

## Effets hardware
{s['effects'] or '—'}

## DAW
{s['daws'] or '—'}

## Synthés iOS
{s['synths_ios'] or '—'}

## Plugins
{s['plugins'] or '—'}

## Signal routing
{s['signal_routing'] or '—'}

## Algo MicroFreak
{s['microfreak_algo'] or '—'}

## Patches / Presets
{s['patches'] or '—'}

## Caractère sonore
{s['character'] or '—'}

## Timestamps intéressants
{s['timestamps'] or '—'}

## Fichier audio
{s['audio_file'] or '—'}

## Tags
{s['tags'] or '—'}

## Influences
{s['influences'] or '—'}

## Lien lore Robōtariis
{s['lore_link'] or '—'}

## Stratégie Robōtariis
> {s['oblique'] or '—'}

## Notes libres
{s['comments'] or '—'}

## Récap session Claude
{s['recap_claude'] or '—'}

---
*À retravailler: {'Oui' if s['to_rework'] else 'Non'} | Potentiel release: {'Oui' if s['release_potential'] else 'Non'}*
*Journal de Sessions Robōtariis v{VERSION}*
"""


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


# ── ROUTES SESSIONS ────────────────────────────────────────────────────────────

@app.route("/")
def index():
    conn = get_db()
    sessions = conn.execute("""
        SELECT s.*, p.title AS project_title, p.color AS project_color
        FROM sessions s
        LEFT JOIN projects p ON s.project_id = p.id
        ORDER BY s.date DESC
    """).fetchall()
    conn.close()
    return render_template("index.html",
                           sessions=sessions,
                           oblique=rand_oblique(),
                           version=VERSION,
                           is_search=False)


@app.route("/new", methods=["GET", "POST"])
def new_session():
    if request.method == "POST":
        data = request.form
        conn = get_db()
        conn.execute("""
            INSERT INTO sessions (
                title, date, duration_min, mode, intention, energy_level,
                machines, effects, daws, synths_ios, plugins,
                patches, audio_file, timestamps, rating, tags,
                character, lore_link, to_rework, release_potential,
                tempo, tonality, signal_routing, microfreak_algo,
                linked_session, influences, oblique, comments, recap_claude, project_id
            ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """, (
            data.get("title", "").strip(),
            data.get("date", datetime.now().strftime("%Y-%m-%d %H:%M")),
            data.get("duration_min") or None,
            data.get("mode"),
            data.get("intention"),
            data.get("energy_level") or None,
            ", ".join(request.form.getlist("machines")),
            ", ".join(request.form.getlist("effects")),
            ", ".join(request.form.getlist("daws")),
            ", ".join(request.form.getlist("synths_ios")),
            ", ".join(request.form.getlist("plugins")),
            data.get("patches"),
            data.get("audio_file"),
            data.get("timestamps"),
            data.get("rating") or None,
            data.get("tags"),
            ", ".join(request.form.getlist("character")),
            data.get("lore_link"),
            1 if data.get("to_rework") else 0,
            1 if data.get("release_potential") else 0,
            data.get("tempo"),
            data.get("tonality"),
            data.get("signal_routing"),
            data.get("microfreak_algo"),
            data.get("linked_session") or None,
            ", ".join(request.form.getlist("influences")),
            data.get("oblique"),
            data.get("comments"),
            data.get("recap_claude"),
            data.get("project_id") or None,
        ))
        conn.commit()
        # Nettoyer la session live si elle a servi de source
        if data.get("_from_live"):
            conn.execute("DELETE FROM live_session")
            conn.commit()
        conn.close()
        return redirect(url_for("index"))

    # Prefill depuis session live en cours (?from_live=1)
    prefill = None
    from_live = request.args.get("from_live")
    if from_live:
        pf_conn = get_db()
        ls = pf_conn.execute("SELECT * FROM live_session LIMIT 1").fetchone()
        pf_conn.close()
        if ls:
            started_at = datetime.strptime(ls["started_at"], "%Y-%m-%d %H:%M:%S")
            duration_min = max(1, int((datetime.now() - started_at).total_seconds() // 60))
            prefill = {
                "id": None,
                "_from_live": True,
                "duration_min": duration_min,
                "started_at": ls["started_at"],
                "machines":   ls["machines"] or "",
                "effects":    ls["effects"] or "",
                "daws":       ls["daws"] or "",
                "synths_ios": ls["synths_ios"] or "",
                "plugins":    ls["plugins"] or "",
                "mode":       ls["mode"] or "",
                "intention":  ls["intention"] or "",
                "oblique":    ls["oblique"] or "",
                "project_id": ls["project_id"],
                # champs vides à compléter
                "character": "", "influences": "",
            }

    # Prefill depuis une session existante (?from=ID)
    from_id = request.args.get("from")
    if from_id and not prefill:
        pf_conn = get_db()
        prefill = pf_conn.execute(
            "SELECT * FROM sessions WHERE id=?", (from_id,)
        ).fetchone()
        pf_conn.close()

    cat = get_catalogue()
    conn = get_db()
    all_sessions = conn.execute("SELECT id, date, machines FROM sessions ORDER BY date DESC").fetchall()
    projects = conn.execute("SELECT * FROM projects ORDER BY title").fetchall()
    conn.close()
    return render_template("new.html",
                           catalogue=cat,
                           item_types=ITEM_TYPES,
                           characters=CHARACTERS,
                           modes=MODES,
                           intentions=INTENTIONS,
                           influences=get_influences_active(),
                           oblique=rand_oblique(),
                           all_sessions=all_sessions,
                           projects=projects,
                           prefill=prefill,
                           version=VERSION,
                           now=datetime.now().strftime("%Y-%m-%dT%H:%M"))


@app.route("/session/<int:sid>")
def view_session(sid):
    conn = get_db()
    session = conn.execute("""
        SELECT s.*, p.title AS project_title, p.color AS project_color, p.id AS project_id_val
        FROM sessions s
        LEFT JOIN projects p ON s.project_id = p.id
        WHERE s.id = ?
    """, (sid,)).fetchone()
    linked = None
    if session and session["linked_session"]:
        linked = conn.execute(
            "SELECT * FROM sessions WHERE id = ?", (session["linked_session"],)
        ).fetchone()
    conn.close()
    if not session:
        return redirect(url_for("index"))
    return render_template("view.html", session=session, linked=linked, version=VERSION)


def _chunk_list(lst, n):
    """Découpe une liste en blocs de taille max n."""
    lst = list(lst)
    return [lst[i:i+n] for i in range(0, len(lst), n)]

def _catalogue_blocks(catalogue, block_size=16):
    """
    Retourne une liste de blocs prêts pour le template.
    Les sections dépassant block_size items sont découpées en sous-blocs
    nommés 'Section 1/2', 'Section 2/2', etc.
    Seul le dernier bloc d'une section reçoit la ligne d'ajout manuel.
    """
    LABELS = {
        'machine':   'Hardware / Machines',
        'effet':     'Effets Hardware',
        'daw':       'DAW',
        'synth_ios': 'Synthés iOS',
        'plugin':    'Plugins VST/AU',
    }
    blocks = []
    for key, label in LABELS.items():
        items = list(catalogue.get(key, []))
        if not items:
            continue
        chunks = _chunk_list(items, block_size)
        n = len(chunks)
        for i, chunk in enumerate(chunks):
            suffix = f" {i+1}/{n}" if n > 1 else ""
            blocks.append({
                'title':    label + suffix,
                'entries':  chunk,
                'add_line': (i == n - 1),   # ligne vierge uniquement sur le dernier bloc
            })
    return blocks

def _influence_blocks(influences, block_size=20):
    """Même logique pour les influences."""
    items = list(influences)
    if not items:
        return []
    chunks = _chunk_list(items, block_size)
    n = len(chunks)
    return [
        {
            'title':    f"Influences de session{f' {i+1}/{n}' if n > 1 else ''}",
            'entries':  chunk,
            'add_line': (i == n - 1),
        }
        for i, chunk in enumerate(chunks)
    ]


@app.route("/form/blank")
def form_blank():
    """Formulaire vierge imprimable — mode dégradé papier."""
    conn = get_db()
    catalogue = {}
    for t in ITEM_TYPES:
        catalogue[t] = conn.execute(
            "SELECT name FROM catalogue WHERE type=? ORDER BY name", (t,)
        ).fetchall()
    influences = conn.execute("SELECT name FROM influences ORDER BY name").fetchall()
    oblique = rand_oblique()
    conn.close()
    return render_template("form_blank.html",
                           catalogue_blocks=_catalogue_blocks(catalogue),
                           influence_blocks=_influence_blocks(influences),
                           characters=CHARACTERS,
                           modes=MODES,
                           intentions=INTENTIONS,
                           oblique=oblique,
                           version=VERSION)


@app.route("/session/<int:sid>/print")
def print_session(sid):
    conn = get_db()
    session = conn.execute("""
        SELECT s.*, p.title AS project_title, p.color AS project_color
        FROM sessions s
        LEFT JOIN projects p ON s.project_id = p.id
        WHERE s.id = ?
    """, (sid,)).fetchone()
    conn.close()
    if not session:
        return redirect(url_for("index"))
    return render_template("print.html", session=session, version=VERSION)


@app.route("/session/<int:sid>/edit", methods=["GET", "POST"])
def edit_session(sid):
    conn = get_db()
    session = conn.execute(
        "SELECT * FROM sessions WHERE id = ?", (sid,)
    ).fetchone()
    conn.close()
    if not session:
        return redirect(url_for("index"))

    if request.method == "POST":
        data = request.form
        conn = get_db()
        conn.execute("""
            UPDATE sessions SET
                title=?, date=?, duration_min=?, mode=?, intention=?, energy_level=?,
                machines=?, effects=?, daws=?, synths_ios=?, plugins=?,
                patches=?, audio_file=?, timestamps=?, rating=?, tags=?,
                character=?, lore_link=?, to_rework=?, release_potential=?,
                tempo=?, tonality=?, signal_routing=?, microfreak_algo=?,
                linked_session=?, influences=?, oblique=?, comments=?, recap_claude=?,
                project_id=?
            WHERE id=?
        """, (
            data.get("title", "").strip(),
            data.get("date"),
            data.get("duration_min") or None,
            data.get("mode"),
            data.get("intention"),
            data.get("energy_level") or None,
            ", ".join(request.form.getlist("machines")),
            ", ".join(request.form.getlist("effects")),
            ", ".join(request.form.getlist("daws")),
            ", ".join(request.form.getlist("synths_ios")),
            ", ".join(request.form.getlist("plugins")),
            data.get("patches"),
            data.get("audio_file"),
            data.get("timestamps"),
            data.get("rating") or None,
            data.get("tags"),
            ", ".join(request.form.getlist("character")),
            data.get("lore_link"),
            1 if data.get("to_rework") else 0,
            1 if data.get("release_potential") else 0,
            data.get("tempo"),
            data.get("tonality"),
            data.get("signal_routing"),
            data.get("microfreak_algo"),
            data.get("linked_session") or None,
            ", ".join(request.form.getlist("influences")),
            data.get("oblique"),
            data.get("comments"),
            data.get("recap_claude"),
            data.get("project_id") or None,
            sid,
        ))
        conn.commit()
        conn.close()
        return redirect(url_for("view_session", sid=sid))

    cat = get_catalogue()
    conn2 = get_db()
    all_sessions = conn2.execute(
        "SELECT id, date, machines FROM sessions WHERE id != ? ORDER BY date DESC", (sid,)
    ).fetchall()
    projects = conn2.execute("SELECT * FROM projects ORDER BY title").fetchall()
    conn2.close()
    return render_template("edit.html",
                           session=session,
                           catalogue=cat,
                           item_types=ITEM_TYPES,
                           characters=CHARACTERS,
                           modes=MODES,
                           intentions=INTENTIONS,
                           influences=get_influences_active(),
                           all_sessions=all_sessions,
                           projects=projects,
                           version=VERSION)


@app.route("/session/<int:sid>/delete", methods=["POST"])
def delete_session(sid):
    conn = get_db()
    conn.execute("DELETE FROM sessions WHERE id=?", (sid,))
    conn.commit()
    conn.close()
    return redirect(url_for("index"))


# ── ROUTES PROJETS ────────────────────────────────────────────────────────────

@app.route("/projects")
def list_projects():
    conn = get_db()
    projects = conn.execute("SELECT * FROM projects ORDER BY title").fetchall()
    # Compter les sessions par projet
    counts = {}
    for p in projects:
        n = conn.execute(
            "SELECT COUNT(*) FROM sessions WHERE project_id=?", (p["id"],)
        ).fetchone()[0]
        counts[p["id"]] = n
    conn.close()
    return render_template("projects.html", projects=projects, counts=counts,
                           version=VERSION, oblique=rand_oblique())


@app.route("/projects/new", methods=["POST"])
def new_project():
    title = request.form.get("title", "").strip()
    if title:
        conn = get_db()
        conn.execute(
            "INSERT INTO projects (title, description, color) VALUES (?,?,?)",
            (title, request.form.get("description","").strip(),
             request.form.get("color","#D4380D"))
        )
        conn.commit()
        conn.close()
    return redirect(url_for("list_projects"))


@app.route("/projects/<int:pid>")
def view_project(pid):
    conn = get_db()
    project = conn.execute("SELECT * FROM projects WHERE id=?", (pid,)).fetchone()
    if not project:
        return redirect(url_for("list_projects"))
    sessions = conn.execute(
        "SELECT * FROM sessions WHERE project_id=? ORDER BY date DESC", (pid,)
    ).fetchall()
    conn.close()
    return render_template("project_detail.html", project=project, sessions=sessions,
                           version=VERSION, oblique=rand_oblique())


@app.route("/projects/<int:pid>/edit", methods=["GET", "POST"])
def edit_project(pid):
    conn = get_db()
    project = conn.execute("SELECT * FROM projects WHERE id=?", (pid,)).fetchone()
    conn.close()
    if not project:
        return redirect(url_for("list_projects"))
    if request.method == "POST":
        title = request.form.get("title", "").strip()
        if title:
            conn = get_db()
            conn.execute(
                "UPDATE projects SET title=?, description=?, color=? WHERE id=?",
                (title,
                 request.form.get("description", "").strip(),
                 request.form.get("color", "#D4380D"),
                 pid)
            )
            conn.commit()
            conn.close()
        return redirect(url_for("view_project", pid=pid))
    return render_template("project_edit.html", project=project,
                           version=VERSION, oblique=rand_oblique())


@app.route("/projects/<int:pid>/delete", methods=["POST"])
def delete_project(pid):
    conn = get_db()
    # Détacher les sessions liées
    conn.execute("UPDATE sessions SET project_id=NULL WHERE project_id=?", (pid,))
    conn.execute("DELETE FROM projects WHERE id=?", (pid,))
    conn.commit()
    conn.close()
    return redirect(url_for("list_projects"))


# ── ROUTES EXPORT ──────────────────────────────────────────────────────────────

@app.route("/export/<int:sid>")
def export_one(sid):
    conn = get_db()
    s = conn.execute("""
        SELECT s.*, p.title AS project_title
        FROM sessions s LEFT JOIN projects p ON s.project_id = p.id
        WHERE s.id = ?
    """, (sid,)).fetchone()
    conn.close()
    if not s:
        return "Session introuvable", 404
    return Response(
        session_to_md(s),
        mimetype="text/plain",
        headers={"Content-Disposition": f"attachment; filename=session_{sid}.md"}
    )


@app.route("/export/all")
def export_all():
    conn = get_db()
    sessions = conn.execute("""
        SELECT s.*, p.title AS project_title
        FROM sessions s LEFT JOIN projects p ON s.project_id = p.id
        ORDER BY s.date DESC
    """).fetchall()
    conn.close()
    if not sessions:
        content = f"""# Journal de Sessions Robōtariis v{VERSION}

*Exporté le {datetime.now().strftime('%Y-%m-%d %H:%M')}*
*0 session(s)*

Aucune session à exporter.
"""
        filename = f"robotariis_{datetime.now().strftime('%Y%m%d')}.md"
        return Response(
            content,
            mimetype="text/plain",
            headers={"Content-Disposition": f"attachment; filename={filename}"}
        )
    parts = [
        f"# Journal de Sessions Robōtariis v{VERSION}",
        f"*Exporté le {datetime.now().strftime('%Y-%m-%d %H:%M')}*",
        f"*{len(sessions)} session(s)*\n\n---\n",
    ]
    for s in sessions:
        parts.append(session_to_md(s))
        parts.append("\n---\n")
    filename = f"robotariis_{datetime.now().strftime('%Y%m%d')}.md"
    return Response(
        "\n".join(parts),
        mimetype="text/plain",
        headers={"Content-Disposition": f"attachment; filename={filename}"}
    )


@app.route("/export/csv")
def export_csv():
    """Export toutes les sessions en CSV."""
    import csv, io
    conn = get_db()
    sessions = conn.execute("""
        SELECT s.*, p.title AS project_title
        FROM sessions s LEFT JOIN projects p ON s.project_id = p.id
        ORDER BY s.date DESC
    """).fetchall()
    conn.close()

    cols = [
        "id","date","duration_min","mode","intention","energy_level",
        "machines","effects","daws","synths_ios","plugins",
        "patches","audio_file","timestamps","rating","tags",
        "character","lore_link","to_rework","release_potential",
        "tempo","tonality","signal_routing","microfreak_algo",
        "influences","oblique","comments","recap_claude","project_title",
    ]
    buf = io.StringIO()
    w = csv.writer(buf)
    w.writerow(cols)
    for s in sessions:
        w.writerow([s[c] if c in s.keys() else "" for c in cols])
    buf.seek(0)
    filename = f"robotariis_{datetime.now().strftime('%Y%m%d')}.csv"
    return Response(
        "\ufeff" + buf.getvalue(),   # BOM UTF-8 pour Excel
        mimetype="text/csv; charset=utf-8",
        headers={"Content-Disposition": f"attachment; filename={filename}"}
    )


@app.route("/session/<int:sid>/obsidian", methods=["POST"])
def export_obsidian(sid):
    """Copie le fichier Markdown de la session dans le vault Obsidian configuré."""
    cfg = get_config()
    vault = cfg.get("obsidian_vault", "").strip()
    if not vault:
        return jsonify({"error": "Chemin vault non configuré dans les Paramètres"}), 400
    conn = get_db()
    s = conn.execute("""
        SELECT s.*, p.title AS project_title
        FROM sessions s LEFT JOIN projects p ON s.project_id = p.id
        WHERE s.id = ?
    """, (sid,)).fetchone()
    conn.close()
    if not s:
        return jsonify({"error": "Session introuvable"}), 404
    try:
        os.makedirs(vault, exist_ok=True)
        fname = f"session_{s['date'][:10].replace('-','')}_{sid}.md"
        with open(os.path.join(vault, fname), "w", encoding="utf-8") as f:
            f.write(session_to_md(s))
        return jsonify({"status": "ok", "file": fname})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/settings/obsidian", methods=["POST"])
def settings_obsidian():
    cfg = get_config()
    cfg["obsidian_vault"] = request.form.get("obsidian_vault", "").strip()
    save_config(cfg)
    return redirect(url_for("settings", msg="Chemin Obsidian sauvegardé"))


# ── ROUTE STATS ────────────────────────────────────────────────────────────────

@app.route("/stats")
def stats():
    conn = get_db()
    sessions = conn.execute("SELECT * FROM sessions").fetchall()
    conn.close()

    total = len(sessions)
    if total == 0:
        return render_template("stats.html", version=VERSION,
                               oblique=rand_oblique(), stats_data=None, total=0)

    def count_items(field):
        counter = Counter()
        for s in sessions:
            val = s[field] or ""
            for item in [x.strip() for x in val.split(",") if x.strip()]:
                counter[item] += 1
        return dict(counter.most_common(15))

    # Ratings distribution
    ratings = [s["rating"] or 0 for s in sessions]
    rating_dist = {str(i): ratings.count(i) for i in range(1, 6)}

    # Energy distribution
    energies = [s["energy_level"] or 0 for s in sessions]
    energy_dist = {str(i): energies.count(i) for i in range(1, 4)}

    # Sessions par mois
    monthly = Counter()
    for s in sessions:
        if s["date"]:
            month = s["date"][:7]
            monthly[month] += 1
    monthly_sorted = dict(sorted(monthly.items()))

    # Modes
    modes = Counter(s["mode"] for s in sessions if s["mode"])

    # Intentions
    intentions = Counter(s["intention"] for s in sessions if s["intention"])

    # Projets
    conn2 = get_db()
    projects_rows = conn2.execute("""
        SELECT p.title, COUNT(s.id) as cnt
        FROM projects p
        JOIN sessions s ON s.project_id = p.id
        GROUP BY p.id ORDER BY cnt DESC
    """).fetchall()
    conn2.close()
    projects_dist = {r["title"]: r["cnt"] for r in projects_rows}

    # Taux release / rework
    release_count = sum(1 for s in sessions if s["release_potential"])
    rework_count = sum(1 for s in sessions if s["to_rework"])

    # Durée moyenne
    durations = [s["duration_min"] for s in sessions if s["duration_min"]]
    avg_duration = round(sum(durations) / len(durations)) if durations else 0

    # Heatmap — {YYYY-MM-DD: count} pour les 53 dernières semaines
    heatmap = {}
    for s in sessions:
        if s["date"]:
            day = s["date"][:10]
            heatmap[day] = heatmap.get(day, 0) + 1

    # Streak courant et max streak
    from datetime import date as _date, timedelta
    today_d = _date.today()
    streak, max_streak, cur = 0, 0, 0
    d = today_d
    while True:
        if heatmap.get(d.isoformat(), 0) > 0:
            cur += 1
            if d == today_d or d == today_d - timedelta(days=1):
                streak = cur
        else:
            max_streak = max(max_streak, cur)
            cur = 0
            if d < today_d - timedelta(days=365):
                break
        d -= timedelta(days=1)
    max_streak = max(max_streak, cur)

    # Records
    best = max(sessions, key=lambda s: (s["rating"] or 0, s["duration_min"] or 0))
    longest = max(sessions, key=lambda s: s["duration_min"] or 0)
    top_machine = max(count_items("machines"), key=count_items("machines").get) if count_items("machines") else None

    stats_data = {
        "total": total,
        "avg_duration": avg_duration,
        "release_count": release_count,
        "rework_count": rework_count,
        "machines": count_items("machines"),
        "effects": count_items("effects"),
        "daws": count_items("daws"),
        "synths_ios": count_items("synths_ios"),
        "plugins": count_items("plugins"),
        "influences": count_items("influences"),
        "characters": count_items("character"),
        "rating_dist": rating_dist,
        "energy_dist": energy_dist,
        "monthly": monthly_sorted,
        "modes": dict(modes.most_common()),
        "intentions": dict(intentions.most_common()),
        "projects": projects_dist,
        "heatmap": heatmap,
        "streak": streak,
        "max_streak": max_streak,
        "total_min": sum(durations),
        "records": {
            "best_id": best["id"], "best_date": best["date"][:10],
            "best_rating": best["rating"] or 0,
            "longest_id": longest["id"], "longest_date": longest["date"][:10],
            "longest_min": longest["duration_min"] or 0,
            "top_machine": top_machine,
            "top_machine_count": count_items("machines").get(top_machine, 0) if top_machine else 0,
        },
    }

    return render_template("stats.html", version=VERSION,
                           oblique=rand_oblique(),
                           stats_data=json.dumps(stats_data),
                           stats=stats_data, total=total)


# ── ROUTES OBLIQUES ────────────────────────────────────────────────────────────

@app.route("/oblique")
def get_oblique():
    return jsonify({"text": rand_oblique()})


@app.route("/obliques", methods=["GET", "POST"])
def manage_obliques():
    conn = get_db()
    if request.method == "POST":
        action = request.form.get("action")
        if action == "add":
            t = request.form.get("text", "").strip()
            if t:
                conn.execute("INSERT INTO obliques (text) VALUES (?)", (t,))
        elif action == "delete":
            conn.execute("DELETE FROM obliques WHERE id=?", (request.form.get("id"),))
        elif action == "edit":
            conn.execute("UPDATE obliques SET text=? WHERE id=?",
                         (request.form.get("text","").strip(), request.form.get("id")))
        elif action == "toggle":
            conn.execute("UPDATE obliques SET active=1-active WHERE id=?",
                         (request.form.get("id"),))
        conn.commit()
        conn.close()
        return redirect(url_for("manage_obliques"))
    obliques = conn.execute("SELECT * FROM obliques ORDER BY id").fetchall()
    conn.close()
    return render_template("obliques.html", obliques=obliques,
                           version=VERSION, oblique=rand_oblique())


# ── ROUTES CATALOGUE ───────────────────────────────────────────────────────────

@app.route("/catalogue", methods=["GET", "POST"])
def manage_catalogue():
    conn = get_db()
    if request.method == "POST":
        action = request.form.get("action")
        if action == "add":
            typ = request.form.get("type")
            name = request.form.get("name", "").strip()
            notes = request.form.get("notes", "").strip()
            if typ and name:
                conn.execute(
                    "INSERT INTO catalogue (type, name, notes) VALUES (?,?,?)",
                    (typ, name, notes)
                )
        elif action == "delete":
            conn.execute("DELETE FROM catalogue WHERE id=?", (request.form.get("id"),))
        elif action == "edit":
            conn.execute(
                "UPDATE catalogue SET name=?, notes=? WHERE id=?",
                (request.form.get("name","").strip(),
                 request.form.get("notes","").strip(),
                 request.form.get("id"))
            )
        elif action == "toggle":
            conn.execute("UPDATE catalogue SET active=1-active WHERE id=?",
                         (request.form.get("id"),))
        conn.commit()
        conn.close()
        return redirect(url_for("manage_catalogue"))

    items = conn.execute(
        "SELECT * FROM catalogue ORDER BY type, name"
    ).fetchall()
    conn.close()
    grouped = {k: [] for k in ITEM_TYPES}
    for item in items:
        if item["type"] in grouped:
            grouped[item["type"]].append(dict(item))
    return render_template("catalogue.html", grouped=grouped,
                           item_types=ITEM_TYPES, version=VERSION,
                           oblique=rand_oblique())


# ── ROUTES INFLUENCES ──────────────────────────────────────────────────────────

@app.route("/influences", methods=["GET", "POST"])
def manage_influences():
    conn = get_db()
    if request.method == "POST":
        action = request.form.get("action")
        if action == "add":
            name = request.form.get("name", "").strip()
            typ = request.form.get("type", "artiste")
            notes = request.form.get("notes", "").strip()
            if name:
                conn.execute(
                    "INSERT INTO influences (name, type, notes) VALUES (?,?,?)",
                    (name, typ, notes)
                )
        elif action == "delete":
            conn.execute("DELETE FROM influences WHERE id=?", (request.form.get("id"),))
        elif action == "edit":
            conn.execute(
                "UPDATE influences SET name=?, type=?, notes=? WHERE id=?",
                (request.form.get("name","").strip(),
                 request.form.get("type","artiste"),
                 request.form.get("notes","").strip(),
                 request.form.get("id"))
            )
        elif action == "toggle":
            conn.execute("UPDATE influences SET active=1-active WHERE id=?",
                         (request.form.get("id"),))
        conn.commit()
        conn.close()
        return redirect(url_for("manage_influences"))

    influences = conn.execute(
        "SELECT * FROM influences ORDER BY type, name"
    ).fetchall()
    conn.close()
    return render_template("influences.html", influences=influences,
                           version=VERSION, oblique=rand_oblique())


# ── ROUTES PARAMÈTRES ─────────────────────────────────────────────────────────

@app.route("/settings")
def settings():
    conn = get_db()
    nb_sessions = conn.execute("SELECT COUNT(*) FROM sessions").fetchone()[0]
    conn.close()
    return render_template("settings.html", version=VERSION,
                           oblique=rand_oblique(), nb_sessions=nb_sessions)


@app.route("/settings/backup")
def settings_backup():
    """Télécharger la base de données actuelle."""
    with open(DB_PATH, "rb") as f:
        data = f.read()
    filename = f"robotariis_backup_{datetime.now().strftime('%Y%m%d_%H%M')}.db"
    return Response(data, mimetype="application/octet-stream",
                    headers={"Content-Disposition": f"attachment; filename={filename}"})


@app.route("/settings/import", methods=["POST"])
def settings_import():
    """Importer (fusionner) une base de données SQLite uploadée."""
    f = request.files.get("db_file")
    if not f or not f.filename.endswith(".db"):
        return render_template("settings.html", version=VERSION,
                               oblique=rand_oblique(), nb_sessions=0,
                               error="Fichier invalide — sélectionne un fichier .db")

    # Sauvegarder dans un fichier temporaire
    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".db")
    f.save(tmp.name)
    tmp.close()

    try:
        src = sqlite3.connect(tmp.name)
        src.row_factory = sqlite3.Row

        # Vérifier que c'est bien une DB Robōtariis
        tables = [r[0] for r in src.execute(
            "SELECT name FROM sqlite_master WHERE type='table'"
        ).fetchall()]
        if "sessions" not in tables:
            src.close()
            return render_template("settings.html", version=VERSION,
                                   oblique=rand_oblique(), nb_sessions=0,
                                   error="Ce fichier ne contient pas de table 'sessions'.")

        # Colonnes disponibles dans la source
        src_cols = {r[1] for r in src.execute("PRAGMA table_info(sessions)").fetchall()}
        # Colonnes dans la DB courante (sans 'id' et 'created_at')
        dst_cols = {r[1] for r in get_db().execute("PRAGMA table_info(sessions)").fetchall()}
        common = [c for c in dst_cols if c in src_cols and c not in ("id",)]

        rows = src.execute("SELECT * FROM sessions").fetchall()
        src.close()

        if not rows:
            return render_template("settings.html", version=VERSION,
                                   oblique=rand_oblique(), nb_sessions=0,
                                   msg="La base importée ne contient aucune session.")

        dst = get_db()
        imported = 0
        skipped  = 0
        for row in rows:
            # Éviter les doublons exacts (même date + mêmes machines)
            exists = dst.execute(
                "SELECT id FROM sessions WHERE date=? AND machines=?",
                (row["date"], row["machines"])
            ).fetchone()
            if exists:
                skipped += 1
                continue
            cols_str = ", ".join(common)
            placeholders = ", ".join("?" for _ in common)
            vals = tuple(row[c] for c in common)
            dst.execute(f"INSERT INTO sessions ({cols_str}) VALUES ({placeholders})", vals)
            imported += 1

        dst.commit()
        dst.close()

        nb = get_db().execute("SELECT COUNT(*) FROM sessions").fetchone()[0]
        get_db().close()
        msg = f"{imported} session(s) importée(s), {skipped} doublon(s) ignoré(s)."
        return render_template("settings.html", version=VERSION,
                               oblique=rand_oblique(), nb_sessions=nb, msg=msg)

    except Exception as e:
        return render_template("settings.html", version=VERSION,
                               oblique=rand_oblique(), nb_sessions=0,
                               error=f"Erreur lors de l'import : {str(e)}")
    finally:
        os.unlink(tmp.name)


@app.route("/settings/reset-sessions", methods=["POST"])
def settings_reset_sessions():
    """Supprimer toutes les sessions (catalogue/influences/obliques conservés)."""
    conn = get_db()
    conn.execute("DELETE FROM sessions")
    conn.execute("DELETE FROM sqlite_sequence WHERE name='sessions'")
    conn.commit()
    conn.close()
    nb = 0
    return render_template("settings.html", version=VERSION,
                           oblique=rand_oblique(), nb_sessions=nb,
                           msg="Toutes les sessions ont été supprimées.")


# ── ROUTES SAMPLES ────────────────────────────────────────────────────────────

@app.route("/samples", methods=["GET", "POST"])
def manage_samples():
    conn = get_db()
    if request.method == "POST":
        action = request.form.get("action")
        if action == "add":
            conn.execute(
                "INSERT INTO sample_banks (name, type, rating, source, notes) VALUES (?,?,?,?,?)",
                (request.form.get("name","").strip(),
                 request.form.get("type"),
                 request.form.get("rating") or None,
                 request.form.get("source","").strip(),
                 request.form.get("notes","").strip())
            )
        elif action == "delete":
            conn.execute("DELETE FROM sample_banks WHERE id=?", (request.form.get("id"),))
        elif action == "edit":
            conn.execute("""UPDATE sample_banks SET name=?,type=?,rating=?,source=?,notes=? WHERE id=?""",
                (request.form.get("name","").strip(), request.form.get("type"),
                 request.form.get("rating") or None, request.form.get("source","").strip(),
                 request.form.get("notes","").strip(), request.form.get("id")))
        conn.commit()
        conn.close()
        return redirect(url_for("manage_samples"))
    samples = conn.execute("SELECT * FROM sample_banks ORDER BY type, name").fetchall()
    conn.close()
    return render_template("samples.html", samples=samples, sample_types=SAMPLE_TYPES,
                           version=VERSION, oblique=rand_oblique())


# ── ROUTES MORCEAUX INSPIRANTS ─────────────────────────────────────────────────

@app.route("/tracks", methods=["GET", "POST"])
def manage_tracks():
    conn = get_db()
    if request.method == "POST":
        action = request.form.get("action")
        if action == "add":
            conn.execute(
                "INSERT INTO inspiring_tracks (title, artist, album, year, tags, notes, url) VALUES (?,?,?,?,?,?,?)",
                (request.form.get("title","").strip(), request.form.get("artist","").strip(),
                 request.form.get("album","").strip(), request.form.get("year","").strip(),
                 request.form.get("tags","").strip(), request.form.get("notes","").strip(),
                 request.form.get("url","").strip())
            )
        elif action == "delete":
            conn.execute("DELETE FROM inspiring_tracks WHERE id=?", (request.form.get("id"),))
        elif action == "edit":
            conn.execute("""UPDATE inspiring_tracks SET title=?,artist=?,album=?,year=?,tags=?,notes=?,url=? WHERE id=?""",
                (request.form.get("title","").strip(), request.form.get("artist","").strip(),
                 request.form.get("album","").strip(), request.form.get("year","").strip(),
                 request.form.get("tags","").strip(), request.form.get("notes","").strip(),
                 request.form.get("url","").strip(), request.form.get("id")))
        conn.commit()
        conn.close()
        return redirect(url_for("manage_tracks"))
    tracks = conn.execute("SELECT * FROM inspiring_tracks ORDER BY artist, title").fetchall()
    conn.close()
    return render_template("tracks.html", tracks=tracks, version=VERSION, oblique=rand_oblique())


# ── ROUTES WISHLIST ────────────────────────────────────────────────────────────

@app.route("/wishlist", methods=["GET", "POST"])
def manage_wishlist():
    conn = get_db()
    if request.method == "POST":
        action = request.form.get("action")
        if action == "add":
            conn.execute(
                "INSERT INTO gear_wishlist (manufacturer, name, type, price, priority, notes, url) VALUES (?,?,?,?,?,?,?)",
                (request.form.get("manufacturer","").strip(), request.form.get("name","").strip(),
                 request.form.get("type"), request.form.get("price") or None,
                 request.form.get("priority","Un jour"), request.form.get("notes","").strip(),
                 request.form.get("url","").strip())
            )
        elif action == "delete":
            conn.execute("DELETE FROM gear_wishlist WHERE id=?", (request.form.get("id"),))
        elif action == "acquired":
            conn.execute("UPDATE gear_wishlist SET acquired=1-acquired WHERE id=?", (request.form.get("id"),))
        elif action == "edit":
            conn.execute("""UPDATE gear_wishlist SET manufacturer=?,name=?,type=?,price=?,priority=?,notes=?,url=? WHERE id=?""",
                (request.form.get("manufacturer","").strip(), request.form.get("name","").strip(),
                 request.form.get("type"), request.form.get("price") or None,
                 request.form.get("priority","Un jour"), request.form.get("notes","").strip(),
                 request.form.get("url","").strip(), request.form.get("id")))
        conn.commit()
        conn.close()
        return redirect(url_for("manage_wishlist"))
    items = conn.execute(
        "SELECT * FROM gear_wishlist ORDER BY acquired, CASE priority WHEN 'Urgent' THEN 1 WHEN 'Bientôt' THEN 2 WHEN 'Un jour' THEN 3 ELSE 4 END, name"
    ).fetchall()
    conn.close()
    return render_template("wishlist.html", items=items, wishlist_types=WISHLIST_TYPES,
                           priorities=WISHLIST_PRIOS, version=VERSION, oblique=rand_oblique())


# ── ROUTES INSPIRATIONS ────────────────────────────────────────────────────────

@app.route("/inspirations", methods=["GET", "POST"])
def manage_inspirations():
    conn = get_db()
    if request.method == "POST":
        action = request.form.get("action")
        if action == "add":
            conn.execute(
                "INSERT INTO inspirations (type, content, source, notes) VALUES (?,?,?,?)",
                (request.form.get("type"), request.form.get("content","").strip(),
                 request.form.get("source","").strip(), request.form.get("notes","").strip())
            )
        elif action == "delete":
            conn.execute("DELETE FROM inspirations WHERE id=?", (request.form.get("id"),))
        elif action == "edit":
            conn.execute("UPDATE inspirations SET type=?,content=?,source=?,notes=? WHERE id=?",
                (request.form.get("type"), request.form.get("content","").strip(),
                 request.form.get("source","").strip(), request.form.get("notes","").strip(),
                 request.form.get("id")))
        conn.commit()
        conn.close()
        return redirect(url_for("manage_inspirations"))
    inspirations = conn.execute("SELECT * FROM inspirations ORDER BY type, created_at DESC").fetchall()
    conn.close()
    return render_template("inspirations.html", inspirations=inspirations,
                           inspi_types=INSPI_TYPES, version=VERSION, oblique=rand_oblique())


# ── ROUTES MIRACK ──────────────────────────────────────────────────────────────

@app.route("/mirack", methods=["GET", "POST"])
def manage_mirack():
    conn = get_db()
    if request.method == "POST":
        action = request.form.get("action")
        if action == "add":
            conn.execute(
                "INSERT INTO mirack_modules (name, category, mastered, favorite, notes) VALUES (?,?,?,?,?)",
                (request.form.get("name","").strip(), request.form.get("category"),
                 1 if request.form.get("mastered") else 0,
                 1 if request.form.get("favorite") else 0,
                 request.form.get("notes","").strip())
            )
        elif action == "delete":
            conn.execute("DELETE FROM mirack_modules WHERE id=?", (request.form.get("id"),))
        elif action == "toggle_mastered":
            conn.execute("UPDATE mirack_modules SET mastered=1-mastered WHERE id=?", (request.form.get("id"),))
        elif action == "toggle_favorite":
            conn.execute("UPDATE mirack_modules SET favorite=1-favorite WHERE id=?", (request.form.get("id"),))
        elif action == "edit":
            conn.execute("UPDATE mirack_modules SET name=?,category=?,notes=? WHERE id=?",
                (request.form.get("name","").strip(), request.form.get("category"),
                 request.form.get("notes","").strip(), request.form.get("id")))
        conn.commit()
        conn.close()
        return redirect(url_for("manage_mirack"))
    modules = conn.execute(
        "SELECT * FROM mirack_modules ORDER BY category, name"
    ).fetchall()
    conn.close()
    grouped = {}
    for m in modules:
        cat = m["category"] or "Autre"
        grouped.setdefault(cat, []).append(dict(m))
    return render_template("mirack.html", grouped=grouped, modules=modules,
                           mirack_cats=MIRACK_CATS, version=VERSION, oblique=rand_oblique())


# ── ROUTE SPARK (EN PANNE D'INSPIRATION) ─────────────────────────────────────

@app.route("/spark")
def spark():
    conn = get_db()
    sessions = conn.execute("SELECT * FROM sessions ORDER BY date DESC").fetchall()
    total = len(sessions)

    suggestions = []

    if total >= 3:
        # Machines sous-utilisées (< 25% des sessions)
        from collections import Counter
        def count_field(field):
            c = Counter()
            for s in sessions:
                for item in [x.strip() for x in (s[field] or "").split(",") if x.strip()]:
                    c[item] += 1
            return c

        machines_count = count_field("machines")
        effects_count  = count_field("effects")
        ios_count      = count_field("synths_ios")
        plugins_count  = count_field("plugins")

        threshold = max(1, total * 0.25)

        underused_machines = [k for k, v in machines_count.items() if v < threshold]
        underused_effects  = [k for k, v in effects_count.items()  if v < threshold]
        underused_ios      = [k for k, v in ios_count.items()      if v < threshold]
        underused_plugins  = [k for k, v in plugins_count.items()  if v < threshold]

        if underused_machines:
            pick = random.choice(underused_machines)
            n = machines_count[pick]
            suggestions.append({
                "icon": "⚙", "type": "Machine sous-utilisée",
                "text": f"<strong>{pick}</strong>",
                "sub": f"Utilisée dans seulement {n} session{'s' if n>1 else ''} sur {total}"
            })
        if underused_effects:
            pick = random.choice(underused_effects)
            suggestions.append({
                "icon": "~", "type": "Effet hardware oublié",
                "text": f"<strong>{pick}</strong>",
                "sub": f"Utilisé dans {effects_count[pick]} session{'s' if effects_count[pick]>1 else ''} sur {total}"
            })
        if underused_ios:
            pick = random.choice(underused_ios)
            suggestions.append({
                "icon": "📱", "type": "Synthé iOS à explorer",
                "text": f"<strong>{pick}</strong>",
                "sub": f"Utilisé dans {ios_count[pick]} session{'s' if ios_count[pick]>1 else ''} sur {total}"
            })

        # Intentions jamais choisies
        used_intentions = {s["intention"] for s in sessions if s["intention"]}
        unused_intentions = [i for i in INTENTIONS if i not in used_intentions]
        if unused_intentions:
            pick = random.choice(unused_intentions)
            suggestions.append({
                "icon": "◎", "type": "Intention jamais explorée",
                "text": f"<strong>{pick}</strong>",
                "sub": "Tu n'as jamais enregistré de session avec cette intention"
            })

        # Caractères jamais utilisés
        used_chars = set()
        for s in sessions:
            for c in (s["character"] or "").split(","):
                used_chars.add(c.strip())
        unused_chars = [c for c in CHARACTERS if c not in used_chars]
        if unused_chars:
            pick = random.choice(unused_chars)
            suggestions.append({
                "icon": "◈", "type": "Caractère sonore inexploré",
                "text": f"<strong>{pick}</strong>",
                "sub": "Aucune session avec ce caractère dans ta base"
            })

    # Modules MiRack non maîtrisés
    unmastered = conn.execute(
        "SELECT * FROM mirack_modules WHERE mastered=0 ORDER BY RANDOM() LIMIT 2"
    ).fetchall()
    for m in unmastered:
        suggestions.append({
            "icon": "⬡", "type": "Module MiRack à maîtriser",
            "text": f"<strong>{m['name']}</strong>",
            "sub": m["category"] or "Module non classifié"
        })

    # Inspiration aléatoire hors musique
    inspi = conn.execute("SELECT * FROM inspirations ORDER BY RANDOM() LIMIT 1").fetchone()
    if inspi:
        suggestions.append({
            "icon": "∴", "type": f"Inspiration — {inspi['type']}",
            "text": f"« {inspi['content']} »",
            "sub": inspi["source"] or ""
        })

    # Morceau inspirant aléatoire
    track = conn.execute("SELECT * FROM inspiring_tracks ORDER BY RANDOM() LIMIT 1").fetchone()
    if track:
        suggestions.append({
            "icon": "♪", "type": "Réécoute ce morceau",
            "text": f"<strong>{track['title']}</strong>" + (f" — {track['artist']}" if track["artist"] else ""),
            "sub": track["notes"] or (track["tags"] or "")
        })

    # Stratégie Oblique
    oblique_text = rand_oblique()
    suggestions.append({
        "icon": "∴", "type": "Stratégie Robōtariis",
        "text": f"<em>{oblique_text}</em>",
        "sub": "Laisse la machine te guider"
    })

    conn.close()
    random.shuffle(suggestions)
    return render_template("spark.html", suggestions=suggestions,
                           total=total, version=VERSION)


@app.route("/spark/focus")
def spark_focus():
    """Mode contrainte unique — une seule suggestion, affichée en grand."""
    conn = get_db()
    sessions = conn.execute("SELECT * FROM sessions ORDER BY date DESC").fetchall()
    total = len(sessions)

    pool = []

    # Obliques (toujours dispos)
    for _ in range(3):  # poids plus élevé pour les obliques
        pool.append({"icon": "∴", "type": "Stratégie Robōtariis",
                     "text": rand_oblique(), "sub": ""})

    if total >= 3:
        from collections import Counter
        def count_field(f):
            c = Counter()
            for s in sessions:
                for item in [x.strip() for x in (s[f] or "").split(",") if x.strip()]:
                    c[item] += 1
            return c

        threshold = max(1, total * 0.25)
        mc = count_field("machines")
        underused = [k for k, v in mc.items() if v < threshold]
        if underused:
            pick = random.choice(underused)
            pool.append({"icon": "⚙", "type": "Machine à sortir du placard",
                         "text": pick,
                         "sub": f"{mc[pick]} session{'s' if mc[pick]>1 else ''} sur {total}"})

        used_intentions = {s["intention"] for s in sessions if s["intention"]}
        unused = [i for i in INTENTIONS if i not in used_intentions]
        if unused:
            pool.append({"icon": "◎", "type": "Intention jamais explorée",
                         "text": random.choice(unused), "sub": ""})

        used_chars = set()
        for s in sessions:
            for c in (s["character"] or "").split(","):
                used_chars.add(c.strip())
        unused_c = [c for c in CHARACTERS if c not in used_chars]
        if unused_c:
            pool.append({"icon": "◈", "type": "Caractère sonore inexploré",
                         "text": random.choice(unused_c), "sub": ""})

    unmastered = conn.execute(
        "SELECT * FROM mirack_modules WHERE mastered=0 ORDER BY RANDOM() LIMIT 1"
    ).fetchone()
    if unmastered:
        pool.append({"icon": "⬡", "type": "Module MiRack à maîtriser",
                     "text": unmastered["name"],
                     "sub": unmastered["category"] or ""})

    inspi = conn.execute("SELECT * FROM inspirations ORDER BY RANDOM() LIMIT 1").fetchone()
    if inspi:
        pool.append({"icon": "∴", "type": f"Inspiration — {inspi['type']}",
                     "text": f"« {inspi['content']} »",
                     "sub": inspi["source"] or ""})

    conn.close()
    focus = random.choice(pool) if pool else {
        "icon": "∴", "type": "Stratégie", "text": "La machine ne ment pas. Elle déforme.", "sub": ""
    }
    return render_template("spark_focus.html", focus=focus, version=VERSION)


# ── ROUTE ABOUT ───────────────────────────────────────────────────────────────

@app.route("/about")
def about():
    return render_template("about.html", version=VERSION, oblique=rand_oblique())


# ── ROUTES PROMPTEUR DAWLESS ──────────────────────────────────────────────────

@app.route("/prompter")
def prompter_list():
    conn = get_db()
    scripts = conn.execute("SELECT * FROM prompter_scripts ORDER BY created_at DESC").fetchall()
    conn.close()
    return render_template("prompter_list.html", scripts=scripts, version=VERSION, oblique=rand_oblique())


@app.route("/prompter/new", methods=["GET", "POST"])
@app.route("/prompter/<int:sid>/edit", methods=["GET", "POST"])
def prompter_edit(sid=None):
    conn = get_db()
    script = None
    if sid:
        script = conn.execute("SELECT * FROM prompter_scripts WHERE id=?", (sid,)).fetchone()
        if not script:
            conn.close()
            return redirect(url_for("prompter_list"))

    if request.method == "POST":
        title = request.form.get("title", "").strip() or "Script sans titre"
        description = request.form.get("description", "").strip()
        # Reconstruit les cues depuis les champs dynamiques
        times   = request.form.getlist("cue_time[]")
        patches = request.form.getlist("cue_patch[]")
        actions = request.form.getlist("cue_action[]")
        colors  = request.form.getlist("cue_color[]")
        cues = []
        for t, p, a, c in zip(times, patches, actions, colors):
            if p.strip() or a.strip():
                # Convertit MM:SS en secondes
                secs = 0
                if t.strip():
                    parts = t.strip().split(":")
                    try:
                        if len(parts) == 2:
                            secs = int(parts[0]) * 60 + int(parts[1])
                        else:
                            secs = int(parts[0])
                    except ValueError:
                        secs = 0
                cues.append({"time_s": secs, "time_fmt": t.strip(), "patch": p.strip(), "action": a.strip(), "color": c or "default"})

        cues_json = json.dumps(cues, ensure_ascii=False)
        if sid:
            conn.execute("UPDATE prompter_scripts SET title=?, description=?, cues=? WHERE id=?",
                         (title, description, cues_json, sid))
        else:
            conn.execute("INSERT INTO prompter_scripts (title, description, cues) VALUES (?,?,?)",
                         (title, description, cues_json))
        conn.commit()
        conn.close()
        return redirect(url_for("prompter_list"))

    conn.close()
    cues = json.loads(script["cues"]) if script else []
    return render_template("prompter_edit.html", script=script, cues=cues, version=VERSION, oblique=rand_oblique())


@app.route("/prompter/<int:sid>/delete", methods=["POST"])
def prompter_delete(sid):
    conn = get_db()
    conn.execute("DELETE FROM prompter_scripts WHERE id=?", (sid,))
    conn.commit()
    conn.close()
    return redirect(url_for("prompter_list"))


@app.route("/prompter/<int:sid>/play")
def prompter_play(sid):
    conn = get_db()
    script = conn.execute("SELECT * FROM prompter_scripts WHERE id=?", (sid,)).fetchone()
    conn.close()
    if not script:
        return redirect(url_for("prompter_list"))
    cues = json.loads(script["cues"])
    return render_template("prompter_play.html", script=script, cues=cues, version=VERSION)


@app.route("/prompter/<int:sid>/export/json")
def prompter_export_json(sid):
    conn = get_db()
    script = conn.execute("SELECT * FROM prompter_scripts WHERE id=?", (sid,)).fetchone()
    conn.close()
    if not script:
        return redirect(url_for("prompter_list"))
    payload = {
        "title":       script["title"],
        "description": script["description"] or "",
        "cues":        json.loads(script["cues"])
    }
    data = json.dumps(payload, ensure_ascii=False, indent=2)
    filename = script["title"].lower().replace(" ", "_")[:40] + ".json"
    return Response(data, mimetype="application/json",
                    headers={"Content-Disposition": f"attachment; filename=\"{filename}\""})


@app.route("/prompter/<int:sid>/export/md")
def prompter_export_md(sid):
    conn = get_db()
    script = conn.execute("SELECT * FROM prompter_scripts WHERE id=?", (sid,)).fetchone()
    conn.close()
    if not script:
        return redirect(url_for("prompter_list"))
    cues = json.loads(script["cues"])
    lines = [f"# {script['title']}"]
    if script["description"]:
        lines.append(f"\n> {script['description']}\n")
    lines.append("\n| Temps  | Patch | Action | Couleur |")
    lines.append("|--------|-------|--------|---------|")
    for c in cues:
        t = c.get("time_fmt") or "—"
        p = (c.get("patch")  or "—").replace("|", "\\|")
        a = (c.get("action") or "—").replace("|", "\\|")
        col = c.get("color") or "default"
        lines.append(f"| {t} | {p} | {a} | {col} |")
    data = "\n".join(lines) + "\n"
    filename = script["title"].lower().replace(" ", "_")[:40] + ".md"
    return Response(data, mimetype="text/markdown",
                    headers={"Content-Disposition": f"attachment; filename=\"{filename}\""})


@app.route("/prompter/import", methods=["POST"])
def prompter_import():
    f = request.files.get("import_file")
    if not f:
        flash("Aucun fichier fourni.", "error")
        return redirect(url_for("prompter_list"))
    try:
        raw = f.read().decode("utf-8")
        # Détecte JSON ou Markdown
        if f.filename.endswith(".md") or f.filename.endswith(".txt"):
            # Parse le Markdown : titre = première ligne H1, tableau = lignes |
            title, description, cues = "", "", []
            for line in raw.splitlines():
                line = line.strip()
                if line.startswith("# ") and not title:
                    title = line[2:].strip()
                elif line.startswith("> ") and not description:
                    description = line[2:].strip()
                elif line.startswith("|") and not line.startswith("|---"):
                    cells = [c.strip() for c in line.strip("|").split("|")]
                    if len(cells) >= 3 and cells[0] != "Temps":
                        t_fmt = cells[0] if cells[0] != "—" else ""
                        patch  = cells[1] if cells[1] != "—" else ""
                        action = cells[2] if cells[2] != "—" else ""
                        color  = cells[3] if len(cells) > 3 and cells[3] not in ("—","Couleur") else "default"
                        secs = 0
                        if t_fmt:
                            parts = t_fmt.split(":")
                            try:
                                secs = int(parts[0])*60 + int(parts[1]) if len(parts)==2 else int(parts[0])
                            except ValueError:
                                secs = 0
                        cues.append({"time_fmt": t_fmt, "time_s": secs, "patch": patch, "action": action, "color": color})
        else:
            # JSON
            payload = json.loads(raw)
            title       = payload.get("title", "Script importé")
            description = payload.get("description", "")
            raw_cues    = payload.get("cues", [])
            cues = []
            for c in raw_cues:
                t_fmt = c.get("time_fmt", "")
                secs  = c.get("time_s", 0)
                cues.append({
                    "time_fmt": t_fmt,
                    "time_s":   int(secs),
                    "patch":    c.get("patch",  ""),
                    "action":   c.get("action", ""),
                    "color":    c.get("color",  "default")
                })
        if not title:
            title = "Script importé"
        conn = get_db()
        conn.execute("INSERT INTO prompter_scripts (title, description, cues) VALUES (?,?,?)",
                     (title, description, json.dumps(cues, ensure_ascii=False)))
        conn.commit()
        new_id = conn.execute("SELECT last_insert_rowid()").fetchone()[0]
        conn.close()
        flash(f"Script « {title} » importé avec succès ({len(cues)} cues).", "success")
        return redirect(url_for("prompter_edit", sid=new_id))
    except Exception as e:
        flash(f"Erreur d'import : {e}", "error")
        return redirect(url_for("prompter_list"))


# ── ROUTES LIVE SESSION ────────────────────────────────────────────────────────

@app.route("/live")
def live():
    conn = get_db()
    ls = conn.execute("SELECT * FROM live_session LIMIT 1").fetchone()
    cat = get_catalogue()
    projects = conn.execute("SELECT * FROM projects ORDER BY title").fetchall()
    conn.close()
    return render_template("live.html",
                           ls=dict(ls) if ls else None,
                           catalogue=cat,
                           item_types=ITEM_TYPES,
                           modes=MODES,
                           intentions=INTENTIONS,
                           projects=projects,
                           version=VERSION)


@app.route("/live/start", methods=["POST"])
def live_start():
    conn = get_db()
    conn.execute("DELETE FROM live_session")
    oblique = rand_oblique()
    conn.execute("""
        INSERT INTO live_session (id, started_at, oblique, mode, intention, project_id)
        VALUES (1, ?, ?, ?, ?, ?)
    """, (
        datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        oblique,
        request.form.get("mode", ""),
        request.form.get("intention", ""),
        request.form.get("project_id") or None,
    ))
    conn.commit()
    conn.close()
    return redirect(url_for("live"))


@app.route("/live/save", methods=["POST"])
def live_save():
    """AJAX — auto-sauvegarde des notes et checkboxes toutes les 15 s."""
    data = request.get_json(silent=True) or {}
    conn = get_db()
    conn.execute("""
        UPDATE live_session SET
            notes_live=?, machines=?, effects=?, daws=?,
            synths_ios=?, plugins=?, mode=?, intention=?
        WHERE id=1
    """, (
        data.get("notes_live", ""),
        data.get("machines", ""),
        data.get("effects", ""),
        data.get("daws", ""),
        data.get("synths_ios", ""),
        data.get("plugins", ""),
        data.get("mode", ""),
        data.get("intention", ""),
    ))
    conn.commit()
    conn.close()
    return jsonify({"status": "ok"})


@app.route("/live/finish", methods=["POST"])
def live_finish():
    """Déclenche un save final puis redirige vers /new pré-rempli."""
    # Save depuis le form si envoyé (fallback)
    conn = get_db()
    conn.execute("""
        UPDATE live_session SET
            notes_live=?, machines=?, effects=?, daws=?,
            synths_ios=?, plugins=?, mode=?, intention=?
        WHERE id=1
    """, (
        request.form.get("notes_live", ""),
        ", ".join(request.form.getlist("machines")),
        ", ".join(request.form.getlist("effects")),
        ", ".join(request.form.getlist("daws")),
        ", ".join(request.form.getlist("synths_ios")),
        ", ".join(request.form.getlist("plugins")),
        request.form.get("mode", ""),
        request.form.get("intention", ""),
    ))
    conn.commit()
    conn.close()
    return redirect(url_for("new_session", from_live=1))


@app.route("/live/abandon", methods=["POST"])
def live_abandon():
    conn = get_db()
    conn.execute("DELETE FROM live_session")
    conn.commit()
    conn.close()
    return redirect(url_for("index"))


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

    # ANSI
    _R   = "\033[0m"
    _B   = "\033[1m"
    _DIM = "\033[2m"
    _C   = "\033[38;5;208m"   # orange Robōtariis
    _C2  = "\033[38;5;166m"   # orange foncé (ombres)
    _GR  = "\033[38;5;71m"    # vert URL
    _W   = "\033[97m"         # blanc vif
    _G   = "\033[38;5;240m"   # gris foncé

    # ASCII art — police "block" (figlet) — 75 chars de large
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
        # Dégradé orange → orange foncé sur les dernières lignes
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
    if port_env:
        port = int(port_env)
    else:
        port = find_free_port(5001)
    url  = print_banner(port)
    init_db()

    # ── Backup automatique (garde les 5 derniers) ──────────────────────────────
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

    # Supprimer les logs Flask verbeux pour garder le terminal propre
    log = logging.getLogger("werkzeug")
    log.setLevel(logging.ERROR)

    app.run(debug=False, host="0.0.0.0", port=port, use_reloader=False)
