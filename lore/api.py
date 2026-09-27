import json
import os

from flask import Blueprint, render_template, request, current_app, jsonify, redirect, url_for, flash

from core.oblique import rand_oblique
from .engine import SECTIONS, LoreEngine

bp = Blueprint("lore", __name__)

# Là où le corpus vit par défaut. Réglable dans les Paramètres, parce qu'un
# chemin en dur dans le code du journal serait un chemin qu'il faut recompiler
# pour déménager le vault.
RACINE_DEFAUT = "~/robotariis/PUBLICATIONS-QUARTZ"


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
    return LoreEngine(_config().get("lore_path") or RACINE_DEFAUT)


def _commun(engine):
    """Ce que toutes les vues lore portent : version, stratégie, citation."""
    return {
        "version":  current_app.config.get("VERSION", ""),
        "oblique":  rand_oblique(current_app.config["DB_PATH"]),
        "citation": engine.citation(),
        "dispo":    engine.dispo,
        "racine":   engine.racine,
    }


@bp.route("/lore")
def index():
    engine = _engine()
    q = (request.args.get("q") or "").strip()
    return render_template("lore_index.html",
                           sections=engine.sections(),
                           resultats=engine.cherche(q) if q else None,
                           q=q, **_commun(engine))


@bp.route("/lore/timeline")
def timeline():
    engine = _engine()
    return render_template("lore_timeline.html",
                           lignes=engine.timeline(), **_commun(engine))


@bp.route("/lore/section/<section>")
def section(section):
    engine = _engine()
    if section not in SECTIONS:
        flash(f"Section de lore inconnue : {section}", "error")
        return redirect(url_for("lore.index"))
    return render_template("lore_section.html",
                           section=section, section_nom=SECTIONS[section],
                           entrees=engine.entrees(section), **_commun(engine))


@bp.route("/lore/citations")
def citations():
    engine = _engine()
    return render_template("lore_citations.html",
                           citations=engine.citations(), **_commun(engine))


@bp.route("/api/citation")
def api_citation():
    """Une citation du corpus. Rien n'est enregistré : le vault est la source."""
    return jsonify(_engine().citation() or {})


@bp.route("/api/lore/entrees")
def api_entrees():
    """Les titres du corpus, pour alimenter la saisie du champ `lore_link`.

    C'est ce qui rend possible, plus tard, la carte et la frise reliées aux
    sessions : sans liens réels, elles n'auraient rien à montrer.
    """
    return jsonify(entrees=[{"titre": e["titre"], "section": e["section_nom"],
                             "slug": e["slug"]}
                            for e in _engine().tout()])


@bp.route("/settings/lore", methods=["POST"])
def settings_lore():
    cfg = _config()
    cfg["lore_path"] = (request.form.get("lore_path") or "").strip()
    chemin = current_app.config.get("CONFIG_PATH", "config.json")
    with open(chemin, "w", encoding="utf-8") as f:
        json.dump(cfg, f, ensure_ascii=False, indent=2)
    flash("Chemin du corpus de lore enregistré.", "success")
    return redirect(url_for("lore.index"))
