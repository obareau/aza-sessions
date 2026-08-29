import os
import json
import subprocess
from datetime import datetime
from flask import Blueprint, render_template, request, redirect, url_for, Response, jsonify, current_app, flash
from core.oblique import rand_oblique as _rand_oblique
from core.ollama_client import generate_recap
from core.constants import CHARACTERS, MODES, INTENTIONS, ITEM_TYPES, SESSION_TYPES
from .engine import SessionsEngine, catalogue_blocks, influence_blocks

bp = Blueprint("sessions", __name__)


def _engine():
    return SessionsEngine(current_app.config["DB_PATH"])


def _version():
    return current_app.config.get("VERSION", "")


def _oblique():
    return _rand_oblique(current_app.config["DB_PATH"])


def _get_config():
    config_path = current_app.config.get("CONFIG_PATH", "config.json")
    if os.path.exists(config_path):
        try:
            with open(config_path, encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {}


def _save_config(data):
    config_path = current_app.config.get("CONFIG_PATH", "config.json")
    with open(config_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)


def _form_to_data(form):
    return {
        "session_type":     form.get("session_type") or "music",
        "title":            form.get("title", "").strip(),
        "date":             form.get("date", datetime.now().strftime("%Y-%m-%d %H:%M")),
        "duration_min":     form.get("duration_min") or None,
        "mode":             form.get("mode"),
        "intention":        form.get("intention"),
        "energy_level":     form.get("energy_level") or None,
        "machines":         ", ".join(form.getlist("machines")),
        "effects":          ", ".join(form.getlist("effects")),
        "daws":             ", ".join(form.getlist("daws")),
        "synths_ios":       ", ".join(form.getlist("synths_ios")),
        "ipad":             ", ".join(form.getlist("ipad")),
        "zynthian":         ", ".join(form.getlist("zynthian")),
        "plugins":          ", ".join(form.getlist("plugins")),
        "patches":          form.get("patches"),
        "audio_file":       form.get("audio_file"),
        "timestamps":       form.get("timestamps"),
        "rating":           form.get("rating") or None,
        "tags":             form.get("tags"),
        "character":        ", ".join(form.getlist("character")),
        "lore_link":        form.get("lore_link"),
        "to_rework":        form.get("to_rework"),
        "release_potential": form.get("release_potential"),
        "tempo":            form.get("tempo"),
        "tonality":         form.get("tonality"),
        "signal_routing":   form.get("signal_routing"),
        "microfreak_algo":  form.get("microfreak_algo"),
        "linked_session":   form.get("linked_session") or None,
        "influences":       ", ".join(form.getlist("influences")),
        "oblique":          form.get("oblique"),
        "comments":         form.get("comments"),
        "recap_claude":     form.get("recap_claude"),
        "project_id":       form.get("project_id") or None,
    }


PER_PAGE = 25

@bp.route("/")
def index():
    engine = _engine()
    page = max(1, request.args.get("page", 1, type=int))
    sessions, total = engine.list_page(page, PER_PAGE)
    total_pages = max(1, (total + PER_PAGE - 1) // PER_PAGE)
    if page > total_pages:
        page = total_pages
        sessions, _ = engine.list_page(page, PER_PAGE)
    return render_template("index.html",
                           sessions=sessions,
                           oblique=_oblique(),
                           version=_version(),
                           is_search=False,
                           page=page,
                           total_pages=total_pages,
                           total=total,
                           heatmap=engine.heatmap_data())


@bp.route("/new", methods=["GET", "POST"])
def new_session():
    engine = _engine()
    if request.method == "POST":
        data = _form_to_data(request.form)
        from_live = request.form.get("_from_live")
        engine.create(data, from_live=bool(from_live))
        return redirect(url_for("sessions.index"))

    prefill = None
    if request.args.get("from_live"):
        prefill = engine.prefill_from_live()
        if prefill:
            prefill["recap_claude"] = generate_recap(prefill) or ""

    from_id = request.args.get("from")
    if from_id and not prefill:
        prefill = engine.get_plain(from_id)

    if request.args.get("from_patch") and not prefill:
        from flask import session as flask_session
        prefill = flask_session.pop("session_prefill_patch", None)

    cat = engine.get_catalogue()
    return render_template("new.html",
                           catalogue=cat,
                           catalogue_blocks=catalogue_blocks(cat),
                           item_types=ITEM_TYPES,
                           session_types=SESSION_TYPES,
                           characters=CHARACTERS,
                           modes=MODES,
                           intentions=INTENTIONS,
                           influences=engine.get_influences_active(),
                           oblique=_oblique(),
                           all_sessions=engine.list_brief(),
                           projects=engine.get_projects(),
                           prefill=prefill,
                           version=_version(),
                           now=datetime.now().strftime("%Y-%m-%dT%H:%M"))


@bp.route("/session/<int:sid>")
def view_session(sid):
    engine = _engine()
    session, linked = engine.get(sid)
    if not session:
        return redirect(url_for("sessions.index"))
    return render_template("view.html", session=session, linked=linked, version=_version())


@bp.route("/session/<int:sid>/reveal")
def reveal_audio(sid):
    engine = _engine()
    session, _ = engine.get(sid)
    if not session or not session.get("audio_file"):
        return redirect(url_for("sessions.view_session", sid=sid))
    path = session["audio_file"].strip()
    if os.path.isabs(path) and os.path.exists(path):
        subprocess.Popen(["open", "-R", path])
    elif os.path.exists(path):
        subprocess.Popen(["open", "-R", os.path.abspath(path)])
    return redirect(url_for("sessions.view_session", sid=sid))


@bp.route("/form/blank")
def form_blank():
    engine = _engine()
    cat = engine.get_catalogue()
    influences = engine.get_influences_active()
    return render_template("form_blank.html",
                           catalogue_blocks=catalogue_blocks(cat),
                           influence_blocks=influence_blocks(influences),
                           characters=CHARACTERS,
                           modes=MODES,
                           intentions=INTENTIONS,
                           oblique=_oblique(),
                           version=_version())


@bp.route("/session/<int:sid>/print")
def print_session(sid):
    engine = _engine()
    session, _ = engine.get(sid)
    if not session:
        return redirect(url_for("sessions.index"))
    return render_template("print.html", session=session, version=_version())


@bp.route("/session/<int:sid>/edit", methods=["GET", "POST"])
def edit_session(sid):
    engine = _engine()
    session = engine.get_plain(sid)
    if not session:
        return redirect(url_for("sessions.index"))

    if request.method == "POST":
        data = _form_to_data(request.form)
        engine.update(sid, data)
        return redirect(url_for("sessions.view_session", sid=sid))

    cat = engine.get_catalogue()
    return render_template("edit.html",
                           session=session,
                           catalogue=cat,
                           item_types=ITEM_TYPES,
                           session_types=SESSION_TYPES,
                           characters=CHARACTERS,
                           modes=MODES,
                           intentions=INTENTIONS,
                           influences=engine.get_influences_active(),
                           all_sessions=engine.list_brief(exclude_id=sid),
                           projects=engine.get_projects(),
                           version=_version())


@bp.route("/vite", methods=["GET", "POST"])
def quick_session():
    """Saisie minimale — une zone de texte, et c'est tout.

    Le formulaire complet compte 45 champs. C'est trop quand la fatigue tombe
    d'un coup : la fenêtre pour noter quelque chose peut se fermer avant qu'on
    ait fini de la remplir, et une session à moitié saisie ne vaut pas mieux
    qu'une session non saisie.

    Ici rien n'est obligatoire sauf le texte, la date est automatique, et la
    création est INSTANTANÉE : pas de génération de récap au moment de valider,
    parce qu'attendre cinq secondes à ce moment-là annulerait tout l'intérêt.
    Le récap se génère ensuite d'un bouton, depuis la vue de la session, ou
    jamais. Le reste des champs se complète plus tard — ou pas.
    """
    if request.method == "POST":
        texte = (request.form.get("comments") or "").strip()
        if not texte:
            flash("Rien à enregistrer.", "error")
            return redirect(url_for("sessions.quick_session"))
        sid = _engine().create({
            "comments":     texte,
            "title":        (request.form.get("title") or "").strip(),
            "machines":     (request.form.get("machines") or "").strip(),
            "session_type": request.form.get("session_type") or "music",
        })
        flash("Session enregistrée. Tu peux compléter plus tard.", "success")
        return redirect(url_for("sessions.view_session", sid=sid))

    return render_template("quick.html",
                           version=current_app.config.get("VERSION", ""),
                           oblique=_oblique())


@bp.route("/session/<int:sid>/recap", methods=["POST"])
def session_recap(sid):
    """Génère (ou régénère) le récap d'une session existante.

    Le récap n'existait jusqu'ici que sur le chemin `/new?from_live=1` : une
    session saisie normalement n'en avait donc jamais, et le module `live`
    étant inutilisé, la fonctionnalité n'a en pratique jamais tourné.

    Appel synchrone assumé (~5 s mesurées) : le service tourne en --workers 1,
    donc l'app est bloquée pendant la génération. C'est court, et le faire en
    tâche de fond demanderait une file dont ce projet n'a pas l'usage.
    """
    engine = _engine()
    session = engine.get_plain(sid)
    if session is None:
        return jsonify({"error": "Session introuvable."}), 404

    recap = generate_recap(session)
    if not recap:
        # Ollama silencieux : modèle retiré, service arrêté, timeout. L'échec
        # est muet côté client — c'est ce qui avait laissé le récap mort sans
        # que personne le voie (cf. ROADMAP, 2026-07-31).
        return jsonify({"error": "Ollama n'a rien renvoyé — vérifier le modèle "
                                 "et le service sur 192.168.1.100."}), 502

    engine.set_recap(sid, recap)
    return jsonify({"ok": True, "recap": recap})


@bp.route("/session/<int:sid>/delete", methods=["POST"])
def delete_session(sid):
    _engine().delete(sid)
    return redirect(url_for("sessions.index"))


@bp.route("/export/<int:sid>")
def export_one(sid):
    content, filename = _engine().export_md_one(sid, _version())
    if content is None:
        return "Session introuvable", 404
    return Response(content, mimetype="text/plain",
                    headers={"Content-Disposition": f"attachment; filename={filename}"})


@bp.route("/export/all")
def export_all():
    content, filename = _engine().export_md_all(_version())
    return Response(content, mimetype="text/plain",
                    headers={"Content-Disposition": f"attachment; filename={filename}"})


@bp.route("/export/csv")
def export_csv():
    content, filename = _engine().export_csv(_version())
    return Response(content, mimetype="text/csv; charset=utf-8",
                    headers={"Content-Disposition": f"attachment; filename={filename}"})


@bp.route("/session/<int:sid>/obsidian", methods=["POST"])
def export_obsidian(sid):
    cfg = _get_config()
    vault = cfg.get("obsidian_vault", "").strip()
    if not vault:
        return jsonify({"error": "Chemin vault non configuré dans les Paramètres"}), 400
    content, _ = _engine().export_md_one(sid, _version())
    if content is None:
        return jsonify({"error": "Session introuvable"}), 404
    try:
        os.makedirs(vault, exist_ok=True)
        engine = _engine()
        session = engine.get_plain(sid)
        fname = f"session_{session['date'][:10].replace('-','')}_{sid}.md"
        with open(os.path.join(vault, fname), "w", encoding="utf-8") as f:
            f.write(content)
        return jsonify({"status": "ok", "file": fname})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@bp.route("/settings/obsidian", methods=["POST"])
def settings_obsidian():
    cfg = _get_config()
    cfg["obsidian_vault"] = request.form.get("obsidian_vault", "").strip()
    _save_config(cfg)
    return redirect(url_for("sessions.settings", msg="Chemin Obsidian sauvegardé"))



@bp.route("/search")
def search():
    engine = _engine()
    q = request.args.get("q", "").strip()
    machine = request.args.get("machine", "").strip()
    session_type = request.args.get("session_type", "").strip()
    mode = request.args.get("mode", "").strip()
    intention = request.args.get("intention", "").strip()
    tag = request.args.get("tag", "").strip()
    rating = request.args.get("rating", "").strip()
    project_id = request.args.get("project_id", "").strip()
    date = request.args.get("date", "").strip()

    sessions = engine.list_all()
    if q:
        q_low = q.lower()
        sessions = [s for s in sessions if
                    q_low in (s.get("title") or "").lower() or
                    q_low in (s.get("machines") or "").lower() or
                    q_low in (s.get("effects") or "").lower() or
                    q_low in (s.get("tags") or "").lower() or
                    q_low in (s.get("comments") or "").lower() or
                    q_low in (s.get("recap_claude") or "").lower() or
                    q_low in (s.get("patches") or "").lower() or
                    q_low in (s.get("influences") or "").lower() or
                    q_low in (s.get("lore_link") or "").lower() or
                    q_low in (s.get("signal_routing") or "").lower()]
    if date:
        sessions = [s for s in sessions if (s.get("date") or "").startswith(date)]
    if machine:
        sessions = [s for s in sessions if machine.lower() in (s.get("machines") or "").lower()]
    if session_type:
        sessions = [s for s in sessions if (s.get("session_type") or "music") == session_type]
    if mode:
        sessions = [s for s in sessions if s.get("mode") == mode]
    if intention:
        sessions = [s for s in sessions if s.get("intention") == intention]
    if tag:
        sessions = [s for s in sessions if tag.lower() in (s.get("tags") or "").lower()]
    if rating:
        sessions = [s for s in sessions if str(s.get("rating") or "") == rating]
    if project_id:
        sessions = [s for s in sessions if str(s.get("project_id") or "") == project_id]

    total = len(sessions)
    page = max(1, request.args.get("page", 1, type=int))
    total_pages = max(1, (total + PER_PAGE - 1) // PER_PAGE)
    page = min(page, total_pages)
    offset = (page - 1) * PER_PAGE
    sessions = sessions[offset:offset + PER_PAGE]

    return render_template("index.html",
                           sessions=sessions,
                           oblique=_oblique(),
                           version=_version(),
                           is_search=True,
                           search_q=q,
                           search_date=date,
                           search_session_type=session_type,
                           modes=MODES,
                           intentions=INTENTIONS,
                           session_types=SESSION_TYPES,
                           projects=engine.get_projects(),
                           page=page,
                           total_pages=total_pages,
                           total=total,
                           heatmap=engine.heatmap_data())


@bp.route("/settings")
def settings():
    from core.db import get_db
    conn = get_db(current_app.config["DB_PATH"])
    nb_sessions = conn.execute("SELECT COUNT(*) FROM sessions").fetchone()[0]
    conn.close()
    msg = request.args.get("msg", "")
    cfg = _get_config()
    return render_template("settings.html", version=_version(),
                           oblique=_oblique(), nb_sessions=nb_sessions, msg=msg,
                           obsidian_vault=cfg.get("obsidian_vault", ""))
