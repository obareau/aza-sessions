from flask import Blueprint, render_template, request, redirect, url_for, current_app
from core.constants import INSPI_TYPES
from .engine import InspirationsEngine

bp = Blueprint("inspirations", __name__)


def _engine():
    return InspirationsEngine(current_app.config["DB_PATH"])


def _version():
    return current_app.config.get("VERSION", "")


@bp.route("/inspirations", methods=["GET", "POST"])
def manage_inspirations():
    engine = _engine()
    if request.method == "POST":
        action = request.form.get("action")
        if action == "add":
            engine.add(
                request.form.get("type"),
                request.form.get("content", "").strip(),
                request.form.get("source", "").strip(),
                request.form.get("notes", "").strip(),
            )
        elif action == "delete":
            engine.delete(request.form.get("id"))
        elif action == "edit":
            engine.edit(
                request.form.get("id"),
                request.form.get("type"),
                request.form.get("content", "").strip(),
                request.form.get("source", "").strip(),
                request.form.get("notes", "").strip(),
            )
        return redirect(url_for("inspirations.manage_inspirations"))
    return render_template("inspirations.html", inspirations=engine.list_all(),
                           inspi_types=INSPI_TYPES,
                           version=_version(), oblique=engine.rand_oblique())
