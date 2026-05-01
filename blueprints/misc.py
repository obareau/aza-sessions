import random
from collections import Counter

from flask import Blueprint, redirect, render_template, request, url_for

from constants import (CHARACTERS, INSPI_TYPES, INTENTIONS, MIRACK_CATS,
                       SAMPLE_TYPES, VERSION, WISHLIST_PRIOS, WISHLIST_TYPES)
from db import get_db
from helpers import rand_oblique

bp = Blueprint("misc", __name__)


# ── Samples ───────────────────────────────────────────────────────────────────

@bp.route("/samples", methods=["GET", "POST"])
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
        return redirect(url_for("misc.manage_samples"))
    samples = conn.execute("SELECT * FROM sample_banks ORDER BY type, name").fetchall()
    conn.close()
    return render_template("samples.html", samples=samples, sample_types=SAMPLE_TYPES,
                           version=VERSION, oblique=rand_oblique())


# ── Morceaux inspirants ────────────────────────────────────────────────────────

@bp.route("/tracks", methods=["GET", "POST"])
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
        return redirect(url_for("misc.manage_tracks"))
    tracks = conn.execute("SELECT * FROM inspiring_tracks ORDER BY artist, title").fetchall()
    conn.close()
    return render_template("tracks.html", tracks=tracks, version=VERSION, oblique=rand_oblique())


# ── Wishlist ──────────────────────────────────────────────────────────────────

@bp.route("/wishlist", methods=["GET", "POST"])
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
        return redirect(url_for("misc.manage_wishlist"))
    items = conn.execute(
        "SELECT * FROM gear_wishlist ORDER BY acquired, CASE priority WHEN 'Urgent' THEN 1 WHEN 'Bientôt' THEN 2 WHEN 'Un jour' THEN 3 ELSE 4 END, name"
    ).fetchall()
    conn.close()
    return render_template("wishlist.html", items=items, wishlist_types=WISHLIST_TYPES,
                           priorities=WISHLIST_PRIOS, version=VERSION, oblique=rand_oblique())


# ── Inspirations ──────────────────────────────────────────────────────────────

@bp.route("/inspirations", methods=["GET", "POST"])
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
        return redirect(url_for("misc.manage_inspirations"))
    inspirations = conn.execute("SELECT * FROM inspirations ORDER BY type, created_at DESC").fetchall()
    conn.close()
    return render_template("inspirations.html", inspirations=inspirations,
                           inspi_types=INSPI_TYPES, version=VERSION, oblique=rand_oblique())


# ── MiRack ────────────────────────────────────────────────────────────────────

@bp.route("/mirack", methods=["GET", "POST"])
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
        return redirect(url_for("misc.manage_mirack"))
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


# ── Spark ─────────────────────────────────────────────────────────────────────

@bp.route("/spark")
def spark():
    conn = get_db()
    sessions = conn.execute("SELECT * FROM sessions ORDER BY date DESC").fetchall()
    total = len(sessions)

    suggestions = []

    if total >= 3:
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

        used_intentions = {s["intention"] for s in sessions if s["intention"]}
        unused_intentions = [i for i in INTENTIONS if i not in used_intentions]
        if unused_intentions:
            pick = random.choice(unused_intentions)
            suggestions.append({
                "icon": "◎", "type": "Intention jamais explorée",
                "text": f"<strong>{pick}</strong>",
                "sub": "Tu n'as jamais enregistré de session avec cette intention"
            })

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

    unmastered = conn.execute(
        "SELECT * FROM mirack_modules WHERE mastered=0 ORDER BY RANDOM() LIMIT 2"
    ).fetchall()
    for m in unmastered:
        suggestions.append({
            "icon": "⬡", "type": "Module MiRack à maîtriser",
            "text": f"<strong>{m['name']}</strong>",
            "sub": m["category"] or "Module non classifié"
        })

    inspi = conn.execute("SELECT * FROM inspirations ORDER BY RANDOM() LIMIT 1").fetchone()
    if inspi:
        suggestions.append({
            "icon": "∴", "type": f"Inspiration — {inspi['type']}",
            "text": f"« {inspi['content']} »",
            "sub": inspi["source"] or ""
        })

    track = conn.execute("SELECT * FROM inspiring_tracks ORDER BY RANDOM() LIMIT 1").fetchone()
    if track:
        suggestions.append({
            "icon": "♪", "type": "Réécoute ce morceau",
            "text": f"<strong>{track['title']}</strong>" + (f" — {track['artist']}" if track["artist"] else ""),
            "sub": track["notes"] or (track["tags"] or "")
        })

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


@bp.route("/spark/focus")
def spark_focus():
    conn = get_db()
    sessions = conn.execute("SELECT * FROM sessions ORDER BY date DESC").fetchall()
    total = len(sessions)

    pool = []

    for _ in range(3):
        pool.append({"icon": "∴", "type": "Stratégie Robōtariis",
                     "text": rand_oblique(), "sub": ""})

    if total >= 3:
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


# ── About ─────────────────────────────────────────────────────────────────────

@bp.route("/about")
def about():
    return render_template("about.html", version=VERSION, oblique=rand_oblique())
