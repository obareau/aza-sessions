from flask import Blueprint, render_template, request, redirect, url_for, current_app
from core.constants import WISHLIST_TYPES, WISHLIST_PRIOS
from .engine import WishlistEngine

bp = Blueprint("wishlist", __name__)


def _engine():
    return WishlistEngine(current_app.config["DB_PATH"])


def _version():
    return current_app.config.get("VERSION", "")


@bp.route("/wishlist", methods=["GET", "POST"])
def manage_wishlist():
    engine = _engine()
    if request.method == "POST":
        action = request.form.get("action")
        if action == "add":
            engine.add(
                request.form.get("manufacturer", "").strip(),
                request.form.get("name", "").strip(),
                request.form.get("type"),
                request.form.get("price"),
                request.form.get("priority", "Un jour"),
                request.form.get("notes", "").strip(),
                request.form.get("url", "").strip(),
            )
        elif action == "delete":
            engine.delete(request.form.get("id"))
        elif action == "acquired":
            engine.toggle_acquired(request.form.get("id"))
        elif action == "edit":
            engine.edit(
                request.form.get("id"),
                request.form.get("manufacturer", "").strip(),
                request.form.get("name", "").strip(),
                request.form.get("type"),
                request.form.get("price"),
                request.form.get("priority", "Un jour"),
                request.form.get("notes", "").strip(),
                request.form.get("url", "").strip(),
            )
        return redirect(url_for("wishlist.manage_wishlist"))
    return render_template("wishlist.html", items=engine.list_all(),
                           wishlist_types=WISHLIST_TYPES, priorities=WISHLIST_PRIOS,
                           version=_version(), oblique=engine.rand_oblique())
