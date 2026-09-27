from flask import Blueprint, render_template, current_app, request, jsonify, session as flask_session
from core.lore_names import propose
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


@bp.route("/api/noms-aza")
def api_noms_aza():
    """Des titres dans l'esthétique d'AZA, pour débloquer le champ Titre.

    Rien n'est enregistré et rien n'est imposé : la proposition sert à amorcer,
    elle se réécrit toujours à la main.
    """
    return jsonify(noms=propose(request.args.get("n", 1, type=int)))
