from datetime import date
from flask import Blueprint, render_template, request, redirect, url_for, current_app, jsonify, flash
from core.oblique import rand_oblique
from .engine import CatalogueEngine, GearNotebookEngine, ITEM_TYPES

bp = Blueprint("catalogue", __name__)


def _engine():
    return CatalogueEngine(current_app.config["DB_PATH"])


def _notebook():
    return GearNotebookEngine(current_app.config["DB_PATH"])


@bp.route("/catalogue", methods=["GET", "POST"])
def manage_catalogue():
    engine = _engine()
    if request.method == "POST":
        action       = request.form.get("action")
        name         = request.form.get("name", "").strip()
        manufacturer = request.form.get("manufacturer", "").strip()
        notes        = request.form.get("notes", "").strip()
        item_id      = request.form.get("id")
        if action == "add":
            typ = request.form.get("type", "").strip().lower().replace(" ","_")
            if typ and name:
                engine.add(typ, name, manufacturer, notes)
        elif action == "bulk":
            typ = request.form.get("type", "").strip().lower().replace(" ","_")
            names         = request.form.getlist("bulk_name")
            manufacturers = request.form.getlist("bulk_manufacturer")
            bulk_notes    = request.form.getlist("bulk_notes")
            if typ and names:
                rows = []
                for i, nm in enumerate(names):
                    rows.append({
                        "name":         nm,
                        "manufacturer": manufacturers[i] if i < len(manufacturers) else "",
                        "notes":        bulk_notes[i] if i < len(bulk_notes) else "",
                    })
                added, skipped = engine.add_bulk(typ, rows)
                msg = f"{added} élément{'s' if added != 1 else ''} ajouté{'s' if added != 1 else ''}"
                if skipped:
                    msg += f", {skipped} doublon{'s' if skipped != 1 else ''} ignoré{'s' if skipped != 1 else ''}"
                flash(msg, "success")
        elif action == "delete":
            engine.delete(item_id)
        elif action == "edit":
            engine.edit(item_id, name, manufacturer, notes)
        elif action == "toggle":
            engine.toggle(item_id)
        elif action == "favorite":
            engine.toggle_favorite(item_id)
        return redirect(url_for("catalogue.manage_catalogue"))

    db_path = current_app.config["DB_PATH"]
    all_types = engine.get_all_types()
    return render_template("catalogue.html",
                           grouped=engine.list_grouped(),
                           item_types=ITEM_TYPES,
                           all_types=all_types,
                           version=current_app.config.get("VERSION", ""),
                           oblique=rand_oblique(db_path))


@bp.route("/api/catalogue/add", methods=["POST"])
def api_catalogue_add():
    """Ajout rapide inline depuis formulaire session (AJAX)."""
    data         = request.get_json(silent=True) or {}
    typ          = data.get("type", "").strip()
    name         = data.get("name", "").strip()
    manufacturer = data.get("manufacturer", "").strip()
    if not typ or not name:
        return jsonify({"error": "type et nom requis"}), 400
    row = _engine().add_inline(typ, name, manufacturer)
    if row is None:
        return jsonify({"error": "existe déjà"}), 409
    return jsonify({
        "id":           row["id"],
        "name":         row["name"],
        "type":         row["type"],
        "manufacturer": row.get("manufacturer") or "",
    })


@bp.route("/catalogue/<int:gear_id>", methods=["GET", "POST"])
def gear_notebook(gear_id):
    """Carnet d'un instrument — patches favoris, associations, remarques."""
    nb = _notebook()
    gear = nb.get(gear_id)
    if gear is None:
        flash("Cette fiche n'existe pas ou plus.", "error")
        return redirect(url_for("catalogue.manage_catalogue"))

    if request.method == "POST":
        action = request.form.get("action")
        if action == "add_pairing":
            partner_id = request.form.get("partner_id")
            if partner_id:
                ok = nb.add_pairing(gear_id, partner_id, request.form.get("pairing_note", ""))
                if not ok:
                    flash("Association déjà notée, ou fiche associée à elle-même.", "error")
        elif action == "delete_pairing":
            nb.delete_pairing(request.form.get("pairing_id"))
        elif action == "add_note":
            if not nb.add_note(gear_id, request.form.get("note", ""),
                               request.form.get("date") or None):
                flash("Remarque vide — rien enregistré.", "error")
        elif action == "delete_note":
            nb.delete_note(request.form.get("note_id"))
        return redirect(url_for("catalogue.gear_notebook", gear_id=gear_id))

    db_path = current_app.config["DB_PATH"]
    return render_template("catalogue_detail.html",
                           gear=gear,
                           presets=nb.presets(gear_id),
                           pairings=nb.pairings(gear_id),
                           notes=nb.notes(gear_id),
                           candidates=nb.candidates(gear_id),
                           today=date.today().isoformat(),
                           version=current_app.config.get("VERSION", ""),
                           oblique=rand_oblique(db_path))
