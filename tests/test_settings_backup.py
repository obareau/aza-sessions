"""Paramètres → sauvegardes : export, restauration, filet avant destruction.

Chaque test pointe l'app sur sa PROPRE base : restaurer ou vider la base
partagée de conftest casserait les tests qui suivent.
"""
import io
import json
import sqlite3

import pytest

from core import journal as jr
from core.init_db import init_db


@pytest.fixture()
def iso(app, tmp_path, monkeypatch):
    db = str(tmp_path / "sessions.db")
    init_db(db)
    folder = str(tmp_path / "json")
    j = jr.Journal(db, folder, "test")
    monkeypatch.setitem(app.config, "DB_PATH", db)
    monkeypatch.setitem(app.config, "JSON_BACKUP_DIR", folder)
    monkeypatch.setitem(app.extensions, "aza_journal", j)
    return db, j


def _session(db, title):
    c = sqlite3.connect(db)
    c.execute("INSERT INTO sessions (date, title) VALUES ('2026-11-14T21:00', ?)", (title,))
    c.commit()
    c.close()


def _titles(db):
    return [r[0] for r in sqlite3.connect(db).execute("SELECT title FROM sessions ORDER BY id")]


def _autre_base(tmp_path, *titles):
    other = str(tmp_path / "autre.db")
    init_db(other)
    for t in titles:
        _session(other, t)
    return other


def test_page_parametres_montre_les_sauvegardes(client, iso):
    _, j = iso
    j.save_now()
    r = client.get("/settings")
    assert r.status_code == 200
    html = r.get_data(as_text=True)
    assert "Sauvegardes automatiques" in html and j.backup_dir in html
    assert "Restaurer une sauvegarde" in html


def test_premiere_ouverture_explique_quoi_faire(client, iso):
    assert "Première ouverture" in client.get("/settings?premiere=1").get_data(as_text=True)
    assert "Première ouverture" not in client.get("/settings").get_data(as_text=True)


def test_export_json_telechargeable(client, iso):
    db, _ = iso
    _session(db, "exportée")
    r = client.get("/settings/export.json")
    assert r.status_code == 200 and "attachment" in r.headers["Content-Disposition"]
    data = json.loads(r.get_data(as_text=True))
    assert data["format"] == jr.FORMAT
    assert data["tables"]["sessions"]["rows"][0]["title"] == "exportée"


def test_telechargement_db_est_une_vraie_base(client, iso):
    db, _ = iso
    _session(db, "dans le .db")
    r = client.get("/settings/backup")
    assert r.data[:16] == jr.SQLITE_MAGIC


def test_sauvegarder_maintenant(client, iso):
    _, j = iso
    r = client.post("/settings/sauvegarder", follow_redirects=True)
    assert "Sauvegarde écrite" in r.get_data(as_text=True)
    r = client.post("/settings/sauvegarder", follow_redirects=True)
    assert "à jour" in r.get_data(as_text=True)
    assert len(jr.list_snapshots(j.backup_dir)) == 1


def test_etat_api(client, iso):
    _, j = iso
    j.save_now()
    data = client.get("/api/sauvegarde/etat").get_json()
    assert data["nombre"] == 1 and data["erreur"] is None


def test_restaurer_un_json_remplace_tout_et_garde_l_avant(client, iso, tmp_path):
    db, j = iso
    _session(db, "état actuel")
    other = _autre_base(tmp_path, "ancienne 1", "ancienne 2")
    payload = jr.to_json(jr.dump_db(other)).encode("utf-8")

    r = client.post("/settings/restaurer",
                    data={"backup_file": (io.BytesIO(payload), "sauvegarde.json")},
                    content_type="multipart/form-data", follow_redirects=True)
    html = r.get_data(as_text=True)
    assert "Base restaurée" in html and "2 séance(s)" in html
    assert _titles(db) == ["ancienne 1", "ancienne 2"]

    avant = [s for s in jr.list_snapshots(j.backup_dir) if s["label"] == "avant-restauration"]
    assert len(avant) == 1
    with open(avant[0]["path"], encoding="utf-8") as f:
        assert "état actuel" in f.read(), "l'état écrasé est récupérable"


def test_restaurer_une_vieille_base_db(client, iso, tmp_path):
    db, _ = iso
    other = _autre_base(tmp_path, "depuis un .db")
    with open(other, "rb") as f:
        payload = f.read()
    client.post("/settings/restaurer",
                data={"backup_file": (io.BytesIO(payload), "sessions.db")},
                content_type="multipart/form-data")
    assert _titles(db) == ["depuis un .db"]


def test_fichier_invalide_ne_touche_a_rien(client, iso):
    db, j = iso
    _session(db, "à garder")
    r = client.post("/settings/restaurer",
                    data={"backup_file": (io.BytesIO(b"pas une sauvegarde"), "x.json")},
                    content_type="multipart/form-data", follow_redirects=True)
    assert "Rien n&#39;a été modifié" in r.get_data(as_text=True) or \
           "Rien n'a été modifié" in r.get_data(as_text=True)
    assert _titles(db) == ["à garder"]
    assert not jr.list_snapshots(j.backup_dir), "pas de copie de sécurité pour un refus"


def test_restaurer_depuis_la_liste(client, iso):
    db, j = iso
    _session(db, "version 1")
    first = j.save_now()
    _session(db, "ajout regretté")
    j.save_now()
    name = first.rsplit("/", 1)[-1]
    client.post(f"/settings/sauvegardes/{name}/restaurer")
    assert _titles(db) == ["version 1"]


def test_nom_de_sauvegarde_inconnu_ou_detourne(client, iso):
    db, _ = iso
    _session(db, "intacte")
    name = "aza-sessions_2020-01-01_00-00-00.json"
    r = client.post(f"/settings/sauvegardes/{name}/restaurer", follow_redirects=True)
    assert "introuvable" in r.get_data(as_text=True)
    r = client.get(f"/settings/sauvegardes/{name}", follow_redirects=True)
    assert "introuvable" in r.get_data(as_text=True)
    # un nom qui sort du dossier : refusé avant même la route, ou introuvable
    for name in ("..%2F..%2Fsessions.db", "..", "sessions.db"):
        r = client.get(f"/settings/sauvegardes/{name}", follow_redirects=True)
        assert r.status_code == 404 or "introuvable" in r.get_data(as_text=True)
        assert jr.SQLITE_MAGIC not in r.data
    assert _titles(db) == ["intacte"]


def test_vider_ecrit_un_filet_d_abord(client, iso):
    db, j = iso
    _session(db, "vidée puis retrouvée")
    r = client.post("/settings/reset-sessions")
    assert "avant-vidage" in r.get_data(as_text=True)
    assert _titles(db) == []
    avant = [s for s in jr.list_snapshots(j.backup_dir) if s["label"] == "avant-vidage"]
    client.post(f"/settings/sauvegardes/{avant[0]['name']}/restaurer")
    assert _titles(db) == ["vidée puis retrouvée"]


def test_sans_filet_pas_de_destruction(client, iso, tmp_path, monkeypatch):
    db, _ = iso
    _session(db, "survivante")
    bloque = tmp_path / "fichier-pas-dossier"
    bloque.write_text("x")
    j = jr.Journal(db, str(bloque), "test")
    monkeypatch.setitem(client.application.extensions, "aza_journal", j)
    r = client.post("/settings/reset-sessions", follow_redirects=True)
    assert "Opération annulée" in r.get_data(as_text=True)
    assert _titles(db) == ["survivante"]


def test_bandeau_si_la_sauvegarde_echoue(client, iso):
    _, j = iso
    j.last_error = "PermissionError: [Errno 1] Operation not permitted"
    html = client.get("/stats").get_data(as_text=True)
    assert "La sauvegarde automatique échoue" in html and "Operation not permitted" in html
    j.last_error = None
    assert "La sauvegarde automatique échoue" not in client.get("/stats").get_data(as_text=True)


def test_api_sauvegarde_maintenant(client, iso):
    db, _ = iso
    r = client.post("/api/sauvegarde")
    assert r.status_code == 200 and r.get_json()["ecrit"].startswith("aza-sessions_")
    r = client.post("/api/sauvegarde")
    assert r.get_json()["ecrit"] is None, "base inchangée : rien de neuf à écrire"
    _session(db, "nouvelle")
    assert client.post("/api/sauvegarde").get_json()["ecrit"]
