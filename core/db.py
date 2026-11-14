import os
import sqlite3
import urllib.request


def get_db(db_path):
    conn = sqlite3.connect(db_path, timeout=10.0)
    conn.row_factory = sqlite3.Row
    return conn


def ro_uri(db_path):
    """URI SQLite en lecture seule, chemin encodé.

    ⚠️ Pas de `f"file:{db_path}?mode=ro"` brut : un `#` ou un `?` dans le chemin
    y est pris pour un fragment ou une requête, et SQLite ouvre alors un AUTRE
    fichier — sans erreur. L'app Mac range la base sous « Application Support/
    AZA Sessions », un chemin qui n'a plus rien d'anodin.
    """
    return "file:" + urllib.request.pathname2url(os.path.abspath(db_path)) + "?mode=ro"
