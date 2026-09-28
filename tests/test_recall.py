"""Fiche de rappel — reconstruire la chaîne d'une séance.

Les données existaient déjà, éparpillées dans le formulaire ; ce qui se teste
ici c'est la remise en ordre : l'ordre du signal, et le rattachement des façades
relevées à la bonne séance.
"""
import os

from catalogue.engine import KnobSheetEngine
from core.db import get_db

_DB = os.environ["DB_PATH"]


def _seance(**champs):
    champs.setdefault("date", "2026-09-28T21:00")
    cols = ", ".join(champs)
    conn = get_db(_DB)
    cur = conn.execute(f"INSERT INTO sessions ({cols}) VALUES ({', '.join('?' * len(champs))})",
                       tuple(champs.values()))
    conn.commit()
    sid = cur.lastrowid
    conn.close()
    return sid


def _gear(nom, code=""):
    conn = get_db(_DB)
    cur = conn.execute(
        "INSERT INTO catalogue (type, name, manufacturer, active, code) "
        "VALUES ('machine', ?, 'Behringer', 1, ?)", (nom, code))
    conn.commit()
    gid = cur.lastrowid
    conn.close()
    return gid


def test_ordre_du_signal(client):
    """Instruments d'abord, puis traitements — et jamais un tri alphabétique."""
    sid = _seance(title="Chaîne", machines="Zeta, Alpha", effects="Beta")
    h = client.get(f"/session/{sid}/rappel").get_data(as_text=True)
    assert h.count("rc-step") >= 3
    # L'ordre de saisie est celui de la chaîne : Zeta avant Alpha.
    assert h.index("Zeta") < h.index("Alpha") < h.index("Beta")


def test_prise_r8_en_bout_de_chaine(client):
    sid = _seance(machines="Alpha", audio_file="WPMG_1")
    h = client.get(f"/session/{sid}/rappel").get_data(as_text=True)
    assert "WPMG_1" in h and h.index("Alpha") < h.index("WPMG_1")


def test_seance_sans_materiel(client):
    """Ne doit pas lever — juste dire qu'il n'y a rien à rappeler."""
    sid = _seance(title="Vide")
    r = client.get(f"/session/{sid}/rappel")
    assert r.status_code == 200
    assert "rien à rappeler" in r.get_data(as_text=True)


def test_seance_inconnue(client):
    assert client.get("/session/999999/rappel").status_code == 302


def test_facades_de_la_seance_seulement(client):
    """Un relevé rattaché à une autre séance ne doit pas fuir sur cette fiche."""
    gid = _gear("Rappel Synth", "RS")
    ici = _seance(title="Ici", machines="Rappel Synth")
    ailleurs = _seance(title="Ailleurs", machines="Rappel Synth")
    eng = KnobSheetEngine(_DB)
    eng.set_controls(gid, "Cutoff")
    eng.save(gid, {"Cutoff": "7"}, label="le bon", session_id=ici)
    eng.save(gid, {"Cutoff": "2"}, label="l'autre", session_id=ailleurs)
    h = client.get(f"/session/{ici}/rappel").get_data(as_text=True)
    assert "le bon" in h and "l'autre" not in h


def test_releve_non_rattache_reste_hors_fiche(client):
    gid = _gear("Libre Synth", "LS")
    sid = _seance(title="Sans façade", machines="Libre Synth")
    eng = KnobSheetEngine(_DB)
    eng.set_controls(gid, "Cutoff")
    eng.save(gid, {"Cutoff": "5"}, label="orphelin")       # aucune séance
    h = client.get(f"/session/{sid}/rappel").get_data(as_text=True)
    assert "orphelin" not in h
    assert "Aucune façade relevée" in h


def test_by_session_porte_le_nom_de_linstrument():
    gid = _gear("Nommé Synth", "NS")
    sid = _seance(machines="Nommé Synth")
    eng = KnobSheetEngine(_DB)
    eng.set_controls(gid, "Cutoff")
    eng.save(gid, {"Cutoff": "4"}, session_id=sid)
    assert eng.by_session(sid)[0]["gear_name"] == "Nommé Synth"


def test_lien_depuis_la_seance(client):
    sid = _seance(title="Avec lien")
    assert f"/session/{sid}/rappel" in client.get(f"/session/{sid}").get_data(as_text=True)
