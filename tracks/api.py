from flask import Blueprint, render_template, request, redirect, url_for, current_app
from .engine import TracksEngine

bp = Blueprint("tracks", __name__)


def _engine():
    return TracksEngine(current_app.config["DB_PATH"])


def _version():
    return current_app.config.get("VERSION", "")


@bp.route("/tracks", methods=["GET", "POST"])
def manage_tracks():
    engine = _engine()
    if request.method == "POST":
        action = request.form.get("action")
        if action == "add":
            engine.add(
                request.form.get("title", "").strip(),
                request.form.get("artist", "").strip(),
                request.form.get("album", "").strip(),
                request.form.get("year", "").strip(),
                request.form.get("tags", "").strip(),
                request.form.get("notes", "").strip(),
                request.form.get("url", "").strip(),
            )
        elif action == "delete":
            engine.delete(request.form.get("id"))
        elif action == "edit":
            engine.edit(
                request.form.get("id"),
                request.form.get("title", "").strip(),
                request.form.get("artist", "").strip(),
                request.form.get("album", "").strip(),
                request.form.get("year", "").strip(),
                request.form.get("tags", "").strip(),
                request.form.get("notes", "").strip(),
                request.form.get("url", "").strip(),
            )
        return redirect(url_for("tracks.manage_tracks"))
    return render_template("tracks.html", tracks=engine.list_all(),
                           version=_version(), oblique=engine.rand_oblique())
