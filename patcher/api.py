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
    return render_template("patcher_view.html",
                           layout=layout,
                           nodes=nodes,
                           connections=connections,
                           node_colors=NODE_COLORS,
                           signal_colors=SIGNAL_COLORS,
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


@bp.route("/patcher/<int:layout_id>/delete", methods=["POST"])
def patcher_delete(layout_id):
    _engine().delete_layout(layout_id)
    return redirect(url_for("patcher.patcher_list"))
