from flask_login import login_required

from flask import Blueprint, redirect, render_template, request, url_for

from constants import VERSION
from db import get_db
from helpers import rand_oblique

bp = Blueprint("influences", __name__)


@bp.route("/influences", methods=["GET", "POST"])
@login_required
def manage_influences():
    conn = get_db()
    if request.method == "POST":
        action = request.form.get("action")
        if action == "add":
            name = request.form.get("name", "").strip()
            typ = request.form.get("type", "artiste")
            notes = request.form.get("notes", "").strip()
            if name:
                conn.execute(
                    "INSERT INTO influences (name, type, notes) VALUES (?,?,?)",
                    (name, typ, notes)
                )
        elif action == "delete":
            conn.execute("DELETE FROM influences WHERE id=?", (request.form.get("id"),))
        elif action == "edit":
            conn.execute(
                "UPDATE influences SET name=?, type=?, notes=? WHERE id=?",
                (request.form.get("name","").strip(),
                 request.form.get("type","artiste"),
                 request.form.get("notes","").strip(),
                 request.form.get("id"))
            )
        elif action == "toggle":
            conn.execute("UPDATE influences SET active=1-active WHERE id=?",
                         (request.form.get("id"),))
        conn.commit()
        conn.close()
        return redirect(url_for("influences.manage_influences"))

    influences = conn.execute(
        "SELECT * FROM influences ORDER BY type, name"
    ).fetchall()
    conn.close()
    return render_template("influences.html", influences=influences,
                           version=VERSION, oblique=rand_oblique())
