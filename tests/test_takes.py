"""Registre des prises — construit uniquement sur ce qui est saisi à la main.

Aucun fichier, aucun dossier : la version précédente scrutait un dossier de
vidage de carte SD, ce qui supposait un dossier qu'Olivier ne remplit pas. Ce
qui reste à tester, c'est le groupement — et surtout la détection des noms
réutilisés, puisque le compteur du R8 est quotidien.
"""
import os

from core.db import get_db
from takes.engine import TakesEngine

_DB = os.environ["DB_PATH"]


def _seance(titre, prise, date="2026-09-28T20:00"):
    conn = get_db(_DB)
    cur = conn.execute(
        "INSERT INTO sessions (date, title, audio_file) VALUES (?, ?, ?)",
        (date, titre, prise))
    conn.commit()
    sid = cur.lastrowid
    conn.close()
    return sid


def _entree(registre, nom):
    return next((g for g in registre if g["nom"].upper() == nom.upper()), None)


def test_une_prise_une_entree():
    _seance("Simple", "TKREG_1")
    g = _entree(TakesEngine(_DB).registre(), "TKREG_1")
    assert g and [s["title"] for s in g["seances"]] == ["Simple"]
    assert g["doublon"] is False


def test_nom_reutilise_signale():
    """Le compteur est quotidien : le même nom revient d'un jour à l'autre."""
    _seance("Lundi", "TKDUP_1", "2026-09-21T20:00")
    _seance("Mardi", "TKDUP_1", "2026-09-22T20:00")
    g = _entree(TakesEngine(_DB).registre(), "TKDUP_1")
    assert g["doublon"] is True
    assert {s["title"] for s in g["seances"]} == {"Lundi", "Mardi"}


def test_casse_ignoree_pour_le_groupement():
    """« mf_1 » et « MF_1 » désignent la même prise — les séparer masquerait
    justement le doublon qu'on veut voir."""
    _seance("Majuscule", "TKCASE_1", "2026-09-21T20:00")
    _seance("Minuscule", "tkcase_1", "2026-09-22T20:00")
    g = _entree(TakesEngine(_DB).registre(), "TKCASE_1")
    assert g["doublon"] is True and len(g["seances"]) == 2


def test_espaces_ignores():
    _seance("Espacée", "  TKSP_1  ")
    assert _entree(TakesEngine(_DB).registre(), "TKSP_1") is not None


def test_seance_sans_prise_hors_registre():
    sid = _seance("Muette", "")
    reg = TakesEngine(_DB).registre()
    assert all(sid not in [s["id"] for s in g["seances"]] for g in reg)
    assert sid in [s["id"] for s in TakesEngine(_DB).sans_prise()]


def test_plus_recent_dabord():
    _seance("Vieille", "TKORD_1", "2020-01-01T10:00")
    _seance("Neuve", "TKORD_2", "2099-01-01T10:00")
    noms = [g["nom"] for g in TakesEngine(_DB).registre()]
    assert noms.index("TKORD_2") < noms.index("TKORD_1")


def test_page(client):
    _seance("Affichée", "TKPAGE_1")
    h = client.get("/prises").get_data(as_text=True)
    assert "TKPAGE_1" in h and "Affichée" in h


def test_page_ne_lit_aucun_fichier(client):
    """Garde-fou : plus aucune route ne sert de fichier depuis le disque."""
    assert client.get("/prises/ecouter?f=x.wav").status_code == 404
