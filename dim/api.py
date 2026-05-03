import json
from flask import Blueprint, render_template, request, redirect, url_for, flash, Response, current_app
from .engine import DimEngine

bp = Blueprint("dim", __name__)


def _engine():
    return DimEngine(current_app.config["DB_PATH"])


@bp.route("/prompter")
def prompter_list():
    engine = _engine()
    scripts = engine.list_scripts()
    return render_template("prompter_list.html", scripts=scripts,
                           version=current_app.config.get("VERSION", ""),
                           oblique=engine.rand_oblique())


@bp.route("/prompter/new", methods=["GET", "POST"])
@bp.route("/prompter/<int:sid>/edit", methods=["GET", "POST"])
def prompter_edit(sid=None):
    engine = _engine()
    script = engine.get_script(sid) if sid else None

    if sid and not script:
        return redirect(url_for("dim.prompter_list"))

    if request.method == "POST":
        title       = request.form.get("title", "").strip() or "Script sans titre"
        description = request.form.get("description", "").strip()
        cues = DimEngine.parse_form_cues(
            request.form.getlist("cue_time[]"),
            request.form.getlist("cue_patch[]"),
            request.form.getlist("cue_action[]"),
            request.form.getlist("cue_color[]"),
        )
        engine.save(sid, title, description, cues)
        return redirect(url_for("dim.prompter_list"))

    cues = json.loads(script["cues"]) if script else []
    return render_template("prompter_edit.html", script=script, cues=cues,
                           version=current_app.config.get("VERSION", ""),
                           oblique=engine.rand_oblique())


@bp.route("/prompter/<int:sid>/delete", methods=["POST"])
def prompter_delete(sid):
    _engine().delete(sid)
    return redirect(url_for("dim.prompter_list"))


@bp.route("/prompter/<int:sid>/play")
def prompter_play(sid):
    engine = _engine()
    script = engine.get_script(sid)
    if not script:
        return redirect(url_for("dim.prompter_list"))
    cues = json.loads(script["cues"])
    return render_template("prompter_play.html", script=script, cues=cues,
                           version=current_app.config.get("VERSION", ""))


@bp.route("/prompter/<int:sid>/export/json")
def prompter_export_json(sid):
    result = _engine().export_json(sid)
    if not result:
        return redirect(url_for("dim.prompter_list"))
    data, filename = result
    return Response(data, mimetype="application/json",
                    headers={"Content-Disposition": f"attachment; filename=\"{filename}\""})


@bp.route("/prompter/<int:sid>/export/md")
def prompter_export_md(sid):
    result = _engine().export_md(sid)
    if not result:
        return redirect(url_for("dim.prompter_list"))
    data, filename = result
    return Response(data, mimetype="text/markdown",
                    headers={"Content-Disposition": f"attachment; filename=\"{filename}\""})


@bp.route("/prompter/import", methods=["POST"])
def prompter_import():
    engine = _engine()
    f = request.files.get("import_file")
    if not f:
        flash("Aucun fichier fourni.", "error")
        return redirect(url_for("dim.prompter_list"))
    try:
        raw = f.read().decode("utf-8")
        title, description, cues = engine.import_raw(raw, f.filename)
        new_id = engine.save(None, title, description, cues)
        flash(f"Script « {title} » importé avec succès ({len(cues)} cues).", "success")
        return redirect(url_for("dim.prompter_edit", sid=new_id))
    except Exception as e:
        flash(f"Erreur d'import : {e}", "error")
        return redirect(url_for("dim.prompter_list"))
