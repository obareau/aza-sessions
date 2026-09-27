"""Évolution temporelle et corrélations — surtout le seuil.

Ce qui compte ici n'est pas la moyenne (une division) mais le refus de la
calculer : sous MIN_POINTS sessions, les blocs doivent rester vides pour que
la page ne les affiche pas du tout.
"""
import pytest

from core.db import get_db
from core.init_db import init_db
from stats.engine import StatsEngine, MIN_POINTS

LIGNES = [
    ("2026-05-04T21:00", 3, 2, 45), ("2026-05-18T14:30", 4, 3, 90),
    ("2026-06-02T20:22", 3, 2, 60), ("2026-06-21T22:10", 5, 3, 120),
    ("2026-07-02T21:21", 4, 3, 75), ("2026-07-19T10:05", 2, 1, 30),
]


def _db(tmp_path, lignes):
    chemin = str(tmp_path / "s.db")
    init_db(chemin)
    conn = get_db(chemin)
    for d, r, e, dur in lignes:
        conn.execute(
            "INSERT INTO sessions (date, rating, energy_level, duration_min)"
            " VALUES (?, ?, ?, ?)", (d, r, e, dur))
    conn.commit()
    conn.close()
    return StatsEngine(chemin).compute()


def test_sous_le_seuil_rien_nest_calcule(tmp_path):
    d = _db(tmp_path, LIGNES[:MIN_POINTS - 1])
    assert d["monthly_rating"] == {}
    assert d["monthly_energy"] == {}
    assert d["duration_rating"] == []
    assert d["energy_by_hour"] == {}


def test_moyennes_par_mois(tmp_path):
    d = _db(tmp_path, LIGNES)
    assert d["monthly_rating"]["2026-05"] == 3.5   # (3 + 4) / 2
    assert d["monthly_energy"]["2026-07"] == 2.0   # (3 + 1) / 2
    assert list(d["monthly_rating"]) == sorted(d["monthly_rating"])


def test_mois_sans_donnee_absent_et_non_zero(tmp_path):
    """Une session non notée ne doit pas tirer la moyenne de son mois vers 0."""
    d = _db(tmp_path, LIGNES + [("2026-08-01T20:00", None, None, 50)])
    assert "2026-08" not in d["monthly_rating"]


def test_nuage_note_duree(tmp_path):
    d = _db(tmp_path, LIGNES)
    assert len(d["duration_rating"]) == len(LIGNES)
    assert {"x": 45, "y": 3} in d["duration_rating"]


def test_duree_manquante_exclue_du_nuage(tmp_path):
    d = _db(tmp_path, LIGNES + [("2026-08-01T20:00", 4, 2, None)])
    assert all(p["x"] for p in d["duration_rating"])


def test_energie_par_heure(tmp_path):
    d = _db(tmp_path, LIGNES)
    assert d["energy_by_hour"]["21h"] == 2.5       # 2 puis 3, même heure
    assert d["energy_by_hour"]["10h"] == 1.0


@pytest.mark.parametrize("date", ["2026-05-04", ""])
def test_date_sans_heure_ignoree(tmp_path, date):
    """Une date tronquée ne doit pas lever, juste ne pas produire de point."""
    d = _db(tmp_path, LIGNES + [(date, 4, 3, 50)])
    assert sum(1 for _ in d["energy_by_hour"]) >= 1


def test_resume_digest(client):
    """Le digest n8n doit porter des valeurs, pas des null silencieux."""
    r = client.get("/api/stats/summary")
    assert r.status_code == 200
    d = r.get_json()
    assert set(("total", "top_machine", "this_month")) <= set(d)
