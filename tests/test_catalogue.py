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
