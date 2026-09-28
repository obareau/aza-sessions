"""Dépouillement des prises — rapprocher les fichiers du R8 et les séances.

Le cœur du sujet est le rapprochement : le R8 range ses enregistrements en
dossiers de projet, donc le nom fabriqué par AZA se retrouve souvent sur le
dossier et pas sur le fichier. Un test par faux corpus, jamais par le vrai
dossier de prises — il n'existe pas encore et son contenu n'est pas du code.
"""
import os
import struct
import wave
from pathlib import Path

from core.db import get_db
from takes.engine import TakesEngine, mmss

_DB = os.environ["DB_PATH"]


def _wav(chemin: Path, secondes=1):
    chemin.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(chemin), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(8000)
        f.writeframes(struct.pack("<h", 0) * (8000 * secondes))


def _seance(titre, prise):
    conn = get_db(_DB)
    cur = conn.execute(
        "INSERT INTO sessions (date, title, audio_file) VALUES ('2026-09-28T20:00', ?, ?)",
        (titre, prise))
    conn.commit()
    sid = cur.lastrowid
    conn.close()
    return sid


def test_dossier_absent(tmp_path):
    eng = TakesEngine(_DB, str(tmp_path / "nulle-part"))
    assert eng.dispo is False
    assert eng.fichiers() == []
    d = eng.depouille()
    assert d["rattachees"] == [] and d["orphelines"] == []


def test_nom_porte_par_le_dossier_de_projet(tmp_path):
    """Cas réel du R8 : PROJET/TRACK01.WAV — c'est le dossier qui nomme.

    Le nom de prise est unique à ce test : la base de test est partagée entre
    fichiers, et deux tests qui choisiraient le même nom se rapprocheraient
    l'un l'autre.
    """
    _wav(tmp_path / "TKDOS_1" / "TRACK01.WAV")
    _seance("Nappe", "TKDOS_1")
    d = TakesEngine(_DB, str(tmp_path)).depouille()
    assert [s["title"] for f in d["rattachees"] for s in f["seances"]] == ["Nappe"]


def test_collision_de_nom_montre_les_deux_seances(tmp_path):
    """Le compteur du R8 est quotidien : `MF_1` revient chaque jour.

    Cette collision est assumée (voir CLAUDE.md). Le dépouillement doit donc
    montrer les deux séances candidates plutôt que d'en élire une au hasard —
    c'est à l'oreille de trancher.
    """
    _wav(tmp_path / "TKCOL_1.WAV")
    _seance("Lundi", "TKCOL_1")
    _seance("Mardi", "TKCOL_1")
    d = TakesEngine(_DB, str(tmp_path)).depouille()
    titres = {s["title"] for f in d["rattachees"] for s in f["seances"]}
    assert titres == {"Lundi", "Mardi"}


def test_nom_porte_par_le_fichier(tmp_path):
    _wav(tmp_path / "MF_9.WAV")
    _seance("Directe", "MF_9")
    d = TakesEngine(_DB, str(tmp_path)).depouille()
    assert d["rattachees"] and not d["orphelines"]


def test_casse_ignoree(tmp_path):
    _wav(tmp_path / "mfmg_4.wav")
    _seance("Casse", "MFMG_4")
    assert TakesEngine(_DB, str(tmp_path)).depouille()["rattachees"]


def test_orpheline(tmp_path):
    _wav(tmp_path / "ZOOM0043.WAV")
    d = TakesEngine(_DB, str(tmp_path)).depouille()
    assert [f["nom"] for f in d["orphelines"]] == ["ZOOM0043.WAV"]


def test_reclamee_mais_absente(tmp_path):
    _seance("Perdue", "INTROUV_1")
    d = TakesEngine(_DB, str(tmp_path))  # dossier vide mais existant
    tmp_path.mkdir(exist_ok=True)
    assert "INTROUV_1" in [s["audio_file"] for s in d.depouille()["manquantes"]]


def test_duree_lue_dans_lentete(tmp_path):
    _wav(tmp_path / "DUREE_1.WAV", secondes=3)
    f = TakesEngine(_DB, str(tmp_path)).fichiers()[0]
    assert f["duree"] == "0:03"


def test_fichier_non_audio_ignore(tmp_path):
    (tmp_path / "notes.txt").write_text("rien", encoding="utf-8")
    assert TakesEngine(_DB, str(tmp_path)).fichiers() == []


def test_mmss():
    assert mmss(0) == "" and mmss(None) == ""
    assert mmss(65) == "1:05" and mmss(600) == "10:00"


# ── Sécurité du chemin ───────────────────────────────────────────────────────

def test_traversee_de_chemin_refusee(tmp_path):
    """Sans ce garde-fou, la route d'écoute servirait tout le disque."""
    _wav(tmp_path / "ok.wav")
    secret = tmp_path.parent / "secret.wav"
    _wav(secret)
    eng = TakesEngine(_DB, str(tmp_path))
    assert eng.chemin_sur("ok.wav") is not None
    assert eng.chemin_sur("../secret.wav") is None
    assert eng.chemin_sur("/etc/passwd") is None
    assert eng.chemin_sur("") is None


def test_lien_symbolique_sortant_refuse(tmp_path):
    """On compare les chemins réels : un lien qui sort doit être arrêté aussi."""
    dehors = tmp_path.parent / "dehors.wav"
    _wav(dehors)
    tmp_path.mkdir(exist_ok=True)
    lien = tmp_path / "piege.wav"
    try:
        lien.symlink_to(dehors)
    except OSError:
        return  # pas de lien symbolique possible ici
    assert TakesEngine(_DB, str(tmp_path)).chemin_sur("piege.wav") is None


# ── Routes ───────────────────────────────────────────────────────────────────

def test_page_sans_dossier(client):
    """Sans dossier configuré, la page le dit au lieu de planter."""
    r = client.get("/prises")
    assert r.status_code == 200
    assert "introuvable" in r.get_data(as_text=True).lower()


def test_ecoute_refuse_hors_racine(client):
    assert client.get("/prises/ecouter?f=../../etc/passwd").status_code == 404


def test_creation_depuis_une_orpheline(client):
    """La séance naît avec le nom du fichier déjà inscrit."""
    assert 'value="ZOOM0043"' in client.get("/new?audio=ZOOM0043").get_data(as_text=True)


def test_copie_de_setup_ne_recopie_pas_la_prise(client):
    sid = _seance("Source", "PRISE_X")
    h = client.get(f"/new?from={sid}").get_data(as_text=True)
    assert 'value="PRISE_X"' not in h
