from datetime import datetime
from flask import Blueprint, render_template, request, redirect, url_for, current_app
from core.db import get_db
from .engine import PresetsEngine

bp = Blueprint("presets", __name__)


def _engine():
    return PresetsEngine(current_app.config["DB_PATH"])


def _version():
    return current_app.config.get("VERSION", "")


def _catalogue_and_influences():
    conn = get_db(current_app.config["DB_PATH"])
    cat = [dict(r) for r in conn.execute(
        "SELECT * FROM catalogue WHERE active=1 ORDER BY type, manufacturer, name"
    ).fetchall()]
    inf = [dict(r) for r in conn.execute(
        "SELECT * FROM influences WHERE active=1 ORDER BY name"
    ).fetchall()]
    sessions = [dict(r) for r in conn.execute(
        "SELECT id, date, title FROM sessions ORDER BY date DESC LIMIT 100"
    ).fetchall()]
    conn.close()
    return cat, inf, sessions


@bp.route("/presets")
def presets_list():
    cat_id = request.args.get("catalogue_id", type=int)
    q = request.args.get("q", "").strip()
    notes = _engine().list_all(catalogue_id=cat_id, q=q or None)
    cat, inf, sessions = _catalogue_and_influences()
    grouped = {}
    for n in notes:
        key = n.get("cat_name") or "Sans instrument"
        grouped.setdefault(key, []).append(n)
    return render_template("presets.html",
                           notes=notes,
                           grouped=grouped,
                           catalogue=cat,
                           influences=inf,
                           sessions=sessions,
                           filter_cat_id=cat_id,
                           search_q=q,
                           version=_version(),
                           now=datetime.now().strftime("%Y-%m-%dT%H:%M"))


@bp.route("/presets/new", methods=["POST"])
def preset_create():
    data = {
        "date":         request.form.get("date") or datetime.now().strftime("%Y-%m-%d %H:%M"),
        "catalogue_id": request.form.get("catalogue_id") or None,
        "preset_name":  request.form.get("preset_name", "").strip(),
        "evocation":    request.form.get("evocation", "").strip(),
        "song_idea":    request.form.get("song_idea", "").strip(),
        "influence_id": request.form.get("influence_id") or None,
        "rating":       request.form.get("rating") or None,
        "tags":         request.form.get("tags", "").strip(),
        "session_id":   request.form.get("session_id") or None,
        "notes":        request.form.get("notes", "").strip(),
    }
    _engine().create(data)
    back = request.form.get("_back")
    return redirect(back or url_for("presets.presets_list"))


@bp.route("/presets/<int:nid>/edit", methods=["GET", "POST"])
def preset_edit(nid):
    engine = _engine()
    note = engine.get(nid)
    if not note:
        return redirect(url_for("presets.presets_list"))

    if request.method == "POST":
        data = {
            "date":         request.form.get("date") or datetime.now().strftime("%Y-%m-%d %H:%M"),
            "catalogue_id": request.form.get("catalogue_id") or None,
            "preset_name":  request.form.get("preset_name", "").strip(),
            "evocation":    request.form.get("evocation", "").strip(),
            "song_idea":    request.form.get("song_idea", "").strip(),
            "influence_id": request.form.get("influence_id") or None,
            "rating":       request.form.get("rating") or None,
            "tags":         request.form.get("tags", "").strip(),
            "session_id":   request.form.get("session_id") or None,
            "notes":        request.form.get("notes", "").strip(),
        }
        engine.update(nid, data)
        return redirect(url_for("presets.presets_list"))

    cat, inf, sessions = _catalogue_and_influences()
    return render_template("presets_edit.html",
                           note=note,
                           catalogue=cat,
                           influences=inf,
                           sessions=sessions,
                           version=_version())


@bp.route("/presets/<int:nid>/delete", methods=["POST"])
def preset_delete(nid):
    _engine().delete(nid)
    return redirect(url_for("presets.presets_list"))


@bp.route("/presets/stats")
def presets_stats():
    engine = _engine()
    return render_template("presets_stats.html",
                           stats=engine.stats(),
                           top=engine.top_presets(),
                           version=_version())
