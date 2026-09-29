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
    """« MicroFreak » vaut deux mots : MFR, pas MIC."""
    assert CatalogueEngine._candidats("MicroFreak")[0] == "MFR"


def test_consonne_prise_dans_le_dernier_mot():
    """C'est le dernier mot qui distingue : Volca Drum → VDR, pas VDL."""
    assert CatalogueEngine._candidats("Volca Drum")[0] == "VDR"
    assert CatalogueEngine._candidats("Volca Kick")[0] == "VKC"


def test_chiffre_en_fin_de_code():
    """Un chiffre est très discriminant dans ces noms et se lit mieux à la fin."""
    assert CatalogueEngine._candidats("NTS-1")[0] == "NT1"
    assert CatalogueEngine._candidats("Zoom R8")[0] == "ZR8"


def test_accents_et_ponctuation_retires():
    assert CatalogueEngine._candidats("Éclat Sonore")[0].isalnum()
    assert all(c.isalnum() for cand in CatalogueEngine._candidats("iPad/iPhone") for c in cand)


def test_taille_respectee():
    for taille in (2, 3, 4):
        for nom in ("A", "Peach", "X-1", "Un Deux Trois Quatre", "MicroFreak"):
            for cand in CatalogueEngine._candidats(nom, taille):
                assert len(cand) == taille, (nom, taille, cand)


def test_trois_lettres_par_defaut():
    """Décision du 2026-09-29 : « MFR » se relit, « MF » se devine."""
    assert CatalogueEngine.TAILLE_CODE == 3
    assert len(CatalogueEngine._candidats("MicroFreak")[0]) == 3


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
    assert props[machine] == CatalogueEngine._candidats("Prio Truc")[0]
    assert props[alias] != props[machine]


def test_taille_choisie_de_bout_en_bout(client):
    """La taille demandée doit traverser la route jusqu'aux codes rendus."""
    _gear("Taille Bout En Bout")
    for taille in (2, 3, 4):
        d = client.get(f"/api/codes-proposes?taille={taille}").get_json()
        assert d["taille"] == taille
        assert all(len(c) == taille for c in d["codes"].values())


def test_taille_bornee(client):
    """Hors bornes, on retombe sur du utilisable plutôt que sur une erreur."""
    assert client.get("/api/codes-proposes?taille=9").get_json()["taille"] == 4
    assert client.get("/api/codes-proposes?taille=0").get_json()["taille"] == 2


def test_route_n_ecrit_rien(client):
    gid = _gear("Route Sans Ecriture")
    assert client.get("/api/codes-proposes").get_json()["codes"][str(gid)]
    conn = get_db(_DB)
    code = conn.execute("SELECT code FROM catalogue WHERE id=?", (gid,)).fetchone()["code"]
    conn.close()
    assert (code or "") == "", "la route a écrit en base — elle ne doit que proposer"


def test_bouton_present(client):
    assert "btn-codes" in client.get("/catalogue/fiches").get_data(as_text=True)
