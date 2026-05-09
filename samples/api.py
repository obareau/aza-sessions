from flask import Blueprint, render_template, request, redirect, url_for, current_app
from core.constants import SAMPLE_TYPES
from .engine import SamplesEngine

bp = Blueprint("samples", __name__)


def _engine():
    return SamplesEngine(current_app.config["DB_PATH"])


def _version():
    return current_app.config.get("VERSION", "")


@bp.route("/samples", methods=["GET", "POST"])
def manage_samples():
    engine = _engine()
    if request.method == "POST":
        action = request.form.get("action")
        if action == "add":
            engine.add(
                request.form.get("name", "").strip(),
                request.form.get("type"),
                request.form.get("rating"),
                request.form.get("source", "").strip(),
                request.form.get("notes", "").strip(),
            )
        elif action == "delete":
            engine.delete(request.form.get("id"))
        elif action == "edit":
            engine.edit(
                request.form.get("id"),
                request.form.get("name", "").strip(),
                request.form.get("type"),
                request.form.get("rating"),
                request.form.get("source", "").strip(),
                request.form.get("notes", "").strip(),
            )
        return redirect(url_for("samples.manage_samples"))
    return render_template("samples.html", samples=engine.list_all(),
                           sample_types=SAMPLE_TYPES,
                           version=_version(), oblique=engine.rand_oblique())
