import json
import os
import tempfile
from datetime import datetime

from flask_login import login_required

from flask import Blueprint, Response, flash, jsonify, redirect, render_template, request, url_for

from config import get_config, save_config
from constants import CHARACTERS, INTENTIONS, ITEM_TYPES, MODES, VERSION
from db import get_db
from helpers import get_catalogue, get_influences_active, rand_oblique, session_to_md

bp = Blueprint("sessions", __name__)


@bp.route("/")
@login_required
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


@bp.route("/new", methods=["GET", "POST"])
@login_required
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
        if data.get("_from_live"):
            conn.execute("DELETE FROM live_session")
            conn.commit()
        conn.close()
        return redirect(url_for("sessions.index"))

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
                "character": "", "influences": "",
            }

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


@bp.route("/session/<int:sid>")
@login_required
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
        return redirect(url_for("sessions.index"))
    return render_template("view.html", session=session, linked=linked, version=VERSION)


@bp.route("/form/blank")
@login_required
def form_blank():
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
                           catalogue=catalogue,
                           influences=influences,
                           characters=CHARACTERS,
                           modes=MODES,
                           intentions=INTENTIONS,
                           oblique=oblique,
                           version=VERSION)


@bp.route("/session/<int:sid>/print")
@login_required
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
        return redirect(url_for("sessions.index"))
    return render_template("print.html", session=session, version=VERSION)


@bp.route("/session/<int:sid>/edit", methods=["GET", "POST"])
@login_required
def edit_session(sid):
    conn = get_db()
    session = conn.execute(
        "SELECT * FROM sessions WHERE id = ?", (sid,)
    ).fetchone()
    conn.close()
    if not session:
        return redirect(url_for("sessions.index"))

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
        return redirect(url_for("sessions.view_session", sid=sid))

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


@bp.route("/session/<int:sid>/delete", methods=["POST"])
@login_required
def delete_session(sid):
    conn = get_db()
    conn.execute("DELETE FROM sessions WHERE id=?", (sid,))
    conn.commit()
    conn.close()
    return redirect(url_for("sessions.index"))


# ── Export ────────────────────────────────────────────────────────────────────

@bp.route("/export/<int:sid>")
@login_required
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


@bp.route("/export/all")
@login_required
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


@bp.route("/export/csv")
@login_required
def export_csv():
    import csv
    import io
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
        "﻿" + buf.getvalue(),
        mimetype="text/csv; charset=utf-8",
        headers={"Content-Disposition": f"attachment; filename={filename}"}
    )


@bp.route("/session/<int:sid>/obsidian", methods=["POST"])
@login_required
def export_obsidian(sid):
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
