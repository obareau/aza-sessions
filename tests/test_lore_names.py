"""Générateur de titres AZA — le contrat, pas le hasard.

On ne teste pas *quel* titre sort (c'est du hasard, c'est le but) mais qu'il
sort toujours quelque chose d'utilisable : le bon nombre, sans doublon, non
vide, et dans le vocabulaire de l'univers.
"""
from core.lore_names import propose


def test_nombre_demande():
    assert len(propose(5, seed=1)) == 5


def test_sans_doublon_et_non_vide():
    noms = propose(20, seed=2)
    assert len(set(noms)) == len(noms)
    assert all(n.strip() for n in noms)


def test_bornes():
    assert len(propose(0)) == 5          # 0 ou None → le défaut, jamais rien
    assert len(propose(999, seed=3)) <= 20


def test_registre_de_lunivers():
    """Chaque titre doit porter au moins un mot du vocabulaire AZA."""
    from core.lore_names import NOMS, LIEUX, CODES
    vocab = set(NOMS) | set(LIEUX) | set(CODES)
    # Recherche par sous-chaîne : les lieux composés (SECTEUR-NORD) ne
    # survivent pas à un découpage sur le tiret.
    for titre in propose(20, seed=4):
        assert any(mot in titre for mot in vocab), titre


def test_route(client):
    r = client.get("/api/noms-aza?n=3")
    assert r.status_code == 200
    assert len(r.get_json()["noms"]) == 3
