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


@bp.route("/catalogue/fiches", methods=["GET", "POST"])
def fiches():
    """Vue table — fabricant, à quoi ça sert, comment je compte m'en servir.

    La table entière se soumet en un POST : on remplit plusieurs lignes d'affilée,
    et un enregistrement par ligne obligerait à recharger la page à chaque champ.
    Le moteur ne réécrit que ce qui a changé.
    """
    engine = _engine()
    if request.method == "POST":
        ids           = request.form.getlist("id")
        manufacturers = request.form.getlist("manufacturer")
        purposes      = request.form.getlist("purpose")
        intents       = request.form.getlist("intent")
        rows = [
            {
                "id":           item_id,
                "manufacturer": manufacturers[i] if i < len(manufacturers) else "",
                "purpose":      purposes[i] if i < len(purposes) else "",
                "intent":       intents[i] if i < len(intents) else "",
            }
            for i, item_id in enumerate(ids)
        ]
        touched = engine.update_fiches(rows)
        if touched:
            flash(f"{touched} fiche{'s' if touched > 1 else ''} enregistrée{'s' if touched > 1 else ''}.", "success")
        else:
            flash("Aucune modification à enregistrer.", "success")
        return redirect(url_for("catalogue.fiches"))

    db_path = current_app.config["DB_PATH"]
    rows = engine.fiches()
    return render_template("catalogue_fiches.html",
                           rows=rows,
                           item_types=ITEM_TYPES,
                           incomplete=sum(1 for r in rows if not (r["purpose"] or "").strip()
                                          or not (r["intent"] or "").strip()),
                           version=current_app.config.get("VERSION", ""),
                           oblique=rand_oblique(db_path))


@bp.route("/catalogue/fiches/print")
def fiches_print():
    """Version papier de la vue table — A4 paysage, groupée par type.

    Reprend les filtres de l'écran (`q`, `type`, `todo`) : imprimer, c'est
    presque toujours imprimer *ce qu'on regarde*, et souvent justement les
    fiches à compléter — les cases vides sortent réglées pour être remplies
    au stylo pendant une session.
    """
    q    = (request.args.get("q") or "").strip().lower()
    typ  = (request.args.get("type") or "").strip()
    todo = request.args.get("todo") == "1"

    rows = []
    for r in _engine().fiches():
        if typ and r["type"] != typ:
            continue
        if todo and (r["purpose"] or "").strip() and (r["intent"] or "").strip():
            continue
        if q:
            hay = " ".join(str(r[f] or "") for f in
                           ("name", "manufacturer", "purpose", "intent")).lower()
            if q not in hay:
                continue
        rows.append(r)

    grouped = {}
    for r in rows:
        grouped.setdefault(r["type"], []).append(r)

    filters = []
    if typ:
        filters.append(ITEM_TYPES.get(typ, typ))
    if todo:
        filters.append("à compléter")
    if q:
        filters.append(f'« {q} »')

    return render_template("catalogue_fiches_print.html",
                           grouped=grouped,
                           total=len(rows),
                           filters=" · ".join(filters),
                           item_types=ITEM_TYPES,
                           today=date.today().isoformat(),
                           version=current_app.config.get("VERSION", ""))


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
                           sessions=nb.sessions(gear_id),
                           candidates=nb.candidates(gear_id),
                           today=date.today().isoformat(),
                           version=current_app.config.get("VERSION", ""),
                           oblique=rand_oblique(db_path))
