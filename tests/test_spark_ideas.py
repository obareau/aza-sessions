"""Tests Phase 3 — idées en vrac (type 'Idée') et intégration SPARK."""
import os

from core.db import get_db
from core.constants import INSPI_TYPES
from spark.engine import SparkEngine

_DB = os.environ["DB_PATH"]


def _add_idea(content, source=""):
    conn = get_db(_DB)
    conn.execute(
        "INSERT INTO inspirations (type, content, source) VALUES ('Idée', ?, ?)",
        (content, source),
    )
    conn.commit()
    conn.close()


def test_idee_in_inspi_types():
    assert "Idée" in INSPI_TYPES


def test_focus_can_return_idea():
    _add_idea("drone sur une seule note pendant 10 min")
    eng = SparkEngine(_DB)
    seen_types = set()
    for _ in range(200):
        seen_types.add(eng.focus().get("type"))
    assert "Idée en vrac" in seen_types


def test_focus_dedup_excludes_seen_idea():
    _add_idea("traiter le silence comme un instrument", "note perso")
    eng = SparkEngine(_DB)
    # Récupère une clé d'idée
    idea_key = None
    for _ in range(200):
        f = eng.focus()
        if f.get("type") == "Idée en vrac":
            idea_key = f["_key"]
            break
    assert idea_key is not None
    # Avec cette clé exclue, focus ne doit jamais la re-proposer (pool non épuisé)
    for _ in range(100):
        f = eng.focus(exclude=[idea_key])
        assert f["_key"] != idea_key


def test_suggestions_surfaces_idea():
    _add_idea("enregistrer une session entièrement à l'aveugle")
    eng = SparkEngine(_DB)
    found = False
    for _ in range(50):
        res = eng.suggestions()
        if any(s.get("type") == "Idée en vrac" for s in res["suggestions"]):
            found = True
            break
    assert found


def test_inspirations_page_reframed(client):
    resp = client.get("/inspirations")
    assert resp.status_code == 200
    assert "Idées en vrac" in resp.data.decode()
