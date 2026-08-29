"""Sauvegarde automatique de la base — appelée au démarrage, local ET Gunicorn."""
import glob
import hashlib
import os
import sqlite3
import tempfile
from datetime import datetime

PREFIX = "sessions_"
KEEP = 5


def _sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def _snapshot(db_path, dest):
    """Copie cohérente via l'API backup de SQLite.

    Pas un shutil.copy2 : sous Gunicorn l'app sert déjà des requêtes au moment
    du démarrage, et copier le fichier pendant une écriture donne une base
    déchirée. L'API backup prend un verrou propre et gère le WAL.
    """
    src = sqlite3.connect(db_path, timeout=10.0)
    try:
        dst = sqlite3.connect(dest)
        try:
            src.backup(dst)
        finally:
            dst.close()
    finally:
        src.close()


def backup_db(db_path, backups_dir, keep=KEEP):
    """Snapshot horodaté de db_path dans backups_dir, rétention des `keep` derniers.

    Retourne le chemin écrit, ou None si rien n'a été fait (base absente, ou
    inchangée depuis le dernier backup).

    ⚠️ Le saut sur base inchangée n'est pas une optimisation, c'est ce qui protège
    la rétention. aza-sessions.service tourne en `Restart=always` : si Gunicorn
    part en boucle de redémarrage, cinq relances suffisent à évincer les cinq
    backups et il ne reste que des copies de l'état cassé — le filet disparaît
    précisément au moment où il servirait. Une base inchangée ne consomme donc
    aucun emplacement.
    """
    if not os.path.exists(db_path):
        return None

    os.makedirs(backups_dir, exist_ok=True)
    existing = sorted(glob.glob(os.path.join(backups_dir, f"{PREFIX}*.db")))

    fd, tmp = tempfile.mkstemp(suffix=".db", dir=backups_dir)
    os.close(fd)
    try:
        _snapshot(db_path, tmp)
        if existing and _sha256(tmp) == _sha256(existing[-1]):
            return None
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        dest = os.path.join(backups_dir, f"{PREFIX}{ts}.db")
        os.replace(tmp, dest)
        tmp = None
    finally:
        if tmp and os.path.exists(tmp):
            os.remove(tmp)

    for old in existing[: max(0, len(existing) + 1 - keep)]:
        try:
            os.remove(old)
        except OSError:
            pass

    return dest
