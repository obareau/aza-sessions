"""Tests Phase 1 — catalogue : favoris, types dédiés, saisie rapide multi-lignes."""
import os

from core.db import get_db
from catalogue.engine import CatalogueEngine, ITEM_TYPES

_DB = os.environ["DB_PATH"]


def test_favorite_column_exists():
    """La colonne favorite doit exister sur catalogue après init_db()."""
    conn = get_db(_DB)
    cols = {r[1] for r in conn.execute("PRAGMA table_info(catalogue)").fetchall()}
    conn.close()
    assert "favorite" in cols


def test_dedicated_types_present():
    """Les types dédiés ipad et zynthian doivent être déclarés."""
    assert "ipad" in ITEM_TYPES
    assert "zynthian" in ITEM_TYPES


def test_toggle_favorite():
    """toggle_favorite bascule le flag favorite."""
    eng = CatalogueEngine(_DB)
    eng.add("machine", "TestFavMachine", "TestMfr")
    conn = get_db(_DB)
    item_id = conn.execute(
        "SELECT id FROM catalogue WHERE name='TestFavMachine'"
    ).fetchone()["id"]
    conn.close()

    eng.toggle_favorite(item_id)
    conn = get_db(_DB)
    fav = conn.execute("SELECT favorite FROM catalogue WHERE id=?", (item_id,)).fetchone()["favorite"]
    conn.close()
    assert fav == 1

    eng.toggle_favorite(item_id)
    conn = get_db(_DB)
    fav = conn.execute("SELECT favorite FROM catalogue WHERE id=?", (item_id,)).fetchone()["favorite"]
    conn.close()
    assert fav == 0


def test_add_bulk_inserts_and_dedups():
    """add_bulk insère les nouvelles lignes, ignore les vides et les doublons."""
    eng = CatalogueEngine(_DB)
    rows = [
        {"name": "BulkA", "manufacturer": "Korg", "notes": "n1"},
        {"name": "BulkB", "manufacturer": "Moog", "notes": ""},
        {"name": "", "manufacturer": "Vide", "notes": "ignore"},     # ligne vide
        {"name": "BulkA", "manufacturer": "Korg", "notes": ""},        # doublon dans le lot
    ]
    added, skipped = eng.add_bulk("ipad", rows)
    assert added == 2
    assert skipped == 1

    # Re-soumettre BulkA → doublon existant en DB
    added2, skipped2 = eng.add_bulk("ipad", [{"name": "BulkA", "manufacturer": "Korg"}])
    assert added2 == 0
    assert skipped2 == 1


def test_bulk_route_post(client):
    """POST /catalogue action=bulk crée plusieurs items et redirige."""
    resp = client.post("/catalogue", data={
        "action": "bulk",
        "type": "zynthian",
        "bulk_manufacturer": ["", ""],
        "bulk_name": ["ZynRouteA", "ZynRouteB"],
        "bulk_notes": ["", ""],
    }, follow_redirects=False)
    assert resp.status_code == 302

    conn = get_db(_DB)
    cnt = conn.execute(
        "SELECT COUNT(*) FROM catalogue WHERE type='zynthian' AND name IN ('ZynRouteA','ZynRouteB')"
    ).fetchone()[0]
    conn.close()
    assert cnt == 2


def test_favorite_route_post(client):
    """POST /catalogue action=favorite bascule le favori."""
    eng = CatalogueEngine(_DB)
    eng.add("effet", "FavRouteItem")
    conn = get_db(_DB)
    item_id = conn.execute("SELECT id FROM catalogue WHERE name='FavRouteItem'").fetchone()["id"]
    conn.close()

    client.post("/catalogue", data={"action": "favorite", "id": item_id})
    conn = get_db(_DB)
    fav = conn.execute("SELECT favorite FROM catalogue WHERE id=?", (item_id,)).fetchone()["favorite"]
    conn.close()
    assert fav == 1


# ── Fiches détaillées (vue table) ────────────────────────────────────────────

def test_fiche_columns_exist():
    """purpose et intent doivent exister sur catalogue après init_db()."""
    conn = get_db(_DB)
    cols = {r[1] for r in conn.execute("PRAGMA table_info(catalogue)").fetchall()}
    conn.close()
    assert "purpose" in cols
    assert "intent" in cols


def test_update_fiches_writes_only_changed_rows():
    """update_fiches renseigne les trois champs et ignore les lignes inchangées."""
    eng = CatalogueEngine(_DB)
    eng.add("machine", "FicheMachine")
    eng.add("plugin", "FicheInchangee")
    conn = get_db(_DB)
    ids = {r["name"]: r["id"] for r in conn.execute(
        "SELECT id, name FROM catalogue WHERE name IN ('FicheMachine','FicheInchangee')"
    ).fetchall()}
    conn.close()

    touched = eng.update_fiches([
        {"id": ids["FicheMachine"], "manufacturer": "Arturia",
         "purpose": "  Synthé numérique wavetable  ", "intent": "Nappes de fond"},
        {"id": ids["FicheInchangee"], "manufacturer": "", "purpose": "", "intent": ""},
    ])
    assert touched == 1

    conn = get_db(_DB)
    row = conn.execute(
        "SELECT manufacturer, purpose, intent FROM catalogue WHERE id=?",
        (ids["FicheMachine"],)
    ).fetchone()
    conn.close()
    assert row["manufacturer"] == "Arturia"
    assert row["purpose"] == "Synthé numérique wavetable"   # espaces retirés
    assert row["intent"] == "Nappes de fond"

    # Re-soumettre à l'identique ne réécrit rien
    assert eng.update_fiches([
        {"id": ids["FicheMachine"], "manufacturer": "Arturia",
         "purpose": "Synthé numérique wavetable", "intent": "Nappes de fond"},
    ]) == 0


def test_update_fiches_ignores_unknown_ids():
    """Un id inexistant ou illisible ne fait pas échouer l'enregistrement."""
    eng = CatalogueEngine(_DB)
    assert eng.update_fiches([
        {"id": 999999, "manufacturer": "X", "purpose": "Y", "intent": "Z"},
        {"id": "pas-un-entier", "manufacturer": "X", "purpose": "Y", "intent": "Z"},
    ]) == 0


def test_fiches_route_get_and_post(client):
    """GET /catalogue/fiches affiche la table, POST enregistre les lignes."""
    eng = CatalogueEngine(_DB)
    eng.add("effet", "FicheRouteItem")
    conn = get_db(_DB)
    item_id = conn.execute("SELECT id FROM catalogue WHERE name='FicheRouteItem'").fetchone()["id"]
    conn.close()

    resp = client.get("/catalogue/fiches")
    assert resp.status_code == 200
    assert b"FicheRouteItem" in resp.data

    resp = client.post("/catalogue/fiches", data={
        "id": [str(item_id)],
        "manufacturer": ["Strymon"],
        "purpose": ["Reverb modulee"],
        "intent": ["Fin de chaine sur les nappes"],
    }, follow_redirects=False)
    assert resp.status_code == 302

    conn = get_db(_DB)
    row = conn.execute(
        "SELECT manufacturer, purpose, intent FROM catalogue WHERE id=?", (item_id,)
    ).fetchone()
    conn.close()
    assert row["manufacturer"] == "Strymon"
    assert row["purpose"] == "Reverb modulee"
    assert row["intent"] == "Fin de chaine sur les nappes"


def test_fiche_shown_on_gear_notebook(client):
    """Les deux champs se relisent depuis le carnet de la fiche."""
    eng = CatalogueEngine(_DB)
    eng.add("machine", "FicheCarnetItem")
    conn = get_db(_DB)
    item_id = conn.execute("SELECT id FROM catalogue WHERE name='FicheCarnetItem'").fetchone()["id"]
    conn.close()
    eng.update_fiches([{"id": item_id, "manufacturer": "Elektron",
                        "purpose": "Boite a rythmes analogique",
                        "intent": "Ossature rythmique des sessions live"}])

    resp = client.get(f"/catalogue/{item_id}")
    assert resp.status_code == 200
    assert "Boite a rythmes analogique".encode() in resp.data
    assert "Ossature rythmique des sessions live".encode() in resp.data


def test_fiches_print_route(client):
    """GET /catalogue/fiches/print rend la version papier."""
    eng = CatalogueEngine(_DB)
    eng.add("machine", "FichePrintItem")
    conn = get_db(_DB)
    item_id = conn.execute("SELECT id FROM catalogue WHERE name='FichePrintItem'").fetchone()["id"]
    conn.close()
    eng.update_fiches([{"id": item_id, "manufacturer": "Moog",
                        "purpose": "Basse analogique", "intent": "Fondations"}])

    resp = client.get("/catalogue/fiches/print")
    assert resp.status_code == 200
    body = resp.data.decode()
    assert "FichePrintItem" in body
    assert "Basse analogique" in body
    assert "landscape" in body          # A4 paysage


def test_fiches_print_honours_filters(client):
    """Les filtres de l'écran (type, todo, q) s'appliquent au papier."""
    eng = CatalogueEngine(_DB)
    eng.add("effet", "FichePrintFiltre")   # laissée vide → « à compléter »
    conn = get_db(_DB)
    item_id = conn.execute("SELECT id FROM catalogue WHERE name='FichePrintFiltre'").fetchone()["id"]
    conn.close()

    # Filtre par type : une fiche machine ne doit pas sortir sur un tirage 'effet'
    body = client.get("/catalogue/fiches/print?type=effet").data.decode()
    assert "FichePrintFiltre" in body
    assert "FichePrintItem" not in body

    # Filtre « à compléter » : la fiche renseignée disparaît, la vide reste
    body = client.get("/catalogue/fiches/print?todo=1").data.decode()
    assert "FichePrintFiltre" in body
    assert "FichePrintItem" not in body

    # Recherche libre
    body = client.get("/catalogue/fiches/print?q=fichceprintintrouvable").data.decode()
    assert "Aucune fiche ne correspond" in body

    # Une fois renseignée, elle sort du tirage « à compléter »
    eng.update_fiches([{"id": item_id, "manufacturer": "Boss",
                        "purpose": "Delay", "intent": "Nappes"}])
    body = client.get("/catalogue/fiches/print?todo=1").data.decode()
    assert "FichePrintFiltre" not in body
