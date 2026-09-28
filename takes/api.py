from flask import Blueprint, render_template, current_app

from core.oblique import rand_oblique
from .engine import TakesEngine

bp = Blueprint("takes", __name__)


def _engine():
    return TakesEngine(current_app.config["DB_PATH"])


@bp.route("/prises")
def index():
    """Registre des noms de prise saisis. Ne lit aucun fichier, aucun dossier."""
    engine = _engine()
    db_path = current_app.config["DB_PATH"]
    return render_template("takes.html",
                           registre=engine.registre(),
                           sans_prise=engine.sans_prise(),
                           version=current_app.config.get("VERSION", ""),
                           oblique=rand_oblique(db_path))
