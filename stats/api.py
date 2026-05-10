import json
from flask import Blueprint, render_template, current_app, jsonify
from core.oblique import rand_oblique as _rand_oblique
from .engine import StatsEngine

bp = Blueprint("stats", __name__)


def _engine():
    return StatsEngine(current_app.config["DB_PATH"])


def _oblique():
    return _rand_oblique(current_app.config["DB_PATH"])


def _version():
    return current_app.config.get("VERSION", "")


@bp.route("/stats")
def stats():
    data = _engine().compute()
    if data is None:
        return render_template("stats.html", version=_version(),
                               oblique=_oblique(), stats_data=None, total=0)
    return render_template("stats.html", version=_version(),
                           oblique=_oblique(),
                           stats_data=json.dumps(data),
                           stats=data, total=data["total"])


@bp.route("/api/stats/summary")
def stats_summary():
    """Résumé JSON pour n8n Daily Digest."""
    data = _engine().compute()
    if data is None:
        return jsonify({"total": 0})
    return jsonify({
        "total":         data["total"],
        "avg_duration":  data["avg_duration"],
        "release_count": data["release_count"],
        "rework_count":  data["rework_count"],
        "streak":        data.get("streak", 0),
        "top_machine":   data.get("top_machine"),
        "top_mode":      max(data["modes"], key=data["modes"].get) if data.get("modes") else None,
        "this_month":    data.get("this_month", 0),
    })
