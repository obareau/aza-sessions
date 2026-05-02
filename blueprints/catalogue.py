from flask_login import login_required

from flask import Blueprint, redirect, render_template, request, url_for

from constants import ITEM_TYPES, VERSION
from db import get_db
from helpers import rand_oblique

bp = Blueprint("catalogue", __name__)


@bp.route("/catalogue", methods=["GET", "POST"])
@login_required
def manage_catalogue():
    conn = get_db()
    if request.method == "POST":
        action = request.form.get("action")
        if action == "add":
            typ = request.form.get("type")
            name = request.form.get("name", "").strip()
            notes = request.form.get("notes", "").strip()
            if typ and name:
                conn.execute(
                    "INSERT INTO catalogue (type, name, notes) VALUES (?,?,?)",
                    (typ, name, notes)
                )
        elif action == "delete":
            conn.execute("DELETE FROM catalogue WHERE id=?", (request.form.get("id"),))
        elif action == "edit":
            conn.execute(
                "UPDATE catalogue SET name=?, notes=? WHERE id=?",
                (request.form.get("name","").strip(),
                 request.form.get("notes","").strip(),
                 request.form.get("id"))
            )
        elif action == "toggle":
            conn.execute("UPDATE catalogue SET active=1-active WHERE id=?",
                         (request.form.get("id"),))
        conn.commit()
        conn.close()
        return redirect(url_for("catalogue.manage_catalogue"))

    items = conn.execute(
        "SELECT * FROM catalogue ORDER BY type, name"
    ).fetchall()
    conn.close()
    grouped = {k: [] for k in ITEM_TYPES}
    for item in items:
        if item["type"] in grouped:
            grouped[item["type"]].append(dict(item))
    return render_template("catalogue.html", grouped=grouped,
                           item_types=ITEM_TYPES, version=VERSION,
                           oblique=rand_oblique())
