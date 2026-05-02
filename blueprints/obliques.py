from flask_login import login_required

from flask import Blueprint, jsonify, redirect, render_template, request, url_for

from constants import VERSION
from db import get_db
from helpers import rand_oblique

bp = Blueprint("obliques", __name__)


@bp.route("/oblique")
@login_required
def get_oblique():
    return jsonify({"text": rand_oblique()})


@bp.route("/obliques", methods=["GET", "POST"])
@login_required
def manage_obliques():
    conn = get_db()
    if request.method == "POST":
        action = request.form.get("action")
        if action == "add":
            t = request.form.get("text", "").strip()
            if t:
                conn.execute("INSERT INTO obliques (text) VALUES (?)", (t,))
        elif action == "delete":
            conn.execute("DELETE FROM obliques WHERE id=?", (request.form.get("id"),))
        elif action == "edit":
            conn.execute("UPDATE obliques SET text=? WHERE id=?",
                         (request.form.get("text","").strip(), request.form.get("id")))
        elif action == "toggle":
            conn.execute("UPDATE obliques SET active=1-active WHERE id=?",
                         (request.form.get("id"),))
        conn.commit()
        conn.close()
        return redirect(url_for("obliques.manage_obliques"))
    obliques = conn.execute("SELECT * FROM obliques ORDER BY id").fetchall()
    conn.close()
    return render_template("obliques.html", obliques=obliques,
                           version=VERSION, oblique=rand_oblique())
