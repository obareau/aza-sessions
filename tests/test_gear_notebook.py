"""Tests du carnet d'instrument — patches, associations, remarques."""
import os

import pytest

from core.db import get_db
from catalogue.engine import CatalogueEngine, GearNotebookEngine

_DB = os.environ["DB_PATH"]


@pytest.fixture()
def gear():
    """Deux fiches catalogue distinctes, propres à chaque test."""
    eng = CatalogueEngine(_DB)
    conn = get_db(_DB)
    ids = []
    for name in ("NBTestSynth", "NBTestReverb"):
        row = conn.execute("SELECT id FROM catalogue WHERE name=?", (name,)).fetchone()
        if row is None:
            eng.add("machine" if "Synth" in name else "effet", name)
            row = conn.execute("SELECT id FROM catalogue WHERE name=?", (name,)).fetchone()
        ids.append(row["id"])
    conn.close()
    yield ids
    conn = get_db(_DB)
    for gid in ids:
        conn.execute("DELETE FROM gear_pairings WHERE gear_id=? OR partner_id=?", (gid, gid))
        conn.execute("DELETE FROM gear_notes WHERE gear_id=?", (gid,))
    conn.commit()
    conn.close()


def test_tables_exist():
    """gear_pairings et gear_notes doivent exister après init_db()."""
    conn = get_db(_DB)
    tables = {r[0] for r in conn.execute(
        "SELECT name FROM sqlite_master WHERE type='table'").fetchall()}
    conn.close()
    assert {"gear_pairings", "gear_notes"} <= tables


def test_pairing_reads_from_both_sides(gear):
    """Le point central : une association notée d'un côté se lit de l'autre.

    Sans ça, la moitié de ce qu'on sait resterait invisible selon la fiche
    par laquelle on arrive.
    """
    a, b = gear
    nb = GearNotebookEngine(_DB)
    assert nb.add_pairing(a, b, "tient les nappes") is True
    assert [p["partner_id"] for p in nb.pairings(a)] == [b]
    assert [p["partner_id"] for p in nb.pairings(b)] == [a]
    assert nb.pairings(b)[0]["note"] == "tient les nappes"


def test_pairing_duplicate_refused_both_directions(gear):
    """Un doublon est refusé même saisi dans l'autre sens."""
    a, b = gear
    nb = GearNotebookEngine(_DB)
    assert nb.add_pairing(a, b) is True
    assert nb.add_pairing(a, b) is False
    assert nb.add_pairing(b, a) is False


def test_pairing_self_refused(gear):
    """Une fiche ne s'associe pas à elle-même."""
    a, _ = gear
    assert GearNotebookEngine(_DB).add_pairing(a, a) is False


def test_notes_stack_newest_first(gear):
    """Les remarques s'empilent au lieu de s'écraser, plus récente d'abord."""
    a, _ = gear
    nb = GearNotebookEngine(_DB)
    nb.add_note(a, "première", date="2026-01-01")
    nb.add_note(a, "seconde", date="2026-06-01")
    notes = nb.notes(a)
    assert len(notes) == 2
    assert notes[0]["note"] == "seconde"


def test_empty_note_refused(gear):
    """Une remarque vide ou blanche n'est pas enregistrée."""
    a, _ = gear
    nb = GearNotebookEngine(_DB)
    assert nb.add_note(a, "   ") is False
    assert nb.notes(a) == []


def test_presets_sorted_by_rating(gear):
    """Les patches viennent de preset_notes, les mieux notés d'abord."""
    a, _ = gear
    conn = get_db(_DB)
    conn.execute("INSERT INTO preset_notes (date, catalogue_id, preset_name, rating)"
                 " VALUES ('2026-01-01', ?, 'FAIBLE', 2)", (a,))
    conn.execute("INSERT INTO preset_notes (date, catalogue_id, preset_name, rating)"
                 " VALUES ('2026-01-01', ?, 'FORT', 5)", (a,))
    conn.commit()
    conn.close()
    names = [p["preset_name"] for p in GearNotebookEngine(_DB).presets(a)]
    assert names[:2] == ["FORT", "FAIBLE"]


def test_candidates_exclude_self(gear):
    """La liste des fiches associables ne se propose pas elle-même."""
    a, _ = gear
    assert a not in [c["id"] for c in GearNotebookEngine(_DB).candidates(a)]


def test_route_renders(client, gear):
    """La page du carnet répond 200 et porte ses trois sections."""
    a, _ = gear
    r = client.get(f"/catalogue/{a}")
    assert r.status_code == 200
    html = r.get_data(as_text=True)
    assert "NBTestSynth" in html
    for section in ("Patches favoris", "Marche bien avec", "Remarques"):
        assert section in html


def test_route_unknown_gear_redirects(client):
    """Une fiche inexistante redirige vers le catalogue, pas une 500."""
    r = client.get("/catalogue/999999")
    assert r.status_code == 302
    assert "/catalogue" in r.headers["Location"]


def test_sessions_lists_where_the_gear_played(gear):
    """La fiche retrouve les sessions qui la mentionnent — sans saisie."""
    a, _ = gear
    nb = GearNotebookEngine(_DB)
    conn = get_db(_DB)
    cur = conn.execute(
        "INSERT INTO sessions (date, title, machines) VALUES ('2026-08-01', 'Avec', ?)",
        ("NBTestSynth, Autre Chose",))
    sid = cur.lastrowid
    conn.execute("INSERT INTO sessions (date, title, machines) VALUES ('2026-08-02', 'Sans', 'Rien')")
    conn.commit()
    conn.close()

    titles = [s["title"] for s in nb.sessions(a)]
    assert "Avec" in titles
    assert "Sans" not in titles

    conn = get_db(_DB)
    conn.execute("DELETE FROM sessions WHERE title IN ('Avec','Sans')")
    conn.commit()
    conn.close()
    assert sid


def test_sessions_does_not_match_a_substring(gear):
    """« NBTestSynth » ne doit pas remonter sur « NBTestSynthesizer ».

    Un LIKE seul confondrait les deux — et sur ce catalogue réel, « Volca »
    ramènerait Volca Drum et Volca Kick indifféremment.
    """
    a, _ = gear
    conn = get_db(_DB)
    conn.execute("INSERT INTO sessions (date, title, machines)"
                 " VALUES ('2026-08-03', 'Piège', 'NBTestSynthesizer')")
    conn.commit()
    conn.close()

    assert "Piège" not in [s["title"] for s in GearNotebookEngine(_DB).sessions(a)]

    conn = get_db(_DB)
    conn.execute("DELETE FROM sessions WHERE title='Piège'")
    conn.commit()
    conn.close()


def test_sessions_scans_every_gear_column(gear):
    """Une fiche citée en effet, pas en machine, est trouvée quand même."""
    _, b = gear          # NBTestReverb, type effet
    conn = get_db(_DB)
    conn.execute("INSERT INTO sessions (date, title, effects)"
                 " VALUES ('2026-08-04', 'EnEffet', 'NBTestReverb')")
    conn.commit()
    conn.close()

    assert "EnEffet" in [s["title"] for s in GearNotebookEngine(_DB).sessions(b)]

    conn = get_db(_DB)
    conn.execute("DELETE FROM sessions WHERE title='EnEffet'")
    conn.commit()
    conn.close()
