"""SysEx Loader — envoi SysEx DX7/Volca FM via Web MIDI API."""
import sqlite3
from flask import (Blueprint, render_template, request, redirect,
                   url_for, jsonify, Response, current_app)
from core.db import get_db

bp = Blueprint("sysex", __name__)


def _version():
    return current_app.config.get("VERSION", "")


def _db():
    return get_db(current_app.config["DB_PATH"])


@bp.route("/sysex")
def sysex_index():
    conn = _db()
    banks = conn.execute(
        "SELECT id, name, format, size, created_at FROM sysex_banks ORDER BY created_at DESC"
    ).fetchall()
    conn.close()
    return render_template("sysex.html", banks=[dict(b) for b in banks], version=_version())


@bp.route("/sysex/save", methods=["POST"])
def sysex_save():
    f = request.files.get("file")
    name = request.form.get("name", "").strip()
    if not f:
        return redirect(url_for("sysex.sysex_index"))
    data = f.read()
    size = len(data)
    if size == 4104:
        fmt = "32-voice bulk"
    elif size == 163:
        fmt = "single voice"
    else:
        fmt = f"raw ({size} bytes)"
    if not name:
        name = (f.filename or "bank").rsplit(".", 1)[0]
    conn = _db()
    conn.execute(
        "INSERT INTO sysex_banks (name, format, size, data) VALUES (?,?,?,?)",
        (name, fmt, size, sqlite3.Binary(data))
    )
    conn.commit()
    conn.close()
    return redirect(url_for("sysex.sysex_index"))


@bp.route("/sysex/<int:bid>/data")
def sysex_data(bid):
    """Retourne les bytes SysEx en JSON pour envoi MIDI côté client."""
    conn = _db()
    row = conn.execute("SELECT data, name, format FROM sysex_banks WHERE id=?", (bid,)).fetchone()
    conn.close()
    if not row:
        return jsonify({"error": "not found"}), 404
    return jsonify({"data": list(bytes(row["data"])), "name": row["name"], "format": row["format"]})


@bp.route("/sysex/<int:bid>/download")
def sysex_download(bid):
    conn = _db()
    row = conn.execute("SELECT name, data FROM sysex_banks WHERE id=?", (bid,)).fetchone()
    conn.close()
    if not row:
        return redirect(url_for("sysex.sysex_index"))
    fname = row["name"].replace(" ", "_") + ".syx"
    return Response(bytes(row["data"]), mimetype="application/octet-stream",
                    headers={"Content-Disposition": f'attachment; filename="{fname}"'})


@bp.route("/sysex/<int:bid>/delete", methods=["POST"])
def sysex_delete(bid):
    conn = _db()
    conn.execute("DELETE FROM sysex_banks WHERE id=?", (bid,))
    conn.commit()
    conn.close()
    return redirect(url_for("sysex.sysex_index"))
