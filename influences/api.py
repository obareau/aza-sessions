from flask import Blueprint, render_template, request, redirect, url_for, current_app
from core.oblique import rand_oblique
from .engine import InfluencesEngine

bp = Blueprint("influences", __name__)


def _engine():
    return InfluencesEngine(current_app.config["DB_PATH"])


@bp.route("/influences", methods=["GET", "POST"])
def manage_influences():
    engine = _engine()
    if request.method == "POST":
        action  = request.form.get("action")
        name    = request.form.get("name", "").strip()
        typ     = request.form.get("type", "artiste")
        notes   = request.form.get("notes", "").strip()
        item_id = request.form.get("id")
        if action == "add" and name:
            engine.add(name, typ, notes)
        elif action == "delete":
            engine.delete(item_id)
        elif action == "edit":
            engine.edit(item_id, name, typ, notes)
        elif action == "toggle":
            engine.toggle(item_id)
        return redirect(url_for("influences.manage_influences"))

    db_path = current_app.config["DB_PATH"]
    return render_template("influences.html",
                           influences=engine.list_all(),
                           version=current_app.config.get("VERSION", ""),
                           oblique=rand_oblique(db_path))
