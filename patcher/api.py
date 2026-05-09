from flask import Blueprint, render_template, request, redirect, url_for, jsonify, current_app
from .engine import PatcherEngine, NODE_COLORS, SIGNAL_COLORS

bp = Blueprint("patcher", __name__)


def _engine():
    return PatcherEngine(current_app.config["DB_PATH"])


def _version():
    return current_app.config.get("VERSION", "")


@bp.route("/patcher")
def patcher_list():
    engine = _engine()
    return render_template("patcher_list.html",
                           layouts=engine.list_layouts(),
                           sessions=engine.get_sessions(),
                           version=_version(),
                           oblique=engine.rand_oblique())


@bp.route("/patcher/new", methods=["POST"])
def patcher_new():
    engine = _engine()
    name = request.form.get("name", "").strip() or "Nouveau patch"
    session_id = request.form.get("session_id") or None
    import_mode = request.form.get("import_mode", "none")

    layout_id = engine.create_layout(name, session_id)

    if import_mode == "session" and session_id:
        engine.import_from_session(layout_id, int(session_id))
    elif import_mode == "catalogue":
        engine.import_from_catalogue(layout_id)
    elif import_mode == "session_all" and session_id:
        engine.import_from_session(layout_id, int(session_id))

    return redirect(url_for("patcher.patcher_view", layout_id=layout_id))


@bp.route("/patcher/<int:layout_id>")
def patcher_view(layout_id):
    engine = _engine()
    layout, nodes, connections = engine.get_layout(layout_id)
    if not layout:
        return redirect(url_for("patcher.patcher_list"))
    all_types = engine.get_all_catalogue_types()
    return render_template("patcher_view.html",
                           layout=layout,
                           nodes=nodes,
                           connections=connections,
                           node_colors=NODE_COLORS,
                           signal_colors=SIGNAL_COLORS,
                           all_catalogue_types=all_types,
                           catalogue_groups=engine.get_catalogue_items(),
                           version=_version(),
                           oblique=engine.rand_oblique())


@bp.route("/patcher/<int:layout_id>/save", methods=["POST"])
def patcher_save(layout_id):
    engine = _engine()
    data = request.get_json(silent=True) or {}
    engine.save_layout(layout_id, data.get("nodes", []), data.get("connections", []))
    # Renvoie les nœuds/connexions avec leurs vrais IDs DB pour que le client se resynchronise
    layout, nodes, connections = engine.get_layout(layout_id)
    return jsonify({"status": "ok", "nodes": nodes, "connections": connections})


@bp.route("/patcher/<int:layout_id>/rename", methods=["POST"])
def patcher_rename(layout_id):
    engine = _engine()
    name = (request.get_json(silent=True) or {}).get("name", "").strip()
    if name:
        engine.update_layout_name(layout_id, name)
    return jsonify({"status": "ok"})


@bp.route("/patcher/<int:layout_id>/import", methods=["POST"])
def patcher_import(layout_id):
    """Import depuis session ou catalogue (AJAX, post-création)."""
    engine = _engine()
    data = request.get_json(silent=True) or {}
    mode = data.get("mode", "catalogue")
    session_id = data.get("session_id")

    if mode == "session" and session_id:
        added = engine.import_from_session(layout_id, int(session_id))
    else:
        added = engine.import_from_catalogue(layout_id)

    layout, nodes, connections = engine.get_layout(layout_id)
    return jsonify({"status": "ok", "added": added,
                    "nodes": nodes, "connections": connections})


@bp.route("/patcher/<int:layout_id>/export/mermaid")
def patcher_export_mermaid(layout_id):
    """Export du layout en Mermaid Markdown."""
    from flask import Response
    engine = _engine()
    layout, nodes, connections = engine.get_layout(layout_id)
    if not layout:
        return redirect(url_for("patcher.patcher_list"))

    ICONS = {"machine":"⚙","effet":"≈","daw":"▣","synth_ios":"⊞","plugin":"◉","free":"◇"}
    SIG_ARROWS = {"audio":"-->","midi":"-.->","cv":"==>","usb":"--x","autre":"-->"}

    lines = [f"# Patch : {layout['name']}"]
    if layout.get("session_date"):
        lines.append(f"*Session : {layout['session_date']}"
                     + (f" — {layout['session_title']}" if layout.get("session_title") else "") + "*")
    lines += ["", "```mermaid", "graph LR"]

    # Styles par type de nœud
    type_colors = {"machine":"#D4380D","effet":"#8B0000","daw":"#1A3A6B",
                   "synth_ios":"#1D5C2E","plugin":"#4A1A6B","free":"#3A3A3A"}
    seen_types = set()
    for n in nodes:
        icon = ICONS.get(n["node_type"], "◈")
        label_parts = [f"{icon} {n['label']}"]
        if n.get("note"):
            note = n["note"][:30] + ("…" if len(n["note"]) > 30 else "")
            label_parts.append(note)
        label = "\\n".join(label_parts)
        lines.append(f'    n{n["id"]}["{label}"]')
        seen_types.add(n["node_type"])

    lines.append("")
    for c in connections:
        arrow = SIG_ARROWS.get(c["signal_type"], "-->")
        lbl = c.get("label") or c["signal_type"]
        lines.append(f'    n{c["from_id"]} {arrow}|"{lbl}"| n{c["to_id"]}')

    # Styles de couleur par type
    lines.append("")
    for t in seen_types:
        col = type_colors.get(t, "#3A3A3A")
        node_ids = " ".join(f"n{n['id']}" for n in nodes if n["node_type"] == t)
        if node_ids:
            lines.append(f"    style {node_ids.split()[0]} fill:{col}22,stroke:{col},color:{col}")
            # classDef + linkStyle serait plus propre mais mermaid supporte mieux style ligne par ligne
            for nid in node_ids.split()[1:]:
                lines.append(f"    style {nid} fill:{col}22,stroke:{col},color:{col}")

    lines.append("```")
    if nodes:
        lines += ["", "## Nœuds", ""]
        lines += [f"| ID | Nom | Type | Note |", "|----|-----|------|------|"]
        for n in nodes:
            lines.append(f"| n{n['id']} | {n['label']} | {n['node_type']} | {n.get('note','') or ''} |")
    if connections:
        lines += ["", "## Connexions", ""]
        lines += [f"| De | Vers | Signal | Label |", "|----|------|--------|-------|"]
        for c in connections:
            fn = next((n["label"] for n in nodes if n["id"]==c["from_id"]), str(c["from_id"]))
            tn = next((n["label"] for n in nodes if n["id"]==c["to_id"]),   str(c["to_id"]))
            lines.append(f"| {fn} | {tn} | {c['signal_type']} | {c.get('label','') or ''} |")

    md = "\n".join(lines)
    safe_name = layout["name"].lower().replace(" ", "-").replace("/", "-")
    return Response(md, mimetype="text/markdown; charset=utf-8",
                    headers={"Content-Disposition":
                             f'attachment; filename="patch-{layout_id}-{safe_name}.md"'})


@bp.route("/patcher/import/json", methods=["POST"])
def patcher_import_json():
    """Import d'un patch depuis un fichier .json exporté."""
    import json as jsonlib
    f = request.files.get("file")
    if not f:
        return redirect(url_for("patcher.patcher_list"))
    try:
        data = jsonlib.load(f)
    except Exception:
        return redirect(url_for("patcher.patcher_list"))

    engine = _engine()
    name = data.get("name", "Patch importé")
    layout_id = engine.create_layout(name)

    raw_nodes = data.get("nodes", [])
    nodes = [
        {
            "id": f"tmp_import_{i}",
            "label":       n.get("label", "?"),
            "x":           n.get("x", 100 + i * 20),
            "y":           n.get("y", 100),
            "node_type":   n.get("node_type", "free"),
            "color":       n.get("color", "#3A3A3A"),
            "note":        n.get("note", ""),
            "catalogue_id": n.get("catalogue_id"),
        }
        for i, n in enumerate(raw_nodes)
    ]

    connections = []
    for c in data.get("connections", []):
        fi = c.get("from_index", -1)
        ti = c.get("to_index", -1)
        if 0 <= fi < len(nodes) and 0 <= ti < len(nodes):
            connections.append({
                "from_id":    nodes[fi]["id"],
                "to_id":      nodes[ti]["id"],
                "label":      c.get("label", ""),
                "signal_type": c.get("signal_type", "audio"),
                "note":       c.get("note", ""),
            })

    engine.save_layout(layout_id, nodes, connections)
    return redirect(url_for("patcher.patcher_view", layout_id=layout_id))


@bp.route("/patcher/<int:layout_id>/delete", methods=["POST"])
def patcher_delete(layout_id):
    _engine().delete_layout(layout_id)
    return redirect(url_for("patcher.patcher_list"))
