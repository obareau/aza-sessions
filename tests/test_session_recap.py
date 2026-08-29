"""Tests du récap à la demande sur une session existante."""
import os

import pytest

from core.db import get_db
from sessions.engine import SessionsEngine

_DB = os.environ["DB_PATH"]


@pytest.fixture()
def sid():
    """Une session jetable."""
    conn = get_db(_DB)
    cur = conn.execute(
        "INSERT INTO sessions (date, title, session_type, machines, comments)"
        " VALUES ('2026-08-29T21:00', 'RecapTest', 'music', 'MicroFreak', 'nappe tenue')")
    conn.commit()
    new_id = cur.lastrowid
    conn.close()
    yield new_id
    conn = get_db(_DB)
    conn.execute("DELETE FROM sessions WHERE id=?", (new_id,))
    conn.commit()
    conn.close()


def test_set_recap_touches_only_that_column(sid):
    """set_recap n'écrit que recap_claude — le reste de la session est intact."""
    eng = SessionsEngine(_DB)
    eng.set_recap(sid, "texte du récap")
    row = eng.get_plain(sid)
    assert row["recap_claude"] == "texte du récap"
    assert row["title"] == "RecapTest"
    assert row["machines"] == "MicroFreak"
    assert row["comments"] == "nappe tenue"


def test_route_generates_and_persists(client, sid, monkeypatch):
    """La route écrit le récap en base et le renvoie."""
    monkeypatch.setattr("sessions.api.generate_recap", lambda d: "RECAP GÉNÉRÉ")
    r = client.post(f"/session/{sid}/recap")
    assert r.status_code == 200
    assert r.get_json()["recap"] == "RECAP GÉNÉRÉ"
    assert SessionsEngine(_DB).get_plain(sid)["recap_claude"] == "RECAP GÉNÉRÉ"


def test_route_reports_silent_ollama_failure(client, sid, monkeypatch):
    """Ollama muet doit remonter une ERREUR, pas un succès vide.

    C'est le cœur du sujet : un appel LLM qui échoue en silence ne se voit
    jamais depuis l'interface — c'est ce qui avait laissé le récap mort
    pendant des semaines (ROADMAP, corrigé le 2026-07-31).
    """
    monkeypatch.setattr("sessions.api.generate_recap", lambda d: None)
    r = client.post(f"/session/{sid}/recap")
    assert r.status_code == 502
    assert "error" in r.get_json()
    assert SessionsEngine(_DB).get_plain(sid)["recap_claude"] in (None, "")


def test_route_unknown_session(client, monkeypatch):
    """Session inexistante : 404 propre, sans appeler Ollama."""
    called = []
    monkeypatch.setattr("sessions.api.generate_recap",
                        lambda d: called.append(1) or "x")
    r = client.post("/session/999999/recap")
    assert r.status_code == 404
    assert called == []


def test_regenerate_overwrites(client, sid, monkeypatch):
    """Régénérer remplace le récap précédent."""
    SessionsEngine(_DB).set_recap(sid, "ancien")
    monkeypatch.setattr("sessions.api.generate_recap", lambda d: "nouveau")
    client.post(f"/session/{sid}/recap")
    assert SessionsEngine(_DB).get_plain(sid)["recap_claude"] == "nouveau"
