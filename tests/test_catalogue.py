"""Tests Phase 1 — catalogue : favoris, types dédiés, saisie rapide multi-lignes."""
import os

from core.db import get_db
from catalogue.engine import CatalogueEngine, ITEM_TYPES

_DB = os.environ["DB_PATH"]


def test_favorite_column_exists():
    """La colonne favorite doit exister sur catalogue après init_db()."""
    conn = get_db(_DB)
    cols = {r[1] for r in conn.execute("PRAGMA table_info(catalogue)").fetchall()}
    conn.close()
    assert "favorite" in cols


def test_dedicated_types_present():
    """Les types dédiés ipad et zynthian doivent être déclarés."""
    assert "ipad" in ITEM_TYPES
    assert "zynthian" in ITEM_TYPES


def test_toggle_favorite():
    """toggle_favorite bascule le flag favorite."""
    eng = CatalogueEngine(_DB)
    eng.add("machine", "TestFavMachine", "TestMfr")
    conn = get_db(_DB)
    item_id = conn.execute(
        "SELECT id FROM catalogue WHERE name='TestFavMachine'"
    ).fetchone()["id"]
    conn.close()

    eng.toggle_favorite(item_id)
    conn = get_db(_DB)
    fav = conn.execute("SELECT favorite FROM catalogue WHERE id=?", (item_id,)).fetchone()["favorite"]
    conn.close()
    assert fav == 1

    eng.toggle_favorite(item_id)
    conn = get_db(_DB)
    fav = conn.execute("SELECT favorite FROM catalogue WHERE id=?", (item_id,)).fetchone()["favorite"]
    conn.close()
    assert fav == 0


def test_add_bulk_inserts_and_dedups():
    """add_bulk insère les nouvelles lignes, ignore les vides et les doublons."""
    eng = CatalogueEngine(_DB)
    rows = [
        {"name": "BulkA", "manufacturer": "Korg", "notes": "n1"},
        {"name": "BulkB", "manufacturer": "Moog", "notes": ""},
        {"name": "", "manufacturer": "Vide", "notes": "ignore"},     # ligne vide
        {"name": "BulkA", "manufacturer": "Korg", "notes": ""},        # doublon dans le lot
    ]
    added, skipped = eng.add_bulk("ipad", rows)
    assert added == 2
    assert skipped == 1

    # Re-soumettre BulkA → doublon existant en DB
    added2, skipped2 = eng.add_bulk("ipad", [{"name": "BulkA", "manufacturer": "Korg"}])
    assert added2 == 0
    assert skipped2 == 1


def test_bulk_route_post(client):
    """POST /catalogue action=bulk crée plusieurs items et redirige."""
    resp = client.post("/catalogue", data={
        "action": "bulk",
        "type": "zynthian",
        "bulk_manufacturer": ["", ""],
        "bulk_name": ["ZynRouteA", "ZynRouteB"],
        "bulk_notes": ["", ""],
    }, follow_redirects=False)
    assert resp.status_code == 302

    conn = get_db(_DB)
    cnt = conn.execute(
        "SELECT COUNT(*) FROM catalogue WHERE type='zynthian' AND name IN ('ZynRouteA','ZynRouteB')"
    ).fetchone()[0]
    conn.close()
    assert cnt == 2


def test_favorite_route_post(client):
    """POST /catalogue action=favorite bascule le favori."""
    eng = CatalogueEngine(_DB)
    eng.add("effet", "FavRouteItem")
    conn = get_db(_DB)
    item_id = conn.execute("SELECT id FROM catalogue WHERE name='FavRouteItem'").fetchone()["id"]
    conn.close()

    client.post("/catalogue", data={"action": "favorite", "id": item_id})
    conn = get_db(_DB)
    fav = conn.execute("SELECT favorite FROM catalogue WHERE id=?", (item_id,)).fetchone()["favorite"]
    conn.close()
    assert fav == 1


# ── Fiches détaillées (vue table) ────────────────────────────────────────────

def test_fiche_columns_exist():
    """purpose et intent doivent exister sur catalogue après init_db()."""
    conn = get_db(_DB)
    cols = {r[1] for r in conn.execute("PRAGMA table_info(catalogue)").fetchall()}
    conn.close()
    assert "purpose" in cols
    assert "intent" in cols


def test_update_fiches_writes_only_changed_rows():
    """update_fiches renseigne les trois champs et ignore les lignes inchangées."""
    eng = CatalogueEngine(_DB)
    eng.add("machine", "FicheMachine")
    eng.add("plugin", "FicheInchangee")
    conn = get_db(_DB)
    ids = {r["name"]: r["id"] for r in conn.execute(
        "SELECT id, name FROM catalogue WHERE name IN ('FicheMachine','FicheInchangee')"
    ).fetchall()}
    conn.close()

    touched = eng.update_fiches([
        {"id": ids["FicheMachine"], "manufacturer": "Arturia",
         "purpose": "  Synthé numérique wavetable  ", "intent": "Nappes de fond"},
        {"id": ids["FicheInchangee"], "manufacturer": "", "purpose": "", "intent": ""},
    ])
    assert touched == 1

    conn = get_db(_DB)
    row = conn.execute(
        "SELECT manufacturer, purpose, intent FROM catalogue WHERE id=?",
        (ids["FicheMachine"],)
    ).fetchone()
    conn.close()
    assert row["manufacturer"] == "Arturia"
    assert row["purpose"] == "Synthé numérique wavetable"   # espaces retirés
    assert row["intent"] == "Nappes de fond"

    # Re-soumettre à l'identique ne réécrit rien
    assert eng.update_fiches([
        {"id": ids["FicheMachine"], "manufacturer": "Arturia",
         "purpose": "Synthé numérique wavetable", "intent": "Nappes de fond"},
    ]) == 0


def test_update_fiches_ignores_unknown_ids():
    """Un id inexistant ou illisible ne fait pas échouer l'enregistrement."""
    eng = CatalogueEngine(_DB)
    assert eng.update_fiches([
        {"id": 999999, "manufacturer": "X", "purpose": "Y", "intent": "Z"},
        {"id": "pas-un-entier", "manufacturer": "X", "purpose": "Y", "intent": "Z"},
    ]) == 0


def test_fiches_route_get_and_post(client):
    """GET /catalogue/fiches affiche la table, POST enregistre les lignes."""
    eng = CatalogueEngine(_DB)
    eng.add("effet", "FicheRouteItem")
    conn = get_db(_DB)
    item_id = conn.execute("SELECT id FROM catalogue WHERE name='FicheRouteItem'").fetchone()["id"]
    conn.close()

    resp = client.get("/catalogue/fiches")
    assert resp.status_code == 200
    assert b"FicheRouteItem" in resp.data

    resp = client.post("/catalogue/fiches", data={
        "id": [str(item_id)],
        "manufacturer": ["Strymon"],
        "purpose": ["Reverb modulee"],
        "intent": ["Fin de chaine sur les nappes"],
    }, follow_redirects=False)
    assert resp.status_code == 302

    conn = get_db(_DB)
    row = conn.execute(
        "SELECT manufacturer, purpose, intent FROM catalogue WHERE id=?", (item_id,)
    ).fetchone()
    conn.close()
    assert row["manufacturer"] == "Strymon"
    assert row["purpose"] == "Reverb modulee"
    assert row["intent"] == "Fin de chaine sur les nappes"


def test_fiche_shown_on_gear_notebook(client):
    """Les deux champs se relisent depuis le carnet de la fiche."""
    eng = CatalogueEngine(_DB)
    eng.add("machine", "FicheCarnetItem")
    conn = get_db(_DB)
    item_id = conn.execute("SELECT id FROM catalogue WHERE name='FicheCarnetItem'").fetchone()["id"]
    conn.close()
    eng.update_fiches([{"id": item_id, "manufacturer": "Elektron",
                        "purpose": "Boite a rythmes analogique",
                        "intent": "Ossature rythmique des sessions live"}])

    resp = client.get(f"/catalogue/{item_id}")
    assert resp.status_code == 200
    assert "Boite a rythmes analogique".encode() in resp.data
    assert "Ossature rythmique des sessions live".encode() in resp.data


def test_fiches_print_route(client):
    """GET /catalogue/fiches/print rend la version papier."""
    eng = CatalogueEngine(_DB)
    eng.add("machine", "FichePrintItem")
    conn = get_db(_DB)
    item_id = conn.execute("SELECT id FROM catalogue WHERE name='FichePrintItem'").fetchone()["id"]
    conn.close()
    eng.update_fiches([{"id": item_id, "manufacturer": "Moog",
                        "purpose": "Basse analogique", "intent": "Fondations"}])

    resp = client.get("/catalogue/fiches/print")
    assert resp.status_code == 200
    body = resp.data.decode()
    assert "FichePrintItem" in body
    assert "Basse analogique" in body
    assert "landscape" in body          # A4 paysage


def test_fiches_print_honours_filters(client):
    """Les filtres de l'écran (type, todo, q) s'appliquent au papier."""
    eng = CatalogueEngine(_DB)
    eng.add("effet", "FichePrintFiltre")   # laissée vide → « à compléter »
    conn = get_db(_DB)
    item_id = conn.execute("SELECT id FROM catalogue WHERE name='FichePrintFiltre'").fetchone()["id"]
    conn.close()

    # Filtre par type : une fiche machine ne doit pas sortir sur un tirage 'effet'
    body = client.get("/catalogue/fiches/print?type=effet").data.decode()
    assert "FichePrintFiltre" in body
    assert "FichePrintItem" not in body

    # Filtre « à compléter » : la fiche renseignée disparaît, la vide reste
    body = client.get("/catalogue/fiches/print?todo=1").data.decode()
    assert "FichePrintFiltre" in body
    assert "FichePrintItem" not in body

    # Recherche libre
    body = client.get("/catalogue/fiches/print?q=fichceprintintrouvable").data.decode()
    assert "Aucune fiche ne correspond" in body

    # Une fois renseignée, elle sort du tirage « à compléter »
    eng.update_fiches([{"id": item_id, "manufacturer": "Boss",
                        "purpose": "Delay", "intent": "Nappes"}])
    body = client.get("/catalogue/fiches/print?todo=1").data.decode()
    assert "FichePrintFiltre" not in body


def test_add_fiche_creates_and_dedups():
    """add_fiche crée une fiche complète et refuse le doublon (type, nom)."""
    eng = CatalogueEngine(_DB)
    new_id = eng.add_fiche("Synth iOS", "FicheAjoutee", "Korg",
                           "  Synthé virtuel  ", "Textures au casque")
    assert new_id is not None

    conn = get_db(_DB)
    row = conn.execute(
        "SELECT type, name, manufacturer, purpose, intent FROM catalogue WHERE id=?",
        (new_id,)
    ).fetchone()
    conn.close()
    assert row["type"] == "synth_ios"          # normalisé comme sur /catalogue
    assert row["manufacturer"] == "Korg"
    assert row["purpose"] == "Synthé virtuel"  # espaces retirés
    assert row["intent"] == "Textures au casque"

    # Deux sorties distinctes pour deux causes distinctes : None dit « doublon »,
    # ValueError dit « saisie incomplète ». Elles ne se corrigent pas pareil.
    assert eng.add_fiche("synth_ios", "FicheAjoutee") is None   # doublon
    for typ, nom, cas in (("machine", "", "nom vide"), ("", "SansType", "type vide")):
        try:
            eng.add_fiche(typ, nom)
        except ValueError:
            continue
        raise AssertionError(f"{cas} aurait du lever ValueError")


def test_fiches_route_add_action(client):
    """POST action=add sur /catalogue/fiches ajoute la fiche et redirige."""
    resp = client.post("/catalogue/fiches", data={
        "action": "add",
        "type": "effet",
        "manufacturer": "Eventide",
        "name": "FicheAjoutRoute",
        "purpose": "Reverb granulaire",
        "intent": "Fin de chaine",
    }, follow_redirects=False)
    assert resp.status_code == 302

    conn = get_db(_DB)
    row = conn.execute(
        "SELECT manufacturer, purpose, intent FROM catalogue WHERE name='FicheAjoutRoute'"
    ).fetchone()
    conn.close()
    assert row["manufacturer"] == "Eventide"
    assert row["purpose"] == "Reverb granulaire"
    assert row["intent"] == "Fin de chaine"

    # La nouvelle fiche s'affiche dans la table
    assert b"FicheAjoutRoute" in client.get("/catalogue/fiches").data


def test_fiches_save_action_still_saves(client):
    """L'enregistrement de la table n'est pas confondu avec un ajout."""
    eng = CatalogueEngine(_DB)
    eng.add("machine", "FicheActionSave")
    conn = get_db(_DB)
    item_id = conn.execute("SELECT id FROM catalogue WHERE name='FicheActionSave'").fetchone()["id"]
    before = conn.execute("SELECT COUNT(*) FROM catalogue").fetchone()[0]
    conn.close()

    client.post("/catalogue/fiches", data={
        "action": "save",
        "id": [str(item_id)],
        "manufacturer": ["Roland"],
        "purpose": ["Boite a rythmes"],
        "intent": ["Rythmique"],
    })

    conn = get_db(_DB)
    after = conn.execute("SELECT COUNT(*) FROM catalogue").fetchone()[0]
    row = conn.execute("SELECT manufacturer FROM catalogue WHERE id=?", (item_id,)).fetchone()
    conn.close()
    assert after == before          # rien de créé au passage
    assert row["manufacturer"] == "Roland"


def test_les_deux_echecs_d_ajout_disent_des_choses_differentes(client):
    """C'est là qu'était le défaut : un seul message pour deux causes.

    L'utilisateur qui saisit un doublon lisait un message parlant de champs
    manquants, et réciproquement.
    """
    base = {"action": "add", "type": "machine", "purpose": "", "intent": "",
            "manufacturer": ""}

    r = client.post("/catalogue/fiches", data={**base, "name": "FicheMessage"},
                    follow_redirects=True)
    assert "ajouté au catalogue".encode() in r.data

    # même nom, même type → doublon
    r = client.post("/catalogue/fiches", data={**base, "name": "FicheMessage"},
                    follow_redirects=True)
    assert "existe déjà".encode() in r.data
    assert "requis".encode() not in r.data, "un doublon ne doit pas parler de champs requis"

    # nom vide → saisie incomplète
    r = client.post("/catalogue/fiches", data={**base, "name": "  "},
                    follow_redirects=True)
    assert "requis".encode() in r.data
    assert "existe déjà".encode() not in r.data, "une saisie vide ne doit pas parler de doublon"


# ── Nom de prise (codes catalogue) ───────────────────────────────────────────

def _avec_code(eng, typ, nom, code):
    eng.add_fiche(typ, nom)
    conn = get_db(_DB)
    conn.execute("UPDATE catalogue SET code=? WHERE type=? AND name=?", (code, typ, nom))
    conn.commit(); conn.close()


def test_code_column_exists():
    conn = get_db(_DB)
    cols = {r[1] for r in conn.execute("PRAGMA table_info(catalogue)").fetchall()}
    conn.close()
    assert "code" in cols


def test_take_name_suit_l_ordre_du_signal_pas_l_alphabet():
    """MicroFreak puis MS-50G : la machine avant l'effet, quoi qu'en dise l'alphabet."""
    eng = CatalogueEngine(_DB)
    _avec_code(eng, "machine", "TakeMicroFreak", "MF")
    _avec_code(eng, "effet", "TakeMS50G", "MG5")
    nom = eng.take_name({"machines": "TakeMicroFreak", "effects": "TakeMS50G"}, "2026-09-27")
    assert nom == "MFMG5_1"


def test_le_compteur_repart_chaque_jour():
    eng = CatalogueEngine(_DB)
    _avec_code(eng, "machine", "TakeCompteur", "TC")
    conn = get_db(_DB)
    for d in ("2026-09-27", "2026-09-27", "2026-09-28"):
        conn.execute("INSERT INTO sessions (date, audio_file) VALUES (?, ?)",
                     (d + "T10:00", "TC_1" if d == "2026-09-28" else "TC_x"))
    conn.execute("UPDATE sessions SET audio_file='TC_1' WHERE date LIKE '2026-09-27%' LIMIT 1")
    conn.commit(); conn.close()
    # 2026-09-28 a déjà TC-1 → la prochaine du 28 est TC-2
    assert eng.take_name({"machines": "TakeCompteur"}, "2026-09-28") == "TC_2"
    # un autre jour repart de 1
    assert eng.take_name({"machines": "TakeCompteur"}, "2026-10-01") == "TC_1"


def test_matos_sans_code_est_ignore_plutot_qu_invente():
    eng = CatalogueEngine(_DB)
    _avec_code(eng, "machine", "TakeAvecCode", "AC")
    eng.add_fiche("effet", "TakeSansCode")          # pas de code
    nom = eng.take_name({"machines": "TakeAvecCode", "effects": "TakeSansCode"}, "2026-11-01")
    assert nom == "AC_1", "un nom sans code ne doit pas fabriquer d'abréviation"


def test_aucun_code_du_tout_ne_donne_pas_de_nom():
    eng = CatalogueEngine(_DB)
    eng.add_fiche("machine", "TakeRien")
    assert eng.take_name({"machines": "TakeRien"}, "2026-11-02") == ""
    assert eng.take_name({}, "2026-11-02") == ""


def test_doublon_de_code_compte_une_fois():
    """Deux machines partageant un code ne doivent pas le répéter."""
    eng = CatalogueEngine(_DB)
    _avec_code(eng, "machine", "TakeJumeauA", "JX")
    _avec_code(eng, "machine", "TakeJumeauB", "JX")
    assert eng.take_name({"machines": "TakeJumeauA, TakeJumeauB"}, "2026-11-03") == "JX_1"


def test_le_nom_respecte_les_contraintes_du_zoom_r8():
    """Manuel du R8 p. 94 : nom de PROJET = 8 caractères max, A-Z 0-9 et « _ ».

    Le tiret est interdit ; une chaîne à trois appareils doit donc être rognée
    plutôt que refusée par la machine à la saisie.
    """
    eng = CatalogueEngine(_DB)
    _avec_code(eng, "machine", "R8Synthe", "MF")
    _avec_code(eng, "effet", "R8Pedale", "MG5")
    _avec_code(eng, "machine", "R8Boite", "DT")

    nom = eng.take_name({"machines": "R8Synthe, R8Boite", "effects": "R8Pedale"}, "2026-12-01")
    assert len(nom) <= 8, f"{nom} dépasse les 8 caractères du R8"
    assert "-" not in nom, "le tiret est refusé par le R8"
    assert all(c.isupper() or c.isdigit() or c == "_" for c in nom), nom
    assert nom.endswith("_1"), "le rang survit au rognage, jamais l'inverse"


def test_un_code_mal_saisi_est_nettoye_pas_transmis():
    """Une saisie avec tiret ou minuscules ne doit pas atteindre la machine."""
    eng = CatalogueEngine(_DB)
    _avec_code(eng, "machine", "R8Sale", "m-f 5")
    nom = eng.take_name({"machines": "R8Sale"}, "2026-12-02")
    assert nom == "MF5_1", nom
