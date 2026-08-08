import json
import os
import uuid
import urllib.request
import urllib.error
from flask import Blueprint, render_template, request, redirect, url_for, flash, Response, current_app, jsonify
from .engine import DimEngine
from core import link_service

bp = Blueprint("dim", __name__)

DIM_HOST = "localhost"
DIM_PORT = int(os.environ.get("DIM_PORT", 5002))

# AZA cue color names → hex pour D.I.M
_COLOR_MAP = {
    "blue":   "#4D7DB5",
    "green":  "#3D8A5F",
    "red":    "#E84B1A",
    "yellow": "#D4890A",
    "purple": "#8B5CF6",
    "white":  "#E8E4DC",
    "":       "#2E2C29",
}


def _engine():
    return DimEngine(current_app.config["DB_PATH"])


def _detect_dim():
    """Vérifie si une instance D.I.M tourne sur localhost:5001. Timeout 300ms."""
    try:
        req = urllib.request.urlopen(
            f"http://{DIM_HOST}:{DIM_PORT}/api/state", timeout=0.3
        )
        return req.status == 200
    except Exception:
        return False


def _duree_cue_secondes(cue):
    """Durée d'un cue en secondes.

    ⚠️ Le champ est `time_s` (entier), écrit par `dim/engine.py`. Le
    convertisseur lisait `time` — un champ qui n'a jamais existé — et
    retombait donc sur 0, puis sur 4 mesures par défaut : **tous les cues
    étaient exportés à 4 mesures, quelle que soit leur durée réelle.**
    Le format "MM:SS" est gardé en repli au cas où d'anciennes données
    traîneraient.
    """
    v = cue.get("time_s")
    if isinstance(v, (int, float)) and v > 0:
        return int(v)
    t = str(cue.get("time") or "").strip()
    if not t:
        return 0
    try:
        parts = t.split(":")
        return int(parts[0]) * 60 + int(parts[1]) if len(parts) == 2 else int(parts[0])
    except (ValueError, IndexError):
        return 0


def _tempo_export(demande=None):
    """Tempo servant à convertir les secondes en mesures.

    Priorité : valeur explicite → grille Ableton Link en cours → 120.

    ⚠️ Convertir à 120 BPM en dur était faux dès que la session ne jouait pas
    à 120 : à 115 BPM une mesure fait 2,087 s et l'écart s'accumule à chaque
    cue. On prend donc le tempo réel du réseau quand il est connu.

    ℹ️ Le tempo retenu est écrit dans `project.tempo_bpm` : l'export reste
    auditable, on sait toujours sur quelle base les mesures ont été calculées.
    """
    if demande:
        try:
            v = float(demande)
            if 20.0 <= v <= 999.0:
                return v
        except (TypeError, ValueError):
            pass
    etat = link_service.state()
    if etat.get("available") and etat.get("peers", 0) > 0:
        return float(etat["tempo"])
    return 120.0


def _script_to_dim_json(script, tempo=None):
    """Convertit un script AZA (cues linéaires) en project D.I.M JSON (1 lane)."""
    cues = json.loads(script.get("cues") or "[]")
    bpm = _tempo_export(tempo)
    # En 4/4, une mesure dure 4 temps = 240/BPM secondes.
    sec_par_mesure = 240.0 / bpm
    sections = []
    for i, cue in enumerate(cues):
        secs = _duree_cue_secondes(cue)
        duration_bars = round(secs / sec_par_mesure, 2) if secs > 0 else 4.0

        sections.append({
            "id": f"s-{i}",
            "name": cue.get("patch") or f"Cue {i + 1}",
            "type": "custom",
            "color": _COLOR_MAP.get(cue.get("color", ""), "#2E2C29"),
            "instruction": {"op": "PLAY"},
            "playlist": {"mode": "all"},
            "cues": [{
                "id": f"c-{i}-0",
                "label": cue.get("patch") or f"Cue {i + 1}",
                "content": cue.get("action") or "",
                "duration_bars": duration_bars,
                "repeat": 1,
                "instruction": {"op": "PLAY"},
                "enabled": True,
                "order_index": 0,
            }],
        })

    return {
        "dim_version": "1.0",
        "project": {
            "id": f"aza-{script['id']}-{uuid.uuid4().hex[:8]}",
            "name": script.get("title") or "Script AZA",
            "tempo_bpm": round(bpm, 2),
            "time_signature": "4/4",
            "gosub_stack_limit": 4,
            "lanes": [{
                "id": "lane-0",
                "name": script.get("title") or "AZA",
                "color": "#E84B1A",
                "speed_ratio": "1:1",
                "is_conductor": False,
                "sections": sections,
            }],
            "arrangement": [],
        },
    }


@bp.route("/prompter")
def prompter_list():
    engine = _engine()
    scripts = engine.list_scripts()
    dim_active = _detect_dim()
    dim_url = f"http://{DIM_HOST}:{DIM_PORT}" if dim_active else None
    return render_template("prompter_list.html", scripts=scripts,
                           version=current_app.config.get("VERSION", ""),
                           oblique=engine.rand_oblique(),
                           dim_active=dim_active,
                           dim_url=dim_url)


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


# ---------------------------------------------------------------------------
# Ableton Link — le Prompteur lit la grille partagée du réseau
# ⚠️ Le navigateur ne peut pas parler Link (multicast UDP) : il interroge ceci.
# ---------------------------------------------------------------------------

@bp.route("/api/link/state")
def link_state():
    """Tempo, phase et nombre de pairs. Renvoie toujours 200 : l'absence de
    Link n'est pas une erreur, c'est un état (`available: false`), et le widget
    se cache tout seul plutôt que de faire clignoter une alerte pendant un set."""
    return jsonify(link_service.state())


@bp.route("/prompter/<int:sid>/export/json")
def prompter_export_json(sid):
    result = _engine().export_json(sid)
    if not result:
        return redirect(url_for("dim.prompter_list"))
    data, filename = result
    return Response(data, mimetype="application/json",
                    headers={"Content-Disposition": f"attachment; filename=\"{filename}\""})


@bp.route("/prompter/<int:sid>/export/dim")
def prompter_export_dim(sid):
    """Export au format D.I.M JSON natif — importable directement dans D.I.M."""
    script = _engine().get_script(sid)
    if not script:
        return redirect(url_for("dim.prompter_list"))
    # ?tempo=115 force la base de conversion ; sinon Link, sinon 120.
    payload = _script_to_dim_json(script, request.args.get("tempo"))
    filename = f"dim_{script['title'].replace(' ', '_')[:40]}.json"
    return Response(
        json.dumps(payload, indent=2, ensure_ascii=False),
        mimetype="application/json",
        headers={"Content-Disposition": f"attachment; filename=\"{filename}\""},
    )


@bp.route("/api/dim/script/<int:sid>")
def api_dim_script(sid):
    """
    GET /api/dim/script/<id>
    Retourne le script AZA converti au format D.I.M JSON.
    D.I.M peut fetch cette URL directement pour importer le script.
    """
    script = _engine().get_script(sid)
    if not script:
        return jsonify({"error": "script not found"}), 404
    return jsonify(_script_to_dim_json(script, request.args.get("tempo")))


@bp.route("/api/dim/scripts")
def api_dim_scripts():
    """
    GET /api/dim/scripts
    Liste tous les scripts AZA avec leur URL d'import D.I.M.
    """
    scripts = _engine().list_scripts()
    return jsonify([{
        "id": s["id"],
        "title": s["title"],
        "description": s.get("description") or "",
        "cue_count": len(json.loads(s.get("cues") or "[]")),
        "created_at": s["created_at"],
        "dim_import_url": url_for("dim.api_dim_script", sid=s["id"], _external=True),
    } for s in scripts])


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
