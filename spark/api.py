from flask import Blueprint, render_template, current_app, session as flask_session
from .engine import SparkEngine

bp = Blueprint("spark", __name__)

SEEN_MAX = 8  # taille de l'historique avant reset


def _engine():
    return SparkEngine(current_app.config["DB_PATH"])


@bp.route("/spark")
def spark():
    data = _engine().suggestions()
    return render_template("spark.html", suggestions=data["suggestions"],
                           total=data["total"],
                           version=current_app.config.get("VERSION", ""))


@bp.route("/spark/focus")
def spark_focus():
    seen = flask_session.get("spark_seen", [])
    focus = _engine().focus(exclude=seen)

    key = focus.pop("_key", None)
    if key:
        seen.append(key)
        if len(seen) > SEEN_MAX:
            seen = seen[-SEEN_MAX:]
        flask_session["spark_seen"] = seen

    return render_template("spark_focus.html", focus=focus,
                           version=current_app.config.get("VERSION", ""))
