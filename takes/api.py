import json
import os

from flask import (Blueprint, render_template, request, current_app, redirect,
                   url_for, flash, send_file, abort)

from core.oblique import rand_oblique
from .engine import TakesEngine

bp = Blueprint("takes", __name__)

# Là où la carte SD se vide. Réglable, parce qu'un chemin en dur serait un
# chemin qu'il faut modifier le code pour changer.
RACINE_DEFAUT = "~/R8-DUMP"


def _config():
    chemin = current_app.config.get("CONFIG_PATH", "config.json")
    if os.path.exists(chemin):
        try:
            with open(chemin, encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {}


def _engine():
    return TakesEngine(current_app.config["DB_PATH"],
                       _config().get("takes_path") or RACINE_DEFAUT)


@bp.route("/prises")
def index():
    engine = _engine()
    db_path = current_app.config["DB_PATH"]
    data = engine.depouille() if engine.dispo else {
        "rattachees": [], "orphelines": [], "manquantes": [], "nb_fichiers": 0}
    return render_template("takes.html",
                           dispo=engine.dispo, racine=engine.racine,
                           version=current_app.config.get("VERSION", ""),
                           oblique=rand_oblique(db_path), **data)


@bp.route("/prises/ecouter")
def listen():
    """Sert un fichier du dossier de prises, et rien d'autre.

    `chemin_sur()` refuse tout ce qui sort de la racine — sans quoi cette route
    servirait n'importe quel fichier du disque à qui devine un `../`.
    """
    chemin = _engine().chemin_sur(request.args.get("f", ""))
    if not chemin:
        abort(404)
    return send_file(chemin, conditional=True)


@bp.route("/settings/prises", methods=["POST"])
def settings_takes():
    cfg = _config()
    cfg["takes_path"] = (request.form.get("takes_path") or "").strip()
    chemin = current_app.config.get("CONFIG_PATH", "config.json")
    with open(chemin, "w", encoding="utf-8") as f:
        json.dump(cfg, f, ensure_ascii=False, indent=2)
    flash("Dossier de prises enregistré.", "success")
    return redirect(url_for("takes.index"))
