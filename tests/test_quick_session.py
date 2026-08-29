"""Tests de la saisie minimale — /vite."""
import os

from core.db import get_db
from sessions.engine import SessionsEngine

_DB = os.environ["DB_PATH"]


def _cleanup(sid):
    conn = get_db(_DB)
    conn.execute("DELETE FROM sessions WHERE id=?", (sid,))
    conn.commit()
    conn.close()


def test_page_loads(client):
    """La page s'ouvre et ne demande qu'une chose."""
    r = client.get("/vite")
    assert r.status_code == 200
    html = r.get_data(as_text=True)
    assert "Ce qui s'est passé" in html
    # tout le reste est explicitement facultatif
    assert html.count("facultatif") >= 2


def test_text_alone_creates_a_session(client):
    """Un texte seul suffit : ni titre, ni machine, ni date à saisir."""
    r = client.post("/vite", data={"comments": "nappe tenue, filtre lent"},
                    follow_redirects=False)
    assert r.status_code == 302
    sid = int(r.headers["Location"].rstrip("/").split("/")[-1])
    row = SessionsEngine(_DB).get_plain(sid)
    assert row["comments"] == "nappe tenue, filtre lent"
    assert row["date"]                      # date automatique
    assert row["session_type"] == "music"   # défaut
    _cleanup(sid)


def test_creation_is_instant_no_recap(client, monkeypatch):
    """La création ne génère AUCUN récap.

    Attendre ~5 s au moment de valider annulerait l'intérêt d'une saisie
    minimale : la fenêtre pour noter quelque chose est courte. Le récap se
    demande ensuite, depuis la session.
    """
    called = []
    monkeypatch.setattr("sessions.api.generate_recap", lambda d: called.append(1) or "x")
    r = client.post("/vite", data={"comments": "texte"})
    sid = int(r.headers["Location"].rstrip("/").split("/")[-1])
    assert called == []
    assert not SessionsEngine(_DB).get_plain(sid)["recap_claude"]
    _cleanup(sid)


def test_empty_text_creates_nothing(client):
    """Un texte vide ou blanc ne crée pas de session fantôme."""
    conn = get_db(_DB)
    n0 = conn.execute("SELECT COUNT(*) FROM sessions").fetchone()[0]
    conn.close()
    r = client.post("/vite", data={"comments": "   "}, follow_redirects=True)
    assert r.status_code == 200
    conn = get_db(_DB)
    n1 = conn.execute("SELECT COUNT(*) FROM sessions").fetchone()[0]
    conn.close()
    assert n1 == n0


def test_optional_fields_are_kept(client):
    """Titre et machines, s'ils sont donnés, sont enregistrés."""
    r = client.post("/vite", data={"comments": "t", "title": "Brume",
                                   "machines": "MicroFreak"})
    sid = int(r.headers["Location"].rstrip("/").split("/")[-1])
    row = SessionsEngine(_DB).get_plain(sid)
    assert row["title"] == "Brume"
    assert row["machines"] == "MicroFreak"
    _cleanup(sid)


def test_create_returns_id():
    """create() renvoie l'id, sans quoi on ne saurait pas où rediriger."""
    eng = SessionsEngine(_DB)
    sid = eng.create({"comments": "x"})
    assert isinstance(sid, int) and sid > 0
    _cleanup(sid)
