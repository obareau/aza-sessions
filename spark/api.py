from flask import Blueprint, render_template, current_app
from .engine import SparkEngine

bp = Blueprint("spark", __name__)


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
    focus = _engine().focus()
    return render_template("spark_focus.html", focus=focus,
                           version=current_app.config.get("VERSION", ""))
