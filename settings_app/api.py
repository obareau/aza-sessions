import os
import subprocess
import sys
import tempfile

from flask import (
    Blueprint,
    Response,
    current_app,
    flash,
    redirect,
    render_template,
    request,
    send_file,
    url_for,
)

from core import journal as jr

from .engine import SettingsEngine

bp = Blueprint("settings_app", __name__)


def _engine():
    return SettingsEngine(
        current_app.config["DB_PATH"],
        current_app.config["CONFIG_PATH"],
    )


def _version():
    return current_app.config.get("VERSION", "")


def _journal():
    """La veille de l'app ; à défaut (app montée autrement), une instance locale."""
    j = current_app.extensions.get("aza_journal")
    if j is None:
        j = jr.Journal(current_app.config["DB_PATH"],
                       current_app.config["JSON_BACKUP_DIR"], _version())
        current_app.extensions["aza_journal"] = j
    return j


def _render(**extra):
    engine = _engine()
    j = _journal()
    ctx = {
        "version": _version(),
        "oblique": engine.rand_oblique(),
        "nb_sessions": engine.count_sessions(),
        "sauvegarde": j.status(),
        "snapshots": jr.list_snapshots(j.backup_dir)[:12],
        "peut_ouvrir_dossier": sys.platform == "darwin",
        "premiere": request.args.get("premiere") == "1",
        "msg": request.args.get("msg", ""),
    }
    ctx.update(extra)
    return render_template("settings.html", **ctx)


def _filet(label):
    """Copie de sécurité AVANT une opération destructive.

    Retourne le nom du fichier écrit, ou None si la copie a échoué — auquel cas
    l'opération ne doit PAS avoir lieu : détruire sans filet, c'est ce qui a
    coûté l'historique jusqu'ici.
    """
    path = _journal().save_now(label=label)
    return os.path.basename(path) if path else None


def _refus_sans_filet():
    flash("✕ Opération annulée : la copie de sécurité n'a pas pu être écrite "
          f"({_journal().last_error}). Rien n'a été modifié.", "error")
    return redirect(url_for("settings_app.settings"))


@bp.route("/settings")
def settings():
    return _render()


# ── SAUVEGARDES ──────────────────────────────────────────────────────────────

@bp.route("/settings/backup")
def settings_backup():
    engine = _engine()
    data, filename = engine.backup_data()
    return Response(data, mimetype="application/octet-stream",
                    headers={"Content-Disposition": f"attachment; filename={filename}"})


@bp.route("/settings/export.json")
def settings_export_json():
    dump = jr.dump_db(current_app.config["DB_PATH"], _version())
    stamp = dump["created_at"].replace(":", "-").replace("T", "_")
    return Response(jr.to_json(dump), mimetype="application/json",
                    headers={"Content-Disposition":
                             f"attachment; filename=aza-sessions_{stamp}.json"})


@bp.route("/settings/sauvegarder", methods=["POST"])
def settings_save_now():
    j = _journal()
    path = j.save_now()
    if path:
        flash(f"✓ Sauvegarde écrite : {os.path.basename(path)}", "success")
    elif j.last_error:
        flash(f"✕ Sauvegarde en échec : {j.last_error}", "error")
    else:
        flash("✓ Rien de neuf depuis la dernière sauvegarde — elle est à jour.", "success")
    return redirect(url_for("settings_app.settings"))


@bp.route("/api/sauvegarde", methods=["POST"])
def backup_now_api():
    """⌘S dans l'app Mac : sauvegarde immédiate, réponse en JSON."""
    j = _journal()
    path = j.save_now()
    state = j.status()
    state["ecrit"] = os.path.basename(path) if path else None
    return state, (500 if j.last_error else 200)


@bp.route("/api/sauvegarde/etat")
def backup_status():
    """État de la sauvegarde, pour l'app Mac et pour qui veut le surveiller."""
    return _journal().status()


def _snapshot_path(name):
    """Chemin d'une sauvegarde LISTÉE — jamais un chemin fabriqué depuis l'URL."""
    for snap in jr.list_snapshots(_journal().backup_dir):
        if snap["name"] == name:
            return snap["path"]
    return None


@bp.route("/settings/sauvegardes/<name>")
def settings_snapshot_download(name):
    path = _snapshot_path(name)
    if not path:
        flash("✕ Sauvegarde introuvable.", "error")
        return redirect(url_for("settings_app.settings"))
    return send_file(path, mimetype="application/json", as_attachment=True,
                     download_name=name)


@bp.route("/settings/sauvegardes/ouvrir", methods=["POST"])
def settings_open_folder():
    folder = _journal().backup_dir
    os.makedirs(folder, exist_ok=True)
    if sys.platform == "darwin":
        subprocess.Popen(["open", folder])
    return redirect(url_for("settings_app.settings"))


# ── RESTAURATION ─────────────────────────────────────────────────────────────

def _restaurer(dump, allow_unknown):
    """Restaure `dump` après avoir écrit la copie de sécurité. Flash le résultat."""
    try:
        jr.check_dump(dump)
    except jr.RestoreError as exc:
        flash(f"✕ Restauration refusée : {exc}. Rien n'a été modifié.", "error")
        return redirect(url_for("settings_app.settings"))

    avant = _filet("avant-restauration")
    if not avant:
        return _refus_sans_filet()
    try:
        report = jr.restore(current_app.config["DB_PATH"], dump,
                            allow_unknown=allow_unknown)
    except jr.RestoreError as exc:
        flash(f"✕ Restauration refusée : {exc}. Rien n'a été modifié.", "error")
        return redirect(url_for("settings_app.settings"))

    _journal().save_now()
    counts = report["counts"]
    resume = ", ".join(f"{n} {t}" for t, n in sorted(counts.items()) if n)
    flash(f"✓ Base restaurée — {counts.get('sessions', 0)} séance(s). Détail : {resume}. "
          f"L'état précédent est gardé dans {avant}.", "success")
    if report["ignored"]:
        flash("⚠ Ignoré, absent de cette version : " + ", ".join(report["ignored"]), "error")
    return redirect(url_for("settings_app.settings"))


@bp.route("/settings/restaurer", methods=["POST"])
def settings_restore():
    f = request.files.get("backup_file")
    if not f or not f.filename:
        flash("✕ Choisis un fichier de sauvegarde (.json) ou une base (.db).", "error")
        return redirect(url_for("settings_app.settings"))
    fd, tmp = tempfile.mkstemp(suffix=os.path.splitext(f.filename)[1] or ".bin")
    os.close(fd)
    try:
        f.save(tmp)
        try:
            dump = jr.load_file(tmp)
        except jr.RestoreError as exc:
            flash(f"✕ {f.filename} : {exc}. Rien n'a été modifié.", "error")
            return redirect(url_for("settings_app.settings"))
        return _restaurer(dump, request.form.get("allow_unknown") == "1")
    finally:
        os.remove(tmp)


@bp.route("/settings/sauvegardes/<name>/restaurer", methods=["POST"])
def settings_snapshot_restore(name):
    path = _snapshot_path(name)
    if not path:
        flash("✕ Sauvegarde introuvable.", "error")
        return redirect(url_for("settings_app.settings"))
    try:
        dump = jr.load_file(path)
    except jr.RestoreError as exc:
        flash(f"✕ {name} : {exc}. Rien n'a été modifié.", "error")
        return redirect(url_for("settings_app.settings"))
    return _restaurer(dump, allow_unknown=False)


# ── IMPORT (fusion) & VIDAGE ─────────────────────────────────────────────────

@bp.route("/settings/import", methods=["POST"])
def settings_import():
    engine = _engine()
    f = request.files.get("db_file")
    if not f or not f.filename.endswith(".db"):
        return _render(error="Fichier invalide — sélectionne un fichier .db")

    avant = _filet("avant-import")
    if not avant:
        return _refus_sans_filet()

    fd, tmp = tempfile.mkstemp(suffix=".db")
    os.close(fd)
    f.save(tmp)

    try:
        imported, skipped, _total, error = engine.import_db(tmp)
        if error:
            return _render(error=f"Erreur lors de l'import : {error}")
        if imported == 0 and skipped == 0:
            return _render(msg="La base importée ne contient aucune session.")
        return _render(msg=f"{imported} session(s) importée(s), {skipped} doublon(s) ignoré(s). "
                           f"État précédent gardé dans {avant}.")
    finally:
        os.unlink(tmp)


@bp.route("/settings/reset-sessions", methods=["POST"])
def settings_reset_sessions():
    avant = _filet("avant-vidage")
    if not avant:
        return _refus_sans_filet()
    _engine().reset_sessions()
    _journal().save_now()
    return _render(msg=f"Toutes les sessions ont été supprimées. Elles restent dans {avant} "
                       "— restaurable ci-dessous.")
