"""Proposition de codes catalogue.

Les codes alimentent le nom de prise R8 : sans eux la fonctionnalité est inerte,
et personne n'en saisit quarante à la main. Ce qui se teste ici : que la
proposition soit unique, parlante, et surtout qu'elle ne touche **jamais** un
code déjà posé — il est peut-être déjà inscrit sur des prises enregistrées.
"""
import os

from catalogue.engine import CatalogueEngine
from core.db import get_db

_DB = os.environ["DB_PATH"]


def _gear(nom, typ="machine", code=""):
    conn = get_db(_DB)
    cur = conn.execute(
        "INSERT INTO catalogue (type, name, active, code) VALUES (?, ?, 1, ?)",
        (typ, nom, code))
    conn.commit()
    gid = cur.lastrowid
    conn.close()
    return gid


def _propose(gid):
    return CatalogueEngine(_DB).propose_codes().get(gid)


def test_majuscules_internes():
    """« MicroFreak » vaut deux mots : MF, pas MI."""
    assert _propose(_gear("CodeTestMicroFreak")) == "CT"
    assert CatalogueEngine._candidats("MicroFreak")[0] == "MF"


def test_deux_mots():
    assert CatalogueEngine._candidats("Volca Drum")[0] == "VD"


def test_chiffre_discriminant():
    assert "N1" in CatalogueEngine._candidats("NTS-1")


def test_accents_et_ponctuation_retires():
    assert CatalogueEngine._candidats("Éclat Sonore")[0] == "ES"
    assert all(c.isalnum() for cand in CatalogueEngine._candidats("iPad/iPhone") for c in cand)


def test_toujours_deux_caracteres():
    for nom in ("A", "Peach", "X-1", "Un Deux Trois Quatre"):
        for cand in CatalogueEngine._candidats(nom):
            assert len(cand) == 2, (nom, cand)


def test_code_existant_intouchable():
    gid = _gear("Code Deja Pose", code="ZZ")
    assert gid not in CatalogueEngine(_DB).propose_codes()


def test_pas_de_collision_avec_un_code_existant():
    _gear("Collision Alpha", code="CB")       # occupe CB
    autre = _gear("Collision Beta")           # voudrait CB
    assert _propose(autre) != "CB"


def test_propositions_uniques_entre_elles():
    props = CatalogueEngine(_DB).propose_codes()
    assert len(set(props.values())) == len(props)


def test_machine_prioritaire_sur_son_alias_effet():
    """Sans priorité, « Zoom R8 (effets) » raflait le code de la machine."""
    machine = _gear("Prio Truc", "machine")
    alias = _gear("Prio Truc (effets)", "effet")
    props = CatalogueEngine(_DB).propose_codes()
    assert props[machine] == "PT"
    assert props[alias] != props[machine]


def test_route_n_ecrit_rien(client):
    gid = _gear("Route Sans Ecriture")
    assert client.get("/api/codes-proposes").get_json()["codes"][str(gid)]
    conn = get_db(_DB)
    code = conn.execute("SELECT code FROM catalogue WHERE id=?", (gid,)).fetchone()["code"]
    conn.close()
    assert (code or "") == "", "la route a écrit en base — elle ne doit que proposer"


def test_bouton_present(client):
    assert "btn-codes" in client.get("/catalogue/fiches").get_data(as_text=True)
