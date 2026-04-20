from flask import Flask, render_template, request, redirect, url_for, jsonify, Response
import sqlite3
import os
import random
import json
from datetime import datetime
from collections import Counter

app = Flask(__name__)
VERSION = "0.4.0"
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

    # Migration : ajouter recap_claude si absent (v0.3.1+)
    try:
        conn.execute("ALTER TABLE sessions ADD COLUMN recap_claude TEXT")
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
    sessions = conn.execute(
        "SELECT * FROM sessions ORDER BY date DESC"
    ).fetchall()
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
                linked_session, influences, oblique, comments, recap_claude
            ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
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
        ))
        conn.commit()
        conn.close()
        return redirect(url_for("index"))

    cat = get_catalogue()
    return render_template("new.html",
                           catalogue=cat,
                           item_types=ITEM_TYPES,
                           characters=CHARACTERS,
                           modes=MODES,
                           intentions=INTENTIONS,
                           influences=get_influences_active(),
                           oblique=rand_oblique(),
                           version=VERSION,
                           now=datetime.now().strftime("%Y-%m-%dT%H:%M"))


@app.route("/session/<int:sid>")
def view_session(sid):
    conn = get_db()
    session = conn.execute(
        "SELECT * FROM sessions WHERE id = ?", (sid,)
    ).fetchone()
    conn.close()
    if not session:
        return redirect(url_for("index"))
    return render_template("view.html", session=session, version=VERSION)


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
                linked_session=?, influences=?, oblique=?, comments=?, recap_claude=?
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
            sid,
        ))
        conn.commit()
        conn.close()
        return redirect(url_for("view_session", sid=sid))

    cat = get_catalogue()
    return render_template("edit.html",
                           session=session,
                           catalogue=cat,
                           item_types=ITEM_TYPES,
                           characters=CHARACTERS,
                           modes=MODES,
                           intentions=INTENTIONS,
                           influences=get_influences_active(),
                           version=VERSION)


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


# ── MAIN ───────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    init_db()
    print(f"🤖 Journal de Sessions Robōtariis v{VERSION} — http://localhost:5001")
    app.run(debug=True, host="0.0.0.0", port=5001)
