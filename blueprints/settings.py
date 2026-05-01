import os
import sqlite3
import tempfile

from flask import Blueprint, Response, redirect, render_template, request, url_for

from config import get_config, save_config
from constants import VERSION
from db import DB_PATH, get_db
from helpers import rand_oblique

bp = Blueprint("settings", __name__)


@bp.route("/settings")
def settings():
    conn = get_db()
    nb_sessions = conn.execute("SELECT COUNT(*) FROM sessions").fetchone()[0]
    conn.close()
    return render_template("settings.html", version=VERSION,
                           oblique=rand_oblique(), nb_sessions=nb_sessions)


@bp.route("/settings/backup")
def settings_backup():
    with open(DB_PATH, "rb") as f:
        data = f.read()
    from datetime import datetime
    filename = f"robotariis_backup_{datetime.now().strftime('%Y%m%d_%H%M')}.db"
    return Response(data, mimetype="application/octet-stream",
                    headers={"Content-Disposition": f"attachment; filename={filename}"})


@bp.route("/settings/import", methods=["POST"])
def settings_import():
    f = request.files.get("db_file")
    if not f or not f.filename.endswith(".db"):
        return render_template("settings.html", version=VERSION,
                               oblique=rand_oblique(), nb_sessions=0,
                               error="Fichier invalide — sélectionne un fichier .db")

    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".db")
    f.save(tmp.name)
    tmp.close()

    try:
        src = sqlite3.connect(tmp.name)
        src.row_factory = sqlite3.Row

        tables = [r[0] for r in src.execute(
            "SELECT name FROM sqlite_master WHERE type='table'"
        ).fetchall()]
        if "sessions" not in tables:
            src.close()
            return render_template("settings.html", version=VERSION,
                                   oblique=rand_oblique(), nb_sessions=0,
                                   error="Ce fichier ne contient pas de table 'sessions'.")

        src_cols = {r[1] for r in src.execute("PRAGMA table_info(sessions)").fetchall()}
        dst_cols = {r[1] for r in get_db().execute("PRAGMA table_info(sessions)").fetchall()}
        common = [c for c in dst_cols if c in src_cols and c not in ("id",)]

        rows = src.execute("SELECT * FROM sessions").fetchall()
        src.close()

        if not rows:
            return render_template("settings.html", version=VERSION,
                                   oblique=rand_oblique(), nb_sessions=0,
                                   msg="La base importée ne contient aucune session.")

        dst = get_db()
        imported = 0
        skipped  = 0
        for row in rows:
            exists = dst.execute(
                "SELECT id FROM sessions WHERE date=? AND machines=?",
                (row["date"], row["machines"])
            ).fetchone()
            if exists:
                skipped += 1
                continue
            cols_str = ", ".join(common)
            placeholders = ", ".join("?" for _ in common)
            vals = tuple(row[c] for c in common)
            dst.execute(f"INSERT INTO sessions ({cols_str}) VALUES ({placeholders})", vals)
            imported += 1

        dst.commit()
        dst.close()

        nb = get_db().execute("SELECT COUNT(*) FROM sessions").fetchone()[0]
        get_db().close()
        msg = f"{imported} session(s) importée(s), {skipped} doublon(s) ignoré(s)."
        return render_template("settings.html", version=VERSION,
                               oblique=rand_oblique(), nb_sessions=nb, msg=msg)

    except Exception as e:
        return render_template("settings.html", version=VERSION,
                               oblique=rand_oblique(), nb_sessions=0,
                               error=f"Erreur lors de l'import : {str(e)}")
    finally:
        os.unlink(tmp.name)


@bp.route("/settings/reset-sessions", methods=["POST"])
def settings_reset_sessions():
    conn = get_db()
    conn.execute("DELETE FROM sessions")
    conn.execute("DELETE FROM sqlite_sequence WHERE name='sessions'")
    conn.commit()
    conn.close()
    return render_template("settings.html", version=VERSION,
                           oblique=rand_oblique(), nb_sessions=0,
                           msg="Toutes les sessions ont été supprimées.")


@bp.route("/settings/obsidian", methods=["POST"])
def settings_obsidian():
    cfg = get_config()
    cfg["obsidian_vault"] = request.form.get("obsidian_vault", "").strip()
    save_config(cfg)
    return redirect(url_for("settings.settings", msg="Chemin Obsidian sauvegardé"))
