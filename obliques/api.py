from flask import Blueprint, render_template, request, redirect, url_for, jsonify, current_app
from core.oblique import rand_oblique
from .engine import ObliquesEngine

bp = Blueprint("obliques", __name__)


def _engine():
    return ObliquesEngine(current_app.config["DB_PATH"])


@bp.route("/oblique")
def get_oblique():
    return jsonify({"text": rand_oblique(current_app.config["DB_PATH"])})


@bp.route("/obliques", methods=["GET", "POST"])
def manage_obliques():
    engine = _engine()
    if request.method == "POST":
        action  = request.form.get("action")
        text    = request.form.get("text", "").strip()
        item_id = request.form.get("id")
        if action == "add" and text:
            engine.add(text)
        elif action == "delete":
            engine.delete(item_id)
        elif action == "edit":
            engine.edit(item_id, text)
        elif action == "toggle":
            engine.toggle(item_id)
        return redirect(url_for("obliques.manage_obliques"))

    db_path = current_app.config["DB_PATH"]
    return render_template("obliques.html",
                           obliques=engine.list_all(),
                           version=current_app.config.get("VERSION", ""),
                           oblique=rand_oblique(db_path))
