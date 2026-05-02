import json

from flask_login import login_required

from flask import Blueprint, Response, flash, redirect, render_template, request, url_for

from constants import VERSION
from db import get_db
from helpers import rand_oblique

bp = Blueprint("prompter", __name__)


@bp.route("/prompter")
@login_required
def prompter_list():
    conn = get_db()
    scripts = conn.execute("SELECT * FROM prompter_scripts ORDER BY created_at DESC").fetchall()
    conn.close()
    return render_template("prompter_list.html", scripts=scripts, version=VERSION, oblique=rand_oblique())


@bp.route("/prompter/new", methods=["GET", "POST"])
@bp.route("/prompter/<int:sid>/edit", methods=["GET", "POST"])
@login_required
def prompter_edit(sid=None):
    conn = get_db()
    script = None
    if sid:
        script = conn.execute("SELECT * FROM prompter_scripts WHERE id=?", (sid,)).fetchone()
        if not script:
            conn.close()
            return redirect(url_for("prompter.prompter_list"))

    if request.method == "POST":
        title = request.form.get("title", "").strip() or "Script sans titre"
        description = request.form.get("description", "").strip()
        times   = request.form.getlist("cue_time[]")
        patches = request.form.getlist("cue_patch[]")
        actions = request.form.getlist("cue_action[]")
        colors  = request.form.getlist("cue_color[]")
        cues = []
        for t, p, a, c in zip(times, patches, actions, colors):
            if p.strip() or a.strip():
                secs = 0
                if t.strip():
                    parts = t.strip().split(":")
                    try:
                        if len(parts) == 2:
                            secs = int(parts[0]) * 60 + int(parts[1])
                        else:
                            secs = int(parts[0])
                    except ValueError:
                        secs = 0
                cues.append({"time_s": secs, "time_fmt": t.strip(), "patch": p.strip(), "action": a.strip(), "color": c or "default"})

        cues_json = json.dumps(cues, ensure_ascii=False)
        if sid:
            conn.execute("UPDATE prompter_scripts SET title=?, description=?, cues=? WHERE id=?",
                         (title, description, cues_json, sid))
        else:
            conn.execute("INSERT INTO prompter_scripts (title, description, cues) VALUES (?,?,?)",
                         (title, description, cues_json))
        conn.commit()
        conn.close()
        return redirect(url_for("prompter.prompter_list"))

    conn.close()
    cues = json.loads(script["cues"]) if script else []
    return render_template("prompter_edit.html", script=script, cues=cues, version=VERSION, oblique=rand_oblique())


@bp.route("/prompter/<int:sid>/delete", methods=["POST"])
@login_required
def prompter_delete(sid):
    conn = get_db()
    conn.execute("DELETE FROM prompter_scripts WHERE id=?", (sid,))
    conn.commit()
    conn.close()
    return redirect(url_for("prompter.prompter_list"))


@bp.route("/prompter/<int:sid>/play")
@login_required
def prompter_play(sid):
    conn = get_db()
    script = conn.execute("SELECT * FROM prompter_scripts WHERE id=?", (sid,)).fetchone()
    conn.close()
    if not script:
        return redirect(url_for("prompter.prompter_list"))
    cues = json.loads(script["cues"])
    return render_template("prompter_play.html", script=script, cues=cues, version=VERSION)


@bp.route("/prompter/<int:sid>/export/json")
@login_required
def prompter_export_json(sid):
    conn = get_db()
    script = conn.execute("SELECT * FROM prompter_scripts WHERE id=?", (sid,)).fetchone()
    conn.close()
    if not script:
        return redirect(url_for("prompter.prompter_list"))
    payload = {
        "title":       script["title"],
        "description": script["description"] or "",
        "cues":        json.loads(script["cues"])
    }
    data = json.dumps(payload, ensure_ascii=False, indent=2)
    filename = script["title"].lower().replace(" ", "_")[:40] + ".json"
    return Response(data, mimetype="application/json",
                    headers={"Content-Disposition": f"attachment; filename=\"{filename}\""})


@bp.route("/prompter/<int:sid>/export/md")
@login_required
def prompter_export_md(sid):
    conn = get_db()
    script = conn.execute("SELECT * FROM prompter_scripts WHERE id=?", (sid,)).fetchone()
    conn.close()
    if not script:
        return redirect(url_for("prompter.prompter_list"))
    cues = json.loads(script["cues"])
    lines = [f"# {script['title']}"]
    if script["description"]:
        lines.append(f"\n> {script['description']}\n")
    lines.append("\n| Temps  | Patch | Action | Couleur |")
    lines.append("|--------|-------|--------|---------|")
    for c in cues:
        t = c.get("time_fmt") or "—"
        p = (c.get("patch")  or "—").replace("|", "\\|")
        a = (c.get("action") or "—").replace("|", "\\|")
        col = c.get("color") or "default"
        lines.append(f"| {t} | {p} | {a} | {col} |")
    data = "\n".join(lines) + "\n"
    filename = script["title"].lower().replace(" ", "_")[:40] + ".md"
    return Response(data, mimetype="text/markdown",
                    headers={"Content-Disposition": f"attachment; filename=\"{filename}\""})


@bp.route("/prompter/import", methods=["POST"])
@login_required
def prompter_import():
    f = request.files.get("import_file")
    if not f:
        flash("Aucun fichier fourni.", "error")
        return redirect(url_for("prompter.prompter_list"))
    try:
        raw = f.read().decode("utf-8")
        if f.filename.endswith(".md") or f.filename.endswith(".txt"):
            title, description, cues = "", "", []
            for line in raw.splitlines():
                line = line.strip()
                if line.startswith("# ") and not title:
                    title = line[2:].strip()
                elif line.startswith("> ") and not description:
                    description = line[2:].strip()
                elif line.startswith("|") and not line.startswith("|---"):
                    cells = [c.strip() for c in line.strip("|").split("|")]
                    if len(cells) >= 3 and cells[0] != "Temps":
                        t_fmt = cells[0] if cells[0] != "—" else ""
                        patch  = cells[1] if cells[1] != "—" else ""
                        action = cells[2] if cells[2] != "—" else ""
                        color  = cells[3] if len(cells) > 3 and cells[3] not in ("—","Couleur") else "default"
                        secs = 0
                        if t_fmt:
                            parts = t_fmt.split(":")
                            try:
                                secs = int(parts[0])*60 + int(parts[1]) if len(parts)==2 else int(parts[0])
                            except ValueError:
                                secs = 0
                        cues.append({"time_fmt": t_fmt, "time_s": secs, "patch": patch, "action": action, "color": color})
        else:
            payload = json.loads(raw)
            title       = payload.get("title", "Script importé")
            description = payload.get("description", "")
            raw_cues    = payload.get("cues", [])
            cues = []
            for c in raw_cues:
                t_fmt = c.get("time_fmt", "")
                secs  = c.get("time_s", 0)
                cues.append({
                    "time_fmt": t_fmt,
                    "time_s":   int(secs),
                    "patch":    c.get("patch",  ""),
                    "action":   c.get("action", ""),
                    "color":    c.get("color",  "default")
                })
        if not title:
            title = "Script importé"
        conn = get_db()
        conn.execute("INSERT INTO prompter_scripts (title, description, cues) VALUES (?,?,?)",
                     (title, description, json.dumps(cues, ensure_ascii=False)))
        conn.commit()
        new_id = conn.execute("SELECT last_insert_rowid()").fetchone()[0]
        conn.close()
        flash(f"Script « {title} » importé avec succès ({len(cues)} cues).", "success")
        return redirect(url_for("prompter.prompter_edit", sid=new_id))
    except Exception as e:
        flash(f"Erreur d'import : {e}", "error")
        return redirect(url_for("prompter.prompter_list"))
