from flask import Blueprint, render_template, request, redirect, url_for, jsonify, current_app
from core.constants import ITEM_TYPES, MODES, INTENTIONS
from core.whisper_client import transcribe
from .engine import LiveEngine

bp = Blueprint("live", __name__)


def _engine():
    return LiveEngine(current_app.config["DB_PATH"])


def _version():
    return current_app.config.get("VERSION", "")


@bp.route("/live")
def live():
    engine = _engine()
    return render_template("live.html",
                           ls=engine.get(),
                           catalogue=engine.get_catalogue(),
                           item_types=ITEM_TYPES,
                           modes=MODES,
                           intentions=INTENTIONS,
                           projects=engine.get_projects(),
                           version=_version())


@bp.route("/live/start", methods=["POST"])
def live_start():
    _engine().start(
        request.form.get("mode", ""),
        request.form.get("intention", ""),
        request.form.get("project_id"),
    )
    return redirect(url_for("live.live"))


@bp.route("/live/save", methods=["POST"])
def live_save():
    _engine().save(request.get_json(silent=True) or {})
    return jsonify({"status": "ok"})


@bp.route("/live/finish", methods=["POST"])
def live_finish():
    _engine().save({
        "notes_live": request.form.get("notes_live", ""),
        "machines":   ", ".join(request.form.getlist("machines")),
        "effects":    ", ".join(request.form.getlist("effects")),
        "daws":       ", ".join(request.form.getlist("daws")),
        "synths_ios": ", ".join(request.form.getlist("synths_ios")),
        "plugins":    ", ".join(request.form.getlist("plugins")),
        "mode":       request.form.get("mode", ""),
        "intention":  request.form.get("intention", ""),
    })
    return redirect(url_for("sessions.new_session", from_live=1))


@bp.route("/live/transcribe", methods=["POST"])
def live_transcribe():
    audio = request.files.get("audio")
    if not audio:
        return jsonify({"error": "no audio"}), 400
    text = transcribe(audio.read(), filename=audio.filename or "audio.webm")
    if text is None:
        return jsonify({"error": "whisper unavailable"}), 503
    return jsonify({"text": text})


@bp.route("/live/abandon", methods=["POST"])
def live_abandon():
    _engine().abandon()
    return redirect(url_for("sessions.index"))
