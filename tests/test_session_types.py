"""Tests Phase 2 — sessions typées (music / lore / veille) + colonnes iPad/Zynthian."""
import os

from core.db import get_db
from core.constants import SESSION_TYPES

_DB = os.environ["DB_PATH"]


def test_session_columns_exist():
    conn = get_db(_DB)
    cols = {r[1] for r in conn.execute("PRAGMA table_info(sessions)").fetchall()}
    conn.close()
    assert "session_type" in cols
    assert "ipad" in cols
    assert "zynthian" in cols


def test_session_types_constant():
    assert set(SESSION_TYPES) == {"music", "lore", "veille"}


def test_create_lore_and_veille(client):
    client.post("/new", data={
        "session_type": "lore", "title": "Lore A",
        "date": "2026-06-27 10:00", "comments": "écriture", "lore_link": "Secteur 7",
    })
    client.post("/new", data={
        "session_type": "veille", "title": "Veille A",
        "date": "2026-06-27 11:00", "comments": "codage outil",
    })
    conn = get_db(_DB)
    rows = {r["title"]: r["session_type"]
            for r in conn.execute("SELECT title, session_type FROM sessions").fetchall()}
    conn.close()
    assert rows.get("Lore A") == "lore"
    assert rows.get("Veille A") == "veille"


def test_default_session_type_is_music(client):
    """Sans session_type explicite, défaut = music."""
    client.post("/new", data={"title": "NoType", "date": "2026-06-27 09:00"})
    conn = get_db(_DB)
    st = conn.execute("SELECT session_type FROM sessions WHERE title='NoType'").fetchone()["session_type"]
    conn.close()
    assert st == "music"


def test_ipad_zynthian_roundtrip(client):
    client.post("/new", data={
        "session_type": "music", "title": "GearTest", "date": "2026-06-27 14:00",
        "ipad": ["AudioKit", "Drambo"], "zynthian": ["ZynAddSubFX"],
    })
    conn = get_db(_DB)
    row = conn.execute("SELECT ipad, zynthian FROM sessions WHERE title='GearTest'").fetchone()
    conn.close()
    assert row["ipad"] == "AudioKit, Drambo"
    assert row["zynthian"] == "ZynAddSubFX"


def test_search_filter_by_session_type(client):
    client.post("/new", data={"session_type": "lore", "title": "OnlyLore", "date": "2026-06-27 08:00"})
    client.post("/new", data={"session_type": "music", "title": "OnlyMusic", "date": "2026-06-27 08:30"})
    resp = client.get("/search?session_type=lore")
    body = resp.data.decode()
    assert resp.status_code == 200
    assert "OnlyLore" in body
    assert "OnlyMusic" not in body


def test_csv_export_has_session_type(client):
    resp = client.get("/export/csv")
    assert resp.status_code == 200
    header = resp.data.decode().splitlines()[0]
    assert "session_type" in header
    assert "ipad" in header
    assert "zynthian" in header
