from flask import Blueprint, render_template, request, redirect, url_for, current_app
from .engine import ProjectsEngine

bp = Blueprint("projects", __name__)


def _engine():
    return ProjectsEngine(current_app.config["DB_PATH"])


def _version():
    return current_app.config.get("VERSION", "")


@bp.route("/projects")
def list_projects():
    engine = _engine()
    projects, counts = engine.list_all()
    return render_template("projects.html", projects=projects, counts=counts,
                           version=_version(), oblique=engine.rand_oblique())


@bp.route("/projects/new", methods=["POST"])
def new_project():
    title = request.form.get("title", "").strip()
    if title:
        _engine().create(
            title,
            request.form.get("description", "").strip(),
            request.form.get("color", "#D4380D"),
        )
    return redirect(url_for("projects.list_projects"))


@bp.route("/projects/<int:pid>")
def view_project(pid):
    engine = _engine()
    project, sessions = engine.get_with_sessions(pid)
    if not project:
        return redirect(url_for("projects.list_projects"))
    return render_template("project_detail.html", project=project, sessions=sessions,
                           version=_version(), oblique=engine.rand_oblique())


@bp.route("/projects/<int:pid>/edit", methods=["GET", "POST"])
def edit_project(pid):
    engine = _engine()
    project = engine.get(pid)
    if not project:
        return redirect(url_for("projects.list_projects"))
    if request.method == "POST":
        title = request.form.get("title", "").strip()
        if title:
            engine.update(
                pid, title,
                request.form.get("description", "").strip(),
                request.form.get("color", "#D4380D"),
            )
        return redirect(url_for("projects.view_project", pid=pid))
    return render_template("project_edit.html", project=project,
                           version=_version(), oblique=engine.rand_oblique())


@bp.route("/projects/<int:pid>/delete", methods=["POST"])
def delete_project(pid):
    _engine().delete(pid)
    return redirect(url_for("projects.list_projects"))
