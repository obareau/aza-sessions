"""Sauvegarde JSON (`core/journal.py`) — ce qui protège l'historique.

Chaque test travaille sur sa propre base, jamais sur celle de conftest : on y
restaure, on y écrase, on y casse des fichiers.
"""
import json
import os
import sqlite3
import time
from datetime import datetime, timedelta

import pytest

from core import journal
from core.init_db import init_db


def _db(tmp_path, name="sessions.db"):
    path = str(tmp_path / name)
    init_db(path)
    return path


def _remplir(path):
    c = sqlite3.connect(path)
    c.execute("INSERT INTO projects (id, title) VALUES (7, 'Ordium')")
    c.execute(
        "INSERT INTO sessions (date, title, comments, rating, project_id, recap_claude) "
        "VALUES (?, ?, ?, ?, ?, NULL)",
        ("2026-11-14T21:00", "Nappe — Scaër", "drone « froid », 𝄞 et accents : éèà", 4, 7))
    c.execute("INSERT INTO sessions (date, title) VALUES ('2026-11-15T10:00', 'à supprimer')")
    c.execute("DELETE FROM sessions WHERE title='à supprimer'")  # trou dans les id
    c.execute("INSERT INTO patch_layouts (id, name) VALUES (1, 'chaîne')")
    c.execute("INSERT INTO patch_nodes (layout_id, label, x, y) VALUES (1, 'MicroFreak', 12.5, -0.1)")
    c.execute("INSERT INTO sysex_banks (name, data) VALUES ('DX7', ?)", (bytes(range(256)) * 16,))
    c.commit()
    c.close()


def _donnees(path):
    d = journal.dump_db(path)
    return d["tables"], d["sequences"]


# ── EXPORT ───────────────────────────────────────────────────────────────────

def test_export_couvre_toutes_les_tables(tmp_path):
    path = _db(tmp_path)
    _remplir(path)
    d = journal.dump_db(path, app_version="9.9.9")
    assert d["format"] == journal.FORMAT and d["app_version"] == "9.9.9"
    tables = {r[0] for r in sqlite3.connect(path).execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")}
    assert set(d["tables"]) == tables, "une table oubliée est une table perdue"
    assert d["counts"]["sessions"] == 1
    assert d["sequences"]["sessions"] == 2, "le compteur garde la trace de l'id supprimé"
    blob = d["tables"]["sysex_banks"]["rows"][0]["data"]
    assert set(blob) == {"$base64"}


def test_export_est_du_json_lisible(tmp_path):
    path = _db(tmp_path)
    _remplir(path)
    text = journal.to_json(journal.dump_db(path))
    assert "drone « froid »" in text, "les accents restent lisibles, pas en \\u00ab"
    assert json.loads(text)["tables"]["sessions"]["rows"][0]["title"] == "Nappe — Scaër"


def test_empreinte_ignore_la_date_mais_pas_les_donnees(tmp_path):
    path = _db(tmp_path)
    a = journal.dump_db(path)
    time.sleep(1.1)
    b = journal.dump_db(path)
    assert a["created_at"] != b["created_at"] and a["sha256"] == b["sha256"]
    _remplir(path)
    assert journal.dump_db(path)["sha256"] != a["sha256"]


# ── RESTAURATION ─────────────────────────────────────────────────────────────

def test_aller_retour_identique(tmp_path):
    src = _db(tmp_path, "src.db")
    _remplir(src)
    dump = json.loads(journal.to_json(journal.dump_db(src)))  # passe par le texte

    dst = _db(tmp_path, "dst.db")
    sqlite3.connect(dst).execute("INSERT INTO sessions (date) VALUES ('x')").connection.commit()
    report = journal.restore(dst, dump)

    assert _donnees(dst) == _donnees(src)
    assert report["counts"]["sessions"] == 1 and report["ignored"] == []
    data = sqlite3.connect(dst).execute("SELECT data FROM sysex_banks").fetchone()[0]
    assert data == bytes(range(256)) * 16


def test_restauration_ne_reutilise_pas_un_id_supprime(tmp_path):
    src = _db(tmp_path, "src.db")
    _remplir(src)
    dst = _db(tmp_path, "dst.db")
    journal.restore(dst, journal.dump_db(src))
    c = sqlite3.connect(dst)
    c.execute("INSERT INTO sessions (date) VALUES ('2026-11-16')")
    assert c.execute("SELECT max(id) FROM sessions").fetchone()[0] == 3


def test_une_connexion_ouverte_voit_la_base_restauree(tmp_path):
    """La base est réécrite EN PLACE : pas de fichier remplacé sous les pieds
    d'une connexion déjà ouverte, qui écrirait sinon dans le vide."""
    src = _db(tmp_path, "src.db")
    _remplir(src)
    dst = _db(tmp_path, "dst.db")
    ouverte = sqlite3.connect(dst)
    assert ouverte.execute("SELECT count(*) FROM sessions").fetchone()[0] == 0
    journal.restore(dst, journal.dump_db(src))
    assert ouverte.execute("SELECT count(*) FROM sessions").fetchone()[0] == 1


def test_fichier_abime_refuse_et_base_intacte(tmp_path):
    src = _db(tmp_path, "src.db")
    _remplir(src)
    dump = journal.dump_db(src)
    dump["tables"]["sessions"]["rows"][0]["title"] = "modifié en route"

    dst = _db(tmp_path, "dst.db")
    sqlite3.connect(dst).execute("INSERT INTO sessions (date) VALUES ('garde-moi')").connection.commit()
    avant = _donnees(dst)
    with pytest.raises(journal.RestoreError, match="SHA-256"):
        journal.restore(dst, dump)
    assert _donnees(dst) == avant


def test_json_corrige_a_la_main_sans_empreinte_accepte(tmp_path):
    src = _db(tmp_path, "src.db")
    _remplir(src)
    dump = journal.dump_db(src)
    dump["tables"]["sessions"]["rows"][0]["title"] = "corrigé à la main"
    del dump["sha256"]
    dst = _db(tmp_path, "dst.db")
    journal.restore(dst, dump)
    assert sqlite3.connect(dst).execute("SELECT title FROM sessions").fetchone()[0] == "corrigé à la main"


def test_colonne_inconnue_refusee_sauf_si_on_l_accepte(tmp_path):
    src = _db(tmp_path, "src.db")
    _remplir(src)
    dump = journal.dump_db(src)
    dump["tables"]["sessions"]["rows"][0]["humeur"] = "rouille"
    dump["tables"]["sessions"]["columns"].append("humeur")
    dump["sha256"] = journal.content_hash(dump)

    dst = _db(tmp_path, "dst.db")
    with pytest.raises(journal.RestoreError, match="sessions.humeur"):
        journal.restore(dst, dump)
    assert _donnees(dst)[0]["sessions"]["rows"] == []

    report = journal.restore(dst, dump, allow_unknown=True)
    assert "sessions.humeur" in report["ignored"]
    assert sqlite3.connect(dst).execute("SELECT count(*) FROM sessions").fetchone()[0] == 1


def test_vieille_base_restauree_entiere(tmp_path):
    """Une sessions.db d'avant les migrations : colonnes manquantes, table du
    Prompteur parti chez D.I.M. Tout ce qui se range est repris."""
    old = str(tmp_path / "vieille.db")
    c = sqlite3.connect(old)
    c.execute("CREATE TABLE sessions (id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, "
              "machines TEXT, comments TEXT, created_at TEXT)")
    c.execute("CREATE TABLE prompter_scripts (id INTEGER PRIMARY KEY, title TEXT)")
    c.execute("CREATE TABLE obliques (id INTEGER PRIMARY KEY AUTOINCREMENT, text TEXT NOT NULL, "
              "active INTEGER DEFAULT 1, created_at TEXT)")
    c.execute("INSERT INTO sessions (date, machines, comments) VALUES ('2026-03-02', 'MicroFreak', 'première')")
    c.execute("INSERT INTO prompter_scripts (title) VALUES ('set')")
    c.execute("INSERT INTO obliques (text) VALUES ('Une seule stratégie.')")
    c.commit()
    c.close()

    dump = journal.load_file(old)
    dst = _db(tmp_path, "dst.db")
    report = journal.restore(dst, dump)
    assert report["ignored"] == ["prompter_scripts"]
    c = sqlite3.connect(dst)
    row = c.execute("SELECT comments, session_type, title FROM sessions").fetchone()
    assert row == ("première", "music", ""), "les colonnes absentes prennent leur défaut"
    assert c.execute("SELECT count(*) FROM obliques").fetchone()[0] == 1
    # les tables que la vieille base n'avait pas gardent les valeurs d'usine
    assert c.execute("SELECT count(*) FROM influences").fetchone()[0] > 0


def test_load_file_refuse_ce_qui_n_est_pas_une_sauvegarde(tmp_path):
    p = tmp_path / "x.json"
    p.write_text('{"bonjour": 1}', encoding="utf-8")
    with pytest.raises(journal.RestoreError, match="pas une sauvegarde"):
        journal.load_file(str(p))
    p.write_bytes(b"\x00\x01 rien")
    with pytest.raises(journal.RestoreError):
        journal.load_file(str(p))
    tronque = tmp_path / "t.json"
    src = _db(tmp_path, "src.db")
    tronque.write_text(journal.to_json(journal.dump_db(src))[:500], encoding="utf-8")
    with pytest.raises(journal.RestoreError):
        journal.load_file(str(tronque))


def test_format_plus_recent_refuse(tmp_path):
    src = _db(tmp_path, "src.db")
    dump = journal.dump_db(src)
    dump["format_version"] = journal.FORMAT_VERSION + 1
    with pytest.raises(journal.RestoreError, match="plus récent"):
        journal.check_dump(dump)


# ── FICHIERS & RÉTENTION ─────────────────────────────────────────────────────

def test_ecriture_meme_seconde_ne_s_ecrase_pas(tmp_path):
    src = _db(tmp_path, "src.db")
    d = journal.dump_db(src)
    now = datetime(2026, 11, 14, 21, 0, 0)
    a = journal.write_snapshot(d, str(tmp_path / "b"), now=now)
    b = journal.write_snapshot(d, str(tmp_path / "b"), now=now)
    c = journal.write_snapshot(d, str(tmp_path / "b"), label="avant-restauration", now=now)
    assert len({a, b, c}) == 3
    snaps = journal.list_snapshots(str(tmp_path / "b"))
    assert len(snaps) == 3 and {s["label"] for s in snaps} == {"", "avant-restauration"}
    assert not [f for f in os.listdir(tmp_path / "b") if f.startswith(".")], "aucun reste d'écriture"


def _snap(when, label=""):
    return {"name": f"{when:%Y-%m-%d_%H-%M-%S}{label}", "when": when, "label": label}


def test_retention_par_paliers():
    now = datetime(2026, 11, 14, 12, 0)
    snaps = []
    # une sauvegarde toutes les heures pendant 400 jours
    for h in range(400 * 24):
        snaps.append(_snap(now - timedelta(hours=h)))
    snaps.append(_snap(now - timedelta(days=300), label="avant-vidage"))
    keep = journal.keep_set(snaps, now)
    kept = [s for s in snaps if s["name"] in keep]

    recent = [s for s in kept if now - s["when"] < timedelta(hours=48)]
    assert len(recent) == 48, "tout ce qui a moins de 48 h"
    days = {s["when"].date() for s in kept if timedelta(hours=48) <= now - s["when"] < timedelta(days=60)}
    assert len([s for s in kept if timedelta(hours=48) <= now - s["when"] < timedelta(days=60)]) == len(days)
    assert any(s["label"] == "avant-vidage" for s in kept), "une copie de sécurité ne s'efface pas"
    months = {(s["when"].year, s["when"].month) for s in snaps}
    assert {(s["when"].year, s["when"].month) for s in kept} == months, "au moins une par mois"
    assert len(kept) < 200


def test_retention_garde_les_vingt_dernieres_meme_anciennes():
    now = datetime(2026, 11, 14)
    snaps = [_snap(now - timedelta(days=200, minutes=m)) for m in range(30)]
    keep = journal.keep_set(snaps, now)
    assert len(keep) == journal.KEEP_NEWEST


# ── VEILLE ───────────────────────────────────────────────────────────────────

def test_save_now_ne_duplique_pas_une_base_inchangee(tmp_path):
    path = _db(tmp_path)
    j = journal.Journal(path, str(tmp_path / "json"))
    first = j.save_now()
    assert first and j.save_now() is None
    # une autre instance (redémarrage de l'app) relit l'empreinte sur disque
    j2 = journal.Journal(path, str(tmp_path / "json"))
    assert j2.save_now() is None
    assert j2.save_now(label="avant-restauration"), "une copie étiquetée s'écrit toujours"
    _remplir(path)
    assert j2.save_now()
    assert j2.status()["nombre"] == 3 and j2.status()["erreur"] is None


def test_echec_d_ecriture_est_rapporte(tmp_path):
    path = _db(tmp_path)
    bloque = tmp_path / "pas-un-dossier"
    bloque.write_text("fichier")
    j = journal.Journal(path, str(bloque))
    assert j.save_now() is None
    assert j.last_error, "une sauvegarde qui échoue doit se voir"


def test_la_veille_sauvegarde_apres_une_ecriture(tmp_path):
    path = _db(tmp_path)
    j = journal.Journal(path, str(tmp_path / "json"), interval=0.05, quiet=0.15, max_wait=2)
    j.save_now()
    j.start()
    try:
        c = sqlite3.connect(path)
        c.execute("INSERT INTO sessions (date, title) VALUES ('2026-11-14', 'vue par la veille')")
        c.commit()
        c.close()
        deadline = time.time() + 5
        while time.time() < deadline and j.status()["nombre"] < 2:
            time.sleep(0.05)
    finally:
        j.stop(flush=False)
    snaps = journal.list_snapshots(str(tmp_path / "json"))
    assert len(snaps) == 2
    with open(snaps[0]["path"], encoding="utf-8") as f:
        assert "vue par la veille" in f.read()


def test_rafale_continue_sauvegardee_au_plus_tard_a_max_wait(tmp_path):
    path = _db(tmp_path)
    j = journal.Journal(path, str(tmp_path / "json"), interval=0.05, quiet=10, max_wait=0.4)
    j.save_now()
    j.start()
    try:
        c = sqlite3.connect(path)
        t0 = time.time()
        while time.time() - t0 < 1.5 and j.status()["nombre"] < 2:
            c.execute("INSERT INTO sessions (date) VALUES ('rafale')")
            c.commit()
            time.sleep(0.03)
        c.close()
    finally:
        j.stop(flush=False)
    assert journal.list_snapshots(str(tmp_path / "json")).__len__() >= 2
