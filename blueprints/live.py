from datetime import datetime

from flask import Blueprint, jsonify, redirect, render_template, request, url_for

from constants import INTENTIONS, ITEM_TYPES, MODES, VERSION
from db import get_db
from helpers import get_catalogue, rand_oblique

bp = Blueprint("live", __name__)


@bp.route("/live")
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


@bp.route("/live/start", methods=["POST"])
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
    return redirect(url_for("live.live"))


@bp.route("/live/save", methods=["POST"])
def live_save():
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


@bp.route("/live/finish", methods=["POST"])
def live_finish():
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
    return redirect(url_for("sessions.new_session", from_live=1))


@bp.route("/live/abandon", methods=["POST"])
def live_abandon():
    conn = get_db()
    conn.execute("DELETE FROM live_session")
    conn.commit()
    conn.close()
    return redirect(url_for("sessions.index"))
