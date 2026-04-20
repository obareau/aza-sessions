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
VERSION = "0.6.0-alpha"
DB_PATH = os.path.join(os.path.dirname(__file__), "sessions.db")

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

# ── DB ────────────────────────────────────────────────────────────────────────

def get_db():
    conn = sqlite3.connect(DB_PATH)
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
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    """)

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

    # Migrations
    for migration in [
        "ALTER TABLE sessions ADD COLUMN recap_claude TEXT",
        "ALTER TABLE sessions ADD COLUMN project_id INTEGER",
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
    return f"""# Session {s['date']}

**Mode:** {s['mode'] or '—'}
**Intention:** {s['intention'] or '—'}
**Durée:** {s['duration_min'] or '—'} min
**Énergie:** {'⚡' * (s['energy_level'] or 0)}
**Note:** {'★' * (s['rating'] or 0)}

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
                           version=VERSION)


@app.route("/new", methods=["GET", "POST"])
def new_session():
    if request.method == "POST":
        data = request.form
        conn = get_db()
        conn.execute("""
            INSERT INTO sessions (
                date, duration_min, mode, intention, energy_level,
                machines, effects, daws, synths_ios, plugins,
                patches, audio_file, timestamps, rating, tags,
                character, lore_link, to_rework, release_potential,
                tempo, tonality, signal_routing, microfreak_algo,
                linked_session, influences, oblique, comments, recap_claude, project_id
            ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """, (
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
        conn.close()
        return redirect(url_for("index"))

    # Prefill depuis une session existante (?from=ID)
    prefill = None
    from_id = request.args.get("from")
    if from_id:
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
                date=?, duration_min=?, mode=?, intention=?, energy_level=?,
                machines=?, effects=?, daws=?, synths_ios=?, plugins=?,
                patches=?, audio_file=?, timestamps=?, rating=?, tags=?,
                character=?, lore_link=?, to_rework=?, release_potential=?,
                tempo=?, tonality=?, signal_routing=?, microfreak_algo=?,
                linked_session=?, influences=?, oblique=?, comments=?, recap_claude=?,
                project_id=?
            WHERE id=?
        """, (
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
    s = conn.execute("SELECT * FROM sessions WHERE id = ?", (sid,)).fetchone()
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
    sessions = conn.execute(
        "SELECT * FROM sessions ORDER BY date DESC"
    ).fetchall()
    conn.close()
    if not sessions:
        return "Aucune session", 404
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

    # Taux release / rework
    release_count = sum(1 for s in sessions if s["release_potential"])
    rework_count = sum(1 for s in sessions if s["to_rework"])

    # Durée moyenne
    durations = [s["duration_min"] for s in sessions if s["duration_min"]]
    avg_duration = round(sum(durations) / len(durations)) if durations else 0

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


# ── ROUTE ABOUT ───────────────────────────────────────────────────────────────

@app.route("/about")
def about():
    return render_template("about.html", version=VERSION, oblique=rand_oblique())


# ── BANNER & PORT ─────────────────────────────────────────────────────────────

# Codes ANSI
_R  = "\033[0m"       # reset
_B  = "\033[1m"       # bold
_DIM = "\033[2m"      # dim
_C  = "\033[38;5;208m"  # orange Robōtariis
_G  = "\033[38;5;240m"  # gris foncé
_W  = "\033[97m"      # blanc vif
_GR = "\033[38;5;71m"   # vert URL


def find_free_port(start=5001, attempts=10):
    for port in range(start, start + attempts):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            try:
                s.bind(("0.0.0.0", port))
                return port
            except OSError:
                continue
    raise RuntimeError("Aucun port disponible entre %d et %d" % (start, start + attempts - 1))


def _row(text, width, color=""):
    """Ligne de cadre : │  texte<padding>  │ — padding calculé sans ANSI."""
    inner = width - 4  # 2 espaces de chaque côté
    pad = max(0, inner - len(text))
    return f"{_C}{_B}│{_R}  {color}{text}{_R}{' ' * pad}  {_C}{_B}│{_R}"


def print_banner(port):
    url   = f"http://localhost:{port}"
    W     = 52                      # largeur intérieure totale (entre les │)
    hrule = "─" * W

    title    = f"ROBOTARIIS SESSIONS  v{VERSION}"
    subtitle = "Journal de sessions musicales"
    url_line = f"> {url}"

    print()
    print(f"{_C}{_B}┌{hrule}┐{_R}")
    print(f"{_C}{_B}│{' ' * W}│{_R}")
    print(_row(title,    W, _W + _B))
    print(_row(subtitle, W, _DIM))
    print(f"{_C}{_B}│{' ' * W}│{_R}")
    print(f"{_C}{_B}├{hrule}┤{_R}")
    print(_row(url_line, W, _GR + _B))
    print(f"{_C}{_B}└{hrule}┘{_R}")
    print()
    print(f"{_G}  Ctrl+C pour arreter{_R}")
    print()
    return url


# ── MAIN ───────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import logging
    port = find_free_port(5001)
    url  = print_banner(port)
    init_db()

    # Supprimer les logs Flask verbeux pour garder le terminal propre
    log = logging.getLogger("werkzeug")
    log.setLevel(logging.ERROR)

    app.run(debug=False, host="0.0.0.0", port=port, use_reloader=False)
