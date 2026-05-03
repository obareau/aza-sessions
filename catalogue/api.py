from flask import Blueprint, render_template, request, redirect, url_for, current_app
from core.oblique import rand_oblique
from .engine import CatalogueEngine, ITEM_TYPES

bp = Blueprint("catalogue", __name__)


def _engine():
    return CatalogueEngine(current_app.config["DB_PATH"])


@bp.route("/catalogue", methods=["GET", "POST"])
def manage_catalogue():
    engine = _engine()
    if request.method == "POST":
        action = request.form.get("action")
        name   = request.form.get("name", "").strip()
        notes  = request.form.get("notes", "").strip()
        item_id = request.form.get("id")
        if action == "add":
            typ = request.form.get("type")
            if typ and name:
                engine.add(typ, name, notes)
        elif action == "delete":
            engine.delete(item_id)
        elif action == "edit":
            engine.edit(item_id, name, notes)
        elif action == "toggle":
            engine.toggle(item_id)
        return redirect(url_for("catalogue.manage_catalogue"))

    db_path = current_app.config["DB_PATH"]
    return render_template("catalogue.html",
                           grouped=engine.list_grouped(),
                           item_types=ITEM_TYPES,
                           version=current_app.config.get("VERSION", ""),
                           oblique=rand_oblique(db_path))
