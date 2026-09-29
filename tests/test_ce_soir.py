"""Le tirage du soir, la feuille d'atelier, et l'ouverture d'une séance en un clic.

Trois faces d'une même idée : tout ce qu'AZA sait ne servait qu'**après** avoir
joué. Ce qui se teste ici, c'est que ça marche à partir du catalogue seul — sans
historique de séances à accumuler d'abord.
"""
import os

from core.db import get_db
from core.tirage import tirer

_DB = os.environ["DB_PATH"]


def _gear(nom, typ="machine", code="", favori=0, actif=1):
    conn = get_db(_DB)
    cur = conn.execute(
        "INSERT INTO catalogue (type, name, active, code, favorite) VALUES (?, ?, ?, ?, ?)",
        (typ, nom, actif, code, favori))
    conn.commit()
    gid = cur.lastrowid
    conn.close()
    return gid


# ── Tirage ───────────────────────────────────────────────────────────────────

def test_tire_un_instrument_et_un_traitement():
    t = tirer(_DB, seed=1)
    assert t["instrument"] and t["instrument"]["type"] in ("machine", "synth_ios", "app_ios")
    assert t["traitement"] and t["traitement"]["type"] in ("effet", "plugin", "plugin_ios")


def test_porte_contrainte_et_titre():
    t = tirer(_DB, seed=2)
    assert t["oblique"] and t["titre"]


def test_reproductible_a_graine_egale():
    assert tirer(_DB, seed=7)["noms"] == tirer(_DB, seed=7)["noms"]


def test_ignore_le_materiel_inactif(tmp_path):
    """Un appareil désactivé ne doit jamais tomber — c'est le seul réglage
    dont dispose l'usager pour écarter une fiche du tirage."""
    from core.init_db import init_db
    chemin = str(tmp_path / "t.db")
    init_db(chemin)
    conn = get_db(chemin)
    conn.execute("UPDATE catalogue SET active = 0")
    conn.execute("INSERT INTO catalogue (type,name,active) VALUES ('machine','Seul Actif',1)")
    conn.commit()
    conn.close()
    for graine in range(12):
        t = tirer(chemin, seed=graine)
        assert t["instrument"]["name"] == "Seul Actif"


def test_catalogue_vide_ne_leve_pas(tmp_path):
    from core.init_db import init_db
    chemin = str(tmp_path / "v.db")
    init_db(chemin)
    conn = get_db(chemin)
    conn.execute("UPDATE catalogue SET active = 0")
    conn.commit()
    conn.close()
    t = tirer(chemin, seed=1)
    assert t["vide"] is True and t["noms"] == []


def test_favori_pondere(tmp_path):
    """Un favori sort plus souvent — sinon le tirage proposerait surtout ce
    qu'on n'a pas aimé assez pour le marquer."""
    from core.init_db import init_db
    chemin = str(tmp_path / "f.db")
    init_db(chemin)
    conn = get_db(chemin)
    conn.execute("UPDATE catalogue SET active = 0")
    conn.execute("INSERT INTO catalogue (type,name,active,favorite) VALUES ('machine','Chouchou',1,1)")
    conn.execute("INSERT INTO catalogue (type,name,active,favorite) VALUES ('machine','Banal',1,0)")
    conn.commit()
    conn.close()
    tirages = [tirer(chemin, seed=g)["instrument"]["name"] for g in range(60)]
    assert tirages.count("Chouchou") > tirages.count("Banal")


# ── Pages ────────────────────────────────────────────────────────────────────

def test_page_ce_soir(client):
    _gear("Tirage Synthe", "machine", "TSY")
    _gear("Tirage Pedale", "effet", "TPD")
    h = client.get("/ce-soir").get_data(as_text=True)
    assert "Je joue ça" in h and "Autre tirage" in h


def test_seance_preselectionnee(client):
    """Le clic « je joue ça » doit arriver sur /vite avec le matériel coché."""
    _gear("Preselect Synthe", "machine", "PSY")
    h = client.get("/vite?gear=Preselect%20Synthe&title=NODE%20TEST").get_data(as_text=True)
    assert '"Preselect Synthe"' in h          # dans la présélection JS
    assert 'value="NODE TEST"' in h           # titre déjà posé


def test_presel_absente_nempeche_rien(client):
    assert client.get("/vite").status_code == 200


def test_feuille_datelier(client):
    gid = _gear("Atelier Synthe", "machine", "ASY")
    conn = get_db(_DB)
    conn.execute("UPDATE catalogue SET controls = '-- FILTRE\nCutoff\nMode: LP | HP' WHERE id = ?", (gid,))
    conn.commit()
    conn.close()
    h = client.get("/atelier?gear=Atelier%20Synthe").get_data(as_text=True)
    assert "Cutoff" in h and "at-jauge" in h
    assert "LP" in h                           # le sélecteur sort en cases à cocher


def test_atelier_instrument_non_declare(client):
    """Sans commandes déclarées, des lignes vides plutôt que rien."""
    _gear("Atelier Nu", "machine", "ANU")
    h = client.get("/atelier?gear=Atelier%20Nu").get_data(as_text=True)
    assert h.count("at-jauge") >= 6


def test_atelier_sans_materiel(client):
    assert client.get("/atelier").status_code == 200


def test_bouton_je_joue_sur_la_fiche(client):
    gid = _gear("Bouton Jouer", "machine", "BJ1")
    h = client.get(f"/catalogue/{gid}").get_data(as_text=True)
    assert "Je joue avec ça" in h
    assert "/vite?gear=Bouton+Jouer" in h or "Bouton%20Jouer" in h
