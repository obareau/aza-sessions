"""Relevés de potards — surtout la distinction « pas relevé » / « à zéro ».

C'est tout l'enjeu : un synthé analo sans mémoire ne se retrouve que par ses
positions, et un potard noté 0 par défaut ferait croire à un réglage qu'on n'a
jamais lu sur la façade.
"""
import os

from catalogue.engine import KnobSheetEngine, controls_names, parse_controls
from core.db import get_db

_DB = os.environ["DB_PATH"]

DECL = """-- OSCILLATEURS
Osc 1 Freq
Forme 1: Saw | Pulse | Sine
# une ligne de commentaire

-- FILTRE
Cutoff
Mode: LP | BP | HP"""


def _gear(nom):
    conn = get_db(_DB)
    cur = conn.execute(
        "INSERT INTO catalogue (type, name, manufacturer, active) VALUES ('machine', ?, 'Test', 1)",
        (nom,))
    conn.commit()
    gid = cur.lastrowid
    conn.close()
    return gid


# ── Déclaration ──────────────────────────────────────────────────────────────

def test_parse_les_trois_formes():
    kinds = [(c["kind"], c["name"]) for c in parse_controls(DECL)]
    assert ("section", "OSCILLATEURS") in kinds
    assert ("dial", "Cutoff") in kinds
    assert ("switch", "Mode") in kinds


def test_selecteur_garde_ses_positions():
    mode = next(c for c in parse_controls(DECL) if c["name"] == "Mode")
    assert mode["options"] == ["LP", "BP", "HP"]


def test_commentaires_et_vides_ignores():
    assert parse_controls("# rien\n\n   \n") == []


def test_sections_non_relevables():
    """Un titre de section n'a pas de valeur — il ne doit pas devenir un potard."""
    assert "OSCILLATEURS" not in controls_names(DECL)
    assert controls_names(DECL) == ["Osc 1 Freq", "Forme 1", "Cutoff", "Mode"]


def test_declaration_vide():
    assert parse_controls("") == [] and parse_controls(None) == []


# ── Relevés ──────────────────────────────────────────────────────────────────

def test_potard_non_renseigne_nest_pas_zero():
    gid = _gear("Analo A")
    eng = KnobSheetEngine(_DB)
    eng.set_controls(gid, DECL)
    eng.save(gid, {"Cutoff": "7", "Osc 1 Freq": "", "Mode": "LP"})
    sh = eng.sheets(gid)[0]
    assert sh["valeurs"] == {"Cutoff": "7", "Mode": "LP"}
    vide = next(c for c in sh["controls"] if c["name"] == "Osc 1 Freq")
    assert vide["value"] == ""          # pas 0


def test_zero_explicite_est_conserve():
    """0 tapé à la main est un vrai réglage : potard à fond à gauche."""
    gid = _gear("Analo B")
    eng = KnobSheetEngine(_DB)
    eng.set_controls(gid, DECL)
    eng.save(gid, {"Cutoff": "0"})
    assert eng.sheets(gid)[0]["valeurs"] == {"Cutoff": "0"}


def test_commande_declaree_apres_coup_apparait_vide():
    gid = _gear("Analo C")
    eng = KnobSheetEngine(_DB)
    eng.set_controls(gid, "Cutoff")
    eng.save(gid, {"Cutoff": "4"})
    eng.set_controls(gid, "Cutoff\nRésonance")
    noms = {c["name"]: c["value"] for c in eng.sheets(gid)[0]["controls"]}
    assert noms == {"Cutoff": "4", "Résonance": ""}


def test_releve_sans_declaration_reste_visible():
    """Sinon un relevé pris avant la déclaration deviendrait invisible."""
    gid = _gear("Analo D")
    eng = KnobSheetEngine(_DB)
    eng.save(gid, {"Truc": "9"})
    assert eng.sheets(gid)[0]["controls"][0]["name"] == "Truc"


def test_le_plus_recent_dabord():
    gid = _gear("Analo E")
    eng = KnobSheetEngine(_DB)
    eng.set_controls(gid, DECL)
    eng.save(gid, {"Cutoff": "1"}, label="premier")
    eng.save(gid, {"Cutoff": "2"}, label="second")
    assert [s["label"] for s in eng.sheets(gid)] == ["second", "premier"]


def test_suppression():
    gid = _gear("Analo F")
    eng = KnobSheetEngine(_DB)
    eng.set_controls(gid, DECL)
    sid = eng.save(gid, {"Cutoff": "3"})
    eng.delete(sid)
    assert eng.sheets(gid) == []


# ── Route ────────────────────────────────────────────────────────────────────

def test_parcours_complet(client):
    gid = _gear("Analo G")
    r = client.post(f"/catalogue/{gid}", data={"action": "set_controls", "controls": DECL},
                    follow_redirects=True)
    assert r.status_code == 200
    r = client.post(f"/catalogue/{gid}", data={
        "action": "add_sheet", "label": "nappe corrodée",
        "k_Cutoff": "6.5", "k_Mode": "LP"}, follow_redirects=True)
    assert "nappe corrodée" in r.get_data(as_text=True)


def test_releve_vide_refuse(client):
    gid = _gear("Analo H")
    client.post(f"/catalogue/{gid}", data={"action": "set_controls", "controls": DECL})
    client.post(f"/catalogue/{gid}", data={"action": "add_sheet", "k_Cutoff": "", "k_Mode": ""},
                follow_redirects=True)
    assert KnobSheetEngine(_DB).sheets(gid) == []
