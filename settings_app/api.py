import os
import tempfile
from flask import Blueprint, render_template, request, redirect, url_for, Response, current_app
from .engine import SettingsEngine

bp = Blueprint("settings_app", __name__)


def _engine():
    return SettingsEngine(
        current_app.config["DB_PATH"],
        current_app.config["CONFIG_PATH"],
    )


def _version():
    return current_app.config.get("VERSION", "")


@bp.route("/settings")
def settings():
    engine = _engine()
    return render_template("settings.html", version=_version(),
                           oblique=engine.rand_oblique(),
                           nb_sessions=engine.count_sessions())


@bp.route("/settings/backup")
def settings_backup():
    engine = _engine()
    data, filename = engine.backup_data()
    return Response(data, mimetype="application/octet-stream",
                    headers={"Content-Disposition": f"attachment; filename={filename}"})


@bp.route("/settings/import", methods=["POST"])
def settings_import():
    engine = _engine()
    f = request.files.get("db_file")
    if not f or not f.filename.endswith(".db"):
        return render_template("settings.html", version=_version(),
                               oblique=engine.rand_oblique(), nb_sessions=0,
                               error="Fichier invalide — sélectionne un fichier .db")

    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".db")
    f.save(tmp.name)
    tmp.close()

    try:
        imported, skipped, total, error = engine.import_db(tmp.name)
        if error:
            return render_template("settings.html", version=_version(),
                                   oblique=engine.rand_oblique(), nb_sessions=0,
                                   error=f"Erreur lors de l'import : {error}")
        if imported == 0 and skipped == 0:
            return render_template("settings.html", version=_version(),
                                   oblique=engine.rand_oblique(), nb_sessions=0,
                                   msg="La base importée ne contient aucune session.")
        msg = f"{imported} session(s) importée(s), {skipped} doublon(s) ignoré(s)."
        return render_template("settings.html", version=_version(),
                               oblique=engine.rand_oblique(), nb_sessions=total, msg=msg)
    finally:
        os.unlink(tmp.name)


@bp.route("/settings/reset-sessions", methods=["POST"])
def settings_reset_sessions():
    engine = _engine()
    engine.reset_sessions()
    return render_template("settings.html", version=_version(),
                           oblique=engine.rand_oblique(), nb_sessions=0,
                           msg="Toutes les sessions ont été supprimées.")
