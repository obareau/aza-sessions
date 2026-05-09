from flask import Blueprint, render_template, request, redirect, url_for, current_app
from core.constants import MIRACK_CATS
from .engine import MirackEngine

bp = Blueprint("mirack", __name__)


def _engine():
    return MirackEngine(current_app.config["DB_PATH"])


def _version():
    return current_app.config.get("VERSION", "")


@bp.route("/mirack", methods=["GET", "POST"])
def manage_mirack():
    engine = _engine()
    if request.method == "POST":
        action = request.form.get("action")
        if action == "add":
            engine.add(
                request.form.get("name", "").strip(),
                request.form.get("category"),
                request.form.get("mastered"),
                request.form.get("favorite"),
                request.form.get("notes", "").strip(),
            )
        elif action == "delete":
            engine.delete(request.form.get("id"))
        elif action == "toggle_mastered":
            engine.toggle_mastered(request.form.get("id"))
        elif action == "toggle_favorite":
            engine.toggle_favorite(request.form.get("id"))
        elif action == "edit":
            engine.edit(
                request.form.get("id"),
                request.form.get("name", "").strip(),
                request.form.get("category"),
                request.form.get("notes", "").strip(),
            )
        return redirect(url_for("mirack.manage_mirack"))
    modules, grouped = engine.list_all()
    return render_template("mirack.html", grouped=grouped, modules=modules,
                           mirack_cats=MIRACK_CATS,
                           version=_version(), oblique=engine.rand_oblique())
