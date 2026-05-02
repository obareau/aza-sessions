from flask_login import login_required

from flask import Blueprint, redirect, render_template, request, url_for

from constants import VERSION
from db import get_db
from helpers import rand_oblique

bp = Blueprint("projects", __name__)


@bp.route("/projects")
@login_required
def list_projects():
    conn = get_db()
    projects = conn.execute("SELECT * FROM projects ORDER BY title").fetchall()
    counts = {}
    for p in projects:
        n = conn.execute(
            "SELECT COUNT(*) FROM sessions WHERE project_id=?", (p["id"],)
        ).fetchone()[0]
        counts[p["id"]] = n
    conn.close()
    return render_template("projects.html", projects=projects, counts=counts,
                           version=VERSION, oblique=rand_oblique())


@bp.route("/projects/new", methods=["POST"])
@login_required
def new_project():
    title = request.form.get("title", "").strip()
    if title:
        conn = get_db()
        conn.execute(
            "INSERT INTO projects (title, description, color) VALUES (?,?,?)",
            (title, request.form.get("description","").strip(),
             request.form.get("color","#D4380D"))
        )
        conn.commit()
        conn.close()
    return redirect(url_for("projects.list_projects"))


@bp.route("/projects/<int:pid>")
@login_required
def view_project(pid):
    conn = get_db()
    project = conn.execute("SELECT * FROM projects WHERE id=?", (pid,)).fetchone()
    if not project:
        conn.close()
        return redirect(url_for("projects.list_projects"))
    sessions = conn.execute(
        "SELECT * FROM sessions WHERE project_id=? ORDER BY date DESC", (pid,)
    ).fetchall()
    conn.close()
    return render_template("project_detail.html", project=project, sessions=sessions,
                           version=VERSION, oblique=rand_oblique())


@bp.route("/projects/<int:pid>/edit", methods=["GET", "POST"])
@login_required
def edit_project(pid):
    conn = get_db()
    project = conn.execute("SELECT * FROM projects WHERE id=?", (pid,)).fetchone()
    conn.close()
    if not project:
        return redirect(url_for("projects.list_projects"))
    if request.method == "POST":
        title = request.form.get("title", "").strip()
        if title:
            conn = get_db()
            conn.execute(
                "UPDATE projects SET title=?, description=?, color=? WHERE id=?",
                (title,
                 request.form.get("description", "").strip(),
                 request.form.get("color", "#D4380D"),
                 pid)
            )
            conn.commit()
            conn.close()
        return redirect(url_for("projects.view_project", pid=pid))
    return render_template("project_edit.html", project=project,
                           version=VERSION, oblique=rand_oblique())


@bp.route("/projects/<int:pid>/delete", methods=["POST"])
@login_required
def delete_project(pid):
    conn = get_db()
    conn.execute("UPDATE sessions SET project_id=NULL WHERE project_id=?", (pid,))
    conn.execute("DELETE FROM projects WHERE id=?", (pid,))
    conn.commit()
    conn.close()
    return redirect(url_for("projects.list_projects"))
